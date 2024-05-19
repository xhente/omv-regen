#!/bin/bash
# -*- ENCODING: UTF-8 -*-

# This file is licensed under the terms of the GNU General Public
# License version 3. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

# omv-regen 7.0.14
# Utilidad para restaurar la configuración de openmediavault en otro sistema - Utility to restore openmediavault configuration to another system

ORVersion="7.0.14"

# Definicion de Variables - Definition of variables
. /etc/default/openmediavault
OmvVersion=$(dpkg -l openmediavault | awk '$2 == "openmediavault" { print substr($3,1,1) }')
Codename="$(lsb_release --codename --short)"
Fecha=""
Cli=""
Camino="MenuPrincipal"
Alto=30
Ancho=70

declare -A txt
declare -A ORA
declare -a FASE
declare -a CARPETAS
declare -a AYUDA

ResetearAjustes () {
  ORA[Idioma]="en"
  Idioma="$(printenv LANG)"
  [ "${Idioma:0:2}" = "es" ] && ORA[Idioma]="es"
  Idioma="$(awk -F "=" '/LANG=/ {print $2}' /etc/default/locale)"
  [ "${Idioma:0:2}" = "es" ] && ORA[Idioma]="es"
  [ "${Idioma:1:2}" = "es" ] && ORA[Idioma]="es"
  ORA[RutaBackup]="/ORBackup"
  ORA[Dias]='7'
  ORA[Actualizar]="Si"
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

# Actualizar Archivos de Ajustes existentes - Update Existing Settings Files
Idioma="${ORA[Idioma]}"

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
Reinicio=""
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
ComplementosNoRegenerados=""
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
declare -a SISTEMA_ARCHIVOS=("openmediavault-zfs" "openmediavault-lvm2" "openmediavault-mergerfs" "openmediavault-snapraid" "openmediavault-md" "openmediavault-remotemount" "openmediavault-mounteditor" "openmediavault-luksencryption")
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

# NODOS DE LA BASE DE DATOS                                                          - DATABASE NODES
# El primer valor es la ruta del nodo en la base de datos (nulo = el nodo no existe) - The first value is the path of the node in the database (null = node does not exist)
# Los siguientes valores son los módulos que debe actualizar salt                    - The following values ​​are the modules that salt should update

# Interfaz GUI - GUI interface
declare -A CONFIG
CONFIG[webadmin]="/config/webadmin monit nginx"
CONFIG[time]="/config/system/time chrony cron timezone"
# Nota: El estado de salt cronapt solo existe en OMV6. - Note: The cronapt salt state only exists in OMV6.
if [ "${OmvVersion}" = "6" ]; then
  CONFIG[email]="/config/system/email cronapt mdadm monit postfix smartmontools"
  CONFIG[notification]="/config/system/notification cronapt mdadm monit smartmontools zfszed"
else
  CONFIG[email]="/config/system/email mdadm monit postfix smartmontools"
  CONFIG[notification]="/config/system/notification cronapt mdadm monit smartmontools zfszed"
fi
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
CONFIG[fstab]="/config/system/fstab collectd fstab monit quota"
CONFIG[shares]="/config/system/shares sharedfolders systemd"
CONFIG[nfs]="/config/services/nfs avahi collectd fstab monit nfs quota"
CONFIG[rsync]="/config/services/rsync rsync avahi rsyncd"
CONFIG[smb]="/config/services/smb avahi samba"
CONFIG[ssh]="/config/services/ssh ssh avahi"
CONFIG[homedirectory]="/config/system/usermanagement/homedirectory samba"
CONFIG[users]="/config/system/usermanagement/users postfix rsync rsyncd samba systemd ssh"
CONFIG[groups]="/config/system/usermanagement/groups rsync rsyncd samba sharedfolders systemd"
CONFIG[syslog]="/config/system/syslog rsyslog"

# Complementos - Plugins
CONFIG[openmediavault-omvextras]="/config/system/omvextras"
CONFIG[openmediavault-anacron]="/config/services/anacron anacron"
CONFIG[openmediavault-apttool]="/config/services/apttool"
CONFIG[openmediavault-autoshutdown]="/config/services/autoshutdown autoshutdown"
CONFIG[openmediavault-backup]="/config/system/backup cron"
CONFIG[openmediavault-borgbackup]="/config/services/borgbackup borgbackup"
CONFIG[openmediavault-clamav]="/config/services/clamav clamav"
CONFIG[openmediavault-compose]="/config/services/compose compose"
CONFIG[openmediavault-cputemp]="nulo"
CONFIG[openmediavault-diskclone]="nulo"
CONFIG[openmediavault-diskstats]="nulo"
CONFIG[openmediavault-downloader]="/config/services/downloader"
CONFIG[openmediavault-fail2ban]="/config/services/fail2ban fail2ban"
CONFIG[openmediavault-filebrowser]="/config/services/filebrowser avahi filebrowser"
CONFIG[openmediavault-flashmemory]="nulo"
CONFIG[openmediavault-forkeddaapd]="/config/services/daap forked-daapd monit"
CONFIG[openmediavault-ftp]="/config/services/ftp avahi monit proftpd"
CONFIG[openmediavault-hosts]="/config/system/network/hosts hosts"
CONFIG[openmediavault-iperf3]="/config/services/iperf3 iperf3"
CONFIG[openmediavault-kernel]="nulo"
CONFIG[openmediavault-kvm]="/config/services/kvm"
CONFIG[openmediavault-locate]="nulo"
CONFIG[openmediavault-luksencryption]="nulo luks"
CONFIG[openmediavault-lvm2]="nulo collectd fstab monit quota"
CONFIG[openmediavault-md]="nulo initramfs mdadm collectd fstab monit quota"
CONFIG[openmediavault-mergerfs]="/config/services/mergerfs collectd fstab mergerfs monit quota"
CONFIG[openmediavault-minidlna]="/config/services/minidlna minidlna"
CONFIG[openmediavault-mounteditor]="nulo fstab monit"
CONFIG[openmediavault-nut]="/config/services/nut collectd monit nut"
CONFIG[openmediavault-onedrive]="/config/services/onedrive onedrive"
CONFIG[openmediavault-owntone]="/config/services/owntone owntone"
CONFIG[openmediavault-photoprism]="/config/services/photoprism avahi photoprism"
CONFIG[openmediavault-podman]="nulo"
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
CONFIG[openmediavault-webdav]="/config/services/webdav nginx webdav"
CONFIG[openmediavault-wakealarm]="/config/system/wakealarm wakealarm"
CONFIG[openmediavault-wetty]="/config/services/wetty avahi wetty"
CONFIG[openmediavault-wireguard]="/config/services/wireguard wireguard"
CONFIG[openmediavault-wol]="/config/services/wol"
CONFIG[openmediavault-zfs]="nulo zfszed collectd fstab monit quota nfs samba sharedfolders systemd tftpd-hpa"

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
# Nota: Evita que los cuadros de diálogo fallen - Note: Prevent dialog boxes from crashing
export NCURSES_NO_UTF8_ACS=1

############################################# TRADUCCIONES - TRANSLATIONS ####################################################

txt () {
  if [ "$3" ] && [ "${ORA[Idioma]}" = "en" ]; then
    txt[$1]="$3"
  else
    txt[$1]="$2"
  fi
}

Traducir () {
  if [ "${ORA[Idioma]}" = "es" ]; then
    export LANG=es_ES.UTF-8
    export LANGUAGE=es_ES.UTF-8
  else
    export LANG=C.UTF-8
    export LANGUAGE=C
  fi
  export LC_ALL=C.UTF-8

  txt Abortar "Abortar" "Abort"; txt Actualizar "Actualizar" "Update"; txt Ahora "Ahora" "Now"; txt Ajustar "Ajustar" "Adjust"; txt Ajustes "Ajustes" "Settings"
  txt Anterior "Anterior" "Previous"; txt Ayuda "Ayuda" "Help"; txt Backup_Ajustes "Backup_Ajustes" "Backup_Settings"; txt Buscar "Buscar" "Search"; txt Cancelar "Cancelar" "Cancel"
  txt Carpeta "Carpeta" "Folder"; txt Continuar "Continuar" "Continue"; txt Crear "Crear" "Create"; txt Dias "Días" "Days"; txt Ejecutar "Ejecutar" "Run"; txt Eliminar "Eliminar" "Delete"
  txt Idioma "Idioma" "Language"; txt Modificar "Modificar" "Modify"; txt Salir "Salir" "Exit"; txt Si "Si" "Yes"; txt Siempre "Siempre" "Always"; txt Siguiente "Siguiente" "Next"
  txt Red "Red" "Network"; txt Regenera_Ajustes "Regenera_Ajustes" "Regenera_Settings"; txt Resetear "Resetear" "Reset"; txt Ruta "Ruta" "Path";   txt Tarea "Tarea" "Task"
  txt Volver "Volver" "Go back"

txt AyudaOmvregen \
"\n \
\n          OMV-REGEN ES \
\n \
\n    omv-regen es una utilidad que se ejecuta en línea de comando (CLI) y que sirve para migrar/regenerar las configuraciones realizadas en la interfaz gráfica de usuario (GUI) de un sistema openmediavault (OMV) a otro sistema OMV. Es un script realizado en bash. \
\n \
\n    omv-regen se divide en dos funciones principales, ambas integradas en una interfaz gráfica de usuario, omv regen backup y omv-regen regenera. \
\n \
\n    omv-regen backup hace un backup de las configuraciones realizadas en la GUI del sistema original de OMV. Los archivos necesarios para hacer una regeneración del sistema se empaquetan en un archivo tar, fundamentalmente la base de datos y algunos otros archivos del sistema, además de otros generados por omv-regen que contienen información necesaria del sistema. \
\n \
\n    omv-regen regenera hace una regeneración de todas las configuraciones de la GUI de OMV del sistema original en un sistema nuevo de OMV a partir del backup realizado con omv-regen backup. Requiere realizar previamente una instalación limpia de OMV, preferiblemente en otro disco o pendrive diferente.\
\n \
\n \
\n          OMV-REGEN NO ES \
\n \
\n    omv-regen no es una utilidad para backup programado y restauración del sistema operativo en cualquier momento. Si necesitas un backup de openmediavault que puedas restaurar en cualquier momento utiliza el complemento openmediavault-backup. La razón de esto se explican detalladamente en el apartado \"Limitaciones de omv-regen\", pero el resumen es que necesitas un backup actualizado para poder restaurar con omv-regen. \
\n    Alternativamente puedes regenerar el sistema en otra unidad, por ejemplo un pendrive y seguir utilizando el disco/pendrive original, eso te proporcionaría un backup utilizable en cualquier momento. \
\n \
\n \
\n          OMV-REGEN ES ÚTIL PARA \
\n \
\n    - Reinstalar openmediavault en un disco nuevo o un hardware nuevo manteniendo las configuraciones. \
\n    - Migrar openmediavault entre diferentes arquitecturas, por ejemplo de una Raspberry a un sistema x86 o viceversa, pero cuidado, no todos los complementos son compatibles con todas las arquitecturas. \
\n    - Conseguir una instalación limpia de openmediavault tras un cambio de versiones de openmediavault. Si por ejemplo actualizas OMV5 a OMV6 y la actualización da problemas omv-regen puede trasladar la configuración a un sistema limpio.\
\n    - Reinstalar el sistema si se ha vuelto inestable por algún motivo, siempre que la base de datos esté en buen estado y el sistema pueda actualizarse a la última versión disponible. \
\n \
\n \
\n          LIMITACIONES DE OMV-REGEN \
\n \
\n    - Las configuraciones realizadas en CLI no se trasladarán al nuevo sistema, se perderán y tendrás que realizarlas de nuevo. omv-regen hace la regeneración a partir de la base de datos de OMV, y esta base de datos solo almacena las configuraciones que se han hecho en la GUI. Un usuario medio lo configurará todo mediante la GUI de OMV pero un usuario avanzado que haga configuraciones personalizadas en CLI debe tener esto en cuenta. \
\n    - Las versiones de openmediavault y de los complementos deben coincidir en el sistema original y el sistema nuevo. Para asegurar esto omv-regen actualizará el sistema original antes de hacer el backup y actualizará el sistema nuevo antes de regenerar. Puede ocurrir que entre el backup y la regeneración se produzca una actualización en los repositorios de OMV. En este caso, si las versiones de openmediavault o de uno de los complementos esenciales (relacionados con los sistemas de archivos) no coinciden la regeneración se detendrá. En este caso debes volver al sistema original y hacer un nuevo backup. Si ocurre eso con cualquier otro complemento no esencial, el complemento se instalará pero no se aplicarán sus configuraciones, la regeneración se completará pero dejando ese complemento listo para configurar manualmente en la GUI de OMV. \
\n" \
"\n \
\n          OMV-REGEN IS \
\n \
\n    omv-regen is a command line (CLI) utility that is used to migrate/regenerate the configurations made in the graphical user interface (GUI) of one openmediavault (OMV) system to another OMV system. It is a script made in bash. \
\n \
\n    omv-regen is divided into two main functions, both integrated into a graphical user interface, omv regen backup and omv-regen regenera. \
\n \
\n    omv-regen backup -> makes a backup of the configurations made in the GUI of the original OMV system. The files necessary to perform a system regeneration are packaged in a tar file, primarily the database and some other system files, as well as others generated by omv-regen that contain necessary system information. \
\n \
\n    omv-regen regenera -> regenerates all the OMV GUI configurations of the original system on a new OMV system from the backup made with omv-regen backup. It requires previously performing a clean installation of OMV, preferably on a different disk or pendrive.\
\n \
\n \
\n          OMV-REGEN IS NOT \
\n \
\n    omv-regen is not a utility for scheduled backup and restore of the operating system at any time. If you need an openmediavault backup that you can restore at any time, use the openmediavault-backup plugin. The reason for this is explained in detail in the \"Limitations of omv-regen\" section, but the summary is that you need an updated backup to be able to restore with omv-regen. \
\n    Alternatively, you can regenerate the system on another drive, for example a pendrive, and continue using the original disk/pendrive, which would provide you with a usable backup at any time. \
\n \
\n \
\n          OMV-REGEN IS USEFUL FOR \
\n \
\n    - Reinstall openmediavault on a new disk or new hardware keeping the configurations. \
\n    - Migrate openmediavault between different architectures, for example from a Raspberry to an x86 system or vice versa, but be careful, not all plugins are compatible with all architectures. \
\n    - Get a clean installation of openmediavault after a change of openmediavault versions. If, for example, you update OMV5 to OMV6 and the update causes problems, omv-regen can move the configuration to a clean system.\
\n    - Reinstall the system if it has become unstable for any reason, as long as the database is healthy and the system can be updated to the latest available version. \
\n \
\n \
\n          LIMITATIONS OF OMV-REGEN \
\n \
\n    - Configurations made in CLI will not be carried over to the new system, they will be lost and you will have to make them again. omv-regen does the regeneration from the OMV database, and this database only stores the configurations that have been made in the GUI. An average user will configure everything using the OMV GUI but an advanced user doing custom configurations in the CLI should keep this in mind. \
\n    - The openmediavault and plug-in versions must match on the original system and the new system. To ensure this omv-regen will update the original system before doing the backup and will update the new system before regenerating. It may happen that between the backup and the regeneration, an update occurs in the OMV repositories. In this case, if the versions of openmediavault or one of the essential plugins (related to file systems) do not match, the regeneration will stop. In this case you must return to the original system and make a new backup. If that happens with any other non-essential plugin, the plugin will be installed but its configurations will not be applied, the regeneration will complete but leaving that plugin ready to be manually configured in the OMV GUI."

txt AyudaComoUsar \
"\n \
\n          COMO USAR OMV-REGEN \
\n \
\n    El procedimiento básico se resume en tres pasos: \
\n \
\n          PASO 1. Crea un backup del sistema original con omv-regen. \
\n          PASO 2. Haz una instalación nueva de OMV en el disco que quieras y conecta las unidades de datos originales. \
\n          PASO 3. Utiliza omv-regen para migrar las configuraciones del sistema original al nuevo sistema. \
\n \
\n    ${AzulD}Paso 1. Crear un backup.${ResetD} \
\n          - Inicia sesión por ssh en el sistema original, por ejemplo con putty. \
\n          - Instala omv-regen en el sistema original. Ejecuta -> sudo wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | sudo bash \
\n          - Ejecuta el comando omv-regen y sigue las indicaciones de la interfaz gráfica de usuario para crear un backup. Marca la opción para actualizar el sistema antes de hacer el backup. omv-regen creará un archivo comprimido con tar que contiene los archivos necesarios para regenerar el sistema. Si has elegido opcionalmente alguna carpeta se creará otro archivo comprimido por cada carpeta elegida. Los archivos de cada backup están etiquetados en el nombre con fecha y hora.\
\n          - Copia el backup a tu escritorio, por ejemplo con WinSCP. El archivo del backup es muy pequeño y se mueve instantáneamente. \
\n \
\n    ${AzulD}Paso 2. Haz una instalación limpia de openmediavault.${ResetD} \
\n          - Instala openmediavault en un disco o pendrive diferente al original. Conserva el disco original, de esta forma podrás volver al sistema original en cualquier momento. \
\n          - Apaga el sistema. Conecta los discos de datos. Inicia el sistema. No hagas nada mas, no configures nada. \
\n \
\n    ${AzulD}Paso 3. Migrar las configuraciones al nuevo sistema.${ResetD} \
\n          - Inicia sesión por ssh en el nuevo sistema, por ejemplo con putty. \
\n          - Instala omv-regen en el nuevo sistema. Ejecuta -> sudo wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | sudo bash \
\n          - Crea una carpeta en el nuevo sistema y copia el backup a esa carpeta, por ejemplo con WinSCP. \
\n          - Ejecuta el comando omv-regen y sigue las indicaciones de la interfaz gráfica de usuario para hacer la regeneración. Puedes elegir no configurar la red o no instalar el kernel proxmox si estaba instalado en el sistema original. Es posible que se requiera un reinicio durante el proceso, si es así omv-regen te pedirá hacerlo, después del reinicio ejecuta de nuevo omv-regen, el proceso seguirá su curso automáticamente. \
\n          - omv-regen reiniciará el sistema cuando la regeneración finalice. Accede a la GUI de OMV en un navegador y comprueba que todo está como esperabas. Si no puedes acceder presiona Ctrl+Mays+R para borrar la caché del navegador, si es necesario repítelo varias veces. \
\n \
\n    ${AzulD}El resultado de la regeneración será el siguiente:${ResetD} \
\n          - Todas las configuraciones realizadas en la GUI de OMV en el sistema original se replicarán en el sistema nuevo. Esto incluye usuarios y contraseñas, sistemas de archivos, docker y contenedores configurados con el complemento compose, etc. Asegúrate de que los datos persistentes de los contenedores residan en un disco independiente, si están en el disco del sistema operativo debes incluir esa carpeta en el backup de omv-regen si no quieres perderlos. \
\n          - NO incluye cualquier configuración realizada en CLI fuera de la GUI de OMV. Usa otros medios para respaldar eso. \
\n          - NO incluye contenedores configurados en Portainer. Deberás recrearlos tu mismo. \
\n          - Los complementos Filebrowser y Photoprism son contenedores podman. No se respaldarán, usa otros medios.
\n          - Puedes consultar los registros del último mes en el archivo /var/log/omv-regen.log" \
"\n \
\n          HOW TO USE OMV-REGEN \
\n \
\n    The basic procedure is summarized in three steps: \
\n \
\n          STEP 1. Create a backup of the original system with omv-regen. \
\n          STEP 2. Do a fresh installation of OMV on the desired disk and connect the original data drives. \
\n          STEP 3. Use omv-regen to migrate the settings from the original system to the new system. \
\n \
\n    ${AzulD}Step 1. Create a backup.${ResetD} \
\n          - Log in via ssh on the original system, for example with putty. \
\n          - Install omv-regen on the original system. Run -> sudo wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | sudo bash \
\n          - Run the omv-regen command and follow the GUI prompts to create a backup. Check the option to update the system before making the backup. omv-regen will create a tar archive containing the files needed to regenerate the system. If you have optionally chosen a folder, another compressed file will be created for each folder chosen. The files in each backup are labeled in name with date and time.\
\n          - Copy the backup to your desktop, for example with WinSCP. The backup file is very small and moves instantly. \
\n \
\n    ${AzulD}Step 2. Do a clean install of openmediavault.${ResetD} \
\n          - Install openmediavault on a disk or pendrive different from the original one. Keep the original disk, this way you can return to the original system at any time. \
\n          - Turn off the system. Connect the data disks. Start the system. Don't do anything else, don't configure anything. \
\n \
\n    ${AzulD}Step 3. Migrate configurations to the new system.${ResetD} \
\n          - Log in via ssh to the new system, for example with putty. \
\n          - Install omv-regen on the new system. Run -> sudo wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | sudo bash \
\n          - Create a folder on the new system and copy the backup to that folder, for example with WinSCP. \
\n          - Run the omv-regen command and follow the GUI prompts to do the regeneration. You can choose not to configure networking or not install the proxmox kernel if it was installed on the original system. A reboot may be required during the process, if so omv-regen will ask you to do so, after the reboot run omv-regen again, the process will continue automatically. \
\n          - omv-regen will reboot the system when the regeneration is complete. Access the OMV GUI in a browser and check that everything is as you expected. If you cannot access press Ctrl+Shift+R to clear the browser cache, if necessary repeat it several times. \
\n \
\n    ${AzulD}The result of the regeneration will be the following:${ResetD} \
\n          - All configurations made in the OMV GUI on the original system will be replicated on the new system. This includes users and passwords, filesystems, docker and containers configured with the compose plugin, etc. Make sure that the persistent data in the containers resides on a separate disk, if it is on the operating system disk you must include that folder in the omv-regen backup if you do not want to lose it. \
\n          - It does NOT include any configuration done in CLI outside of the OMV GUI. Use other means to support that. \
\n          - Does NOT include containers configured in Portainer. You will have to recreate them yourself. \
\n          - Filebrowser and Photoprism plugins are podman containers. They will not be backed up, use other means. \
\n          - You can check the logs for the last month in the file /var/log/omv-regen.log" \

txt AyudaFunciones \
"\n \
\n          FUNCIONES DE OMV-REGEN \
\n \
\n  1 - ${AzulD}omv-regen${ResetD} - Abre la interfaz gráfica con los menús de configuración y ejecución de cualquier función de omv-regen. La GUI te guiará para ejecutar un backup o una regeneración. \
\n \
\n  2 - ${AzulD}omv-regen backup${ResetD} - Realiza un backup muy ligero de los datos esenciales para regenerar las configuraciones de un sistema OMV. Puedes incluir carpetas opcionales, incluso de tus discos de datos, y definir el destino. Previamente debes configurar los parámetros del backup en la GUI de omv-regen, una vez configurado puedes ejecutar omv-regen backup en CLI o programar una tarea en la GUI de OMV para automatizar backups. \
\n \
\n  3 - ${AzulD}omv-regen regenera${ResetD} - Realiza una regeneración de un sistema completo OMV con sus configuraciones originales a partir de una instalación nueva de OMV y el backup del sistema original realizado con omv-regen backup. Ejecuta omv-regen en línea de comando y la interfaz te guiará para configurar los parámetros y ejecutar la regeneración. Después puedes ejecutarla desde el menú o desde CLI con el comando omv-regen regenera \
\n \
\n  4 - ${AzulD}omv-regen ayuda${ResetD} - Acceso a los cuadros de diálogo con la ayuda completa de omv-regen." \
"\n \
\n          OMV-REGEN FEATURES \
\n \
\n  1 - ${AzulD}omv-regen${ResetD} - Opens the graphical interface with the configuration and execution menus for any omv-regen function. The GUI will guide you to run a backup or regeneration. \
\n \
\n  2 - ${AzulD}omv-regen backup${ResetD} - Performs a very light backup of essential data to regenerate the configurations of an OMV system. You can include optional folders, even from your data disks, and define the destination. You must previously configure the backup parameters in the omv-regen GUI, once configured you can run omv-regen backup in the CLI or schedule a task in the OMV GUI to automate backups. \
\n \
\n  3 - ${AzulD}omv-regen regenera${ResetD} - Regenerates a complete OMV system with its original configurations from a fresh OMV installation and the backup of the original system made with omv-regen backup. Run omv-regen on the command line and the interface will guide you to configure the parameters and run the regeneration. Then you can run it from the menu or from CLI with the command: omv-regen regenera \
\n \
\n  4 - ${AzulD}omv-regen ayuda${ResetD} - Access to dialogs with full omv-regen help."

txt AyudaConsejos \
"\n \
\n          ALGUNOS CONSEJOS \
\n \
\n    ${AzulD}- CARPETAS OPCIONALES:${ResetD}    Si eliges carpetas opcionales asegúrate de que no son carpetas de sistema. O, si lo son, al menos asegúrate de que no dañarán el sistema cuando se copien al disco de OMV. Sería una lástima romper el sistema por esto una vez regenerado. \
\n \
\n    ${AzulD}- COMPLEMENTOS FILEBROWSER Y PHOTOPRISM:${ResetD}    Si utilizas los complementos Filebrowser o Photoprism o cualquier otro basado en podman debes buscar medios alternativos para respaldarlos, omv-regen no los respaldará. omv-regen los instalará y regenerará las configuraciones de la base de datos de OMV, esto incluye las configuraciones de la GUI de OMV, carpeta compartida, puerto de acceso al complemento, etc. Pero las configuraciones internas de los dos contenedores se perderán. Tal vez sea suficiente con incluir la carpeta donde reside la base de datos del contenedor para que omv-regen también la restaure. Esto no garantiza nada, solo es una sugerencia no probada. \
\n \
\n    ${AzulD}- OPENMEDIAVAULT-APTTOOL:${ResetD}    Si tienes algún paquete instalado manualmente, por ejemplo lm-sensors, y quieres que también se instale al mismo tiempo puedes usar el complemento apttool. omv-regen instalará los paquetes que se hayan instalado mediante este complemento. \
\n \
\n    ${AzulD}- OPENMEDIAVAULT-SYMLINK:${ResetD}    Si usas symlinks en tu sistema omv-regen los recreará si se generaron con el complemento. Si lo hiciste de forma manual en CLI tendrás que volver a hacerlo en el sistema nuevo. \
\n \
\n    ${AzulD}- HAZ LA REGENERACION INMEDIATAMENTE DESPUÉS DEL BACKUP:${ResetD}    Debes hacer el backup y de forma inmediata hacer la regeneración para evitar diferencias entre versiones de paquetes. Ver Limitaciones de omv-regen. \
\n \
\n    ${AzulD}- UNIDAD DE SISTEMA DIFERENTE:${ResetD}    Es muy recomendable utilizar una unidad de sistema diferente a la original para instalar OMV en el sistema nuevo. Es muy sencillo usar un pendrive para instalar openmediavault. Si tienes la mala suerte de que se publique una actualización de un paquete esencial entre el momento del backup y el momento de la regeneración no podrás terminar la regeneración, y necesitarás el sistema original para hacer un nuevo backup actualizado. \
\n \
\n    ${AzulD}- CONTENEDORES DOCKER:${ResetD}    Toda la información que hay en el disco de sistema original va a desaparecer. Para conservar los contenedores docker en el mismo estado asegúrate de hacer algunas cosas antes. Cambia la ruta de instalación por defecto de docker desde la carpeta /var/lib/docker a una carpeta en alguno de los discos de datos. Configura todos los volumenes de los contenedores fuera del disco de sistema, en alguno de los discos de datos. Estas son recomendaciones generales, pero en este caso con mas motivo, si no lo haces perderás esos datos. Alternativamente puedes añadir carpetas opcionales al backup." \
"\n \
\n          SOME ADVICES \
\n \
\n    ${AzulD}- OPTIONAL FOLDERS:${ResetD}    If you choose optional folders make sure they are not system folders. Or, if they are, at least make sure they won't harm your system when copied to the OMV disk. It would be a shame to break the system for this once regenerated. \
\n \
\n    ${AzulD}- FILEBROWSER AND PHOTOPRISM PLUGINS:${ResetD}    If you use the Filebrowser or Photoprism plugins or any other based on podman you should find alternative means to back them up, omv-regen will not support them. omv-regen will install them and regenerate the OMV database configurations, this includes the OMV GUI configurations, shared folder, plugin access port, etc. But the internal configurations of the two containers will be lost. It may be enough to include the folder where the container database resides so that omv-regen will restore it as well. This does not guarantee anything, it is just an untested suggestion. \
\n \
\n    ${AzulD}- OPENMEDIAVAULT-APTTOOL:${ResetD}    If you have a package installed manually, for example lm-sensors, and you want it to also be installed at the same time you can use the apttool plugin. omv-regen will install packages that have been installed using this plugin. \
\n \
\n    ${AzulD}- OPENMEDIAVAULT-SYMLINK:${ResetD}    If you use symlinks on your system omv-regen will recreate them if they were generated with the plugin. If you did it manually in CLI you will have to do it again in the new system. \
\n \
\n    ${AzulD}- DO THE REGENERATION IMMEDIATELY AFTER THE BACKUP:${ResetD}    You must make the backup and immediately do the regeneration to avoid differences between package versions. See Limitations of omv-regen. \
\n \
\n    ${AzulD}- DIFFERENT SYSTEM UNIT:${ResetD}    It is highly recommended to use a different system drive than the original one to install OMV on the new system. It is very easy to use a pendrive to install openmediavault. If you are unlucky enough that an update to an essential package is released between the time of the backup and the time of the rebuild, you will not be able to finish the rebuild, and you will need the original system to make a new updated backup. \
\n \
\n    ${AzulD}- DOCKER CONTAINERS:${ResetD}    All the information on the original system disk will disappear. To keep your docker containers in the same state make sure you do a few things first. Change the default docker installation path from the /var/lib/docker folder to a folder on one of the data disks. Configure all container volumes off the system disk, on one of the data disks. These are general recommendations, but in this case even more so, if you don't do it you will lose that data. Alternatively you can add optional folders to the backup."

txt AyudaBackup \
"\n \
\n          OPCIONES DE OMV-REGEN BACKUP \
\n \
\n    ${AzulD}- RUTA DE LA CARPETA DE BACKUPS:${ResetD}    Esta carpeta se usará para almacenar todos los backups generados. Por defecto esta carpeta es /ORBackup, puedes usar la que quieras pero no uses los discos de datos si pretendes hacer una regeneración, no serán accesibles en ese momento. Para hacer una regeneración es mejor copiar el backup directamente a tu escritorio con WinSCP o similar y luego copiarla al sistema nuevo. En esta carpeta omv-regen creará un archivo empaquetado con tar para cada backup, etiquetado con la fecha y la hora en el nombre. Si has incluido carpetas opcionales en el backup se crearán archivos adicionales también empaquetados con tar y con la etiqueta user1, user2,... Las subcarpetas tienen el prefijo ORB_ en su nombre. Si quieres conservar alguna versión de backup en particular y que omv-regen no la elimine puedes editar este prefijo a cualquier otra cosa y no se eliminará esa subcarpeta. Puedes utilizar omv-regen backup para programar backups con tareas programadas en la GUI de OMV. Se aplicará la configuración guardada. Un backup completo con dos carpetas opcionales hecho el día 1 de octubre de 2023 a las 10:38 a.m. podría tener este aspecto: \
\n         ${AzulD}ORB_231001_103828_regen.tar.gz${ResetD}    <-- Archivo con la información de regenera \
\n         ${AzulD}ORB_231001_103828_user1.tar.gz${ResetD}    <-- Archivo con la carpeta opcional 1 de usuario \
\n         ${AzulD}ORB_231001_103828_user2.tar.gz${ResetD}    <-- Archivo con la carpeta opcional 2 de usuario \
\n \
\n    ${AzulD}- DIAS QUE SE CONSERVAN LOS BACKUPS:${ResetD}    Esta opción establece el número de días máximo para conservar backups. Cada vez que hagas un backup se eliminarán todos aquellos existentes en la misma ruta con mas antigüedad de la configurada, mediante el escaneo de fechas de todos los archivos con el prefijo ORB_ Se establece un valor en días. El valor por defecto son 7 días. \
\n \
\n    ${AzulD}- ACTUALIZAR EL SISTEMA:${ResetD}    Esta opción hará que el sistema se actualice automáticamente justo antes de realizar el backup. Asegúrate que esté activa si tu intención es hacer un backup para proceder a una regeneración inmediatamente después. Desactívala si estás haciendo backups programados. El valor establecido debe ser Si/on o No/off. \
\n \
\n    ${AzulD}- CARPETAS ADICIONALES:${ResetD}    Puedes definir tantas carpetas opcionales como quieras que se incluirán en el backup. Útil si tienes información que quieres transferir al nuevo sistema que vas a regenerar. Si copias carpetas con configuraciones del sistema podrías romperlo. Estas carpetas se devolverán a su ubicación original en la parte final del proceso de regeneración. Se crea un archivo tar comprimido para cada carpeta etiquetado de la misma forma que el resto del backup. Puedes incluir carpetas que estén ubicadas en los discos de datos. Puesto que la restauración de estas carpetas se hace al final del proceso, en ese momento todos los sistemas de archivos ya están montados y funcionando. La carpeta /root se incluirá por defecto en el backup." \
"\n \
\n          OMV-REGEN BACKUP OPTIONS \
\n \
\n    ${AzulD}- BACKUP FOLDER PATH:${ResetD}    This folder will be used to store all the backups generated. By default this folder is /ORBackup, you can use whatever you want but do not use the data disks if you intend to do a regeneration, they will not be accessible at that time. To do a regeneration it is better to copy the backup directly to your desktop with WinSCP or similar and then copy it to the new system. In this folder omv-regen will create a tar-packaged archive for each backup, labeled with the date and time in the name. If you have included optional folders in the backup, additional files will be created, also packaged with tar and labeled user1, user2,... The subfolders have the ORB_ prefix in their name. If you want to keep a particular backup version and not have omv-regen delete it, you can edit this prefix to anything else and that subfolder will not be deleted. You can use omv-regen backup to schedule backups with scheduled tasks in the OMV GUI. The saved settings will be applied. A full backup with two optional folders made on October 1, 2023 at 10:38 a.m. could look like this: \
\n         ${AzulD}ORB_231001_103828_regen.tar.gz${ResetD}    <-- File with regenera information \
\n         ${AzulD}ORB_231001_103828_user1.tar.gz${ResetD}    <-- File with optional user folder 1 \
\n         ${AzulD}ORB_231001_103828_user2.tar.gz${ResetD}    <-- File with optional user folder 2 \
\n \
\n    ${AzulD}- DAYS BACKUPS ARE KEPT:${ResetD}    This option establishes the maximum number of days to keep backups. Every time you make a backup, all those existing in the same path that are older than the configured one will be eliminated, by scanning the files of all the files with the ORB_ prefix. A value is established in days. The default value is 7 days. \
\n \
\n    ${AzulD}- UPDATE SYSTEM:${ResetD}  This option will cause the system to update automatically just before performing the backup. Make sure it is active if your intention is to make a backup to proceed with a regeneration immediately afterwards. Disable it if you are doing scheduled backups. The set value must be Yes/on or No/off. \
\n \
\n    ${AzulD}- ADDITIONAL FOLDERS:${ResetD}    You can define as many optional folders as you want that will be included in the backup. Useful if you have information that you want to transfer to the new system that you are going to regenerate. If you copy folders with system settings you could break it. These folders will be returned to their original location in the final part of the regeneration process. A compressed tar file is created for each folder labeled the same as the rest of the backup. You can include folders that are located on the data disks. Since the restoration of these folders is done at the end of the process, at that point all file systems are already mounted and working. The /root folder is included by default in the backup."

txt AyudaRegenera \
"\n \
\n          OPCIONES DE OMV-REGEN REGENERA \
\n \
\n    ${AzulD}- RUTA BACKUP DE ORIGEN:${ResetD}    En el menú debes definir la ubicación de esta carpeta. Por defecto será /ORBackup pero puedes elegir la ubicación que quieras. Esta carpeta debe contener al menos un archivo tar generado con omv-regen. Antes de ejecutar una regeneración el programa comprobará que esta carpeta contiene todos los archivos necesarios para la regeneración. Cuando definas una ruta en el menú omv-regen escaneará los archivos de esa ruta y buscará el backup mas reciente. Una vez localizado el backup, omv-regen comprobará que en su interior están todos los archivos necesarios. Si falta algún archivo la ruta no se dará por válida y no se permitirá continuar adelante. \
\n \
\n    ${AzulD}- INSTALAR KERNEL PROXMOX:${ResetD}    Si el sistema original tenía el kernel proxmox instalado tendrás la opción de decidir si quieres instalarlo también en el sistema nuevo o no. Cuando la regeneración esté en funcionamiento, si esta opción está activada se instalará el kernel a mitad de proceso. En ese momento omv-regen te pedirá que reinicies el sistema. Después de eso debes ejecutar de nuevo omv-regen y la regeneración continuará en el punto en que se detuvo. Ten en cuenta que si tienes un sistema de archivos ZFS o usas kvm es recomendable tener este kernel instalado, en caso contrario podrías tener problemas durante la instalación de estos dos complementos. Si desactivas esta opción el kernel proxmox no se instalará en el sistema nuevo. \
\n \
\n    ${AzulD}- REGENERAR LA INTERFAZ DE RED:${ResetD}    Esta opción sirve para omitir la regeneración de la interfaz de red. Si desactivas esta opción no se regenerará la interfaz de red y la IP seguirá siendo la misma que tiene el sistema después del reinicio al final del proceso. Si activas esta opción se regenerará la interfaz de red al final del proceso de regeneración. Si la IP original es distinta de la IP actual deberás conectarte a la IP original después del reinicio para acceder a OMV. El menú te indica cual será esta IP antes de iniciar la regeneración. Cuando finalice la regeneración también la tendrás en pantalla pero podrías no verla si no estás atento." \
"\n \
\n          OMV-REGEN REGENERA OPTIONS \
\n \
\n    ${AzulD}- SOURCE BACKUP PATH:${ResetD}    In the menu you must define the location of this folder. By default it will be /ORBackup but you can choose the location you want. This folder must contain at least one tar file generated with omv-regen. Before executing a regeneration, the program will check that this folder contains all the files necessary for the regeneration. When you define a path in the menu omv-regen will scan the files in that path and look for the most recent backup. Once the backup is located, omv-regen will check that all the necessary files are inside. If any file is missing, the route will not be considered valid and you will not be allowed to continue further. \
\n \
\n    ${AzulD}- INSTALL PROXMOX KERNEL:${ResetD}    If the original system had the proxmox kernel installed you will have the option to decide if you want to also install it on the new system or not. When regeneration is running, if this option is enabled it will install the kernel mid-process. At that point omv-regen will ask you to reboot the system. After that you have to run omv-regen again and the regeneration will continue from the point where it stopped. Keep in mind that if you have a ZFS file system or use kvm it is recommended to have this kernel installed, otherwise you could have problems installing these two plugins. If you disable this option the proxmox kernel will not be installed on the new system. \
\n \
\n    ${AzulD}- REGENERATE THE NETWORK INTERFACE:${ResetD}    This option is used to skip regenerating the network interface. If you deactivate this option, the network interface will not be regenerated and the IP will remain the same as the system's after the reboot at the end of the process. If you activate this option, the network interface will be regenerated at the end of the regeneration process. If the original IP is different from the current IP you will need to connect to the original IP after the reboot to access OMV. The menu tells you what this IP will be before starting the regeneration. When the regeneration ends you will also have it on the screen but you may not see it if you are not attentive."

  AYUDA=("${txt[AyudaOmvregen]}" "${txt[AyudaComoUsar]}" "${txt[AyudaFunciones]}" "${txt[AyudaConsejos]}" "${txt[AyudaBackup]}" "${txt[AyudaRegenera]}")
  if [ "${ORA[Actualizar]}" = "Si" ] || [ "${ORA[Actualizar]}" = "Yes" ]; then
    ORA[Actualizar]="${txt[Si]}"
  fi
}

########################################## MENUS #################################################

Ayuda () {
  i=0
  while [ "${AYUDA[i]}" ]; do
    dialog \
      --backtitle "omv-regen ${ORVersion} ${txt[Ayuda]}" \
      --title "omv-regen ${ORVersion} ${txt[Ayuda]}" \
      --yes-label "${txt[Siguiente]}" \
      --no-label "${txt[Salir]}" \
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

# MENU BACKUP - BACKUP MENU
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
      --yes-label "${txt[Ejecutar]}" \
      --no-label "${txt[Volver]}" \
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

# MENU DE AJUSTES DE BACKUP - BACKUP SETTINGS MENU
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

  # Opciones Backup - Backup Options
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

  # Carpetas adicionales Backup - Additional folders Backup
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

# MENU AÑADIR CARPETA OPCIONAL A BACKUP - MENU ADD OPTIONAL FOLDER TO BACKUP
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

# MENU REGENERA - REGENERA MENU
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
      --yes-label "${txt[11]}" \
      --extra-button \
      --extra-label "${txt[12]}" \
      --no-label "${txt[13]}" \
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

# MENU DE AJUSTES REGENERA - REGENERA SETTINGS MENU
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
        ORA[Kernel]="off"; ORA[Red]="off"
        [ "$(echo "$Respuesta" | grep Kernel)" ] && ORA[Kernel]="on"
        [ "$(echo "$Respuesta" | grep "${txt[Red]}")" ] && ORA[Red]="on"
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

# MENU DE OPCIONES DE ACTUALIZACION DE OMV-REGEN - OMV-REGEN UPDATE OPTIONS MENU
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
      [ "$(echo "$Respuesta" | grep "${txt[Buscar]}")" ] && ORA[Buscar]="on"; [ ! "${ORA[Buscar]}" = "on" ] && ORA[Buscar]="off"
      [ "$(echo "$Respuesta" | grep "${txt[Siempre]}")" ] && ORA[Siempre]="on"; [ ! "${ORA[Siempre]}" = "on" ] && ORA[Siempre]="off"
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

# MENU PARA CAMBIAR EL IDIOMA ESPAÑOL/INGLES - MENU TO CHANGE THE SPANISH/ENGLISH LANGUAGE
CambiarIdioma () {
  txt 1 "Cambiar idioma" "Change language"
  txt 2 "Español  Spanish" "Spanish  Español"
  txt 3 "Inglés   English" "English  Inglés"
  Respuesta=$(dialog \
    --backtitle "omv-regen ${ORVersion}" \
    --title "${txt[1]}" \
    --ok-label "${txt[Continuar]}" \
    --cancel-label "${txt[Cancelar]}" \
    --stdout \
    --radiolist  "\n " 0 0 2 \
    1 "${txt[2]}" on \
    2 "${txt[3]}" off)
  Salida=$?
  case $Salida in
    0)
      [ "${Respuesta}" = 1 ] && ORA[Idioma]=es
      [ "${Respuesta}" = 2 ] && ORA[Idioma]=en
      Traducir; GuardarAjustes
      ;;
    1|255)
      Info 3 "Operación cancelada. No se han guardado los cambios." "Operation cancelled. Changes have not been saved."
      ;;
  esac
}

