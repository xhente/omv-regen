#!/bin/bash
# -*- ENCODING: UTF-8 -*-

# This file is licensed under the terms of the GNU General Public
# License version 3. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

# omv-regen 2.0.2
# Utilidad para respaldar y restaurar la configuración de openmediavault

ORVersion="2.0.3"

# Establece idioma español si procede
Sp=""
Idioma="$(printenv LANG)"
[ "${Idioma:0:2}" = "es" ] && Sp="si"
Idioma="$(awk -F "=" '/LANG=/ {print $2}' /etc/default/locale)"
[ "${Idioma:0:2}" = "es" ] && Sp="si"
[ "${Idioma:1:2}" = "es" ] && Sp="si"

# Traducción
declare -A txt
txt () {
  if [ "$3" ]; then
    [ "$Sp" ] && txt[$1]="$2" || txt[$1]="$3"
  else
    txt[$1]="$2"
  fi
}

txt Abortar "Abortar" "Abort"; txt Actualizar "Actualizar" "Update"; txt Ahora "Ahora" "Now"
txt Ajustar "Ajustar" "Adjust"; txt Ajustes "Ajustes" "Settings"; txt Anterior "Anterior" "Previous"
txt Ayuda "Ayuda" "Help"; txt Backup_Ajustes "Backup_Ajustes" "Backup_Settings"; txt Buscar "Buscar" "Search"
txt Cancelar "Cancelar" "Cancel"; txt Carpeta "Carpeta" "Folder"; txt Continuar "Continuar" "Continue"
txt Crear "Crear" "Create"; txt Dias "Días" "Days"; txt Ejecutar "Ejecutar" "Run"; txt Eliminar "Eliminar" "Delete"
txt Modificar "Modificar" "Modify"; txt Salir "Salir" "Exit"; txt Si "Si" "Yes"; txt Siempre "Siempre" "Always"
txt Siguiente "Siguiente" "Next"; txt Red "Red" "Network"; txt Regenera_Ajustes "Regenera_Ajustes" "Regenera_Settings"
txt Resetear "Resetear" "Reset"; txt Ruta "Ruta" "Path"; txt Tarea "Tarea" "Task"; txt Volver "Volver" "Go back"

. /etc/default/openmediavault
Fecha=""
Cli=""
Camino="MenuPrincipal"
Alto=30
Ancho=70

declare -A ORA
declare -a FASE
declare -a CARPETAS

ResetearAjustes () {
  ORA[RutaBackup]="/ORBackup"
  ORA[Dias]='7'
  ORA[Actualizar]="${txt[Si]}"
  ORA[RutaOrigen]="/ORBackup"
  ORA[Kernel]="on"
  ORA[Red]="on"
  ORA[Buscar]="on"
  ORA[Siempre]="on"
  ORA[FechaBackup]=""
  ORA[RutaRegen]=""
  ORA[ActualizacionPendiente]=""
  unset CARPETAS
  unset FASE
  FASE[1]="iniciar"
  CARPETAS=("/home")
}

ResetearAjustes

declare -a RUTAS=""
declare -A ORB
ORB[Dpkg]="/ORB_Dpkg"
ORB[DpkgOMV]="/ORB_DpkgOMV"
ORB[Unamea]="/ORB_Unamea"
ORB[Zpoollist]="/ORB_Zpoollist"
ORB[Systemctl]="/ORB_Systemctl"
ORB[HostnameI]="/ORB_HostnameI"
ORB[Lsblk]="/ORB_Lsblk"
ORB[Rootfs]="/ORB_Rootfs"
Configxml="${OMV_CONFIG_FILE}"
Passwd="/etc/passwd"
Shadow="/etc/shadow"
Group="/etc/group"
Subuid="/etc/subuid"
Subgid="/etc/subgid"
Passdb="/var/lib/samba/private/passdb.tdb"
Default="/etc/default/openmediavault"
ORAjustes="/etc/regen/omv-regen.settings"
Omvregen="/usr/sbin/omv-regen"
declare -a ARCHIVOS=("$Configxml" "$Passwd" "$Shadow" "$Group" "$Subuid" "$Subgid" "$Passdb" "$Default" "$ORAjustes" "$Omvregen")
ValidarBackup=""
ValBacRuta=""
ValRutaEsc=""
ValDias=""
ValCarpetas=""
ValidarRegenera=""
ValRegRuta=""
ValFechaBackup=""
ValRegCont=""
ValDpkg=""
ValRegDiscos=""
ValRegRootfs=""
TarRegen=""
TarUserNumero=""
ControlVersiones=""
ComplementosNoInstalados=""
Pregunta=""
Texto=""
URLomvregen="https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh"
URLextras="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master"
ConfTmp="/etc/openmediavault/config.rg"
ORTemp="/tmp/ORTemp"
Listasucia="${OMV_ENGINED_DIRTY_MODULES_FILE}"
Backports="${OMV_APT_USE_KERNEL_BACKPORTS}"
declare -a COMPLEMENTOS
Plugin=""
KernelOR=""
KernelIN=""
declare -a SISTEMA_ARCHIVOS=("openmediavault-zfs" "openmediavault-lvm2" "openmediavault-mergerfs" "openmediavault-snapraid" "openmediavault-remotemount")
OrdenarComplementos=""
VersionOR=""
VersionDI=""
InstII=""
IpOR=""
IpAC=""
Rojo="\e[31m"
Verde="\e[32m"
Reset="\e[0m"
RojoD="\Z1"
AzulD="\Z4"
ResetD="\Zn"
Abortar=""
Ahora=""

# NODOS DE LA BASE DE DATOS
# La primera variable es la ruta del nodo. (nulo = no hay nodo en la base de datos)
# Las siguientes variables son los módulos que debe actualizar salt

# Interfaz GUI
declare -A CONFIG
CONFIG[webadmin]="/config/webadmin monit nginx"
CONFIG[time]="/config/system/time chrony cron timezone"
CONFIG[email]="/config/system/email cronapt mdadm monit postfix smartmontools"
CONFIG[notification]="/config/system/notification cronapt mdadm monit smartmontools"
CONFIG[powermanagement]="/config/system/powermanagement cpufrequtils cron systemd-logind"
CONFIG[monitoring]="/config/system/monitoring collectd monit rrdcached"
CONFIG[crontab]="/config/system/crontab cron"
CONFIG[certificates]="/config/system/certificates certificates"
CONFIG[apt]="/config/system/apt"
CONFIG[dns]="/config/system/network/dns avahi hostname hosts postfix samba systemd-networkd"
CONFIG[interfaces]="/config/system/network/interfaces avahi halt hosts issue systemd-networkd"
CONFIG[proxy]="/config/system/network/proxy apt profile"
CONFIG[iptables]="/config/system/network/iptables iptables"
CONFIG[hdparm]="/config/system/storage/hdparm hdparm"
CONFIG[smart]="/config/services/smart smartmontools"
CONFIG[fstab]="/config/system/fstab initramfs mdadm collectd fstab monit quota"
CONFIG[shares]="/config/system/shares sharedfolders systemd"
CONFIG[nfs]="/config/services/nfs avahi collectd fstab monit nfs quota"
CONFIG[rsync]="/config/services/rsync rsync avahi rsyncd"
CONFIG[smb]="/config/services/smb avahi samba"
CONFIG[ssh]="/config/services/ssh ssh avahi"
CONFIG[homedirectory]="/config/system/usermanagement/homedirectory samba"
CONFIG[users]="/config/system/usermanagement/users postfix rsync rsyncd samba systemd ssh"
CONFIG[groups]="/config/system/usermanagement/groups rsync rsyncd samba sharedfolders systemd"
CONFIG[syslog]="/config/system/syslog rsyslog"

# Complementos
CONFIG[openmediavault-omvextras]="/config/system/omvextras"
CONFIG[openmediavault-anacron]="/config/services/anacron anacron"
CONFIG[openmediavault-apttool]="/config/services/apttool"
CONFIG[openmediavault-autoshutdown]="/config/services/autoshutdown autoshutdown"
CONFIG[openmediavault-backup]="/config/system/backup cron"
CONFIG[openmediavault-borgbackup]="/config/services/borgbackup borgbackup"
CONFIG[openmediavault-clamav]="/config/services/clamav clamav"
CONFIG[openmediavault-compose]="/config/services/compose compose"
CONFIG[openmediavault-cputemp]="nulo"
CONFIG[openmediavault-diskstats]="nulo"
CONFIG[openmediavault-downloader]="/config/services/downloader"
CONFIG[openmediavault-fail2ban]="/config/services/fail2ban fail2ban"
CONFIG[openmediavault-filebrowser]="/config/services/filebrowser avahi filebrowser"
CONFIG[openmediavault-flashmemory]="nulo"
CONFIG[openmediavault-forkeddaapd]="/config/services/daap forked-daapd monit"
CONFIG[openmediavault-ftp]="/config/services/ftp avahi monit proftpd"
CONFIG[openmediavault-kernel]="nulo"
CONFIG[openmediavault-kvm]="/config/services/kvm"
CONFIG[openmediavault-locate]="nulo"
CONFIG[openmediavault-luksencryption]="nulo luks"
CONFIG[openmediavault-lvm2]="nulo collectd fstab monit quota"
CONFIG[openmediavault-mergerfs]="/config/services/mergerfs collectd fstab mergerfs monit quota"
CONFIG[openmediavault-minidlna]="/config/services/minidlna minidlna"
CONFIG[openmediavault-nut]="/config/services/nut collectd monit nut"
CONFIG[openmediavault-onedrive]="/config/services/onedrive onedrive"
CONFIG[openmediavault-owntone]="/config/services/owntone owntone"
CONFIG[openmediavault-photoprism]="/config/services/photoprism avahi photoprism"
CONFIG[openmediavault-remotemount]="/config/services/remotemount collectd fstab monit quota remotemount"
CONFIG[openmediavault-resetperms]="/config/services/resetperms"
CONFIG[openmediavault-rsnapshot]="/config/services/rsnapshot rsnapshot"
CONFIG[openmediavault-s3]="/config/services/minio avahi minio"
CONFIG[openmediavault-sftp]="/config/services/sftp sftp fstab"
CONFIG[openmediavault-shairport]="/config/services/shairport monit shairport-sync"
CONFIG[openmediavault-sharerootfs]="nulo"
CONFIG[openmediavault-snapraid]="/config/services/snapraid snapraid"
CONFIG[openmediavault-snmp]="/config/services/snmp snmpd"
CONFIG[openmediavault-symlinks]="/config/services/symlinks"
CONFIG[openmediavault-tftp]="/config/services/tftp avahi tftpd-hpa"
CONFIG[openmediavault-tgt]="/config/services/tgt tgt"
CONFIG[openmediavault-usbbackup]="/config/services/usbbackup usbbackup"
CONFIG[openmediavault-wakealarm]="/config/system/wakealarm wakealarm"
CONFIG[openmediavault-wetty]="/config/services/wetty avahi wetty"
CONFIG[openmediavault-wireguard]="/config/services/wireguard wireguard"
CONFIG[openmediavault-wol]="/Config/services/wol"
CONFIG[openmediavault-zfs]="nulo zfszed collectd fstab monit quota nfs samba sharedfolders systemd tftpd-hpa"

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export LANG=C.UTF-8
export LANGUAGE=C
export LC_ALL=C.UTF-8
# Nota: Evita que los cuadros de diálogo fallen
export NCURSES_NO_UTF8_ACS=1

######################################### TEXTOS DE AYUDA ##############################################

txt AyudaComoUsar \
"\n \
\n          COMO USAR OMV-REGEN 2 \
\n \
\n    omv-regen sirve para regenerar las configuraciones de un sistema openmediavault en una instalación nueva de OMV. El procedimiento resumido es: \
\n \
\n          PASO 1. Crea un backup del sistema original con omv-regen. \
\n          PASO 2. Haz una instalación nueva de OMV en el disco que quieras y conecta las unidades de datos. \
\n          PASO 3. Utiliza omv-regen para clonar las configuraciones desde el backup en el nuevo sistema. \
\n \
\n    Se podría decir que es una restauración pero decir regeneración es más exacto puesto que se está generando un sistema nuevo. Se reinstala todo el software y se aplican las configuraciones del sistema original. Entrando en detalles, las condiciones para que esto funcione son las siguientes: \
\n
\n          - Es muy recomendable usar un disco de sistema diferente del original, no es necesario que sea el mismo. \
\n          - Todos los demás discos deben estar conectados en el momento de hacer la regeneración. \
\n          - Las versiones de OMV y de los complementos deben coincidir en ambos sistemas, original y nuevo. \
\n     Como consecuencia del punto anterior: \
\n          - El sistema original debe estar actualizado cuando hagas el backup, no esperes un día para regenerar. \
\n          - Si se publica alguna actualización de un complemento importante durante el proceso podría detenerse. \
\n          - Si se da el caso anterior omv-regen decidirá si se puede omitir o no la instalación de ese complemento. \
\n          - Ese es el motivo principal por el que es recomendable usar un disco de sistema nuevo y conservar el original. \
\n     El resultado será el siguiente: \
\n          - Todo lo que está respaldado por la base de datos de OMV se habrá recreado en el sistema nuevo. \
\n          - Esto incluye docker y contenedores configurados con el complemento compose. Funcionarán como antes. \
\n          - Incluye todas las configuraciones que hayas hecho en la GUI de OMV, usuarios y contraseñas, sistemas de archivos, etc. \
\n          - NO incluye cualquier configuración realizada en CLI fuera de OMV. Usa otros medios para respaldar eso. \
\n          - NO incluye contenedores configurados en Portainer. Deberás recrearlos tu mismo. \
\n          - Los complementos Filebrowser y Photoprism son contenedores podman. No se respaldarán, usa otros medios." \
"\n \
\n          HOW TO USE OMV-REGEN 2 \
\n \
\n    omv-regen is used to regenerate the configurations of an openmediavault system in a new OMV installation. The summarized procedure is: \
\n \
\n          STEP 1. Create a backup of the original system with omv-regen. \
\n          STEP 2. Do a fresh installation of OMV on the disk you want and connect the data drives. \
\n          STEP 3. Use omv-regen to clone the configurations from the backup to the new system. \
\n \
\n    You could say that it is a restoration but saying regeneration is more accurate since a new system is being generated. All software is reinstalled and the original system settings are applied. Going into details, the conditions for this to work are the following: \
\n
\n          - It is highly recommended to use a different system disk than the original, it does not have to be the same one. \
\n          - All other disks must be connected at the time of regeneration. \
\n          - OMV and plugin versions must match on both the original and new systems. \
\n     As a consequence of the previous point: \
\n          - The original system must be updated when you make the backup, do not wait a day to regenerate. \
\n          - If an important plugin update is released during the process it could stop. \
\n          - If the above case occurs, omv-regen will decide whether or not the installation of that plugin can be skipped. \
\n          - That is the main reason why it is advisable to use a new system disk and keep the original one. \
\n     The result will be the following: \
\n          - Everything that is backed up by the OMV database will have been recreated on the new system. \
\n          - This includes docker and containers configured with the compose plugin. They will work as before. \
\n          - Includes all the configurations you have made in the OMV GUI, users and passwords, file systems, etc. \
\n          - DOES NOT include any configuration done in CLI outside of OMV. Use other means to support that. \
\n          - DOES NOT include containers configured in Portainer. You will have to recreate them yourself. \
\n          - Filebrowser and Photoprism plugins are podman containers. They will not support each other, use other means."

txt AyudaFunciones \
"\n \
\n          FUNCIONES DE OMV-REGEN 2 \
\n \
\n  1 - ${AzulD}omv-regen${ResetD} - Proporciona acceso a los menús de configuración y ejecución de cualquier función de omv-regen. Desde aquí podrás configurar fácilmente los parámetros para hacer un backup o una regeneración y podrás ejecutar ambos. También podrás gestionar las actualizaciones de omv-regen. \
\n
\n  2 - ${AzulD}omv-regen backup${ResetD} - Realiza un backup muy ligero de los datos esenciales para regenerar las configuraciones de un sistema OMV. Puedes incluir carpetas opcionales, incluso de tus discos de datos, y definir el destino. Ejecuta omv-regen en línea de comando y la interfaz te guiará para configurar los parámetros y guardarlos. Después puedes ejecutar el backup desde los menús o desde CLI con el comando: [ omv-regen backup ] Puedes configurar una tarea programada en la GUI de OMV que ejecute el comando [ omv-regen backup ] y gestionarlo desde allí. \
\n \
\n  3 - ${AzulD}omv-regen regenera${ResetD} - Regenera un sistema completo OMV con sus configuraciones originales a partir de una instalación nueva de OMV y el backup del sistema original realizado con omv-regen backup. Ejecuta omv-regen en línea de comando y la interfaz te guiará para configurar los parámetros y ejecutar la regeneración. Después puedes ejecutarla desde el menú o desde CLI con el comando: omv-regen regenera \
\n \
\n  4 - ${AzulD}omv-regen ayuda${ResetD} - Acceso a los cuadros de diálogo con la ayuda completa de omv-regen." \
"\n \
\n          OMV-REGEN 2.0 FEATURES \
\n \
\n  1 - ${AzulD}omv-regen${ResetD} - Provides access to the configuration menus and execution of any omv-regen function. From here you can easily configure the parameters to make a backup or a regeneration and you can execute both. You will also be able to manage omv-regen updates. \
\n
\n  2 - ${AzulD}omv-regen backup${ResetD} - Performs a very light backup of essential data to regenerate the configurations of an OMV system. You can include optional folders, even from your data disks, and define the destination. Run omv-regen on the command line and the interface will guide you to configure the parameters and save them. You can then run the backup from the menus or from the CLI with the command: [ omv-regen backup ] You can configure a scheduled task in the OMV GUI that runs the command [ omv-regen backup ] and manage it from there. \
\n \
\n  3 - ${AzulD}omv-regen regenera${ResetD} - Regenerates a complete OMV system with its original configurations from a fresh OMV installation and the backup of the original system made with omv-regen backup. Run omv-regen on the command line and the interface will guide you to configure the parameters and run the regeneration. Then you can run it from the menu or from CLI with the command: omv-regen regenera \
\n \
\n  4 - ${AzulD}omv-regen ayuda${ResetD} - Access to dialogs with full omv-regen help."

