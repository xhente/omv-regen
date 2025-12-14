#!/bin/bash
# -*- ENCODING: UTF-8 -*-

# This file is licensed under the terms of the GNU General Public
# License version 3. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

# omv-regen 7.1.9
# Utilidad de copia de seguridad y restauración de la configuración de OpenMediaVault
# OpenMediaVault configuration backup and restore utility

# shellcheck disable=SC2059,SC1091,SC2016

ORVersion="7.1.9"

Logo_omvregen="\
\n┌───────────────┐                                         \
\n│               │     ┌────────────┐     ┌──────────────┐ \
\n│   omv-regen   │ >>> │   backup   │ >>> │   regenera   │ \
\n│               │     └────────────┘     └──────────────┘ \
\n└───────────────┘                                         "

#################################### VARIABLES ##############################################

# Determinar si OMV está instalado, su versión y la versión de Debian.
# Determine if OMV is installed, its version, and the Debian codename.
omv_instalado() { dpkg -s openmediavault &>/dev/null; }
if omv_instalado; then
    # Variables de entorno y funciones auxiliares de OMV
    # OMV Environment Variables and Helper Functions
    . /etc/default/openmediavault
    . /usr/share/openmediavault/scripts/helper-functions
    OMV_VERSION__or="$(dpkg -l openmediavault | awk '$2 == "openmediavault" { print substr($3,1,1) }')"
else
    OMV_VERSION__or=0
fi
DEBIAN_CODENAME__or=$(
    codename_os=$(env -i bash -c '. /etc/os-release; echo $VERSION_CODENAME')
    codename_dpkg=$(dpkg --status tzdata 2>/dev/null | awk -F'[:-]' '/Provides/{print $NF}' | tr -d ' ')
    [[ -n "$codename_dpkg" && "$codename_dpkg" != "$codename_os" ]] && echo "$codename_dpkg" || echo "$codename_os"
)

# Ajustes de omv-regen
# omv-regen settings
declare -A txt
declare -A CFG
declare -a CARPETAS_ADICIONALES
declare -a AYUDA

# Banderas para ejecuciones desatendidas
# Flags for unattended executions
BackupProgramado=1; LimpiezaProgramada=1; ModoAuto=1

# Archivos y carpetas de configuración de omv-regen
# omv-regen configuration files and folders
OR_dir="/var/lib/omv-regen"
OR_hook_dir="${OR_dir}/hook"
OR_repo_dir="${OR_dir}/repo"
OR_ajustes_dir="${OR_dir}/settings"
OR_hook_file="/etc/apt/post-invoke.d/01omv-regen"
OR_lock_file="/var/run/omv-regen.lock"
OR_logRotate_file="/etc/logrotate.d/omv-regen"
OR_cron_file="/etc/cron.d/omv-regen"
OR_ajustes_file="${OR_ajustes_dir}/omv-regen.settings"
OR_script_file="/usr/sbin/omv-regen"
OR_log_file="/var/log/omv-regen.log"
OR_regen_log="$OR_dir/regen.log"

# Archivo generado para la regeneración
# File generated for regeneration
OR_RegenInfo_file="${OR_dir}/regen_info"

# Archivos de OMV necesarios para la regeneración
# OMV files required for regeneration
Config_xml_file="$OMV_CONFIG_FILE"
Passwd_file="/etc/passwd"
Shadow_file="/etc/shadow"
Group_file="/etc/group"
Subuid_file="/etc/subuid"
Subgid_file="/etc/subgid"
Default_file="/etc/default/openmediavault"

# Archivos para incluir en el backup
# Files to include in the backup
declare -a ARCHIVOS_BACKUP=("$Config_xml_file" "$Passwd_file" "$Shadow_file" "$Group_file" "$Subuid_file" "$Subgid_file" "$Default_file" "$OR_RegenInfo_file" "$OR_script_file")

# Archivos temporales
# Temporary files
Conf_tmp_file="/etc/openmediavault/config.rg"
OR_tmp_dir="${OR_dir}/tmp"

# Variables para la regeneración, ver LeerRegenInfoFile()
# Variables for regeneration, see LeerRegenInfoFile()
declare -A VERSION_ORIGINAL
IPOriginal=""
KernelOriginal=""
declare -a OriginalZFS
FechaInfo=""
Carpeta_Regen=""

# Testigo de control para aplicar Salt
# Control witness to apply Salt
Salt=0

# Variables globales validaciones
# Global variables validations
ErrorValRegen=""
InfoValRegen=""
TarRegenFile=""
ErrorValBackup=""
PaquetesFaltantesBackup=""

# Complementos relacionados con el sistema de archivos. Este es el orden de instalación, no modificar.
# File System Related Plugins. This is the installation order, do not modify
declare -a SISTEMA_ARCHIVOS
SISTEMA_ARCHIVOS=("openmediavault-zfs"  "openmediavault-luksencryption" "openmediavault-bcache" "openmediavault-lvm2" "openmediavault-md" "openmediavault-mergerfs" "openmediavault-snapraid" "openmediavault-remotemount" "openmediavault-mounteditor" "openmediavault-symlinks")

# Lista de paquetes esenciales
# Essential package list
declare -a NO_OMITIR
NO_OMITIR=("openmediavault" "openmediavault-keyring" "openmediavault-kernel" "openmediavault-omvextrasorg" "openmediavault-sharerootfs")
NO_OMITIR=( "${NO_OMITIR[@]}" "${SISTEMA_ARCHIVOS[@]}" )

# URLs
URL_OMVREGEN_SCRIPT="https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen_6_7.sh"
URL_OPENMEDIAVAULT_PAQUETES="https://packages.openmediavault.org/public/pool/main/o/"
URL_OMVEXTRAS="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master"
# shellcheck disable=SC2034
URL_RASPBERRY_PREINSTALL_SCRIPT="https://raw.githubusercontent.com/OpenMediaVault-Plugin-Developers/installScript/master/preinstall"
URL_OMV_INSTALL_SCRIPT="https://raw.githubusercontent.com/OpenMediaVault-Plugin-Developers/installScript/master/installOld7"
URL_OMVREGEN_INSTALL="https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen-install.sh"

# Códigos de color
# Color codes
# Rojo="\e[31m"
Verde="\e[32m"
Reset="\e[0m"
# RojoD="\Z1"
AzulD="\Z4"
ResetD="\Zn"

# NODOS DE LA BASE DE DATOS - Valor de la ruta del nodo en la base de datos (nulo = el nodo no existe)
# DATABASE NODES - Value of the node path in the database (nulo = node does not exist)

# Interfaz GUI
# GUI interface
declare -A CONFIG
CONFIG[apt]="/config/system/apt"
CONFIG[btrfs]="/config/system/sharedfoldersnapshotlifecycle"
CONFIG[certificates]="/config/system/certificates"
CONFIG[crontab]="/config/system/crontab"
CONFIG[dns]="/config/system/network/dns"
CONFIG[email]="/config/system/email"
CONFIG[fstab]="/config/system/fstab"
CONFIG[groups]="/config/system/usermanagement/groups"
CONFIG[hdparm]="/config/system/storage/hdparm"
CONFIG[homedirectory]="/config/system/usermanagement/homedirectory"
CONFIG[interfaces]="/config/system/network/interfaces"
CONFIG[iptables]="/config/system/network/iptables"
CONFIG[monitoring]="/config/system/monitoring"
CONFIG[nfs]="/config/services/nfs"
CONFIG[notification]="/config/system/notification"
CONFIG[powermanagement]="/config/system/powermanagement"
CONFIG[proxy]="/config/system/network/proxy"
CONFIG[rsync]="/config/services/rsync"
CONFIG[shares]="/config/system/shares"
CONFIG[smart]="/config/services/smart"
CONFIG[smb]="/config/services/smb"
CONFIG[ssh]="/config/services/ssh"
CONFIG[syslog]="/config/system/syslog"
CONFIG[time]="/config/system/time"
CONFIG[users]="/config/system/usermanagement/users"
CONFIG[webadmin]="/config/webadmin"

# Complementos
# Plugins
CONFIG[openmediavault-anacron]="/config/services/anacron"
CONFIG[openmediavault-apt]="/config/system/apt"
CONFIG[openmediavault-apttool]="/config/services/apttool"
CONFIG[openmediavault-autoshutdown]="/config/services/autoshutdown"
CONFIG[openmediavault-backup]="/config/system/backup"
CONFIG[openmediavault-bcache]="nulo"
CONFIG[openmediavault-borgbackup]="/config/services/borgbackup"
CONFIG[openmediavault-clamav]="/config/services/clamav"
CONFIG[openmediavault-compose]="/config/services/compose"
CONFIG[openmediavault-cputemp]="nulo"
CONFIG[openmediavault-cterm]="/config/services/cterm"
CONFIG[openmediavault-diskclone]="nulo"
CONFIG[openmediavault-diskstats]="nulo"
CONFIG[openmediavault-downloader]="/config/services/downloader"
CONFIG[openmediavault-fail2ban]="/config/services/fail2ban"
CONFIG[openmediavault-filebrowser]="/config/services/filebrowser"
CONFIG[openmediavault-flashmemory]="nulo"
CONFIG[openmediavault-forkeddaapd]="/config/services/daap" # Only OMV 6
CONFIG[openmediavault-ftp]="/config/services/ftp"
CONFIG[openmediavault-hddfanctrl]="/config/system/hddfanctrl"
CONFIG[openmediavault-hosts]="/config/system/network/hosts"
CONFIG[openmediavault-iperf3]="/config/services/iperf3"
CONFIG[openmediavault-k8s]="/config/services/k8s"
CONFIG[openmediavault-kernel]="nulo"
CONFIG[openmediavault-kvm]="/config/services/kvm"
CONFIG[openmediavault-locate]="nulo"
CONFIG[openmediavault-luksencryption]="nulo"
CONFIG[openmediavault-lvm2]="nulo"
CONFIG[openmediavault-md]="nulo"
CONFIG[openmediavault-mergerfs]="/config/services/mergerfs"
CONFIG[openmediavault-minidlna]="/config/services/minidlna"
CONFIG[openmediavault-mounteditor]="nulo"
CONFIG[openmediavault-nut]="/config/services/nut"
CONFIG[openmediavault-omvextras]="/config/system/omvextras"
CONFIG[openmediavault-onedrive]="/config/services/onedrive"
CONFIG[openmediavault-owntone]="/config/services/owntone"
CONFIG[openmediavault-photoprism]="/config/services/photoprism"
CONFIG[openmediavault-podman]="nulo"
CONFIG[openmediavault-remotemount]="/config/services/remotemount"
CONFIG[openmediavault-resetperms]="/config/services/resetperms"
CONFIG[openmediavault-rsnapshot]="/config/services/rsnapshot"
CONFIG[openmediavault-s3]="/config/services/minio"
CONFIG[openmediavault-scripts]="/config/services/scripts"
CONFIG[openmediavault-sftp]="/config/services/sftp"
CONFIG[openmediavault-shairport]="/config/services/shairport"
CONFIG[openmediavault-sharerootfs]="nulo"
CONFIG[openmediavault-snapraid]="/config/services/snapraid"
CONFIG[openmediavault-snmp]="/config/services/snmp"
CONFIG[openmediavault-symlinks]="/config/services/symlinks"
CONFIG[openmediavault-tftp]="/config/services/tftp"
CONFIG[openmediavault-tgt]="/config/services/tgt"
CONFIG[openmediavault-timeshift]="/config/services/timeshift"
CONFIG[openmediavault-usbbackup]="/config/services/usbbackup"
CONFIG[openmediavault-wakealarm]="/config/system/wakealarm"
CONFIG[openmediavault-webdav]="/config/services/webdav"
CONFIG[openmediavault-wetty]="/config/services/wetty"
CONFIG[openmediavault-wireguard]="/config/services/wireguard"
CONFIG[openmediavault-wol]="/config/services/wol"
CONFIG[openmediavault-writecache]="/config/services/writecache"
CONFIG[openmediavault-zfs]="nulo"

# Variables del entorno de ejecución
# Execution environment variables
export LANG=C.UTF-8
export LANGUAGE=C
export LC_ALL=C.UTF-8
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export TERM=xterm
# Configurar librería ncurses para la correcta visualización de menus de dialog
# Configure ncurses library for the correct display of dialog menus
export NCURSES_NO_UTF8_ACS=1

# Ajustes guardados en archivo $OR_ajustes_file
# Settings saved in file $OR_ajustes_file
IniciarAjustes() {
    # CONFIGURACIONES RELACIONADAS CON BACKUPS
    # SETTINGS RELATED TO BACKUPS
    # Actualización automática de openmediavault durante un backup
    # Automatic update of openmediavault during a backup.
    pre_ActualizarOMV="No"; CFG[ActualizarOMV]="$pre_ActualizarOMV"
    # Omitir la inclusion de /root en el backup
    # Skip including /root in the backup
    pre_OmitirRoot="No"; CFG[OmitirRoot]="$pre_OmitirRoot"
    # Períodos de retenciones de backups para su eliminación
    # Backup retention periods for deletion
    pre_RetencionDias="7"; CFG[RetencionDias]="$pre_RetencionDias"
    pre_RetencionMeses="6"; CFG[RetencionMeses]="$pre_RetencionMeses"
    pre_RetencionSemanas="4"; CFG[RetencionSemanas]="$pre_RetencionSemanas"
    # Se imprimie información mínima en la salida de un backup
    # Minimal information is printed in the output of a backup
    pre_ModoSilencio="Si"; CFG[ModoSilencio]="$pre_ModoSilencio"
    # Carpeta de almacenamiento de backups
    # Backup storage folder
    pre_RutaBackups="/ORBackup"; CFG[RutaBackups]="$pre_RutaBackups"
    # Rutas de carpetas opcionales que se incluyen en un backup
    # Optional folder paths to include in a backup
    CARPETAS_ADICIONALES=("/home")
    
    # CONFIGURACIONES RELACIONADAS CON LA REGENERACION
    # CONFIGURATIONS RELATED TO REGENERATION
    # Instalar kernel proxmox en la regenerando si ya estaba originalmente
    # Install proxmox kernel on the regenerating one if it was already there originally
    pre_RegenKernel="Si"; CFG[RegenKernel]="$pre_RegenKernel"
    # Regenerar interfaz de red - Regenerate network interface
    pre_RegenRed="Si"; CFG[RegenRed]="$pre_RegenRed"
    # Control del estado de la regeneración en curso
    # Control of the status of the regeneration in progress
    CFG[EstatusRegenera]=""
    # /Ruta/al/archivo_de_backup de una regeneración en progreso
    # /Path/to/backup_file of a regeneration in progress
    CFG[RutaTarRegenera]=""
    # Complementos a excluir durante la regeneración
    # Plugins to exclude during regeneration
    CFG[ComplementosExc]=""

    # CONFIGURACIONES GENERALES DE OMV-REGEN
    # GENERAL OMV-REGEN SETTINGS
    # Actualización automática de omv-regen
    # omv-regen automatic update
    pre_ActualizarOmvregen="Si"; CFG[ActualizarOmvregen]="$pre_ActualizarOmvregen"
    # Control para buscar actualizaciones de omv-regen solo una vez al día
    # Control to check for omv-regen updates only once a day
    pre_UltimaBusqueda="10"; CFG[UltimaBusqueda]="$pre_UltimaBusqueda"
    # Almacena la configuración de idioma inglés-español 
    # Stores English-Spanish language settings
    CFG[Idiomas]=""
}

############################### CONFIGURACION DE IDIOMA Y TEXTOS DE AYUDA ############################################
#################################### LANGUAGE SETTINGS AND HELP TEXTS ################################################

# Instalar idioma español
# Install spanish language
InstalarEsp() {
    locale -a 2>/dev/null | grep -q '^es_' && return 0
    echoe ">>> Instalando idioma español ..."
    sed -i 's/^# *es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/' /etc/locale.gen | _orl
    locale-gen | _orl
    update-locale LANG=es_ES.UTF-8 LC_ALL=es_ES.UTF-8 | _orl
    echoe ">>> Idioma español configurado correctamente."
}