################################### FUNCIONES - FUNCTIONS #######################################

# Validar ajustes de Backup                                                   - Validate Backup settings
# Devuelve ValidarBackup="" si todo es correcto y ValidarBackup="si" si falla - Returns ValidarBackup="" if everything is correct and ValidarBackup="si" if it fails
# Sale si se ha entrado desde CLI y los ajustes no son correctos              - Exits if it was entered from CLI and the settings are not correct.
ValidarBackup () {
  ValidarBackup=""; ValBacRuta=""; ValRutaEsc="" ValDias=""; ValCarpetas=""
  # Comprueba si existe la ruta para el backup - Check if the backup path exists
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
  # Comprueba rutas de Carpetas opcionales - Check Optional Folder paths
  for i in "${CARPETAS[@]}"; do
    if [ ! -d "$i" ]; then
      ValCarpetas="si"
    fi
  done
  # Comprueba formatos de valores - Check value formats
  if [[ "${ORA[Dias]}" =~ ^[0-9]+$ ]]; then
    ValDias=""
  else
    ValDias="si"; ValidarBackup="si"
  fi
  SiNo "${ORA[Actualizar]}"
  ORA[Actualizar]="${SiNo}"
  [ ! "${ORA[Actualizar]}" ] && ValidarBackup="si"
  # Salida CLI - CLI exit
  if [ "${ValidarBackup}" ] && [ "${Cli}" ]; then
    Salir "${Rojo}Los ajustes establecidos no son válidos${Reset}. Ejecuta ${Verde}omv-regen${Reset} sin argumentos para modificarlos.\nSaliendo..." "${Rojo}The established settings are not valid${Reset}. Run ${Verde}omv-regen${Reset} with no arguments to adjust them.\nExiting..."
  fi
}