txt AyudaProcedimiento \
"\n \
\n          PROCEDIMIENTO DE REGENERACION \
\n \
\n    ${AzulD}- INSTALA OMV-REGEN EN EL SISTEMA ORIGINAL Y HAZ UN BACKUP.${ResetD}    Configura un backup en el menú y asegúrate de marcar la opción para actualizar el sistema antes del backup. Se creará un archivo muy ligero empaquetado con tar que incluye todos los archivos e información necesaria para realizar la regeneración. Opcionalmente puedes incluir carpetas personalizadas en el backup. Si lo haces se creará un archivo tar por cada carpeta que selecciones además del archivo anterior. Los archivos de cada backup están etiquetados en el nombre con fecha y hora. Guarda ese backup en alguna parte. WinSCP es una herramienta útil para esto, puedes copiar ese archivo fácilmente a tu escritorio, es un archivo muy pequeño y moverlo es instantáneo. Si configuraste carpetas opcionales copia el resto de archivos también. \
\n    ${AzulD}- HAZ UNA INSTALACIÓN NUEVA DE OPENMEDIAVAULT, NO ESPERES.${ResetD}    No es posible regenerar si las versiones de los complementos disponibles en internet y las que tenía instalados el sistema original son distintas, esto podría crear conflictos en la base de datos y romper el sistema. Aún cabe la posibilidad de que algún paquete reciba una nueva versión antes de que regeneres. Si ocurre esto omv-regen lo detectará, en ese momento optará por omitir la instalación de ese complemento si es posible, o, si es un complemento que no se puede omitir (como zfs o mergerfs...) se detendrá la regeneración y tendrás que empezar de nuevo. Por lo tanto usa una unidad distinta de la original para instalar OMV y conserva la original, de ese modo siempre puedes volver y hacer un nuevo backup actualizado. Recuerda que puedes instalar openmediavault en un pendrive. Cuando hayas acabado la instalación de OMV no configures nada. Apaga el sistema, conecta los mismos discos de datos que tenía el sistema original e inicia el servidor. \
\n    ${AzulD}- COPIA EL BACKUP AL NUEVO OMV, INSTALA OMV-REGEN Y CONFIGURA LA REGENERACION.${ResetD}    Crea una carpeta en el disco de sistema y copia el backup en ella. Puedes usar WinSCP o similar para hacer esto por SSH. Instala omv-regen en el nuevo sistema e inícialo para configurar la regeneración en el menú. Los menús te guiarán para configurar la ubicación del backup y otras opciones. Puedes decidir no regenerar la interfaz de red o no instalar el kernel proxmox si estaba instalado en el servidor original. Una vez configurado todo, si los ajustes son válidos te permitirá iniciar la regeneración. En caso contrario te dirá qué es lo que debes cambiar. \
\n    ${AzulD}- INICIA LA REGENERACION.${ResetD}    Se instalarán todos los complementos que tenías en el sistema original y a medida que se van instalando se va regenerando al mismo tiempo la base de datos con tus configuraciones originales. Si el proceso necesita un reinicio te pedirá que lo hagas tú, después debes ejecutar omv-regen de nuevo y el proceso continuará desde el punto correcto. omv-regen registra el estado de la regeneración, de modo que continuará automáticamente sin hacer nada mas. Si tienes algún corte de luz o similar puedes iniciar el servidor y ejecutar de nuevo omv-regen. Continuará en el punto donde estaba y terminará la regeneración. La duración dependerá de la cantidad de complementos y la velocidad del servidor. Para un caso medio no debería durar mas de 10 o 15 minutos o incluso menos. \
\n    ${AzulD}- FINALIZACIÓN.${ResetD}    Cuando finalice el proceso te avisará en pantalla y se reiniciará automáticamente. Antes de empezar la regeneración, el menú te dirá cual va a ser la IP del servidor después de la regeneración, puedes anotarla. Al final también saldrá en pantalla pero podrías no verla si no estás atento. Espera a que se reinicie y accede a esa IP. Dependiendo de la configuración de tu red esto podría no ser exacto, en ese caso tendrás que averiguar la IP en tu router o conectándote al servidor con pantalla y teclado. Después del reinicio tendrás el sistema con una instalación limpia y la GUI de OMV configurada exactamente como tenías el sistema original. \
\n \
\n    ${AzulD}¡¡¡¡    RECUERDA BORRAR LA CACHE DE TU NAVEGADOR --> CTRL+MAYS+R    !!!!${ResetD}" \
"\n \
\n          REGENERATION PROCEDURE \
\n \
\n    ${AzulD}- INSTALL OMV-REGEN ON THE ORIGINAL SYSTEM AND MAKE A BACKUP.${ResetD}    Set up a backup in the menu and make sure to check the option to update the system before backup. A very lightweight tar packaged archive will be created that includes all the files and information needed to perform the regeneration. You can optionally include custom folders in the backup. If you do this, a tar file will be created for each folder you select in addition to the previous file. The files in each backup are labeled in name with date and time. Save that backup somewhere. WinSCP is a useful tool for this, you can easily copy that file to your desktop, it is a very small file and moving it is instant. If you configured optional folders, copy the rest of the files as well. \
\n    ${AzulD}- DO A NEW INSTALLATION OF OPENMEDIAVAULT, DON'T WAIT.${ResetD}    It is not possible to regenerate if the versions of the plugins available on the internet and those installed on the original system are different, this could create conflicts in the database and break the system. There is still a chance that some package will receive a new version before you regenerate. If this happens omv-regen will detect it, at which point it will choose to skip installing that plugin if possible, or, if it is a plugin that cannot be bypassed (like zfs or mergerfs...) it will stop regeneration and you will have to start again. Therefore use a different drive than the original one to install OMV and keep the original one, that way you can always go back and make a new updated backup. Remember that you can install openmediavault on a pendrive. When you have finished installing OMV, do not configure anything. Shut down the system, connect the same data disks that the original system had, and start the server. \
\n    ${AzulD}- COPY THE BACKUP TO THE NEW OMV, INSTALL OMV-REGEN AND CONFIGURE THE REGENERATION.${ResetD}    Create a folder on the system disk and copy the backup to it. You can use WinSCP or similar to do this over SSH. Install omv-regen on the new system and boot it to configure regeneration in the menu. The menus will guide you to configure the backup location and other options. You can decide not to regenerate the network interface or not to install the proxmox kernel if it was installed on the original server. Once everything is configured, if the settings are valid it will allow you to start the regeneration. Otherwise it will tell you what you should change. \
\n    ${AzulD}- REGENERATION BEGINS.${ResetD}    All the plugins that you had in the original system will be installed and as they are installed, the database will be regenerated at the same time with your original configurations. If the process needs a restart it will ask you to do it, then you must run omv-regen again and the process will continue from the correct point. omv-regen records the status of the regeneration, so it will continue automatically without doing anything else. If you have a power outage or similar, you can start the server and run omv-regen again. It will continue where it was and the regeneration will end. The duration will depend on the number of plugins and the speed of the server. For an average case it should not last more than 10 or 15 minutes or even less. \
\n    ${AzulD}- COMPLETION.${ResetD}    When the process is finished, it will notify you on the screen and it will restart automatically. Before starting the regeneration, the menu will tell you what the server's IP will be after the regeneration, you can write it down. In the end it will also appear on the screen but you might not see it if you are not paying attention. Wait for it to reboot and access that IP. Depending on your network configuration this may not be exact, in which case you will have to find out the IP on your router or by connecting to the server with a screen and keyboard. After the reboot you will have the system with a clean installation and the OMV GUI configured exactly as you had the original system. \
\n \
\n    ${AzulD}REMEMBER TO CLEAR YOUR BROWSER'S CACHE --> CTRL+SHIFT+R    !!!!${ResetD}"

txt AyudaConsejos \
"\n \
\n          ALGUNOS CONSEJOS \
\n \
\n    ${AzulD}- CARPETAS OPCIONALES:${ResetD}    Si eliges carpetas opcionales asegúrate de que no son carpetas de sistema. O, si lo son, al menos asegúrate de que no dañarán el sistema cuando se copien al disco de OMV. Sería una lástima romper el sistema por esto una vez regenerado. \
\n \
\n    ${AzulD}- COMPLEMENTOS FILEBROWSER Y PHOTOPRISM:${ResetD}    Si utilizas los complementos Filebrowser o Photoprism debes buscar medios alternativos para respaldarlos. Son contenedores podman y omv-regen no los respaldará. omv-regen los instalará y regenerará las configuraciones de la base de datos de OMV, esto incluye las configuraciones de la GUI de OMV, carpeta compartida, puerto de acceso al complemento, etc. Pero las configuraciones internas de los dos contenedores se perderán. Tal vez sea suficiente con incluir la carpeta donde reside la base de datos del contenedor para que omv-regen también la restaure. Esto no garantiza nada, solo es una sugerencia no probada. \
\n \
\n    ${AzulD}- OPENMEDIAVAULT-APTTOOL:${ResetD}    Si tienes algún paquete instalado manualmente, por ejemplo lm-sensors, y quieres que también se instale al mismo tiempo puedes usar el complemento apttool. omv-regen instalará los paquetes que se hayan instalado mediante este complemento. \
\n \
\n    ${AzulD}- OPENMEDIAVAULT-SYMLINK:${ResetD}    De la misma forma que en el caso anterior, si usas symlinks en tu sistema omv-regen los recreará si se generaron con el complemento. Si lo hiciste de forma manual tendrás que volver a hacerlo. \
\n \
\n    ${AzulD}- INTENTA HACER LA REGENERACION LO ANTES POSIBLE:${ResetD}    omv-regen omitirá, si es posible, la instalación de algún complemento si la versión disponible en internet para instalar no coincide con la versión que tenía instalada el servidor original. Esto se podrá hacer siempre que ese complemento no esté relacionado con el sistema de archivos, como pueden ser, mergerfs, zfs o similar, en tal caso la regeneración se detendrá y no podrás continuar. Si esto sucede tendrás que hacer un nuevo backup del sistema original actualizándolo previamente. Para evitar esto NO te demores en hacer la regeneración una vez hayas realizado el backup. omv-regen no te puede avisar antes de empezar a regenerar pues sin omv-extras instalado faltan los repositorios en el sistema para consultar versiones de la mayoría de los complementos. \
\n
\n    ${AzulD}- UNIDAD DE SISTEMA DIFERENTE:${ResetD}    Por el mismo motivo explicado en el punto anterior es muy recomendable utilizar una unidad de sistema diferente a la original para regenerar. Es muy sencillo usar un pendrive para instalar openmediavault. Si tienes la mala suerte de que se publique una actualización de un paquete esencial entre elmomento del backup y el momento de la regeneración no podrás terminarla, y necesitarás el sistema original para hacer un nuevo backup actualizado. \
\n \
\n    ${AzulD}- CONTENEDORES DOCKER:${ResetD}    Toda la información que hay en el disco de sistema original va a desaparecer. Para conservar los contenedores docker en el mismo estado asegurate de hacer algunas cosas antes. Cambia la ruta de instalación por defecto de docker desde la carpeta /var/lib/docker a una carpeta en alguno de los discos de datos. Configura todos los volumenes de los contenedores fuera del disco de sistema, en alguno de los discos de datos. Estas son recomendaciones generales, pero en este caso con mas motivo, si no lo haces perderás esos datos. Alternativamente puedes añadir la carpeta /var/lib/docker al backup como carpeta opcional." \
"\n \
\n          SOME ADVICES \
\n \
\n    ${AzulD}- OPTIONAL FOLDERS:${ResetD}    If you choose optional folders make sure they are not system folders. Or, if they are, at least make sure they won't harm your system when copied to the OMV disk. It would be a shame to break the system for this once regenerated. \
\n \
\n    ${AzulD}- FILEBROWSER AND PHOTOPRISM PLUGINS:${ResetD}    If you use the Filebrowser or Photoprism plugins you should find alternative means to back them up. They are podman containers and omv-regen will not support them. omv-regen will install them and regenerate the OMV database configurations, this includes the OMV GUI configurations, shared folder, plugin access port, etc. But the internal configurations of the two containers will be lost. It may be enough to include the folder where the container database resides so that omv-regen will restore it as well. This does not guarantee anything, it is just an untested suggestion. \
\n \
\n    ${AzulD}- OPENMEDIAVAULT-APTTOOL:${ResetD}    If you have a package installed manually, for example lm-sensors, and you want it to also be installed at the same time you can use the apttool plugin. omv-regen will install packages that have been installed using this plugin. \
\n \
\n    ${AzulD}- OPENMEDIAVAULT-SYMLINK:${ResetD}    In the same way as in the previous case, if you use symlinks in your system omv-regen will recreate them if they were generated with the plugin. If you did it manually you will have to do it again. \
\n \
\n    ${AzulD}- TRY TO DO THE REGENERATION AS SOON AS POSSIBLE:${ResetD}    omv-regen will skip, if possible, the installation of any plugin if the version available on the Internet to install does not match the version that the original server had installed. This can be done as long as this plugin is not related to the file system, such as mergerfs, zfs or similar, in which case the regeneration will stop and you will not be able to continue. If this happens you will have to make a new backup of the original system, updating it previously. To avoid this, DO NOT delay doing the regeneration once you have made the backup. omv-regen cannot notify you before starting to regenerate because without omv-extras installed there are no repositories in the system to consult versions of most of the plugins. \
\n \
\n    ${AzulD}- DIFFERENT SYSTEM UNIT:${ResetD}    For the same reason explained in the previous point, it is highly recommended to use a different system unit than the original one to regenerate. It is very easy to use a pendrive to install openmediavault. If you are unlucky enough that an update to an essential package is released between the time of the backup and the time of the rebuild, you will not be able to finish it, and you will need the original system to make a new updated backup. \
\n \
\n    ${AzulD}- DOCKER CONTAINERS:${ResetD}    All the information on the original system disk will disappear. To keep your docker containers in the same state make sure you do a few things first. Change the default docker installation path from the /var/lib/docker folder to a folder on one of the data disks. Configure all container volumes off the system disk, on one of the data disks. These are general recommendations, but in this case even more so, if you don't do it you will lose that data. Alternatively you can add the /var/lib/docker folder to the backup as an optional folder."