# Establecer idioma local inicial y/o cambiar idioma y cargar textos
# Set initial local language and/or change language and load texts
AjustarIdioma() {

    if [ ! "${CFG[Idiomas]}" ]; then
        CFG[Idiomas]="en"
        if locale -a 2>/dev/null | grep -q '^es_'; then
            CFG[Idiomas]="es"
        fi
    fi

    # Textos en Español-Inglés
    # Texts in Spanish-English
    txt Ayuda      "Ayuda"      "Help"
    txt Carpeta    "Carpeta"    "Folder"
    txt inicio     "inicio"     "start"
    txt intento    "intento"    "retry"
    txt Red        "Red"        "Network"
    txt Ruta       "Ruta"       "Path"
    txt Si         "Si"         "Yes"
    txt B_Abortar         "     Abortar     " "      Abort      "
    txt B_Anterior        "    Anterior     " "    Previous     "
    txt B_Ayuda           "      Ayuda      " "      Help       "
    txt B_Cancelar        "    Cancelar     " "     Cancel      "
    txt B_Continuar       "    Continuar    " "    Continue     "
    txt B_No              "       No        " "       No        "
    txt B_Menu_Principal  " Menu  principal " "    Main menu    "
    txt B_Salir           "     Salir       " "      Exit       "
    txt B_Si              "       Si        " "       Yes       "
    txt B_Siguiente       "    Siguiente    " "      Next       "
    txt B_Quitar          "     Quitar      " "     Remove      "

txt salirayuda "\n\n${Logo_omvregen}\n\n\n${Verde}>>>  >>>   omv-regen ${ORVersion}   <<<  <<<\n \
                \n   omv-regen          → Abre la interfaz gráfica principal. \
                \n   omv-regen backup   → Realiza un backup de la configuración de OMV. \
                \n   omv-regen ayuda    → Accede a los cuadros de diálogo con la ayuda completa.${Reset}\n\n" \
               "\n\n${Logo_omvregen}\n\n\n${Verde}>>>  >>>   omv-regen ${ORVersion}   <<<  <<<\n \
                \n   omv-regen          → Opens the main graphical interface. \
                \n   omv-regen backup   → Back up your OMV configuration. \
                \n   omv-regen help     → Access dialog boxes with complete help.${Reset}\n\n"

txt AyudaOmvregen \
"\n \
\n______ INTRODUCCIÓN \
\n \
\nDesde su nacimiento en abril de 2023, omv-regen ha sido una herramienta concebida para migrar configuraciones de OpenMediaVault entre sistemas. \
\nSin embargo, su alcance estaba limitado por la disponibilidad en línea de las versiones de los paquetes. \
\nHoy, con la llegada de la versión 7.1, esa limitación queda atrás. \
\nEsta versión introduce la capacidad de almacenar y reutilizar los paquetes desde un repositorio local, \
\nhaciendo posible una regeneración completa y fiel al sistema original, incluso meses después. \
\n \
\nomv-regen deja así de ser una simple utilidad de migración y se convierte en una auténtica solución de backup y restauración sin límites de tiempo. \
\nLa inestimable ayuda de Aaron Murray y ChatGPT —a quienes expreso mi sincero agradecimiento— ha sido fundamental para alcanzar este hito. \
\n \
\nChente \
\n(Octubre de 2025) \
\n \
\n______ QUÉ ES OMV-REGEN \
\n \
\n- omv-regen es una utilidad desarrollada en bash que se ejecuta desde línea de comandos (CLI) y dispone de interfaz gráfica mediante dialog. \
\n- Permite hacer y programar backups de la configuración de OpenMediaVault (OMV) y usar estos backups para migrar o regenerar la configuración en otro sistema limpio de OMV o Debian. \
\n \
\n- NOTA: omv-regen no permite actualizar entre versiones principales de OMV (por ejemplo, de OMV6 a OMV7). Para eso, utiliza siempre el procedimiento oficial: 'omv-release-upgrade'. omv-regen solo puede regenerar configuraciones dentro de la misma versión principal de OMV. \
\n \
\n    Comandos principales: \
\n \
\n- 'omv-regen'          → Abre la interfaz gráfica principal.  \
\n- 'omv-regen backup'   → Realiza un backup de la configuración de OMV. \
\n- 'omv-regen ayuda'    → Accede a los cuadros de diálogo con la ayuda completa. \
\n \
\n______ VENTAJAS RESPECTO A UN BACKUP CONVENCIONAL \
\n \
\n- Capacidad de recuperar un sistema corrupto si los archivos esenciales están en buen estado y puedes generar un backup. \
\n- El backup es muy ligero, solo ocupa algunos megas de capacidad, lo que permite conservar múltiples versiones con facilidad. \
\n- Permite regenerar un sistema amd64 en uno ARM o viceversa, teniendo en cuenta las limitaciones de arquitectura de algunos complementos. \
\n- Una regeneración proporciona un sistema limpio, puesto que parte de un sistema limpio. \
\n- Permite migrar de hardware sin limitaciones manteniendo las configuraciones de OpenMediaVault. \
\n \
\n______ LIMITACIONES DE OMV-REGEN \
\n \
\n- Las configuraciones realizadas en CLI no se trasladarán al nuevo sistema, solo se respaldan las configuraciones de la GUI de OMV. \
\n- No se trasladan las configuraciones internas de los complementos basados en podman, como Filebrowser o Photoprism — respáldalos por otros medios. \
\n- omv-regen no es un sistema de backup de datos. Su objetivo es preservar la configuración del sistema, no el contenido de los discos de datos. \
\n \
\n______ CÓMO HACER BACKUPS CON OMV-REGEN \
\n \
\n- Conéctate por SSH a tu servidor o con un monitor y teclado, instala y ejecuta 'omv-regen' \
\n- Configura la carpeta de almacenamiento de backups; por defecto es '/ORBackup' \
\n- Por defecto, se programa un backup diario a las 03:00 h. Puedes modificarlo en la GUI de OMV, en Tareas Programadas. \
\n- También puedes ejecutar un backup manual desde la GUI de omv-regen. \
\n- Puedes añadir carpetas adicionales al backup, configúralo en la GUI de omv-regen. \
\n- Utiliza las carpetas adicionales para conservar carpetas existentes fuera del entorno de OMV. \
\n- Desactiva el modo silencio para notificaciones detalladas. \
\n- Siempre recibirás una notificación si se produce un error. \
\n- Cada backup está formado por varios archivos etiquetados con la fecha y hora de su creación y contiene: \
\n   - Un archivo '.regen.tar'  con los elementos necesarios para la regeneración. \
\n   - Un archivo '.sha56'      para verificar la integridad del backup. \
\n   - Un archivo '.user#.tar'  por cada carpeta de usuario incluida en el backup. \
\n \
\n______ CÓMO REGENERAR UN SISTEMA \
\n \
\n- Conéctate por SSH o con un monitor y teclado, instala y ejecuta 'omv-regen' \
\n- Haz un backup del sistema actual y cópialo fuera del servidor (por ejemplo, con WinSCP o a un pendrive). \
\n- Para regenerar, necesitas una instalación limpia de OMV. Dos opciones: \
\n   - Usar la ISO de OMV: instala OMV sin actualizar el sistema; omv-regen actualizará a la versión correcta del backup. \
\n   - Instalar Debian mínimo (64 bits) y dejar que omv-regen instale OMV en la versión del backup. \
\n- Se recomienda usar un disco nuevo para la instalación y conservar el original como copia de seguridad. \
\n- Copia el backup a una carpeta del servidor. \
\n- Configura la ruta del backup e inicia la regeneración. \
\n   - Si quieres omitir la instalación de algún complemento selecciónalo en la GUI de omv-regen regenera antes de iniciar. \
\n- El sistema se reiniciará automáticamente, puedes ejecutar 'omv-regen' en cualquier momento para ver el log en vivo. \
\n- Al finalizar, recibirás un correo con el resultado y podrás comprobar en la GUI de OMV que todo se ha restaurado correctamente. \
\n \
\n______ INSTALACIÓN Y REGENERACIÓN DESDE LA ISO DE OPENMEDIAVAULT \
\n \
\n- Instala OpenMediaVault con la ISO correspondiente a la versión (6.0/7.0) que necesites. \
\n- No actualices el sistema, deja que lo haga omv-regen para adecuar las versiones a las del sistema original. \
\n- Instala omv-regen: \
\n \
\n     'wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | bash' \
\n \
\n- Copia el backup al servidor, inicia 'omv-regen' y ejecuta la regeneración. \
\n \
\n______ INSTALACIÓN Y REGENERACIÓN DESDE DEBIAN \
\n \
\n- Si tu hardware es ARM o no puedes instalar desde la ISO, usa este procedimiento. \
\n- Instala la versión de Debian Lite de 64 bits (sin entorno gráfico) que necesites: \
\n   - Para OMV6 → Debian 11 (Bullseye) \
\n   - Para OMV7 → Debian 12 (Bookworm) \
\n- Durante la instalación, selecciona únicamente el paquete SSH para instalar. \
\n- Una vez finalizada la instalación, inicia sesión con tu usuario y activa root: \
\n \
\n     'sudo -i' \
\n     'passwd root'   # Establece una contraseña segura para root \
\n \
\n- Activa el acceso SSH para el usuario root: \
\n \
\n     'nano /etc/ssh/sshd_config' \
\n \
\n- Busca y modifica las siguientes líneas: \
\n \
\n     'PermitRootLogin yes' \
\n     'PasswordAuthentication yes' \
\n \
\n- Guarda los cambios y reinicia el servicio: \
\n \
\n     'systemctl restart ssh' \
\n \
\n- Ahora puedes conectarte al servidor desde otro equipo con root, por ejemplo con PuTTY o WinSCP. \
\n- Instala wget y omv-regen: \
\n \
\n     'apt-get update' \
\n     'apt-get upgrade -y'  \
\n     'apt-get install wget -y' \
\n     'wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | bash' \
\n \
\n- Copia el backup al servidor (WinSCP), inicia 'omv-regen' y ejecuta la regeneración. omv-regen instalará OMV y continuará la regeneración. \
\n \
\n______ ALGUNOS CONSEJOS Y NOVEDADES PRÁCTICAS \
\n \
\n- SISTEMA DE BACKUPS: \
\n   - Los backups ahora se gestionan mediante un sistema de retenciones automáticas: semanal, mensual y anual. \
\n   - Podrás mantener copias históricas sin llenar el disco; las más antiguas se eliminarán de forma segura según tus ajustes. \
\n \
\n- HOOK AUTOMÁTICO: \
\n   - omv-regen instala un hook que garantiza que todos los paquetes necesarios se descarguen junto al backup. \
\n   - Una primera actualización del sistema tras instalar omv-regen asegurará que todos los paquetes estén disponibles a partir de ese momento. \
\n \
\n- PROGRAMACIÓN AUTOMÁTICA: \
\n   - omv-regen crea por defecto una tarea diaria de backup, que puedes modificar desde la GUI de OMV. \
\n   - Además, se ejecuta una limpieza semanal automática del hook para mantener el sistema ordenado. \
\n \
\n- CARPETAS OPCIONALES: \
\n   - Evita incluir carpetas de sistema en los backups opcionales. \
\n   - Asegúrate de que no contengan archivos críticos que puedan afectar al nuevo sistema. \
\n \
\n- COMPLEMENTOS BASADOS EN CONTENEDORES: \
\n   - omv-regen solo respalda las configuraciones visibles en la GUI de OMV. \
\n   - Complementos basados en podman como Filebrowser o Photoprism deben respaldarse manualmente. \
\n \
\n- OPENMEDIAVAULT-APTTOOL: \
\n   - Si utilizas el complemento apttool, los paquetes instalados mediante él se instalarán automáticamente durante la regeneración. \
\n \
\n- SYMLINKS Y CONFIGURACIONES MANUALES: \
\n   - Los enlaces creados con omv-symlinks se regenerarán automáticamente. \
\n   - Los creados manualmente desde CLI deberán volver a configurarse. \
\n \
\n- DOCKER: \
\n   - Guarda los datos y volúmenes de Docker fuera del disco de sistema, \
\n   - preferiblemente en un disco de datos, para evitar pérdidas durante la regeneración. \
\n   - Después de la regeneración levanta los contenedores en la GUI de OMV. \
\n \
\n- DISCOS ENCRIPTADOS: \
\n   - Si utilizas omv-luksencryption, asegúrate de tener configurado '/etc/crypttab' y las claves de descifrado accesibles. \
\n   - omv-regen las transferirá al nuevo sistema y gestionará los reinicios necesarios. \
\n \
\n- UNIDAD DE SISTEMA: \
\n   - Instala el nuevo sistema en una unidad diferente a la original. \
\n   - Así podrás conservar el disco anterior como copia de seguridad ante cualquier imprevisto. \
\n \
\n______ FUNCIONAMIENTO INTERNO \
\n \
\n- Durante la instalación: \
\n \
\n      - Si el sistema es Debian y aún no tiene instalado OMV, se instalará dialog previamente. \
\n      - Se configura un hook para capturar en vivo los paquetes instalados por el sistema. \
\n      - Se configura en cron un trabajo de limpieza semanal del hook que actualiza el repositorio local, si no se ha hecho ya durante la semana. \
\n      - Se configura el log de omv-regen. \
\n      - Se crea la carpeta '/var/lib/omv-regen' con los archivos de configuración y el repositorio local. \
\n      - Se configura un trabajo programado diario de backup, configurable desde la GUI de OMV. \
\n      - Si el sistema tiene el idioma español, 'omv-regen' se ajusta el idioma a español. \
\n \
\n- Durante la ejecución de un backup: \
\n \
\n      - Aunque no es necesario, puedes activar la actualización automática de OMV. \
\n      - Se actualiza el repositorio local con los paquetes necesarios capturados en el hook y se añaden al backup. \
\n      - Se eliminan los backups obsoletos según las retenciones configuradas. \
\n \
\n- Durante la regeneración: \
\n \
\n      - Se permite omitir la instalación de complementos no esenciales. \
\n      - Se configura un servicio para reanudar la regeneración automáticamente tras cada reinicio. \
\n         - Puedes ejecutar 'omv-regen' en cualquier momento para ver el log en vivo. \
\n      - Se desinstala apparmor si está presente. \
\n      - Si OMV no está instalado, omv-regen instala OMV utilizando el script de instalación de OMV de Aaron Murray. \
\n         - Esta instalación añade omv-extras al sistema, incluso si no estaba en el sistema original. \
\n      - Se instalan las versiones del sistema original de OMV y complementos y se retienen hasta finalizar. \
\n      - Se sustituyen partes de la base de datos siguiendo un orden lógico y ejecutando comandos de SaltStack para aplicar configuraciones. \
\n      - Al finalizar, se liberan las retenciones y se actualiza el sistema a la última versión de cada paquete. \
\n \
\n- Características especiales: \
\n \
\n      - omv-regen impide la ejecución de dos instancias simultáneas, excepto durante la regeneración para poder ver el log en vivo. \
\n \
\n______ NOTAS Y RECOMENDACIONES \
\n \
\n- Requisitos mínimos: Sistema Debian u OMV de 64 bits y conexión a Internet estable. \
\n   - Se recomienda ejecutar 'omv-regen' como root. \
\n \
\n- Logs y seguimiento: \
\n   - Los registros de ejecución se guardan en '/var/log/omv-regen.log' \
\n   - Si la regeneración se interrumpe, puedes reanudarla ejecutando de nuevo 'omv-regen' \
\n \
\n- Compatibilidad de versiones: \
\n   - 'omv-regen regenera' requiere que la versión de OMV sea igual o inferior a la del sistema original. \
\n      - No actualices OMV, deja que lo haga omv-regen, o deja que omv-regen instale OMV desde Debian. \
\n      - Una vez completado el proceso, omv-regen actualizará el sistema con seguridad. \
\n \
\n- Copias de seguridad: \
\n   - Guarda siempre una copia del backup fuera del servidor antes de iniciar la regeneración. \
\n   - No borres el backup original hasta confirmar que el nuevo sistema funciona correctamente. \
\n \
\n- Seguridad: \
\n   - omv-regen no realiza modificaciones en los discos de datos; solo en el sistema. \
\n   - Verifica que todos los discos originales estén conectados antes de iniciar la regeneración. \
\n   - Recuperación manual: Si una regeneración se detiene con algún problema de instalación. \
\n      - Limpia la regeneración actual desde la GUI de omv-regen para desbloquear las versiones de paquetes. \
\n      - A partir de ese momento el sistema queda en tus manos. \
\n \
\n- Consideraciones para sistemas con tarjeta SD (Raspberry Pi y similares): \
\n   - Durante la regeneración del sistema, omv-regen realiza operaciones intensivas de lectura y escritura. \
\n   - En dispositivos que utilizan almacenamiento flash (como tarjetas SD o eMMC), este proceso puede provocar un desgaste significativo y acortar la vida útil del medio. \
\n   - Sistemas con 2GB de RAM pueden experimentar inestabilidad, especialmente al aplicar múltiples cambios de configuración o reiniciar servicios, ya que el uso de swap aumenta el riesgo de fallos y de desgaste adicional de la tarjeta SD. \
\n   - Recomendaciones: \
\n      - Realiza la regeneración sobre un SSD conectado por USB siempre que sea posible. \
\n      - Si usas una SD, utiliza una de alta calidad y evita regeneraciones repetidas en la misma tarjeta. \
\n      - Considera usar modelos con 4 GB de RAM o más para una mayor estabilidad. \
\n \
\n- Soporte: \
\n   - Para dudas o incidencias, consulta el foro oficial de OpenMediaVault. \
\n   - Recuerda incluir los últimos registros del log para obtener ayuda más rápida. \
\n \
\n- Nota final: \
\n   - omv-regen ha sido diseñado para ofrecer una restauración fiable y automatizada. \
\n   - No obstante, úsalo bajo tu responsabilidad y revisa siempre los mensajes antes de confirmar cada paso. \
\n" \
"\n \
\n______ INTRODUCTION \
\n \
\nSince its creation in April 2023, omv-regen has been a tool designed to migrate OpenMediaVault configurations between systems. \
\nHowever, its scope was limited by the online availability of package versions. \
\nToday, with the arrival of version 7.1, that limitation is gone. \
\nThis version introduces the ability to store and reuse packages from a local repository, \
\nmaking it possible to fully and faithfully regenerate a system — even months later. \
\n \
\nThus, omv-regen is no longer just a migration utility but a true backup and restoration solution without time limits. \
\nThe invaluable help of Aaron Murray and ChatGPT —to whom I extend my deepest gratitude— has been essential in achieving this milestone. \
\n \
\nChente \
\n(October 2025) \
\n \
\n______ WHAT IS OMV-REGEN \
\n \
\n- omv-regen is a bash-based utility that runs from the command line (CLI) and provides a graphical interface through dialog. \
\n- It allows you to create and schedule backups of your OpenMediaVault (OMV) configuration and use those backups to migrate or regenerate the configuration on a clean OMV or Debian system. \
\n \
\n- NOTE: omv-regen does not support upgrading between major OMV versions (e.g., from OMV 6 to OMV 7). For this, always use the official 'omv-release-upgrade' procedure. omv-regen can only regenerate configurations within the same major OMV version. \
\n \
\n    Main commands: \
\n \
\n- 'omv-regen'          → Opens the main graphical interface. \
\n- 'omv-regen backup'   → Creates a backup of the OMV configuration. \
\n- 'omv-regen ayuda'    → Opens the help dialogs with full documentation. \
\n \
\n______ ADVANTAGES OVER A CONVENTIONAL BACKUP \
\n \
\n- Can recover a corrupted system as long as essential files are intact and a backup can be created. \
\n- The backup is lightweight, usually only a few megabytes, allowing you to keep multiple versions easily. \
\n- Can regenerate a system from amd64 to ARM or vice versa, taking into account plugin architecture limitations. \
\n- A regeneration produces a clean system, since it starts from a clean installation. \
\n- Allows hardware migration without limitations while preserving all OpenMediaVault configurations. \
\n \
\n______ LIMITATIONS OF OMV-REGEN \
\n \
\n- Custom configurations made from the CLI will not be transferred; only settings made through the OMV GUI are included. \
\n- Internal configurations of podman-based plugins (such as Filebrowser or Photoprism) are not included — back them up separately. \
\n- omv-regen is not a data backup system. Its purpose is to preserve system configuration, not data content. \
\n \
\n______ HOW TO MAKE BACKUPS WITH OMV-REGEN \
\n \
\n- Connect via SSH to your server or use a monitor and keyboard, then install and run 'omv-regen'. \
\n- Configure the backup storage folder; the default is '/ORBackup'. \
\n- By default, a daily backup is scheduled at 03:00 AM. You can modify this in the OMV GUI under Scheduled Tasks. \
\n- You can also manually execute a backup from the omv-regen GUI. \
\n- You can add additional folders to the backup; configure them in the omv-regen GUI. \
\n- Use additional folders to keep existing folders outside the OMV environment. \
\n- Turn off silent mode for detailed notifications. \
\n- You will always receive a notification if an error occurs. \
\n- Each backup consists of several files labeled with the creation date and time and contains: \
\n   - A '.regen.tar'  file with the elements needed for regeneration. \
\n   - A '.sha56'      file to verify backup integrity. \
\n   - A '.user#.tar'  file for each user folder included in the backup. \
\n \
\n______ HOW TO REGENERATE A SYSTEM \
\n \
\n- Connect via SSH or use a monitor and keyboard, install and run 'omv-regen'. \
\n- Create a backup of the current system and copy it outside the server (e.g., using WinSCP or to a USB drive). \
\n- To regenerate, you need a clean installation of OMV. Two options: \
\n   - Use the OMV ISO: install OMV without updating the system; omv-regen will adjust to the correct backup version. \
\n   - Install minimal Debian (64-bit) and let omv-regen install OMV in the version from the backup. \
\n- It is recommended to use a new disk for installation and keep the original as a safety copy. \
\n- Copy the backup to a folder on the server. \
\n- Configure the backup path and start regeneration. \
\n   - If you want to skip installing certain plugins, select them in the omv-regen regenera GUI before starting. \
\n- The system will reboot automatically. You can run 'omv-regen' at any time to view the live log. \
\n- When finished, you will receive an email with the results and can verify in the OMV GUI that everything has been restored correctly. \
\n \
\n______ INSTALLATION AND REGENERATION FROM THE OPENMEDIAVAULT ISO \
\n \
\n- Install OpenMediaVault with the ISO corresponding to the version (6.0/7.0) you need. \
\n- Do not update the system; let omv-regen handle it to match the original versions. \
\n- Install omv-regen: \
\n \
\n     'wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | bash' \
\n \
\n- Copy the backup to the server, start 'omv-regen', and run regeneration. \
\n \
\n______ INSTALLATION AND REGENERATION FROM DEBIAN \
\n \
\n- If your hardware is ARM or you cannot install from the ISO, use this procedure. \
\n- Install the minimal 64-bit Debian Lite version you need: \
\n   - For OMV6 → Debian 11 (Bullseye) \
\n   - For OMV7 → Debian 12 (Bookworm) \
\n- During installation, select only the SSH package to install. \
\n- Once installation is complete, log in with your user and enable root: \
\n \
\n     'sudo -i' \
\n     'passwd root'   # Set a secure password for root \
\n \
\n- Enable SSH access for the root user: \
\n \
\n     'nano /etc/ssh/sshd_config' \
\n \
\n- Find and modify the following lines: \
\n \
\n     'PermitRootLogin yes' \
\n     'PasswordAuthentication yes' \
\n \
\n- Save changes and restart the service: \
\n \
\n     'systemctl restart ssh' \
\n \
\n- You can now connect to the server from another machine as root, using PuTTY or WinSCP. \
\n- Install wget and omv-regen: \
\n \
\n     'apt-get update' \
\n     'apt-get upgrade -y' \
\n     'apt-get install wget -y' \
\n     'wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | bash' \
\n \
\n- Copy the backup to the server (WinSCP), start 'omv-regen', and run regeneration. omv-regen will install OMV and continue regeneration. \
\n \
\n______ SOME PRACTICAL TIPS AND NEW FEATURES \
\n \
\n- BACKUP SYSTEM: \
\n   - Backups are now managed through an automatic retention system: weekly, monthly, and yearly. \
\n   - You can keep historical copies without filling your disk; older ones are safely deleted according to your settings. \
\n \
\n- AUTOMATIC HOOK: \
\n   - omv-regen installs a hook that ensures all required packages are downloaded together with the backup. \
\n   - An initial system update after installing omv-regen guarantees that all packages are available from that point on. \
\n \
\n- AUTOMATIC SCHEDULING: \
\n   - omv-regen creates a default daily backup task, which can be modified from the OMV GUI. \
\n   - A weekly automatic cleanup of the hook is also scheduled to keep the system tidy. \
\n \
\n- OPTIONAL FOLDERS: \
\n   - Avoid including system folders in optional backups. \
\n   - Ensure they do not contain critical files that might affect the new system. \
\n \
\n- CONTAINER-BASED PLUGINS: \
\n   - omv-regen only backs up configurations visible in the OMV GUI. \
\n   - Podman-based plugins such as Filebrowser or Photoprism should be backed up manually. \
\n \
\n- OPENMEDIAVAULT-APTTOOL: \
\n   - If you use the apttool plugin, packages installed through it \
\n   - will be automatically installed during regeneration. \
\n \
\n- SYMLINKS AND MANUAL CONFIGURATIONS: \
\n   - Links created with omv-symlinks will be automatically regenerated. \
\n   - Links created manually from the CLI will need to be reconfigured. \
\n \
\n- DOCKER: \
\n   - Store Docker data and volumes outside the system drive, \
\n   - preferably on a data disk, to prevent loss during regeneration. \
\n   - After regeneration, bring the containers back up through the OMV GUI. \
\n \
\n- ENCRYPTED DRIVES: \
\n   - If you use omv-luksencryption, make sure '/etc/crypttab' and decryption keys are accessible. \
\n   - omv-regen will transfer them to the new system and handle necessary reboots. \
\n \
\n- SYSTEM DRIVE: \
\n   - Install the new system on a different drive than the original. \
\n   - This way, you can keep the old drive as a backup in case of issues. \
\n \
\n______ INTERNAL OPERATION \
\n \
\n- During installation: \
\n \
\n   - If the system is Debian and OMV is not yet installed, dialog will be installed first. \
\n   - A hook is set up to capture installed packages in real-time. \
\n   - A weekly cron job is configured to clean the hook that updates the local repository, if not already done that week. \
\n   - The omv-regen log is configured. \
\n   - The '/var/lib/omv-regen' folder is created with configuration files and the local repository. \
\n   - A daily scheduled backup task is configured, editable from the OMV GUI. \
\n   - If the system language is Spanish, omv-regen automatically adjusts to Spanish. \
\n \
\n- During backup execution: \
\n \
\n   - Although not required, you can enable automatic OMV updates. \
\n   - The local repository is updated with the necessary packages captured in the hook and added to the backup. \
\n   - Obsolete backups are deleted according to retention settings. \
\n \
\n- During regeneration: \
\n \
\n   - You can skip installing non-essential plugins. \
\n   - A service is configured to automatically resume regeneration after each reboot. \
\n      - You can run 'omv-regen' at any time to view the live log. \
\n   - AppArmor will be uninstalled if present. \
\n   - If OMV is not installed, it is installed using Aaron Murray’s OMV installation script. \
\n      - This installation includes omv-extras even if it was not part of the original system. \
\n   - The original versions of OMV and plugins are installed and held until completion. \
\n   - Parts of the database are replaced in logical order, executing SaltStack commands to apply configurations. \
\n   - At the end, holds are released and the system is safely updated to the latest package versions. \
\n \
\n- Special features: \
\n \
\n   - omv-regen prevents multiple instances from running simultaneously, except during regeneration to allow viewing the live log. \
\n \
\n______ NOTES AND RECOMMENDATIONS \
\n \
\n- Minimum requirements: Debian or OMV 64-bit system and stable Internet connection. \
\n   - It is recommended to run 'omv-regen' as root. \
\n \
\n- Logs and monitoring: \
\n   - Execution logs are saved in '/var/log/omv-regen.log'. \
\n   - If regeneration is interrupted, you can resume it by running 'omv-regen' again. \
\n \
\n- Version compatibility: \
\n   - omv-regen regenera requires the OMV version to be equal to or lower than the original system’s version. \
\n   - Do not update OMV; let omv-regen do it, or let it install OMV from Debian. \
\n   - Once the process is complete, omv-regen will safely update the system. \
\n \
\n- Backups: \
\n   - Always store a copy of the backup outside the server before starting regeneration. \
\n   - Do not delete the original backup until confirming the new system works properly. \
\n \
\n- Security: \
\n   - omv-regen does not modify data disks; it only affects the system. \
\n   - Verify that all original disks are connected before starting regeneration. \
\n \
\n- Manual recovery: If regeneration stops due to installation issues: \
\n   - Clean the current regeneration from the omv-regen GUI to unlock package versions. \
\n   - From that point, the system is in your hands. \
\n \
\n- Considerations for systems using SD cards (Raspberry Pi and similar devices): \
\n   - During the system regeneration process, omv-regen performs intensive read and write operations. \
\n   - On devices that use flash storage (such as SD or eMMC cards), this process can cause significant wear and shorten the lifespan of the storage medium. \
\n   - Systems with 2GB of RAM may experience instability, especially when applying multiple configuration changes or restarting services, as using swap increases the risk of failure and additional wear on the SD card. \
\n   - Recommendations: \
\n      - Whenever possible, perform the regeneration on a USB-connected SSD. \
\n      - If you use an SD card, choose a high-quality one and avoid running multiple regenerations on the same card. \
\n      - Consider using models with 4GB of RAM or more for greater stability. \
\n \
\n- Support: \
\n   - For questions or issues, visit the official OpenMediaVault forum. \
\n   - Include the latest log entries to get faster help. \
\n \
\n- Final note: \
\n   - omv-regen is designed to provide reliable and automated restoration. \
\n   - However, use it responsibly and always review the messages before confirming each step. \
\n"

txt AyudaMenuBackup \
"\n \
\n                                       AYUDA DE OMV-REGEN BACKUP \
\n \
\n \
\n    POSIBLES MENSAJES DE ERROR____________________________________________ \
\n \
\n        ⚫ LA RUTA DE DESTINO DEL BACKUP NO EXISTE O NO SE PUEDE ESCRIBIR ⚫ \
\n          Asegúrate de que la ruta de destino existe y se puede escribir. Cambia la ruta si es necesario. \
\n \
\n    QUÉ CONTIENE EL BACKUP________________________________________________ \
\n \
\n        - Al ejecutar 'omv-regen backup', se generan uno o más archivos comprimidos con tar en la carpeta de destino configurada. \
\n        - Un backup puede incluir: \
\n \
\n                ${AzulD}ORBackup_241001_103828_d_s_m_regen.tar.gz${ResetD} \
\n                ${AzulD}ORBackup_241001_103828_d_s_m_regen.sha56${ResetD} \
\n                ${AzulD}ORBackup_241001_103828_d_s_m_user1.tar.gz${ResetD} \
\n \
\n            Estructura del nombre: \
\n                ORBackup_         → Cabecera fija. Puedes cambiarla para proteger un backup de la eliminación automática. \
\n                _241001_103828_   → Fecha y hora (Ejemplo: 2024-10-01 10:38:28h), identifica los archivos de un mismo backup. \
\n                _d_s_m_           → Retenciones (diaria, semanal o mensual). Controla la eliminación automática. \
\n                _regen            → Archivo principal y su checksum, necesarios para regenerar el sistema. \
\n                _user1 _user2 ... → Archivos adicionales con las carpetas configuradas por el usuario. \
\n \
\n    CÓMO CONFIGURAR EL BACKUP_____________________________________________ \
\n \
\n        ${AzulD}CARPETA DE BACKUPS${ResetD} \
\n            - Carpeta donde se guardan los backups (por defecto /ORBackup). \
\n            - Asegúrate de que sea accesible y no forme parte de las carpetas adicionales. \
\n \
\n        ${AzulD}RETENCIONES DE BACKUPS${ResetD} \
\n            - Omv-regen elimina automáticamente backups antiguos según las retenciones configuradas. \
\n            - Retención semanal de 4 semanas: se conservará un backup por cada una de las últimas 4 semanas. \
\n            - Tipos de retención: diaria, semanal y mensual. Por defecto: 7 días, 4 semanas y 6 meses. \
\n            - Funciona mejor si haces backups regularmente, usando la tarea programada. \
\n \
\n        ${AzulD}ACTUALIZAR OPENMEDIAVAULT${ResetD} \
\n            - Al activar esta opción, el sistema se actualizará antes de hacer el backup. \
\n            - Proceso de actualización: \
\n                - Si hay un reinicio pendiente, se hace primero el backup y luego se reinicia. No se actualiza. \
\n                - Después de actualizar, se aplican los cambios de configuración con Salt si es necesario. \
\n                - Si se requiere otro reinicio, se hace el backup y luego se reinicia. \
\n                - El reinicio se realizará solo si es necesario y si la actualización finalizó correctamente. \
\n \
\n        ${AzulD}MODO SILENCIO${ResetD} \
\n            - Reduce la salida de 'omv-regen backup' a mensajes esenciales. \
\n            - Útil para notificaciones cortas por correo. \
\n            - Los resultados de la actualización de OMV siempre se imprimirán en el correo. \
\n            - El registro completo del backup estará disponible en /var/log/omv-regen.log. \
\n \
\n        ${AzulD}TAREA PROGRAMADA${ResetD} \
\n            - Por defecto, omv-regen crea una tarea diaria a las 3:00 a.m. \
\n            - Puedes personalizarla o eliminarla desde la GUI de OMV. \
\n            - Desde la GUI de omv-regen también puedes crear o eliminar esta tarea. \
\n" \
"\n \
\n                                       OMV-REGEN BACKUP HELP \
\n \
\n \
\n    POSSIBLE ERROR MESSAGES_______________________________________________ \
\n \
\n        ⚫ BACKUP DESTINATION PATH DOES NOT EXIST OR IS NOT WRITABLE ⚫ \
\n          Make sure the destination path exists and is writable. Change it if necessary. \
\n \
\n    WHAT THE BACKUP CONTAINS______________________________________________ \
\n \
\n        - When you run 'omv-regen backup', one or more tar-compressed files are generated in the configured destination folder. \
\n        - A backup may include: \
\n \
\n                ${AzulD}ORBackup_241001_103828_d_s_m_regen.tar.gz${ResetD} \
\n                ${AzulD}ORBackup_241001_103828_d_s_m_regen.sha56${ResetD} \
\n                ${AzulD}ORBackup_241001_103828_d_s_m_user1.tar.gz${ResetD} \
\n \
\n            Filename structure: \
\n                ORBackup_         → Fixed header. You can change it to protect a backup from automatic deletion. \
\n                _241001_103828_   → Date and time (example: 2024-10-01 10:38:28h), identifies files from the same backup. \
\n                _d_s_m_           → Retention tags (daily, weekly, or monthly). Controls automatic deletion. \
\n                _regen            → Main file and its checksum, required to regenerate the system. \
\n                _user1 _user2 ... → Additional files containing user-defined folders. \
\n \
\n    HOW TO CONFIGURE BACKUPS______________________________________________ \
\n \
\n        ${AzulD}BACKUP FOLDER${ResetD} \
\n            - Folder where backups are stored (default: /ORBackup). \
\n            - Make sure it’s accessible and not included among the additional folders. \
\n \
\n        ${AzulD}BACKUP RETENTIONS${ResetD} \
\n            - Omv-regen automatically deletes old backups according to the configured retention policy. \
\n            - Weekly retention of 4 weeks: keeps one backup for each of the last 4 weeks. \
\n            - Retention types: daily, weekly, and monthly. Defaults: 7 days, 4 weeks, 6 months. \
\n            - Works best when backups are performed regularly, using the scheduled task. \
\n \
\n        ${AzulD}UPDATE OPENMEDIAVAULT${ResetD} \
\n            - When enabled, the system will be updated before creating the backup. \
\n            - Update process: \
\n                - If a reboot is pending, the backup is created first and then the system reboots. No update is performed. \
\n                - After updating, configuration changes are applied with Salt if needed. \
\n                - If another reboot is required, the backup is made first and then the reboot is performed. \
\n                - Reboot only occurs if necessary and if the update finished successfully. \
\n \
\n        ${AzulD}SILENT MODE${ResetD} \
\n            - Reduces 'omv-regen backup' output to essential messages. \
\n            - Useful for short email notifications. \
\n            - The results of the OMV update will always appear in the email. \
\n            - The full backup log is available at /var/log/omv-regen.log. \
\n \
\n        ${AzulD}SCHEDULED TASK${ResetD} \
\n            - By default, omv-regen creates a daily task at 3:00 a.m. \
\n            - You can customize or remove it from the OMV GUI. \
\n            - It can also be created or deleted from the omv-regen GUI. \
\n" \

txt AyudaMenuRegenera \
"\n \
\n                              AYUDA DE OMV-REGEN REGENERA \
\n \
\n    EJECUCIÓN DE LA REGENERACIÓN \
\n \
\n        - Copia los archivos del backup (misma fecha y hora) a tu PC (por ejemplo con WinSCP). \
\n        - Instala OpenMediaVault o Debian en otro disco o pendrive diferente. No configures nada en la GUI. \
\n        - Conecta los discos de datos del sistema original al nuevo sistema. \
\n        - Copia los archivos del backup en el nuevo sistema. \
\n        - Instala omv-regen y ejecuta la regeneración desde el menú. \
\n \
\n    ⚫ → MENSAJES DE ERROR → No se puede ejecutar la regeneración. \
\n    ⬛ → ADVERTENCIAS → Información a tener en cuenta, pero la regeneración puede continuar. \
\n \
\n    ERRORES/ADVERTENCIAS DE BACKUP \
\n \
\n        ⚫ NO SE PUEDE ENCONTRAR EL BACKUP DE FECHA ___________ DE LA REGENERACION EN CURSO ⚫ \
\n            El archivo necesario para la regeneración no se encuentra en la ruta indicada. \
\n                >>> Verifica la ruta y la presencia de los archivos. \
\n        ⚫ NO HAY NINGÚN BACKUP EN ESTA RUTA ⚫ \
\n            No se han encontrado archivos de backup. \
\n                >>> Comprueba la ruta y que los archivos estén presentes. \
\n        ⚫ EL CONTENIDO ESENCIAL DEL BACKUP DE FECHA ____________ ESTÁ INCOMPLETO ⚫ \
\n            Faltan archivos críticos en el archivo etiquetado como _regen.tar. \
\n                >>> Puede deberse a corrupción o fallo al guardar. Genera un nuevo backup completo. \
\n        ⚫ LA MARCA DE FECHA DEL ARCHIVO TAR NO ES CORRECTA ______________ ⚫ \
\n            La fecha del archivo TAR no coincide con la esperada. \
\n                >>> Usa nombres preestablecidos para evitar errores. \
\n        ⚫ EL NOMBRE DEL ARCHIVO _____________ NO CUMPLE CON EL FORMATO ESPERADO ⚫ \
\n            El nombre del archivo no sigue el formato estándar. \
\n                >>> Renómbralo según: ORBackup_YYMMDD_HHMMSS_regen.tar.gz (marcas _d_s_m_ opcionales) \
\n        ⚫ NO SE PUEDE LEER EL ARCHIVO DE INFORMACION INTERNO DEL BACKUP ⚫ \
\n            El backup no contiene la información necesaria o no es legible. \
\n                >>> Comprueba integridad y permisos. \
\n        ⚫ NO SE PUDO DESCOMPRIMIR EL ARCHIVO TAR DE BACKUP ⚫ \
\n            El sistema no pudo descomprimir el archivo TAR. \
\n                >>> Puede estar corrupto o con formato incorrecto. Reintenta o genera un nuevo backup. \
\n        ⬛ ADVERTENCIA ⬛ NO SE PUEDE VALIDAR EL CHECKSUM \
\n            La verificación de checksum falló. Puede faltar el archivo o estar dañado. \
\n                >>> Si el checksum existe, considera repetir el backup. \
\n \
\n    INCOMPATIBILIDADES DEL SISTEMA \
\n \
\n        ⚫ EL SISTEMA ACTUAL YA ESTÁ CONFIGURADO ⚫ \
\n            Se requiere un sistema limpio, recién instalado y sin configuraciones en OMV. \
\n                >>> Usa un sistema limpio para continuar. \
\n        ⚫ LA INSTALACION ACTUAL DE OPENMEDIAVAULT ESTÁ EN MAL ESTADO ⚫ \
\n            OpenMediaVault no funciona correctamente. \
\n                >>> Corrige los errores antes de regenerar. \
\n        ⚫ LA VERSION DE OMV INSTALADA ES SUPERIOR A LA DEL SISTEMA ORIGINAL ⚫ \
\n            No es posible regenerar un sistema previo con una versión más reciente de OMV. \
\n                >>> Instala la misma versión o inferior de OMV, o inicia desde Debian limpio. \
\n        ⚫ EL SISTEMA ACTUAL ES DE 32 BITS, INSTALA UN SISTEMA DE 64 BITS ⚫ \
\n            No se admite regeneración en sistemas de 32 bits. \
\n                >>> Cambia a 64 bits para compatibilidad. \
\n \
\n    ERRORES/ADVERTENCIAS DE REGENERACION \
\n \
\n        ⬛ ADVERTENCIA ⬛ FALTAN PAQUETES NECESARIOS EN EL BACKUP: ____________________ \
\n            No todos los paquetes requeridos están presentes. La regeneración puede fallar. \
\n                >>> Descarga los paquetes faltantes o genera un backup completo. \
\n        ⬛ ADVERTENCIA ⬛ LA CPU DE ESTE SISTEMA ES INCOMPATIBLE CON KVM \
\n            KVM no se instalará porque la CPU no soporta virtualización. \
\n                >>> Usa hardware compatible si necesitas KVM. \
\n        ⚫ ZFS DETECTADO EN EL BACKUP Y SISTEMA ARM, NO SOPORTADO ⚫ \
\n            ZFS no es compatible con ARM en OMV y omv-regen. \
\n                >>> Usa una arquitectura compatible o elimina ZFS. \
\n        ⬛ ADVERTENCIA ⬛ PERDERÁS LA CONEXIÓN AL FINALIZAR. La nueva IP será ⬛ __________ ⬛ \
\n            La regeneración restablecerá la configuración de red, incluyendo la IP. \
\n                >>> Nueva IP: __________. Conéctate nuevamente tras el reinicio. \
\n" \
"\n \
\n                              OMV-REGEN REGENERATION HELP \
\n \
\n    RUNNING THE REGENERATION \
\n \
\n        - Copy the backup files (same date and time) to your PC (e.g., using WinSCP). \
\n        - Install OpenMediaVault or Debian on another disk or USB drive. Do not configure anything in the GUI. \
\n        - Connect the original data drives to the new system. \
\n        - Copy the backup files to the new system. \
\n        - Install omv-regen and start the regeneration from the menu. \
\n \
\n    ⚫ → ERROR MESSAGES → The regeneration cannot continue. \
\n    ⬛ → WARNINGS → Information to keep in mind, but regeneration can continue. \
\n \
\n    BACKUP ERRORS/WARNINGS \
\n \
\n        ⚫ CANNOT FIND BACKUP DATED ___________ FOR THE CURRENT REGENERATION ⚫ \
\n            The required file for regeneration is not found in the specified path. \
\n                >>> Verify the path and that the files are present. \
\n        ⚫ NO BACKUPS FOUND IN THIS PATH ⚫ \
\n            No backup files were found. \
\n                >>> Check the path and make sure the files are present. \
\n        ⚫ ESSENTIAL CONTENT MISSING IN BACKUP DATED ____________ ⚫ \
\n            Critical files are missing from the _regen.tar archive. \
\n                >>> May be due to corruption or save failure. Generate a new complete backup. \
\n        ⚫ INCORRECT DATE TAG IN TAR FILE ______________ ⚫ \
\n            The TAR file date does not match the expected value. \
\n                >>> Use the predefined naming format to avoid errors. \
\n        ⚫ INVALID FILE NAME _____________ ⚫ \
\n            The file name does not follow the standard format. \
\n                >>> Rename it using this pattern: ORBackup_YYMMDD_HHMMSS_regen.tar.gz (optional _d_s_m_ tags) \
\n        ⚫ UNABLE TO READ INTERNAL BACKUP INFORMATION FILE ⚫ \
\n            The backup lacks required information or is unreadable. \
\n                >>> Check file integrity and permissions. \
\n        ⚫ FAILED TO EXTRACT BACKUP TAR FILE ⚫ \
\n            The system could not extract the TAR archive. \
\n                >>> It may be corrupted or incorrectly formatted. Retry or create a new backup. \
\n        ⬛ WARNING ⬛ CHECKSUM VALIDATION FAILED \
\n            Checksum verification failed. The file may be missing or damaged. \
\n                >>> If the checksum file exists, consider regenerating the backup. \
\n \
\n    SYSTEM INCOMPATIBILITIES \
\n \
\n        ⚫ CURRENT SYSTEM IS ALREADY CONFIGURED ⚫ \
\n            A clean, freshly installed system without OMV configurations is required. \
\n                >>> Use a clean system to continue. \
\n        ⚫ CURRENT OPENMEDIAVAULT INSTALLATION IS CORRUPTED ⚫ \
\n            OpenMediaVault is not functioning correctly. \
\n                >>> Fix the issues before regenerating. \
\n        ⚫ INSTALLED OMV VERSION IS NEWER THAN THE ORIGINAL SYSTEM ⚫ \
\n            You cannot regenerate an older system using a newer OMV version. \
\n                >>> Install the same or an older OMV version, or start from a clean Debian installation. \
\n        ⚫ CURRENT SYSTEM IS 32-BIT, INSTALL A 64-BIT SYSTEM ⚫ \
\n            Regeneration is not supported on 32-bit systems. \
\n                >>> Switch to 64-bit for compatibility. \
\n \
\n    REGENERATION ERRORS/WARNINGS \
\n \
\n        ⬛ WARNING ⬛ MISSING REQUIRED PACKAGES IN BACKUP: ____________________ \
\n            Not all required packages are present. Regeneration may fail. \
\n                >>> Download the missing packages or create a full backup. \
\n        ⬛ WARNING ⬛ CPU IS INCOMPATIBLE WITH KVM \
\n            KVM will not be installed because the CPU does not support virtualization. \
\n                >>> Use compatible hardware if KVM is required. \
\n        ⚫ ZFS DETECTED IN BACKUP AND ARM SYSTEM, NOT SUPPORTED ⚫ \
\n            ZFS is not supported on ARM systems in OMV or omv-regen. \
\n                >>> Use a compatible architecture or remove ZFS. \
\n        ⬛ WARNING ⬛ YOU WILL LOSE CONNECTION WHEN FINISHED. The new IP will be ⬛ __________ ⬛ \
\n            Regeneration will restore the network configuration, including the IP. \
\n                >>> New IP: __________. Reconnect after reboot. \
\n"

    AYUDA=("${txt[AyudaOmvregen]}" "${txt[AyudaMenuBackup]}" "${txt[AyudaMenuRegenera]}")
    FormatearSiNo
}

########################################## MENUS GRAFICOS ##########################################
########################################## GRAPHIC MENUS ###########################################

# MENU PRINCIPAL
# MAIN MENU
MenuPrincipal() {
    local porc_pant_alto_0=50 porc_pant_ancho_0=50 alto_min_0=23 ancho_min_0=90
    local alto ancho desplaz alto_pan_0 ancho_pan_0
    local texto salida_0

    while true; do
        if [[ $VIA == 0 ]]; then
            [[ $(tput lines) -lt 14 || $(tput cols) -lt 71 ]] && \
                Salir nolog ">>> La pantalla es demasiado pequeña. Ajusta el tamaño del terminal e inténtalo nuevamente." \
                            ">>> The screen is too small. Resize the terminal and try again."

            read -r alto ancho desplaz alto_pan_0 ancho_pan_0 _ < <(definir_ventana "$porc_pant_alto_0" "$porc_pant_ancho_0" "$alto_min_0" "$ancho_min_0")
            LimpiarTxt
            if [[ $alto_pan_0 -lt 20 || $ancho_pan_0 -lt 85 ]]; then
                txtc 1 "\n┌───────────────────┐\n│     omv-regen     │\n└───────────────────┘"
            else
                txtc 1 "$Logo_omvregen"
            fi
            if [ "${CFG[UltimaBusqueda]}" = "1" ]; then
                ((alto++))
                txtc 2 "\n¡¡ HAY UNA ACTUALIZACION DISPONIBLE DE OMV-REGEN !!" \
                       "\nAN OMV-REGEN UPDATE IS AVAILABLE !!"
            fi
            if ! omv_instalado; then
                ((alto++))
                txtc 3 "\nOMV NO ESTÁ INSTALADO. EJECUTA REGENERA." \
                       "\nOMV IS NOT INSTALLED. PLEASE RUN REGENERA."
            fi
            if [ "${CFG[ActualizarOmvregen]}" = "No" ]; then
                txt 5 "Activar actualizaciones de omv-regen.           " \
                      "Enable omv-regen updates.                       "
            else
                txt 5 "Desactivar actualizaciones de omv-regen.        " \
                      "Disable omv-regen updates.                      "
            fi
            txt T_Backup           "              BACKUP     → Configurar/Crear un backup del sistema actual.  " \
                                   "              BACKUP     → Configure/Create a backup of the current system."
            txt T_Regenera         "            REGENERA     → Regenerar desde un backup en el sistema actual. " \
                                   "            REGENERA     → Regenerate from a backup on the current system. "
            txt T_Actualizar       "          Actualizar     → ${txt[5]}" \
                                   "              Update     → ${txt[5]}"
            txt T_Resetear         "            Resetear     → Resetear ajustes.                               " \
                                   "               Reset     → Reset settings.                                 "
            txt T_Idioma           "              Idioma     → Cambiar idioma a Inglés.                        " \
                                   "            Languaje     → Change language to Spanish.                     "
            txt T_Ayuda            "               Ayuda     → Ayuda general.                                  " \
                                   "                Help     → General help.                                   "
            txt T_Salir            "               Salir     → Salir.                                          " \
                                   "                Exit     → Exit.                                           "
            clear
            VIA=$(dialog --backtitle "omv-regen ${ORVersion}" \
                        --ok-label "${txt[B_Continuar]}" \
                        --cancel-label "${txt[B_Salir]}" \
                        --help-button \
                        --help-label "${txt[B_Ayuda]}" \
                        --no-tags \
                        --stdout \
                        --menu "${txt[1]}${txt[2]}${txt[3]} " "$alto" "$ancho" 8 1 "${txt[T_Backup]}" 2 "${txt[T_Regenera]}" 3 "" 4 "${txt[T_Actualizar]}" 5 "${txt[T_Resetear]}" 6 "${txt[T_Idioma]}" 7 "${txt[T_Ayuda]}" 8 "${txt[T_Salir]}")
            salida_0=$?
        fi
        case $salida_0 in
            1|255) VIA=8 ;;
            2) VIA=7 ;;
        esac
        case $VIA in
            1)  MenuBackup ;;
            2)  MenuRegenera ;;
            3)  VIA=0 ;;
            4)  AlternarOpcion ActualizarOmvregen "${txt[5]}" "${txt[5]}"; VIA=0 ;;
            5)  ResetearOmvregen; VIA=0 ;;
            6)  [ "${CFG[Idiomas]}" = "en" ] && InstalarEsp
                AlternarOpcion Idiomas "Cambiar el idioma a Inglés.\nChange the language to English." \
                                       "Change the language to Spanish.\nCambiar el idioma a Español."; VIA=0 ;;
            7)  Ayuda; VIA=0 ;;
            8)  clear; Salir ;;
            9) 
                if Continuar 10 "\n\n  Se va a realizar un BACKUP en  \n\n  ${CFG[RutaBackups]} \n\n " \
                                "\n\n  A BACKUP is going to be made in  \n\n  ${CFG[RutaBackups]} \n\n "; then
                    Mostrar EjecutarBackup || Mensaje error "No se ha podido completar el backup. ${txt[error]}" \
                                                            "The backup could not be completed. ${txt[error]}"
                fi
                VIA=1
                backup_desatendido && Salir
                ;;
            10)
                EjecutarRegenera || Mensaje error "La regeneración se ha detenido. Revisa los registros.\n${txt[error]}" \
                                                  "Regeneration has stopped. Check the logs.\n${txt[error]}"
                VIA=2
                regen_auto && Salir ">>> Regeneración en modo auto abortada. Saliendo ..." \
                                    ">>> Regeneration in auto mode aborted. Exiting ..."
                ;;
            11) 
                LimpiezaSemanal || error "No se ha podido realizar la limpieza semanal del hook. ${txt[error]}" \
                                         "The weekly cleaning of the hook could not be carried out. ${txt[error]}"
                Salir
                ;;
        esac
    done
}

MenuBackup() {
    local porc_pant_alto=70 porc_pant_ancho=70 alto_min=21 ancho_min=100 margen=6
    local alto ancho desplaz altoPan anchoPan linea 
    local cont salida_menu=0 respuesta dirs carpeta clave

    while [[ $VIA == 1 ]]; do
        read -r alto ancho desplaz altoPan anchoPan linea < <(definir_ventana $porc_pant_alto $porc_pant_ancho $alto_min $ancho_min)
        if [[ $anchoPan -lt 106 ]]; then
            Mensaje ">>> La pantalla es demasiado pequeña. Ajusta el tamaño del terminal e inténtalo nuevamente." \
                    ">>> The screen is too small. Resize the terminal and try again."
            VIA=0
            return 1
        fi
        LimpiarTxt
        txt lin "$linea"
        txtc 2 "\n┌──────────────────────────┐\n│     omv-regen backup     │\n└──────────────────────────┘"
        
        if dir_backups_es_ok; then
            txt 50 "_____________________________________ EJECUTAR UN BACKUP AHORA ________________________________________" \
                   "_________________________________________ RUN A BACKUP NOW ____________________________________________"
        else
            txt 50 "_____________________________⚫ LOS AJUSTES ACTUALES NO SON VÁLIDOS ⚫________________________________" \
                   "_______________________________⚫ CURRENT SETTINGS ARE NOT VALID ⚫___________________________________"
            txtc 22 "⚫ LA CARPETA DE DESTINO DE LOS BACKUPS NO EXISTE O NO SE PUEDE ESCRIBIR ⚫" \
                    "⚫ THE BACKUP DESTINATION FOLDER DOES NOT EXIST OR CANNOT BE WRITTEN ⚫"; ((alto_min++))
        fi
        
        txtm 0 20 "CARPETA DE BACKUPS" \
                  "BACKUPS FOLDER"
        txtm 4 21 "${CFG[RutaBackups]}"

        txtm 0 30 "CARPETAS ADICIONALES" \
                  "ADDITIONAL FOLDERS"
        txt 32 "Esta carpeta no existe. No se incluirá en el backup." \
               "This folder does not exist. It will not be included in the backup."
        dirs=""
        cont=0
        for carpeta in "${CARPETAS_ADICIONALES[@]}"; do
            if [ -n "$carpeta" ]; then
                ((cont++))
                if [ -d "$carpeta" ]; then
                    dirs="${dirs}${txt[Carpeta]^^} $cont  → ${carpeta}\n"; ((alto_min++))
                else
                    dirs="${dirs}${txt[Carpeta]^^} $cont  → ${carpeta}\n    >>> **** ${txt[32]}\n"; ((alto_min+=2))
                fi
            fi
        done
        if [ -n "$dirs" ]; then
            txtm 4 31 "$dirs"
        else txtm 8 31 ">>> No se han incluido carpetas opcionales." \
                       ">>> No optional folders have been included."; ((alto_min++)); fi
        
        if [ -n "$RepoIncompleto" ]; then
            txt 32 "${txt[lin]}"
            txtm 8 33 "⬛ ADVERTENCIA: FALTAN PAQUETES EN EL REPOSITORIO, OMV-REGEN INTENTARÁ DESCARGARLOS. ⬛" \
                      "⬛ WARNING: PACKAGES ARE MISSING IN THE REPOSITORY, OMV-REGEN WILL ATTEMPT TO DOWNLOAD THEM. ⬛"
        fi

        [[ $alto -lt $alto_min ]] && alto=$alto_min
        if [[ $altoPan -lt $alto_min ]]; then
            txt 30 "" ""; txt 31 "" ""; txt lin ""
        fi
        if [[ $anchoPan -lt $((ancho_min + 4)) ]]; then
            txt lin ""
        fi
        
        txt 1 "${txt[2]}${txt[lin]}${txt[20]}${txt[21]}${txt[22]}${txt[lin]}${txt[30]}${txt[31]}${txt[33]}"
        
        local d s m
        d="${CFG[RetencionDias]}";    [[ $d -lt 10 ]] && d="0$d"
        s="${CFG[RetencionSemanas]}"; [[ $s -lt 10 ]] && s="0$s"
        m="${CFG[RetencionMeses]}";   [[ $m -lt 10 ]] && m="0$m"
        txt 63 "Desactivado ------------------------------> " \
               "Disabled ---------------------------------> "
        txt 64 "Activado ---------------------------------> " \
               "Enabled ----------------------------------> "
        case "${CFG[ActualizarOMV]}" in
            No)     txt 61 "${txt[63]}"; txt 62 "Activar actualización de OMV    " \
                                                "Enable OMV update               " ;;
            Si|Yes) txt 61 "${txt[64]}"; txt 62 "Desactivar actualización de OMV " \
                                                "Disable OMV update              " ;;
        esac
        case "${CFG[ModoSilencio]}" in
            No)     txt 71 "${txt[63]}"; txt 72 "Activar Modo silencio           " \
                                                "Enable Silent mode              " ;;
            Si|Yes) txt 71 "${txt[64]}"; txt 72 "Desactivar Modo silencio        " \
                                                "Disable Silent mode             " ;;
        esac
        case "${CFG[OmitirRoot]}" in
            No)     txt 81 "${txt[63]}"; txt 82 "Activar omisión carpeta /root   " \
                                                "Enable skipping /root folder    " ;;
            Si|Yes) txt 81 "${txt[64]}"; txt 82 "Desactivar omisión carpeta /root" \
                                                "Disable skipping /root folder   " ;;
        esac

        if existe_tarea_backup; then
            txt 91 "Existe una tarea de backup ---------------> " \
                   "There is a backup task -------------------> "
            txt 92 "Eliminar tarea programada       " \
                   "Delete scheduled task           "
        else
            txt 91 "No existe tarea programada ---------------> " \
                   "There is no scheduled task ---------------> "
            txt 92 "Crear y activar tarea programada" \
                   "Create and enable scheduled task"
        fi

        txt 51 "  CARPETA DE BACKUPS    ---------------------------------------------> Cambiar carpeta de destino      " \
               "  BACKUPS FOLDER        ---------------------------------------------> Change destination folder       "
        txt 52 "  CARPETAS ADICIONALES  ---------------------------------------------> Cambiar carpetas adicionales    " \
               "  ADDITIONAL FOLDERS    ---------------------------------------------> Change additional folders       "
        txt 53 "  PERIODOS DE RETENCION -- Diario $d --- Semanal $s --- Mensual $m --> Cambiar períodos de retención   " \
               "  RETENTION PERIODS     -- Daily $d ---- Weekly $s ---- Monthly $m --> Change retention periods        "
        txt 54 "  ACTUALIZAR OMV        -- ${txt[61]}${txt[62]}" \
               "  UPDATE OMV            -- ${txt[61]}${txt[62]}"
        txt 55 "  SALIDA EN SILENCIO    -- ${txt[71]}${txt[72]}" \
               "  OUTPUT IN SILENCE     -- ${txt[71]}${txt[72]}"
        txt 56 "  OMITIR CARPETA /root  -- ${txt[81]}${txt[82]}" \
               "  SKIP /root FOLDER     -- ${txt[81]}${txt[82]}"
        txt 57 "  TAREA PROGRAMADA      -- ${txt[91]}${txt[92]}" \
               "  SCHEDULED TASK        -- ${txt[91]}${txt[92]}"
        clear
        respuesta=$(dialog --backtitle "omv-regen $ORVersion" --title "omv-regen backup $ORVersion" \
            --ok-label "${txt[B_Continuar]}" \
            --cancel-label "${txt[B_Menu_Principal]}" \
            --help-button \
            --help-label "${txt[B_Ayuda]}" \
            --stdout \
            --menu "${txt[1]}" "$alto" "$ancho" 7 1 "${txt[50]}" 2 "" 3 "${txt[51]}" 4 "${txt[52]}" 5 "${txt[53]}" 6 "${txt[54]}" 7 "${txt[55]}" 8 "${txt[56]}" 9 "${txt[57]}")
        salida_menu=$?
        case $salida_menu in
            1|255) VIA=0 ;;
            2)  Ayuda AyudaMenuBackup ;;
            0)  case $respuesta in
                    1)  VIA=9 ;;
                    3)  MenuRutaBackups ;;
                    4)  MenuRutasAdicionales ;;
                    5)  MenuRetenciones ;;
                    6)  AlternarOpcion ActualizarOMV "${txt[62]}" ;;
                    7)  AlternarOpcion ModoSilencio "${txt[72]}" ;;
                    8)  AlternarOpcion OmitirRoot "${txt[82]}" ;;
                    9)  if Pregunta "${txt[92]} \n\n>>> ¿Quieres continuar?  " \
                                    "${txt[92]} \n\n>>> Do you want to continue?  "; then
                            if ProgramarBackup; then
                                Info 2 guardado
                            else
                                Mensaje ">>> No se ha podido configurar la tarea programada." \
                                        ">>> The scheduled task could not be configured."
                            fi
                        fi ;;
                esac ;;
        esac
    done
}