# Validar ajustes de Regenera                                                     - Validate Regenera settings
# Devuelve ValidarRegenera="" si todo es correcto y ValidarRegenera="si" si falla - Returns ValidarRegenera="" if everything is correct and ValidarRegenera="si" if it fails.
ValidarRegenera () {
  ValidarRegenera=""; ValRegRuta=""; ValFechaBackup=""; TarRegen=""; ValDpkg=""; ValRegCont=""; ValRegDiscos=""; ValRegRootfs=""; IpOR=""; IpAC=""; KernelOR=""; FechaBackup=""; TarUserNumero=""; Discos=""; Dev=""; RootfsAC=""; RootfsOR=""; DiscosAC=""; DiscosOR=""; Serial=""; DpkgAC=""

  # Validar Ruta de Backup de origen - Validate Source Backup Path
  TarRegen="$(find "${ORA[RutaOrigen]}" -name 'ORB_*_regen.tar.gz' | sort -r | awk -F "/" 'NR==1{print $NF}')"
  if [ "${TarRegen}" = "" ]; then
    ValidarRegenera="si"; ValRegRuta="si"
  else
    # Comprobar si el backup contiene todos los archivos - Check if the backup contains all the files
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
    # Comprobar si hay carpetas opcionales en el backup - Check if there are optional folders in the backup
    FechaBackup="$(echo "${TarRegen}" | awk -F "_" 'NR==1{print $2"_"$3}')"
    TarUserNumero="$(find "${ORA[RutaOrigen]}" -name "ORB_${FechaBackup}"'_user*.tar.gz' | awk 'END {print NR}')"
    [ "${TarUserNumero}" = 0 ] && TarUserNumero=""
    # Comprobar si el sistema original tenía kernel proxmox - Check if the original system had proxmox kernel
    tar -C /tmp -xvf "${ORA[RutaOrigen]}/${TarRegen}" "regen_${FechaBackup}/ORB_Unamea" >/dev/null
    KernelOR=$(awk '{print $3}' "/tmp/regen_${FechaBackup}/${ORB[Unamea]}" | awk -F "." '/pve$/ {print $1"."$2}')
    # Comprobar si están conectados los discos del sistema original - Check if the original system disks are connected
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
    # Comprobar valores de red - Check network settings
    tar -C /tmp -xvf "${ORA[RutaOrigen]}/${TarRegen}" "regen_${FechaBackup}/ORB_HostnameI" >/dev/null
    IpAC=$(hostname -I | awk '{print $1}')
    IpOR=$(awk '{print $1}' "/tmp/regen_${FechaBackup}/${ORB[HostnameI]}")
    # Limpiar tmp - Clear tmp
    rm -rf "/tmp/regen_${FechaBackup}"
  fi
  if [ ! "${FASE[1]}" = "iniciar" ] && [ ! "${ORA[FechaBackup]}" = "${FechaBackup}" ]; then
    ValidarRegenera="si"; ValFechaBackup="si"
  fi
  # Comprobar sistema actual - Check current system
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
  # Comprobar formatos - Check formats
  SiNo "${ORA[Kernel]}"
  [ ! "${SiNo}" ] && ValidarRegenera="si"
  SiNo "${ORA[Red]}"
  [ ! "${SiNo}" ] && ValidarRegenera="si"
}