txt AyudaBackup \
"\n \
\n          OPCIONES DE OMV-REGEN BACKUP 2 \
\n \
\n    ${AzulD}- RUTA DE LA CARPETA DE BACKUPS:${ResetD}    Esta carpeta se usará para almacenar todos los backups generados. Por defecto esta carpeta es /ORBackup, puedes usar la que quieras pero no uses los discos de datos si pretendes hacer una regeneración, no serán accesibles. Para hacer una regeneración es mejor copiar el backup directamente a tu escritorio con WinSCP o similar y luego copiarla al sistema nuevo. En esta carpeta omv-regen creará un archivo empaquetado con tar para cada backup, etiquetado con la fecha y la hora en el nombre. Si has incluido carpetas opcionales en el backup se crearán archivos adicionales también empaquetados con tar y con la etiqueta user1, user2,... Un backup completo con dos carpetas opcionales hecho el día 1 de octubre de 2023 a las 10:38 a.m. podría tener este aspecto: \
\n         ${AzulD}ORB_231001_103828_regen.tar.gz${ResetD}    <-- Archivo con la información de regenera \
\n         ${AzulD}ORB_231001_103828_user1.tar.gz${ResetD}    <-- Archivo con la carpeta opcional 1 de usuario \
\n         ${AzulD}ORB_231001_103828_user2.tar.gz${ResetD}    <-- Archivo con la carpeta opcional 2 de usuario \
\n    Las subcarpetas tienen el prefijo ORB_ en su nombre. Si quieres conservar alguna versión de backup en particular y que omv-regen no la elimine puedes editar este prefijo a cualquier otra cosa y no se eliminará esa subcarpeta. Puedes utilizar omv-regen para programar backups con tareas programadas en la GUI de OMV. Se aplicará la configuración guardada. \
\n \
\n    ${AzulD}- DIAS QUE SE CONSERVAN LOS BACKUPS:${ResetD}    Esta opción establece el número de días máximo para conservar backups. Cada vez que hagas un backup se eliminarán todos aquellos existentes en la misma ruta con mas antigüedad de la configurada, mediante el escaneo de fechas de todos los archivos con el prefijo ORB_ Se establece un valor en días. El valor por defecto son 7 días. \
\n \
\n    ${AzulD}- ACTUALIZAR EL SISTEMA:${ResetD}    Esta opción hará que el sistema se actualice automáticamente justo antes de realizar el backup. Asegúrate que esté activa si tu intención es hacer un backup para proceder a una regeneración inmediatamente después. Desactívala si estás haciendo backups programados. El valor establecido debe ser Si/on o No/off. \
\n \
\n    ${AzulD}- CARPETAS ADICIONALES:${ResetD}    Puedes definir tantas carpetas opcionales como quieras que se incluirán en el backup. Útil si tienes información que quieres transferir al nuevo sistema que vas a regenerar. Si copias carpetas con configuraciones del sistema podrías romperlo. Estas carpetas se devolverán a su ubicación original en la parte final del proceso de regeneración. Se crea un archivo tar comprimido para cada carpeta etiquetado de la misma forma que el resto del backup. Puedes incluir carpetas que estén ubicadas en los discos de datos. Puesto que la restauración de estas carpetas se hace al final del proceso, en ese momento todos los sistemas de archivos ya están montados y funcionando." \
"\n \
\n          OMV-REGEN BACKUP 2 OPTIONS \
\n \
\n    ${AzulD}- BACKUP FOLDER PATH:${ResetD}    This folder will be used to store all the backups generated. By default this folder is /ORBackup, you can use whatever you want but do not use the data disks if you intend to do a regeneration, they will not be accessible. To do a regeneration it is better to copy the backup directly to your desktop with WinSCP or similar and then copy it to the new system. In this folder omv-regen will create a tar-packaged archive for each backup, labeled with the date and time in the name. If you have included optional folders in the backup, additional files will be created, also packaged with tar and labeled user1, user2,... A complete backup with two optional folders done on October 1, 2023 at 10:38 a.m. could look like this: \
\n         ${AzulD}ORB_231001_103828_regen.tar.gz${ResetD}    <-- File with regenera information \
\n         ${AzulD}ORB_231001_103828_user1.tar.gz${ResetD}    <-- File with optional user folder 1 \
\n         ${AzulD}ORB_231001_103828_user2.tar.gz${ResetD}    <-- File with optional user folder 2 \
\n    Subfolders have the ORB_ prefix in their name. If you want to keep a particular backup version and not have omv-regen delete it, you can edit this prefix to anything else and that subfolder will not be deleted. You can use omv-regen to schedule backups with scheduled tasks in the OMV GUI. The saved settings will be applied. \
\n
\n    ${AzulD}- DAYS BACKUPS ARE KEPT:${ResetD}    This option establishes the maximum number of days to keep backups. Every time you make a backup, all those existing in the same path that are older than the configured one will be eliminated, by scanning the files of all the files with the ORB_ prefix. A value is established in days. The default value is 7 days. \
\n \
\n    ${AzulD}- UPDATE SYSTEM:${ResetD}  This option will cause the system to update automatically just before performing the backup. Make sure it is active if your intention is to make a backup to proceed with a regeneration immediately afterwards. Disable it if you are doing scheduled backups. The set value must be Yes/on or No/off. \
\n \
\n    ${AzulD}- ADDITIONAL FOLDERS:${ResetD}    You can define as many optional folders as you want that will be included in the backup. Useful if you have information that you want to transfer to the new system that you are going to regenerate. If you copy folders with system settings you could break it. These folders will be returned to their original location in the final part of the regeneration process. A compressed tar file is created for each folder labeled the same as the rest of the backup. You can include folders that are located on the data disks. Since the restoration of these folders is done at the end of the process, at that point all file systems are already mounted and working."

txt AyudaRegenera \
"\n \
\n          OPCIONES DE OMV-REGEN REGENERA 2 \
\n
\n    ${AzulD}- RUTA BACKUP DE ORIGEN:${ResetD}    En el menú debes definir la ubicación de esta carpeta. Por defecto será /ORBackup pero puedes elegir la ubicación que quieras. Esta carpeta debe contener al menos un archivo tar generado con omv-regen. Antes de ejecutar una regeneración el programa comprobará que esta carpeta contiene todos los archivos necesarios para la regeneración. Cuando definas una ruta en el menú omv-regen escaneará los archivos de esa ruta y buscará el backup mas reciente. Una vez localizado el backup, omv-regen comprobará que en su interior están todos los archivos necesarios. Si falta algún archivo la ruta no se dará por válida y no se permitirá continuar adelante. \
\n
\n    ${AzulD}- INSTALAR KERNEL PROXMOX:${ResetD}    Si el sistema original tenía el kernel proxmox instalado tendrás la opción de decidir si quieres instalarlo también en el sistema nuevo o no. Cuando la regeneración esté en funcionamiento, si esta opción está activada se instalará el kernel a mitad de proceso. En ese momento omv-regen te pedirá que reinicies el sistema. Después de eso debes ejecutar de nuevo omv-regen y la regeneración continuará en el punto en que se detuvo. Ten en cuenta que si tienes un sistema de archivos ZFS o usas kvm es recomendable tener este kernel instalado, en caso contrario podrías tener problemas durante la instalación de estos dos complementos. Si desactivas esta opción el kernel proxmox no se instalará en el sistema nuevo. \
\n
\n    ${AzulD}- REGENERAR LA INTERFAZ DE RED:${ResetD}    Esta opción sirve para omitir la regeneración de la interfaz de red. Si desactivas esta opción no se regenerará la interfaz de red y la IP seguirá siendo la misma que tiene el sistema después del reinicio al final del proceso. Si activas esta opción se regenerará la interfaz de red al final del proceso de regeneración. Si la IP original es distinta de la IP actual deberás conectarte a la IP original después del reinicio para acceder a OMV. El menú te indica cual será esta IP antes de iniciar la regeneración. Cuando finalice la regeneración también la tendrás en pantalla pero podrías no verla si no estás atento." \
"\n \
\n          OMV-REGEN REGENERA 2 OPTIONS \
\n \
\n    ${AzulD}- SOURCE BACKUP PATH:${ResetD}    In the menu you must define the location of this folder. By default it will be /ORBackup but you can choose the location you want. This folder must contain at least one tar file generated with omv-regen. Before executing a regeneration, the program will check that this folder contains all the files necessary for the regeneration. When you define a path in the menu omv-regen will scan the files in that path and look for the most recent backup. Once the backup is located, omv-regen will check that all the necessary files are inside. If any file is missing, the route will not be considered valid and you will not be allowed to continue further. \
\n \
\n    ${AzulD}- INSTALL PROXMOX KERNEL:${ResetD}    If the original system had the proxmox kernel installed you will have the option to decide if you want to also install it on the new system or not. When regeneration is running, if this option is enabled it will install the kernel mid-process. At that point omv-regen will ask you to reboot the system. After that you have to run omv-regen again and the regeneration will continue from the point where it stopped. Keep in mind that if you have a ZFS file system or use kvm it is recommended to have this kernel installed, otherwise you could have problems installing these two plugins. If you disable this option the proxmox kernel will not be installed on the new system. \
\n \
\n    ${AzulD}- REGENERATE THE NETWORK INTERFACE:${ResetD}    This option is used to skip regenerating the network interface. If you deactivate this option, the network interface will not be regenerated and the IP will remain the same as the system's after the reboot at the end of the process. If you activate this option, the network interface will be regenerated at the end of the regeneration process. If the original IP is different from the current IP you will need to connect to the original IP after the reboot to access OMV. The menu tells you what this IP will be before starting the regeneration. When the regeneration ends you will also have it on the screen but you may not see it if you are not attentive."

declare -a AYUDA=("${txt[AyudaComoUsar]}" "${txt[AyudaFunciones]}" "${txt[AyudaProcedimiento]}" "${txt[AyudaConsejos]}" "${txt[AyudaBackup]}" "${txt[AyudaRegenera]}")

Ayuda () {
  i=0
  while [ "${AYUDA[i]}" ]; do
    dialog \
      --backtitle "omv-regen ${ORVersion} ${txt[Ayuda]}" \
      --title "omv-regen ${ORVersion} ${txt[Ayuda]}" \
      --ok-label "${txt[Siguiente]}" \
      --cancel-label "${txt[Salir]}" \
      --extra-button \
      --extra-label "${txt[Anterior]}" \
      --colors \
      --yesno "${AYUDA[i]}\n " 0 0
    case $? in
      0)
        ((i++))
        ;;
      1|255)
        i=1000
        ;;
      3)
        ((i--))
        ;;
    esac
  done
}

########################################## MENUS #################################################

# MENU BACKUP
MenuBackup () {
  while [ "${Camino}" = "MenuBackup" ]; do
    ValidarBackup
    [ "${ValidarBackup}" ] && txt 3 "\n\n\n    ${RojoD}ESTOS AJUSTES NO SON VALIDOS. DEBES MODIFICARLOS.${ResetD}" "\n\n\n    ${RojoD}THESE SETTINGS ARE INVALID. YOU MUST MODIFY THEM.${ResetD}" || txt 3 "\n\n\n    ESTOS AJUSTES SON VALIDOS.\n\n\n    Pulsa ejecutar para hacer un backup ahora o programa\n    una tarea en la GUI de OMV con el comando ${AzulD}omv-regen backup${ResetD}" "\n\n\n    THESE SETTINGS ARE VALID.\n\n\n    Press run to make a backup now or schedule\n    a task in the OMV GUI with the command ${AzulD}omv-regen backup${ResetD}"
    [ "${ValBacRuta}" ] && txt 4 "\n       ${RojoD}**** Esta ruta no existe.${ResetD}" "\n       ${RojoD}**** This path does not exist.${ResetD}" || txt 4 "" ""
    [ "${ValDias}" ] && txt 5 "\n       ${RojoD}**** Este valor debe ser un número.${ResetD}" "\n       ${RojoD}**** This value must be a number.${ResetD}" || txt 5 "" ""
    [ "${ORA[Actualizar]}" = "${txt[Ajustar]}" ] && txt 6 "\n       ${RojoD}**** Este valor debe ser Si o No.${ResetD}" "\n       ${RojoD}**** This value must be Yes or No.${ResetD}" || txt 6 "" ""
    [ "${ORA[Actualizar]}" = "No" ] && txt 9 "\n       **** Si el backup es para regenerar asegúrate de actualizar antes.\n       **** Deshabilita esta opción solo para backups programados." "\n       **** If the backup is to regenerate, make sure to update before.\n       **** Disable this option only for scheduled backups." || txt 9 "" ""
    Texto=""; cont=0
    for i in "${CARPETAS[@]}"; do
      if [ "$i" ];then
        ((cont++))
        Texto="${Texto}\n    ${AzulD}${txt[Carpeta]} $cont  ==> $i${ResetD}"
      fi
    done
    txt 8 "\n       **** No se han incluido carpetas opcionales." "\n       **** No optional folders have been included."
    [ ! "${Texto}" ] && txt 8 "\n       **** No se han incluido carpetas opcionales." "\n       **** No optional folders have been included." || txt 8 "" ""
    [ "${ValCarpetas}" ] && txt 7 "\n       ${RojoD}****${ResetD} Hay al menos una carpeta incluida que no existe." "\n       ${RojoD}****${ResetD} There is at least one folder included that does not exist." || txt 7 "" ""
    txt 1 "Ejecuta Backup" "Run Backup"
    txt 2 "\n\n    AJUSTES ACTUALES ESTABLECIDOS EN BACKUP\n\n \
      \nRuta a la carpeta para almacenar el backup del sistema original. \
      \n    ${AzulD}${txt[Ruta]} ==> ${ORA[RutaBackup]}${ResetD}${txt[4]} \n \
      \nDías de antigüedad que se conservan los backups. \
      \n    ${AzulD}${txt[Dias]} ==> ${ORA[Dias]}${ResetD}${txt[5]} \n \
      \nActualizar el sistema antes de la ejecución del backup. \
      \n    ${AzulD}${txt[Actualizar]} ==> ${ORA[Actualizar]}${ResetD}${txt[6]}${txt[9]} \n \
      \nCarpetas adicionales que se incluirán en el backup. \
      ${Texto}${txt[7]}${txt[8]} \n \
      ${txt[3]} \n\n " \
      "\n\n    CURRENT SETTINGS ESTABLISHED IN BACKUP:\n\n\n \
      \nPath to the folder to store the original system backup. \
      \n    ${AzulD}${txt[Ruta]} ==> ${ORA[RutaBackup]}${ResetD}${txt[4]} \n \
      \nHow many days old the backups are kept. \
      \n    ${AzulD}${txt[Dias]} ==> ${ORA[Dias]}${ResetD}${txt[5]} \n \
      \nUpdate the system before running the backup. \
      \n    ${AzulD}${txt[Actualizar]} ==> ${ORA[Actualizar]}${ResetD}${txt[6]}${txt[9]} \n \
      \nAdditional folders to be included in the backup. \
      ${Texto}${txt[7]}${txt[8]} \n \
      ${txt[3]} \n\n "
    dialog \
      --backtitle "omv-regen backup ${ORVersion}" \
      --title "${txt[1]}" \
      --ok-label "${txt[Ejecutar]}" \
      --cancel-label "${txt[Volver]}" \
      --extra-button \
      --extra-label "${txt[Modificar]}" \
      --help-button \
      --help-label "${txt[Ayuda]}"\
      --colors \
      --yesno "${txt[2]}" 0 0
    Respuesta=$?
    case ${Respuesta} in
      0)
        ValidarBackup
        if [ "${ValidarBackup}" ]; then
          Info 3 "Los ajustes actuales no son válidos. Debes ajustarlos." "The current settings are invalid. You must adjust them."
          Camino="BackupAjustes"
        else
          Camino="EjecutarBackup"
        fi
        ;;
      1|255)
        Camino="MenuPrincipal"
        ;;
      2)
        Ayuda
        ;;
      3)
        Camino="BackupAjustes"
        ;;
    esac
  done
}

# MENU DE AJUSTES DE BACKUP
BackupAjustes () {

  # Ruta Backup
  Ruta="${ORA[RutaBackup]}"
  while [ "${Camino}" = "BackupAjustes" ]; do
    txt 1 "Escribe la ruta de destino de los backups" "Write the backup destination path"
    ORA[RutaBackup]=$(dialog \
      --backtitle "omv-regen backup ${ORVersion}" \
      --title "${txt[1]}" \
      --ok-label "${txt[Continuar]}" \
      --cancel-label "${txt[Cancelar]}" \
      --stdout \
      --dselect "${ORA[RutaBackup]}" ${Alto} ${Ancho})
    Salida=$?
    case $Salida in
      0)
        ValidarBackup
        if [ "${ValBacRuta}" ]; then
          Pregunta "La carpeta de destino del backup ${ORA[RutaBackup]} no existe.\n\n¿Quieres crearla?" "The ${ORA[RutaBackup]} backup destination folder does not exist.\n\nDo you want to create it?"
          if [ ! "${Pregunta}" ]; then
            mkdir -p "${ORA[RutaBackup]}"
            if [ ! -d "${ORA[RutaBackup]}" ]; then
              Mensaje "No se ha podido crear la carpeta ${ORA[RutaBackup]}" "Could not create ${ORA[RutaBackup]} folder"
            else
              Info 3 "Se ha creado la carpeta ${ORA[RutaBackup]}" "The folder ${ORA[RutaBackup]} has been created"
            fi
          fi
        fi
        ValidarBackup
        if [ ! "${ValBacRuta}" ]; then
          if [ "${ValRutaEsc}" ]; then
            Mensaje "No se puede escribir en la ruta establecida para el backup." "Cannot write to the path established for the backup."
          else
            GuardarAjustes
            Camino="BackupAjustes2"
          fi
        fi
        ;;
      1|255)
        ORA[RutaBackup]="${Ruta}"
        Camino="MenuBackup"
    esac
  done

  # Opciones Backup
  while [ "${Camino}" = "BackupAjustes2" ]; do
    txt 1 "Opciones de Backup" "Backup options"
    txt 2 "Configura las siguientes opciones para Backup:" "Set the following options for Backup:     "
    txt 3 "Número de días que se guardan los backups:    " "Number of days that backups are kept:     "
    txt 4 "Actualizar el sistema antes del backup (S/N): " "Update the system before backup (Y/N):    "
    Respuesta=$(dialog \
      --backtitle "omv-regen backup ${ORVersion}" \
      --title "${txt[1]}" \
      --ok-label "${txt[Continuar]}" \
      --cancel-label "${txt[Cancelar]}" \
      --help-button \
      --help-label "${txt[Ayuda]}"\
      --separate-widget $"\n" \
      --form  "\n${txt[2]}\n " 20 ${Ancho} 0 \
      "${txt[3]}"   1 1 "${ORA[Dias]}"   1 50 20 0 \
      "${txt[4]}"   2 1 "${ORA[Actualizar]}"   2 50 20 0 3>&1 1>&2 2>&3 3>&-)
    Salida=$?
    case $Salida in
      0) 
        ORA[Dias]=$(echo "$Respuesta" | sed -n 1p)
        ORA[Actualizar]=$(echo "$Respuesta" | sed -n 2p)
        ValidarBackup
        if [ "${ValidarBackup}" ]; then
          [ "${Valdias}" ] && txt 1 "\nEl valor para los días debe ser un número." "\nThe value for days must be a number." || txt 1 ""
          [ ! "${ORA[Actualizar]}" ] && txt 2 "\nEl valor para Actualizar debe ser Si o No." "\nThe value for Update must be Yes or No." || txt 2 ""
          Info 3 "Estos ajustes no son válidos.${txt[1]}${txt[2]}" "These settings are not valid.${txt[1]}${txt[2]}"
        else
          GuardarAjustes
          Camino="BackupAjustes3"
        fi
        ;;
      1)
        Camino="MenuBackup"
        ;;
      2)
        Ayuda
        ;;
    esac
  done

  # Carpetas adicionales Backup
  if [ "${Camino}" = "BackupAjustes3" ]; then
    unset RUTAS
    cont=0
    for i in "${CARPETAS[@]}"; do
      AñadirCarpeta "$i"
      if [ "${Camino}" = "BackupAjustes3" ]; then
        if [ "${Ruta}" ]; then
          RUTAS[cont]="${Ruta}"
          ((cont++))
        else
          Info 3 "La carpeta $i no se incluirá en el backup." "The $i folder will not be included in the backup."
        fi
      fi
    done
  fi
  if [ "${Camino}" = "BackupAjustes3" ]; then
    Ruta="x"
    while [ "${Ruta}" ]; do
      AñadirCarpeta extra
      if [ "${Ruta}" ]; then
        RUTAS[cont]="${Ruta}"
        ((cont++))
      fi
    done
  fi
  if [ "${Camino}" = "MenuBackup" ]; then
    Info 3 "Operación cancelada." "Operation cancelled."
  else
    unset CARPETAS
    cont=0
    for i in "${RUTAS[@]}"; do
      CARPETAS[cont]=$i
      ((cont++))
    done
    GuardarAjustes
    Info 3 "La configuración de Backup se ha guardado." "The Backup configuration has been saved."
    Camino="MenuBackup"
  fi
}