# Menu para definir la ruta de almacenamiento de backups
# Menu to define the backup storage path
MenuRutaBackups() {
    local ruta_inicial salida_menu=0

    txt 1 " Escribe la ruta a la CARPETA DE ALMACENAMIENTO DE LOS BACKUPS " \
          " Write the path to the STORAGE FOLDER OF THE BACKUPS "
    ruta_inicial="${CFG[RutaBackups]}"
    while [ $salida_menu = 0 ]; do
        clear
        CFG[RutaBackups]=$(dialog --backtitle "omv-regen $ORVersion" --title "${txt[1]}" \
            --ok-label "${txt[B_Continuar]}" \
            --cancel-label "${txt[B_Cancelar]}" \
            --stdout \
            --dselect "${CFG[RutaBackups]}" 25 90 )
        salida_menu=$?
        if [[ $salida_menu != 0 ]]; then
            CFG[RutaBackups]="$ruta_inicial"
            Info 2 cancelado
        else
            salida_menu=1
            case "${CFG[RutaBackups]}" in
                "") CFG[RutaBackups]="$ruta_inicial" ;;
                "$ruta_inicial") ;;
                "/ORBackup") ;;
                *)
                    if [ ! -d "${CFG[RutaBackups]}" ]; then
                        if Pregunta ">>> La carpeta ${CFG[RutaBackups]} no existe.\n\n>>> ¿Quieres crearla?" \
                                    ">>> The ${CFG[RutaBackups]} folder does not exist.\n\n>>> Do you want to create it?"; then
                            mkdir -p "${CFG[RutaBackups]}" || {
                                Mensaje ">>> No se ha podido crear la carpeta ${CFG[RutaBackups]}" \
                                        ">>> Could not create ${CFG[RutaBackups]} folder"
                                CFG[RutaBackups]="$ruta_inicial"
                            }
                        else
                            CFG[RutaBackups]="$ruta_inicial"
                            salida_menu=0
                        fi
                    fi
                    ;;
            esac
            if [[ "${CFG[RutaBackups]}" != "$ruta_inicial" ]]; then
                SalvarAjustes || { CFG[RutaBackups]="$ruta_inicial"; return 1; }
                Info 2 guardado
            fi
        fi
    done
    return 0
}