# Comprueba si un valor es si/on o no/off - Checks if a value is yes/on or no/off
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

# Escribir ajustes actuales en disco - Write current settings to disk
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

# Buscar nueva versión de omv-regen y actualizar si existe - Check for new version of omv-regen and update if it exists
BuscarOR () {
  txt 1 "\n\nBuscando actualizaciones de omv-regen..." "\n\nChecking for omv-regen updates..."
  txt 2 "No se ha podido descargar el archivo." "The file could not be downloaded."
  echoe "${txt[1]}"
  [ -f "${ORTemp}" ] && rm -f "${ORTemp}"
  wget -O - "${URLomvregen}" > "${ORTemp}"
  if [ ! -f "${ORTemp}" ]; then
    echoe "${txt[2]}"; Info 3 "${txt[1]}\n${txt[2]}"
  else
    VersionDI="$(awk -F "regen " 'NR==8 {print $2}' "${ORTemp}")"
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

# Funciones OMV - OMV functions
. /usr/share/openmediavault/scripts/helper-functions

# Muestra el mensaje en español o inglés según el sistema - Displays the message in Spanish or English depending on the system
echoe () {
  if [ "$2" ] && [ "${ORA[Idioma]}" = "en" ]; then
    echo -e "$2"
  else
    echo -e "$1"
  fi
}

# Parada del programa hasta que se pulse una tecla - Program stop until a key is pressed
Continuar () {
  if [ ! "${Cli}" ]; then
    echoe "\nPULSA CUALQUIER TECLA PARA CONTINUAR\n" "\nPRESS ANY KEY TO CONTINUE\n"
    until read -t10 -n1 -r -p ""; do
	    sleep 0
    done
  fi
}

# Mostrar mensaje y salir. Si $1=ayuda sale con ayuda - Show message and exit. If $1=ayuda exit with help
Salir () {
  if [ "$1" = "ayuda" ]; then
    [ "${ORA[Idioma]}" = "es" ] && echo -e "$2" || echo -e "$3"
    [ "${ORA[Idioma]}" = "es" ] && echo -e  "\n\n\n${Verde}>>>  >>>   omv-regen ${ORVersion}   <<<  <<<\n\nomv-regen          ==> para acceder al menú\nomv-regen backup   ==> para ejecutar un backup\nomv-regen regenera ==> para ejecutar una regeneración\nomv-regen ayuda    ==> para ver la ayuda${Reset}\n\n" || echo -e "\n\n\n${Verde}>>>  >>>   omv-regen ${ORVersion}   <<<  <<<\n\nomv-regen          ==> to access the menu\nomv-regen backup   ==> to run a backup\nomv-regen regenera ==> to run a regeneration\nomv-regen help     ==> to see the help${Reset}\n\n"
  else
    [ "${ORA[Idioma]}" = "es" ] && echo -e "$1" || echo -e "$2"
  fi
  exit
}

# Mensaje con tiempo de espera y posibilidad de abortar                             - Message with waiting time and possibility to abort
# $1=segundos de espera. $2 y $3 texto. $4 y $5 texto opcional mensaje si se aborta - $1=waiting seconds. $2 and $3 text. $4 and $5 optional text message if aborted
# Si se ha abortado devuelve Abortar="si"                                           - If it has been aborted, it returns Abort="si"
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

# Informacion con tiempo de espera para leer - Information with waiting time to read
# $1=segundos de espera                      - $1=waiting seconds
# $2 y $3 es el texto                        - $2 and $3 is the text
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

# Habilitar o deshabilitar backports - Enable or disable backports
# $1=YES --> Habilitar               - $1=YES --> Enable
# $1=NO --> Deshabilitar             - $1=NO --> Disable
Backports () {
  if [ ! "${Backports}" = "$1" ]; then
    if [ "$1" = "YES" ] || [ "$1" = "NO" ]; then
      Backports="$1"
      if [ "${OmvVersion}" = "6" ]; then
        sed -i "/bullseye-backports/d" /etc/apt/sources.list
      else
        sed -i "/bookworm-backports/d" /etc/apt/sources.list
      fi
      omv_set_default "OMV_APT_USE_KERNEL_BACKPORTS" "${Backports}" true
      omv-salt stage run --quiet prepare
      omv-salt deploy run --quiet apt
      omv-aptclean repos
      [ "${Backports}" = "YES" ] && omv-upgrade
    fi
  fi
}
  
# Analizar estado de paquete. Instalación y versiones. - Analyze package status. Installation and versions.
Analizar () {
  VersionOR=""; VersionDI=""; InstII=""

  VersionOR=$(awk -v i="$1" '$2 == i {print $3}' "${ORA[RutaRegen]}${ORB[DpkgOMV]}")
  VersionDI=$(apt-cache madison "$1" | awk 'NR==1{print $3}')
  InstII=$(dpkg -l | awk -v i="$1" '$2 == i {print $1}')
  [ "${InstII}" == "ii" ] && InstII="si" || InstII=""
}

# Control de versiones                                                          - Version control
# $1=esencial -> Si no es la misma versión se detiene la regeneración.          - $1=esencial -> If it is not the same version, the regeneration stops.
# $1=noesencial -> Si no es la misma versión avisa y almacena en una variable.  - $1=noesencial -> If it is not the same version, it warns and stores it in a variable.
# $2 es el paquete que se analiza.                                              - $2 is the package being analyzed.
ControlVersiones () {
  ControlVersiones=""; Esencial=$1; Paquete=$2

  txt 1 "La versión de ${Paquete} en el sistema original es ${VersionOR} y la versión disponible en el repositorio es ${VersionDI} \nEstas versiones no coinciden porque el sistema original no estaba actualizado cuando se hizo el backup o ha habido una actualización reciente. \nRegenerar ${Paquete} en estas condiciones podría corromper la base de datos. \n" "The version of ${Paquete} on the original system is ${VersionOR} and the version available in the repository is ${VersionDI} \nThese versions do not match because the original system was not updated when the backup was made or there has been a recent update. \nRegenerating ${Paquete} under these conditions could corrupt the database. \n"
  txt 2 "Debes hacer un nuevo backup del sistema original actualizado y empezar de nuevo el proceso de regeneración. \n" "You must make a new backup of the original updated system and start the rebuild process again. \n"
  Analizar "${Paquete}"
  if [ "${VersionOR}" ] && [ ! "${VersionOR}" = "${VersionDI}" ]; then
    if [ "${Esencial}" = "noesencial" ]; then
      ControlVersiones="si"
      Info 10 "${txt[1]}Puesto que ${Paquete} no es un complemento esencial para el sistema se va a instalar pero no se va a regenerar. \nTendrás que configurarlo después manualmente. \n" "${txt[1]}Since ${Paquete} is not an essential plugin for the system, it will be installed but not regenerated. \nYou will have to configure it later manually. \n"
      ComplementosNoRegenerados="${ComplementosNoRegenerados}${Paquete} -> ${VersionOR} -> ${VersionDI}\n"
    elif [ "${Esencial}" = "esencial" ]; then
      if [ "${Paquete}" = "openmediavault-omvextrasorg" ] || [ "${Paquete}" = "openmediavault" ]; then
        Info 10 "Debido a una actualización reciente o a que el sistema original no estaba actualizado cuando se hizo el backup la versión de ${Paquete} instalada no coincide con la versión que tenía el sistema original. \nNo se puede continuar la regeneración en estas condiciones porque el sistema podría terminar corrupto. \n${txt[2]}" "Due to a recent update or because the original system was not updated when the backup was made, the version of ${Paquete} installed does not match the version that the original system had. \nThe regeneration cannot continue under these conditions because the system it could end up corrupt. \n${txt[2]}"
      else
        Info 10 "${txt[1]}La regeneración se va a detener porque ${Paquete} es esencial para el sistema. \n${txt[2]}" "${txt[1]}Regeneration will stop because ${Paquete} is essential to the system. \n${txt[2]}"
      fi
      exit
    else
      echo "Error. No se ha definido si el paquete es esencial."; exit
    fi
  else
    echoe "Las versiones de ${Paquete} coinciden." "The versions of ${Paquete} match."
  fi
}

# Instalar paquete - Install package
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

# Extraer valor de una entrada de la base de datos - Extract value from a database entry
LeerValor () {
  ValorOR=""; ValorAC=""; NumVal=""

  echoe "Leyendo el valor de $1 en la base de datos original..." "Reading the value of $1 in original database..."
  ValorOR="$(xmlstarlet select --template --value-of "$1" --nl "${ORA[RutaRegen]}""${Configxml}")"
  echoe "Leyendo el valor de $1 en la base de datos actual..." "Reading the value of $1 in actual database..."
  ValorAC="$(xmlstarlet select --template --value-of "$1" --nl "${Configxml}")"
  NumVal="$(echo "${ValorAC}" | awk '{print NR}' | sed -n '$p')"
  echoe "El número de valores es ${NumVal}" "The number of values is ${NumVal}"
}

# Sustituye nodo de la base de datos actual por el existente en la base de datos original y aplica cambios en módulos salt - Replaces the current database node with the existing one in the original database and applies changes in salt modules
# El argumento de entrada debe ser un elemento de la matriz CONFIG[] - The input argument must be an element of the CONFIG[] array
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
      echoe "Configuración de módulos salt completada." "Salt module configuration completed."
    fi
  fi
}