# MENU AÑADIR CARPETA OPCIONAL A BACKUP 
AñadirCarpeta () {
  Carpeta=$1
  txt 1 "Ruta de carpeta adicional a incluir en el backup" "Additional folder path to include in the backup"
  [ "${Carpeta}" = "extra" ] && txt 2 "/ Pulsa CONTINUAR para terminar (o déjalo en blanco)." "/ Press CONTINUE to finish (or leave it blank)." || txt 2 "${Carpeta}"
  [ "${Carpeta}" = "extra" ] && txt 3 "Salir" "Exit" || txt 3 "Quitar" "Remove"
  Ruta=$(dialog \
    --backtitle "omv-regen backup ${ORVersion}" \
    --title "${txt[1]}" \
    --ok-label "${txt[Continuar]}" \
    --cancel-label "${txt[3]}" \
    --stdout \
    --dselect "${txt[2]}" ${Alto} ${Ancho})
  Salida=$?
  case $Salida in
    0)
      if [ "${Carpeta}" = "extra" ] && [ "${Ruta}" = "${txt[2]}" ]; then
        Ruta=""
      fi
      if [ "${Ruta}" ] && [ ! -d "${Ruta}" ]; then
        Info 3 "La carpeta ${Ruta} incluida en el backup no existe." "The ${Ruta} folder included in the backup does not exist."
      fi
      if [ "${Ruta}" = "/" ]; then
        Info 3 "No se puede incluir rootfs en el backup." "You cannot include rootfs in the backup."
        Ruta=""
      fi
      ;;
    1)
      Ruta=""
      ;;
    255)
      Camino="MenuBackup"
      ;;
  esac
}

# MENU REGENERA
MenuRegenera () {
  while [ "${Camino}" = "MenuRegenera" ]; do
    ValidarRegenera
    [ "${ValidarRegenera}" ] && txt 3 "AJUSTES ACTUALES ESTABLECIDOS EN REGENERA: ==> ${RojoD}HAY ALGO QUE NO ES CORRECTO.${ResetD}" "CURRENT SETTINGS ESTABLISHED IN REGENERA: ==> ${RojoD}THERE IS SOMETHING THAT IS NOT CORRECT.${ResetD}" || txt 3 "AJUSTES ACTUALES ESTABLECIDOS EN REGENERA: ==> TODAS LAS CONFIGURACIONES SON CORRECTAS." "CURRENT SETTINGS ESTABLISHED IN REGENERA: ==> ALL CONFIGURATIONS ARE CORRECT."
    txt 4 "\n\nRuta a la carpeta del backup con los datos del sistema original." "\n\nPath to the backup folder with the original system data."
    [ "${ValRegRuta}" ] && txt 41 "\n       ${RojoD}****NO HAY NINGÚN BACKUP EN ESTA RUTA.${ResetD}" "\n       ${RojoD}****THERE IS NO BACKUP ON THIS PATH.${ResetD}" || txt 41 "\n       **** El backup mas reciente en esta ruta es ${TarRegen}" "\n       **** The most recent backup on this path is ${TarRegen}"
    [ "${ValFechaBackup}" ] && txt 42 "\n       ${RojoD}**** LA FECHA ${FechaBackup} NO COINCIDE CON LA REGENERACIÓN EN CURSO.${ResetD}" "\n       ${RojoD}**** THE DATE ${FechaBackup} DOES NOT COINCIDE WITH THE REGENERATION IN PROGRESS.${ResetD}" || txt 42 ""
    [ "${ValRegCont}" ] && txt 43 "\n       ${RojoD}**** EL CONTENIDO DEL BACKUP DE FECHA ${FechaBackup} NO ESTÁ COMPLETO.${ResetD}" "\n       ${RojoD}**** THE CONTENT OF THE BACKUP DATED ${FechaBackup} IS NOT COMPLETE.${ResetD}" || txt 43 ""
    [ "${KernelOR}" ] && txt 44 "\n       **** El sistema original tenía instalado el Kernel Proxmox ${KernelOR}" "\n       **** The original system had the Proxmox Kernel ${KernelOR} installed." || txt 44 "\n       **** El sistema original no tenía instalado ningún Kernel Proxmox." "\n       **** The original system did not have any Proxmox Kernel installed."
    [ "${IpOR}" ] && txt 45 "\n       **** La IP del sistema original es ${IpOR}" "\n       **** The IP of the original system is ${IpOR}" || txt 45 ""
    [ "${TarUserNumero}" ] && txt 46 "\n       **** En este backup hay ${TarUserNumero} carpetas opcionales que también se restaurarán." "\n       **** In this backup there are ${TarUserNumero} optional folders that will also be restored." || txt 46 "\n       **** En este backup no hay carpetas opcionales para restaurar." "\n       **** In this backup there are no optional folders to restore."
    txt 5 "\n\nRegenerar interfaz de red al finalizar la regeneración." "\n\nRegenerate network interface upon completion of regeneration."
    if [ "${ORA[Red]}" = "on" ]; then
      txt 51 "${txt[Si]}"
      if [ "${ValRegRuta}" ]; then
        txt 52 "" ""; txt 53 "" ""
      else
        txt 52 "\n       **** IP original = ${IpOR}\n       **** IP Actual   = ${IpAC}" "\n       **** Original IP = ${IpOR}\n       **** Current IP  = ${IpAC}"
        [ "${IpAC}" = "${IpOR}" ] && txt 53 "\n       **** Con estos ajustes la IP seguirá siendo la misma después de regenerar." "\n       **** With these settings the IP will remain the same after regenerating." || txt 53 "\n       **** Perderás la conexión cuando finalice el proceso.\n       **** La nueva IP después de regenerar será ${RojoD}${IpOR}${ResetD}" "\n       **** You will lose the connection when the process ends.\n       **** The new IP after regenerating will be ${RojoD}${IpOR}${ResetD}"
      fi
    else
      txt 51 "No"; txt 52 "" ""; txt 53 "" ""
    fi
    if [ "${KernelOR}" ]; then
      txt 6 "\n\nInstalar el mismo kernel proxmox que el sistema original.\n    ${AzulD}Kernel  ==> ${ResetD}" "\n\nInstall the same proxmox kernel as the original system.\n    ${AzulD}Kernel  ==> ${ResetD}"
      if [ "${ORA[Kernel]}" = "on" ]; then
        txt 61 "${AzulD}${txt[Si]}${ResetD}"
        txt 62 "\n       **** La regeneración se detendrá después instalar el kernel.\n            Será necesario ${RojoD}reiniciar y ejecutar omv-regen${ResetD} de nuevo.\n            El proceso continuará automáticamente cuando ejecutes de nuevo omv-regen." "\n       **** Regeneration will stop after installing the kernel.\n            It will be necessary to ${RojoD}restart and run omv-regen${ResetD} again.\n            The process will continue automatically when you run omv-regen again."
      else
        txt 61 "${AzulD}No${ResetD}"; txt 62 "" ""
      fi
    else
      txt 6 "" ""; txt 61 "" ""; txt 62 "" ""
    fi
    txt 7 "\n\nComprobación de números de serie de discos de datos conectados:" "\n\nChecking serial numbers of connected data disks:"
    [ ! "${DiscosOR}" ] && txt 73 "No se ha podido leer." "It could not be read." || txt 73 "${DiscosOR}"
    [ ! "${DiscosAC}" ] && txt 74 "No se ha podido leer." "It could not be read." || txt 74 "${DiscosAC}"
    txt 71 "\n    ${AzulD}Discos conectados sistema original ==> ${txt[73]}\n    Discos conectados sistema actual   ==> ${txt[74]}${ResetD}" "\n    ${AzulD}Disks connected original system ==> ${txt[73]}\n    Disks connected current system  ==> ${txt[74]}${ResetD}"
    if [ "${ValRegDiscos}" = "ilegible" ]; then
      txt 72 "\n       ${RojoD}**** NO SE HA PODIDO LEER LA INFORMACION DE LAS UNIDADES DE DATOS.\n            ASEGURATE DE QUE ESTÁN TODAS CONECTADAS.${ResetD}" "\n       ${RojoD}**** THE INFORMATION FROM THE DATA UNITS COULD NOT BE READ.\n            MAKE SURE THEY ARE ALL CONNECTED.${ResetD}"
    elif [ "${ValRegDiscos}" = "si" ]; then
      txt 72 "\n       ${RojoD}**** NO ESTÁN CONECTADAS TODAS LAS UNIDADES DE DATOS DEL SISTEMA ORIGINAL.${ResetD}" "\n       ${RojoD}**** NOT ALL DATA UNITS OF THE ORIGINAL SYSTEM ARE CONNECTED.${ResetD}"
    else
      txt 72 "\n       **** Las unidades de datos originales y actuales coinciden. Es correcto." "\n       **** The original and current data units match. It's right."
    fi
    txt 8 "\n\nComprobación de números de serie de disco de sistema, rootfs:" "\n\nChecking system disk serial numbers, rootfs:"
    [ ! "${RootfsOR}" ] && txt 83 "No se ha podido leer." "It could not be read." || txt 83 "${RootfsOR}"
    [ ! "${RootfsAC}" ] && txt 84 "No se ha podido leer." "It could not be read." || txt 84 "${RootfsAC}"
    txt 81 "\n    ${AzulD}Disco de sistema original ==> ${txt[83]}\n    Disco de sistema actual   ==> ${txt[84]}${ResetD}" "\n    ${AzulD}Original system disk ==> ${txt[83]}\n    Current system disk  ==> ${txt[84]}${ResetD}"
    if [ "${ValRegRootfs}" = "ilegible" ]; then
      txt 82 "\n       ${RojoD}**** NO SE HA PODIDO LEER LA INFORMACION DE LA UNIDAD DE SISTEMA.\n            ASEGURATE DE QUE ESTÁS USANDO UNA UNIDAD DIFERENTE. CONSULTA LA AYUDA.${ResetD}" "\n       ${RojoD}**** THE INFORMATION FROM THE SYSTEM UNIT COULD NOT BE READ.\n            MAKE SURE YOU ARE USING A DIFFERENT UNIT. CONSULT THE HELP.${ResetD}"
    elif [ "${ValRegRootfs}" = "si" ]; then
      txt 82 "\n       ${RojoD}**** LA UNIDAD DE SISTEMA ACTUAL ES LA MISMA QUE TENIA EL SISTEMA ORIGINAL\n            DEBERÍAS USAR UN UNIDAD DISTINTA Y CONSERVAR LA ORIGINAL. CONSULTA LA AYUDA.\n            RECUERDA QUE PUEDES INSTALAR OPENMEDIAVAULT EN UN PENDRIVE.${ResetD}" "\n       ${RojoD}**** THE CURRENT SYSTEM UNIT IS THE SAME THAT THE ORIGINAL SYSTEM HAD\n            YOU SHOULD USE A DIFFERENT UNIT AND KEEP THE ORIGINAL. CONSULT THE HELP.\n            REMEMBER THAT YOU CAN INSTALL OPENMEDIAVAULT ON A PENDRIVE.${ResetD}"
    else
      txt 82 "\n       **** La unidad de sistema actual y la original son diferentes. Correcto." "\n       **** The current and original system unit are different. It's right."
    fi
    txt 9 "\n\nComprobación de estado del sistema actual:" "\n\nCurrent system status check:"
    [ "${ValDpkg}" ] && txt 91 "\n       ${RojoD}**** ESTE SISTEMA YA ESTÁ CONFIGURADO.\n            PARA REGENERAR DEBES HACER ANTES UNA INSTALACION LIMPIA DE OPENMEDIAVAULT.${ResetD}" "\n       ${RojoD}**** THIS SYSTEM IS ALREADY CONFIGURED.\n            TO REGENERATE YOU MUST FIRST DO A CLEAN INSTALLATION OF OPENMEDIAVAULT.${ResetD}" || txt 91 "\n       **** El sistema actual no está configurado. Correcto." "\n       **** The current system is not configured. It's right."
    if [ "${ValidarRegenera}" ]; then
      txt 11 "${txt[Modificar]}"; txt 12 "${txt[Volver]}"; txt 13 "${txt[Ayuda]}"
    else
      txt 11 "${txt[Ejecutar]}"; txt 12 "${txt[Modificar]}"; txt 13 "${txt[Volver]}"
    fi
    if [ "${ValRegRuta}" ]; then
      txt 6 ""; txt 61 ""; txt 62 ""; txt 7 ""; txt 44 ""; txt 46 ""; txt 71 ""; txt 72 ""; txt 8 ""; txt 81 ""; txt 82 ""
    fi
    txt 1 "Ejecuta Regenera" "Run Regenera"
    txt 2 "\n    ${txt[3]}\n \
      ${txt[4]} \
      \n    ${AzulD}${txt[Ruta]}  ==> ${ORA[RutaOrigen]}${ResetD} \
      ${txt[41]}${txt[42]}${txt[43]}${txt[44]}${txt[45]}${txt[46]} \
      ${txt[5]} \
      \n    ${AzulD}${txt[Red]}  ==> ${txt[51]}${ResetD} \
      ${txt[52]}${txt[53]} \
      ${txt[6]}${txt[61]}${txt[62]} \
      ${txt[7]}${txt[71]}${txt[72]} \
      ${txt[8]}${txt[81]}${txt[82]} \
      ${txt[9]}${txt[91]} \n\n "
    dialog \
      --backtitle "omv-regen regenera ${ORVersion}" \
      --title "${txt[1]}" \
      --ok-label "${txt[11]}" \
      --extra-button \
      --extra-label "${txt[12]}" \
      --cancel-label "${txt[13]}" \
      --colors \
      --yesno "${txt[2]}" 0 0
    Respuesta=$?
    case ${Respuesta} in
      0)
        [ "${ValidarRegenera}" ] && Camino="RegeneraAjustes" || Camino="EjecutarRegenera"
        ;;
      3)
        [ "${ValidarRegenera}" ] && Camino="MenuPrincipal" || Camino="RegeneraAjustes"
        ;;
      1)
        if [ "${ValidarRegenera}" ]; then
          Ayuda
        else
          Camino="MenuPrincipal"
        fi
        ;;
      255)
        Camino="MenuPrincipal"
        ;;
    esac
  done
}

# MENU DE AJUSTES REGENERA
RegeneraAjustes () {
  while [ "${Camino}" = "RegeneraAjustes" ]; do
    txt 1 "Escribe la ruta del backup del sistema original" "Write the original system backup path"
    Ruta=$(dialog \
      --backtitle "omv-regen regenera ${ORVersion}" \
      --title "${txt[1]}" \
      --ok-label "${txt[Continuar]}" \
      --cancel-label "${txt[Cancelar]}" \
      --stdout \
      --dselect "${ORA[RutaOrigen]}" ${Alto} ${Ancho})
    Salida=$?
    case $Salida in
      0)
        ORA[RutaOrigen]="${Ruta}"
        ValidarRegenera
        if [ "${ValRegRuta}" ]; then
          Info 3 "La ruta seleccionada no contiene un backup omv-regen válido." "The selected path does not contain a valid omv-regen backup."
        else
          Camino="RegeneraAjustes2"
          GuardarAjustes
        fi
        ;;
      1|255)
        Camino="MenuRegenera"
        ;;
    esac
  done
  if [ "${Camino}" = "RegeneraAjustes2" ]; then
    txt 1 "Opciones de Regenera" "Regenera options"
    txt 2 "Configura las siguientes opciones para omv-regen regenera:" "Set the following options for omv-regen regenera:"
    txt 3 "Instalar kernel proxmox si ya estaba en el sistema original." "Install proxmox kernel if it was already on the original system."
    txt 4 "Regenerar interfaz de red." "Regenerate network interface."
    Respuesta=$(dialog \
      --backtitle "omv-regen regenera ${ORVersion}" \
      --title "${txt[1]}" \
      --ok-label "${txt[Continuar]}" \
      --cancel-label "${txt[Cancelar]}" \
      --separate-output \
      --stdout \
      --checklist  "\n${txt[2]}\n " 0 0 3 \
      Kernel             "${txt[3]}" "${ORA[Kernel]}" \
      "${txt[Red]}"      "${txt[4]}" "${ORA[Red]}")
    Salida=$?
    case $Salida in
      0)
        if [ "$(echo "$Respuesta" | grep Kernel)" ]; then
          ORA[Kernel]="on"
        else
          ORA[Kernel]="off"
        fi
        if [ "$(echo "$Respuesta" | grep "${txt[Red]}")" ]; then
          ORA[Red]="on"
        else
          ORA[Red]="off"
        fi
        GuardarAjustes
        Info 3 "La configuración de Regenera se ha guardado." "The Regenera configuration has been saved."
        ;;
      1|255)
        Info 3 "Operación cancelada." "Operation cancelled."
        ;;
    esac
  fi
  Camino="MenuRegenera"
}