# Carpetas adicionales Backup
# Additional folders Backup
MenuRutasAdicionales() {
    local guardar=0 carpeta RUTAS=() respuesta accion sale
    
    txt 1 "Ruta de CARPETA ADICIONAL a incluir en el backup" \
          "ADDITIONAL FOLDER path to include in the backup"

    procesar_respuesta() {
        local carpeta=$1 entrada=$2
        local res="ignorar"
        case $entrada in
            "${txt[2]}")                    [ "$carpeta" = "extra" ] && res="terminar" ;;
            "${CFG[RutaBackups]}")          Mensaje ">>> $entrada es el destino del backup, no se puede incluir en el backup." \
                                                    ">>> $entrada is the backup destination, it cannot be included in the backup." ;;
            /root)                          Mensaje ">>> Selecciona en el menú del backup si quieres incluir la carpeta root. Se ignora." \
                                                    ">>> Select whether you want to include the root folder in the backup menu. It is ignored." ;;
            /etc/libvirt|/var/lib/libvirt)  Mensaje ">>> La carpeta $entrada se incluye por defecto en el backup. Se ignora." \
                                                    ">>> The $entrada folder is included by default in the backup. It is ignored." ;;
            "")                             [ "$carpeta" = "extra" ] && res="terminar" || res="eliminar" ;;
            /)                              Mensaje ">>> No se puede incluir rootfs en el backup." \
                                                    ">>> You cannot include rootfs in the backup." ;;
            /*)                             [ ! -d "$entrada" ] && Mensaje ">>> La carpeta $entrada no existe pero se añade a la lista." \
                                                                           ">>> The $entrada folder does not exist but is added to the list."
                                            res="ok" ;;
            *)                              Mensaje ">>> La carpeta debe comenzar con '/'" \
                                                    ">>> The folder must start with '/'" ;;
        esac
        echo "$res"
    }

    for carpeta in "${CARPETAS_ADICIONALES[@]}"; do
        while true; do
            clear
            respuesta=$(dialog --backtitle "omv-regen $ORVersion" --title "${txt[1]}" \
                --ok-label "${txt[B_Continuar]}" \
                --cancel-label "${txt[B_Quitar]}" \
                --stdout \
                --dselect "$carpeta" 25 90)
            sale=$?
            respuesta=$(echo "$respuesta" | xargs)
            case $sale in
                1)      accion="eliminar" ;;
                255)    Info 2 cancelado; return ;;
                0)      accion=$(procesar_respuesta "$carpeta" "$respuesta") ;;
            esac
            [ "$accion" != "ignorar" ] && break
        done
        case $accion in
            eliminar)   guardar=1
                        Mensaje ">>> La carpeta $carpeta no se incluirá en el backup." \
                                ">>> The $carpeta folder will not be included in the backup." ;;
            ok)         if [ "$carpeta" != "$respuesta" ]; then
                            Mensaje ">>> La carpeta $carpeta se ha sustituido por la carpeta $respuesta" \
                                    ">>> The $carpeta folder has been replaced by the $respuesta folder."
                            guardar=1
                        fi
                        RUTAS+=("$respuesta") ;;
        esac
    done

    txt 2 "/ CONTINUAR para terminar (o déjalo en blanco)." \
          "/ Press CONTINUE to finish (or leave it blank)."
    while [ "$accion" != "terminar" ]; do
        clear
        respuesta=$(dialog --backtitle "omv-regen $ORVersion" --title "${txt[1]}" \
            --ok-label "${txt[B_Continuar]}" \
            --cancel-label "${txt[B_Salir]}" \
            --stdout \
            --dselect "${txt[2]}" 25 90)
        sale=$?
        respuesta=$(echo "$respuesta" | xargs)
        case $sale in
            1)      accion="terminar" ;;
            255)    Info 2 cancelado; return ;;
            0)      accion=$(procesar_respuesta "extra" "$respuesta") ;;
        esac
        [ "$accion" = "ok" ] && RUTAS+=("$respuesta") && guardar=1
    done

    if [ $guardar -eq 1 ]; then
        CARPETAS_ADICIONALES=("${RUTAS[@]}")
        SalvarAjustes || return 1; Info 2 guardado
    fi
}

# Menu para definición de retenciones de eliminación de backups antiguos
# Menu for defining retentions for deleting old backups
MenuRetenciones() {
    local porPaAlto=60 porPaAncho=60 altoMin=26 anchoMin=90 margen=22
    local alto ancho desplaz altoPan anchoPan linea
    local valor_inicial respuesta="" salida_menu=0 hasta diass seman meses retencion

    read -r alto ancho desplaz altoPan anchoPan linea < <(definir_ventana $porPaAlto $porPaAncho $altoMin $anchoMin)
    for retencion in RetencionDias RetencionSemanas RetencionMeses; do
        valor_inicial="${CFG[$retencion]}"
        diass="${CFG[RetencionDias]}"
        seman="${CFG[RetencionSemanas]}"
        meses="${CFG[RetencionMeses]}"
        case $retencion in
            RetencionDias)    hasta=99; txt 41 "DIARIA"  "DAILY" ;;
            RetencionSemanas) hasta=52; txt 41 "SEMANAL" "WEEKLY" ;;
            RetencionMeses)   hasta=24; txt 41 "MENSUAL" "MONTHLY" ;;
        esac
        txtc 1 "\nOPCIONES DE BACKUP\n${linea}" \
               "\nBACKUP OPTIONS\n${linea}"
        txtc 2 "Períodos de retención de Backups\n\n\n\nConfigura los períodos de retención diario, semanal y mensual para los backups.\n\n\nConfiguración actual:" \
               "Backup Retention Periods\n\n\n\nConfigure daily, weekly, and monthly retention periods for backups.\n\n\nCurrent configuration:"
        txtm 0 3 "Retención diaria  →  $diass backups diarios\nRetención semanal →  $seman backups semanales\nRetención mensual →  $meses backups mensuales" \
                 "Daily retention   →  $diass daily backups\nWeekly retention  →  $seman weekly backups\nMonthly retention →  $meses monthly backups"
		txtc 4 "CONFIGURA LA RETENCIÓN ${txt[41]}\n( Selecciona con las teclas [ARRIBA/ABAJO] o [+/-] )" \
               "SET UP ${txt[41]} RETENTION\n( Select with the [UP/DOWN] or [+/-] keys )"
        if [ $salida_menu = 0 ]; then
            clear
            respuesta=$(dialog --backtitle "omv-regen $ORVersion" --title "omv-regen backup $ORVersion" \
                --ok-label "${txt[B_Continuar]}" \
                --cancel-label "${txt[B_Cancelar]}" \
                --rangebox "${txt[1]}${txt[2]}${txt[3]}\n\n\n${txt[4]}" $altoMin "$ancho" 0 $hasta "$valor_inicial" 3>&1 1>&2 2>&3 3>&-)
            salida_menu=$?
            if [[ $salida_menu != 0 ]]; then
                Info 2 cancelado
            elif [[ "$respuesta" != "$valor_inicial" ]]; then
                salvar_cfg $retencion "$respuesta" || return 1
                Info 2 guardado
            fi
        fi
    done
}

MenuRegenera() {
    local alto ancho desplaz altoPan anchoPan linea salida_menu=0 respuesta="" advertencias ip_actual backup_disponible=1
    local fecha_tar_en_curso
    fecha_tar_en_curso="$(awk -F "_" 'NR==1{print $2"_"$3}' <<< "$(basename "${CFG[RutaTarRegenera]}")")"

    validacion_tiene() {
        [[ " $ErrorValRegen " == *" $1 "* || " $InfoValRegen " == *" $1 "* ]] && return 0
        return 1
    }

    while [ "$VIA" = 2 ]; do
        local porPaAlto=77 porPaAncho=75 altoMin=46 anchoMin=106 margen=6 Tab=4
        read -r alto ancho desplaz altoPan anchoPan linea < <(definir_ventana $porPaAlto $porPaAncho $altoMin $anchoMin)
        advertencias=0
        LimpiarTxt
        txt lin "$linea"
        txtc lin2 "__________________________________________________________________________________________"
        txtc 2 "\n┌────────────────────────────┐\n│     omv-regen regenera     │\n└────────────────────────────┘"

        if Regenera_es_Valido; then
            txtc 3 "LOS AJUSTES ACTUALES SON VÁLIDOS\nAsegúrate de que has CONECTADO LAS UNIDADES DE DATOS del sistema original." \
                   "CURRENT SETTINGS ARE VALID\nMake sure you have CONNECTED THE DATA DRIVES of the original system."
        else txtc 3 "⚫ LOS AJUSTES ACTUALES NO SON VÁLIDOS ⚫\nConsulta la ayuda." \
                    "⚫ CURRENT SETTINGS ARE NOT VALID ⚫\nConsult the help."
        fi

        local tar_regen_nombre tar_regen_fecha tar_user_num
        tar_regen_nombre="$(basename "$TarRegenFile")"
        tar_regen_fecha="$( awk -F "_" 'NR==1{print $2"_"$3}' <<< "$tar_regen_nombre" )"
        tar_user_num="$(find "${CFG[RutaBackups]}" -name "ORBackup_${tar_regen_fecha}_*_user*.tar.gz" | grep -c .)"

        txtm 0 10 "Ruta a la carpeta del backup con los datos del sistema original." \
                  "Path to the backup folder with the original system data."
        txtm $Tab 11 "${txt[Ruta]^^}  → ${CFG[RutaBackups]}"
        if regen_en_progreso; then
            if validacion_tiene archivo_regen_en_progreso; then
                txtm 8 12 ">>> ⚫ NO SE PUEDE ENCONTRAR EL BACKUP DE FECHA $fecha_tar_en_curso DE LA REGENERACION EN CURSO ⚫" \
                          ">>> ⚫ CANNOT FIND THE BACKUP DATE $fecha_tar_en_curso OF THE REGENERATION IN PROGRESS ⚫"
            else txtm 8 12 ">>> El backup de la regeneración en curso $tar_regen_nombre está disponible." \
                           ">>> Backup of the ongoing regeneration $tar_regen_nombre is available."
                backup_disponible=0
            fi
        else
            if validacion_tiene ruta_origen_vacia; then
                txtm 8 13 ">>> ⚫ NO HAY NINGÚN BACKUP EN ESTA RUTA ⚫" \
                          ">>> ⚫ THERE IS NO BACKUP ON THIS PATH ⚫"
            else txtm 8 13 ">>> El backup mas reciente en esta ruta es $tar_regen_nombre" \
                           ">>> The most recent backup on this path is $tar_regen_nombre"
                backup_disponible=0
            fi
        fi
        if [ "$backup_disponible" = 0 ]; then
            if validacion_tiene contenido_incompleto; then
                txtm 8 14 ">>> ⚫ EL CONTENIDO ESENCIAL DEL BACKUP DE FECHA $tar_regen_fecha ESTÁ INCOMPLETO ⚫" \
                          ">>> ⚫ THE ESSENTIAL CONTENT OF THE BACKUP DATED $tar_regen_fecha IS INCOMPLETE ⚫"
            else txtm 8 14 ">>> El contenido esencial del backup está completo." \
                          ">>> The essential content of the backup is complete."        
            fi
            if [ "$tar_user_num" = 0 ]; then
                txtm 8 15 ">>> En este backup no hay carpetas opcionales para restaurar." \
                          ">>> In this backup there are no optional folders to restore."
            elif [ "$tar_user_num" -gt 0 ]; then
                txtm 8 15 ">>> En este backup hay carpetas opcionales que también se restaurarán. Total = $tar_user_num" \
                          ">>> In this backup there are optional folders that will also be restored. Total = $tar_user_num"
            fi
            if validacion_tiene checksum_no_validado; then
                txtm 8 16 ">>> ⬛ ADVERTENCIA ⬛ NO SE PUEDE VALIDAR EL CHECKSUM" \
                          ">>> ⬛ WARNING ⬛ THE CHECKSUM CANNOT BE VALIDATED"
                ((advertencias++))
            else txtm 8 16 ">>> Se ha comprobado el checksum del archivo y es válido." \
                          ">>> The file checksum has been checked and is valid."        
            fi
            if validacion_tiene fecha_info_incorrecta; then
                txtm 8 17 ">>> ⚫ LA MARCA DE FECHA DEL ARCHIVO TAR NO ES CORRECTA $tar_regen_fecha ⚫" \
                          ">>> ⚫ THE DATE STAMP ON THE TAR FILE IS NOT CORRECT $tar_regen_fecha ⚫"
            fi
            if validacion_tiene formato_nombre_archivo; then
                txtm 8 18 ">>> ⚫ EL NOMBRE DEL ARCHIVO $tar_regen_nombre NO CUMPLE CON EL FORMATO ESPERADO ⚫" \
                          ">>> ⚫ THE FILE NAME $tar_regen_nombre DOES NOT MEET THE EXPECTED FORMAT ⚫"
            fi
            if validacion_tiene error_lectura_RegenInfo_file; then
                txtm 8 19 ">>> ⚫ NO SE PUEDE LEER EL ARCHIVO DE INFORMACION INTERNO DEL BACKUP ⚫" \
                          ">>> ⚫ CANNOT READ THE INTERNAL BACKUP INFORMATION FILE ⚫"
            fi
            if validacion_tiene error_descomprimir_tar; then
                txtm 8 20 ">>> ⚫ NO SE PUDO DESCOMPRIMIR EL ARCHIVO TAR DE BACKUP ⚫" \
                          ">>> ⚫ THE BACKUP TAR FILE COULD NOT BE DECOMPRESSED ⚫"
            fi
        fi

        txtm 0 25 "Regenerar interfaz de red al finalizar la regeneración." \
                  "Regenerate network interface upon completion of regeneration."
        txtm $Tab 26 "${txt[Red]^^}  → $(TraducirSiNo "${CFG[RegenRed]}")"
        if [ "$backup_disponible" = 0 ]; then
            ip_actual=$( hostname -I | awk '{print $1}' )
            if [[ -n "$IPOriginal" && -n "$ip_actual" ]]; then
                txtm 8 27 ">>> IP original = $IPOriginal \n>>> IP actual   = $ip_actual"
                if [ "${CFG[RegenRed]}" = "No" ]; then
                    txtm 12 28 ">>> Con estos ajustes la IP seguirá siendo $ip_actual después de regenerar." \
                               ">>> With these settings the IP will still be $ip_actual after regenerating."
                elif [[ "$IPOriginal" != "$ip_actual" ]]; then
                    txtm 12 28 ">>> ⬛ ADVERTENCIA ⬛ PERDERÁS LA CONEXIÓN AL FINALIZAR. La nueva IP será ⬛ $IPOriginal ⬛" \
                               ">>> ⬛ WARNING ⬛ YOU WILL LOSE THE CONNECTION AT THE END. The new IP will be ⬛ $IPOriginal ⬛"
                    ((advertencias++))
                fi
            fi
        fi

        txtm 0 30 "Instalar el mismo kernel proxmox que tenía el sistema original." \
                  "Install the same proxmox kernel that the original system had."
        txtm $Tab 31 "KERNEL  → $(TraducirSiNo "${CFG[RegenKernel]}")"
        if [ "$backup_disponible" = 0 ]; then
            if [ "$KernelOriginal" = 0 ]; then
                txtm 8 32 ">>> El sistema original no tenía instalado ningún Kernel Proxmox." \
                          ">>> The original system did not have any Proxmox Kernel installed."
            else
                txtm 8 32 ">>> El sistema original tenía instalado el Kernel Proxmox $KernelOriginal" \
                          ">>> The original system had the Proxmox Kernel $KernelOriginal installed."
                if [ "${CFG[RegenKernel]}" = "No" ]; then
                    txtm 12 33 ">>> No se va a instalar el antiguo kernel proxmox. Si tienes ZFS o KVM reconsidera esto." \
                               ">>> The old proxmox kernel will not be installed. If you have ZFS or KVM reconsider this."
                fi
            fi
        fi

        txtm 0 40 "Comprobación de estado del sistema actual y paquetes necesarios en el backup." \
                  "Checking the status of the current system and necessary packages in the backup."
        if validacion_tiene mal_estado_OMV; then
            txtm 8 42 ">>> ⚫ LA INSTALACION ACTUAL DE OPENMEDIAVAULT ESTÁ EN MAL ESTADO ⚫" \
                      ">>> ⚫ THE CURRENT OPENMEDIAVAULT INSTALLATION IS IN BAD CONDITION ⚫"
        fi
        if validacion_tiene sistema_configurado; then
            txtm 8 43 ">>> ⚫ EL SISTEMA ACTUAL YA ESTÁ CONFIGURADO  ⚫" \
                      ">>> ⚫ THE CURRENT SYSTEM IS ALREADY CONFIGURED ⚫"
        fi
        if validacion_tiene version_superior_OMV; then
            txtm 8 44 ">>> ⚫ LA VERSION DE OMV INSTALADA ES SUPERIOR A LA DEL SISTEMA ORIGINAL ⚫" \
                      ">>> ⚫ THE INSTALLED OMV VERSION IS HIGHER THAN THAT OF THE ORIGINAL SYSTEM ⚫"
        fi
        if [ -n "$PaquetesFaltantesBackup" ]; then
            txtm 8 45 ">>> ⬛ ADVERTENCIA ⬛ FALTAN PAQUETES NECESARIOS EN EL BACKUP: $PaquetesFaltantesBackup" \
                      ">>> ⬛ WARNING ⬛ REQUIRED PACKAGES ARE MISSING IN THE BACKUP: $PaquetesFaltantesBackup"
            ((advertencias++))
        fi
        if validacion_tiene CPU_incompatible_KVM; then
            txtm 8 46 ">>> ⬛ ADVERTENCIA ⬛ LA CPU DE ESTE SISTEMA ES INCOMPATIBLE CON KVM" \
                      ">>> ⬛ WARNING ⬛ THE CPU OF THIS SYSTEM IS INCOMPATIBLE WITH KVM"
            ((advertencias++))
        fi
        if validacion_tiene ARM_incompatible_ZFS; then
            txtm 8 47 ">>> ⚫ ZFS DETECTADO EN EL BACKUP Y SISTEMA ARM, NO SOPORTADO ⚫" \
                      ">>> ⚫ ZFS DETECTED IN BACKUP AND ARM SYSTEM, NOT SUPPORTED ⚫"
        fi
        if validacion_tiene sistema_32bits; then
            txtm 8 48 ">>> ⚫ EL SISTEMA ACTUAL ES DE 32 BITS, INSTALA UN SISTEMA DE 64 BITS ⚫" \
                      ">>> ⚫ THE CURRENT SYSTEM IS 32 BIT, INSTALL A 64 BIT SYSTEM ⚫"
        fi
        if validacion_tiene usuarios_locales; then
            txtm 8 49 ">>> ⚫ EL SISTEMA ACTUAL TIENE MAS DE UN USUARIO LOCAL CONFIGURADO ⚫" \
                      ">>> ⚫ THE CURRENT SYSTEM HAS MORE THAN ONE LOCAL USER CONFIGURED ⚫"
        fi
        if [ $advertencias -gt 0 ]; then
            txtc 4 "(Hay Advertencias: $advertencias en total)" \
                   "(There are Warnings: $advertencias in total)"
        fi

        txtm 0 91 "Complementos omitidos en la regeneración que no se instalarán." \
                  "Plugins skipped on regeneration that will not be installed."
        if [[ -n "${CFG[ComplementosExc]}" ]]; then
            local excluidos
            excluidos=$(for p in ${CFG[ComplementosExc]}; do echo -n "${p#openmediavault-} "; done )
            txtm 8 92 ">>> Complementos omitidos: $excluidos" \
                      ">>> Skipped plugins: $excluidos"
        else
            txtm 8 92 ">>> Ninguno." \
                      ">>> None."
        fi

        txt 1 "${txt[2]}${txt[lin]}\n\
${txt[10]}${txt[11]}${txt[12]}${txt[13]}${txt[14]}${txt[15]}${txt[16]}${txt[17]}${txt[18]}${txt[19]}${txt[20]}${txt[lin2]}\
${txt[25]}${txt[26]}${txt[27]}${txt[28]}${txt[lin2]}\
${txt[30]}${txt[31]}${txt[32]}${txt[33]}${txt[lin2]}\
${txt[91]}${txt[92]}${txt[lin2]}\
\n${txt[41]}${txt[42]}${txt[43]}${txt[44]}${txt[45]}${txt[46]}${txt[47]}${txt[48]}${txt[49]}\
${txt[lin]}\n${txt[3]}${txt[4]} "

        txt 83 "Desactivado ------------------------------> " \
               "Disabled ---------------------------------> "
        txt 84 "Activado ---------------------------------> " \
               "Enabled ----------------------------------> "
        case "${CFG[RegenRed]}" in
            No)     txt 71 "${txt[83]}"; txt 72 "Activar Regeneración de Red     " \
                                                "Enable Network Regeneration     " ;;
            Si|Yes) txt 71 "${txt[84]}"; txt 72 "Desactivar Regeneración de Red  " \
                                                "Disable Network Regeneration    " ;;
        esac
        case "${CFG[RegenKernel]}" in
            No)     txt 81 "${txt[83]}"; txt 82 "Activar Instalación de Kernel   " \
                                                "Enable Kernel Installation      " ;;
            Si|Yes) txt 81 "${txt[84]}"; txt 82 "Desactivar Instalación de Kernel" \
                                                "Disable Kernel Installation     " ;;
        esac

        txt 50 "                                     EJECUTAR LA REGENERACION AHORA                                    " \
               "                                        RUN THE REGENERATION NOW                                       "
        txt 60 "  CARPETA DE BACKUP     ---------------------------------------------> Cambiar carpeta de origen       " \
               "  BACKUP FOLDER         ---------------------------------------------> Change destination folder       "

        regen_en_progreso && { \
        txt 50 "                                  CONTINUAR LA REGENERACION EN PROGRESO                                " \
               "                                  CONTINUE THE REGENERATION IN PROGRESS                                "
        txt 60 "  LIMPIAR REGENERACION  ---------------------------------------------> Limpiar regeneración en progreso" \
               "  CLEAN REGENERATION    ---------------------------------------------> Clean regeneration in progress  "; }

        txt 70 "  REGENERAR RED         -- ${txt[71]}${txt[72]}" \
               "  REGENERATE NETWORK    -- ${txt[71]}${txt[72]}"
        txt 80 "  INSTALAR KERNEL       -- ${txt[81]}${txt[82]}" \
               "  INSTALL KERNEL        -- ${txt[81]}${txt[82]}"
        txt 90 "  OMITIR COMPLEMENTOS   ---------------------------------------------> Omitir instalación complementos " \
               "  SKIP PLUGINS          ---------------------------------------------> Skip installing plugins         "
        clear
        respuesta=$(dialog --backtitle "omv-regen $ORVersion" --title "omv-regen regenera $ORVersion" \
            --ok-label "${txt[B_Continuar]}" \
            --cancel-label "${txt[B_Menu_Principal]}" \
            --help-button \
            --help-label "${txt[B_Ayuda]}" \
            --no-tags \
            --stdout \
            --menu "${txt[1]}" "$alto" "$ancho" 3  1 "${txt[50]}" 2 "${txt[60]}" 3 "${txt[70]}" 4 "${txt[80]}" 5 "${txt[90]}")
        salida_menu=$?
        case $salida_menu in
            2)  Ayuda AyudaMenuRegenera ;;
            1|255)  
                if [[ -n "${CFG[ComplementosExc]}" ]]; then
                    Info 3 ">>> Los complementos marcados para omitir se descartan. Limpiando exclusiones ..." \
                           ">>> Plugins marked to be skipped are discarded. Cleaning exclusions ..."
                    CFG[ComplementosExc]=""
                    SalvarAjustes || return 1
                fi
                VIA=0
                ;;
            0)
                case $respuesta in
                    1)  VIA=10 ;;
                    2)  if regen_en_progreso; then
                            Pregunta "⬛ ADVERTENCIA ⬛ \n \
                                    \n>>> Esta acción eliminará el entorno de la regeneración en progreso. \
                                    \n>>> Se desbloquearán las versiones de paquetes de OMV. \
                                    \n>>> Se limpiarán las carpetas temporales y repositorio. \
                                    \n>>> Se desbloqueará el acceso a la GUI de OMV. \
                                    \n>>> Se eliminará el progreso de regeneración en omv-regen. \
                                    \n\n>>> Utiliza esta opción solo si omv-regen no puede continuar y quieres intentar una recuperación manual. \
                                    \n\n>>> ¿Quieres continuar?" \
                                    "⬛ WARNING ⬛ \n \
                                    \n>>> This action will delete the environment from the regeneration in progress. \
                                    \n>>> The OMV package versions will be unlocked. \
                                    \n>>> The temporary and repository folders will be cleaned up. \
                                    \n>>> Access to the OMV GUI will be unlocked. \
                                    \n>>> Regeneration progress in omv-regen will be removed. \
                                    \n\n>>> Use this option only if omv-regen cannot continue and you want to attempt a manual recovery. \
                                    \n\n>>> Do you want to continue?" && LimpiarRegeneracion
                        else
                            MenuRutaBackups
                        fi
                        ;;
                    3)  AlternarOpcion RegenRed "${txt[72]}" ;;
                    4)  AlternarOpcion RegenKernel "${txt[82]}" ;;
                    5)  OmitirComplementos ;;
                esac
                ;;
        esac
    done
}

# Determina si un complemento es esencial (no se puede omitir)
# Determine whether a plugin is essential (cannot be omitted)
es_esencial() {
    local complemento=$1

    for c in "${NO_OMITIR[@]}"; do
        [ "$complemento" = "$c" ] && return 0
    done
    return 1
}

# Selecciona complementos a omitir durante la regeneración
# Select plugins to skip during regeneration
OmitirComplementos() {
    local COMPLEMENTOS_EXCLUSIONES=()

    for complemento in "${!VERSION_ORIGINAL[@]}"; do
        ! es_esencial "${complemento}" && COMPLEMENTOS_EXCLUSIONES+=("$complemento" "$complemento" "off")
    done

    txt 1 "Selecciona complementos a omitir" \
          "Select plugins to skip"
    txt 2 "Selecciona los complementos que deseas OMITIR durante la regeneración:" \
          "Select the add-ons you want to SKIP during regeneration:"
    local resultado
    resultado=$(dialog --backtitle "omv-regen $ORVersion" \
                      --title "${txt[1]}" \
                      --checklist "${txt[2]}" \
                      20 70 15 \
                      "${COMPLEMENTOS_EXCLUSIONES[@]}" \
                      2>&1 >/dev/tty)
    salvar_cfg ComplementosExc "$resultado" || return 1
    return 0
}

Ayuda() {
    local salida_menu=0 i=0 n_paginas=${#AYUDA[@]}
    local clave="$1"

    if [ -n "$clave" ]; then
        for j in "${!AYUDA[@]}"; do
            if [ "${AYUDA[j]}" = "${txt[$clave]}" ]; then
                i=$j
                break
            fi
        done
    fi

    while true; do
        dialog --backtitle "omv-regen $ORVersion" --title "omv-regen $ORVersion ${txt[Ayuda]}" \
               --colors \
               --extra-button \
               --yes-label "${txt[B_Siguiente]}" \
               --no-label "${txt[B_Salir]}" \
               --extra-label "${txt[B_Anterior]}" \
               --yesno "${AYUDA[i]}\n " 0 0
        salida_menu=$?
        case $salida_menu in
            0)      ((i++)) ;;
            3)      ((i--)) ;;
            1|255)  break ;;
        esac
        ((i = (i + n_paginas) % n_paginas))
    done
}

###################################### FUNCIONES AUXILIARES ########################################
###################################### AUXILIARY FUNCTIONS #########################################

# Enviar notificación por correo. Las notificaciones tienen que estar configuradas y habilitadas en la GUI de OMV
# $1 = Cabecera   $2 = Cuerpo del mensaje
# Send email notifications. Notifications must be configured and enabled in the OMV GUI.
# $1 = Subject   $2 = Message body
EnviarCorreo() {
    local asunto="omv-regen: $1"

    txt cuerpo "\nomv-regen\n\n$2"

    LeerValorBD "/config/system/email/enable"
    case "$ValorBD" in
        1)      echo -e "${txt[cuerpo]}" | mail -E -s "$asunto" root 2>/dev/null \
                    || alerta "Fallo al enviar el correo. Comprueba la configuración de email en OMV." \
                              "Failed to send email. Check OMV email settings." ;;
        0|"")   echoe ">>> Envío de correo deshabilitado o OMV no instalado. Omitiendo notificación. ValorBD: $ValorBD" \
                      ">>> Email disabled or OMV not installed. Skipping notification. ValorBD: $ValorBD" ;;
        *)      error log "Estado inesperado de la configuración de la base de datos de OMV." \
                          "Unexpected state of OMV database configuration." ;;
    esac
}

# return 0 -> Regeneration in progress
# return 1 -> No regeneration in progress
regen_en_progreso() { [[ -f /etc/apt/preferences.d/omv-regen ]]; }

# Detecta si es una Raspbeery Pi
# Detect if it is a Raspberry Pi
es_raspberry() { grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null || return 1; }

# Convierte valores a Si o No. Si es inválido se deja vacío
# Convert values ​​to Yes or No. If it is invalid, it is left empty
FormatearSiNo() {
    local clave
    for clave in ActualizarOMV ModoSilencio OmitirRoot ActualizarOmvregen RegenKernel RegenRed; do
        if [[ "${CFG[$clave]}" =~ ^(s|S|si|Si|SI|y|Y|yes|Yes|YES|on)$ ]]; then
            CFG[$clave]="Si"
        elif [[ "${CFG[$clave]}" =~ ^(n|N|no|No|NO|off)$ ]]; then
            CFG[$clave]="No"
        else 
            CFG[$clave]=""
        fi
    done
}

# Devuelve Si o No traducido al idioma actual
# Returns Yes or No translated to the current language
TraducirSiNo() { [ "$1" = "Si" ] && echo "${txt[Si]}" || echo "No"; }

# Alterna entre "Si" y "No" el valor de una clave en CFG
# Toggle between "Yes" and "No" the value of a key in CFG
AlternarOpcion() {
    local clave="$1" texto_es="$2" texto_in="$3"
    [[ -z "${CFG[$clave]}" ]] && Mensaje error "Clave inválida o no definida: $clave AlternarOpcion()" \
                                               "Invalid or undefined key: $clave AlternarOpcion()" && return 1
    [[ -z "$texto_es" ]] && Mensaje error "Texto vacío AlternarOpcion()" \
                                          "Empty text AlternarOpcion()" && return 1
    
    if [[ "$clave" == "ActualizarOmvregen" ]]; then
        texto_es="\n          $texto_es\n \
                \n______________________________________________________________________________________ \
                \n >>> Si se ejecuta omv-regen se buscan actualizaciones una vez al día.\
                \n >>> Si esta opción está activada se actualizará omv-regen automáticamente, si no solo se informará.\
                \n >>> La opción Activar forzará una nueva búsqueda ahora.\n"
        texto_in="\n         $texto_in\n \
                \n______________________________________________________________________________________ \
                \n >>> Running omv-regen will check for updates once a day.\
                \n >>> If this option is enabled, omv-regen will be updated automatically, otherwise it will just inform you.\
                \n >>> The Enable option will force a new search now.\n"
    fi

    if Pregunta "$texto_es \n\n>>> ¿Quieres continuar?  " \
                "$texto_in \n\n>>> Do you want to continue?  "; then
        if [ "$clave" = "Idiomas" ]; then
            CFG[Idiomas]="$([[ "${CFG[Idiomas]}" = "es" ]] && echo "en" || echo "es")"
            AjustarIdioma; SalvarAjustes || return 1
        else
            salvar_cfg "$clave" "$([[ "${CFG[$clave]}" = "No" ]] && echo "Si" || echo "No")" || return 1
        fi
        Info 2 guardado
        [[ "$clave" == "ActualizarOmvregen" && "${CFG[ActualizarOmvregen]}" = "Si" ]] && CFG[UltimaBusqueda]="10" && BuscarOR
    fi
}

# Comprobar condiciones de ejecucion desatendida
# Check unattended execution conditions
backup_desatendido() { [[ $BackupProgramado == 0 ]]; }
limpieza_programada() { [[ $LimpiezaProgramada == 0 ]]; }
regen_auto() { [[ $ModoAuto == 0 ]]; }
modo_desatendido() { 
    if backup_desatendido || limpieza_programada || regen_auto; then
        return 0
    fi
    return 1
}

# Traducir expresiones
# Translate expressions
txt() {
    [[ -n "$3" && "${CFG[Idiomas]}" = "en" ]] && txt[$1]="$3" && return 0
    txt[$1]="$2"
}

# Traducir expresiones y centrar texto en dialog
# Translate expressions and center text in dialog
txtc() {
    txt "$1" "$2" "$3"
    txt[$1]="$(centrar "${txt[$1]}")"
}

# Traducir expresiones y aplicar margen al texto en dialog
# Translate expressions and apply margin to text in dialog
txtm() {
    txt "$2" "$3" "$4"
    txt[$2]="$(margen "$1" "${txt[$2]}")"
}

# Vaciar valores de txt del 1 al 100
# Empty txt values from 1 to 100
LimpiarTxt() { for i in {1..100}; do txt[$i]=""; done; }

# echoe [sil|info $1|nolog|error] "Mensaje en español" "Message in English"
# Devuelve el mensaje en el idioma configurado. Envía la salida estándar y de error a diferentes destinos → Ver _orl()
# Returns the message in the configured language. Sends standard output and error output to different destinations → See _orl()
echoe() {
    local tipo="$1" mensaje

    obtener_mensaje() {
        local es="$1" en="$2" idioma="${CFG[Idiomas]:-en}"
        if [[ "$idioma" = "en" && -n "$en" ]]; then
            echo "$en"
        else
            echo "$es"
        fi
    }

    case "$tipo" in
        sil)    mensaje=$(obtener_mensaje "$2" "$3")
                echo -e "$mensaje" | _orl sil
                ;;
        nolog)  mensaje=$(obtener_mensaje "$2" "$3")
                echo -e "$mensaje"
                ;;
        error)  mensaje=$(obtener_mensaje "$2" "$3")
                txt error "$mensaje"
                echo -e "$mensaje" | _orl error
                ;;
        log)    mensaje=$(obtener_mensaje "$2" "$3")
                txt error "$mensaje"
                echo -e "$mensaje" | _orl log
                ;;
        *)      mensaje=$(obtener_mensaje "$1" "$2")
                echo -e "$mensaje" | _orl
                ;;
    esac
}

# Muestra el error con echoe. Si es modo desatendido envía correo.
# Display the error using echoe. If it's unattended mode, send an email.
error() {
    [ "$1" = "log" ] && echoe log ">>> ERROR: $2" ">>> ERROR: $3" && return 0

    echoe error ">>> ERROR: $1" ">>> ERROR: $2"
    
    modo_desatendido || return 0

    txt cuerpo ">>> ERROR: $1" ">>> ERROR: $2"
    backup_desatendido && txt cabecera "BACKUP ERROR"
    limpieza_programada && txt cabecera "ERROR LIMPIEZA SEMANAL HOOK" "WEEKLY CLEANING HOOK ERROR"
    regen_auto && txt cabecera "ERROR REGENERACION" "REGENERATING ERROR"
    EnviarCorreo "${txt[cabecera]}" "${txt[cuerpo]}"
}

alerta() { echoe error "ATENCIÓN: $1" "WARNING: $2"; }

# Desvía la salida estándar y de error en dos direcciones, sin buffering (asegura el orden correcto de los mensajes)
#   - Salida 1: Al registro    - Se añade marca de hora. Además, la marca '[ERROR]' si el mensaje procede de la salida de error
#                              - Si $1=error, siempre se añade la marca '[ERROR]'
#   - Salida 2:  - Si modo_desatendido=0, CFG[ModoSilencio]=Si y $1=sil, se genera salida completa al registro pero en consola se muestra solo mensajes mínimos. 
# Forwards standard and error output in two directions, without buffering (ensures correct order of messages)
#   - Output 1: To log         - Timestamp is added. Also, the '[ERROR]' flag is added if the message comes from error output
#                              - If $1=error, the '[ERROR]' flag is always added
#   - Output 2:  - If modo_desatendido=0, CFG[ModoSilencio]=Si, and $1=sil, complete output is generated to the log but only minimal messages are shown in the console.
_orl() {
    local nombre_funcion
    nombre_funcion="'${FUNCNAME[1]}()'"
    [ -n "${FUNCNAME[2]}" ] && nombre_funcion="'${FUNCNAME[1]}()'-'${FUNCNAME[2]}()'"
    [ -n "${FUNCNAME[3]}" ] && nombre_funcion="'${FUNCNAME[1]}()'-'${FUNCNAME[2]}()'-'${FUNCNAME[3]}()'"
    # Verificamos si el mensaje debe ser silencioso (solo log)
    # We check if the message should be silent (log only)
    if modo_desatendido && [ "$1" = "sil" ] && [ "${CFG[ModoSilencio]}" = "Si" ]; then
        # Si es silencio, solo lo redirigimos al log con marca de tiempo
        # If it's silent, we just redirect it to the timestamp log.
        sed "s/^/[$(date +'%Y-%m-%d %H:%M:%S')][OR] >>> /" >> "$OR_log_file" \
        2>&1 | sed "s/^/[$(date +'%Y-%m-%d %H:%M:%S')][OR][ERROR][$nombre_funcion] >>> /" >> "$OR_log_file"
    elif [ "$1" = "error" ]; then
        # Si es un error, mostramos el mensaje en consola y lo redirigimos al log con la etiqueta [ERROR]
        # If it is an error, we display the message in the console and redirect it to the log with the label [ERROR]
        sed "s/^/[$(date +'%Y-%m-%d %H:%M:%S')][OR][ERROR][$nombre_funcion] >>> /" |& tee -a "$OR_log_file"
    elif [ "$1" = "log" ]; then
        # Si es 'log', solo redirigimos al log sin mostrar nada en consola
        # If it is 'log', we just redirect to the log without showing anything in the console
        sed "s/^/[$(date +'%Y-%m-%d %H:%M:%S')][OR] >>> /" >> "$OR_log_file" \
        2>&1 | sed "s/^/[$(date +'%Y-%m-%d %H:%M:%S')][OR][ERROR][$nombre_funcion] >>> /" >> "$OR_log_file"
    else
        # En los otros casos, mostramos el mensaje en consola y lo redirigimos al log
        # In the other cases, we display the message in the console and redirect it to the log.
        tee >(sed "s/^/[$(date +'%Y-%m-%d %H:%M:%S')][OR] >>> /" >> "$OR_log_file") \
        2> >(tee >(sed "s/^/[$(date +'%Y-%m-%d %H:%M:%S')][OR][ERROR][$nombre_funcion] >>> /" >> "$OR_log_file"))
    fi
    # Propagación del código de salida
    # Exit code propagation
    return "${PIPESTATUS[0]}"
}

# echoe [+ error] + exit
Salir() {
    if [ "$1" = "error" ]; then
        error "$2" "$3"
    else
        echoe "$@"
    fi
    echoe sil ">>> Saliendo de omv-regen ..." \
              ">>> Exiting omv-regen ..."
    exit
}

# Limpieza de archivos temporales
# Cleanup of temporary files
TrapSalir() {   
    [ -d "$OR_tmp_dir" ] && rm -rf "$OR_tmp_dir"
    [ -f "$Conf_tmp_file" ] && rm -f "$Conf_tmp_file"
    [ -f "$OR_lock_file" ] && rm -f "$OR_lock_file"
}

# Muestra el desarrollo de un proceso en consola. Si no es modo desatendido al finalizar muestra el resultado en una ventana explorable.
# Displays the progress of a process in the console. If it is not in unattended mode, it displays the result in a searchable window upon completion.
Mostrar() {
    local proceso=$1 pid_proceso temp_file rc
    temp_file="$(mktemp)"

    modo_desatendido || clear
    $proceso |& tee -a "$temp_file" &
    pid_proceso=$!
    wait "$pid_proceso"
    rc=$?
    if ! modo_desatendido; then
        sleep 2
        dialog --title "omv-regen $ORVersion" --no-shadow --textbox "$temp_file" "$(tput lines)" "$(tput cols)"
    fi
    rm -f "$temp_file"
    return $rc
}

# Mensaje con tiempo de espera y posibilidad de abortar. Devuelve 0 si es afirmativo o modo desatendido
# $1=segundos de espera. $2 y $3 texto.
# Message with waiting time and possibility to abort. Returns 0 if yes or unattended mode
# $1=waiting seconds. $2 and $3 text.
Continuar() {
    local res=0
    txt mensaje "$2" "$3"
    echoe sil "${txt[mensaje]}"
    modo_desatendido && return 0
    dialog --backtitle "omv-regen ${ORVersion}" --title "omv-regen ${ORVersion}" \
           --ok-label "${txt[B_Continuar]}" \
           --cancel-label "${txt[B_Abortar]}" \
           --colors \
           --pause "\n  \n${txt[mensaje]}  \n\n\n\n" 0 0 "$1"
    res=$?
    [ ! "${res}" -eq 0 ] && Info 2 cancelado
    return $res
}

# Información con $1=segundos de espera para leer. En modo desatendido solo echoe().
# Information with waiting $1=seconds to read. In unattended mode, only echoe().
Info() {
    txt mensaje "$2" "$3"
    [ "$2" = "cancelado" ] && txt mensaje ">>> Operación cancelada." ">>> Operation cancelled."
    [ "$2" = "guardado"  ] && txt mensaje ">>> La configuración se ha guardado." ">>> The configuration has been saved."
    modo_desatendido && echoe "${txt[mensaje]}" && return 0
    dialog --backtitle "omv-regen ${ORVersion}" --title "omv-regen ${ORVersion}" --no-collapse --colors --infobox "\n${txt[mensaje]}\n " 0 0
    sleep "$1"
}

# Información en espera hasta pulsar. En modo desatendido solo echoe().
# Information waiting until pressed. In unattended mode, only echoe().
Mensaje() {
    case "$1" in
        error)  error  "$2" "$3"
                txt mensaje ">>> ERROR: $2" ">>> ERROR: $3"
                ;;
        alerta) alerta "$2" "$3"
                txt mensaje ">>> ATENCION: $2" ">>> WARNING: $3"
                ;;
        *)      echoe "$@"
                txt mensaje "$1" "$2"
                [ -n "$3" ] && txt mensaje "$2" "$3"
                ;;
    esac
    modo_desatendido && return 0
    dialog --backtitle "omv-regen $ORVersion" --title "omv-regen $ORVersion" --no-collapse --colors --msgbox "\n${txt[mensaje]}\n " 0 0
}

# Pregunta al usuario y devuelve 0 si es afirmativo o 1 si es negativo. En modo desatendido siempre devuelve 0.
# Ask the user and return 0 if yes or 1 if no. In unattended mode it always returns 0.
Pregunta() {
    modo_desatendido && return 0
    txt mensaje "$1" "$2"
    dialog --backtitle "omv-regen $ORVersion" --title "omv-regen $ORVersion" --no-collapse --yes-label "${txt[B_Si]}" --no-label "${txt[B_No]}" --colors --yesno "\n${txt[mensaje]}\n " 0 0
    return $?
}

# Obtener alto y ancho de la ventana, desplazamiento (espacios a la izquierda) y definir línea de ancho completo
#   $1 y $2: Porcentajes de alto y ancho a ocupar en la pantalla    $3 y $4: Alto y ancho mínimo de la ventana
# Retorna alto y ancho de la ventana, el desplazamiento de texto, dimensiones de pantalla actual y una línea completa
# Get window height and width, scroll (left spaces) and set full width line
#   $1 and $2: Percentages of height and width to occupy on the screen    $3 and $4: Minimum height and width of the window
# Returns window height and width, text scrolling, current screen dimensions and a full line
definir_ventana() {
    local porcPantAlto=$1 porcPantAncho=$2 altoMinimo=$3 anchoMinimo=$4
    local altoPantalla anchoPantalla anchoLinea linea ventana
    altoPantalla=$(tput lines)
    anchoPantalla=$(tput cols)
    if [[ $(( altoPantalla * porcPantAlto / 100 )) -lt $altoMinimo ]]; then
        ventana=$altoMinimo
    else
        ventana=$(( altoPantalla * porcPantAlto / 100 ))
    fi
    local anchoMaximo=$(( anchoPantalla * porcPantAncho / 100 ))
    if [[ $anchoMaximo -lt $anchoMinimo ]]; then
        ventana="$ventana $anchoMinimo 0"
        anchoLinea=$(( anchoMinimo - 4 ))
    else
        ventana="$ventana $anchoMaximo $(( (anchoMaximo - anchoMinimo) / 2 ))"
        anchoLinea=$(( anchoMaximo - 4 ))
    fi
    linea="$(printf "%*s" $anchoLinea "" | tr ' ' '_')\n"
    echo "$ventana $altoPantalla $anchoPantalla $linea"
}

# Aplicar el margen a un texto. 'desplaz' y 'margen' deben estar en el ámbito de margen()
# Apply the margin to a text. 'desplaz' and 'margen' must be in scope of margen()
margen() {
    local margenAd=$1 texto="$2" texto_desplazado=""
    local margenTot=$(( desplaz + margen + margenAd ))
    while IFS= read -r linea; do
        texto_desplazado="${texto_desplazado}$(printf "%${margenTot}s%s" "" "$linea")\n"
    done <<< "$(echo -e "$texto")"
    echo "$texto_desplazado"
}

# Centrar el texto en una ventana. 'ancho' debe estar en el ámbito de centrar()
# Center text in a window. 'ancho' must be in scope of centrar()
centrar() {
    local texto="$1" espacios texto_centrado=""
    while IFS= read -r linea; do
        if [ ${#linea} -lt $(( ancho - 4 )) ]; then
            espacios=$(( ( ( ancho -4 ) - ${#linea} ) / 2 ))
            texto_centrado="${texto_centrado}$(printf "%${espacios}s%s" "" "$linea")\n"
        else
            texto_centrado="${texto_centrado}${linea}\n"
        fi
    done <<< "$(echo -e "$texto")"
    echo "$texto_centrado"
}

# Devuelve 0 si todos los paquetes de OMV están en buen estado (ii o hi) o rc si no son esenciales. Si no devuelve 1.
# Returns 0 if all MVNO packages are in good condition (ii or hi) or rc if they are not essential. If it does not return 1.
estado_correcto_omv() {
    local paquete estado
    while read -r estado paquete; do
        case $estado in
            ii|hi) ;;
            rc)
                es_esencial "$paquete" && {
                    error "El paquete esencial $paquete no está instalado pero hay archivos de configuración, estado: $estado" \
                          "The essential $paquete package is not installed but there are configuration files, state: $estado"
                    return 1; }
                ;;
            *)  
                error "El paquete $paquete está en mal estado: $estado" \
                      "Package $paquete is in bad condition: $estado"
                return 1 ;;
        esac
    done < <(dpkg -l | awk '/openmediavault/ {print $1, $2}')
}

# Genera archivo que marca un reinicio pendiente '/var/run/reboot-required'
# Generates a file that marks a pending reboot '/var/run/reboot-required'
GenerarReinicio() {
    echoe "\n>>> Generando el archivo '/var/run/reboot-required' para marcar un reinicio pendiente ..." \
          "\n>>> Generating '/var/run/reboot-required' file to mark a pending reboot ..."
    if [ ! -f "/var/run/reboot-required" ]; then
        txt 1 "Reinicio requerido por omv-regen" \
              "Reboot required by omv-regen"
        echo "${txt[1]}" > /var/run/reboot-required
    else
        echoe ">>> Ya existía un archivo de reinicio pendiente '/var/run/reboot-required'. Contenido actual:" \
              ">>> A pending reboot file '/var/run/reboot-required' already existed. Current content:"
        sed 's/^/>>>     /' /var/run/reboot-required | _orl
    fi
}

# Si hay un reinicio pendiente aplica cambios pendientes de Saltstack y reinicia.
# If there is a pending reboot, apply pending Saltstack changes and reboot.
EjecutarReinicioPendiente() {
    if [ -f "/var/run/reboot-required" ]; then
        LimpiarSalt || { error "No se pueden aplicar los cambios pendientes en la configuración de OMV. El sistema no se puede actualizar." \
                               "Pending changes to the OMV configuration cannot be applied. The system cannot be updated."; return 1; }
        echoe ">>> Hay un reinicio pendiente, omv-regen va a reiniciar el sistema dentro de 10 segundos. [Ctrl+C] para cancelar." \
              ">>> There is a reboot pending, omv-regen will reboot the system within 10 seconds. [Ctrl+C] to cancel."
        txt 1 ">>> OMV-REGEN REINICIARÁ EL SISTEMA DENTRO DE" \
              ">>> OMV-REGEN WILL RESTART THE SYSTEM WITHIN"
        txt 2 "SEGUNDOS" "SECONDS"
        for ((i = 10; i >= 1; i--)); do echo -ne "\r${txt[1]} $i ${txt[2]} "; sleep 1; done
        echoe "\n>>> Reiniciando ..." "\n>>> Rebooting ..."
        sync; sleep 0,5; reboot
        sleep 3; exit
    fi
}

# Actualizar openmediavault
# Update openmediavault
ActualizarOMV() {
    EsperarAptDpkg
    LimpiarSalt | _orl sil || { error "No se pueden aplicar los cambios pendientes en la configuración de OMV. El sistema no se puede actualizar." \
                                      "Pending changes to the OMV configuration cannot be applied. The system cannot be updated."; return 1; }
    omv-upgrade | _orl sil || { error "No se ha podido actualizar el sistema." \
                                      "The system could not be updated."; return 1; }
    LimpiarSalt | _orl sil || { error "Después de la actualización, no se pudieron aplicar los cambios pendientes en la configuración de OMV." \
                                      "After the upgrade, pending changes to the OMV configuration could not be applied."; return 1; }
    if [ -f "/var/run/reboot-required" ]; then
        echoe sil ">>> Tras la actualización de OMV hay un reinicio pendiente." \
                  ">>> After the OMV update there is a pending reboot."
    fi
    return 0
}

############################## FUNCIONES GENERALES DE CONFIGURACION DE OMV-REGEN ###############################
################################## GENERAL OMV-REGEN CONFIGURATION FUNCTIONS ###################################

# Impedir multiples instancias de omv-regen
# Prevent multiple instances of omv-regen
ArchivoBloqueo() {
    exec 9>"$OR_lock_file"  # Abre un descriptor de archivo para el bloqueo - Open a file descriptor for the lock
    if ! flock -n 9; then   # Intenta adquirir el bloqueo sin bloquear el proceso - Try to acquire the lock without blocking the process
        # omv-regen ya está en ejecución - omv-regen is already running
        return 1
    fi
    # Dejar el descriptor de archivo abierto para mantener el bloqueo - Leave file descriptor open to maintain lock
    echo "$$" > "$OR_lock_file"
}

ResetearOmvregen() {
    if Pregunta ">>> Se van a restablecer los ajustes de omv-regen a los valores predeterminados. \
                \n>>> Se va eliminar el repositorio de omv-regen. \
                \n>>> Se perderá el progreso de la regeneración si ya se ha iniciado. \
                \n¿Quieres continuar?" \
                ">>> The omv-regen settings will be reset to default values. \
                \n>>> The omv-regen repository is being removed. \
                \n>>> Regeneration progress will be lost if it has already started. \
                \nDo you want to continue?"; then
        OmvregenReset
        Info 4 ">>> Se ha reseteado omv-regen." \
               ">>> omv-regen has been reset."
        exec bash "$OR_script_file"
    fi
}

DesinstalarOmvregen() {
    if Pregunta ">>> Se va a desinstalar omv-regen.\n¿Quieres continuar?" \
                ">>> omv-regen will be uninstalled.\nDo you want to continue?"; then
        OmvregenReset
        [ -d "$OR_dir" ] && rm -rf "$OR_dir"
        [ -f "$OR_script_file" ] && rm -f "$OR_script_file"
        echoe ">>> Se ha desinstalado omv-regen. Saliendo ..." \
              ">>> omv-regen has been uninstalled. Exiting ..."
        exit 0
    fi
}

# Elimina los archivos de configuración de omv-regen y la tarea programada. Libera paquetes retenidos.
# Remove the omv-regen configuration files and the scheduled task. Release held packages.
OmvregenReset() {
    regen_en_progreso && LimpiarRegeneracion
    [ -f "$OR_ajustes_file" ] && rm -f "$OR_ajustes_file"
    [ -d "$OR_hook_dir" ] && rm -rf "$OR_hook_dir"
    [ -d "$OR_repo_dir" ] && rm -rf "$OR_repo_dir"
    [ -f "$OR_hook_file" ] && rm -f "$OR_hook_file"
    [ -f "$OR_logRotate_file" ] && rm -f "$OR_logRotate_file"
    [ -f "$OR_cron_file" ] && rm -f "$OR_cron_file"
    ProgramarBackup eliminar
}

# Leer los ajustes de omv-regen desde el archivo de ajustes persistente
# Read omv-regen settings from persistent settings file
LeerAjustes() {
    local clave cont=0 linea claves_ora version_ajustes
    local archivo_ajustes="$OR_ajustes_file"
    local version_compatible_min="7.1.0"
    
    unset CARPETAS_ADICIONALES
    version_ajustes=$(awk -F "omv-regen version " 'NR==1{print $2}' "$OR_ajustes_file")
    if sort -V <<<"$version_ajustes"$'\n'"$version_compatible_min" | head -n1 | grep -qx "$version_compatible_min"; then
        claves_ora=$(echo "${!CFG[@]}" | tr ' ' '|')
        while IFS= read -r linea; do
            if [[ "$linea" =~ ^($claves_ora)\ :\ (.*) ]]; then
                clave="${BASH_REMATCH[1]}"
                CFG[$clave]="${BASH_REMATCH[2]}"
            elif [[ "$linea" =~ ^(Carpeta|Folder)\ :\ (.*) ]]; then
                CARPETAS_ADICIONALES[cont]="${BASH_REMATCH[2]}" && ((cont++))
            fi
        done < "$archivo_ajustes"
    else
        Salir error "La versión del archivo de ajustes no coincide." \
                    "The settings file version does not match."
        # PARA MIGRACIONES POSTERIORES
    fi
}

# Migrar ajustes desde versiones 7.0.x o anterior
# Migrate settings from versions 7.0.x or earlier
MigrarAjustes_7_0() {
    local ajuste
    local ajustes_antiguo="/etc/regen/omv-regen.settings"

    IniciarAjustes; AjustarIdioma

    Info 3 ">>> Migrando ajustes anteriores hasta $ORVersion ... \
           \n>>> Los ajustes antiguos se guardarán en el log para referencia: $OR_log_file "\
           ">>> Migrating previous settings to $ORVersion ... \
           \n>>> The old settings will be saved in the log for reference: $OR_log_file "
    txt 1 "INICIO DE AJUSTES ANTIGUOS" "START OLD SETTINGS"
    txt 2 "FIN DE AJUSTES ANTIGUOS" "END OF OLD SETTINGS"
    { echo ">>> ${txt[1]} <<<"
    cat "$ajustes_antiguo"
    echo ">>> ${txt[2]} <<<"; } >> "$OR_log_file"

    ajuste="$(grep "^Actualizar : " "$ajustes_antiguo")" || error "No se encontró 'Actualizar' en los ajustes antiguos: $ajustes_antiguo " \
                                                                  "'Actualizar' not found in old settings: $ajustes_antiguo"
    CFG[ActualizarOMV]="${ajuste#Actualizar : }"
    [ "${CFG[ActualizarOMV]}" = "" ] && CFG[ActualizarOMV]="$pre_ActualizarOMV"
    ajuste="$(grep "^RutaBackup : " "$ajustes_antiguo")" || error "No se encontró 'RutaBackup' en los ajustes antiguos: $ajustes_antiguo " \
                                                                  "'RutaBackup' not found in old settings: $ajustes_antiguo"
    CFG[RutaBackups]="${ajuste#RutaBackup : }"
    [ "${CFG[RutaBackups]}" = "" ] && CFG[RutaBackups]="$pre_RutaBackups"

    rm -r /etc/regen
    [ ! -d "${OR_dir}/settings" ] && mkdir -p "${OR_dir}/settings"
    OmvregenReset
    ProgramarBackup crear
    SalvarAjustes || return 1

    Info 3 ">>> Ajustes migrados desde 7.0.x o anterior. Consulta la ayuda para conocer las nuevas configuraciones." \
           ">>> Settings migrated from 7.0.x or earlier. Please consult the help to learn about new configurations."
}

# Crear o actualizar tarea en cron para limpieza semanal del hook. >/dev/null solo envia correo en caso de error
# Create or update cron job for weekly hook cleanup. >/dev/null only send email in case of error
ConfigurarLimpiezaHook() {
    local cron_tarea="0 5 * * 0 root /bin/bash /usr/sbin/omv-regen limpieza_semanal >/dev/null"
    local cron_archivo="${OR_cron_file:-/etc/cron.d/omv-regen}"

    omv_instalado || { echoe log ">>> OMV no está instalado, saltando la configuración de la limpieza del hook ..." \
                                 ">>> OMV is not installed, skipping hook cleanup configuration ..."; return 0; }

    if [ -f "$cron_archivo" ] && grep -Fxq "$cron_tarea" "$cron_archivo"; then
        return 0
    fi

    echo "$cron_tarea" > "$cron_archivo" || { error "No se ha podido configurar cron para limpieza semanal del hook." \
                                                    "Could not configure cron for weekly hook cleanup."; return 1; }
    chmod 644 "$cron_archivo"
    chown root:root "$cron_archivo"
    echoe log ">>> Tarea programada para limpieza semanal configurada." \
              ">>> Scheduled weekly cleanup task configured."
}

# Configurar la rotación de registros
# Set up log rotation
ConfigurarLogrotate () {
    [ -f "$OR_log_file" ] || touch "$OR_log_file"
    if [ ! -f "$OR_logRotate_file" ]; then
        echo "$OR_log_file {
  size 10M
  weekly
  missingok
  rotate 12
  compress
  delaycompress
  notifempty
  create 0640 root root
  copytruncate
  postrotate
    [ -x /usr/bin/systemctl ] && systemctl reload logrotate.service > /dev/null 2>&1 || true
  endscript
}" > "$OR_logRotate_file"
    fi
}

# Configurar sistema de captura de paquetes en actualizaciones
# Configure packet capture system in updates
ConfigurarHook() {
    [ ! -s "$OR_hook_file" ] && rm -f "$OR_hook_file"
    if [ ! -f "$OR_hook_file" ]; then
        cat <<EOF > "$OR_hook_file"
#!/bin/bash
# omv-regen Hook. Captures updated packages and logs execution details.

# Log the hook execution
echo "[\$(date +'%Y-%m-%d %H:%M:%S')][HOOK] >>> Hook executed by: \$0 \$@" >> /var/log/omv-regen.log

# Ensure the destination folder exists
if [ ! -d /var/lib/omv-regen/hook/ ]; then
    mkdir -p /var/lib/omv-regen/hook/
    chmod 755 /var/lib/omv-regen/hook
    chown root:root /var/lib/omv-regen/hook
fi

# Copy .deb files to the hook folder if not already present
cp -u /var/cache/apt/archives/*.deb /var/lib/omv-regen/hook/ 2>/dev/null || true
EOF
        chmod 755 "$OR_hook_file" || return 1
        chown root:root "$OR_hook_file" || return 1
    fi
    if [ ! -d "$OR_hook_dir" ]; then
        mkdir -p "$OR_hook_dir"
        chmod 755 "$OR_hook_dir"
        chown root:root "$OR_hook_dir"
    fi
    if [ ! -f "$OR_hook_file" ] || [ ! -d "$OR_hook_dir" ]; then
        error "Configuración del hook incompleta. Archivo o directorio faltante." \
              "Hook configuration incomplete. Missing file or directory."
        return 1
    fi

    return 0
}

# Verificar correcta configuración del hook
# Verify correct hook configuration
hook_es_ok() {

    omv_instalado || { echoe ">>> OMV no está instalado, saltando la comprobación del hook ..." \
                             ">>> OMV is not installed, skipping hook check ..."; return 0; }

    if [ ! -f "$OR_hook_file" ] || [ ! -s "$OR_hook_file" ]; then
        error "El archivo del hook no existe o está vacío: $OR_hook_file" \
              "The hook file does not exist or is empty: $OR_hook_file"
        return 1
    fi
    if [ "$(stat -c %a "$OR_hook_file")" != "755" ] || [ "$(stat -c %U:%G "$OR_hook_file")" != "root:root" ]; then
        error "Permisos o propiedad incorrecta en el archivo: $OR_hook_file" \
              "Incorrect permissions or ownership on the file: $OR_hook_file"
        return 1
    fi
    if ! grep -q "# Log the hook execution" "$OR_hook_file"; then
        error "Contenido del hook incompleto o incorrecto en: $OR_hook_file" \
              "Hook file content is incomplete or incorrect in: $OR_hook_file"
        return 1
    fi
    if [ ! -d "$OR_hook_dir" ]; then
        error "El directorio del hook no existe: $OR_hook_dir" \
              "The hook directory does not exist: $OR_hook_dir"
        return 1
    fi
    if [ "$(stat -c %a "$OR_hook_dir")" != "755" ] || [ "$(stat -c %U:%G "$OR_hook_dir")" != "root:root" ]; then
        error "Permisos o propiedad incorrecta en el directorio: $OR_hook_dir" \
              "Incorrect permissions or ownership on the directory: $OR_hook_dir"
        return 1
    fi
}

# Actualiza valor a variable y guarda en disco
# Updates value to variable and saves to disk
salvar_cfg() {
    local clave="$1" valor="$2"
    [ -z "$1" ] && { error "Argumento vacío." "Empty argument."; return 1; }
    [[ "${CFG[$clave]}" != "$valor" ]] || return 0
    CFG[$clave]="$valor"
    SalvarAjustes || return 1
}

# Valida ajustes actuales y escribe en disco
# Validates current settings and writes to disk
SalvarAjustes() {
    local res=0 mensaje_error="" carpeta CARPETAS_LIMPIAS=() clave
    local temp_file="${OR_tmp_dir}/ajustes"
    : > "$temp_file"

    [[ ! "${CFG[Idiomas]}" =~ ^(es|en)$ ]] && CFG[Idiomas]="" && AjustarIdioma
    FormatearSiNo
    # Eliminar barra final si existe (previene // en concatenaciones)
    # Remove trailing slash if it exists (prevents // in concatenations)
    CFG[RutaBackups]="${CFG[RutaBackups]%/}"

    txt 1 "Este valor es inválido y se ajusta a su valor predeterminado: " \
          "This value is invalid and is set to its default value: "
    ValidarAjuste() {
        local clave="$1" valor_pred="$2" regex="$3" min="$4" max="$5"
        if [[ -z "${CFG[$clave]}" || ( -n "$regex" && ! "${CFG[$clave]}" =~ $regex ) || \
          ( -n "$min" && -n "$max" && ( "${CFG[$clave]}" -lt "$min" || "${CFG[$clave]}" -gt "$max" ) ) ]]; then
            CFG[$clave]="$valor_pred"
            mensaje_error="${mensaje_error}${txt[1]}${clave}→${valor_pred}\n"
        fi
    }
    ValidarAjuste "ActualizarOMV" "$pre_ActualizarOMV" '^(Si|No)$'
    ValidarAjuste "RutaBackups" "$pre_RutaBackups" '^/([^/]+/)*[^/]*$'
    ValidarAjuste "RetencionDias" "$pre_RetencionDias" '^[0-9]{1,2}$' 0 99
    ValidarAjuste "RetencionMeses" "$pre_RetencionMeses" '^[0-9]{1,2}$' 0 24
    ValidarAjuste "RetencionSemanas" "$pre_RetencionSemanas" '^[0-9]{1,2}$' 0 52
    ValidarAjuste "ModoSilencio" "$pre_ModoSilencio" '^(Si|No)$'
    ValidarAjuste "OmitirRoot" "$pre_OmitirRoot" '^(Si|No)$'
    ValidarAjuste "ActualizarOmvregen" "$pre_ActualizarOmvregen" '^(Si|No)$'
    ValidarAjuste "UltimaBusqueda" "$pre_UltimaBusqueda" '^[0-9]+$'
    ValidarAjuste "RegenKernel" "$pre_RegenKernel" '^(Si|No)$'
    ValidarAjuste "RegenRed" "$pre_RegenRed" '^(Si|No)$'
    if [ -n "$mensaje_error" ]; then
        Mensaje error "$mensaje_error"
    fi
    for clave in "${!CFG[@]}"; do
        [[ "${CFG[$clave]}" == "Si" ]] && echo "$clave : ${txt[Si]}"     >>"$temp_file"
        [[ "${CFG[$clave]}" != "Si" ]] && echo "$clave : ${CFG[$clave]}" >>"$temp_file"
    done

    es_duplicada() {
        local valor="$1"
        for c in "${CARPETAS_LIMPIAS[@]}"; do
            [[ "$c" == "$valor" ]] && return 0
        done
        return 1
    }

    for carpeta in "${CARPETAS_ADICIONALES[@]}"; do
        if [[ "${carpeta:0:1}" != "/" ]] || [[ "$carpeta" == "/" ]]; then
            Mensaje alerta "La carpeta adicional $carpeta no es válida, ignorada en los ajustes." \
                           "The additional folder $carpeta is invalid, ignored in the settings."
        elif [[ "$carpeta" == "${CFG[RutaBackups]}" ]]; then
            Mensaje alerta "La carpeta adicional $carpeta es el destino del backup, ignorada en los ajustes." \
                           "The additional folder $carpeta is the backup destination, ignored in the settings."
        elif [[ "$carpeta" == "/root" ]]; then
            Mensaje alerta "La carpeta /root se gestiona desde la GUI (ajuste OmitirRoot), ignorada en los ajustes." \
                           "The /root folder is managed from the GUI (OmitirRoot setting), ignored in the settings."
        elif [[ "$carpeta" == "/etc/libvirt" || "$carpeta" == "/var/lib/libvirt" ]]; then
            Mensaje alerta "La carpeta adicional $carpeta se incluye por defecto en el backup, ignorada en los ajustes." \
                           "The additional folder $carpeta is included by default in the backup, ignored in the settings."
        elif es_duplicada "$carpeta"; then
            Mensaje alerta "Carpeta adicional duplicada $carpeta ignorada en los ajustes." \
                           "Duplicate additional folder $carpeta ignored in the settings."
        else
            CARPETAS_LIMPIAS+=("$carpeta")
            echo "${txt[Carpeta]} : $carpeta" >>"$temp_file"
        fi
    done

    CARPETAS_ADICIONALES=("${CARPETAS_LIMPIAS[@]}")
    txt 1 "# omv-regen version ${ORVersion}\n# Archivo de ajustes generado por omv-regen\n# No modifiques este archivo manualmente\n" \
          "# omv-regen version ${ORVersion}\n# Settings file generated by omv-regen\n# Do not modify this file manually\n"
    echo -e "${txt[1]}" >"$OR_ajustes_file" \
        || { Mensaje error "No se ha podido escribir en el archivo de ajustes de omv-regen, ajustes no guardados." \
                      "Failed to write to omv-regen settings file, settings not saved."
             return 1; }
    sort "$temp_file" | awk 1 >>"$OR_ajustes_file"
    rm -f "$temp_file"
    return 0
}

# Buscar nueva versión de omv-regen y actualizar si existe
# CFG[UltimaBusqueda] guarda el día en que se hizo la última búsqueda (formato yymmdd)
# Si vale "1", significa que hay una actualización pendiente que no se aplicó todavía
# Check for new version of omv-regen and update if it exists
# CFG[LastSearch] saves the day the last search was performed (yymmdd format).
# If it is "1", it means there is a pending update that has not been applied yet.
BuscarOR() {
    local version_disp
    local or_file="${OR_tmp_dir}/or_file"
    local busqueda_anterior="${CFG[UltimaBusqueda]}"
    local version_nueva="${OR_ajustes_dir}/new_version"
    [ -f "$or_file" ] && rm -f "$or_file"
    trap 'rm -f "$or_file"' EXIT

    NotificarVersion() {
        if [ ! -f "$version_nueva" ] || ! grep -Fxq "$version_disp" "$version_nueva"; then
            txt cabecera "NEW VERSION"
            txt cuerpo "Hay una nueva version disponible de omv-regen: $version_disp" \
                       "A new version of omv-regen is available: $version_disp"
            echo "${txt[cuerpo]}" > "$version_nueva"
            EnviarCorreo "${txt[cabecera]}" "${txt[cuerpo]}"
        fi
    }

    [[ "${CFG[UltimaBusqueda]}" -eq $(date +%y%m%d) ]] && return 0
    salvar_cfg UltimaBusqueda "$(date +%y%m%d)" || return 1
    
    echoe log "\n\n>>>    Buscando actualizaciones de omv-regen ...\n" \
              "\n\n>>>    Checking for omv-regen updates ...\n"

    regen_en_progreso && { Info 3 ">>> No es posible actualizar omv-regen hasta que finalice la regeneración. \
                                  \n>>> Se volverá a intentar el $(date -d tomorrow +%d/%m/%y)." \
                                  ">>> It is not possible to update omv-regen until the regeneration is complete. \
                                  \n>>> It will be attempted again on $(date -d tomorrow +%d/%m/%y)."; return 0; }

    echoe log ">>> Conectando a github.........." \
              ">>> Connecting to github.........."
    if ! wget -q -O "$or_file" "${URL_OMVREGEN_SCRIPT}"; then
        error "No se ha podido descargar el archivo de omv-regen desde github." \
              "The omv-regen file could not be downloaded from github."
        salvar_cfg UltimaBusqueda "$busqueda_anterior" || return 1
        return 1
    fi

    version_disp="$(awk -F "regen " 'NR==8 {print $2}' "$or_file")"
    [ "$version_disp" = "$ORVersion" ] && { echoe log ">>> No hay versiones nuevas de omv-regen." \
                                                      ">>> There are no new versions of omv-regen."
                                            [ -f "$version_nueva" ] && rm -f "$version_nueva"; return 0; }

    Info 2 ">>> ¡Hay una nueva versión de omv-regen!" \
           ">>> There is a new version of omv-regen!"
    salvar_cfg UltimaBusqueda 1 || return 1

    if [ "${CFG[ActualizarOmvregen]}" = "No" ]; then
        modo_desatendido && { 
            echoe ">>> Actualización automática de omv-regen desactivada, NO se va a actualizar." \
                  ">>> Omv-regen auto-update disabled, it will NOT be updated."
            NotificarVersion; return 0; }
        Pregunta ">>> Actualización automática de omv-regen desactivada.\n\n>>> ¿Quieres actualizar ahora?" \
                 ">>> Omv-regen auto-update disabled.\n\n>>> Do you want to update now?" || { 
            NotificarVersion; return 0; }
    fi
    
    cat "$or_file" >"$OR_script_file"
    [ -f "$version_nueva" ] && rm -f "$version_nueva"
    salvar_cfg UltimaBusqueda "$(date +%y%m%d)" || return 1
    sleep 2
    modo_desatendido || clear
    Salir ">>> omv-regen se ha actualizado. Saliendo ..." \
          ">>> omv-regen has been updated. Exiting ..."
}

######################################### FUNCIONES DE BACKUP #########################################
########################################## BACKUP FUNCTIONS ###########################################

# Validar la ruta de los backups
# Validate backups path
dir_backups_es_ok() { [[ "${CFG[RutaBackups]}" == "/ORBackup" ]] || [[ -d "${CFG[RutaBackups]}" && -w "${CFG[RutaBackups]}" ]]; }

# Actualizar repositorio si no se ha hecho ningún backup la ultima semana
# Update repository if no backup has been made in the last week
LimpiezaSemanal() {
    local log_archivo="${OR_log_file:-/var/log/omv-regen.log}"
    local log_rotado="${log_archivo}.1"
    local log_combinado="${OR_tmp_dir}/log_combinado"
    local ultima_fecha fecha_hoy ts_ultima ts_hoy dias

    omv_instalado || { echoe "OMV no está instalado, saltando limpieza semanal." \
                             "OMV not installed, skipping weekly cleanup."; return 0; }

    echoe ">>> Se va a ejecutar la limpieza semanal del hook si procede." \
          ">>> The hook will be cleaned weekly if applicable."

    cat "$log_archivo" "$log_rotado" 2>/dev/null > "$log_combinado"
    ultima_fecha=$(grep -E ">>> Actualizando el repositorio de omv-regen ...|>>> Updating the omv-regen repository ..." "$log_combinado" | \
                   cut -d'[' -f2 | cut -d']' -f1 | cut -d' ' -f1 | sort -r | head -n 1 | tr -d '[:space:]')
    fecha_hoy=$(date '+%Y-%m-%d')
    if [[ -n "$ultima_fecha" ]]; then
        ts_ultima=$(date -d "$ultima_fecha" +%s 2>/dev/null) || ts_ultima=0
        ts_hoy=$(date -d "$fecha_hoy" +%s 2>/dev/null) || ts_hoy=0
        if (( ts_ultima <= ts_hoy )); then
            dias=$(( (ts_hoy - ts_ultima) / 86400 ))
            if (( dias >= 7 )); then
                echoe ">>> No se encontró ejecución reciente de 'ActualizarRepo'. Ejecutando limpieza semanal." \
                      ">>> No recent execution of 'ActualizarRepo' found. Running weekly cleanup."
                ActualizarRepo &>/dev/null || { error "No se ha podido actualizar el repositorio." \
                                                      "The repository could not be updated."; return 1; }
            else
                echoe ">>> Limpieza semanal no necesaria. 'ActualizarRepo' ya ejecutado esta semana." \
                      ">>> Weekly cleanup not needed. 'ActualizarRepo' already executed this week."
            fi
        fi
    else
        echoe ">>> Limpieza semanal ejecutada por primera vez o sin registros previos." \
              ">>> Weekly cleaning performed for the first time or without previous logs."
	fi
    echoe ">>> Limpieza semanal terminada." \
          ">>> Weekly cleaning completed."
    return 0
}

# Comprobar si hay una tarea programada de backup
# Check if there is a scheduled backup task
existe_tarea_backup() { [[ $(xmlstarlet sel -t -v "count(/config/system/crontab/job[command='omv-regen backup'])" "$Config_xml_file") -ge 1 ]]; }

# Crea/elimina una tarea programada de backup en la GUI de OMV
# Create/delete a scheduled backup task in the OMV GUI
ProgramarBackup() {
    local conf_xml_copia="${Conf_tmp_file}.ori" conf_xml_temp="$Conf_tmp_file"
    local comando="omv-regen backup" pb_res=0 accion=$1

    omv_instalado || { echoe ">>> OMV no está instalado, saltando la programación de un backup ..." \
                             ">>> OMV is not installed, skipping backup scheduling ..."; return 0; }

    case "$accion" in
        "")         if existe_tarea_backup; then accion="eliminar"; else accion="crear"; fi ;;
        crear)      : ;;
        eliminar)   ! existe_tarea_backup && return 0 ;;
        *)          error "Acción no válida: $accion" "Invalid action: $accion"; return 1 ;;
    esac

    if [ "$accion" = "crear" ]; then
        ValidarCrontabBD || { error "El formato de crontab en la base de datos no coincide." \
                                    "The crontab format in the database does not match."; return 1; }
    fi

    echoe log ">>> Creando archivos temporales ..." \
              ">>> Creating temporary files ..."
    [ -f "$conf_xml_copia" ] && rm -f "$conf_xml_copia"
    cp -a "$Config_xml_file" "$conf_xml_copia" && cat "$Config_xml_file" > "$conf_xml_copia"
    xmlstarlet fo "$conf_xml_copia" | tee "$Config_xml_file" >/dev/null
    [ -f "$conf_xml_temp" ] && rm -f "$conf_xml_temp"
    cp -a "$Config_xml_file" "$conf_xml_temp" && cat "$Config_xml_file" > "$conf_xml_temp"

    if [ "$accion" = "eliminar" ]; then
        echoe log ">>> Eliminando tarea programada con comando '$comando' ..." \
                  ">>> Deleting scheduled task with command '$comando' ..."
        xmlstarlet edit -d "/config/system/crontab/job[command=\"${comando}\"]" "$conf_xml_temp" | tee "$Config_xml_file" >/dev/null
    else
        echoe log ">>> Creando tarea programada con comando '$comando' ..." \
                  ">>> Creating scheduled task with command '$comando' ..."
        local uuid
        uuid=$(cat /proc/sys/kernel/random/uuid)
        txt comentario "tarea de omv-regen" "omv-regen task"
        local nueva_tarea="<job>
  <uuid>${uuid}</uuid>
  <enable>1</enable>
  <execution>exactly</execution>
  <sendemail>1</sendemail>
  <comment>${txt[comentario]}</comment>
  <type>userdefined</type>
  <minute>0</minute>
  <everynminute>0</everynminute>
  <hour>3</hour>
  <everynhour>0</everynhour>
  <month>*</month>
  <dayofmonth>*</dayofmonth>
  <everyndayofmonth>0</everyndayofmonth>
  <dayofweek>*</dayofweek>
  <username>root</username>
  <command>${comando}</command>
</job>"

        xmlstarlet edit -d "/config/system/crontab/job[command=\"${comando}\"]" "$Config_xml_file" | tee "$conf_xml_temp" >/dev/null
        if [ "$(awk 'END{print $0}' "$conf_xml_temp" )" = "</config>" ]; then
            sed -i '$d' "$conf_xml_temp"
            echo "${nueva_tarea}</config>" >> "$conf_xml_temp"
            xmlstarlet edit -m "/config/job" "/config/system/crontab" "$conf_xml_temp" | tee "$Config_xml_file" >/dev/null
        else
            pb_res=1
        fi
    fi

    manejar_error() {
        error "$1" "$2"
        cat "$conf_xml_copia" >"$Config_xml_file"
        omv-salt deploy run --quiet cron
        rm -f "${Conf_tmp_file}.ori" "$Conf_tmp_file"
        return 1
    }

    if [ $pb_res -eq 0 ]; then
        echoe log ">>> Validando archivo XML con xmlstarlet ..." \
                  ">>> Validating XML file with xmlstarlet ..."
        xmlstarlet val "$Config_xml_file" >/dev/null || manejar_error "El archivo XML no es válido." \
                                                               "The XML file is not valid."
        echoe log ">>> Ejecutando 'omv-salt deploy run --quiet cron' ..." \
                  ">>> Running 'omv-salt deploy run --quiet cron' ..."
        omv-salt deploy run --quiet cron || manejar_error ">>> ERROR al aplicar cron con omv-salt" \
                                                          ">>> ERROR applying cron with omv-salt"
    fi

    rm -f "${Conf_tmp_file}.ori" "$Conf_tmp_file"
    return "$pb_res"
}

# Validar estructura esperada del XML de tareas cron de OMV
# Validate expected structure of OMV cron job XML
ValidarCrontabBD() {
    local xml_file="$Config_xml_file" bloque_xml job_ejemplo="<!--
<job>
<uuid>xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx</uuid>
<enable>0|1</enable>
<execution>exactly|hourly|daily|weekly|monthly|yearly|reboot</execution>
<sendemail>0|1</sendemail>
<type>reboot|shutdown|standby|userdefined</type>
<comment>xxx</comment>
<minute>[00-59|*]</minute>
<everynminute>0|1</everynminute>
<hour>[00-23|*]</hour>
<everynhour>0|1</everynhour>
<dayofmonth>[01-31|*]</dayofmonth>
<everyndayofmonth>0|1</everyndayofmonth>
<month>[01-12|*]</month>
<dayofweek>[1-7|*]</dayofweek>
<username>xxx</username>
<command>xxx</command>
</job>
-->"
    bloque_xml=$(awk '/<crontab>/,/<\/crontab>/' "$xml_file" | awk '/<!--/,/-->/' | sed 's/^[[:space:]]*//')

    # Arreglar error de formato del ejemplo de la base de datos de OMV. No quitar esto para compatibilidad con versiones anteriores de OMV.
    # Fix formatting error in the OMV database example. Do not remove this for backward compatibility with OMV versions.
    bloque_xml=$(echo "$bloque_xml" | sed -E 's#<sendemail>0\|1</?sendemail>#<sendemail>0|1</sendemail>#g')

    if [[ "$job_ejemplo" != "$bloque_xml" ]]; then
        error "Bloque de ejemplo de crontab modificado o ausente en la base de datos de OMV." \
              "Sample crontab block modified or missing in OMV database."
        return 1
    fi
}