# Ejecuta salt en modulos pendientes de aplicar cambios - Run salt on modules pending application of changes 
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
    echoe "\n\n       <<< Backup para regenerar sistema de fecha ${Fecha} >>>\n" "\n\n       <<< Backup to regenerate system dated ${Fecha} >>>\n"
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
    if [ -f "/etc/crypttab" ]; then
      cp -apv "/etc/crypttab" "${CarpetaRegen}/etc/crypttab"
      for i in $(awk 'NR>1{print $3}' /etc/crypttab); do
        [ ! -d "$(dirname "${CarpetaRegen}$i")" ] && mkdir -p "$(dirname "${CarpetaRegen}$i")"
        cp -apv "$i" "${CarpetaRegen}$i"
      done
    fi
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
    echoe "\n>>>    Copiando carpeta /root a ${CarpetaRegen} ...\n" "\n>>>    Copying /root folder to ${CarpetaRegen} ...\n"
    rsync -av /root/ "${CarpetaRegen}/root" --exclude *.deb
    echoe "\n>>>    Extrayendo lista de versiones (dpkg)...\n" "\n>>>    Extracting version list (dpkg)...\n"
    dpkg -l | grep openmediavault > "${CarpetaRegen}${ORB[DpkgOMV]}"
    dpkg -l > "${CarpetaRegen}${ORB[Dpkg]}"
    awk '{print $2" "$3}' "${CarpetaRegen}${ORB[DpkgOMV]}"
    echoe "\n>>>    Extrayendo información del sistema (uname -a)...\n" "\n>>>    Extracting system info (uname -a)...\n"
    uname -a | tee "${CarpetaRegen}${ORB[Unamea]}"
    echoe "\n>>>    Extrayendo información de zfs (zpool list)...\n" "\n>>>    Extracting zfs info (zpool list)...\n"
    [ "$(dpkg -l | grep openmediavault-zfs)" ] && zpool list | tee "${CarpetaRegen}${ORB[Zpoollist]}" || echo "--" | tee "${CarpetaRegen}${ORB[Zpoollist]}"
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
    [ "${Cli}" ] && echoe "\n       ¡Backup completado!\n" "\n       Backup completed!\n"
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
      ControlVersiones esencial openmediavault
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
          *kernel|*sharerootfs|*zfs|*lvm2|*mergerfs|*snapraid|*remotemount|*md)
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
  if [ -f "${ORA[RutaRegen]}/etc/crypttab" ]; then
    cp -apv "${ORA[RutaRegen]}/etc/crypttab" "/etc/crypttab"
    Reinicio="si"
    for i in $(awk 'NR>1{print $3}' /etc/crypttab); do
      [ ! -d "$(dirname "$i")" ] && mkdir -p "$(dirname "$i")"
      cp -apv "${ORA[RutaRegen]}$i" "$i"
    done
  fi
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
    [ -f "/etc/apt/sources.list.d/omvextras.list" ] && rm "/etc/apt/sources.list.d/omvextras.list"
    echoe "Descargando el complemento omv-extras.org para openmediavault ${OmvVersion}.x ..." "Downloading omv-extras.org plugin for openmediavault ${OmvVersion}.x ..."
    Archivo="openmediavault-omvextrasorg_latest_all${OmvVersion}.deb"
    if ! grep -qrE "^deb.*${Codename}\s+main" /etc/apt/sources.list*; then
      echoe "Añadiendo el repositorio principal que falta..." "Adding missing main repo..."
      echo "deb http://deb.debian.org/debian/ ${Codename} main contrib non-free" | tee -a /etc/apt/sources.list
    fi
    if ! grep -qrE "^deb.*${Codename}-updates\s+main" /etc/apt/sources.list*; then
      echoe "Añadiendo el repositorio de actualizaciones principales que falta..." "Adding missing main updates repo..."
      echo "deb http://deb.debian.org/debian/ ${Codename}-updates main contrib non-free" | tee -a /etc/apt/sources.list
    fi
    echoe "Actualizando repositorios antes de instalar..." "Updating repos before installing..."
    apt-get update
    echoe "Instalando prerequisitos..." "Install prerequisites..."
    apt-get --yes --no-install-recommends install gnupg 
    [ $? -gt 0 ] && Salir "No se pueden instalar los requisitos previos de omv-extras. Saliendo." "Unable to install omv-extras prerequisites.  Exiting."
    [ -f "${Archivo}" ] && rm "${Archivo}"
    wget "${URLextras}/${Archivo}"
    if [ -f "${Archivo}" ]; then
      if ! dpkg -i "${Archivo}"; then
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
  fi
  if [ "${VersionOR}" ]; then
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
      Info 5 "\n\nKernel proxmox ${KernelOR} instalado.\n " \
      "\n\nKernel proxmox ${KernelOR} installed.\n "
      echoe "Fase Nº3 terminada." "Phase No.3 completed."; sleep 1
      FASE[3]="hecho"; FASE[4]="iniciar"; GuardarAjustes
      Reinicio="si"
    fi
  fi
  if [ "${Reinicio}" ]; then
    Info 5 "\n\nSe va a reiniciar el sistema.\nLa regeneración aún no ha finalizado.\n\n\n${RojoD}Después del reinicio EJECUTA DE NUEVO OMV-REGEN para completar la regeneración.\n\n ${ResetD}\nEl proceso continuará de forma automática.\n " \
    "\n\nThe system will be rebooted.\nThe regeneration is not finished yet.\n\n\n${RojoD}After reboot RUN OMV-REGEN AGAIN to complete the regeneration.\n\n ${ResetD}\nThe process will continue automatically.\n "
    reboot
    sleep 3; exit
  fi
  echoe "Fase Nº3 terminada." "Phase No.3 completed."; sleep 1
  FASE[3]="hecho"; FASE[4]="iniciar"; GuardarAjustes
}