# MENU DE OPCIONES DE ACTUALIZACION DE OMV-REGEN
OpcionesActualizacion () {
  txt 1 "Opciones de Actualización" "Update options"
  txt 2 "Buscar actualizaciones al iniciar omv-regen. " "Check for updates when starting omv-regen."
  txt 3 "Actualizar automáticamente.                  " "Update automatically."
  txt 4 "Actualizar ahora.                            " "Update now."
  Respuesta=$(dialog \
    --backtitle "omv-regen ${ORVersion}" \
    --title "${txt[1]}" \
    --ok-label "${txt[Continuar]}" \
    --cancel-label "${txt[Cancelar]}" \
    --separate-output \
    --stdout \
    --checklist  "\n " 0 0 3 \
    "${txt[Buscar]}"  "${txt[2]}" "${ORA[Buscar]}" \
    "${txt[Siempre]}" "${txt[3]}" "${ORA[Siempre]}" \
    "${txt[Ahora]}"   "${txt[4]}" off )
  Salida=$?
  case $Salida in
    0)
      ORA[Buscar]=$(echo "$Respuesta" | grep "${txt[Buscar]}"); [ "${ORA[Buscar]}" ] && ORA[Buscar]="on" || ORA[Buscar]="off"
      ORA[Siempre]=$(echo "$Respuesta" | grep "${txt[Siempre]}"); [ "${ORA[Siempre]}" ] && ORA[Siempre]="on" || ORA[Siempre]="off"
      [ "${ORA[Siempre]}" = "on" ] && ORA[Buscar]="on"
      Ahora=$(echo "$Respuesta" | grep "${txt[Ahora]}")
      GuardarAjustes
      if [ "${Ahora}" ]; then
        BuscarOR
        Info 3 "No hay versiones nuevas de omv-regen disponibles." "There are no new versions of omv-regen available."
      fi
      ;;
    1|255)
      Info 3 "Operación cancelada. No se han guardado los cambios." "Operation cancelled. Changes have not been saved."
      ;;
  esac
  Camino="MenuPrincipal"
}

################################### FUNCIONES #######################################

# Validar ajustes de Backup.
# Devuelve ValidarBackup="" si todo es correcto y ValidarBackup="si" si no es correcto.
# Sale si se ha entrado desde CLI y los ajustes no son correctos.
ValidarBackup () {
  ValidarBackup=""; ValBacRuta=""; ValRutaEsc="" ValDias=""; ValCarpetas=""
  # Comprueba si existe la ruta para el backup
  if [ ! "${ORA[RutaBackup]}" = "/ORBackup" ]; then
    if [ ! -d "${ORA[RutaBackup]}" ]; then
      ValBacRuta="si"; ValidarBackup="si"
    else
      touch "${ORA[RutaBackup]}"/pruebaescritura
      if [ ! -f "${ORA[RutaBackup]}/pruebaescritura" ]; then
        ValRutaEsc="si"; ValidarBackup="si"
      else
        rm "${ORA[RutaBackup]}"/pruebaescritura
      fi
    fi
  fi
  # Comprueba rutas de Carpetas opcionales
  for i in "${CARPETAS[@]}"; do
    if [ ! -d "$i" ]; then
      ValCarpetas="si"
    fi
  done
  # Comprueba formatos de valores
  if [[ "${ORA[Dias]}" =~ ^[0-9]+$ ]]; then
    ValDias=""
  else
    ValDias="si"; ValidarBackup="si"
  fi
  SiNo "${ORA[Actualizar]}"
  ORA[Actualizar]="${SiNo}"
  [ ! "${ORA[Actualizar]}" ] && ValidarBackup="si"
  # Salida CLI
  if [ "${ValidarBackup}" ] && [ "${Cli}" ]; then
    Salir "${Rojo}Los ajustes establecidos no son válidos${Reset}. Ejecuta ${Verde}omv-regen${Reset} sin argumentos para modificarlos.\nSaliendo..." "${Rojo}The established settings are not valid${Reset}. Run ${Verde}omv-regen${Reset} with no arguments to adjust them.\nExiting..."
  fi
}

# Validar ajustes de Regenera.
# Devuelve ValidarRegenera="" si todo es correcto y ValidarRegenera="si" si falla.
ValidarRegenera () {
  ValidarRegenera=""; ValRegRuta=""; ValFechaBackup=""; TarRegen=""; ValDpkg=""; ValRegCont=""; ValRegDiscos=""; ValRegRootfs=""; IpOR=""; IpAC=""; KernelOR=""; FechaBackup=""; TarUserNumero=""; Discos=""; Dev=""; RootfsAC=""; RootfsOR=""; DiscosAC=""; DiscosOR=""; Serial=""; DpkgAC=""

  # Validar Ruta de Backup de origen

  TarRegen="$(find "${ORA[RutaOrigen]}" -name 'ORB_*_regen.tar.gz' | sort -r | awk -F "/" 'NR==1{print $NF}')"
  if [ "${TarRegen}" = "" ]; then
    ValidarRegenera="si"; ValRegRuta="si"
  else
    # Comprobar si el backup contiene todos los archivos
    for i in "${ORB[@]}"; do
      if [ "$(tar -tzvf "${ORA[RutaOrigen]}/${TarRegen}" | grep "$i")" = "" ]; then
        ValidarRegenera="si"; ValRegCont="si"
      fi
    done
    for i in "${ARCHIVOS[@]}"; do
      if [ "$(tar -tzvf "${ORA[RutaOrigen]}/${TarRegen}" | grep "$i")" = "" ]; then
        ValidarRegenera="si"; ValRegCont="si"
      fi
    done
    # Comprobar si hay carpetas opcionales en el backup
    FechaBackup="$(echo "${TarRegen}" | awk -F "_" 'NR==1{print $2"_"$3}')"
    TarUserNumero="$(find "${ORA[RutaOrigen]}" -name "ORB_${FechaBackup}"'_user*.tar.gz' | awk 'END {print NR}')"
    [ "${TarUserNumero}" = 0 ] && TarUserNumero=""
    # Comprobar si el sistema original tenía kernel proxmox
    tar -C /tmp -xvf "${ORA[RutaOrigen]}/${TarRegen}" "regen_${FechaBackup}/ORB_Unamea" >/dev/null
    KernelOR=$(awk '{print $3}' "/tmp/regen_${FechaBackup}/${ORB[Unamea]}" | awk -F "." '/pve$/ {print $1"."$2}')
    # Comprobar si están conectados los discos del sistema original
    tar -C /tmp -xvf "${ORA[RutaOrigen]}/${TarRegen}" "regen_${FechaBackup}/ORB_Rootfs" >/dev/null
    tar -C /tmp -xvf "${ORA[RutaOrigen]}/${TarRegen}" "regen_${FechaBackup}/ORB_Lsblk" >/dev/null
    Discos="$(lsblk --nodeps -o name,serial)"
    Dev="$(df "${Configxml}" | awk '/^\/dev/ {print $1}' | awk -F "/" '{print $3}')"
    if [ "${Dev}" = "root" ]; then
      Dev="$(mount | grep ' / ' | cut -d' ' -f 1 | awk -F "/" '{print $3}')"
      Dev="${Dev:0:7}"
    else
      Dev="${Dev:0:3}"
    fi
    RootfsAC="$(echo "${Discos}" | awk -v a="${Dev}" '{ if($1 == a) print $2}')"
    Serial="$(echo "${Discos}" | awk -v a="${Dev}" '{ if($1 != a) print $2}')"
    DiscosAC="$(echo "${Serial}" | awk '{ if($1 != "SERIAL") print}')"
    RootfsOR="$(cat "/tmp/regen_${FechaBackup}/${ORB[Rootfs]}")"
    DiscosOR="$(cat "/tmp/regen_${FechaBackup}/${ORB[Lsblk]}")"
    if [ ! "${RootfsOR}" ] || [ ! "${RootfsAC}" ]; then
      ValRegRootfs="ilegible"
    elif [ "${RootfsOR}" = "${RootfsAC}" ]; then
      ValRegRootfs="si"
    fi
    if [ ! "${DiscosOR}" ] || [ ! "${DiscosAC}" ]; then
      ValRegDiscos="ilegible"
    elif [ ! "${DiscosOR}" = "${DiscosAC}" ]; then
      ValRegDiscos="si"
    fi
    # Comprobar valores de red
    tar -C /tmp -xvf "${ORA[RutaOrigen]}/${TarRegen}" "regen_${FechaBackup}/ORB_HostnameI" >/dev/null
    IpAC=$(hostname -I | awk '{print $1}')
    IpOR=$(awk '{print $1}' "/tmp/regen_${FechaBackup}/${ORB[HostnameI]}")
    # Limpiar tmp
    rm -rf "/tmp/regen_${FechaBackup}"
  fi
  if [ ! "${FASE[1]}" = "iniciar" ] && [ ! "${ORA[FechaBackup]}" = "${FechaBackup}" ]; then
    ValidarRegenera="si"; ValFechaBackup="si"
  fi
  # Comprobar sistema actual
  if [ "${FASE[1]}" = "iniciar" ]; then
    DpkgAC=$(dpkg -l | grep openmediavault | awk '{print $2}')
    if [ "$(echo "${DpkgAC}" | awk 'NR==1{print $1}')" = "openmediavault" ] && [ "$(echo "${DpkgAC}" | awk 'NR==2{print $1}')" = "openmediavault-keyring" ] && [ "$(echo "${DpkgAC}" | awk 'NR==3{print $1}')" = "" ]; then
      ValDpkg=""
    elif [ "$(echo "${DpkgAC}" | awk 'NR==1{print $1}')" = "openmediavault" ] && [ "$(echo "${DpkgAC}" | awk 'NR==2{print $1}')" = "openmediavault-flashmemory" ] && [ "$(echo "${DpkgAC}" | awk 'NR==3{print $1}')" = "openmediavault-keyring" ] && [ "$(echo "${DpkgAC}" | awk 'NR==4{print $1}')" = "openmediavault-omvextrasorg" ] && [ "$(echo "${DpkgAC}" | awk 'NR==5{print $1}')" = "" ]; then
      ValDpkg=""
    else
      ValDpkg="si"; ValidarRegenera="si"
    fi
  fi
  # Comprobar formatos
  SiNo "${ORA[Kernel]}"
  [ ! "${SiNo}" ] && ValidarRegenera="si"
  SiNo "${ORA[Red]}"
  [ ! "${SiNo}" ] && ValidarRegenera="si"
}

# Comprueba si un valor es si/on o no/off 
SiNo () {
  SiNo=""
  case $1 in
    s|S|si|Si|SI|y|Y|yes|Yes|YES|on)
      SiNo="${txt[Si]}"
    ;;
    n|N|no|No|NO|off)
      SiNo="No"
    ;;
  esac
}

# Escribir ajustes actuales en disco
GuardarAjustes () {
  [ -f "${ORTemp}" ] && rm -f "${ORTemp}"
  touch "${ORTemp}"
  for i in "${!ORA[@]}"; do
    echo "$i : ${ORA[$i]}" >> "${ORTemp}"
  done
  for i in "${!CARPETAS[@]}"; do
    echo "Carpeta : ${CARPETAS[$i]}" >> "${ORTemp}"
  done
  for i in "${!FASE[@]}"; do
    if [ ! "$i" = 0 ]; then
      echo "FASE$i : ${FASE[$i]}" >> "${ORTemp}"
    fi
  done
  cp -ap "${ORTemp}" "${ORAjustes}"
  rm -f "${ORTemp}"
}

# Buscar nueva versión de omv-regen y actualizar si existe.
BuscarOR () {
  clear
  txt 1 "Buscando actualizaciones de omv-regen..." "Checking for omv-regen updates..."
  txt 2 "No se ha podido descargar el archivo." "The file could not be downloaded."
  echoe "${txt[1]}"
  [ -f "${ORTemp}" ] && rm -f "${ORTemp}"
  wget -O - "${URLomvregen}" > "${ORTemp}"
  if [ ! -f "${ORTemp}" ]; then
    echoe "${txt[2]}"; Info 3 "${txt[1]}\n${txt[2]}"
  else
    VersionDI="$(awk -F "regen " 'NR==8{print $2}' "${ORTemp}")"
    if [ "${ORVersion}" = "${VersionDI}" ]; then
      ORA[ActualizacionPendiente]=""
    else
      ORA[ActualizacionPendiente]="si"
      if [ "${ORA[Siempre]}" = "on" ]; then
        Ahora="si"
      elif [ ! "${Ahora}" ]; then
        Abortar 10 "Hay una nueva versión de omv-regen.\nNO está configurada la actualización automática.\nNO se va a actualizar" "There is a new version of omv-regen.\nAutomatic update is NOT configured.\nIt is NOT going to be updated"
        if [ "${Abortar}" ]; then
          Pregunta "¿Quieres actualizar ahora?" "Do you want to update now?"
          [ ! "${Pregunta}" ] && Ahora="si"
        fi
      fi
      if [ "${Ahora}" ]; then
        cat "${ORTemp}" > "${Omvregen}"
        rm -f "${ORTemp}"
        ORA[ActualizacionPendiente]=""
        GuardarAjustes
        Salir "Se ha actualizado omv-regen ${ORVersion} a la version ${VersionDI}\nEs necesario iniciarlo de nuevo. Saliendo..." "Updated omv-regen ${ORVersion} to version ${VersionDI}\nIt is necessary to start it again. Exiting..."
      fi
    fi
    GuardarAjustes
    rm -f "${ORTemp}"
  fi
  [ "${Camino}" = "Salir" ] && exit
}

# Funciones omv
. /usr/share/openmediavault/scripts/helper-functions

# Muestra el mensaje en español o inglés según el sistema.
echoe () {
  [ "$Sp" ] && echo -e "$1" || echo -e "$2"
}

# Parada del programa hasta que se pulse una tecla.
Continuar () {
  if [ ! "${Cli}" ]; then
    echoe "\nPULSA CUALQUIER TECLA PARA CONTINUAR\n" "\nPRESS ANY KEY TO CONTINUE\n"
    until read -t10 -n1 -r -p ""; do
	    sleep 0
    done
  fi
}

# Mostrar mensaje y salir. Si $1=ayuda sale con ayuda.
Salir () {
  if [ "$1" = "ayuda" ]; then
    [ "$Sp" ] && echo -e "$2" || echo -e "$3"
    [ "$Sp" ] && echo -e  "\n\n\n${Verde}>>>  >>>   omv-regen ${ORVersion}   <<<  <<<\n\nomv-regen          ==> para acceder al menú\nomv-regen backup   ==> para ejecutar un backup\nomv-regen regenera ==> para ejecutar una regeneración\nomv-regen ayuda    ==> para ver la ayuda${Reset}\n\n" || echo -e "\n\n\n${Verde}>>>  >>>   omv-regen ${ORVersion}   <<<  <<<\n\nomv-regen          ==> to access the menu\nomv-regen backup   ==> to run a backup\nomv-regen regenera ==> to run a regeneration\nomv-regen help     ==> to see the help${Reset}\n\n"
  else
    [ "$Sp" ] && echo -e "$1" || echo -e "$2"
  fi
  exit
}

# Mensaje con tiempo de espera y posibilidad de abortar
# $1=segundos de espera. $2 y $3 texto. $4 y $5 texto opcional mensaje si se aborta.
# Si se ha abortado devuelve Abortar="si"
Abortar () {
  Abortar=""
  txt 1 "$2" "$3"
  txt 2 "Se ha abortado la operación." "The operation has been aborted."
  txt 3 "$4" "$5"
  dialog --backtitle "omv-regen ${ORVersion}" \
         --title "omv-regen ${ORVersion}" \
         --ok-label "${txt[Continuar]}" \
         --cancel-label "${txt[Abortar]}" \
         --colors \
         --pause "\n  \n${txt[1]}  \n\n\n\n" 0 0 "$1"
  Respuesta=$?
  if [ ! "${Respuesta}" -eq 0 ]; then
    Abortar="si"
    dialog --backtitle "omv-regen ${ORVersion}" \
           --title "omv-regen ${ORVersion}" \
           --colors \
           --infobox "\n  \n${txt[2]}  \n\n${txt[3]}  \n\n " 0 0
    sleep 3
  fi
}

# Informacion con tiempo de espera para leer.
# $1=segundos de espera
# $2 y $3 es el texto
Info () {
  txt 1 "$2" "$3"
  dialog --title "omv-regen ${ORVersion}" --backtitle "omv-regen ${ORVersion}" --colors --infobox "\n${txt[1]}\n " 0 0
  sleep "$1"
}

Mensaje () {
  txt 1 "$1" "$2"
  dialog --title "omv-regen ${ORVersion}" --backtitle "omv-regen ${ORVersion}" --colors --msgbox "\n${txt[1]}\n " 0 0
}