################################################ EJECUTAR BACKUP ################################################
################################################## RUN BACKUP ###################################################

# Actualiza el repositorio. Elimina paquetes no instalados, fusiona con paquetes capturados en el hook y busca paquetes faltantes
# Update the repository. Remove uninstalled packages, merge with hook-captured packages, and check for missing packages
ActualizarRepo() {
    local paquete_repo nombre_paquete_repo paquete_nuevo nombre_paquete_nuevo

    # No modificar este texto, es el que busca la función 'LimpiezaSemanal' para ejecutarse
    # Do not modify this text, it is what the 'LimpiezaSemanal' function looks for to be executed
    echoe sil ">>> Actualizando el repositorio de omv-regen ..." \
              ">>> Updating the omv-regen repository ..."
    EsperarAptDpkg 

    if ! hook_es_ok; then
        echoe sil ">>> El Hook no está configurado. Procediendo a su configuración." \
                  ">>> Hook is not configured. Proceeding to configure it."
        ConfigurarHook || { error "No se pudo configurar el hook. Abortando ... ${txt[error]}" \
                                  "Could not configure hook. Aborting ... ${txt[error]}"; return 1; }
    fi

    if [ ! -d "$OR_repo_dir" ]; then
        echoe sil ">>> La carpeta del repositorio no existe. Procediendo a su creación ..." \
                  ">>> The repository folder does not exist. Proceeding to create it ..."
        mkdir -p "$OR_repo_dir" || { error "Fallo creando $OR_repo_dir Abortando ... ${txt[error]}" \
                                           "Failure creating $OR_repo_dir Aborting ... ${txt[error]}"; return 1; }
    fi

    echoe sil ">>> Eliminando del repositorio paquetes no instalados ..." \
              ">>> Removing uninstalled packages from the repository ..."
    p=0
    while IFS= read -r paquete_repo; do
        nombre_paquete_repo=$( awk -F "_" '{print $1}' <<< "$paquete_repo" )
        if ! dpkg-query --show -f='${Package}\n' "$nombre_paquete_repo" >/dev/null 2>&1; then
            echoe sil ">>> Eliminando paquete obsoleto: $nombre_paquete_repo ..." \
                      ">>> Removing obsolete package: $nombre_paquete_repo ..."
            rm -f "${OR_repo_dir}/${nombre_paquete_repo}"* \
                || { error "Fallo eliminando paquetes no instalados." \
                           "Failure removing uninstalled packages." ; return 1; }
            p=1
        fi
    done < <(find "$OR_repo_dir" -type f -name "*.deb" -exec basename {} \; | sort)
    [ $p -eq 0 ] && echoe sil ">>> No hay paquetes para eliminar en el repositorio." \
                              ">>> There are no packages to remove in the repository."
    
    echoe sil ">>> Fusionando en el repositorio paquetes capturados con el hook ..." \
              ">>> Merging packages captured with the hook into the repository ..."
    if compgen -G "${OR_hook_dir}/*.deb" >/dev/null; then
        for paquete_nuevo in "${OR_hook_dir}"/*.deb; do
            [ -e "$paquete_nuevo" ] || continue
            nombre_paquete_nuevo="$(awk -F "_" '{print $1}' <<< "$(basename "$paquete_nuevo")")"
            if [[ ! "$nombre_paquete_nuevo" =~ ^openmediavault ]] || ! dpkg-query --show -f='${Package}\n' "$nombre_paquete_nuevo" 2>/dev/null; then
                echoe sil ">>> Eliminando del hook paquete no perteneciente a repositorios de OMV o no instalado: $(basename "$paquete_nuevo")" \
                          ">>> Removing from the hook a package that does not belong to OMV repositories or is not installed: $(basename "$paquete_nuevo")"
                rm -f "$paquete_nuevo" || return 1
            else
                paquete_repo="$(find "$OR_repo_dir" -type f -name "${nombre_paquete_nuevo}_*.deb" -print -quit)"
                if [ -f "$paquete_repo" ] && [ "$(basename "$paquete_nuevo")" = "$(basename "$paquete_repo")" ]; then
                    echoe sil ">>> $paquete_nuevo ya está en el repositorio. Eliminando ..." \
                              ">>> $paquete_nuevo is already in the repository. Deleting ..."
                    rm -f "$paquete_nuevo" || return 1
                else
                    if [ -f "$paquete_repo" ]; then
                        nombre_paquete_repo=$( awk -F "_" '{print $1}' <<< "$(basename "$paquete_repo")" )
                        echoe sil ">>> Eliminando versiones antiguas del paquete: ${nombre_paquete_repo}_* ..." \
                                  ">>> Deleting older versions of package: ${nombre_paquete_repo}_* ..."
                        find "$OR_repo_dir" -maxdepth 1 -type f -name "${nombre_paquete_repo}_*.deb" ! -name "$(basename "$paquete_nuevo")" -delete || return 1
                    fi
                    echoe sil ">>> Moviendo paquete nuevo al repositorio $paquete_nuevo ..." \
                              ">>> Moving new package to repository $paquete_nuevo ..."
                    mv "$paquete_nuevo" "${OR_repo_dir}/" || { error "Fallo moviendo archivo." \
                                                                     "Failed to move file."; return 1; }
                    DescargarOtraArquitectura "$paquete_nuevo" "$OR_repo_dir"
                fi
            fi
        done
    else
        echoe sil ">>> No hay paquetes nuevos en el hook." \
                  ">>> There are no new packages in the hook."
    fi

    echoe sil ">>> Verificación de paquetes faltantes ..." \
              ">>> Check for missing packages ..."
    BuscarPaquetesFaltantes || { error "Fallo verificando paquetes faltantes. ${txt[error]}" \
                                             "Failed to check for missing packages. ${txt[error]}"; return 1; }
    
    echoe sil ">>> Actualización del repositorio de omv-regen completada." \
              ">>> omv-regen repository update completed."

}

# Esperar hasta que no haya procesos de APT ni dpkg en ejecución
# Wait until there are no APT or dpkg processes running
EsperarAptDpkg () {
    while pgrep -x "apt" > /dev/null || pgrep -x "dpkg" > /dev/null; do
        echoe sil ">>> APT o dpkg están en ejecución, esperando a que terminen ..." \
                  ">>> APT or dpkg are running, waiting for them to finish ..."
        sleep 5
    done
}

# Verificar si faltan paquetes en el repositorio y buscar
# Check for missing packages in the repository and search
BuscarPaquetesFaltantes() {
    local n=0 paquete nombre version paquetes_en_repo=() paquetes_instalados=() paquetes_faltantes=()
    local paquete_faltante nombre_paquete_faltante version_paquete_faltante archivo intento version_instalada
    local url_paquetes_omv="$URL_OPENMEDIAVAULT_PAQUETES"

    echoe sil ">>> Eliminando paquetes con versiones que no coinciden con la instalada ..." \
              ">>> Removing packages with versions different from the installed version ..."
    for archivo in "$OR_repo_dir"/*.deb; do
        [ ! -f "$archivo" ] && continue
        nombre="$(dpkg-deb -f "$archivo" Package 2>/dev/null)"
        version="$(dpkg-deb -f "$archivo" Version 2>/dev/null)"
        version_instalada="$(dpkg-query -W -f='${Version}' "$nombre" 2>/dev/null)"
        if [ -n "$version_instalada" ] && [ "$version" != "$version_instalada" ]; then
            echoe sil ">>> Eliminando $archivo (versión $version) porque la instalada es $version_instalada" \
                      ">>> Removing $archivo (version $version) because installed version is $version_instalada"
            rm -f "$archivo"
            ((n++))
        fi
    done
    [ $n -eq 0 ] && echoe sil ">>> Todos los paquetes en el repositorio coinciden con las versiones instaladas." \
                              ">>> All packages in the repository match the installed versions."
    [ $n -ne 0 ] && echoe sil ">>> Se eliminaron $n paquetes del repositorio por versiones distintas." \
                              ">>> $n packages removed from the repository due to version mismatch."

    echoe sil ">>> Verificando paquetes faltantes ..." \
              ">>> Checking for missing packages ..."
    while IFS= read -r paquete; do
        paquetes_en_repo+=("$paquete")
    done < <(find "$OR_repo_dir" -type f -name "*.deb" -exec basename {} \; | awk -F_ '{print $1"_"$2}' | sort)
    while IFS= read -r paquete; do
        paquetes_instalados+=("$paquete")
    done < <(dpkg-query --show -f='${Package}_${Version}\n' | grep openmediavault | sort)
    while IFS= read -r paquete; do
        paquetes_faltantes+=("$paquete")
    done < <(comm -13 <(printf "%s\n" "${paquetes_en_repo[@]}") <(printf "%s\n" "${paquetes_instalados[@]}"))
    if [ "${#paquetes_faltantes[@]}" -eq 0 ]; then
        echoe sil ">>> No faltan paquetes en el repositorio." \
                  ">>> No missing packages in the repository."
    else
        echoe sil ">>> Faltan paquetes en el repositorio, procediendo a su búsqueda ..." \
                  ">>> There are missing packages in the repository, proceeding to search ..."
        RepoIncompleto=""
        for paquete_faltante in "${paquetes_faltantes[@]}"; do
            echoe sil ">>> Paquete faltante: $paquete_faltante. Intentando descargar ..." \
                      ">>> Missing package: $paquete_faltante. Attempting to download ..."
            nombre_paquete_faltante="$(awk -F_ '{print $1}' <<< "$paquete_faltante")"
            version_paquete_faltante="$(awk -F_ '{print $2}' <<< "$paquete_faltante")"
            archivo=""
            for intento in {1..3}; do
                if apt-get download "${nombre_paquete_faltante}=${version_paquete_faltante}" >/dev/null 2>&1; then
                    archivo="$(find . -type f -name "${nombre_paquete_faltante}_${version_paquete_faltante}_*.deb" | head -n 1)"
                    break
                fi
                    echoe sil ">>> Reintentando descargar el paquete: $nombre_paquete_faltante, intento $intento" \
                              ">>> Retrying download of package: $nombre_paquete_faltante, attempt $intento"
                    sleep 2
            done
            if [ ! -f "$archivo" ]; then
                echoe sil ">>> Intentando descargar desde el repositorio de GitHub ..." \
                          ">>> Attempting to download from GitHub repository ..."
                archivo="${nombre_paquete_faltante}_${version_paquete_faltante}_all.deb"
                if wget -q -O "$archivo" "${url_paquetes_omv}${nombre_paquete_faltante}/${archivo}"; then
                    echoe sil ">>> Descargado desde GitHub: $archivo" \
                              ">>> Downloaded from GitHub: $archivo"
                    dpkg-deb --info "$archivo" >/dev/null || {
                        error "$archivo no es un .deb válido. Eliminando archivo ..." \
                              "$archivo is not a valid .deb. Deleting file ..."
                        rm "$archivo"
                    }
                else
                    # Intento especial para omvextrasorg - Special attempt for omvextrasorg
                    if [[ "$nombre_paquete_faltante" == "openmediavault-omvextrasorg" ]]; then
                        echoe sil ">>> Intentando ruta alternativa para omvextrasorg ..." \
                                  ">>> Trying alternative path for omvextrasorg ..."
                        archivo="openmediavault-omvextrasorg_latest_all${OMV_VERSION__or}.deb"
                        local url="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/${archivo}"
                        if wget -q -O "$archivo" "$url"; then
                            version="$(dpkg-deb -f "$archivo" Version 2>/dev/null)"
                            if [[ "${version}" == "${version_paquete_faltante}" ]]; then
                                echoe sil ">>> Descargado desde repositorio de omv-extras: $archivo Version: $version" \
                                          ">>> Downloaded from omv-extras repository: $archivo Version: $version"
                                mv "$archivo" "${OR_repo_dir}/openmediavault-omvextrasorg_${version}_all.deb"
                            else
                                error "No se pudo localizar el paquete en el repositorio de omv-extras: $nombre_paquete_faltante" \
                                      "Could not locate the package in the omv-extras repository: $nombre_paquete_faltante"
                                rm -f "$archivo"
                                archivo=""
                            fi
                        fi
                    else
                        archivo="" && error "No se pudo localizar el paquete en GitHub: $nombre_paquete_faltante" \
                                            "Could not locate the package in GitHub: $nombre_paquete_faltante"
                    fi
                fi
            fi
            if [ -f "$archivo" ] && ! dpkg-deb --info "$archivo" >/dev/null; then
                error "$archivo no es un .deb válido. Eliminando archivo ..." \
                      "$archivo is not a valid .deb. Deleting file ..."
                rm "$archivo"
            fi
            if [ -f "$archivo" ]; then
                echoe sil ">>> Paquete instalado faltante recuperado: $archivo" \
                          ">>> Missing installed package recovered: $archivo"
                mv "$archivo" "${OR_repo_dir}/"  || { error "Fallo moviendo archivo." \
                                                         "Failed to move file."; return 1; }
                DescargarOtraArquitectura "$archivo" "$OR_repo_dir"
            else
                error "No se pudo descargar Paquete instalado faltante. ${nombre_paquete_faltante}=${version_paquete_faltante} Actualiza openmediavault para resolverlo." \
                      "Could not download Missing installed package. ${nombre_paquete_faltante}=${version_paquete_faltante} Update openmediavault to resolve it."
                RepoIncompleto="$RepoIncompleto ${nombre_paquete_faltante}=${version_paquete_faltante}"
                return 1
            fi
        done
        echoe sil ">>> Se encontraron todos los paquetes faltantes." \
                  ">>> All missing packages were found."
    fi

    return 0
}

# Descargar arquitecturas diferentes de un paquete instalado.
# Download different architectures of an installed package.
DescargarOtraArquitectura() {
    local paquete="$1" destino="$2" nombre_paquete version_paquete archivo
    
    if [[ "$(basename "$paquete")" != *all.deb ]]; then
        nombre_paquete="$(awk -F"_" '{print $1}' <<< "$(basename "$paquete")")"
        version_paquete="$(awk -F"_" '{print $2}' <<< "$(basename "$paquete")")"
        echoe sil ">>> El paquete $paquete no es 'all'. Buscando otras arquitecturas si existen ..." \
                  ">>> The $paquete package is not 'all'. Looking for other architectures if they exist ..."
        if [[ "$(basename "$paquete")" == *amd64.deb ]]; then
            if apt-get download "${nombre_paquete}":arm64="$version_paquete" >/dev/null 2>&1; then
                archivo="$(find . -type f -name "${nombre_paquete}_${version_paquete}_*.deb" | head -n 1)"
            else
                echoe sil ">>> No se pudo descargar el paquete para la arquitectura arm64 ..." \
                          ">>> Could not download the package for arm64 architecture ..."
            fi
        elif [[ "$(basename "$paquete")" == *arm64.deb ]]; then
            if apt-get download "${nombre_paquete}":amd64="$version_paquete" >/dev/null 2>&1; then
                archivo="$(find . -type f -name "${nombre_paquete}_${version_paquete}_*.deb" | head -n 1)"
            else
                echoe sil ">>> No se pudo descargar el paquete para la arquitectura amd64 ..." \
                          ">>> Could not download the package for amd64 architecture ..."
            fi
        fi
        archivo="$(find . -type f -name "${nombre_paquete}_${version_paquete}_*.deb" | head -n 1)"
        if [ -f "$archivo" ]; then
            echoe sil ">>> Moviendo al repositorio $archivo encontrado ..." \
                      ">>> Moving to repository $archivo found ..."
            mv "$archivo" "${destino}/"
        else
            echoe sil ">>> No se han encontrado otras arquitecturas para $(basename "$paquete")" \
                      ">>> No other architectures found for $(basename "$paquete")"
        fi
    fi
}

# Actualizar marcas de backups existentes y eliminar antiguos según retenciones configuradas
# Update existing backup tags and delete old ones based on configured retentions
GestionarBackups () {
    local marca dias archivo_retenido fecha1 fecha2 fecha3 segundos_archivo_1 segundos_archivo_3 nombre_con_marca nombre_sin_marca retencion

    # Eliminar la marca del segundo backup (fecha2) cuando los tres backups están dentro del periodo de retención
    # Remove the second backup's mark (fecha2) when the three backups fall within the retention period
    for marca in _d_ _s_ _m_; do
        [ "$marca" = "_d_" ] && dias=1 &&  txt 1 "diaria" "daily"
        [ "$marca" = "_s_" ] && dias=7 &&  txt 1 "semanal" "weekly"
        [ "$marca" = "_m_" ] && dias=30 && txt 1 "mensual" "monthly"
        archivo_retenido="$( find "${CFG[RutaBackups]}" -maxdepth 1 -type f -name "ORBackup_*${marca}*regen.tar.gz" | sort -r )"
        if [[ $(grep -c . <<< "$archivo_retenido") -ge 3 ]]; then
            echoe sil ">>> Actualizando marcas de retención ${txt[1]} ..." \
                      ">>> Updating ${txt[1]} retention marks ..."
            fecha1="$( basename "$(awk 'NR==1{print $0}' <<< "$archivo_retenido")" | awk -F "_" '{print $2"_"$3}' )"
            fecha2="$( basename "$(awk 'NR==2{print $0}' <<< "$archivo_retenido")" | awk -F "_" '{print $2"_"$3}' )"
            fecha3="$( basename "$(awk 'NR==3{print $0}' <<< "$archivo_retenido")" | awk -F "_" '{print $2"_"$3}' )"
            segundos_archivo_1=$( date -d "20${fecha1:0:2}-${fecha1:2:2}-${fecha1:4:2} ${fecha1:7:2}:${fecha1:9:2}:${fecha1:11:2}" +%s )
            segundos_archivo_3=$( date -d "20${fecha3:0:2}-${fecha3:2:2}-${fecha3:4:2} ${fecha3:7:2}:${fecha3:9:2}:${fecha3:11:2}" +%s )
            if [[ $(( segundos_archivo_1-segundos_archivo_3 )) -le $(( dias*(86400+60) )) ]]; then # Añade un minuto cada dia - Add one minute every day
                while IFS= read -r nombre_con_marca; do
                    nombre_sin_marca="$(dirname "$nombre_con_marca")/$(awk -F "$marca" '{print $1"_"$2}' <<< "$(basename "$nombre_con_marca")")"
                    echoe sil ">>> Eliminando retención ${txt[1]} del backup $nombre_sin_marca ..." \
                              ">>> Removing ${txt[1]} retention of the $nombre_sin_marca backup ..."
                    mv "$nombre_con_marca" "$nombre_sin_marca" | _orl sil
                done <<< "$(find "${CFG[RutaBackups]}" -maxdepth 1 -type f -name "ORBackup_${fecha2}*${marca}*")"
            fi
        else
            echoe sil ">>> No hay marcas de retención ${txt[1]} para modificar." \
                      ">>> There are no ${txt[1]} retention marks to modify."
        fi
    done

    # Eliminar marcas de backups mas antiguos que la retención configurada
    # Remove backup tags older than the configured retention
    for marca in _d_ _s_ _m_; do
        [ "$marca" = "_d_" ] && retencion="${CFG[RetencionDias]}"    && dias=$(( retencion - 1 ))  && txt 1 "diaria"  "daily"   && txt 2 "días"    "days"
        [ "$marca" = "_s_" ] && retencion="${CFG[RetencionSemanas]}" && dias=$(( retencion * 7 ))  && txt 1 "semanal" "weekly"  && txt 2 "semanas" "weeks"
        [ "$marca" = "_m_" ] && retencion="${CFG[RetencionMeses]}"   && dias=$(( retencion * 30 )) && txt 1 "mensual" "monthly" && txt 2 "meses"   "months"
        if [ "$( find "${CFG[RutaBackups]}" -maxdepth 1 -type f -name "ORBackup_*${marca}*" -mtime "+${dias}" | wc -l )" = "0" ]; then
            echoe sil ">>> No hay backups con retención ${txt[1]} de hace más de $retencion ${txt[2]}" \
                      ">>> There are no ${txt[1]} retention backups older than $retencion ${txt[2]}"
        else
            echoe sil ">>> Eliminando marcas de retención ${txt[1]} de hace más de $retencion ${txt[2]} ..." \
                      ">>> Removing  ${txt[1]} retention marks from more than $retencion ${txt[2]} ago ..."
            while IFS= read -r nombre_con_marca; do
                nombre_sin_marca="$(dirname "$nombre_con_marca")/$(awk -F "$marca" '{print $1"_"$2}' <<< "$(basename "$nombre_con_marca")")"
                echoe sil ">>> Eliminando retención ${txt[1]} del backup $nombre_sin_marca ..." \
                          ">>> Removing ${txt[1]} retention of the $nombre_sin_marca backup ..."
                mv "$nombre_con_marca" "$nombre_sin_marca" | _orl sil
            done <<< "$(find "${CFG[RutaBackups]}" -maxdepth 1 -type f -name "ORBackup_*${marca}*" -mtime "+$dias")"
        fi
    done

    # Eliminar backups sin retención con más de 10 horas de antigüedad
    # Delete backups without retention that are older than 10 hours
    if [ "$(find "${CFG[RutaBackups]}" -maxdepth 1 -type f -name "ORBackup_*" -not -name "*_m_*" -not -name "*_s_*" -not -name "*_d_*" -mmin +600 | wc -l)" = 0 ]; then
        echoe sil ">>> No hay backups no retenidos de hace más de 10 horas para eliminar." \
                  ">>> There are no unretained backups from more than 10 hours ago to delete."
    else
        echoe sil ">>> Eliminando backups no retenidos de hace más de 10 horas ..." \
                  ">>> Deleting unretained backups from more than 10 hours ago ..."
        find "${CFG[RutaBackups]}" -maxdepth 1 -type f -name "ORBackup_*" -not -name "*_m_*" -not -name "*_s_*" -not -name "*_d_*" -mmin +600 -exec rm -v {} + | _orl sil
    fi
}

EjecutarBackup () {
    local marca_fecha hoy cont paquete carpeta archivo res=0 estado nuevo_nombre servidor clave ruta_destino
    marca_fecha=$(date +%y%m%d_%H%M%S); hoy="$(date +'%Y-%m-%d %H:%M:%S')"
    local dir_regen="${CFG[RutaBackups]}/regen_${marca_fecha}"
    local basename_regen="regen_${marca_fecha}"
    servidor="$(hostname --short)"
  
    omv_instalado || { Mensaje "OMV no está instalado, no puedes hacer un backup." \
                               "OMV is not installed, you cannot make a backup."; return 0; }

    dir_backups_es_ok || { Mensaje error "No se pudo completar el backup, la carpeta de destino de backups no es válida." \
                                         "The backup could not be completed, the backup destination folder is invalid."; return 1; }

    mkdir -p "$dir_regen"
    echoe sil "$Logo_omvregen"
    echoe "\n>>>\n>>>>>>       <<< Backup de fecha $hoy >>>\n>>>\n \
           \n>>> Servidor: $servidor \n" \
          "\n>>>\n>>>>>>       <<< Backup dated $hoy >>>\n>>>\n \
           \n>>> Server: $servidor \n"
    echoe sil ">>> Los parámetros actuales establecidos para el backup son: \
              \n>>> Carpeta donde se guarda el backup           → ${CFG[RutaBackups]} \
              \n>>> Actualizar automáticamente openmediavault   → ${CFG[ActualizarOMV]} \
              \n>>> Opción modo silencio activada               → ${CFG[ModoSilencio]} \
              \n>>> Omitir carpeta /root en el backup           → ${CFG[OmitirRoot]} \
              \n>>> Actualizar automáticamente omv-regen        → ${CFG[ActualizarOmvregen]} \
              \n>>> Retención diaria de backups                 → ${CFG[RetencionDias]} días \
              \n>>> Retención semanal de backups                → ${CFG[RetencionSemanas]} semanas \
              \n>>> Retención mensual de backups                → ${CFG[RetencionMeses]} meses" \
              ">>> The current parameters set for the backup are: \
              \n>>> Folder where the backup is saved            → ${CFG[RutaBackups]} \
              \n>>> Automatically update openmediavault         → $(TraducirSiNo "${CFG[ActualizarOMV]}") \
              \n>>> Silent mode option activated                → $(TraducirSiNo "${CFG[ModoSilencio]}") \
              \n>>> Skip /root folder in backup                 → $(TraducirSiNo "${CFG[OmitirRoot]}") \
              \n>>> Automatically update omv-regen              → $(TraducirSiNo "${CFG[ActualizarOmvregen]}") \
              \n>>> Daily backup retention                      → ${CFG[RetencionDias]} days \
              \n>>> Weekly backup retention                     → ${CFG[RetencionSemanas]} weeks \
              \n>>> Monthly backup retention                    → ${CFG[RetencionMeses]} months"
    if [ "${#CARPETAS_ADICIONALES[@]}" = 0 ]; then
        echoe sil ">>> Carpetas opcionales a incluir en el backup  → Ninguna" \
                  ">>> Optional folders to include in the backup   → None"
    else
        cont=0
        for carpeta in "${CARPETAS_ADICIONALES[@]}"; do
            ((cont++))
            if [ -d "$carpeta" ]; then
                echoe sil ">>> Carpeta opcional $cont a incluir en el backup   → $carpeta " \
                          ">>> Optional folder $cont to include in the backup  → $carpeta "
            else
                echoe sil ">>> Carpeta opcional $cont a incluir en el backup   → $carpeta \n>>>                         No existe y no se incluirá" \
                          ">>> Optional folder $cont to include in the backup  → $carpeta \n>>>       Does not exist and will not be included"
            fi
        done
    fi
    echoe sil "\n"

    if [ "${CFG[ActualizarOMV]}" = "Si" ]; then
        if [ -f "/var/run/reboot-required" ]; then
            error "Hay un reinicio pendiente, no se puede actualizar el sistema. Se hará el backup y luego se reiniciará." \
                  "A reboot is pending, the system cannot be updated. The backup will be made and then it will restart."
        else
            echoe sil ">>> Actualizando el sistema ..." \
                      ">>> Updating the system ..."
            ActualizarOMV || { error "Fallo actualizando el sistema. Abortando ... ${txt[error]}" \
                                     "Failed updating system. Aborting ... ${txt[error]}"; return 1; }
            echoe ">>> Se ha actualizado OMV con éxito." \
                  ">>> OMV has been updated successfully."
        fi
    fi

    echoe sil ">>> Verificando estado de instalación de openmediavault ..." \
              ">>> Checking openmediavault installation status ..."
    estado_correcto_omv || { error "Hay un paquete de OMV en mal estado. Corrige el problema antes de hacer un backup. Abortando ... ${txt[error]}" \
                                   "There is an OMV package in bad condition. Fix the problem before making a backup. Aborting ... ${txt[error]}"; return 1; }

    ActualizarRepo || { error "No se pudo actualizar el repositorio. ${txt[error]}" \
                              "Could not update repository. ${txt[error]}"; return 1; }
    
    echoe sil ">>> Copiando el repositorio a $dir_regen ..." \
              ">>> Copying the repository to $dir_regen ..."
    mkdir -p "${dir_regen}${OR_dir}/repo" | _orl sil
    rsync -a ${OR_dir}/repo/ "${dir_regen}${OR_dir}/repo" | _orl sil || {
        error "Fallo al sincronizar el repositorio. Abortando ..." \
              "Failed to sync repository. Aborting ..."; return 1; }

    echoe sil ">>> Recopilando información del sistema para la regeneración ..." \
              ">>> Gathering system information for regeneration ..."
    {
        echo "# Información para la regeneración"
        echo "# Information for regeneration"
        echo -e "# $(date '+%Y-%m-%d %H:%M:%S')\n"

        echo "[dpkg openmediavault]"
        dpkg -l | awk '/openmediavault/ && $1 ~ /^(hi|ii)/ {print $2, $3}'

        echo -e "\n[hostname]"
        hostname -I | awk '{print $1}'

        echo -e "\n[Kernel proxmox]"
        if [[ "$(uname -r)" == *pve ]]; then
            awk -F "." '{print $1"."$2}' <<< "$(uname -r)"
        else
            echo "no_proxmox"
        fi

        echo -e "\n[ZFS]"
        if dpkg -l | grep -q openmediavault-zfs; then
            z="$(zpool list -H | awk '$0 ~ /ONLINE/ {print $1}')"
            if [ -n "$z" ]; then
                echo "$z"
            else
                echo "no_zfs"
            fi
        else
            echo "no_zfs"
        fi

        echo -e "\n[Fecha]"
        echo "$marca_fecha" 

        echo -e "\n[dpkg completo]"
        dpkg -l | awk '/^ii/ {print $2" "$3}'

    } > "$OR_RegenInfo_file"

    echoe sil ">>> Copiando archivos esenciales a ${dir_regen} ..." \
              ">>> Copying essential files to ${dir_regen} ..."
    for archivo in "${ARCHIVOS_BACKUP[@]}"; do
        [ ! -d "$(dirname "${dir_regen}${archivo}")" ] && mkdir -p "$(dirname "${dir_regen}${archivo}")" | _orl sil
        cp -ap "$archivo" "${dir_regen}${archivo}" | _orl sil \
            || { error "Fallo copiando el archivo $archivo" \
                       "Failed to copy file $archivo"; return 1; }
    done
    rm -f "$OR_RegenInfo_file"
    xmlstarlet fo "$Config_xml_file" | tee "${dir_regen}${Config_xml_file}" >/dev/null
    xmlstarlet val "${dir_regen}${Config_xml_file}" >/dev/null \
        || { error "La base de datos de openmediavault es inutilizable. Abortando ..." \
                   "openmediavault database is unusable. Aborting ..."; return 1; }

    if dpkg -l | grep -q openmediavault-kvm; then
        echoe sil ">>> openmediavault-kvm detectado, copiando carpetas /etc/libvirt y /var/lib/libvirt ..." \
                  ">>> openmediavault-kvm detected, copying /etc/libvirt and /var/lib/libvirt folders ..."
        rsync -a /etc/libvirt "${dir_regen}/etc/" | _orl sil || return 1
        rsync -a /var/lib/libvirt "${dir_regen}/var/lib/" | _orl sil || return 1
    fi

    if [ -f "/etc/crypttab" ]; then
        echoe sil ">>> LUKS detectado, copiando información para la regeneración ..." \
                  ">>> LUKS detected, copying information for regeneration ..."
        cp -ap "/etc/crypttab" "${dir_regen}/etc/crypttab" | _orl sil \
            || { error "Fallo copiando /etc/crypttab." \
                       "Failed to copy /etc/crypttab."; return 1; }
        if [ -s "/etc/crypttab" ]; then
            awk 'NR>1{print $3}' /etc/crypttab | while IFS= read -r clave; do
                ruta_destino="${dir_regen}${clave}"
                [ ! -d "$(dirname "$ruta_destino")" ] && mkdir -p "$(dirname "$ruta_destino")" | _orl sil || return 1
                if [ -f "$clave" ]; then
                    cp -ap "$clave" "$ruta_destino" | _orl sil \
                        || { error "No se pudo copiar $clave." \
                                   "Failed to copy $clave."; return 1; }
                fi
            done
        fi
    fi

    if [ "${CFG[OmitirRoot]}" = "No" ]; then
        echoe sil ">>> Copiando carpeta /root a $dir_regen ..." \
                  ">>> Copying /root folder to $dir_regen ..."
        rsync -a /root/ "${dir_regen}/root" --exclude '**/*.deb' | _orl sil || return 1
    else
        echoe sil ">>> AVISO: La carpeta /root no está incluida en el backup. Omitir /root puede provocar resultados inesperados al regenerar." \
                  ">>> WARNING: The /root folder is not included in the backup. Omitting /root may cause unexpected results when regenerating."
    fi 

    echoe sil ">>> Empaquetando directorio $basename_regen en ${CFG[RutaBackups]}/ORBackup_${marca_fecha}_regen.tar.gz ..." \
              ">>> Packaging $basename_regen directory in ${CFG[RutaBackups]}/ORBackup_${marca_fecha}_regen.tar.gz ..."
    tar --warning=no-file-ignored -czf "${CFG[RutaBackups]}/ORBackup_${marca_fecha}_regen.tar.gz" -C "${CFG[RutaBackups]}" "$basename_regen" | _orl sil || {
        rm -f "${CFG[RutaBackups]}/ORBackup_${marca_fecha}_regen.tar.gz"
        error "Fallo empaquetando el archivo. Abortando ..." \
              "Failed to package the file. Aborting ..."; return 1; }
    rm -rf "$dir_regen"
    echoe ">>> ${CFG[RutaBackups]}/ORBackup_${marca_fecha}_regen.tar.gz → Backup creado." \
          ">>> ${CFG[RutaBackups]}/ORBackup_${marca_fecha}_regen.tar.gz → Backup created."

    echoe sil ">>> Generando checksum para 'ORBackup_${marca_fecha}_regen.tar.gz' ..." \
              ">>> Generating checksum for 'ORBackup_${marca_fecha}_regen.tar.gz' ..."
    sha256sum "${CFG[RutaBackups]}/ORBackup_${marca_fecha}_regen.tar.gz" | awk '{print $1}' > "${CFG[RutaBackups]}/ORBackup_${marca_fecha}_regen.sha256" || {
        error "No se pudo generar el checksum." \
              "The checksum could not be generated."; return 1; }
    echoe sil ">>> Validando checksum para 'ORBackup_${marca_fecha}_regen.tar.gz' ..." \
              ">>> Validating checksum for 'ORBackup_${marca_fecha}_regen.tar.gz' ..."
    ValidarChecksum "${CFG[RutaBackups]}/ORBackup_${marca_fecha}_regen.tar.gz" || {
        rm -f "${CFG[RutaBackups]}/ORBackup_${marca_fecha}_"*
        error "No se ha podido validar el checksum del backup creado." \
              "The checksum of the backup created could not be validated."; return 1; }
    echoe ">>> ${CFG[RutaBackups]}/ORBackup_${marca_fecha}_regen.sha256 → Cheksum creado y validado." \
          ">>> ${CFG[RutaBackups]}/ORBackup_${marca_fecha}_regen.sha256 → Checksum created and validated."
    
    if [ "${#CARPETAS_ADICIONALES[@]}" -eq 0 ]; then
        echoe sil ">>> No se han configurado carpetas opcionales en los ajustes del backup." \
                  ">>> No optional folders set in backup settings.\n"
    else
        echoe sil ">>> Copiando carpetas opcionales ..." \
                  ">>> Copying optional folders ..."
        local n=1
        for carpeta in "${CARPETAS_ADICIONALES[@]}"; do
            if [ -d "$carpeta" ]; then
                echoe sil ">>> Empaquetando directorio $carpeta en ${CFG[RutaBackups]}/ORBackup_${marca_fecha}_user${n}.tar.gz ..." \
                          ">>> Packaging $carpeta directory in ${CFG[RutaBackups]}/ORBackup_${marca_fecha}_user${n}.tar.gz ..."
                tar --warning=no-file-ignored -czf "${CFG[RutaBackups]}/ORBackup_${marca_fecha}_user${n}.tar.gz" -C / "${carpeta:1}" | _orl sil || {
                    rm -f "${CFG[RutaBackups]}/ORBackup_${marca_fecha}_"*
                    error "Fallo empaquetando el archivo. Abortando ..." \
                          "Failed to package the file. Aborting ..."; return 1; }
                echoe ">>> ${CFG[RutaBackups]}/ORBackup_${marca_fecha}_user${n}.tar.gz → Carpeta adicional $carpeta añadida al backup." \
                      ">>> ${CFG[RutaBackups]}/ORBackup_${marca_fecha}_user${n}.tar.gz → Additional folder $carpeta added to backup."
                ((n++))
            else
                echoe sil ">>> AVISO: La carpeta adicional $carpeta no existe, se ignora." \
                          ">>> WARNING: Additional folder $carpeta does not exist, it is ignored."
            fi
        done
    fi

    echoe sil ">>> Actualizando el almacén de backups ..." \
              ">>> Updating the backup store ..."
    find "${CFG[RutaBackups]}" -name "ORBackup_${marca_fecha}_*" | while IFS= read -r archivo; do
        nuevo_nombre="$(awk -F "_" '{print $1"_"$2"_"$3"_d_s_m_"$4}' <<< "$(basename "$archivo")")"
        mv "$archivo" "${CFG[RutaBackups]}/${nuevo_nombre}"
    done
    GestionarBackups || { error "No se pudo actualizar el almacén de backups." \
                                "The backup store could not be updated."; return 1; }

    echoe sil ">>> Validando backup creado ..." \
              ">>> Validating created backup ..."
    ValidarContenidoBackup "${CFG[RutaBackups]}/ORBackup_${marca_fecha}_d_s_m_regen.tar.gz" || {
        rm -f "${CFG[RutaBackups]}/ORBackup_${marca_fecha}_"*
        [ -n "$PaquetesFaltantesBackup" ] && error "Faltan paquetes en el backup: $PaquetesFaltantesBackup  ${txt[error]}" \
                                                   "Missing packages in the backup: $PaquetesFaltantesBackup  ${txt[error]}"
        error "No se ha podido validar el backup creado. El error es: $ErrorValBackup  ${txt[error]}" \
              "The backup created could not be validated. The error is: $ErrorValBackup  ${txt[error]}"; return 1; }
    echoe sil ">>> Relación de backups actualmente guardados:" \
              ">>> List of currently saved backups:"
    find "${CFG[RutaBackups]}" -maxdepth 1 -type f -name "ORBackup_*" | awk -F "/" '{print $NF}' | sort | _orl sil

    echoe "\n>>>\n>>>>>>       <<< ¡Copia de seguridad de $hoy completada! >>>\n>>>\n" \
          "\n>>>\n>>>>>>       <<< $hoy backup completed! >>>\n>>>\n"
    if [ "${CFG[ActualizarOMV]}" = "Si" ]; then
        EjecutarReinicioPendiente || return 1
    fi
    backup_desatendido && BuscarOR && echoe sil ">>>"

    return 0
}