RegeneraFase4 () {
  echoe "\n>>>   >>>    FASE Nº4: MONTAR SISTEMAS DE ARCHIVOS.\n" "\n>>>   >>>    PHASE Nº4: MOUNT FILE SYSTEMS.\n"
  Analizar openmediavault-sharerootfs
  if [ ! "${InstII}" ]; then
    echoe "Instala openmediavault-sharerootfs. Regenera fstab (Sistemas de archivos EXT4 BTRFS)" "Install openmediavault-sharerootfs. Regenerate fstab (EXT4 BTRFS file systems)"
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
  Analizar "openmediavault-luksencryption"
  if [ ! "${VersionOR}" ]; then
    echoe "openmediavault-luksencryption no estaba instalado en el sistema original." "openmediavault-luksencryption was not installed on the original system."
  elif [ ! "${InstII}" ]; then
    ControlVersiones esencial "openmediavault-luksencryption"
    Instalar "openmediavault-luksencryption"
    Regenera "${CONFIG[openmediavault-luksencryption]}"
  fi
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
      Regenera "${CONFIG[openmediavault-symlinks]}"
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
  echoe "\n>>>   >>>    FASE Nº5: REGENERAR USUARIOS, CARPETAS COMPARTIDAS Y RESTO DE GUI.\n" "\n>>>   >>>    PHASE Nº5: REGENERATE USERS, SHARED FOLDERS AND REST OF GUI.\n"
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
      LeerValor /config/services/apttool/packages/package/packagename
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
    Analizar "$i"
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
    Info 10 "¡La regeneración ha finalizado!\n\nLa configuración activa en omv-regen es NO regenerar la interfaz de red.\nSe va a reiniciar el sistema para finalizar.\nRecuerda borrar la caché del navegador." "Regeneration is complete!\n\nThe active setting in omv-regen is to NOT regenerate the network interface.\nThe system will reboot to finish.\nRemember to clear your browser cache."
  else
    Info 10 "¡La regeneración ha finalizado!\n\nLa configuración activa en omv-regen es regenerar la interfaz de red.\nSe va a reiniciar el sistema para finalizar.\n${RojoD}La IP del sistema de origen era ${IpOR}${ResetD}\nDespués del reinicio puedes acceder al servidor en esa IP si era IP estática.\nRecuerda borrar la caché del navegador." "Regeneration is complete!\n\nThe active setting in omv-regen is to regenerate the network interface.\nThe system will reboot to finish.\n${RojoD}The IP of the original system was ${IpOR}${ResetD}\nAfter reboot you can access the server on that IP if it was static IP.\nRemember to clear your browser cache."
  fi
  if [ "${ComplementosNoRegenerados}" ]; then
    Info 10 "Debido a una reciente actualización o a que el sistema original no estaba actualizado cuando se hizo el backup, la versión que tenía el servidor original y la versión disponible en internet para la instalación de:\n${ComplementosNoRegenerados} \nno coinciden.\nEse complemento no es esencial para el sistema y omv-regen lo ha instalado pero no lo ha regenerado, tendrás que configurarlo en la GUI de OMV. Si prefieres hacer una regeneración completa haz un nuevo backup actualizado del sistema original y comienza de nuevo." \
    "Due to a recent update or because the original system was not updated when the backup was made, the version that the original server had and the version available on the internet for the installation of:\n${ComplementosNoRegenerados} \ndo not match.\nThat plugin It is not essential for the system and omv-regen has installed it but not regenerated it, you will have to configure it in the OMV GUI. If you prefer to do a complete regeneration, make a new updated backup of the original system and start again."
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

############################## INICIO - START ##################################

# Root
[[ $(id -u) -ne 0 ]] && Salir ayuda "Ejecuta omv-regen con sudo o como root.  Saliendo..." "Run omv-regen with sudo or as root.  Exiting..."

# Versiones 6.x. o 7.x.
if [ "${Codename}" = "bullseye" ]; then
  [ ! ${OmvVersion} = "6" ] && Salir "Se ha detectado Debian 11. Debes instalar previamente OMV6." "Debian 11 has been detected. You must previously install OMV6."
elif [ "${Codename}" = "bookworm" ]; then
  [ ! ${OmvVersion} = "7" ] && Salir "Se ha detectado Debian 12. Debes instalar previamente OMV7." "Debian 12 has been detected. You must previously install OMV7."
else
  Salir "Versión no soportada.   Solo está soportado OMV 6.x. y OMV 7.x.  Saliendo..." "Unsupported version.  Only OMV 6.x. and OMV 7.x. are supported.  Exiting..."
fi

# Comprobar si omv-regen está instalado - Check if omv-regen is installed
if [ ! "$0" = "${Omvregen}" ]; then
  [ -f "${Omvregen}" ] && rm "${Omvregen}"
  touch "${Omvregen}"
  wget -O - "${URLomvregen}" > "${Omvregen}"
  chmod +x "${Omvregen}"
  Salir ayuda "\n  Se ha instalado omv-regen ${ORVersion}\n" "\n  omv-regen ${ORVersion} has been installed.\n"
fi

# Configurar logrotate - Configure logrotate
if [ ! -f "/etc/logrotate.d/omv-regen" ]; then
  touch "/etc/logrotate.d/omv-regen"
  echo "/var/log/omv-regen.log {
  weekly
  missingok
  rotate 4
  compress
  delaycompress
  notifempty
}" | tee "/etc/logrotate.d/omv-regen"
fi