Pregunta () {
  Pregunta=""
  txt 1 "$1" "$2"
  dialog --title "omv-regen ${ORVersion}" --backtitle "omv-regen ${ORVersion}" --yes-label "${txt[Si]}" --colors --yesno "\n${txt[1]}\n " 0 0
  [ $? -eq 0 ] && Pregunta="" || Pregunta="si"
}

# Habilitar o deshabilitar backports
# $1=YES --> Habilitar
# $1=NO --> Deshabilitar
Backports () {
  if [ ! "${Backports}" = "$1" ]; then
    if [ "$1" = "YES" ] || [ "$1" = "NO" ]; then
      Backports="$1"
      sed -i "/bullseye-backports/d" /etc/apt/sources.list
      omv_set_default "OMV_APT_USE_KERNEL_BACKPORTS" "${Backports}" true
      omv-salt stage run --quiet prepare
      omv-salt deploy run --quiet apt
      omv-aptclean repos
      [ "${Backports}" = "YES" ] && omv-upgrade
    fi
  fi
}
  
# Analizar estado de paquete. Instalación y versiones.
Analizar () {
  VersionOR=""; VersionDI=""; InstII=""

  VersionOR=$(awk -v i="$1" '$2 == i {print $3}' "${ORA[RutaRegen]}${ORB[DpkgOMV]}")
  VersionDI=$(apt-cache madison "$1" | awk 'NR==1{print $3}')
  InstII=$(dpkg -l | awk -v i="$1" '$2 == i {print $1}')
  [ "${InstII}" == "ii" ] && InstII="si" || InstII=""
}

# Control de versiones.
# $1=esencial -> Si no es la misma versión se detiene la regeneración.
# $1=noesencial -> Si no es la misma versión se avisa y se almacena en una variable.
# $2 es el paquete que se analiza.
ControlVersiones () {
  ControlVersiones=""
  Paquete=$2
  [ "$1" = "esencial" ]; Esencial="si"
  [ "$1" = "noesencial" ]; Esencial=""

  Analizar "${Paquete}"
  if [ "${VersionOR}" ] && [ ! "${VersionOR}" = "${VersionDI}" ]; then
    if [ ! "${Esencial}" ]; then
      ControlVersiones="si"
      Info 10 "La versión del sistema original del paquete ${Paquete} es ${VersionOR} \nLa versión disponible en internet para la instalación de este paquete es ${VersionDI} \nEstas versiones no coinciden. Eso significa que ha habido una actualización reciente de este paquete.\nRegenerar este complemento podría resultar en un sistema corrupto.\nPuesto que no se trata de un complemento esencial para el funcionamiento del sistema se va a instalar ${Paquete} pero no se va a regenerar.\nTendrás que configurarlo después manualmente." "The original system version of the package ${Paquete} is ${VersionOR} \nThe version available on the Internet for the installation of this package is ${VersionDI} \nThese versions do not match. That means there has been a recent update to this package.\nRegenerating this plugin could result in a corrupt system.\nSince this is not an essential plugin for the functioning of the system, ${Paquete} will be installed but will not be regenerated.\nYou will have to configure it later manually."
      ComplementosNoInstalados="${ComplementosNoInstalados}${Paquete} -> ${VersionOR} -> ${VersionDI}\n"
    else
      Info 10 "La versión del sistema original del paquete ${Paquete} es ${VersionOR} \nLa versión disponible en internet para la instalación de este paquete es ${VersionDI} \nEstas versiones no coinciden. Eso significa que ha habido una actualización reciente de este paquete.\n Continuar con la regeneración del sistema podría resultar en un sistema corrupto.\nNo se puede omitir la instalación de este paquete porque afectaría al resto del sistema.\nLamentablemente debes hacer un nuevo backup del sistema original actualizado y empezar de nuevo el proceso de regeneración." "The original system version of the package ${Paquete} is ${VersionOR} \nThe version available on the Internet for the installation of this package is ${VersionDI} \nThese versions do not match. That means there has been a recent update to this package.\nContinuing to regenerate the system could result in a corrupted system.\nIt is not possible to skip the installation of this package because it would affect the rest of the system.\nUnfortunately you must make a new backup of the original updated system and start the regeneration process again."
      exit
    fi
  else
    echoe "Las versiones de ${Paquete} coinciden." "The versions of ${Paquete} match."
  fi
}

# Instalar paquete
Instalar () {
  echoe "\nInstalando $1\n" "\nInstall $1 \n"
  if ! apt-get --yes install "$1"; then
    apt-get --yes --fix-broken install
    apt-get update
    if ! apt-get --yes install "$1"; then
      apt-get --yes --fix-broken install
      Salir "$1 no se pudo instalar. Saliendo..." "Failed to install $1. Exiting..."
    fi
  fi
  echoe "\nSe ha instalado $1\n" "\n$1 has been installed\n"
}

# Extraer valor de una entrada de la base de datos
LeerValor () {
  ValorOR=""; ValorAC=""; NumVal=""

  echoe "Leyendo el valor de $1 en la base de datos original..." "Reading the value of $1 in original database..."
  ValorOR="$(xmlstarlet select --template --value-of "$1" --nl "${ORA[RutaRegen]}""${Configxml}")"
  echoe "Leyendo el valor de $1 en la base de datos actual..." "Reading the value of $1 in actual database..."
  ValorAC="$(xmlstarlet select --template --value-of "$1" --nl "${Configxml}")"
  NumVal="$(echo "${ValorAC}" | awk '{print NR}' | sed -n '$p')"
  echoe "El número de valores es ${NumVal}" "The number of values is ${NumVal}"
}

# Sustituye nodo de la base de datos actual por el existente en la base de datos original y aplica cambios en módulos salt
# El argumento de entrada debe ser un elemento de la matriz CONFIG[]
Regenera () {
  local Nodo Padre Etiqueta Salt NodoOR NodoAC Modulo Resto
  
  Nodo="$(echo "$1" | awk '{print $1}')"
  Padre="$(printf "${Nodo%/*}")"
  Etiqueta="$(printf "${Nodo##*/}")"
  Salt="$(echo "$1" | awk '{print NF}')"
  NodoOR=""; NodoAC=""; Modulo=""; Resto=""

  if [ "${Nodo}" = "nulo" ]; then
    echoe "No se ha definido nodo para regenerar en la base de datos." "No node to regenerate has been defined in the database."
  else
    echoe "\nRegenerando nodo ${Nodo} de la base de datos\n" "\nRegenerating node ${Nodo} of the database\n"
    [ ! -f "${ConfTmp}ori" ] && cp -a "${Configxml}" "${ConfTmp}ori"
    cat "${Configxml}" >"${ConfTmp}ori"
    echoe "Formateando base de datos" "Formatting database"
    xmlstarlet fo "${ConfTmp}ori" | tee "${Configxml}" >/dev/null
    echoe "Leyendo el valor de ${Nodo} en la base de datos original..." "Reading the value of ${Nodo} in original database..."
    NodoOR="$(xmlstarlet select --template --copy-of "${Nodo}" --nl "${ORA[RutaRegen]}${Configxml}")"
    echoe "Leyendo el valor de ${Nodo} en la base de datos actual..." "Reading the value of ${Nodo} in actual database..."
    NodoAC="$(xmlstarlet select --template --copy-of "${Nodo}" --nl "${Configxml}")"
    if [ "${NodoOR}" = "" ]; then
      echoe "El nodo ${Nodo} no existe en la base de datos original --> No se modifica la base de datos ni se aplican cambios en salt." "The ${Nodo} node does not exist in the original database --> The database is not modified and no changes are applied to salt."
      Salt=""
    elif [ "${NodoOR}" = "${NodoAC}" ]; then
      echoe "El nodo ${Nodo} coincide en la base de datos original y la actual --> No se modifica la base de datos ni se aplican cambios en salt." "${Nodo} node matches original and current databases --> The database is not modified and no changes are applied to salt."
      Salt=""
    else
      echoe "Regenerando ${Nodo}..." "Regenerating ${Nodo}..."
      echoe "Creando base de datos temporal..." "Creating temporary database..."
      [ ! -f "${ConfTmp}" ] && cp -a "${Configxml}" "${ConfTmp}"
      cat "${Configxml}" >"${ConfTmp}"
      echoe "Eliminando nodo ${Nodo} actual..." "Deleting current ${Nodo} node..."
      xmlstarlet edit -d "${Nodo}" "${Configxml}" | tee "${ConfTmp}" >/dev/null
      echoe "Copiando etiqueta ${Etiqueta} original..." "Copying original ${Etiqueta} tag..."
      sed -i '/<\/config>/d' "${ConfTmp}"
      echo "${NodoOR}" >> "${ConfTmp}"
      echo "</config>" >> "${ConfTmp}"
      echoe "Moviendo ${Etiqueta} a ${Padre}..." "Moving ${Etiqueta} to ${Padre}..."
      xmlstarlet edit -m "/config/${Etiqueta}" "${Padre}" "${ConfTmp}" | tee "${Configxml}" >/dev/null
      if [ "$(xmlstarlet val "${Configxml}" | awk '{print $3}')" = "invalid" ]; then
        echoe "No se ha podido regenerar el nodo ${Nodo} en la base de datos actual. Saliendo..." "Failed to regenerate ${Nodo} node in the current database. Exiting..."
        cat "${ConfTmp}ori" >"${Configxml}"
        exit
      else
        echoe "Nodo ${Nodo} regenerado en la base de datos." "${Nodo} node regenerated in the database."
      fi
    fi
  fi
  if [ "${Salt}" ]; then
    echoe "Aplicando cambios de configuración en los módulos salt..." "Applying configuration changes to salt modules..."
    if [ "${Salt}" = "1" ]; then
      echoe "No hay cambios de configuración para aplicar en los módulos salt." "There are no configuration changes to apply to salt modules."
    else
      cont=1
      while [ ${cont} -lt "${Salt}" ]; do
   	    ((cont++))
        Modulo="$(echo "$1" | awk -v c=${cont} '{print $c}')"
        echoe "Configurando salt ${Modulo}..." "Configuring salt ${Modulo}..."
        omv-salt deploy run --quiet "${Modulo}"
        echoe "Módulo de Salt ${Modulo} configurado." "Salt module ${Modulo} configured."
      done
      Limpiar
      echoe "La configuración de módulos salt para la regeneración de ${Etiqueta} ha finalizado." "The configuration of salt modules for the regeneration of ${Etiqueta} is complete..."
    fi
  fi
}

# Ejecuta salt en modulos pendientes de aplicar cambios. 
Limpiar (){
  Resto="$(jq -r .[] "${Listasucia}" | tr '\n' ' ')"
  if [ "${Resto}" ]; then
    /usr/sbin/omv-rpc -u admin "Config" "applyChanges" "{\"modules\": $(cat /var/lib/openmediavault/dirtymodules.json), \"force\": false}"
  fi
}

#################################################### BACKUP #######################################################
EjecutarBackup () {
  ValidarBackup
  [ "${ValidarBackup}" ] && Mensaje "Los ajustes no son válidos, no se puede ejecutar el backup." "The settings are invalid, the backup cannot be executed."
  [ "${ValidarBackup}" ] && Camino="MenuBackup"
  Fecha=$(date +%y%m%d_%H%M%S)
  [ "${Cli}" ] && Abortar="" || Abortar 10 "\n\n  Se va a realizar un BACKUP en  \n\n  ${ORA[RutaBackup]} \n\n " "\n\nA BACKUP is going to be made in\n\n  ${ORA[RutaBackup]} \n\n "
  if [ "${Abortar}" ]; then
    Camino="MenuBackup"
  else
    clear
    echoe "\n       <<< Backup para regenerar sistema de fecha ${Fecha} >>>\n" "\n       <<< Backup to regenerate system dated ${Fecha} >>>\n"
    echoe "\n>>>    Los parámetros actuales establecidos para el backup son:\n" "\n>>>    The current parameters set for the backup are:\n"
    echoe "Carpeta para almacenar el backup ==> ${ORA[RutaBackup]}" "Folder to store the backup ==> ${ORA[RutaBackup]}"
    echoe "Actualizar sistema antes de hacer el backup ==> ${ORA[Actualizar]}" "Update system before making the backup ==> ${ORA[Actualizar]}"
    echoe "Eliminar backups con una antigüedad superior a ==> ${ORA[Dias]} días." "Delete backups older than ==> ${ORA[Dias]} days."
    if [ "${#CARPETAS[@]}" = 0 ]; then
      echoe "Carpetas opcionales a incluir en el backup ==> Ninguna" "Optional folders to include in the backup ==> None"
    else
      echoe "Carpetas opcionales a incluir en el backup ==>" "Optional folders to include in the backup ==>"
      for i in "${CARPETAS[@]}"; do
        if [ -d "$i" ]; then
          echoe "$i"
  	    else
          echoe "${Rojo}$i --> no existe y no se incluirá.${Reset}" "${Rojo}$i --> does not exist and will not be included.${Reset}"
        fi
      done
    fi
    if [ "${ORA[RutaBackup]}" = "/ORBackup" ] && [ ! -d "/ORBackup" ]; then
      mkdir /ORBackup
    fi
    if [ "${ORA[Actualizar]}" = "${txt[Si]}" ]; then
      echoe "\n>>>    Actualizando el sistema.\n" "\n>>>    Updating the system.\n"
      if ! omv-upgrade; then
        Salir "\nError actualizando el sistema.  Saliendo..." "\nFailed updating system. Exiting..."
      else
        Limpiar
      fi
    fi
    CarpetaRegen="/regen_${Fecha}"
    echoe "\n>>>    Copiando archivos a ${CarpetaRegen} ...\n" "\n>>>    Copying files to ${CarpetaRegen} ...\n"
    mkdir "${CarpetaRegen}"
    for i in "${ARCHIVOS[@]}"; do
      [ ! -d "$(dirname "${CarpetaRegen}$i")" ] && mkdir -p "$(dirname "${CarpetaRegen}$i")"
      cp -apv "$i" "${CarpetaRegen}$i"
    done
    xmlstarlet fo "${Configxml}" | tee "${CarpetaRegen}${Configxml}" >/dev/null
    if [ "$(xmlstarlet val "${CarpetaRegen}${Configxml}" | awk '{print $3}')" = "invalid" ]; then
      Salir "\nLa base de datos de openmediavault es inutilizable, no se puede hacer un backup para regenerar este sistema. Saliendo..." "\nopenmediavault database is unusable, a backup cannot be made to regenerate this system. Exiting..."
    fi
    if dpkg -l | grep openmediavault-kvm >/dev/null; then
   	  echoe "\n>>>    openmediavault-kvm está instalado, copiando carpetas /etc/libvirt y /var//lib/libvirt ...\n" "\n>>>    openmediavault-kvm is installed, copying /etc/libvirt and /var//lib/libvirt folders...\n"
      mkdir -p "${CarpetaRegen}/etc/libvirt" "${CarpetaRegen}/var/lib/libvirt"
      rsync -av /etc/libvirt/ "${CarpetaRegen}/etc/libvirt"
      rsync -av /var/lib/libvirt/ "${CarpetaRegen}/var/lib/libvirt"
    fi
    echoe "\n>>>    Extrayendo lista de versiones (dpkg)...\n" "\n>>>    Extracting version list (dpkg)...\n"
    dpkg -l | grep openmediavault > "${CarpetaRegen}${ORB[DpkgOMV]}"
    dpkg -l > "${CarpetaRegen}${ORB[Dpkg]}"
    awk '{print $2" "$3}' "${CarpetaRegen}${ORB[DpkgOMV]}"
    echoe "\n>>>    Extrayendo información del sistema (uname -a)...\n" "\n>>>    Extracting system info (uname -a)...\n"
    uname -a | tee "${CarpetaRegen}${ORB[Unamea]}"
    echoe "\n>>>    Extrayendo información de zfs (zpool list)...\n" "\n>>>    Extracting zfs info (zpool list)...\n"
    zpool list | tee "${CarpetaRegen}${ORB[Zpoollist]}"
    echoe "\n>>>    Extrayendo información de systemd (systemctl)...\n" "\n>>>    Extracting information from systemd (systemctl)...\n"
    systemctl list-unit-files | tee "${CarpetaRegen}${ORB[Systemctl]}"
    echoe "\n>>>    Extrayendo información de red (hostname -I)...\n" "\n>>>    Retrieving network information (hostname -I)...\n"
    hostname -I | tee "${CarpetaRegen}${ORB[HostnameI]}"
    echoe "\n>>>    Extrayendo información de las unidades de disco del sistema (lsblk --nodeps -o name,serial)...\n" "\n>>>    Extracting information from system drives (lsblk --nodeps -o name,serial)...\n"
    Discos="$(lsblk --nodeps -o name,serial)"
    Dev="$(df "${Configxml}" | awk '/^\/dev/ {print $1}' | awk -F "/" '{print $3}')"
    if [ "${Dev}" = "root" ]; then
      Dev="$(mount | grep ' / ' | cut -d' ' -f 1 | awk -F "/" '{print $3}')"
      Dev="${Dev:0:7}"
    else
      Dev="${Dev:0:3}"
    fi
    echo "${Discos}" | awk -v a="${Dev}" '{ if($1 == a) print $2}' | tee "${CarpetaRegen}${ORB[Rootfs]}"
    Serial="$(echo "${Discos}" | awk -v a="${Dev}" '{ if($1 != a) print $2}' | tee "${CarpetaRegen}${ORB[Lsblk]}")"
    echo "${Serial}" | awk '{ if($1 != "SERIAL") print}' | tee "${CarpetaRegen}${ORB[Lsblk]}"
    echoe "\n>>>    Empaquetando directorio ${CarpetaRegen} en ${ORA[RutaBackup]}/ORB_${Fecha}_regen.tar.gz ...\n" "\n>>>    Packaging ${CarpetaRegen} directory in ${ORA[RutaBackup]}/ORB_${Fecha}_regen.tar.gz ...\n"
    tar -zcvf "${ORA[RutaBackup]}/ORB_${Fecha}_regen.tar.gz" "${CarpetaRegen}"
    rm -rf "${CarpetaRegen}"
    [ "${#CARPETAS[@]}" = 0 ] && echoe "\n>>>    No se han establecido carpetas opcionales en la configuración del backup.\n" "\n>>>    No optional folders set in backup settings.\n" || echoe "\n>>>    Copiando carpetas opcionales.\n" "\n>>>    Copying optional folders.\n"
    cont=1
    for i in "${CARPETAS[@]}"; do
      if [ -d "$i" ]; then
        echoe "\n>>>    Empaquetando directorio $i en ${ORA[RutaBackup]}/ORB_${Fecha}_user$cont.tar.gz ...\n" "\n>>>    Packaging $i directory in ${ORA[RutaBackup]}/ORB_${Fecha}_user$cont.tar.gz ...\n"
        tar -zcf "${ORA[RutaBackup]}/ORB_${Fecha}_user$cont.tar.gz" "$i"
		  ((cont++))
  	  else
        echoe "${Rojo}\n>>>    Aviso: $i definido en los ajustes de Backup no existe y no se copia.\n${Reset}" "${Rojo}\n>>>    Warning: $i defined in the Backup settings does not exist and it is not copied.\n${Reset}"
      fi
    done
    echoe "\n>>>    Eliminando backups de hace más de ${ORA[Dias]} días...\n" "\n>>>    Deleting backups larger than ${ORA[Dias]} days...\n"
    find "${ORA[RutaBackup]}/" -maxdepth 1 -type f -name "ORB_*" -mtime "+${ORA[Dias]}" -exec rm -v {} +
    # Nota:   -mmin = minutos  ///  -mtime = dias
    [ "${Cli}" ] && Salir "\n       ¡Backup completado!\n" "\n       Backup completed!\n"
    Continuar
  fi
  [ "${Camino}" = "EjecutarBackup" ] && Info 3 "\n¡Backup completado!\n" "\nBackup completed!\n"
  Camino="MenuPrincipal"
}