######################################### FUNCIONES DE REGENERA #########################################
########################################## REGENERA FUNCTIONS ###########################################

# Validar ajustes de Regenera. Devuelve ErrorValRegen=0 si todo es correcto y ErrorValRegen="[FALLO...]" si falla
# Validate Regenera settings. Returns ErrorValRegen=0 if everything is correct and ErrorValRegen="[FAIL...]" if it fails.
Regenera_es_Valido() {
    local tar_regen_fecha
    ErrorValRegen=""; InfoValRegen=""; TarRegenFile=""

    # Comprobar si el sistema es de 32 bits
    # Check if the system is 32-bit
    if [ "$(dpkg --print-architecture)" = "armhf" ]; then
        ErrorValRegen="$ErrorValRegen sistema_32bits "
        error log "El sistema actual es de 32 bits. No se puede regenerar." \
                  "The current system is 32 bits. It cannot be regenerated."
        return 1
    fi

    # Comprobar si el backup de la regeneracion en progreso está en la ruta definida
    # Check if the rebuild backup in progress is on the defined path
    if regen_en_progreso; then
        if [ -f "${CFG[RutaTarRegenera]}" ]; then
            TarRegenFile="${CFG[RutaTarRegenera]}"
        else
            error log "Archivo de backup en curso no encontrado: ${CFG[RutaTarRegenera]}" \
                      "Current backup file not found: ${CFG[RutaTarRegenera]}"
            tar_regen_fecha="$(awk -F "_" 'NR==1{print $2"_"$3}' <<< "$(basename "${CFG[RutaTarRegenera]}")")"
            TarRegenFile="$(find "${CFG[RutaBackups]}" -type f -name "ORBackup_${tar_regen_fecha}*_regen.tar.gz")"
            if [ -z "$TarRegenFile" ]; then
                error log "Archivo de backup en curso no encontrado en ruta de backups: ${CFG[RutaBackups]}" \
                          "Backup file in progress not found in backup path: ${CFG[RutaBackups]}"
                ErrorValRegen="$ErrorValRegen archivo_regen_en_progreso "
            fi
        fi
    else
        # Buscar el backup mas reciente en la ruta definida
        # Find the most recent backup in the defined path
        TarRegenFile="$(find "${CFG[RutaBackups]}" -type f -name 'ORBackup_*_regen.tar.gz' | sort -r | awk 'NR==1{print $0}')"
        if [ -z "$TarRegenFile" ]; then
            ErrorValRegen="$ErrorValRegen ruta_origen_vacia "
            error log "Archivo de backup no encontrado en ${CFG[RutaBackups]}" \
                      "Backup file not found in ${CFG[RutaBackups]}"
        elif [[ ! "$(basename "$TarRegenFile")" =~ ^ORBackup_[0-9]{6}_[0-9]{6}(_[a-z_]+)?_regen\.tar\.gz$ ]]; then
            ErrorValRegen="$ErrorValRegen formato_nombre_archivo "
            error log "Formato de nombre de archivo de backup incorrecto: $(basename "$TarRegenFile")" \
                      "Incorrect backup file name format: $(basename "$TarRegenFile")"
        fi
    fi

    # Validar contenido del backup si se ha encontrado
    # Validate backup content if it has been found
    if [ -z "$ErrorValRegen" ]; then
        ValidarChecksum "$TarRegenFile" || {
            InfoValRegen="$InfoValRegen checksum_no_validado "
            error log "Checksum no validado." \
                      "Checksum not validated."
        }
        ValidarContenidoBackup "$TarRegenFile"
        if [ -n "$ErrorValBackup" ]; then
            ErrorValRegen="$ErrorValRegen contenido_incompleto "
            PaquetesFaltantesBackup=""
            error log "No se pudo validar el contenido del backup: $TarRegenFile" \
                      "Could not validate backup content: $TarRegenFile"
        else
            # Comprobar compatibilidad de la CPU con KVM y ZFS
            # Check CPU compatibility with KVM and ZFS
            if ! grep -qE 'vmx|svm' /proc/cpuinfo && [ "$(estado_original_de "openmediavault-kvm")" = "instalado" ];then
                InfoValRegen="$InfoValRegen CPU_incompatible_KVM "
                echoe log ">>> INFO: La CPU es incompatible con KVM." \
                          ">>> INFO: The CPU is incompatible with KVM."
            fi
            # Validar compatibilidad de ZFS según la arquitectura
            # Validate ZFS support based on architecture
            if ! uname -m | grep -qE 'x86_64|amd64' && [ "$(estado_original_de "openmediavault-zfs")" = "instalado" ]; then
                ErrorValRegen="$ErrorValRegen ARM_incompatible_ZFS "
                error log "La arquitectura del sistema actual ARM. OMV no admite ZFS en esta arquitectura." \
                          "The current ARM system architecture. OMV does not support ZFS on this architecture."
            fi
        fi
    fi

    # Comprobar usuarios en el sistema actual
    # Check users in the current system
    if ! regen_en_progreso && (( $(awk -F: '$3>=1000 && $3<65534 {c++} END{print c}' /etc/passwd) > 1 )); then
        ErrorValRegen="$ErrorValRegen usuarios_locales "
        error log "Este sistema tiene varios usuarios locales. No es un sistema limpio." \
                  "This system has multiple local users. Not a clean system."
    fi

    if omv_instalado; then
        # Comprobar si la versión de OMV instalada es superior a la original
        # Check if the installed OMV version is higher than the original one
        if dpkg --compare-versions "$(version_instalada_de openmediavault)" gt "$(version_original_de openmediavault)"; then
            ErrorValRegen="$ErrorValRegen version_superior_OMV "
            error log "La versión instalada de OMV es superior a la versión de OMV del sistema original." \
                      "The installed version of OMV is higher than the OMV version of the original system."
        fi
        # Comprobar el estado de instalación de OMV
        # Check OMV installation status
        if ! estado_correcto_omv; then
            ErrorValRegen="$ErrorValRegen mal_estado_OMV "
            error log "Uno o varios paquetes de OMV están en malas condiciones de instalación." \
                      "One or more OMV packages are in poor installation conditions."
        fi
        if ! regen_en_progreso; then
            # Comprobar estado del sistema actual
            # Check current system status
            if { [[ "$(dpkg -l | grep -c  openmediavault)" -gt 2 ]] && ! dpkg -l | grep -q omvextrasorg; } \
                || [[ "$(dpkg -l | grep -c  openmediavault)" -gt 4 ]]; then
                ErrorValRegen="$ErrorValRegen sistema_configurado "
                error log "Se han detectado complementos instalados previamente a la regeneración." \
                          "Plug-ins installed prior to the regeneration have been detected."
            fi
            valor=$(xmlstarlet select --template --value-of "/config/system/shares/sharedfolder/name" "$Config_xml_file")
            if [ -n "$valor" ]; then
                ErrorValRegen="$ErrorValRegen sistema_configurado "
                error log "Se han detectado configuraciones en la GUI de OMV previamente a la regeneración." \
                          "Configurations have been detected in the OMV GUI prior to regeneration."
            fi
        fi
    fi

    if [ -n "$ErrorValRegen" ]; then
        return 1
    fi
    return 0
}

# Validar checksum del backup
# Validate backup checksum
ValidarChecksum() {
    local tar_regen_file="$1"
    local checksum_file="${tar_regen_file%tar.gz}sha256"
    [ ! -f "$tar_regen_file" ] && error "Archivo TAR no encontrado: $tar_regen_file." \
                                        "TAR file not found: $tar_regen_file." && exit 1

    if [ ! -f "$checksum_file" ]; then
        error log "No se ha encontrado el archivo de checksum: $checksum_file" \
                  "The checksum file could not be found: $checksum_file"
        return 1
    elif ! grep -q "$(sha256sum "$tar_regen_file" | awk '{print $1}')" "$checksum_file"; then
        error log "Checksum no coincidente." \
                  "Checksum not matching."
        return 1
    fi
    return 0
}

# Comprobación del contenido del backup
# Checking the backup content
ValidarContenidoBackup() {
    local tar_regen_file="$1" tar_regen_fecha temp_dir carpeta_regen archivos_en_backup archivo nombre version nombre_version
    PaquetesFaltantesBackup=""; ErrorValBackup=""

    tar_regen_fecha="$(awk -F "_" 'NR==1{print $2"_"$3}' <<< "$(basename "$tar_regen_file")")"
    temp_dir="${OR_tmp_dir}/validar_contenido"
    carpeta_regen="regen_$tar_regen_fecha"
    mkdir -p "$temp_dir"

    # Comprobar si el backup contiene todos los archivos necesarios
    # Check if the backup contains all the necessary files
    archivos_en_backup="$(tar -tzf "$tar_regen_file")"
    for archivo in "${ARCHIVOS_BACKUP[@]}"; do
        if grep -q "$archivo" <<< "$archivos_en_backup"; then
            continue
        fi
        ErrorValBackup=" contenido_incompleto "
        error log "Contenido incompleto en el backup. Falta el archivo: $archivo" \
                  "Incomplete content in backup. Missing file: $archivo"
        break
    done

    # Leer archivo info si no hay errores de contenido
    # If all the files are there, read the info file
    if [ -z "$ErrorValBackup" ]; then
        if tar -C "$temp_dir" -xzf "$tar_regen_file" "${carpeta_regen}${OR_RegenInfo_file}" >/dev/null; then
            if [ -f "${temp_dir}/${carpeta_regen}${OR_RegenInfo_file}" ]; then
                LeerRegenInfoFile "${temp_dir}/${carpeta_regen}${OR_RegenInfo_file}" || {
                    ErrorValBackup="$ErrorValBackup error_lectura_RegenInfo_file "
                    error log "Fallo leyendo el archivo regen_info ${txt[error]}" \
                              "Failed to read regen_info file ${txt[error]}"
                }
                if [ -n "${VERSION_ORIGINAL[openmediavault]}" ]; then
                    # Validar fecha en el nombre del archivo regen
                    # Check date in regen file name
                    if [ "$FechaInfo" != "$tar_regen_fecha" ]; then
                        ErrorValBackup="$ErrorValBackup fecha_info_incorrecta "
                        error log "La fecha en el archivo 'OR_RegenInfo_file': $FechaInfo no conicide con el nombre del archivo: $tar_regen_fecha" \
                                  "The date in the file 'OR_RegenInfo_file': $FechaInfo does not match the file name: $tar_regen_fecha"
                    fi
                    # Validar versiones de OMV y complementos
                    # Check OMV versions and plugins
                    for nombre in "${!VERSION_ORIGINAL[@]}"; do
                        nombre_version="${nombre}_${VERSION_ORIGINAL[$nombre]}"
                        if ! grep -qE "(^|/)$nombre_version(_[a-z0-9]+)?\.deb$" <<< "$archivos_en_backup"; then
                            PaquetesFaltantesBackup="$PaquetesFaltantesBackup $nombre_version "
                            error log "Paquete faltante en el backup: $nombre_version" \
                                      "Missing package in backup: $nombre_version"
                        fi
                    done
                    [ -n "$PaquetesFaltantesBackup" ] && ErrorValBackup="$ErrorValBackup faltan_paquetes "
                else
                    ErrorValBackup="$ErrorValBackup error_lectura_RegenInfo_file "
                    error log "Fallo leyendo el archivo 'OR_RegenInfo_file': ${temp_dir}/${carpeta_regen}${OR_RegenInfo_file}" \
                              "Failure reading file 'OR_RegenInfo_file': ${temp_dir}/${carpeta_regen}${OR_RegenInfo_file}"
                fi
            else
                error log "Archivo no encontrado después de la extracción: ${temp_dir}/${carpeta_regen}${OR_RegenInfo_file}" \
                          "File not found after extraction: ${temp_dir}/${carpeta_regen}${OR_RegenInfo_file}"
            fi
        else
            ErrorValBackup="$ErrorValBackup error_descomprimir_tar "
            error log "Fallo descomprimiendo el backup: $tar_regen_file" \
                      "Failed to decompress backup: $tar_regen_file"
        fi
    fi

    rm -rf "$temp_dir"
    [ -n "$ErrorValBackup" ] && return 1
    return 0
}

# Lee el archivo 'OR_RegenInfo_file' creado en el backup con información del sistema original. $1="/ruta/a/OR_RegenInfo_file"
# Read the 'OR_RegenInfo_file' file created in the backup with information from the original system. $1="/path/to/OR_RegenInfo_file"
LeerRegenInfoFile() {
    local archivo="$1" linea nombre version seccion=""

    [[ ! -f "$archivo" ]] && { error "No se encontró el archivo '$archivo'." \
                                     "File '$archivo' not found."; return 1; }

    while IFS= read -r linea; do
        # Saltar líneas vacías y comentarios
        # Skip empty lines and comments
        [[ -z "$linea" || "$linea" =~ ^# ]] && continue

        # Detectar secciones
        # Detect sections
        if [[ "$linea" =~ ^\[.*\]$ ]]; then
            seccion="${linea//[\[\]]/}"
            continue
        fi

        # Procesar datos según la sección
        # Process data according to section
        case "$seccion" in
        "dpkg openmediavault")
            read -r nombre version <<< "$linea"
            [[ -z "$nombre" || -z "$version" ]] && { error "Paquete o versión vacíos en la sección dpkg." \
                                                           "Empty package or version in dpkg section."; return 1; }
            VERSION_ORIGINAL[$nombre]="$version"
            ;;
        "hostname")
            [[ ! "$linea" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && { error "IP inválida '$linea' en la sección hostname." \
                                                                         "Invalid IP '$linea' in hostname section."; return 1; }
            IPOriginal="$linea"
            ;;
        "Kernel proxmox")
            [[ "$linea" != "no_proxmox" && ! "$linea" =~ ^[0-9]+\.[0-9]+$ ]] && { error "Versión de kernel inválida '$linea'." \
                                                                                        "Invalid kernel version '$linea'."; return 1; }
            KernelOriginal="$linea"
            [ "$KernelOriginal" = "no_proxmox" ] && KernelOriginal=0
            ;;
        "ZFS")
            if [[ "$linea" == "no_zfs" ]]; then
                OriginalZFS+=("$linea")
            else
                [[ ! "$linea" =~ ^[a-zA-Z0-9_-]+$ ]] && { error "No se detectaron zpools válidos en la sección ZFS." \
                                                                "No valid zpools detected in ZFS section."; return 1; }
                OriginalZFS+=("$linea")
            fi
            ;;
        "Fecha")
            [[ ! "$linea" =~ ^[0-9]{2}[0-1][0-9][0-3][0-9]_[0-2][0-9][0-5][0-9][0-5][0-9]$ ]] && { \
                error "Formato de fecha no válido '$linea'. Formato esperado: YYMMDD_HHMMSS." \
                      "Invalid date format '$linea'. Expected format: YYMMDD_HHMMSS."; return 1; }
            FechaInfo=$linea
            ;;
        "dpkg completo")
            ;;
        *)
            alerta "Sección desconocida '$seccion' en línea '$linea'. Ignorando." \
                   "Unknown section '$seccion' in line '$linea'. Ignoring."
            ;;
        esac
    done < "$archivo"

    [ -z "${VERSION_ORIGINAL[openmediavault]}" ] && { error "El archivo Info está incompleto." \
                                                            "The Info file is incomplete."; return 1; }
    return 0
}

# Si un complemento no estaba instalado en el sistema original, VERSION_ORIGINAL no tendrá la clave correspondiente.
# En ese caso, devolvemos "no_instalado" como valor por defecto.
# If a plugin was not installed on the original system, VERSION_ORIGINAL will not contain the corresponding key.
# In that case, we return "no_instalado" as the default value.
version_original_de() {
    local nombre_paquete=$1
    # Si el complemento openmediavault no está presente, significa que el archivo de regeneración no se cargó correctamente.
    # If the openmediavault plugin is not present, it means the regeneration file was not loaded correctly.
    [ "${VERSION_ORIGINAL[openmediavault]}" = "" ] && \
        error "El array 'VERSION_ORIGINAL' está vacío." \
              "The 'VERSION_ORIGINAL' array is empty." && exit 1
    echo "${VERSION_ORIGINAL[$nombre_paquete]:-"no_instalado"}"
}

estado_original_de() {
    local nombre_paquete=$1 estado_original
    if [[ "$(version_original_de "$nombre_paquete")" == "no_instalado" ]]; then
        estado_original="no_instalado"
    else
        estado_original="instalado"
    fi
    echo "$estado_original"
}

version_cache_local_de() {
    local nombre_paquete=$1 version_repo_regen
    version_repo_regen="$(find "/var/cache/apt/archives" -maxdepth 1 -name "${nombre_paquete}_*.deb" | awk -F "_" '{print $2}' | sort -V | tail -n1)"
    [ -z "$version_repo_regen" ] && version_repo_regen=0
    echo "$version_repo_regen"
}

version_repo_regen_de() {
    local nombre_paquete=$1 version_repo_regen
    version_repo_regen="$(find "$OR_repo_dir" -maxdepth 1 -name "${nombre_paquete}_*.deb" | awk -F "_" '{print $2}' | sort -V | tail -n1)"
    [ -z "$version_repo_regen" ] && version_repo_regen=0
    echo "$version_repo_regen"
}

version_repo_web_de() {
    local nombre_paquete=$1 version_repo_web
    version_repo_web=$(apt-cache madison "$nombre_paquete" 2>/dev/null | awk '{print $3}' | head -n1)
    [ -z "$version_repo_web" ] && error "No se encontró versión en el repositorio web para el paquete: $nombre_paquete" \
                                        "No version found in web repo for package: $nombre_paquete" && exit 1
    echo "$version_repo_web"
}

version_disponible_de() {
    local nombre_paquete=$1 version_disponible
    version_disponible="$(find "$OR_repo_dir" -maxdepth 1 -name "${nombre_paquete}_*.deb" | awk -F "_" '{print $2}' | sort -V | tail -n1)"
    [ -z "$version_disponible" ] && version_disponible=$(apt-cache madison "$nombre_paquete" 2>/dev/null | awk '{print $3}' | head -n1)
    [ -z "$version_disponible" ] && error "No se encontró versión en el repositorio web para el paquete: $nombre_paquete" \
                                          "No version found in web repo for package: $nombre_paquete" && exit 1
    echo "$version_disponible"
}

version_instalada_de() {
    local nombre_paquete=$1 version_instalada
    version_instalada="$(dpkg-query --show -f='${Version}\n' "$nombre_paquete" 2>/dev/null)"
    [ -z "$version_instalada" ] && version_instalada=0
    echo "$version_instalada"
}

estado_actual_de() {
    local nombre_paquete=$1 estado_actual
    estado_actual=$(dpkg -l | awk -v pkg="$nombre_paquete" '$2 == pkg { print $1 }')
    if [ -z "$estado_actual" ]; then
        estado_actual="no_instalado"
    else
        case $estado_actual in
            hi)             estado_actual="retenido" ;;
            ii)             estado_actual="instalado" ;;
            rc|un|rn|pu)    estado_actual="no_instalado" ;;
            iU|iF|U|C)      estado_actual="incompleto"
                                error "Estado incompleto para el paquete '$nombre_paquete' ($estado_actual)." \
                                      "Incomplete state for package '$nombre_paquete' ($estado_actual)."
                                return 1 ;;
            *)              estado_actual="desconocido"
                                error "Estado desconocido para el paquete '$nombre_paquete' ($estado_actual)." \
                                      "Unknown state for package '$nombre_paquete' ($estado_actual)."
                                return 1 ;;
        esac
    fi
    
    echo "$estado_actual"
}

# Localizar paquete coincidente con version original para instalar
# Find a matching package with the original version to install
LocalizarPaqueteVO() {
    local paquete="$1" version
    version="$(version_original_de "$paquete")"

    [ -z "$paquete" ] && { error "Argumento vacío: 'paquete'" "Empty argument: 'paquete'"; return 1; }

    if [ "$(version_cache_local_de "$paquete")" = "$version" ]; then
        echoe ">>> El paquete $paquete versión $version está disponible en la caché local." \
              ">>> Package $paquete version $version is available in the local cache."
        return 0
    fi

    if [ "$(version_repo_regen_de "$paquete")" = "$version" ]; then
        echoe ">>> El paquete $paquete versión $version está disponible en el repositorio de omv-regen. Copiando ..." \
              ">>> Package $paquete version $version is available in the omv-regen repository. Copying ..."
        cp "${OR_repo_dir}/$paquete"* "/var/cache/apt/archives/"
        echoe ">>> Copiado $paquete de $OR_repo_dir a la caché local." \
              ">>> Copied $paquete from $OR_repo_dir to the local cache."
    return 0
    fi

    if apt-cache madison "$paquete" | grep -q "$version"; then
        echoe ">>> Descargando paquete $paquete versión $version desde los repositorios ..." \
              ">>> Downloading package $paquete version $version from repositories ..."
        if ! apt-get --yes --download-only install "$paquete=$version" | _orl; then
            error "No se pudo descargar $paquete versión $version desde los repositorios." \
                  "Failed to download $paquete version $version from repositories."
            return 1
        fi
        return 0
    fi
    
    Mensaje error "La versión $version de $paquete no está en los repositorios ni en la caché local." \
                  "Version $version of $paquete is not in repositories or local cache."
    return 1
}

# Marcar retencion de version de paquete instalado
# Check retention of installed package version
MarcarRetencion() {
    local paquete="$1" version_original version_instalada estado_actual

    [ -z "$paquete" ] && { error "Argumento vacío: 'paquete'" "Empty argument: 'paquete'"; return 1; }

    version_original="$(version_original_de "$paquete")"
    version_instalada="$(version_instalada_de "$paquete")"
    estado_actual="$(estado_actual_de "$paquete")"

    if [[ "$estado_actual" == "instalado" || "$estado_actual" == "retenido" ]]; then
        if [[ "$version_original" == "$version_instalada" ]]; then
            if [[ "$estado_actual" == "instalado" ]]; then
                echoe ">>> Marcando retención de $paquete versión $version_original ..." \
                      ">>> Marking retention of $paquete version $version_original ..."
                apt-mark hold "$paquete" | _orl
            fi
        else
            error "El paquete '$paquete' tiene instalada la versión $version_instalada, pero el backup indica $version_original." \
                  "Package '$paquete' has version $version_instalada installed, but backup indicates $version_original."
            return 1
        fi
    fi

    return 0
}

# Instalar y retener la version del sistema original de un paquete
# Install and retain the original system version of a package
InstalarRetenerVO() {
    local paquete="$1" version
    version="$(version_original_de "$paquete")"

    ReiniciarSiRequerido || return 1

    if [ "$(estado_original_de "$paquete")" = "no_instalado" ]; then
        echoe "\n>>> $paquete no estaba instalado en el sistema original; será omitido." \
              "\n>>> $paquete was not installed on the original system; it will be skipped."
        return 0
    else
        echoe "\n>>> Instalando $paquete ..." \
              "\n>>> Installing $paquete ..."
    fi

    if [ "$(estado_actual_de "$paquete")" = "no_instalado" ]; then
        LocalizarPaqueteVO "$paquete" || { error "La version $version del paquete $paquete no está disponible." \
                                                 "The version $version of package $paquete is not available."; return 1; }
        echoe ">>> Instalando $paquete versión $version ..." \
              ">>> Installing $paquete version $version ..."
        apt-get --yes install "${paquete}=${version}" | _orl
        if [[ "$(estado_actual_de "$paquete")" != "instalado" ]]; then
            apt-get --yes --fix-broken install | _orl
            apt-get update | _orl
            if ! apt-get --yes install "${paquete}=${version}" | _orl; then
                if ! apt-get --yes --fix-broken install | _orl; then
                    Mensaje error "No se pudo instalar $paquete versión $version " \
                                  "Failed to install $paquete version $version "
                    return 1
                fi
            fi
        fi
        echoe ">>> $paquete versión $version se ha instalado correctamente." \
              ">>> $paquete version $version has been installed successfully."
        MarcarRetencion "$paquete" || { error "${txt[error]}"; return 1; }
    else
        echoe ">>> $paquete versión $version ya estaba instalado en este sistema." \
              ">>> $paquete version $version was already installed on this system."
    fi

    return 0
}

# Habilitar/Deshabilitar backports en OMV 7
# Enable/Disable backports in OMV 7
# $1=YES/NO
Backports7() {
    local accion=$1
    local script_changebackports="/usr/sbin/omv-changebackports"

    [ -z "$accion" ] && { error "Argumento vacío: 'accion'" "Empty argument: 'accion'"; return 1; }
    [[ "$accion" != "YES" && "$accion" != "NO" ]] && { error "Argumento inválido: $accion" "Invalid argument: $accion"; return 1; }
    [ ! -f "$script_changebackports" ] &&  { error "No se encuentra el script: $script_changebackports " \
                                                   "Script not found: $script_changebackports "; return 1; }
    # shellcheck disable=SC1090
    ( . "$script_changebackports" "$accion" ) | _orl
    if [[ ${PIPESTATUS[0]} == 0 ]]; then
        [ "$accion" = "YES" ] && echoe ">>> Backports se ha habilitado con éxito." \
                                       ">>> Backports has been successfully enabled."
        [ "$accion" = "NO" ] && echoe ">>> Backports se ha deshabilitado con éxito." \
                                      ">>> Backports have been successfully disabled."
        ActualizarOMV || { error "${txt[error]}"; return 1; }
    else
        error "Fallo configurando Backports." \
              "Failed configuring Backports."; return 1
    fi

    return 0
}

# Leer valor y numero de repeticiones del valor en la base de datos. Devuelve 0 si hay algún valor, 1 en caso contrario
# Read value and number of repetitions of the value in the database. Returns 0 if there is a value, 1 otherwise
LeerValorBD() {
    local xpath="$1"
    ValorBD=""; NumValBD=""
    ValorBD="$(xmlstarlet select --template --value-of "$xpath" --nl "$Config_xml_file" 2>/dev/null)"
    NumValBD="$(grep -c . <<< "$ValorBD")"
    [[ "$NumValBD" -gt 0 ]]
}

# Actualizar los elementos en el XPath indicado en el archivo de configuración.
# Update the elements at the given XPath in the configuration file.
Config_Actualizar() {
	local tmpfile xpath=$1 valor=$2
	tmpfile=$(mktemp)

    if xmlstarlet edit -P -u "${xpath}" -v "${valor}" "${Config_xml_file}" | tee "${tmpfile}" >/dev/null; then
        cat "${tmpfile}" >"${Config_xml_file}"
        rm -f -- "${tmpfile}"
    else
        rm -f -- "${tmpfile}"
        error "Fallo actualizando el archivo de configuración (XPath: ${xpath})." \
              "Failed to update configuration file (XPath: ${xpath})."
        return 1
    fi
}

######################################## EJECUTAR REGENERA ###############################################
########################################## RUN REGENERA ##################################################

# Sustituye nodo de la base de datos actual por el existente en la base de datos original y marca cambios en salt
# El argumento de entrada debe ser una clave de la matriz CONFIG[]
# Replaces the current database node with the existing one in the original database and marks changes in salt modules
# The input argument must be a key of the CONFIG[] array
Regenera() {
    local clave="$1" nodo padre etiqueta nodo_ori="" nodo_act="" tar_regen_fecha
    local entrada="${CONFIG[$clave]}"
    tar_regen_fecha="$(awk -F "_" 'NR==1{print $2"_"$3}' <<< "$(basename "${CFG[RutaTarRegenera]}")")"
    local carpeta_regen="${OR_dir}/regen_$tar_regen_fecha"
    [ ! -d "$carpeta_regen" ] && { error "La carpeta no existe: $carpeta_regen" \
                                         "The folder does not exist: $carpeta_regen"; return 1; }
    [ -z "$entrada" ] && { error "No se encontró configuración para la clave '$clave'. Puede ser un nuevo complemento." \
                                 "No configuration found for key '$clave'. It may be a new plugin."; return 0; }
    # CONFIG[openmediavault-forkeddaapd]="/config/services/daap"
    nodo="${entrada%% *}"                     # → /config/services/daap
    padre="${nodo%/*}"                        # → /config/services
    etiqueta="${nodo##*/}"                    # → daap
    local conf_xml_copia="${Conf_tmp_file}.ori"
    local conf_xml_temp="$Conf_tmp_file"
    local conf_xml_backup="${carpeta_regen}${Config_xml_file}"
    
    if [ "$nodo" = "nulo" ]; then
        echoe "\n>>> No se requiere regenerar la base de datos para $clave \n" \
              "\n>>> No database regeneration required for $clave \n"
    else

        echoe "\n>>> Regenerando $nodo ...\n" \
              "\n>>> Regenerating $nodo ...\n" 
        local intentos=5
        while ((intentos > 0)); do
            echoe ">>> Formateando base de datos temporal ..." \
                  ">>> Formatting temporary database ..."
            [ ! -f "$conf_xml_copia" ] && cp -a "$Config_xml_file" "$conf_xml_copia"
            cat "$Config_xml_file" >"$conf_xml_copia"
            [ ! -f "$conf_xml_temp" ] && cp -a "$conf_xml_copia" "$conf_xml_temp"
            cat "$conf_xml_copia" >"$conf_xml_temp"
            # Esperar 1 segundos y comparar para evitar conflictos de escritura concurrentes
            # Wait 1 second and compare to avoid concurrent write conflicts
            sleep 1
            if diff -q "$Config_xml_file" "$conf_xml_temp" >/dev/null 2>&1; then
                echoe ">>> Archivo temporal generado con éxito." \
                      ">>> Temporary file generated successfully."
                break
            else
                alerta "El archivo de configuración original cambió. Reintentando ..." \
                       "The original configuration file changed. Retrying ..."
                rm -f "$conf_xml_temp" "$conf_xml_copia"
                ((intentos--))
            fi
        done
        [ $intentos -eq 0 ] && { error "No se pudo validar la base de datos tras varios intentos." \
                                       "Failed to validate the database after several attempts."; return 1; }

        echoe ">>> Leyendo valores de $nodo en la base de datos ..." \
              ">>> Reading $nodo values into the database ..."
        # Formatear antes de comparar nodos
        # Format before reading to compare nodes
        xmlstarlet fo "$conf_xml_temp" | tee "$Config_xml_file" >/dev/null \
            || { error "No se pudo formatear la base de datos." \
                       "Could not format database."
                 cat "${conf_xml_copia}" >"$Config_xml_file"
                 return 1; }
        nodo_ori="$(xmlstarlet select --template --copy-of "$nodo" --nl "$conf_xml_backup")"
        nodo_act="$(xmlstarlet select --template --copy-of "$nodo" --nl "$Config_xml_file")"
        if [ -z "$nodo_ori" ]; then
            echoe ">>> El nodo $nodo no existe en la base de datos original, no se requieren cambios." \
                  ">>> The $nodo node does not exist in the original database, no changes required."
        elif [ "$nodo_ori" = "$nodo_act" ]; then
            echoe ">>> El nodo $nodo es idéntico en ambas bases de datos, no se requieren cambios." \
                  ">>> Node $nodo is identical in both databases, no changes required."
        else

            echoe ">>> Eliminando nodo $nodo actual ..." \
                  ">>> Deleting current $nodo node ..."
            xmlstarlet edit -d "$nodo" "$Config_xml_file" > "$conf_xml_temp"
            echoe ">>> Copiando etiqueta $etiqueta original ..." \
                  ">>> Copying original $etiqueta tag ..."
            if [ ! "$(awk 'END{print $0}' "$conf_xml_temp" )" = "</config>" ]; then
                error "Hay un error en la base de datos, no se puede continuar." \
                      "There is an error in the database, cannot continue."
                cat "$conf_xml_copia" >"$Config_xml_file"
                return 1
            else
                sed -i '$d' "$conf_xml_temp"
                echo "${nodo_ori}</config>" >>"$conf_xml_temp"
                echoe ">>> Moviendo $etiqueta a $padre ..." \
                      ">>> Moving $etiqueta to $padre ..."
                xmlstarlet edit -m "/config/$etiqueta" "$padre" "$conf_xml_temp" | tee "$Config_xml_file" >/dev/null
            fi
            if xmlstarlet val "$Config_xml_file"; then
                echoe ">>> Nodo $nodo regenerado en la base de datos." \
                      ">>> $nodo node regenerated in the database."
                Salt=1
            else
                cat "$conf_xml_copia" >"$Config_xml_file"
                error "No se ha podido regenerar el nodo $nodo en la base de datos actual." \
                      "Failed to regenerate $nodo node in the current database."
                return 1
            fi
        fi
    fi

    return 0
}

# Aplica todos los modulos Salt si el testigo $Salt=1
# Applies all Salt modules if the token $Salt= 1
AplicarSalt() {

    echoe "\n>>> Comprobando configuraciones pendientes de aplicar con SaltStack ..." \
          "\n>>> Checking pending configurations to be applied with SaltStack ..."

    ReiniciarSiRequerido || return 1

    if [ $Salt -eq 1 ]; then
        echoe ">>> Borrando caché de SaltStack ..." \
              ">>> Clearing SaltStack cache ..."
        /usr/bin/salt-call --local saltutil.clear_cache >/dev/null
        echoe ">>> Preparando la configuración con SaltStack ..." \
              ">>> Preparing the configuration with SaltStack ..."
        omv-salt stage run prepare --quiet >/dev/null 2> >( _orl error ) || { 
            error "Fallo preparando configuración con SaltStack." \
                  "Failure preparing configuration with SaltStack."; return 1; }
        sleep 1
        echoe ">>> Aplicando los cambios de configuración con SaltStack (esto puede tardar un poco) ..." \
              ">>> Applying configuration changes with SaltStack (this may take a while) ..."
        omv-salt stage run deploy --quiet >/dev/null 2> >( _orl error ) || { 
            error "Fallo aplicando cambios con SaltStack." \
                  "Failure applying changes with SaltStack."; return 1; }
        LimpiarSalt || return 1
        Salt=0
    else
        echoe "\n>>> No hay cambios pendientes de aplicar con SaltStack." \
              "\n>>> No pending changes to be applied with SaltStack."
    fi
}

# Ejecuta salt en modulos pendientes de aplicar cambios
# Run salt on modules pending application of changes
LimpiarSalt() {
    local resto=""
    local lista_sucia="$OMV_ENGINED_DIRTY_MODULES_FILE"

    resto="$(jq -r .[] "$lista_sucia" | tr '\n' ' ')"
    if [ -n "$resto" ]; then
        echoe ">>> Aplicando cambios de configuración pendientes en OMV ..." \
              ">>> Applying pending configuration changes in OMV ..."
        omv-salt deploy run --quiet --append-dirty | _orl || return 1
    fi
    resto="$(jq -r .[] "$lista_sucia" | tr '\n' ' ')"
    [ -n "$resto" ] && { error "No se ha podido aplicar todos los cambios de configuración pendientes en OMV." \
                               "Failed to apply all pending configuration changes to OMV."; return 1; }
    return 0
}

# Crear/eliminar servicio de ejecución tras reinicio
# Create/delete service to run after reboot
ServicioReinicio() {
    local accion="$1"
    local archivo="/etc/systemd/system/omv-regen-autostart.service"

    case "$accion" in
        crear)
            if [ ! -f "$archivo" ]; then
                echoe ">>> Creando servicio de ejecución automática tras reinicio ..." \
                      ">>> Creating auto-execution service after reboot ..."
                cat << 'EOF' > $archivo
[Unit]
Description=Autoejecución temporal de omv-regen tras el reinicio
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=TERM=dumb
Environment=LANG=C.UTF-8
ExecStart=/bin/sh -c '/bin/sleep 1; /usr/sbin/omv-regen regenera_auto'
Restart=no
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
                systemctl daemon-reload
            fi
            if ! systemctl is-enabled omv-regen-autostart.service &>/dev/null; then
                echoe ">>> Activando servicio temporal de regeneración tras reinicio ..." \
                      ">>> Enabling temporary regeneration service after reboot ..."
                systemctl enable omv-regen-autostart.service &>/dev/null
            else
                echoe ">>> Servicio temporal de regeneración ya activo." \
                      ">>> Temporary regeneration service already active."
            fi
            ;;
        eliminar)
            if systemctl is-enabled omv-regen-autostart.service &>/dev/null; then
                echoe ">>> Desactivando servicio temporal de regeneración tras reinicio ..." \
                      ">>> Disabling temporary regeneration service after reboot ..."
                systemctl disable --now omv-regen-autostart.service &>/dev/null
            fi
            if [ -f "$archivo" ]; then
                rm -f "$archivo"
                systemctl daemon-reload
            fi
            ;;
        *)  error "Uso: ServicioReinicio {crear|eliminar}" \
                  "Usage: ServicioReinicio {crear|eliminar}"; return 1 ;;
    esac
}