# Generar/recuperar configuraciones de omv-regen - Generate/recover omv-regen configurations
if [ ! -f "${ORAjustes}" ]; then
  [ ! -d "/etc/regen" ] && mkdir -p "/etc/regen"
  touch "${ORAjustes}"
  Traducir
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
  # Actualizar Archivos de Ajustes existentes - Update Existing Settings Files
  if [ "${ORA[Idioma]}" = "" ]; then
    ORA[Idioma]="${Idioma}"
    GuardarAjustes
  fi
  Traducir
fi

# Comprobar estado de regenera - Check regenera status
if [ "${FASE[1]}" = "iniciar" ]; then
  # Buscar actualizaciones de omv-regen - Check for omv-regen updates
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

# Comprobar que no hay mas de un argumento y procesar - Check that there is not more than one argument and process
[ "$2" ] && Salir ayuda "\nArgumento inválido. Si has actualizado desde una versión anterior consulta la ayuda. Saliendo..." "\nInvalid argument. If you have updated from a previous version, consult the help. Exiting..."
case "$1" in
  backup)
    Cli="si"
    EjecutarBackup 2>&1 | tee -a /var/log/omv-regen.log; exit
    ;;
  regenera)
    Camino="EjecutarRegenera"
    ;;
  ayuda|help|-h|-help)
    Ayuda
    clear; exit
    ;;
  "")
    ;;
  *)
    Salir ayuda "\nArgumento inválido. Si has actualizado desde una versión anterior consulta la ayuda. Saliendo..." "\nInvalid argument. If you have updated from a previous version, consult the help. Exiting..."
    ;;