################################################# REGENERA ###############################################
EjecutarRegenera () {
  clear
  ValidarRegenera
  if [ "${ValidarRegenera}" ]; then
    Info 3 "Los ajustes no son válidos, no se puede ejecutar la regeneración.\nDesde el menú principal selecciona Regenera Ajustes para modificarlos." "The settings are invalid, regeneration cannot be executed.\nFrom the main menu select Regenerate Settings to modify them."
    Abortar="si"
  elif [ "${FASE[1]}" = "iniciar" ]; then
    Abortar 10 "\n\n  Se va a ejecutar la REGENERACION DEL SISTEMA ACTUAL desde  \n\n  ${ORA[RutaOrigen]} \n\n " "\n\n  The REGENERATION OF THE CURRENT SYSTEM will be executed from  \n\n  ${ORA[RutaOrigen]} \n\n "
  else
    FaseActual=$(grep FASE "${ORAjustes}" | awk 'END {print NR}')
    Abortar 10 "\n\n  Se va a continuar la REGENERACION DEL SISTEMA ACTUAL desde el punto que se detuvo. \n\n  La Fase actual es la Fase Nº ${FaseActual} \n\n " "\n\n  The REGENERATION OF THE CURRENT SYSTEM will continue from the point it stopped. \n\n  The current Phase is Phase Nº ${FaseActual} \n\n " "El proceso de regeneración no ha finalizado.\nDebes ejecutar de nuevo omv-regen para su finalización." "The regeneration process has not finished.\nYou must run omv-regen again for completion."
  fi
  if [ "${Abortar}" ]; then
    Camino="MenuRegenera"
  elif [ "${FASE[1]}" = "iniciar" ]; then
      ORA[FechaBackup]="${FechaBackup}"
      ORA[RutaRegen]="${ORA[RutaOrigen]}/regen_${FechaBackup}"
      GuardarAjustes
      [ -d "${ORA[RutaRegen]}" ] && rm -rf "${ORA[RutaRegen]}"
      tar -C "${ORA[RutaOrigen]}" -xvf "${ORA[RutaOrigen]}/${TarRegen}"
  elif [ ! -d "${ORA[RutaRegen]}" ]; then
      Info 3 "El backup usado para la regeneración en progreso ya no está disponible.\nNo se puede continuar." "The backup used to start the regeneration is no longer available.\nCan't continue." 
      Camino="MenuRegenera"
  fi
  if [ "${Camino}" = "EjecutarRegenera" ]; then
    clear; echoe "\n\n       <<< REGENERANDO SISTEMA OMV >>>\n\n" "\n\n       <<< REGENERATING OMV SYSTEM >>>\n\n"
    echoe "Actualizando openmediavault..." "Updating openmediavault..."
    if ! omv-upgrade; then
      Salir "Error actualizando el sistema.  Saliendo..." "Failed updating system. Exiting..."
    else
      Limpiar
      ControlVersiones openmediavault
    fi
    f=1
    while [ ! "${FASE[7]}" = "hecho" ]; do
      [ ! "${OrdenarComplementos}" ] && OrdenarComplementos
      if [ ! "${FASE[f]}" = "hecho" ]; then
        while [ ! "${FASE[f]}" = "hecho" ]; do
          case "${FASE[f]}" in
            iniciar)
              FASE[f]="iniciado"
              GuardarAjustes
              ;;
            iniciado)
              FASE[f]="repetir"
              GuardarAjustes
              echoe "Se ha detectado un error en una ejecución anterior de la Fase Nº$f. Se va a intentar de nuevo." "An error was detected in a previous execution of Phase No.$f. It will be tried again."
              ;;
            repetir)
              Abortar 10 "Se ha intentado regenerar la Fase Nº$f varias veces.\nEs posible que haya algún error.\nSe va a intentar de nuevo." "An attempt has been made to regenerate Phase No.$f several times.\nThere may be an error.\nIt will be tried again."
              [ "${Abortar}" ] && exit
              ;;
            *)
              Salir "El archivo de ajustes ha sido manipulado o no se puede leer. Saliendo..." "The settings file has been tampered with or cannot be read. Exiting..."
              ;;
          esac
          if [ $f = 1 ]; then
            RegeneraFase1
          elif [ $f = 2 ]; then
            RegeneraFase2
          elif [ $f = 3 ]; then
            RegeneraFase3
          elif [ $f = 4 ]; then
            RegeneraFase4
          elif [ $f = 5 ]; then
            RegeneraFase5
          elif [ $f = 6 ]; then
            RegeneraFase6
          elif [ $f = 7 ]; then
            RegeneraFase7
          fi
        done
      fi
      ((f++))
    done
  fi
}

OrdenarComplementos () {
  Analizar "openmediavault-omvextrasorg"
  if [ "${InstII}" ] || [ ! "${VersionOR}" ]; then
    echoe "\n>>>   >>>    ANALIZAR VERSIONES Y COMPLEMENTOS INSTALADOS EN EL SERVIDOR ORIGINAL.\n" "\n>>>   >>>    ANALYZE VERSIONS AND ADDITIONS INSTALLED ON THE ORIGINAL SERVER.\n"
    i=0
    unset COMPLEMENTOS
    while IFS= read -r linea; do
      Plugin="$(echo "$linea" | awk '{print $2}')"
      Analizar "${Plugin}"
      if [ ! "${InstII}" ]; then
        case "${Plugin}" in
          *kernel|*sharerootfs|*zfs|*lvm2|*mergerfs|*snapraid|*remotemount)
            ControlVersiones esencial "${Plugin}"
            ;;
          *symlinks|*apttool|*kvm)
            ControlVersiones noesencial "${Plugin}"
            ;;
          * )
            ControlVersiones noesencial "${Plugin}"
            (( i++ ))
            COMPLEMENTOS[i]="${Plugin}"
            ;;
        esac
        if [ ! "${ControlVersiones}" ]; then
          echoe "No instalado y versiones coinciden   -->   Se va a instalar y regenerar   -->   ${Plugin}" "Not installed and versions match   -->   It will be installed and regenerated   -->   ${Plugin}"
        else
          echoe "${Rojo}No instalado y VERSIONES NO COINCIDEN   -->   Se va a instalar y NO SE VA A REGENERAR   -->   ${Plugin}${Reset}" "${Rojo}Not installed and VERSIONS DO NOT MATCH   -->   It is going to be installed and IT WILL NOT BE REGENERATED   -->   ${Plugin}${Reset}"
          sleep 3
        fi
      fi
    done < <(grep -v '^ *#' < "${ORA[RutaRegen]}${ORB[DpkgOMV]}")
    OrdenarComplementos="si"
  fi
}

RegeneraFase1 () {
  echoe "\n>>>   >>>    FASE Nº1: REGENERAR CONFIGURACIONES BÁSICAS.\n" "\n>>>   >>>    PHASE Nº1: REGENERATE BASIC SETTINGS.\n"
  cp -apv "${ORA[RutaRegen]}${Passwd}" "${Passwd}"
  cp -apv "${ORA[RutaRegen]}${Default}" "${Default}"
  echoe "\nRegenerando Configuraciones básicas del sistema...\n" "\nRegenerating basic system settings...\n"
  Regenera "${CONFIG[time]}"
  Regenera "${CONFIG[certificates]}"
  Regenera "${CONFIG[webadmin]}"
  Regenera "${CONFIG[powermanagement]}"
  Regenera "${CONFIG[monitoring]}"
  Regenera "${CONFIG[crontab]}"
  Regenera "${CONFIG[apt]}"
  Regenera "${CONFIG[syslog]}"
  echoe "Aplicando cambios en variables de entorno personalizadas..." "Applying changes to custom environment variables..."
  monit restart omv-engined
  echoe "Fase Nº1 terminada." "Phase No.1 completed."; sleep 1
  FASE[1]="hecho"; FASE[2]="iniciar"; GuardarAjustes
}

RegeneraFase2 () {
  echoe "\n>>>   >>>    FASE Nº2: INSTALAR Y REGENERAR OMV-EXTRAS. CONFIGURAR REPOSITORIOS.\n" "\n>>>   >>>    PHASE Nº2: INSTALL AND REGENERATE OMV-EXTRAS. CONFIGURE REPOSITORIES.\n"
  Analizar "openmediavault-omvextrasorg"
  if [ ! "${VersionOR}" ]; then
    echoe "omv-extras no estaba instalado en el servidor original. No se va a instalar." "omv-extras was not installed on the original server. It is not going to be installed."
  elif [ ! "${InstII}" ]; then
    echoe "Descargando el complemento omv-extras.org para openmediavault 6.x ..." "Downloading omv-extras.org plugin for openmediavault 6.x ..."
    Archivo="openmediavault-omvextrasorg_latest_all6.deb"
    echoe "Actualizando repositorios antes de instalar..." "Updating repos before installing..."
    apt-get update
    echoe "Instalando prerequisitos..." "Install prerequisites..."
    apt-get --yes --no-install-recommends install gnupg
    [ -f "${Archivo}" ] && rm ${Archivo}
    wget "${URLextras}/${Archivo}"
    if [ -f "${Archivo}" ]; then
      if ! dpkg -i ${Archivo}; then
        echoe "Instalando otras dependencias..." "Installing other dependencies..."
        apt-get -f install
      fi
      echoe "Actualizando repositorios..." "Updating repos..."
      apt-get update
    else
      Salir "Hubo un problema al descargar el paquete omv-extras. Saliendo..." "There was a problem downloading the omv-extras package. Exiting..."
    fi
    ControlVersiones esencial "openmediavault-omvextrasorg"
    echoe "Regenerando omv-extras y repositorio de docker..." "Regenerating omv-extras and docker repository..."
    Regenera "${CONFIG[openmediavault-omvextras]}"
    /usr/sbin/omv-aptclean repos
  fi
  echoe "Fase Nº2 terminada." "Phase No.2 completed."; sleep 1
  FASE[2]="hecho"; FASE[3]="iniciar"; GuardarAjustes
}

RegeneraFase3 () {
  echoe "\n>>>   >>>    FASE Nº3: INSTALAR KERNEL PROXMOX.\n" "\n>>>   >>>    PHASE Nº3: INSTALL PROXMOX KERNEL.\n"
  Analizar openmediavault-kernel
  if [ ! "${VersionOR}" ]; then
    echoe "openmediavault-kernel no estaba instalado en el servidor original. No se va a instalar." "openmediavault-kernel was not installed on the original server. It is not going to be installed."
  elif [ ! "${InstII}" ]; then
    Instalar openmediavault-kernel
    KernelOR=$(awk '{print $3}' "${ORA[RutaRegen]}${ORB[Unamea]}" | awk -F "." '/pve$/ {print $1"."$2}')
    KernelIN=$(uname -r | awk -F "." '/pve$/ {print $1"."$2}')
    if [ "${ORA[Kernel]}" = "off" ]; then
      echoe "Opción saltar kernel proxmox habilitada. No se instalará kernel." "Skip proxmox kernel option enabled. Kernel will not be installed."
    elif [ "${KernelOR}" ] && [ ! "${KernelOR}" = "${KernelIN}" ]; then
      echoe "\nInstalando kernel proxmox ${KernelOR}\n" "\nInstalling proxmox kernel ${KernelOR}\n"
      cp -a /usr/sbin/omv-installproxmox /tmp/installproxmox
      sed -i 's/^exit 0.*$/echo "Completado"/' /tmp/installproxmox
      . /tmp/installproxmox "${KernelOR}"
      rm -f /tmp/installproxmox
      Info 5 "\n\nKernel proxmox ${KernelOR} instalado.\nEs necesario reiniciar el sistema para continuar la regeneración.\n\n\n${RojoD}Para completar la regeneración DESPUES DE REINICIAR EJECUTA DE NUEVO omv-regen\n\n ${ResetD}\nEl proceso continuará de forma automática.\n " \
      "\n\nKernel proxmox ${KernelOR} installed.\nA system reboot is required to continue regeneration.\n\n\n${RojoD}To complete the regeneration AFTER REBOOT RUN AGAIN omv-regen\n\n ${ResetD}\nThe process will continue automatically.\n "
      echoe "Fase Nº3 terminada." "Phase No.3 completed."; sleep 1
      FASE[3]="hecho"; FASE[4]="iniciar"; GuardarAjustes
      exit
    fi
  fi
  echoe "Fase Nº3 terminada." "Phase No.3 completed."; sleep 1
  FASE[3]="hecho"; FASE[4]="iniciar"; GuardarAjustes
}