EjecutarRegenera() {
    local fase estado resto tar_regen_fecha
    Salt=0
    OR_log_file="$OR_regen_log"
    [ ! -f "$OR_log_file" ] && touch "$OR_log_file"

    Regenera_es_Valido || { Mensaje error "Los ajustes no son válidos, no se puede ejecutar la regeneración." \
                                          "The settings are not valid, cannot execute regeneration."; return 1; }

    txt regen_continua "\n>>> La regeneración continúa de forma automática después de cada reinicio. \
                        \n>>> Puedes iniciar 'omv-regen' en cualquier momento para ver el log en vivo." \
                       "\n>>> Regeneration continues automatically after each reboot. \
                        \n>>> You can start 'omv-regen' at any time to view the live log."

    read -r fase estado resto <<< "${CFG[EstatusRegenera]}"
    if regen_en_progreso; then
        Continuar 20 "\n\n>>> Se va a continuar la REGENERACION DEL SISTEMA ACTUAL desde el punto que se detuvo.\
                      \n\nFase Nº: $fase \nEstado : $estado \nBackup : ${CFG[RutaTarRegenera]} \n \
                      \n${txt[regen_continua]}\n" \
                     "\n\n>>> The REGENERATION OF THE CURRENT SYSTEM will continue from the point it stopped.\
                      \n\nPhase Nº: $fase \nStatus : $estado \nBackup : ${CFG[RutaTarRegenera]} \n \
                      \n${txt[regen_continua]}\n" \
            || { echoe ">>> Regeneración cancelada por el usuario." \
                       ">>> Regeneration canceled by user."; return 0; }
    else
        Pregunta "\n\n>>> Se va a ejecutar la REGENERACION DEL SISTEMA ACTUAL. \
                  \n>>> El sistema se reiniciará varias veces. \
                  \n${txt[regen_continua]} \
                  \n\n  ⚫  ATENCIÓN  ⚫ \
                  \n\n>>> Antes de continuar, asegúrate de conectar los discos de datos del sistema original.\
                  \n>>> Si no están conectados cancela, conéctalos ahora y repite la regeneración cuando estés listo.\
                  \n\n>>> SI CONTINUAS SIN CONECTAR LOS DISCOS DE DATOS LA REGENERACIÓN FALLARÁ. \
                  \n\n\n\n¿Quieres continuar?\n" \
                 "\n\n>>> The CURRENT SYSTEM REGENERATION will be executed. \
                  \n>>> The system will reboot several times. \
                  \n${txt[regen_continua]} \
                  \n\n  ⚫  WARNING  ⚫  \n\
                  \n>>> Before continuing, make sure to connect the original system’s data disks.\
                  \n>>> If they are not connected, cancel, connect them now and repeat the regeneration when you are ready.\
                  \n\n>>> IF YOU CONTINUE WITHOUT CONNECTING THE DATA DISKS, THE REGENERATION WILL FAIL. \
                  \n\n\n\nDo you want to continue?\n" \
            || { Info 4 ">>> Regeneración cancelada por el usuario." \
                        ">>> Regeneration canceled by user."; return 0; }
        fase="0"
        omv_instalado && fase="1"
        CFG[EstatusRegenera]="$fase ${txt[inicio]}"
        CFG[RutaTarRegenera]="$TarRegenFile"
        SalvarAjustes || return 1

        tar_regen_fecha="$(awk -F "_" 'NR==1{print $2"_"$3}' <<< "$(basename "${CFG[RutaTarRegenera]}")")"
        Carpeta_Regen="${OR_dir}/regen_${tar_regen_fecha}"
        mkdir -p "$Carpeta_Regen"

        echoe ">>> Preparando el entorno de la regeneración ..." \
              ">>> Preparing the environment for regeneration ..."
        txt 1 "Fallo preparando el entorno de la regeneración. Limpiando y abortando ..." \
              "Failed to prepare regeneration environment. Cleaning and aborting ..."

        echoe ">>> Procediendo a desinstalar apparmor." \
              ">>> Proceeding to uninstall apparmor."
        DesinstalarApparmor || { error "${txt[1]}"; LimpiarRegeneracion; return 1; }

        echoe ">>> Procediendo a descomprimir y actualizar repositorios para la ejecución de la regeneración." \
              ">>> Proceeding to decompress and update repositories to execute the regeneration."
        DescomprimirBackup || { error "${txt[1]}"; LimpiarRegeneracion; return 1; }
        
        echoe ">>> Procediendo a configurar prioridades de versiones para los paquetes de OMV ..." \
              ">>> Proceeding to configure version priorities for OMV packages ..."
        FijarVersionesOriginales || { error "${txt[1]}"; LimpiarRegeneracion; return 1; }

        echoe ">>> Procediendo a crear repositorio local con paquetes del backup ..." \
              ">>> Proceeding to create local repository with backup packages ..."
        CrearRepoLocal || { error "${txt[1]}"; LimpiarRegeneracion; return 1; }

        if [ "$(estado_original_de "openmediavault-luksecryption")" = "instalado" ]; then
            echoe ">>> Procediendo a almacenar claves LUKS ..." \
                  ">>> Proceeding to store LUKS keys ..."
            PrepararClavesLUKS || { error "${txt[1]}"; LimpiarRegeneracion; return 1; }
        fi
    fi

    modo_desatendido || clear
    echoe "\n\n       <<< REGENERANDO SISTEMA OMV >>>\n\n" \
          "\n\n       <<< REGENERATING OMV SYSTEM >>>\n\n"

    tar_regen_fecha="$(awk -F "_" 'NR==1{print $2"_"$3}' <<< "$(basename "${CFG[RutaTarRegenera]}")")"
    Carpeta_Regen="${OR_dir}/regen_${tar_regen_fecha}"
    [ -d "$Carpeta_Regen" ] || { error "La carpeta temporal de regeneración no existe: $Carpeta_Regen" \
                                       "The regeneration temporary folder does not exist: $Carpeta_Regen"; return 1; }
    echoe ">>> Carpeta temporal: $Carpeta_Regen" \
          ">>> Temporary folder: $Carpeta_Regen"

    echoe ">>> Comprobando estado de servicio de ejecución tras reinicio ..." \
          ">>> Checking running service status after reboot ..."
    ServicioReinicio crear || return 1

    if ! modo_desatendido; then
        if [ "$estado" = "intento_5" ] || [ "$estado" = "retry_5" ]; then
            if Pregunta ">>> Se ha reintentado regenerar varias veces la Fase Nº$fase sin éxito. \
                       \n>>> Verifica los registros, es posible que haya algún error. \
                       \n>>> ¿Quieres reintentarlo de nuevo?" \
                        ">>> Phase No.$fase has been attempted to regenerate several times without success. \
                       \n>>> Check the logs, there may be an error. \
                       \n>>> Do you want to try again?"; then
                salvar_cfg EstatusRegenera "$fase ${txt[intento]}_4" || return 1
            else
                echoe ">>> Regeneración cancelada por el usuario." \
                      ">>> Regeneration canceled by user."
                return 0
            fi
        fi

        echoe "\n>>> Se va a reiniciar el servidor. Puedes ejecutar 'omv-regen' en cualquier momento para ver el log en vivo.\n" \
              "\n>>> The server is about to restart. You can run 'omv-regen' at any time to view the live log.\n"
        sync; sleep 3; reboot; sleep 3; exit 0
    fi
    
    echoe ">>> Comprobando si hay un reinicio pendiente ..." \
          ">>> Checking if a reboot is pending ..."
    ReiniciarSiRequerido || return 1

    while regen_en_progreso; do
        read -r fase estado resto <<< "${CFG[EstatusRegenera]}"
        case "$estado" in
            inicio|start)       salvar_cfg EstatusRegenera "$fase ${txt[intento]}_1 $resto" || return 1 ;;
            intento_1|retry_1)  salvar_cfg EstatusRegenera "$fase ${txt[intento]}_2 $resto" || return 1 ;;
            intento_2|retry_2)  salvar_cfg EstatusRegenera "$fase ${txt[intento]}_3 $resto" || return 1 ;;
            intento_3|retry_3)  salvar_cfg EstatusRegenera "$fase ${txt[intento]}_4 $resto" || return 1 ;;
            intento_4|retry_4)  salvar_cfg EstatusRegenera "$fase ${txt[intento]}_5 $resto" || return 1 ;;
            intento_5|retry_5)  error "Fase Nº $fase ha fallado repetidamente en modo automático. Abortando regeneración ..." \
                                      "Phase Nº $fase has failed repeatedly in automatic mode. Aborting regeneration ..."
                                return 1 ;;
            *)  error "Estado de regeneración desconocido: $estado" \
                      "Unknown regeneration status: $estado"
                return 1 ;;
        esac
        case "$fase" in
            0) RegeneraFase0 || return 1 ;;
            1) RegeneraFase1 || return 1 ;;
            2) RegeneraFase2 || return 1 ;;
            3) RegeneraFase3 || return 1 ;;
            4) RegeneraFase4 || return 1 ;;
            5) RegeneraFase5 || return 1 ;;
            6) RegeneraFase6 || return 1 ;;
            7) RegeneraFase7 || return 1 ;;
            *) error "Fase desconocida: $fase" "Unknown phase: $fase"; return 1 ;;
        esac
    done
}

# Desinstalar AppArmor si está presente
# Uninstall AppArmor if present
DesinstalarApparmor() {
    if dpkg -s apparmor &>/dev/null; then
        echoe ">>> Desinstalando apparmor ..." \
              ">>> Uninstalling apparmor..."
        systemctl stop apparmor.service
        apt remove --purge -y apparmor apparmor-utils apparmor-profiles apparmor-profiles-extra | _orl \
            || { error "No se pudo desinstalar AppArmor." \
                       "Could not remove AppArmor."; return 1; }
        systemctl daemon-reexec
        rm -rf /etc/apparmor.d/local
        echoe ">>> AppArmor desinstalado correctamente." \
              ">>> AppArmor removed successfully."
    else
        echoe ">>> apparmor no estaba instalado en este sistema." \
              ">>> apparmor was not installed on this system."
    fi
}

# Ejecutar reinicio con aviso de ejecutar de nuevo omv-regen tras el reinicio
# Run reboot with prompt to run omv-regen again after reboot
ReiniciarSiRequerido() {
    local reinicio=0 sin_internet=0 motivo
    txt texto "$1" "$2"

    [[ -f "/var/run/reboot-required" ]]    && reinicio=1
    ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 || sin_internet=1

    (( reinicio == 0 && sin_internet == 0 )) && { echoe "\n>>> No hay reinicio pendiente." \
                                                        "\n>>> No reboot pending."; return 0; }
    (( reinicio == 1 && sin_internet == 0 )) && txt motivo ">>> Se ha detectado un reinicio pendiente." \
                                                           ">>> A pending reboot has been detected."
    (( reinicio == 0 && sin_internet == 1 )) && txt motivo ">>> No se ha detectado conexión a Internet. Se intentará corregir con un reinicio." \
                                                           ">>> No Internet connection detected. A reboot will attempt to correct this."
    (( reinicio == 1 && sin_internet == 1 )) && txt motivo ">>> Se ha detectado un reinicio pendiente y además no hay conexión a Internet." \
                                                           ">>> A pending reboot has been detected and there is no Internet connection."
    echoe "\n$motivo"

    txt 1 "\n$motivo \n\nEl sistema se reiniciará ahora.\n\n${txt[regen_continua]}\n\n${txt[texto]}" \
          "\n$motivo \n\nThe system will now reboot.\n\n${txt[regen_continua]}\n\n${txt[texto]}"

    Continuar 10 "${txt[1]}" \
        || { Mensaje error "Regeneración cancelada por el usuario. \
                          \nEs necesario reiniciar o restaurar la conexión y EJECUTAR DE NUEVO OMV-REGEN para continuar." \
                           "Regeneration canceled by user. \
                          \nYou need to reboot or restore connection and RUN OMV-REGEN AGAIN to continue regeneration."; return 1; }

    txt 2 "Regeneración en progreso" \
          "Regeneration in progress"
    txt 3 "\nRegeneración en progreso\n${txt[1]}" \
          "\nRegeneration in progress\n${txt[1]}"
    EnviarCorreo "${txt[2]}" "${txt[3]}"
    echoe "\n>>> Reiniciando ..." "\n>>> Rebooting ..."
    sync; sleep 3; reboot; sleep 3; exit 0
}