esac

# MENU PRINCIPAL - MAIN MENU
while true; do
  if [ "${Camino}" = "MenuPrincipal" ]; then
    txt 1 "                      MENU PRINCIPAL OMV-REGEN " "                        OMV-REGEN MAIN MENU"
    txt 2 "--> Crear un backup del sistema actual.        " "--> Create a backup of the current system. "
    txt 3 "--> Modificar y guardar ajustes de Backup.     " "--> Modify and save Backup settings.       "
    txt 4 "--> Regenerar sistema a partir de un Backup.   " "--> Regenerate a new system from a backup. "
    txt 5 "--> Modificar y guardar ajustes de Regenera.   " "--> Modify and save Regenera settings.     "
    txt 6 "--> Actualizar omv-regen.                      " "--> Update omv-regen.                      "
    txt 7 "--> Resetear ajustes.                          " "--> Reset settings.                        "
    txt 8 "--> Cambiar idioma.                            " "--> Change language.                       "
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
      Regenera "${txt[4]}" \
      "${txt[Regenera_Ajustes]}" "${txt[5]}" \
      "${txt[Actualizar]}" "${txt[6]}" \
      "${txt[Resetear]}" "${txt[7]}" \
      "${txt[Idioma]}" "${txt[8]}" \
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
        ResetearAjustes; Traducir; GuardarAjustes
        Info 3 "Se han eliminado todos los ajustes guardados." "All saved settings have been deleted."
      fi
      Camino="MenuPrincipal"
      ;;
    Idioma|"${txt[Idioma]}")
      CambiarIdioma; Camino="MenuPrincipal"
      ;;
    Ayuda|"${txt[Ayuda]}")
      Ayuda; Camino="MenuPrincipal"
      ;;
    Salir|"${txt[Salir]}")
      clear; exit
      ;;
    EjecutarBackup)
      EjecutarBackup 2>&1 | tee -a /var/log/omv-regen.log; Camino="MenuPrincipal"
      ;;
    EjecutarRegenera)
      EjecutarRegenera 2>&1 | tee -a /var/log/omv-regen.log; Camino="MenuPrincipal"
      ;;
    *)
      Camino="MenuPrincipal"
      ;;
  esac
done