RegeneraFase4 () {
  echoe "\n>>>   >>>    FASE Nº4: MONTAR SISTEMAS DE ARCHIVOS.\n" "\n>>>   >>>    PHASE Nº4: MOUNT FILE SYSTEMS.\n"
  Analizar openmediavault-sharerootfs
  if [ ! "${InstII}" ]; then
    echoe "Instala openmediavault-sharerootfs. Regenera fstab (Sistemas de archivos EXT4 BTRFS mdadm)" "Install openmediavault-sharerootfs. Regenerate fstab (EXT4 BTRFS mdadm file systems)"
    Instalar openmediavault-sharerootfs
    Regenera "${CONFIG[hdparm]}"
    Regenera "${CONFIG[fstab]}"
    echoe "Cambiar UUID disco de sistema si es nuevo" "Change system disk UUID if it is new"
    echoe "Configurando openmediavault-sharerootfs..." "Configuring openmediavault-sharerootfs..."
    uuid="79684322-3eac-11ea-a974-63a080abab18"
    if [ "$(omv_config_get_count "//mntentref[.='${uuid}']")" = "0" ]; then
      omv-confdbadm delete --uuid "${uuid}" "conf.system.filesystem.mountpoint"
    fi
    apt-get install --reinstall openmediavault-sharerootfs
  fi

  echoe "Regenerar complementos requeridos para los sistemas de archivos." "Regenerate plugins required for file systems."
  for a in "${SISTEMA_ARCHIVOS[@]}"; do
    Analizar "$a"
    if [ ! "${VersionOR}" ]; then
      echoe "$a no estaba instalado en el sistema original." "$a was not installed on the original system."
    elif [ ! "${InstII}" ]; then
      ControlVersiones esencial "$a"
      if [ "$a" = "openmediavault-zfs" ]; then
        echoe "\nHabilitando Backports... \n" "\nEnabling backports... \n"
        Backports YES
        Instalar "$a"
        for i in $(awk 'NR>1{print $1}' "${ORA[RutaRegen]}${ORB[Zpoollist]}"); do
          zpool import -f "$i"
        done
      else
        Instalar "$a"
      fi
      Regenera "${CONFIG[$a]}"
    fi
  done
  Analizar openmediavault-symlinks
  if [ ! "${VersionOR}" ]; then
    echoe "openmediavault-symlinks no estaba instalado en el sistema original." "openmediavault-symlinks was not installed on the original system."
  elif [ ! "${InstII}" ]; then
    Instalar openmediavault-symlinks
    ControlVersiones noesencial openmediavault-symlinks
    if [ ! "${ControlVersiones}" ]; then
      Regenera openmediavault-symlinks
      LeerValor /config/services/symlinks/symlinks/symlink/source
      if [ "${NumVal}" ]; then
        b=0; SymFU=""; SymDE=""
        while [ $b -lt "${NumVal}" ]; do
          ((b++))
          LeerValor /config/services/symlinks/symlinks/symlink/source
          SymFU=$(echo "${ValorAC}" | awk -v i=$b 'NR==i {print $1}')
          LeerValor /config/services/symlinks/symlinks/symlink/destination
          SymDE=$(echo "${ValorAC}" | awk -v i=$b 'NR==i {print $1}')
          echoe "Creando symlink ${SymFU} ${SymDE}" "Creating symlink ${SymFU} ${SymDE}"
          ln -s "${SymFU}" "${SymDE}"
        done
      else
        echoe "No hay symlinks creados en la base de datos original." "No symlinks created in original database."
      fi
    fi
  fi
  echoe "Fase Nº4 terminada." "Phase No.4 completed."; sleep 1
  FASE[4]="hecho"; FASE[5]="iniciar"; GuardarAjustes
}

RegeneraFase5 () {
  echoe "\n>>>   >>>    FASE Nº5: REGENERAR RESTO DE GUI.\n" "\n>>>   >>>    PHASE Nº5: REGENERATE REST OF GUI.\n"
  echoe "Restaurar archivos. Regenerar Usuarios. Carpetas compartidas. Smart. Servicios." "Restore files. Regenerate Users. Shared folders. Smart. Services."
  echoe "Restaurando archivos de sistema..." "Restoring system files..."
  rsync -av "${ORA[RutaRegen]}"/ / --exclude "${Configxml}" --exclude /ORB_* --exclude "${Omvregen}"
  echoe "Regenerando usuarios..." "Regenerating users..."
  Regenera "${CONFIG[homedirectory]}"
  Regenera "${CONFIG[users]}"
  Regenera "${CONFIG[groups]}"
  echoe "Regenerando carpetas compartidas..." "Regenerating shared folders..."
  Regenera "${CONFIG[shares]}"
  echoe "Regenerando SMART..." "Regenerating SMART..."
  Regenera "${CONFIG[smart]}"
  echoe "Regenerando Servicios..." "Regenerating Services..."
  Regenera "${CONFIG[nfs]}"
  Regenera "${CONFIG[rsync]}"
  Regenera "${CONFIG[smb]}"
  Regenera "${CONFIG[ssh]}"
  Regenera "${CONFIG[email]}"
  Regenera "${CONFIG[notification]}"
  echoe "Fase Nº5 terminada." "Phase No.5 completed."; sleep 1
  FASE[5]="hecho"; FASE[6]="iniciar"; GuardarAjustes
}

RegeneraFase6 () {
  echoe "\n>>>   >>>    FASE Nº6: INSTALAR RESTO DE COMPLEMENTOS.\n" "\n>>>   >>>    PHASE Nº6: INSTALL REST OF COMPLEMENTS.\n"
  echoe "Instalar apttool (antes que el resto)" "Install apttool (before the rest)"
  Analizar openmediavault-apttool
  if [ ! "${VersionOR}" ]; then
    echoe "openmediavault-apttool no estaba instalado en el sistema original." "openmediavault-apttool was not installed on the original system."
  elif [ ! "${InstII}" ]; then
    Instalar openmediavault-apttool
    ControlVersiones noesencial openmediavault-apttool
    if [ ! "${ControlVersiones}" ]; then
      Regenera "${CONFIG[openmediavault-apttool]}"
      LeerValor /config/services/apttools/packages/package/packagename
      if [ ! "${NumVal}" ]; then
        echoe "La base de datos original no contiene paquetes instalados mediante el complemento apttool." "The original database does not contain packages installed using the apttool plugin."
      else
        i=0; Pack=""
        while [ $i -lt "${NumVal}" ]; do
          ((i++))
          Pack=$(echo "${ValorAC}" | awk -v i=$i 'NR==i {print $1}')
          VersionOR="$(awk -v i="${Pack}" '$2 == i {print $3}' "${ORA[RutaRegen]}${ORB[Dpkg]}")"
          InstII="$(dpkg -l | awk -v i="${Pack}" '$2 == i {print $1}')"
          if [ "${VersionOR}" ] && [ ! "${InstII}" == "ii" ]; then
            Instalar "${Pack}"
          fi
        done
      fi
    fi
  fi

  echoe "Instalar openmediavault-kvm (requiere opción especial de instalación)" "Install openmediavault-kvm (requires special installation option)"
  Analizar openmediavault-kvm
  if [ ! "${VersionOR}" ]; then
    echoe "openmediavault-kvm no estaba instalado en el sistema original." "openmediavault-kvm was not installed on the original system."
  elif [ ! "${InstII}" ]; then
    echoe "\nHabilitando Backports... \n" "\nEnabling backports... \n"
    Backports YES
    echoe "\nInstalando openmediavault-kvm... \n" "\nInstall openmediavault-kvm... \n"
    if ! apt-get --yes --option DPkg::Options::="--force-confold" install openmediavault-kvm; then
      apt-get --yes --fix-broken install
      apt-get update
      if ! apt-get --yes --option DPkg::Options::="--force-confold" install openmediavault-kvm; then
        apt-get --yes --fix-broken install
        Salir "openmediavault-kvm no se pudo instalar. Saliendo..." "openmediavault-kvm could not be installed. Exiting..."
      fi
    fi
    ControlVersiones noesencial openmediavault-kvm
    if [ ! "${ControlVersiones}" ]; then
      Regenera "${CONFIG[openmediavault-kvm]}"
    fi
  fi

  echoe "Instalar resto de complementos" "Install rest of plugins"
  for i in "${COMPLEMENTOS[@]}"; do
    if [ ! "${InstII}" ]; then
      Instalar "$i"
      ControlVersiones noesencial "$i"
      if [ ! "${CONFIG[$i]}" ]; then
        echoe "\n${Rojo}ERROR >>> No existe la Configuración en omv-regen para regenerar el complemento $i. Probablemente es un complemento nuevo.${Reset}\n" "\n${Rojo}ERROR >>> There is no setting in omv-regen to regenerate the plugin $i. It's probably a new plugin.${Reset}\n"
      elif [ ! "${ControlVersiones}" ]; then
        Regenera "${CONFIG[$i]}"
      fi
    fi
  done
  echoe "Fase Nº6 terminada." "Phase No.6 completed."; sleep 1
  FASE[6]="hecho"; FASE[7]="iniciar"; GuardarAjustes
}

RegeneraFase7 () {
  echoe "\n>>>   >>>    FASE Nº7: RECONFIGURAR, ACTUALIZAR, LIMPIAR, CONFIGURAR RED, REINICIAR.\n" "\n>>>   >>>    PHASE Nº7: RECONFIGURE, UPDATE, WIPE, NETWORK SETUP, REBOOT.\n"
  echoe "Eliminando archivos temporales..." "Deleting temporary files..."
  [ -f "${ConfTmp}ori" ] && rm -f "${ConfTmp}ori"
  [ -f "${ConfTmp}" ] && rm -f "${ConfTmp}"
  [ -f "/tmp/installproxmox" ] && rm -f /tmp/installproxmox
  echoe "Restaurando carpetas de usuario..." "Restoring user folders..."
  if [ "${TarUserNumero}" ]; then
    i=1
    until [ $i -gt "${TarUserNumero}" ]; do
      tar -C / -xvf "${ORA[RutaOrigen]}/ORB_${FechaBackup}_user$i.tar.gz"
      ((i++))
    done
  fi
  echoe "Configurar red y reiniciar" "Configure network and reboot"
  echoe "Regenerando Red..." "Regenerating Network..."
  if [ "${ORA[Red]}" = "off" ]; then
    Info 10 "¡La regeneración ha finalizado!\n\nLa configuración activa en omv-regen es NO regenerar la interfaz de red.\nSe va a reiniciar el sistema para finalizar." "Regeneration is complete!\n\nThe active setting in omv-regen is to NOT regenerate the network interface.\nThe system will reboot to finish."
  else
    Info 10 "¡La regeneración ha finalizado!\n\nLa configuración activa en omv-regen es regenerar la interfaz de red.\nSe va a reiniciar el sistema para finalizar.\n${RojoD}La IP del sistema de origen era ${IpOR}${ResetD}\nDespués del reinicio puedes acceder al servidor en esa IP." "Regeneration is complete!\n\nThe active setting in omv-regen is to regenerate the network interface.\nThe system will reboot to finish.\n${RojoD}The IP of the original system was ${IpOR}${ResetD}\nAfter reboot you can access the server on that IP."
  fi
  if [ "${ComplementosNoInstalados}" ]; then
    Info 10 "Debido a una reciente actualización, la versión que tenía el servidor original y la versión disponible en internet para la instalación de:\n${ComplementosNoInstalados} \nno coinciden.\nEse o esos complementos no eran esenciales para el sistema y omv-regen los ha instalado pero no los ha regenerado, tendrás que configurarlo en la GUI de OMV. Si prefieres hacer una regeneración completa haz un nuevo backup actualizado del sistema original y comienza de nuevo." "Due to a recent update, the version that the original server had and the version available on the internet for:\n${ComplementosNoInstalados} \ninstallation do not match.\nThat plugin or plugins were not essential for the system and omv-regen has installed them but has not regenerated them, you will have to configure it in the OMV GUI. If you prefer to do a complete regeneration, make a new updated backup of the original system and start again."
  fi
  echoe "Fase Nº7 terminada." "Phase No.7 completed."; sleep 1
  FASE[7]="hecho"; GuardarAjustes
  Regenera "${CONFIG[dns]}"
  Regenera "${CONFIG[proxy]}"
  Regenera "${CONFIG[iptables]}"
  if [ "${ORA[Red]}" = "on" ]; then
    Regenera "${CONFIG[interfaces]}"
  fi
  omv-salt stage run prepare --quiet
  omv-salt stage run deploy --quiet
  omv-upgrade
  Limpiar
  reboot; sleep 5; exit
}

############################## INICIO ##################################

# Root
[[ $(id -u) -ne 0 ]] && Salir ayuda "Ejecuta omv-regen con sudo o como root.  Saliendo..." "Run omv-regen with sudo or as root.  Exiting..."

# Release 6.x.
[ ! "$(lsb_release --codename --short)" = "bullseye" ] && Salir ayuda "Versión no soportada.   Solo está soportado OMV 6.x.   Saliendo..." "Unsupported version.  Only OMV 6.x. are supported.  Exiting..."

# Comprobar si omv-regen está instalado
if [ ! "$0" = "${Omvregen}" ]; then
  [ -f "${Omvregen}" ] && rm "${Omvregen}"
  touch "${Omvregen}"
  wget -O - "${URLomvregen}" > "${Omvregen}"
  chmod +x "${Omvregen}"
  Salir ayuda "\n  Se ha instalado omv-regen ${ORVersion}\n" "\n  omv-regen ${ORVersion} has been installed.\n"
fi

# Generar/recuperar configuraciones de omv-regen
if [ ! -f "${ORAjustes}" ]; then
  [ ! -d "/etc/regen" ] && mkdir -p "/etc/regen"
  touch "${ORAjustes}"
  GuardarAjustes
else
  for i in "${!ORA[@]}"; do
    ORA[$i]=$(awk -F " : " -v i="$i" '$1 == i {print $2}' "${ORAjustes}")
  done
  unset CARPETAS
  unset FASE
  cont=0
  while IFS= read -r linea; do
    if [[ "$linea" == "Carpeta"* ]]; then
      CARPETAS[cont]="${linea:10}"
      ((cont++))
    fi
    if [[ "$linea" == "FASE"* ]]; then
      i="${linea:4:1}"
      FASE[i]="${linea:8}"
    fi
  done < "${ORAjustes}"
fi

# Comprobar estado de regenera
if [ "${FASE[1]}" = "iniciar" ]; then
  # Buscar actualizaciones de omv-regen
  [ "${ORA[Buscar]}" = "on" ] && BuscarOR
elif [ "${FASE[1]}" = "" ]; then
  Info 3 "El archivo de ajustes de omv-regen no se puede leer o ha sido manipulado." "The omv-regen settings file cannot be read or has been tampered with."
elif [ ! "${FASE[7]}" = "hecho" ]; then
  echoe "Hay una regeneración en progreso..." "There is a regeneration in progress..."
  Camino="EjecutarRegenera"
else
  unset FASE
  FASE[1]="iniciar"
  ORA[RutaRegen]=""
  ORA[FechaBackup]=""
  GuardarAjustes
fi

# Comprobar que no hay mas de un argumento y procesar
[ "$2" ] && Salir ayuda "\nArgumento inválido. Saliendo..." "\nInvalid argument. Exiting..."
case "$1" in
  backup)
    Cli="si"
    EjecutarBackup
    ;;
  regenera)
    Camino="EjecutarRegenera"
    ;;
  ayuda|help|-h|-help)
    Ayuda
    exit
    ;;
  "")
    ;;
  *)
    Salir ayuda "\nArgumento inválido. Saliendo..." "\nInvalid argument. Exiting..."
    ;;
esac

# MENU PRINCIPAL
while true; do
  if [ "${Camino}" = "MenuPrincipal" ]; then
    txt 1 "                      MENU PRINCIPAL OMV-REGEN " "                        OMV-REGEN MAIN MENU"
    txt 2 "--> Crear un backup del sistema actual.        " "--> Create a backup of the current system. "
    txt 3 "--> Modificar y guardar ajustes de Backup.     " "--> Modify and save Backup settings.       "
    txt 4 "--> Crear/eliminar tarea programada de backups." "--> Create/delete scheduled backup task.   "
    txt 5 "--> Regenerar sistema a partir de un Backup.   " "--> Regenerate a new system from a backup. "
    txt 6 "--> Modificar y guardar ajustes de Regenera.   " "--> Modify and save Regenera settings.     "
    txt 7 "--> Actualizar omv-regen.                      " "--> Update omv-regen.                      "
    txt 8 "--> Resetear ajustes.                          " "--> Reset settings.                        "
    txt 9 "--> Ayuda general.                             " "--> General help.                          "
    txt 10 "--> Salir de omv-regen.                       " "--> Exit omv-regen.                        "
    [ "${ORA[ActualizacionPendiente]}" ] && txt 11 "          ¡¡ HAY UNA ACTUALIZACION DISPONIBLE DE OMV-REGEN !!\n\n\n" "                AN UPDATE TO OMV-REGEN IS AVAILABLE !!\n\n\n" || txt 11 ""
    Camino=$(dialog \
      --backtitle "omv-regen ${ORVersion}" \
      --title "omv-regen ${ORVersion}" \
      --ok-label "${txt[Continuar]}" \
      --cancel-label "${txt[Salir]}" \
      --help-button \
      --help-label "${txt[Ayuda]}"\
      --stdout \
      --menu "\n${txt[11]}${txt[1]}\n " 0 0 9 \
      Backup "${txt[2]}" \
      "${txt[Backup_Ajustes]}" "${txt[3]}" \
      Regenera "${txt[5]}" \
      "${txt[Regenera_Ajustes]}" "${txt[6]}" \
      "${txt[Actualizar]}" "${txt[7]}" \
      "${txt[Resetear]}" "${txt[8]}" \
      "${txt[Ayuda]}" "${txt[9]}" \
      "${txt[Salir]}" "${txt[10]}")
    Salida=$?
    case $Salida in
      0)
        ;;
      1|255)
        Camino="Salir"
        ;;
      2)
        Camino="Ayuda"
    esac
  fi
  case "${Camino}" in
    MenuBackup|Backup)
      Camino="MenuBackup"; MenuBackup
      ;;
    BackupAjustes|"${txt[Backup_Ajustes]}")
      Camino="BackupAjustes"; BackupAjustes
      ;;
    MenuRegenera|Regenera)
      Camino="MenuRegenera"; MenuRegenera
      ;;
    RegeneraAjustes|"${txt[Regenera_Ajustes]}")
      Camino="RegeneraAjustes"; RegeneraAjustes
      ;;
    OpcionesActualizacion|"${txt[Actualizar]}")
      Camino="OpcionesActualizacion"; OpcionesActualizacion
      ;;
    Resetear|"${txt[Resetear]}")
      Pregunta "Esto eliminará todos los ajustes guardados de omv-regen,\nincluido el progreso de la regeneración si ya se ha iniciado.\n¿Estás seguro?" "This will delete all saved omv-regen settings,\nincluding the progress of the regeneration if it has already started.\nYou're sure?"
      if [ ! "${Pregunta}" ]; then
        ResetearAjustes; GuardarAjustes
        Info 3 "Se han eliminado todos los ajustes guardados." "All saved settings have been deleted."
      fi
      Camino="MenuPrincipal"
      ;;
    Ayuda|"${txt[Ayuda]}")
      Ayuda; Camino="MenuPrincipal"
      ;;
    Salir|"${txt[Salir]}")
      clear; exit
      ;;
    EjecutarBackup)
      EjecutarBackup; Camino="MenuPrincipal"
      ;;
    EjecutarRegenera)
      EjecutarRegenera; Camino="MenuPrincipal"
      ;;
    *)
      Camino="MenuPrincipal"
      ;;
  esac
done