# Descomprimir y actualizar repositorios para la regeneración
# Unzip and update repositories for regeneration
DescomprimirBackup() {
    local cache_dir="/var/cache/apt/archives" paquete arquitectura
    [[ -z "${CFG[RutaTarRegenera]}" ]] && { error "Ruta del backup indefinida." "Undefined backup path."; return 1; }
    [ -d "$Carpeta_Regen" ] || { error "No existe: $Carpeta_Regen" "Not exist: $Carpeta_Regen"; return 1; }

    echoe ">>> Descomprimiendo el archivo de backup para regenerar en: $Carpeta_Regen ..." \
          ">>> Decompressing the backup file to regenerate in: $Carpeta_Regen ..."
    if ! tar -xzf "${CFG[RutaTarRegenera]}" -C "${OR_dir}"; then
        error "Fallo descomprimiendo el backup." \
              "Failure decompressing the backup."
        rm -rf "$Carpeta_Regen"
        return 1
    fi

    echoe ">>> Copiando paquetes del backup al repositorio de omv-regen ..." \
          ">>> Copying packages from backup to omv-regen repository ..."
    [[ -d "${Carpeta_Regen}${OR_repo_dir}" ]] || { error "No se encontró el directorio $OR_repo_dir en el backup." \
                                                         "$OR_repo_dir not found in backup."; return 1; }
    rm -rf "$OR_repo_dir" && mkdir -p "$OR_repo_dir"
    cp -v "${Carpeta_Regen}${OR_repo_dir}"/*.deb "${OR_repo_dir}/" \
        || { error "Fallo al copiar los paquetes desde el backup al repositorio local." \
                   "Failed to copy packages from backup to local repository."; return 1; }

    echoe ">>> Copiando paquetes coincidentes con la arquitectura actual al caché de APT ..." \
          ">>> Copying packages matching the current architecture to the APT cache ..."
    [[ -d "$cache_dir" ]] || { error "El directorio de destino $cache_dir no existe." \
                                     "Destination directory $cache_dir does not exist."; return 1; }
    if compgen -G "${OR_repo_dir}/*.deb" >/dev/null; then
        for paquete in "${OR_repo_dir}"/*.deb; do
            if dpkg-deb --info "$paquete" >/dev/null 2>&1; then
                arquitectura="$(dpkg-deb --show --showformat='${Architecture}\n' "$paquete")"
                if [[ "$arquitectura" == "$(dpkg --print-architecture)" || "$arquitectura" == "all" ]]; then
                    cp -v "$paquete" "$cache_dir/" || { error "Fallo al copiar paquete: $paquete a la cache local: $cache_dir" \
                                                              "Failed to copy package: $paquete to local cache: $cache_dir"; return 1; }
                else
                    echoe ">>> Paquete $paquete omitido (arquitectura: $arquitectura)." \
                          ">>> Package $paquete skipped (architecture: $arquitectura)."
                fi
            else
                error "El paquete $paquete está corrupto." \
                      "Package $paquete is corrupt."
                return 1
            fi
        done
    else
        error "No se encontraron paquetes en $OR_repo_dir para sincronizar." \
              "No packages found in $OR_repo_dir to synchronize."
        return 1
    fi

    GenerarBaseDatosRepo

    echoe ">>> Actualizando los repositorios ..." \
          ">>> Updating the repositories ..."
    apt-get update || { error "No se pudo actualizar los repositorios." \
                              "Could not update repositories."; return 1; }
    return 0
}

# Configurar versiones de paquetes OMV del sistema original
# Configure OMV package versions from the original system
FijarVersionesOriginales() {
    local preferencias_dir="/etc/apt/preferences.d"
    local preferencias_file="${preferencias_dir}/omv-regen"
    local paquete estado_actual version_instalada

    if [ ! -f "$preferencias_file" ] || [ ! -s "$preferencias_file" ]; then
        echoe ">>> Configurando prioridades de versiones para los paquetes de OMV ..." \
              ">>> Setting version priorities for OMV packages ..."
        mkdir -p "$preferencias_dir"
        echo -n "" > "$preferencias_file"
        for paquete in "${!VERSION_ORIGINAL[@]}"; do
            if [[ "$(estado_original_de "$paquete")" == "instalado" ]]; then
                cat <<EOF >> $preferencias_file
Package: $paquete
Pin: version $(version_original_de "$paquete")
Pin-Priority: 1001

EOF
            else
                error "No se encontró versión para el paquete $paquete." \
                      "No version found for package $paquete."
                return 1
            fi
        done
    fi
}

# Crear repositorio local con los paquetes de instalación del backup
# Create local repository with backup installation packages
CrearRepoLocal() {
    local omvregen_local="/etc/apt/sources.list.d/omvregen-local.list"

    GenerarBaseDatosRepo

    if [ ! -f "$omvregen_local" ]; then
        echoe ">>> Agregando el repositorio local a las fuentes de apt ..." \
              ">>> Adding local repository to apt sources ..."
        echo "deb [trusted=yes] file:$OR_repo_dir ./" > "$omvregen_local"
    fi

    echoe ">>> Actualizando los índices de apt ..." \
          ">>> Updating apt indexes ..."
    apt-get update || { error "Fallo actualizando los índices de apt." \
                              "Failure updating apt indexes."; return 1; }

    echoe ">>> Verificando que el paquete requerido esté en el repositorio local ..." \
          ">>> Verifying required package in local repository ..."
    if ! apt-cache policy openmediavault | grep -q "$OR_repo_dir"; then
        error "El paquete requerido no se encuentra en el repositorio local. Revisa el backup." \
              "Required package not found in the local repository. Check the backup."
        return 1
    else
        echoe ">>> Correcto." \
              ">>> Correct."
    fi
}

# Solicita al usuario las claves LUKS faltantes y las guarda temporalmente para su uso posterior.
# Prompts the user for missing LUKS keys and temporarily saves them for later use.
PrepararClavesLUKS() {
    local archivo_crypttab="${Carpeta_Regen}/etc/crypttab"
    local archivo_persistente_claves="/root/omv_regen_luks.keys"
    local claves_faltantes=0 volumen ruta_clave linea

    [[ -z "${CFG[RutaTarRegenera]}" ]] && { error "Ruta del backup indefinida." "Undefined backup path."; return 1; }
    [ -d "$Carpeta_Regen" ] || { error "No existe: $Carpeta_Regen" "Not exist: $Carpeta_Regen"; return 1; }
    [ -f "$archivo_crypttab" ] || { error "No se encontró /etc/crypttab en el backup." \
                                          "/etc/crypttab not found in the backup."; return 1; }

    echoe ">>> Verificando claves LUKS en el backup ..." \
          ">>> Verifying LUKS keys in the backup ..."

    [ -f "$archivo_persistente_claves" ] || touch "$archivo_persistente_claves"
    chmod 600 "$archivo_persistente_claves"

    while IFS= read -r linea; do
        [[ -z "$linea" || "$linea" =~ ^# ]] && continue
        volumen=$(awk '{print $1}' <<< "$linea")
        ruta_clave=$(awk '{print $3}' <<< "$linea")

        if grep -q "^$volumen=" "$archivo_persistente_claves"; then
            echoe ">>> Clave para $volumen ya almacenada en $archivo_persistente_claves." \
                  ">>> Key for $volumen already stored in $archivo_persistente_claves."
        else
            if [ ! -f "${Carpeta_Regen}${ruta_clave}" ]; then
                txt 1 ">>> Introduzca la clave para el volumen $volumen:" \
                      ">>> Enter the key for volume $volumen:"
                echo "${txt[1]}"
                read -rs clave
                echo "$volumen=$clave" >> "$archivo_persistente_claves"
                chmod 600 "$archivo_persistente_claves"
                ((claves_faltantes++))
            fi
        fi
    done < "$archivo_crypttab"

    if (( claves_faltantes > 0 )); then
        echoe ">>> Se han almacenado $claves_faltantes nuevas claves en $archivo_persistente_claves." \
              ">>> $claves_faltantes new keys have been stored in $archivo_persistente_claves."
    else
        echoe ">>> Todas las claves necesarias ya estaban almacenadas en $archivo_persistente_claves." \
              ">>> All required keys were already stored in $archivo_persistente_claves."
    fi
}

InstalaRegeneraSalt() {
    local paquete=$1
    [ -z "$paquete" ] && { error "Argumento vacío." "Empty argument."; return 1; }

    if [ "$(estado_original_de "$paquete")" = "no_instalado" ]; then
        echoe ">>> $paquete no estaba instalado en el sistema original; será omitido." \
              ">>> $paquete was not installed on the original system; it will be skipped."
        return 0
    fi

    if no_marcado "inst_${paquete}"; then
        if ! InstalarRetenerVO "$paquete"; then
            if es_esencial "$paquete"; then
                error "Fallo instalando paquete esencial $paquete" \
                      "Failed to install essential package $paquete"
                return 1
            else
                error "No se pudo instalar paquete no esencial $paquete. Se omite su instalación." \
                      "Could not install non-essential package $paquete. Its installation is skipped."
                if [ "$(estado_actual_de "$paquete")" = "incompleto" ]; then
                    echoe ">>> Desinstalando paquete incompleto $paquete ..." \
                          ">>> Removing incomplete package $paquete ..."
                    apt-get remove --purge -y "$paquete" | _orl
                    apt-get autoremove -y | _orl
                else
                    dpkg --purge "$paquete" | _orl
                fi
                marcar "$paquete"
                return 0
            fi
        fi
        marcar "inst_${paquete}"
    fi
    if no_marcado "regen_${paquete}"; then
        Regenera "$paquete" || { error "No se pudo regenerar $paquete" \
                                       "Could not regenerate $paquete"; return 1; }
        marcar "regen_${paquete}"
    fi
    if no_marcado "salt_${paquete}"; then
        AplicarSalt || { error "No se pudo aplicar SaltStack para $paquete" \
                               "Could not apply SaltStack for $paquete"; return 1; }
        marcar "salt_${paquete}"
    fi
    return 0
}

# Devuelve valor 0 si una tarea de la regeneración no está hecha
# Returns value 0 if a regeneration task is not done
no_marcado() {
    local tarea=$1
    [[ -z "$tarea" ]] && { error "Argumento vacio 'no_marcado'" "Empty argument 'no_marcado'"; exit 1; }

    [[ "${CFG[EstatusRegenera]}" != *"$tarea"* ]] && return 0
    return 1
}

# Marcar tarea de regeneracion 'hecha'. Si $1 es fase_x pasa a la siguiente, si no se marca la tarea hecha
# Mark regeneration task 'done'. If $1 is phase_x, move on to the next; if not, mark the task as done.
marcar() {
    local tarea=$1 num_fase
    [[ -z "$tarea" ]] && { error "Argumento vacio 'marcar'" "Empty argument 'marcar'"; exit 1; }

    if [[ "$tarea" == "fase"* ]]; then
        num_fase="${tarea:5}"
        echoe "\n>>> Fase Nº$num_fase terminada." \
              "\n>>> Phase No.$num_fase completed."
        ((num_fase++))
        sleep 0.3
        salvar_cfg EstatusRegenera "$num_fase ${txt[inicio]}" || return 1
    else
        sleep 0.05
        salvar_cfg EstatusRegenera "${CFG[EstatusRegenera]} $tarea " || return 1
    fi
}

GenerarBaseDatosRepo() {
    echoe ">>> Generando la base de datos del repositorio de omv-regen ..." \
          ">>> Generating the omv-regen repository database ..."
    apt-ftparchive packages /var/lib/omv-regen/repo/ | sed 's|/var/lib/omv-regen/repo/||g' > /var/lib/omv-regen/repo/Packages
    gzip -9 -c /var/lib/omv-regen/repo/Packages > /var/lib/omv-regen/repo/Packages.gz
    apt-ftparchive release /var/lib/omv-regen/repo/ > /var/lib/omv-regen/repo/Release
}

# Eliminar el rastro de una regeneración en curso
# Remove traces of a regeneration in progress
LimpiarRegeneracion() {
    local paquetes_retenidos paquete

    echoe ">>> Eliminando retenciones de versiones de paquetes ..." \
          ">>> Removing package version holds ..."
    [[ -f "/etc/apt/preferences.d/omv-regen" ]] && rm -f "/etc/apt/preferences.d/omv-regen"
    paquetes_retenidos=$(dpkg --get-selections | grep hold | awk '{print $1}')
    if [ -n "$paquetes_retenidos" ]; then
        echoe ">>> Desmarcando paquetes retenidos ..." \
              ">>> Unchecking held packages ..."
        for paquete in $paquetes_retenidos; do
            echoe ">>> Desmarcando $paquete ..." \
                  ">>> Unchecking $paquete ..."
            apt-mark unhold "$paquete" || { error "No se pudo desmarcar retención de $paquete" \
                                                  "Could not unhold $paquete"; return 1; }
        done
    else
        echoe ">>> No hay paquetes retenidos." \
              ">>> There are no packages held."
    fi

    echoe ">>> Eliminando el backup descomprimido ..." \
          ">>> Deleting the unzipped backup ..."
    rm -rf "${OR_dir}"/regen_* 2>/dev/null
    
    echoe ">>> Eliminando el repositorio local de apt ..." \
          ">>> Removing local repository from apt sources ..."
    if [[ -f "/etc/apt/sources.list.d/omvregen-local.list" ]]; then
        rm -f "/etc/apt/sources.list.d/omvregen-local.list"
        echoe ">>> Repositorio local eliminado correctamente." \
              ">>> Local repository successfully removed."
    else
        echoe ">>> No se encontró el archivo del repositorio local, nada que eliminar." \
              ">>> Local repository file not found, nothing to remove."
    fi

    echoe ">>> Eliminando base de datos del repositorio local y actualizando el repositorio ..." \
          ">>> Deleting database from local repository and updating repository ..."
    rm -f "$OR_repo_dir"/Packages "$OR_repo_dir"/Packages.gz "$OR_repo_dir"/Release
    ActualizarRepo || { error "No se pudo actualizar el repositorio local." \
                              "Could not update local repository."; return 1; }

    echoe ">>> Restableciendo variables de configuración de estado de la regeneración a cero ..." \
          ">>> Resetting regeneration state configuration variables to zero ..."
    CFG[EstatusRegenera]=""; CFG[RutaTarRegenera]=""; CFG[ComplementosExc]=""
    SalvarAjustes || return 1

    echoe ">>> Actualizando índices de paquetes ..." \
          ">>> Updating package indexes ..."
    apt-get update | _orl || error "No se pudo actualizar la lista de paquetes." \
                            "Failed to update package list."
}

RegeneraFase0() {
    local n=0 temp_dir="${OR_tmp_dir}/instalar_omv"
    local archivo_omvextras nombre_objetivo version_omv directorio_trabajo archivo_inmutable
    mkdir -p "$temp_dir"
    directorio_trabajo="$(pwd)"

    # Desbloquear archivo de instalación de omv-extras
    # Unlock omv-extras installation file
    DesbloquearOMVExtras() {
        archivo_inmutable="$(lsattr "$directorio_trabajo" | awk '/openmediavault-omvextrasorg.*\.deb/ && /\-i\-/ {print $2}')"
        if [ -f "$archivo_inmutable" ]; then
            echoe ">>> Archivo inmutable de omv-extras encontrado: $archivo_inmutable" \
                  ">>> Omv-extras immutable file found: $archivo_inmutable"
            echoe ">>> Desbloqueando archivo de omv-extras en el directorio: $directorio_trabajo" \
                  ">>> Unlocking omv-extras file in directory: $directorio_trabajo"
            chattr -i "$archivo_inmutable" || { error "Fallo al eliminar archivo existente de omv-extras." \
                                                      "Failed to delete existing omv-extras file."; return 1; }
        else
            echoe ">>> No hay archivo inmutable de omv-extras para desbloquear en el directorio de trabajo $directorio_trabajo" \
                  ">>> No immutable omv-extras file to unlock in working directory $directorio_trabajo"
        fi
    }

    echoe ">>> FASE 0: INSTALACION DE OMV." \
          ">>> PHASE 0: INSTALLATION OF OMV."

    txt reinicio ""
    if no_marcado actualizar_sistema; then
        echoe ">>> Comprobando si el sistema está actualizado ..." \
              ">>> Checking if the system is up to date ..."

        apt-get update -qq
        n=$(apt list --upgradable 2>/dev/null | grep -c upgradable || true)

        if (( n > 0 )); then
            echoe ">>> Se detectaron $n actualizaciones. Aplicando actualizaciones del sistema ..." \
                  ">>> Detected $n available updates. Applying system updates ..."
            apt-get upgrade -y | _orl
            echoe ">>> Actualizaciones completadas. El sistema requiere reinicio." \
                  ">>> Updates completed. System requires reboot."
            GenerarReinicio
            txt reinicio ">>> Reinicio después de actualizar el sistema." \
                         ">>> Reboot after system update."
        else
            echoe ">>> El sistema ya está actualizado." \
                  ">>> System is already up to date."
        fi
        marcar actualizar_sistema
    fi

    if no_marcado raspberry; then
        if es_raspberry; then
            echoe ">>> Detectado hardware Raspberry Pi. Ejecutando script de preinstalación integrado desde omv-extras ..." \
                  ">>> Raspberry Pi hardware detected. Running preinstallation script integrated from omv-extras ..."
            if [[ -f /etc/systemd/network/10-persistent-eth0.link ]]; then
                echoe ">>> Ya se detectó configuración persistente de red, omitiendo preinstalación." \
                      ">>> Persistent network configuration already present, skipping preinstallation."
            else
                if ! command -v jq >/dev/null; then
                    apt-get --yes --no-install-recommends install jq | _orl \
                        || { echoe ">>> Error instalando jq, omitiendo configuración persistente." \
                                   ">>> Error installing jq, skipping persistent configuration."; return 1; }
                fi
                local mac
                mac="$(ip -j a show dev eth0 | jq -r .[].address | head -n1)"
                if [ -z "${mac}" ]; then
                    mac="$(ip -j a show dev end0 | jq -r .[].address | head -n1)"
                fi
                if [ -n "${mac}" ]; then
                    echoe "mac - ${mac}"
                    echo -e "[Match]\nMACAddress=${mac}\n[Link]\nName=eth0" > /etc/systemd/network/10-persistent-eth0.link
                fi
            fi
        fi
        txt reinicio "${txt[reinicio]} Reinicio tras script de preinstalacion Raspberry." \
                     "${txt[reinicio]} Reboot after Raspberry preinstallation script."
        GenerarReinicio
        marcar raspberry
    fi

    ReiniciarSiRequerido "${txt[reinicio]}" || return 1

    if ! omv_instalado; then
        archivo_omvextras="$(find "$OR_repo_dir" -name "openmediavault-omvextrasorg*.deb" -print -quit)"
        [[ -z "$archivo_omvextras" ]] && { error "No se encontró un archivo omv-extras en el directorio: $OR_repo_dir" \
                                                 "No omv-extras file found in directory: $OR_repo_dir"; return 1; }

        [[ "$DEBIAN_CODENAME__or" == "bullseye" ]] && version_omv=6
        [[ "$DEBIAN_CODENAME__or" == "bookworm" ]] && version_omv=7
        nombre_objetivo="openmediavault-omvextrasorg_latest_all${version_omv}.deb"

        echoe ">>> Preparando archivo de omv-extras en el directorio: $directorio_trabajo" \
              ">>> Preparing omv-extras file in directory: $directorio_trabajo"

        DesbloquearOMVExtras || return 1

        if [ -f "${directorio_trabajo}/${nombre_objetivo}" ]; then
            rm "${directorio_trabajo}/${nombre_objetivo}" \
                || { error "Fallo al eliminar archivo existente de omv-extras." \
                           "Failed to delete existing omv-extras file."; return 1; }
        fi
        cp -f "$archivo_omvextras" "${directorio_trabajo}/${nombre_objetivo}" \
            || { error "Fallo copiando el archivo omv-extras." \
                       "Failed to copy the omv-extras file."; return 1; }

        # Hacer inmutable para evitar que el script lo elimine
        # Make immutable to prevent the script from deleting it
        chattr +i "${directorio_trabajo}/${nombre_objetivo}" \
            || { error "Fallo aplicando atributo inmutable al archivo omv-extras." \
                       "Failure applying immutable attribute to omv-extras file."; return 1; }

        echoe ">>> Ejecutando script de instalación principal de OMV ..." \
              ">>> Running main OMV installation script ..."
        wget -O "${temp_dir}/install_omv.sh" "$URL_OMV_INSTALL_SCRIPT" \
            || { error "No se pudo descargar el script de instalación." \
                       "Failed to download installation script."; return 1; }
        sed -i 's/declare -i skipReboot=0/declare -i skipReboot=1/' "${temp_dir}/install_omv.sh"
        chmod +x "${temp_dir}/install_omv.sh"
        bash "${temp_dir}/install_omv.sh" | _orl \
            || { error "Fallo al ejecutar el script de instalación." \
                       "Failed to run installation script."; return 1; }
    fi

    if no_marcado limpieza; then
        rm -rf "$temp_dir"
        echoe ">>> Procediendo al desbloqueo del archivo de omv-extras." \
              ">>> Proceeding to unlock the omv-extras file."
        DesbloquearOMVExtras &>/dev/null || return 1
        marcar limpieza
    fi

    if no_marcado reinicio_omv; then
        GenerarReinicio
        marcar reinicio_omv
        txt 1 "Instalación de openmediavault completada con éxito. Es necesario reiniciar." \
              "openmediavault installation completed successfully. Reboot required."
        echoe "${txt[1]}"
        ReiniciarSiRequerido "${txt[1]}" || { error "${txt[error]}"; return 1; }
    fi

    echoe "\n\n\n>>> Tras la instalación de OMV se va a aplicar Saltstack por primera vez. \
          \n>>> Si cambia la IP conéctate a la nueva IP y ejecuta omv-regen para ver el log.\n\n\n" \
          "\n\n\n>>> After installing OMV, Saltstack will be applied for the first time. \
          \n>>> If the IP changes, connect to the new IP and run omv-regen to see the log.\n\n\n"
    Salt=1
    AplicarSalt || { error "${txt[error]}"; return 1; }
    marcar "fase_0"
}

RegeneraFase1() {
    local nodo clave clave_valor archivo_temporal_claves="/root/omv_regen_luks.keys"
    local paquete estado_actual version_instalada
    local fecha_tar_en_curso
    fecha_tar_en_curso="$(awk -F "_" 'NR==1{print $2"_"$3}' <<< "$(basename "${CFG[RutaTarRegenera]}")")"
    [ -f "${CFG[RutaTarRegenera]}" ] || { error "Ruta del backup indefinida." "Undefined backup path."; return 1; }
    [ -d "$Carpeta_Regen" ] || { error "No existe: $Carpeta_Regen" "Not exist: $Carpeta_Regen"; return 1; }

    echoe "\n>>>   >>>    FASE Nº1: RETENER PAQUETES INSTALADOS, COPIAR CARPETAS DE USUARIO, REGENERAR CONFIGURACIONES BÁSICAS.\n" \
          "\n>>>   >>>    PHASE Nº1: RETAIN INSTALLED PACKAGES, COPY USER FOLDERS, REGENERATE BASIC SETTINGS.\n"
    
    if no_marcado retener_paquetes; then
        echoe ">>> Actualizando openmediavault a las versiones del sistema original ..." \
              ">>> Upgrading OpenMediaVault to the original system versions ..."
        ActualizarOMV || return 1
        echoe ">>> Marcando como retenidos los paquetes OMV instalados ..." \
              ">>> Marking installed OMV packages as held ..."
        for paquete in "${!VERSION_ORIGINAL[@]}"; do
            estado_actual="$(estado_actual_de "$paquete")"
            version_instalada="$(version_instalada_de "$paquete")"
            if [[ "$estado_actual" == "instalado" || "$estado_actual" == "retenido" ]]; then
                if [[ "$version_instalada" != "$(version_original_de "$paquete")" ]]; then
                    error "La versión instalada del paquete '$paquete' no coincide con la versión original." \
                          "Installed version of package '$paquete' does not match the original version."
                    return 1
                fi
                if [[ "$estado_actual" == "instalado" ]]; then
                    echoe ">>> Marcando como retenido el paquete '$paquete' version '$version_instalada' ..." \
                          ">>> Marking package '$paquete' version '$version_instalada' as held ..."
                    apt-mark hold "$paquete"
                fi
            fi
        done
        marcar retener_paquetes
        txt 1 ">>> Reinicio requerido tras actualizar OMV." \
              ">>> Reboot required after updating OMV."
        ReiniciarSiRequerido "${txt[1]}" || return 1
    fi

    if no_marcado carpetas_usuario; then
        echoe ">>> Restaurando carpetas de usuario ..." \
              ">>> Restoring user folders ..."
        while IFS= read -r carpeta; do
            tar -tzf "$carpeta" > /dev/null || { error "El archivo $carpeta está corrupto o incompleto." \
                                                       "The file $carpeta is corrupt or incomplete."; return 1; }
            tar -xf "$carpeta" -C /  || { error "Fallo extrayendo $carpeta " \
                                                "Error extracting $carpeta "; return 1; }
        done <<< "$(find "$(dirname "${CFG[RutaTarRegenera]}")" -maxdepth 1 -type f -name "ORBackup_${fecha_tar_en_curso}_*user*.tar.gz")"
        marcar carpetas_usuario
    fi

    if no_marcado "archivos"; then
        echoe ">>> Copiando archivos del sistema desde el backup a su ubicación en el nuevo sistema ..." \
              ">>> Copying system files from the backup to their location on the new system ..."
        cp -apv "${Carpeta_Regen}${Default_file}" "$Default_file" | _orl || { error "cp Default_file: $Default_file"; return 1; }
        . /etc/default/openmediavault
        if [ -f "${Carpeta_Regen}/etc/crypttab" ]; then
            echoe ">>> Restaurando claves LUKS desde el backup ..." \
                  ">>> Restoring LUKS keys from the backup ..."
            awk 'NR>1{print $3}' "${Carpeta_Regen}/etc/crypttab" | while IFS= read -r clave; do
                [ -z "$clave" ] && continue
                if [ ! -d "$(dirname "$clave")" ]; then
                    echoe ">>> Creando directorio $(dirname "$clave") ..." \
                          ">>> Creating directory $(dirname "$clave") ..."
                    mkdir -p "$(dirname "$clave")" | _orl || { error "mkdir clave: $clave"; return 1; }
                fi
                if [ -f "${Carpeta_Regen}${clave}" ]; then
                    echoe ">>> Restaurando clave $clave desde el backup ..." \
                          ">>> Restoring key $clave from the backup ..."
                    cp -apv "${Carpeta_Regen}${clave}" "$clave" | _orl || { error "cp clave: $clave"; return 1; }
                # Usar clave almacenada si no está en el backup
                # Use stored key if not in the backup
                elif grep -q "^$(basename "$clave")=" "$archivo_temporal_claves" 2>/dev/null; then
                    echoe ">>> Restaurando clave almacenada para $clave ..." \
                          ">>> Restoring stored key for $clave ..."
                    clave_valor=$(grep "^$(basename "$clave")=" "$archivo_temporal_claves" | cut -d= -f2-)
                    echo "$clave_valor" > "$clave"
                    chmod 600 "$clave"
                else
                    error "No se encontró la clave para $clave." \
                          "Key for $clave not found."
                    return 1
                fi
            done
        else
            echoe ">>> No se encontró archivo /etc/crypttab en el backup, no se restaurarán claves LUKS." \
                  ">>> /etc/crypttab not found in the backup, no LUKS keys will be restored."
        fi
        marcar "archivos"
    fi
    
    if no_marcado monitorizacion; then
        # Evitar spam de monit durante la regeneración
        # Avoid monit spam during regeneration
        echoe ">>> Desactivando la monitorización en OMV ..." \
              ">>> Disabling monitoring in OMV ..."
        Config_Actualizar "/config/system/monitoring/perfstats/enable" "0" \
            || { error "No se pudo desactivar la monitorización en config.xml" \
                       "Could not disable monitoring in config.xml"; return 1; }
        omv-salt deploy run --quiet collectd monit rrdcached | _orl \
            || { error "Fallo al aplicar cambios de monitorización con Salt" \
                       "Failed to apply monitoring changes via Salt"; return 1; }
        LimpiarSalt || { error "No se pudo limpiar completamente Salt." \
                               "Could not fully clean Salt."; return 1; }
        marcar monitorizacion
    fi

    echoe ">>> Regenerando Configuraciones básicas del sistema ..." \
          ">>> Regenerating basic system settings ..."
    for nodo in time certificates powermanagement crontab apt syslog email; do
        if no_marcado "$nodo"; then
            Regenera $nodo || { error "${txt[error]}"; return 1; }
            marcar "$nodo"
        fi
    done
    
    no_marcado salt && { AplicarSalt || { error "${txt[error]}"; return 1; }; marcar salt; } 
    echoe ">>> Aplicando cambios en variables de entorno personalizadas ..." \
          ">>> Applying changes to custom environment variables ..."
    monit restart omv-engined | _orl || { error "Fallo reiniciando el motor de OMV." \
                                                "Failure restarting OMV engine."; return 1; }
    marcar "fase_1"
    return 0
}

RegeneraFase2() {
    local paquete="" estado_actual

    echoe "\n>>>   >>>    FASE Nº2: INSTALAR Y REGENERAR OMV-EXTRAS. CONFIGURAR REPOSITORIOS.\n" \
          "\n>>>   >>>    PHASE Nº2: INSTALL AND REGENERATE OMV-EXTRAS. CONFIGURE REPOSITORIES.\n"
    if no_marcado "instalacion_omvextras"; then
        if [ "$(estado_original_de "openmediavault-omvextrasorg")" = "no_instalado" ]; then
            echoe ">>> omv-extras no estaba instalado en el servidor original. No se va a instalar/regenerar." \
                  ">>> omv-extras was not installed on the original server. It will not be installed/regenerated."
            marcar "fase_2"
            return 0
        fi
        estado_actual="$(estado_actual_de "openmediavault-omvextrasorg")"
        if [[ "$estado_actual" == "instalado" || "$estado_actual" == "retenido" ]]; then
            marcar "instalacion_omvextras"
        else
            if no_marcado "prerequisitos_omvextras"; then
                if ! grep -qrE "^deb.*${DEBIAN_CODENAME__or}\s+main" /etc/apt/sources.list*; then
                    echoe ">>> Añadiendo el repositorio principal que falta ..." \
                          ">>> Adding the missing main repository ..."
                    echo "deb http://deb.debian.org/debian/ $DEBIAN_CODENAME__or main contrib non-free" | tee -a /etc/apt/sources.list || {
                        error "Fallo añadiendo el repositorio principal." \
                              "Failed to add the main repository."
                        return 1
                    }
                fi
                if ! grep -qrE "^deb.*${DEBIAN_CODENAME__or}-updates\s+main" /etc/apt/sources.list*; then
                    echoe ">>> Añadiendo el repositorio de actualizaciones principales que falta ..." \
                          ">>> Adding the missing core updates repository ..."
                    echo "deb http://deb.debian.org/debian/ ${DEBIAN_CODENAME__or}-updates main contrib non-free" | tee -a /etc/apt/sources.list || {
                        error "Fallo añadiendo el repositorio de actualizaciones principales." \
                              "Failed to add core updates repository."
                        return 1
                    }
                fi
                echoe ">>> Actualizando repositorios antes de instalar ..." \
                      ">>> Updating repos before installing ..."
                apt-get update | _orl || { error "Fallo actualizando los repositorios." \
                                                 "Failure updating repositories."; return 1; }
                echoe ">>> Instalando prerequisitos ..." \
                      ">>> Install prerequisites ..."
                apt-get --yes --no-install-recommends install gnupg | _orl || {
                    error "No se pueden instalar los requisitos previos de omv-extras." \
                          "Unable to install omv-extras prerequisites."; return 1; }
                marcar "prerequisitos_omvextras"
            fi
            if no_marcado "instalar_omvextras"; then
                [ -f "/etc/apt/sources.list.d/omvextras.list" ] && rm "/etc/apt/sources.list.d/omvextras.list"
                paquete=$(find "$OR_repo_dir" -type f -name "openmediavault-omvextrasorg_*.deb")
                if [ -f "$paquete" ]; then
                    echoe ">>> Paquete de omv-extras encontrado en el backup: $paquete" \
                          ">>> omv-extras package found in the backup: $paquete"
                else
                    echoe ">>> El paquete no está en el backup. Intentando descargarlo de Internet ..." \
                          ">>> The package is not in the backup. Trying to download it from the Internet ..."
                    paquete="openmediavault-omvextrasorg_latest_all${OMV_VERSION__or}.deb"
                    [ -f "$paquete" ] && rm "$paquete"
                    if ! wget "${URL_OMVEXTRAS}/${paquete}" | _orl; then
                        error "No se pudo descargar el paquete omv-extras. Verifique su conexión a Internet." \
                              "Unable to download the omv-extras package. Please check your Internet connection."
                        return 1
                    fi
                fi
                echoe ">>> Instalando omv-extras desde $paquete ..." \
                      ">>> Installing omv-extras from $paquete ..."
                if ! dpkg -i "$paquete" | _orl ; then
                    echoe ">>> Resolviendo dependencias ..." \
                          ">>> Resolving dependencies ..."
                    apt-get --yes -f install | _orl || { Mensaje error "No se pudieron resolver las dependencias al instalar omv-extras." \
                                                                       "Unable to resolve dependencies while installing omv-extras."; return 1; }
                fi
                marcar "instalar_omvextras"
            fi
            echoe ">>> Actualizando repositorios ..." \
                  ">>> Updating repos ..."
            apt-get update | _orl || { error "Fallo actualizando los repositorios." \
                                             "Failure updating repositories."; return 1; }
            marcar "instalacion_omvextras"
        fi
    fi
    estado_actual="$(estado_actual_de "openmediavault-omvextrasorg")"
    if [[ "$estado_actual" == "instalado" || "$estado_actual" == "retenido" ]]; then
        if no_marcado "regenerar_omvextras"; then
            echoe ">>> Regenerando omv-extras y repositorio de docker ..." \
                  ">>> Regenerating omv-extras and docker repository ..."
            Regenera "openmediavault-omvextras" || return 1
            marcar "regenerar_omvextras"
        fi
        if [ -f "/usr/sbin/omv-aptclean" ]; then
            echoe ">>> Actualizando repositorios ..." \
                  ">>> Updating repositories ..."
            /usr/sbin/omv-aptclean repos | _orl || { error "Fallo actualizando los repositorios con omv-aptclean repos" \
                                                           "Failure updating repositories with omv-aptclean repos"; return 1; }
        elif [ "$OMV_VERSION__or" = "7" ]; then
            error "No se encontró el archivo /usr/sbin/omv-aptclean" \
                  "The file /usr/sbin/omv-aptclean was not found"
            return 1
        fi
    fi
    marcar "fase_2"
    return 0
}

RegeneraFase3() {
    local kernel_instalado salida script_installproxmox="/usr/sbin/omv-installproxmox"

    echoe "\n>>>   >>>    FASE Nº3: INSTALAR KERNEL PROXMOX.\n" \
          "\n>>>   >>>    PHASE Nº3: INSTALL PROXMOX KERNEL.\n"
    
    if [ "$(estado_original_de "openmediavault-kernel")" = "no_instalado" ]; then
        echoe ">>> openmediavault-kernel no estaba instalado en el sistema original; será omitido." \
              ">>> openmediavault-kernel was not installed on the original system; it will be skipped."
        marcar "fase_3"
        return 0
    fi
    
    if ! InstalarRetenerVO "openmediavault-kernel"; then
        error "Fallo instalando openmediavault-kernel. Se omite la instalación del kernel." \
              "Failed to install openmediavault-kernel. Kernel installation is skipped."
        marcar "fase_3"
        return 0
    fi

    if [ "${CFG[RegenKernel]}" = "No" ]; then
        echoe ">>> Opción saltar kernel proxmox habilitada. No se instalará kernel." \
              ">>> Skip proxmox kernel option enabled. Kernel will not be installed."
        marcar "fase_3"
        return 0
    fi

    kernel_instalado=$(uname -r | awk -F "." '/pve$/ {print $1"."$2}')
    if [[ "$KernelOriginal" == 0 || "$KernelOriginal" == "$kernel_instalado" ]]; then
        if [ -z "$kernel_instalado" ]; then
            echoe ">>> No se detectó un kernel Proxmox instalado." \
                  ">>> No Proxmox kernel detected."
        else
            echoe ">>> El kernel instalado es el correcto: $kernel_instalado" \
                  ">>> The installed kernel is correct: $kernel_instalado"
        fi
        marcar "fase_3"
        return 0
    fi

    echoe ">>> Instalando kernel proxmox: $KernelOriginal para sustituir al actual: $kernel_instalado" \
          ">>> Installing proxmox kernel: $KernelOriginal to replace the current one: $kernel_instalado"
    if [ -f "$script_installproxmox" ]; then
        # shellcheck disable=SC1090
        ( . "$script_installproxmox" "$KernelOriginal" ) | _orl
        salida=$?
        if [ $salida -eq 0 ]; then
            echoe ">>> El kernel $KernelOriginal se ha instalado con éxito." \
                  ">>> Kernel $KernelOriginal has been installed successfully."
        else
            error "El script 'omv-installproxmox' terminó con el código de error: $salida " \
                  "The 'omv-installproxmox' script terminated with the error code: $salida "
            return 1
        fi
    else
        error "No se encuentra el script: $script_installproxmox " \
              "Script not found: $script_installproxmox "; return 1
    fi
    GenerarReinicio
    marcar "fase_3"
    txt 1 ">>> Reinicio requerido tras instalar un kernel proxmox." \
          ">>> Reboot required after installing a proxmox kernel."
    echoe "${txt[1]}"
    ReiniciarSiRequerido "${txt[1]}" || { error "${txt[error]}"; return 1; }

    return 0
}

RegeneraFase4() {
    local pool uuid_sharerootfs paquete fuentes destinos valor symlink_fuente symlink_destino estado_actual

    if no_marcado "actualizar_proxmox"; then
        estado_actual="$(estado_actual_de "openmediavault-kernel")"
        if [[ "$estado_actual" == "instalado" || "$estado_actual" == "retenido" ]]; then
            echoe ">>> Actualizando OMV tras la instalación de openmediavault-kernel ..." \
                  ">>> Updating OMV after installing openmediavault-kernel ..."
            ActualizarOMV || { error "Fallo actualizando OMV. ${txt[error]}" \
                                     "Failure updating OMV. ${txt[error]}"; return 1; }
            marcar "actualizar_proxmox"
            ReiniciarSiRequerido ">>> Reinicio requerido tras actualizar OMV." \
                                 ">>> Reboot required after updating OMV." || { error "${txt[error]}"; return 1; }
        else
            marcar "actualizar_proxmox"
        fi
    fi

    echoe "\n>>>   >>>    FASE Nº4: MONTAR SISTEMAS DE ARCHIVOS.\n" \
          "\n>>>   >>>    PHASE Nº4: MOUNT FILE SYSTEMS.\n"

    if no_marcado instalar_sharerootfs; then
        echoe ">>> Instalando openmediavault-sharerootfs ..." \
              ">>> Installing openmediavault-sharerootfs ..."
        if ! apt-get --yes install openmediavault-sharerootfs | _orl; then
            apt-get --yes --fix-broken install | _orl
            apt-get update | _orl
            if ! apt-get --yes install openmediavault-sharerootfs | _orl; then
                apt-get --yes --fix-broken install | _orl
                error "No se pudo instalar openmediavault-sharerootfs" \
                      "Failed to install openmediavault-sharerootfs"
                return 1
            fi
        fi
        marcar instalar_sharerootfs
    fi
    if no_marcado "hdparm-fstab"; then
        echoe ">>> Regenerar fstab (Sistemas de archivos EXT4 BTRFS)" \
              ">>> Regenerate fstab (EXT4 BTRFS file systems)"
        Regenera hdparm || { error "${txt[error]}"; return 1; }
        Regenera fstab || { error "${txt[error]}"; return 1; }
        AplicarSalt || { error "${txt[error]}"; return 1; }
        echoe ">>> Cambiar UUID disco de sistema si es diferente al original." \
              ">>> Change system disk UUID if it is different from the original."
        echoe ">>> Configurando openmediavault-sharerootfs ..." \
              ">>> Configuring openmediavault-sharerootfs ..."
        uuid_sharerootfs="79684322-3eac-11ea-a974-63a080abab18"
        if [ "$(omv_config_get_count "//mntentref[.='${uuid_sharerootfs}']" | _orl)" = "0" ]; then
            omv-confdbadm delete --uuid "${uuid_sharerootfs}" "conf.system.filesystem.mountpoint" | _orl
        fi
        apt-get install --reinstall openmediavault-sharerootfs  | _orl || { 
            error "No se pudo reinstalar openmediavault-sharerootfs " \
                  "Failed to reinstall openmediavault-sharerootfs "; return 1; }
        marcar "hdparm-fstab"
    fi

    if no_marcado btrfs; then
        echoe ">>> Regenerando política de snapshots BTRFS desde la base de datos original ..." \
              ">>> Regenerating BTRFS snapshot policy from the original database ..."
        Regenera btrfs || { error "${txt[error]}"; return 1; }
        marcar btrfs
    fi

    echoe ">>> Regenerar complementos requeridos para los sistemas de archivos." \
          ">>> Regenerate plugins required for file systems."

    if no_marcado "openmediavault-zfs"; then
        InstalarRetenerVO "openmediavault-zfs" || { error "${txt[error]}"; return 1; }
        estado_actual="$(estado_actual_de "openmediavault-zfs")"
        if [[ "$estado_actual" == "instalado" || "$estado_actual" == "retenido" ]]; then
            if [ ${#OriginalZFS[@]} -gt 0 ] && [[ ! " ${OriginalZFS[*]} " =~ (no_zfs) ]]; then
                for pool in "${OriginalZFS[@]}"; do
                    zpool import -f "$pool" | _orl || { error "No se pudo importar el pool: $pool " \
                                                              "Could not import pool: $pool "; return 1; }
                    if ! zpool status "$pool" | grep -iq "online"; then
                        error "El pool ZFS '$pool' no está online después de la importación." \
                              "ZFS pool '$pool' is not online after import."
                        return 1
                    fi
                done
                Regenera "openmediavault-zfs" || { error "${txt[error]}"; return 1; }
                AplicarSalt || { error "${txt[error]}"; return 1; }
            else
                echoe ">>> El sistema original no tenía pools ZFS para importar en el sistema." \
                      ">>> The original system did not have ZFS pools to import into the system."
            fi
        fi
        marcar "openmediavault-zfs"
    fi

    if no_marcado "luksencryption"; then
        if no_marcado "openmediavault-luksencryption"; then
            InstalaRegeneraSalt "openmediavault-luksencryption" || { error "Fallo procesando openmediavault-luksencryption ${txt[error]}" \
                                                                           "Failed to process openmediavault-luksencryption ${txt[error]}"; return 1; }
            marcar "openmediavault-luksencryption"
        fi
        estado_actual="$(estado_actual_de "openmediavault-luksencryption")"
        if [[ "$estado_actual" == "instalado" || "$estado_actual" == "retenido" ]]; then
            GenerarReinicio
            txt 1 ">>> Reinicio requerido tras instalar openmediavault-luksencryption." \
                  ">>> Reboot required after installing openmediavault-luksencryption."
            echoe "${txt[1]}"
            ReiniciarSiRequerido "${txt[1]}" || { error "${txt[error]}"; return 1; }
        fi
    fi

    if no_marcado "SISTEMA_ARCHIVOS"; then
        # Nota: El orden de instalación es el que está definido en la matriz SISTEMA_ARCHIVOS
        # Note: The installation order is the one defined in the SISTEMA_ARCHIVOS array.
        for paquete in "${SISTEMA_ARCHIVOS[@]}"; do
            if no_marcado "$paquete"; then
                InstalaRegeneraSalt "$paquete" || { error "Fallo procesando $paquete ${txt[error]}" \
                                                          "Failed to process $paquete ${txt[error]}"; return 1; }
                marcar "$paquete"
            fi
        done
        echoe ">>> Complementos relacionados con sistemas de archivos regenerados con éxito." \
              ">>> Filesystem-related plugins were successfully regenerated."
        marcar "SISTEMA_ARCHIVOS"
    fi

    if no_marcado "crear_symlinks"; then
        estado_actual="$(estado_actual_de "openmediavault-symlinks")"
        if [[ "$estado_actual" == "instalado" || "$estado_actual" == "retenido" ]]; then
            echoe ">>> Leyendo symlinks en la base de datos ..." \
                  ">>> Reading symlinks in the database ..."
            if LeerValorBD /config/services/symlinks/symlinks/symlink/source; then
                fuentes="$ValorBD"
                if LeerValorBD /config/services/symlinks/symlinks/symlink/destination; then
                    destinos="$ValorBD"
                    valor=0
                    while [ $valor -lt "$NumValBD" ]; do
                        ((valor++))
                        symlink_fuente=$(awk -v i=$valor 'NR==i {print $1}' <<< "$fuentes")
                        symlink_destino=$(awk -v i=$valor 'NR==i {print $1}' <<< "$destinos")
                        echoe ">>> Creando symlink $symlink_fuente $symlink_destino ..." \
                              ">>> Creating symlink $symlink_fuente $symlink_destino ..."
                        ln -s "$symlink_fuente" "$symlink_destino" | _orl
                    done
                fi
            else
                echoe ">>> No hay symlinks creados en la base de datos original." \
                      ">>> No symlinks created in original database."
            fi
        fi
        marcar "crear_symlinks"
    fi

    marcar "fase_4"
    return 0
}

RegeneraFase5() {
    local nodo
    [[ -z "${CFG[RutaTarRegenera]}" ]] && { error "Ruta del backup indefinida." "Undefined backup path."; return 1; }
    [ -d "$Carpeta_Regen" ] || { error "No existe: $Carpeta_Regen" "Not exist: $Carpeta_Regen"; return 1; }

    echoe "\n>>>   >>>    FASE Nº5: REGENERAR USUARIOS, CARPETAS COMPARTIDAS Y RESTO DE GUI.\n" \
          "\n>>>   >>>    PHASE Nº5: REGENERATE USERS, SHARED FOLDERS AND REST OF GUI.\n"

    if no_marcado "archivos"; then
        echoe ">>> Restaurando archivos de sistema ..." \
              ">>> Restoring system files ..."
        rsync -av --exclude etc/openmediavault/config.xml --exclude usr/sbin/omv-regen --exclude var/lib/omv-regen/ "${Carpeta_Regen}"/ / | _orl \
            || { error "No se pudo sincronizar archivos." \
                       "Could not sync files."; return 1; }
        marcar "archivos"
    fi

    echoe "\n>>> Regenerando resto de GUI ..." \
          "\n>>> Regenerating the rest of the GUI ..."
    for nodo in webadmin smart users groups homedirectory shares nfs ssh notification rsync smb; do
        if no_marcado "regenera_$nodo"; then
            Regenera $nodo || { error "${txt[error]}"; return 1; }
            marcar "regenera_$nodo"
        fi
        if [[ "$nodo" == "groups" || "$nodo" == "shares" || "$nodo" == "smb" ]] && no_marcado "salt_$nodo"; then
            AplicarSalt || { error "${txt[error]}"; return 1; }
            marcar "salt_$nodo"
        fi
    done

    marcar fase_5
    return 0
}

RegeneraFase6() {
    local n=0 paquete dpkg_completo paquetes estado_actual version

    echoe "\n>>>   >>>    FASE Nº6: INSTALAR RESTO DE COMPLEMENTOS.\n" \
          "\n>>>   >>>    PHASE Nº6: INSTALL REST OF COMPLEMENTS.\n"

    if no_marcado exclusiones; then
        echoe ">>> Marcando complementos a excluir ..." \
              ">>> Marking plugins to exclude ..."
        if [[ -n "${CFG[ComplementosExc]}" ]]; then
            for paquete in ${CFG[ComplementosExc]}; do
                marcar "$paquete"
                echoe ">>> Marcado para omitir su instalación: $paquete" \
                      ">>> Marked to skip installation: $paquete"
                n=1
            done
        fi
        [[ $n -eq 0 ]] && echoe ">>> No se ha marcado ningún complemento para omitir su instalación." \
                                ">>> No plugins have been marked for skipping installation."
        marcar exclusiones
        salvar_cfg ComplementosExc ""
    fi

    if no_marcado "paquetes_previos"; then
        # Nota: Respetar este orden de instalación
        # Note: Respect this installation order
        for paquete in "openmediavault-apt" "openmediavault-apttool" "openmediavault-cterm"; do
            if no_marcado "$paquete"; then
                InstalaRegeneraSalt "$paquete" || { error "Fallo procesando $paquete ${txt[error]}" \
                                                          "Failed to process $paquete ${txt[error]}"; return 1; }
                marcar "$paquete"
            fi
        done
        marcar "paquetes_previos"
    fi

    if no_marcado "paquetes_apttol"; then
        estado_actual="$(estado_actual_de "$paquete")"
        if [ "$estado_actual" = "instalado" ] || [ "$estado_actual" = "retenido" ]; then
            echoe ">>> Leyendo paquetes instalados mediante el complemento apttool ..." \
                  ">>> Reading packages installed using the apttool plugin ..."
            paquetes="$(xmlstarlet select --template --value-of "/config/services/apttool/packages/package/packagename" --nl "$Config_xml_file")"
            if [ -z "$paquetes" ]; then
                echoe ">>> La base de datos original no contiene paquetes instalados mediante el complemento apttool." \
                      ">>> The original database does not contain packages installed using the apttool plugin."
            else
                dpkg_completo=$(awk '/^\[dpkg completo\]/{flag=1; next} /^\[/{flag=0} flag' "$OR_RegenInfo_file")
                while IFS= read -r paquete; do
                    if echo "$dpkg_completo" | grep -q "^$paquete "; then
                        echoe ">>> Instalando $paquete ..." \
                              ">>> Installing $paquete ..."
                        apt-get --yes install "$paquete" | _orl \
                            || { error "Fallo instalando $paquete No esencial, la regeneración continúa." \
                                       "Failed to install $paquete Non-essential, regeneration continues."; }
                    else
                        echoe ">>> $paquete no estaba instalado en el sistema original." \
                              ">>> $paquete was not installed on the original system."
                    fi
                done <<< "$paquetes"
            fi
        fi
        marcar "paquetes_apttol"
    fi

    if no_marcado "instalar_kvm"; then
        echoe ">>> Instalar openmediavault-kvm (requiere opción especial de instalación)" \
              ">>> Install openmediavault-kvm (requires special installation option)"
        paquete="openmediavault-kvm"
        if [ "$(estado_original_de "$paquete")" = "no_instalado" ]; then
            echoe ">>> $paquete no estaba instalado en el sistema original; se omite." \
                  ">>> $paquete was not installed on the original system; is omitted."
            marcar "instalar_kvm"
        elif [ "$(estado_actual_de "$paquete")" = "no_instalado" ]; then
            echoe ">>> Comprobando compatibilidad de la CPU con KVM ..." \
                  ">>> Checking CPU compatibility with KVM ..."
            if ! grep -qE 'vmx|svm' /proc/cpuinfo; then
                error "La CPU no soporta virtualización. No es posible instalar KVM." \
                      "The CPU does not support virtualization. KVM cannot be installed."
                marcar "instalar_kvm"
            else
                if ! Backports7 YES; then
                    error "No se pudo habilitar Backports previamente a KVM. Saltando instalacion de KVM." \
                          "Backports could not be enabled prior to KVM. Skipping KVM installation."
                elif ! LocalizarPaqueteVO "$paquete"; then
                    error "No se ha localizado la version correcta de $paquete. No se va a instalar." \
                          "The correct version of $paquete could not be found. It will not be installed."
                else
                    version="$(version_original_de $paquete)"
                    echoe ">>> Instalando $paquete ..." \
                          ">>> Install $paquete ..."
                    if ! apt-get --yes --option DPkg::Options::="--force-confold" install "${paquete}=${version}" | _orl; then
                        apt-get --yes --fix-broken install | _orl
                        apt-get update | _orl
                        if ! apt-get --yes --option DPkg::Options::="--force-confold" install "${paquete}=${version}" | _orl; then
                            apt-get --yes --fix-broken install | _orl || error "$paquete no se pudo instalar." \
                                                                               "$paquete could not be installed."
                        fi
                    fi
                    if [[ "$(estado_actual_de "$paquete")" = "instalado" || "$(estado_actual_de "$paquete")" = "retenido" ]]; then
                        if ! MarcarRetencion "$paquete"; then
                            error "Fallo marcando retencion de $paquete" \
                                  "Failed to mark $paquete retention"
                        elif ! Regenera "$paquete";then
                            error "No se ha podido regenerar $paquete" \
                                  "Could not regenerate $paquete"
                            return 1
                        elif ! AplicarSalt; then
                            error "Fallo aplicando salt a $paquete" \
                                  "Failed to apply salt to $paquete"
                            return 1
                        else
                            echoe "$paquete instalado y regenerado con éxito." \
                                  "$paquete installed and regenerated successfully."
                        fi
                    else
                        error "$paquete no quedó instalado correctamente. Se omite." \
                              "$paquete was not installed correctly. Skipping."
                    fi
                fi
            fi
            Backports7 NO || error "No se pudo deshabilitar Backports. Continuando..." \
                                   "Could not disable Backports. Continuing..."
            marcar "instalar_kvm"
        else
            echoe ">>> $paquete ya estaba instalado; se omite reinstalación." \
                  ">>> $paquete was already installed; skipping reinstallation."
            marcar "instalar_kvm"
        fi
    fi

    echoe ">>> Instalar resto de complementos." \
          ">>> Install rest of plugins."
    for paquete in "${!VERSION_ORIGINAL[@]}"; do
        if no_marcado "$paquete"; then
            es_esencial "$paquete" && { marcar "$paquete"; continue; }
            InstalaRegeneraSalt "$paquete" || { error "Fallo procesando $paquete ${txt[error]}" \
                                                      "Failed to process $paquete ${txt[error]}"; return 1; }
            marcar "$paquete"
        fi
    done

    echoe ">>> Todos los complementos están instalados." \
          ">>> All plugins are installed."

    marcar "fase_6"
    return 0
}

RegeneraFase7() {
    local carpeta nodo
    local archivo_temporal_claves="/root/omv_regen_luks.keys"
    
    echoe "\n>>>   >>>    FASE Nº7: RECONFIGURAR, ACTUALIZAR, LIMPIAR, CONFIGURAR RED, REINICIAR.\n" \
          "\n>>>   >>>    PHASE Nº7: RECONFIGURE, UPDATE, WIPE, NETWORK SETUP, REBOOT.\n"

    if no_marcado regenerar_red; then
        txt 1 "\n\n¡La regeneración está finalizando!\n \
               \nSe va a actualizar OMV a la última versión disponible y se reiniciará el sistema para finalizar. \
               \nRecuerda borrar la caché del navegador.\n\n" \
               "\n\nRegeneration is ending!\n \
               \nOMV will be updated to the latest available version and the system will be rebooted to complete.
               \nRemember to clear your browser cache.\n\n"
        echoe ">>> Regenerando Red ..." \
              ">>> Regenerating Network ..."
        if [ "${CFG[RegenRed]}" = "No" ]; then
            Info 10 "${txt[1]}\n\nLa configuración activa en omv-regen es NO regenerar la interfaz de red." \
                    "${txt[1]}\n\nThe active setting in omv-regen is to NOT regenerate the network interface."
        else
            Info 10 "${txt[1]}\n\nLa configuración activa en omv-regen es regenerar la interfaz de red. \
                    \n La IP del sistema de origen era ${IPOriginal} \
                    \nDespués del reinicio puedes acceder al servidor en esa IP si era IP estática." \
                    "${txt[1]}\n\nThe active setting in omv-regen is to regenerate the network interface. \
                    \nThe IP of the original system was ${IPOriginal} \
                    \nAfter reboot you can access the server on that IP if it was static IP."
            for nodo in iptables interfaces dns proxy; do
                if no_marcado "$nodo"; then
                    Regenera "$nodo" || { error "${txt[error]}"; return 1; }
                    marcar "$nodo"
                fi
            done
        fi
        if es_raspberry; then
            echoe ">>> Saltando configuración de monit en Raspberry Pi.\n${txt[1]}" \
                  ">>> Skipping monit settings on Raspberry Pi.\n${txt[1]}"
        else
            systemctl enable monit.service
            systemctl start monit.service
            no_marcado monitoring && { Regenera monitoring || return 1; marcar monitoring; }
        fi
        AplicarSalt || return 1
        marcar regenerar_red
    fi

    if no_marcado temporales; then
        echoe ">>> Eliminando archivos temporales ..." \
              ">>> Deleting temporary files ..."
        [ -f "${Conf_tmp_file}.ori" ] && rm -f "${Conf_tmp_file}.ori"
        [ -f "$Conf_tmp_file" ] && rm -f "$Conf_tmp_file"
        if [ -f "$archivo_temporal_claves" ]; then
            echoe ">>> Eliminando clave temporal almacenada en $archivo_temporal_claves ..." \
                  ">>> Removing temporary key stored in $archivo_temporal_claves ..."
            shred -u -z "$archivo_temporal_claves" || { error "Fallo Eliminando clave temporal de LUKS." \
                                                              "Failed to delete LUKS temporary key."; return 1; }
        fi
        marcar temporales
    fi

    LimpiarRegeneracion || { error ">>> No se ha podido limpiar la regeneración actual." \
                                   ">>> The current regeneration could not be cleared."; return 1; }

    echoe ">>> Actualizando todos los paquetes a la ultima versión disponible ..." \
          ">>> Updating all packages to the latest available version ..."
    ActualizarOMV || { error "Fallo actualizando OMV. ${txt[error]}" \
                             "Failure updating OMV. ${txt[error]}"; return 1; }

    echoe ">>> Fase Nº7 terminada.\n>>> ¡Regeneración finalizada con éxito!\n>>> Reiniciando el sistema ..." \
          ">>> Phase No.7 completed.\n>>> Regeneration completed successfully!\n>>> Rebooting the system ..."

    txt 1 "Regeneración finalizada" \
          "Regeneration completed"
    txt 2 "¡La regeneración del sistema ha finalizado con éxito!" \
          "System regeneration completed successfully!"
    EnviarCorreo "${txt[1]}" "${txt[2]}"
    OR_log_file="/var/log/omv-regen.log"
    cat "$OR_regen_log" >> "$OR_log_file"
    rm -f "$OR_regen_log"
    ServicioReinicio eliminar
    sync; sleep 5; reboot; sleep 5; exit
}

################################################## INICIO ################################################
################################################## START #################################################

# Cargar ajustes predeterminados
# Load presets
IniciarAjustes; AjustarIdioma

# Ejecutar como root
# Run as root
[[ $(id -u) -ne 0 ]] && Salir nolog ">>> Ejecuta omv-regen como root. Saliendo ... ${txt[salirayuda]}" \
                                    ">>> Run omv-regen as root. Exiting ... ${txt[salirayuda]}"

# Comprobar que no hay mas de un argumento y procesar
# Check that there is not more than one argument and process
[[ $# -gt 1 ]] && Salir nolog "\n>>> Argumento inválido: $* ${txt[salirayuda]}" \
                              "\n>>> Invalid argument: $* ${txt[salirayuda]}"
case "$1" in
    backup|-b|--backup)                 VIA=9; BackupProgramado=0 ;;
    regenera|-r|--regenera)             VIA=10 ;;
    ayuda|-a|--ayuda|help|-h|--help)    Ayuda; clear; exit ;;
    limpieza_semanal)                   VIA=11; LimpiezaProgramada=0 ;;
    regenera_auto)                      VIA=10; ModoAuto=0 ;;
    desinstalar|uninstall)              DesinstalarOmvregen ;;
    "")                                 VIA=0 ;;
    *)                                  Salir nolog "\n>>> Argumento inválido $1 ${txt[salirayuda]}" \
                                                    "\n>>> Invalid argument $1 ${txt[salirayuda]}" ;;
esac

# Gestionar multiples instancias de omv-regen
# Managing multiple instances of omv-regen
if ! ArchivoBloqueo; then
    txt 1 ">>> Hay otra instancia de omv-regen en ejecución." \
          ">>> There is another instance of omv-regen running."
    [ "$1" = "backup" ] && Salir "${txt[1]}\n>>> No se puede ejecutar el backup.\n>>> Saliendo ..." \
                                 "${txt[1]}\n>>> Backup cannot be executed.\n>>> Exiting ..."
    [ "$1" = "limpieza_semanal" ] && Salir "${txt[1]}\n>>> No se puede ejecutar la limpieza semanal.\n>>> Saliendo ..." \
                                           "${txt[1]}\n>>> Weekly cleaning cannot be performed. Exiting ..."
    if regen_en_progreso; then
        [ "$1" = "regenera_auto" ] && { error "La ejecución automática de la regeneración no ha podido bloquear el archivo de control." \
                                              "Automatic regeneration execution could not lock the control file."; exit 1; }
        [ -f "/var/run/reboot-required" ] && Salir ">>> El sistema se va a reiniciar. Conéctate de nuevo tras el reinicio." \
                                                   ">>> The system is about to reboot. Please log back in after the reboot."
        if (( $(awk '{print int($1)}' /proc/uptime) > 15 )); then
            echoe nolog "\n\n>>> Regeneración en curso. Mostrando log en tiempo real (Ctrl+C para salir) ...\n\n" \
                        "\n\n>>> Regeneration in progress. Showing live log (Ctrl+C to exit) ...\n\n"
            sleep 2
            stdbuf -oL tail -F "$OR_regen_log" || true
            Salir nolog "\n>>> Log finalizado. Saliendo ...\n" \
                        "\n>>> Log ended. Exiting ...\n"
        else
            Salir ">>> Inicia 'omv-regen' de nuevo dentro de unos segundos." \
                  ">>> Please start 'omv-regen' again in a few seconds."
        fi
    fi
    Salir "${txt[1]}\n>>> Saliendo ..." \
          "${txt[1]}\n>>> Exiting ..."
fi

# Configurar Trap global
# Configure Global Trap
trap TrapSalir EXIT INT TERM

# Versiones soportadas 6.x. o 7.x.
# Supported versions 6.x. or 7.x.
[[ "$DEBIAN_CODENAME__or" =~ ^(bullseye|bookworm)$ ]] || {
    echoe nolog ">>> Versión no soportada: ${DEBIAN_CODENAME__or}.   Intentando descargar version compatible ..." \
                ">>> Unsupported version: ${DEBIAN_CODENAME__or}.   Trying to download compatible version ..."
    wget -O - "$URL_OMVREGEN_INSTALL" | bash || Salir nolog ">>> ERROR: No se pudo instalar omv-regen." \
                                                            ">>> ERROR: Could not install omv-regen."
    exit 0; }

# Asegurar que el script se ejecuta con bash
# Ensure the script runs with bash
[ -n "$BASH_VERSION" ] || { Salir ">>> Este script requiere bash. Asegúrate de ejecutarlo en un entorno con bash.  Saliendo ..." \
                                  ">>> This script requires bash. Make sure to run it in an environment with bash.  Exiting ..."; }

# Crear archivo de log
# Create log file
if [ ! -f "$OR_log_file" ]; then
    echoe nolog ">>> El archivo de log no existe. Creando $OR_log_file." \
                ">>> The log file does not exist. Creating $OR_log_file."
    touch "$OR_log_file" || Salir nolog ">>> ERROR: No se pudo crear el archivo de log." \
                                        ">>> ERROR: Could not create log file."
fi

# Crear carpeta temporal
# Create temporary folder
[ -d "$OR_tmp_dir" ] && rm -rf "$OR_tmp_dir"
mkdir -p "$OR_tmp_dir" || Salir error "Fallo inicializando carpeta temporal. Saliendo ..." \
                                      "Failed to initialize temporary folder. Exiting ..."

# Generar/recuperar/validar configuraciones
# Generate/recover/validate configurations
if [ -f "$OR_ajustes_file" ]; then
    LeerAjustes || Salir error "No se pudo leer el archivo de ajustes. Saliendo ..." \
                               "Could not read settings file. Exiting ..."
elif [ -f "/etc/regen/omv-regen.settings" ]; then
    MigrarAjustes_7_0 || Salir error "No se pudo migrar ajustes desde versiones anteriores. Saliendo ..." \
                                     "Could not migrate settings from previous versions. Exiting ..."
else
    Info 3 ">>> No hay archivo de ajustes, generando ajustes predeterminados ..." \
           ">>> No settings file, generating default settings ..."
    OmvregenReset
    [ ! -d "${OR_dir}/settings" ] && mkdir -p "${OR_dir}/settings"
    touch "$OR_ajustes_file"
    ProgramarBackup crear
fi
AjustarIdioma
SalvarAjustes || Salir error "No se pudo guardar el archivo de ajustes. Saliendo ..." \
                             "The settings file could not be saved. Exiting ..."
ConfigurarLogrotate
if ! hook_es_ok; then
    echoe ">>> El Hook no está configurado. Procediendo a su configuración." \
          ">>> Hook is not configured. Proceeding to configure it."
    ConfigurarHook || Mensaje error "No se pudo configurar el hook. ${txt[error]}" \
                                    "Could not configure hook. ${txt[error]}"
fi
ConfigurarLimpiezaHook || Mensaje error "No se pudo configurar la tarea de limpieza semanal. ${txt[error]}" \
                                        "Could not configure weekly cleaning task. ${txt[error]}"

# Continuar la regeneración si está en progreso o buscar actualizaciones de omv-regen
# Continue regeneration if in progress or check for omv-regen updates
if regen_en_progreso; then
    VIA=10
else
    ServicioReinicio eliminar
    modo_desatendido || { BuscarOR || Salir error "No se pudo buscar actualizaciones de omv-regen. Saliendo ..." \
                                                  "Could not check for updates for omv-regen. Exiting ..."; }
fi

# Entrar al menú principal
# Enter the main menu
MenuPrincipal
