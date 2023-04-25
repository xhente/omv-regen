#!/bin/bash
# -*- ENCODING: UTF-8 -*-

# This file is licensed under the terms of the GNU General Public
# License version 3. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

Back=""
Rege=""
Ruta=""
OpDias=7
OpFold=""
OpUpda=""
OpKern=1
OpRebo=""
declare -A ORB
ORB[Dpkg]='/ORB_Dpkg'
ORB[Unamea]='/ORB_Unamea'
ORB[Zpoollist]='/ORB_Zpoollist'
ORB[Systemctl]='/ORB_Systemctl'
ORB[HostnameI]='/ORB_HostnameI'
Config="/etc/openmediavault/config.xml"
Passwd="/etc/passwd"
Shadow="/etc/shadow"
Group="/etc/group"
Subuid="/etc/subuid"
Subgid="/etc/subgid"
Passdb="/var/lib/samba/private/passdb.tdb"
declare -a Archivos=( "$Config" "$Passwd" "$Shadow" "$Group" "$Subuid" "$Subgid" "$Passdb" )
declare -a Directorios=( "/home" "/etc/libvirt" )
ConfTmp="/etc/openmediavault/config.rg"
Fecha=$(date +%y%m%d_%H%M)
VersionOR=""
VersionDI=""
InstII=""
VersIdem=""
cont=0
declare -a ListaInstalar
KernelOR=""
KernelIN=""
Inst="/usr/sbin/omv-regen"
Tecla=""
EtiqOR=""
EtiqAC=""
Sysreboot="/etc/systemd/system/omv-regen-reboot.service"
ORBackup="/ORBackup"
URL="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master"
Sucio="/var/lib/openmediavault/dirtymodules.json"
IpOR=""
IpAC=""
. /etc/default/openmediavault

[ "$(cut -b 7,8 /etc/default/locale)" = es ] && Sp=1

# FUNCIONES

# Funciones OMV
. /usr/share/openmediavault/scripts/helper-functions

# Muestra el mensaje en español o inglés según el sistema.
# Opcional $1 = segundos de espera.
# Si hay espera -> Pulsar una tecla sale y devuelve Tecla=1, si no se pulsa Tecla="".
echoe () {
  Tecla=""
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    [ ! "$Sp" ] && echo -e "$2" || echo -e "$3"
    read -t"$1" -n1 -r -p "" Tecla
    if [ $? -eq 0 ]; then
      Tecla=1
    else
      Tecla=""
    fi
  else
    [ ! "$Sp" ] && echo -e "$1" || echo -e "$2"
  fi
}

help () {
  echo -e "\033[0;32m                                                                     "
  echo -e "_______________________________________________________________________________"
  echo -e "                                                                               "
  echo -e "              HELP FOR USING OMV-REGEN    (BACKUP AND REGENERATE)              "
  echo -e "                                                                               "
  echo -e "  - omv-regen   regenerates an OMV system from a clean install by restoring the"
  echo -e "    existing configurations to the original system.                            "
  echo -e "  - Install omv-regen on the original system, update and make a backup. Install"
  echo -e "    OMV on an empty disk without configuring anything.  Mount a backup, install"
  echo -e "    omv-regen and then regenerate. The version available on the internet of the"
  echo -e "    plugins and OMV must match.                                                "
  echo -e "  - Use omv-regen install     to enable omv-regen on your system.             "
  echo -e "  - Use omv-regen backup      to store the necessary information to regenerate."
  echo -e "  - Use omv-regen regenerate  to run a system regeneration from a clean OMV.   "
  echo -e "_______________________________________________________________________________"
  echo -e "                                                                               "
  echo -e "   omv-regen install     -->       Enable the command on the system.           "
  echo -e "_______________________________________________________________________________"
  echo -e "                                                                               "
  echo -e "   omv-regen backup   [OPTIONS]   [/folder_one \"/folder two\" /folder ... ]   "
  echo -e "                                                                               "
  echo -e "                                                                               "
  echo -e "    -b     Path to store the subfolders with the backups.                      "
  echo -e "                                                                               "
  echo -e "    -d     Establishes the days of age of the backups kept (by default 7 days)."
  echo -e "                          You can edit the ORB_ prefix to keep a version.      "
  echo -e "    -h     Help.                                                               "
  echo -e "                                                                               "
  echo -e "    -o     Enable optional folder backup. (by default /home /etc/libvirt)      "
  echo -e "                          Spaces to separate (can use quotes).                 "
  echo -e "    -u     Enable automatic system update before backup.                       "
  echo -e "_______________________________________________________________________________"
  echo -e "                                                                               "
  echo -e "   omv-regen regenera   [OPTIONS]   [/backup_folder]                           "
  echo -e "                                                                               "
  echo -e "                                                                               "
  echo -e "    -b     Path where the backup created by omv-regen is stored.               "
  echo -e "                                                                               "
  echo -e "    -h     Help                                                                "
  echo -e "                                                                               "
  echo -e "    -k     Skip installing the proxmox kernel.                                 "
  echo -e "                                                                               "
  echo -e "    -r     Enable automatic reboot if needed (create reboot service).          "
  echo -e "_______________________________________________________________________________"
  echo -e "                                                                        \033[0m"
  exit
}

# Analizar estado de plugin. Instalación y versiones.
Analiza () {
  VersionOR=""
  VersionDI=""
  InstII=""
  VersIdem=""
  VersionOR=$(awk -v i="$1" '$2 == i {print $3}' "${Ruta}${ORB[Dpkg]}")
  VersionDI=$(apt-cache madison "$1" | awk 'NR==1{print $3}')
  InstII=$(dpkg -l | awk -v i="$1" '$2 == i {print $1}')
  if [ "${InstII}" == "ii" ]; then
    InstII=OK
  else
    InstII=NO
  fi
  if [ "${VersionOR}" = "${VersionDI}" ]; then
    VersIdem=OK
  else
    VersIdem=NO
  fi
}

# Instalar complemento
InstalaPlugin () {
  echoe "\nInstall $1 plugin\n" "\nInstalando el complemento $1\n"
  if ! apt-get --yes install "$1"; then
    apt-get --yes --fix-broken install
    apt-get update
    if ! apt-get --yes install "$1"; then
      apt-get --yes --fix-broken install
      echoe "Failed to install $1 plugin. Exiting..." "El complemento $1 no se pudo instalar. Saliendo..."
      exit
    fi
  fi
}

# Extraer valor de una entrada de la base de datos
LeeEtiqueta () {
  EtiqOR=$(sed -n "s:.*<${1}>\(.*\)</${1}>.*:\1:p" "${Ruta}${Config}")
  echoe "The value of ${1} in Original Config is ${EtiqOR}" "El valor de ${1} en Config Original es ${EtiqOR}"
  EtiqAC=$(sed -n "s:.*<${1}>\(.*\)</${1}>.*:\1:p" "${Config}")
  echoe "The value of ${1} in Current Config is ${EtiqAC}" "El valor de ${1} en Config Actual es ${EtiqAC}"
}

# Lee campos completos entre todas las etiquetas de la seccion $1/$2
LeeSeccion () {
  ValorOR="$(xmlstarlet select --template --copy-of //"${1}"/"${2}" --nl ${Ruta}${Config})"
  echoe "The original value of ${1} ${2} is ${ValorOR}" "El valor original de ${1} ${2} es ${ValorOR}"
  ValorAC="$(xmlstarlet select --template --copy-of //"${1}"/"${2}" --nl ${Config})"
  echoe "The current value of ${1} ${2} is ${ValorAC}" "El valor actual de ${1} ${2} es ${ValorAC}"
  if [ -f "${ConfTmp}" ]; then
    ValorTM="$(xmlstarlet select --template --copy-of //"${1}"/"${2}" --nl ${ConfTmp})"
    echoe "The time value of ${1} ${2} is ${ValorTM}" "El valor temporal de ${1} ${2} es ${ValorTM}"
  else
    ValorTM=""
    echoe "The temporary value of ${1} ${2} is null" "El valor temporal de ${1} ${2} es nulo"
  fi
}

# Sustituye sección de la base de datos actual por la existente en la base de datos original
Regenera () {
  InOR=""
  FiOR=""
  InAC=""
  FiAC=""
  LoAC=""
  NmInOR=""
  NmFiOR=""
  NmInAC=""
  NmFiAC=""
  ValorOR=""
  ValorAC=""
  ValorTM=""
  echoe "Regenerating section $1 $2 of the database" "Regenerando sección $1 $2 de la base de datos"
  if [ "${2}" = "omvextras" ]; then
    omv_config_delete $2
  fi
  LeeSeccion "${1}" "${2}"
  if [ ! "${ValorOR}" = "${ValorAC}" ]; then
    echoe "Regenerating $1 $2..." "Regenerando $1 $2..."
    NmInOR="$(awk "/<${2}>/ {print NR}" "${Ruta}${Config}" | awk '{print NR}' | sed -n '$p')"
    echoe "$2 has ${NmInOR} possible starts in Original Config" "$2 tiene ${NmInOR} posibles inicios en Config Original"
    NmFiOR="$(awk "/<\/${2}>/ {print NR}" "${Ruta}${Config}" | awk '{print NR}' | sed -n '$p')"
    echoe "$2 has ${NmFiOR} possible endings in Original Config" "$2 tiene ${NmFiOR} posibles finales en Config Original"
    NmInAC="$(awk "/<${2}>/ {print NR}" "${Config}" | awk '{print NR}' | sed -n '1p')"
    echoe "$2 has ${NmInAC} possible starts in Current Config" "$2 tiene ${NmInAC} posibles inicios en Config Actual"
    NmFiAC="$(awk "/<\/${2}>/ {print NR}" "${Config}" | awk '{print NR}' | sed -n '$p')"
    echoe "$2 has ${NmFiAC} possible endings in Current Config" "$2 tiene ${NmFiAC} posibles finales en Config Actual"
    LoAC="$(awk 'END {print NR}' "${Config}")"
    echoe "Current config has ${LoAC} lines in total" "Config actual tiene ${LoAC} lineas en total"
    IO=0
    Gen=""
    while [ $IO -lt ${NmInOR} ]; do
      [ "${Gen}" ] && break
      ((IO++))
      InOR="$(awk "/<${2}>/ {print NR}" "${Ruta}${Config}" | awk -v i=$IO 'NR==i {print $1}')"
      echoe "Checking Start of $2 in Config Origin in line ${InOR}..." "Comprobando Inicio de $2 en Config Origen en linea ${InOR}..."
      FO=0
      while [ $FO -lt ${NmFiOR} ]; do
        [ "${Gen}" ] && break
        ((FO++))
        FiOR="$(awk "/<\/${2}>/ {print NR}" "${Ruta}${Config}" | awk -v i=$FO 'NR==i {print $1}')"
        echoe "Checking End of $2 in Config Origin in line ${FiOR}..." "Comprobando Final de $2 en Config Origen en linea ${FiOR}..."
        IA=0
        while [ $IA -lt ${NmInAC} ]; do
          [ "${Gen}" ] && break
          ((IA++))
          InAC="$(awk "/<${2}>/ {print NR}" ${Config} | awk -v i=$IA 'NR==i {print $1}')"
          echoe "Checking Start of $2 in Current Config in line ${InAC}..." "Comprobando Inicio de $2 en Config Actual en linea ${InAC}..."
          FA=0
          while [ $FA -lt ${NmFiAC} ]; do
            ((FA++))
            FiAC="$(awk "/<\/${2}>/ {print NR}" "${Config}" | awk -v i=$FA 'NR==i {print $1}')"
            echoe "Checking End of $2 in Current Config in line ${FiAC}..." "Comprobando Final de $2 en Config Actual en linea ${FiAC}..."
            echoe "Creating Temporary Config..." "Creando Config Temporal..."
            CreaConfTmp
            echoe "Comparing $1 $2 of Temporary Config with the Original..." "Comparando $1 $2 de Config Temporal con el Original..."
            LeeSeccion $1 $2
            if [ "${ValorOR}" = "${ValorTM}" ]; then
              Gen="OK"
              echoe "The $1 $2 section in Temporary Config and Original Config are the same. Regenerating..." "La seccion $1 $2 en Config Temporal y Config Original son iguales. Regenerando..."
              cp -a "${Config}" "${ConfTmp}ps"
              rm "${Config}"
              cp -a "${ConfTmp}" "${Config}"
              echoe "Section $1 $2 regenerated in the database. Applying changes..." "Seccion $1 $2 regenerada en base de datos. Aplicando cambios..."
              Modulos $2
              break
            else
              echoe "" "Generando Config Temporal para seccion $1 $2 ..."
            fi
          done
        done
      done
    done
    if [ ! "${Gen}" ]; then
      echoe "Generating Temporary Config for section $1 $2 ..." "No se ha podido regenerar la seccion $1 $2 en la base de datos actual. Saliendo..."
      exit
    fi
  else
    echoe "$1 $2 are the same in Original and Current Config. Exiting Regenerate function..." "$1 $2 son iguales en Config Original y Actual. Saliendo de función Regenera..."
  fi
}

# Crear config temporal
CreaConfTmp () {
  [ -f "${ConfTmp}" ] && rm "${ConfTmp}"
  cp -a "${Config}" "${ConfTmp}"
  sed -i '1,$d' "${ConfTmp}"
  awk -v IA="${InAC}" 'NR==1, NR==IA-1 {print $0}' "${Config}" > "${ConfTmp}"
  if [ "${InOR}" -eq "${FiOR}" ]; then
    awk -v IO="${InOR}" 'NR==IO {print $0}' "${Ruta}${Config}" >> "${ConfTmp}"
  else
    awk -v IO="${InOR}" -v FO="${FiOR}" 'NR==IO, NR==FO {print $0}' "${Ruta}${Config}" >> "${ConfTmp}"
  fi
  awk -v FA="${FiAC}" -v LA="${LoAC}" 'NR==FA+1, NR==LA {print $0}' "${Config}" >> "${ConfTmp}"
}

# Configura módulos salt
Modulos () {
  case $1 in
    time)
      Mod="chrony cron timezone"
      ;;
    certificates)
      Mod="certificates"
      ;;
    webadmin)
      Mod="monit nginx"
      ;;
    powermanagement)
      Mod="cpufrequtils cron systemd-logind"
      ;;
    monitoring)
      Mod="collectd monit rrdcached"
      ;;
    crontab)
      Mod="cron"
      ;;
    fstab)
      Mod="hdparm collectd fstab monit quota initramfs mdadm"
      ;;
    homedirectory)
      Mod="samba"
      ;;
    users)
      Mod="postfix rsync samba systemd ssh"
      ;;
    groups)
      Mod="rsync samba systemd"
      ;;
    shares)
      Mod="systemd"
      ;;
    smart)
      Mod="smartmontools"
      ;;
    nfs)
      Mod="avahi collectd fstab monit nfs quota"
      ;;
    rsync)
      Mod="rsync avahi rsyncd"
      ;;
    smb)
      Mod="avahi samba"
      ;;
    ssh)
      Mod="avahi samba"
      ;;
    email)
      Mod="cronapt mdadm monit postfix smartmontools"
      ;;
    notification)
      Mod="cronapt mdadm monit smartmontools"
      ;;
    syslog)
      Mod="rsyslog"
      ;;
    dns)
      Mod="avahi hostname hosts postfix systemd-networkd"
      ;;
    interfaces)
      Mod="avahi halt hosts issue systemd-networkd"
      ;;
    proxy)
      Mod="apt profile"
      ;;
    iptables)
      Mod="iptables hdparm"
      ;;
    zfs)
      Mod="zfszed collectd fstab monit quota"
      ;;
    omvextras)
      Mod="omvextras"
      ;;
    *)
      echoe "Changes cannot be applied to modules in section $1. Undoing changes..." "No se puede aplicar cambios a los módulos de la sección $1. Deshaciendo cambios..."
      cp -a "${ConfTmp}ps" "${Config}"
      echoe "The regeneration could not be completed. Coming out..." "No se ha podido completar la regeneración. Saliendo..."
      exit
  esac
  Aplica "${Mod}"
}

Aplica () {
  for i in "$@"; do
    echoe "Configuring $i..." "Configurando $i..."
    omv-salt deploy run "$i"
    echoe 1 "$i configured." "$i configurado."
  done
  Resto="$(cat "${Sucio}")"
  if [[ ! "${Resto}" == "[]" ]]; then
    omv-salt deploy run "$(jq -r .[] ${Sucio} | tr '\n' ' ')"
  fi
}

# Instalar omv-regen
InstalarOR (){
  if [ ! "$0" = "${Inst}" ];then
    if [ -f "${Inst}" ]; then
      rm "${Inst}"
    fi
    touch "${Inst}"
    if [ -f "$0" ]; then
      cp -a "$0" "${Inst}"
    else
      Archivo=$(wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh)
      echo "${Archivo}" > "${Inst}"
    fi
    chmod +x "${Inst}"
    echoe "\n  omv-regen has been installed.\n" "\n  omv-regen se ha instalado.\n"
  else
    echoe "\n  omv-regen was already installed.\n" "\n  omv-regen ya estaba instalado.\n"
  fi
  echoe "Showing the usage:\n" "Mostrando el uso:\n"
  help
}

# Crear servicio reboot
Creasysreboot (){
  echoe "Generating reboot service..." "Generando servicio de reinicio..."
  if [ -f "${Sysreboot}" ]; then
    rm "${Sysreboot}"
  fi
  touch "${Sysreboot}"
  echo "[Unit]
Description=reboot omv-regen service
After=network.target network-online.target
Wants=network-online.target

[Service]
ExecStartPre=/bin/sleep 60
ExecStart=${Comando}

[Install]
WantedBy=multi-user.target" > "${Sysreboot}"
}

# VALIDA ENTORNO

# Root
if [[ $(id -u) -ne 0 ]]; then
  echoe "Run omv-regen with sudo or as root.  Exiting..." "Ejecuta omv-regen con sudo o como root.  Saliendo..."
  help
fi

# Deshabilitar reboot.
if [ -f "${Sysreboot}" ]; then
  Habilit=$(systemctl list-unit-files | grep omv-regen-reboot | awk '{print $2}')
  if [ "${Habilit}" = "enabled" ]; then
    echoe "Disabling reboot..." "Deshabilitando reinicio..."
    systemctl disable omv-regen-reboot.service
  fi
fi

# Release 6.x.
if [ ! "$(lsb_release --codename --short)" = "bullseye" ]; then
  echoe "Unsupported version.  Only OMV 6.x. are supported.  Exiting..." "Versión no soportada.   Solo está soportado OMV 6.x.   Saliendo..."
  help
fi

# Comprobar si omv-regen está instalado
if [ ! "$0" = "${Inst}" ]; then
  if [ "$1" = "install" ] || [ "$1" = "" ]; then
    InstalarOR
  else
    echoe "omv-regen is not installed.\nTo install it run omv-regen install\nExiting..." "omv-regen no está instalado.\nPara instalarlo ejecuta omv-regen install\nSaliendo..."
    help
  fi
fi

# PROCESA ARGUMENTOS

# Almacenar argumentos de ejecución.
Comando="$0"
for i in "$@"; do
  Comando="${Comando} $i"
done

# Procesa primer argumento
case "$1" in
  backup)
    Back=1
    echoe  "\n       <<< Backup to regenerate system dated ${Fecha} >>>\n" "\n       <<< Backup para regenerar sistema de fecha ${Fecha} >>>\n"
    ;;
  regenera)
    Rege=1
    echoe  "\n       <<< Regenerating OMV system >>>\n" "\n       <<< Regenerando sistema OMV >>>\n"
    ;;
  install)
    InstalarOR
    ;;
  help)
    help
    ;;
  *)
    InstalarOR
    ;;
esac
shift

# Procesa parámetros backup
if [ $Back ]; then
  while getopts "b:d:ho:u" opt; do
    case "$opt" in
      b)
        if [ -d "${OPTARG}" ]; then
          Ruta="${OPTARG}"
          echoe "The backup will be stored in ${Ruta}" "El backup se almacenará en ${Ruta}"
        else
          echoe "The folder ${OPTARG} does not exist. Exiting..." "La carpeta ${OPTARG} no existe. Saliendo..."
          help
        fi
        ;;
      d)
        if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
          OpDias=$OPTARG
          echoe "Backups older than $OpDias days will be deleted." "Se eliminarán los backups de mas de $OpDias días de antigüedad."
        else
          echoe "The -d option must be a number. Coming out..." "La opción -d debe ser un número. Saliendo..."
          help
        fi
        ;;
      h)
        help
        ;;
      o)
        if [ -d "${OPTARG}" ]; then
          OpFold="${OPTARG}"
          echoe "The folder ${OpFold} is to be copied." "La carpeta ${OpFold} se va a copiar."
        else
          echoe "The folder ${OPTARG} does not exist. Exiting..." "La carpeta ${OPTARG} no existe. Saliendo..."
          help
        fi
        ;;
      u)
        OpUpda=1
        echoe "The system will be updated before making the backup." "Se va a actualizar el sistema antes de hacer el backup."
        ;;
      *)
        echoe "Invalid argument. Exiting..." "Argumento inválido. Saliendo..."
        help
        ;;
    esac
  done
fi

# Procesa parámetros regenera
if [ $Rege ]; then
  while getopts "b:hkr" opt; do
    case "$opt" in
      b)
        if [ -d "${OPTARG}" ]; then
          Ruta="${OPTARG}"
          echoe "${Ruta} has been set as data source." "Se ha establecido ${Ruta} como origen de datos."
        else
          echoe "The folder ${OPTARG} does not exist. Exiting..." "La carpeta ${OPTARG} no existe. Saliendo..."
          help
        fi
        ;;
      h)
        help
        ;;
      k)
        OpKern=""
        echoe "The proxmox kernel will not be installed." "No se instalará el kernel proxmox."
        ;;
      r)
        OpRebo=1
        echoe 3 "It will automatically reboot the system after installing a kernel." "Se reiniciará automáticamente el sistema después de instalar un kernel."
        ;;
      *)
        echoe "Invalid argument. Exiting..." "Argumento inválido. Saliendo..."
        help
        ;;
    esac
  done
fi

# Procesa resto de argumentos 
shift $((OPTIND -1))
if [ "$Back" ] && [ "$1" ]; then
  if [ "${OpFold}" ]; then
    for i in "$@"; do
      if [ -d "$i" ]; then
        echoe "The folder $i is to be copied." "La carpeta $i se va a copiar."
      else
        echoe "The folder $i does not exist. Coming out..." "La carpeta $i no existe. Saliendo..."
        help
      fi
    done
  else
  echoe "Invalid argument. Coming out..." "Argumento inválido. Saliendo..."
  help
  fi
fi

if [ "$Back" ] && [ ! "${Ruta}" ]; then
  echoe "No backup folder has been set. It will be stored in ${ORBackup}" "No se ha establecido carpeta para el backup. Se almacenará en ${ORBackup}"
  if [ ! -d "${ORBackup}" ]; then
    mkdir -p "${ORBackup}"
  fi
  Ruta="${ORBackup}"
fi

if [ "$Rege" ]; then
  if [ "$2" ]; then
    echoe "Invalid argument $2 Exiting..." "Argumento inválido $2 Saliendo..."
    help
  else
    if [ "$1" ]; then
      if [ "${Ruta}" ]; then
        echoe "Invalid argument $1 Exiting..." "Argumento inválido $1 Saliendo..."
        help
      else
        if [ -d "$1" ]; then
          Ruta="$1"
          echoe "${Ruta} has been set as data source." "Se ha establecido ${Ruta} como origen de datos."
        else
          echoe "The folder $1 does not exist. Exiting..." "La carpeta $1 no existe. Saliendo..."
          help
        fi
      fi
    else
      if [ ! "${Ruta}" ]; then
        echoe "The source path of the backup to rebuild is missing. Exiting..." "Falta la ruta de origen del backup para regenerar. Saliendo..."
        help
      fi
    fi
  fi
fi

# EJECUTA BACKUP

# Opción actualizar
if [ "$OpUpda" ]; then
  if ! omv-upgrade; then
    echoe "Failed updating system. Exiting..." "Error actualizando el sistema.  Saliendo..."
    exit
  fi
fi

if [ $Back ]; then

  # Crea carpeta Destino
  Destino="${Ruta}/ORB_${Fecha}"
  echoe 3 "A backup is going to be made in ${Destino} \nPress any key within 3 seconds to  ABORT" "Se va a realizar un backup en ${Destino} \nPulsa cualquier tecla antes de 3 segundos para  ABORTAR"
  if [ "${Tecla}" ]; then
    echoe "Exiting..." "Saliendo..."
    help
  else
    if [ -d "${Destino}" ]; then
      rm "${Destino}"
    fi
    mkdir -p "${Destino}"
  fi

# Copia directorios opcionales
  if [ "${OpFold}" ]; then
    echoe ">>>    Copying optional $OpFold directory..." ">>>    Copiando directorio opcional $OpFold..."
    mkdir -p "${Destino}$OpFold"
    rsync -av "$OpFold"/ "${Destino}$OpFold"
    while [ "$*" ]; do
      echoe ">>>    Copying optional ${1} directory..." ">>>    Copiando directorio opcional ${1}..."
      mkdir -p "${Destino}$OpFold"
      rsync -av "${1}"/ "${Destino}${1}"
      shift
    done
  fi

  # Copiar directorios existentes predeterminados
  for i in "${Directorios[@]}"; do
    if [ -d "$i" ]; then
      echoe ">>>    Copying $i directory..." ">>>    Copiando directorio $i..."
      if [ ! -d "${Destino}$i" ]; then
        mkdir -p "${Destino}$i"
      fi
      rsync -av "$i"/ "${Destino}$i"
    fi
  done

  # Copiar archivos predeterminados
  echoe ">>>    Copying files to ${Destino}..." ">>>    Copiando archivos a ${Destino}..."
  for i in "${Archivos[@]}"; do
    if [ ! -d "$(dirname "${Destino}$i")" ]; then
      mkdir -p "$(dirname "${Destino}$i")"
    fi
    cp -apv "$i" "${Destino}$i"
  done

  # Crea registro dpkg
  echoe ">>>    Extracting version list (dpkg)..." ">>>    Extrayendo lista de versiones (dpkg)..."
  dpkg -l | grep openmediavault > "${Destino}${ORB[Dpkg]}"
  awk '{print $2" "$3}' "${Destino}${ORB[Dpkg]}"

  # Crea registro uname -a
  echoe ">>>    Extracting system info (uname -a)..." ">>>    Extrayendo información del sistema (uname -a)..."
  uname -a | tee "${Destino}${ORB[Unamea]}"

  # Crea registro zpool list
  echoe ">>>    Extracting zfs info (zpool list)..." ">>>    Extrayendo información de zfs (zpool list)..."
  zpool list | tee "${Destino}${ORB[Zpoollist]}"

  # Crea registro docker systemctl
  echoe ">>>    Extracting information from systemd (systemctl)..." ">>>    Extrayendo información de systemd (systemctl)..."
  systemctl list-unit-files | tee "${Destino}${ORB[Systemctl]}"

  # Crea registro de configuracion de red
  echoe ">>>    Retrieving network information (hostname -I)..." ">>>    Extrayendo información de red (hostname -I)..."
  hostname -I | tee "${Destino}${ORB[HostnameI]}"

  # Elimina backups antiguos
  echoe ">>>    Deleting backups larger than ${OpDias} days..." ">>>    Eliminando backups de hace más de ${OpDias} días..."
  find "${Ruta}/" -maxdepth 1 -type d -name "ORB_*" -mtime "+$OpDias" -exec rm -rv {} +
  # Nota:   -mmin = minutos  ///  -mtime = dias
  
  echoe "\n       Backup completed!\n" "\n       ¡Backup completado!\n"
  exit
fi

# EJECUTA REGENERACION DE SISTEMA

echoe 5 "\n\nThe REGENERATION OF THE CURRENT SYSTEM will be executed from ${Ruta} \nPress any key within 5 seconds to  ABORT....." "\n\nSe va a ejecutar la  REGENERACION DEL SISTEMA ACTUAL  desde ${Ruta} \nPulsa cualquier tecla antes de 5 segundos para  ABORTAR....."
if [ "${Tecla}" ]; then
  echoe "Exiting..." "Saliendo..."
  help
fi

# Comprobar backup
for i in "${ORB[@]}"; do
  if [ ! -f "${Ruta}$i" ]; then
    echoe "Missing file $i in ${Ruta}. Coming out..." "Falta el archivo $i en ${Ruta}.  Saliendo..."
    help
  fi
done

# Versión de OMV original
Analiza "openmediavault"
if [ "${VersIdem}" = "NO" ]; then
  echoe "The OMV version of the original server does not match.  Exiting..." "La versión de OMV del servidor original no coincide.  Saliendo..."
  help
fi

# Actualizar sistema
if ! omv-upgrade; then
  echoe "Failed updating system.  Exiting..." "Error actualizando el sistema.  Saliendo..."
  exit
fi

# 1-Regenerar sección Sistema.
Dif=""
Dif="$(diff "${Ruta}${Passwd}" ${Passwd})"
if [ "${Dif}" ]; then
  cp -apv "${Ruta}${Passwd}" "${Passwd}"
  echoe "Regenerating basic System settings..." "Regenerando ajustes básicos de Sistema..."
  Regenera system time
  Regenera system certificates
  Regenera config webadmin
  Regenera system powermanagement
  Regenera system monitoring
  Regenera system crontab
  Regenera system syslog
  echoe "Preparing database configurations (may take time)..." "Preparando configuraciones de la base de datos (puede tardar)..."
  omv-salt stage run prepare
  echoe "Updating database configurations (may take time)..." "Actualizando configuraciones de la base de datos (puede tardar)..."
  omv-salt stage run deploy
fi

# 2-Instalar omv-extras si estaba y no está instalado.
Analiza "openmediavault-omvextrasorg"
if [ "${VersionOR}" ] &&  [ "${InstII}" = "NO" ]; then
  echoe "Installing omv-extras..." "Instalando omv-extras..."
  echoe "Downloading omv-extras.org plugin for openmediavault 6.x ..." "Descargando el complemento omv-extras.org para openmediavault 6.x ..."
  File="openmediavault-omvextrasorg_latest_all6.deb"
  if [ -f "${File}" ]; then
    rm ${File}
  fi
  wget "${URL}/${File}"
  if [ -f "${File}" ]; then
    if ! dpkg --install ${File}; then
      echoe "Installing other dependencies ..." "Instalando otras dependencias ..."
      apt-get --yes --fix-broken install
      Analiza "openmediavault-omvextrasorg"
      if [[ "${InstII}" = "NO" ]]; then
        echoe "omv-extras failed to install correctly.  Trying to fix with omv-salt deploy run ..." "omv-extras no se pudo instalar correctamente. Intentando corregir con omv-salt deploy run ..."
        if omv-salt deploy run omvextras; then
          echoe "Trying to fix apt ..." "Tratando de corregir apt..."
          apt-get --yes --fix-broken install
        else
          echoe "omv-salt deploy run failed and openmediavault-omvextrasorg is in a bad state. Exiting..." "omv-salt deploy run falló y openmediavault-omvextrasorg está en mal estado. Saliendo..."
          exit 3
        fi
      fi
      Analiza "openmediavault-omvextrasorg"
      if [[ "${InstII}" = "NO" ]]; then
        echoe "openmediavault-omvextrasorg package failed to install or is in a bad state. Exiting..." "El paquete openmediavault-omvextrasorg no se pudo instalar o está en mal estado. Saliendo..."
        exit 3
      fi
    fi
    echoe "Updating repos ..." "Actualizando repositorios..."
    omv-salt deploy run omvextras
  else
    echoe "There was a problem downloading the package. Exiting..." "Hubo un problema al descargar el paquete. Saliendo..."
    exit
  fi
fi

# Analizar versiones y complementos especiales
cont=0
for i in $(awk '{print NR}' "${Ruta}${ORB[Dpkg]}"); do
  Plugin=$(awk -v i="$i" 'NR==i{print $2}' "${Ruta}${ORB[Dpkg]}")
  Analiza "${Plugin}"
  if [ "${InstII}" = "NO" ]; then
    echoe "Versions $VersIdem \tInstalled $InstII \t${Plugin} \c" "Versiones $VersIdem \tInstalado $InstII \t${Plugin} \c"
    case "${Plugin}" in
      *"kernel" ) ;;
      *"zfs" ) ;;
      *"mergerfs" ) ;;
      *"remotemount" ) ;;
      *"sharerootfs" ) ;;
      * )
        (( cont++ ))
        ListaInstalar[cont]="${Plugin}"
        ;;
    esac
    if [ "${VersIdem}" = "NO" ]; then
      echoe "\t************\n********** ERROR: Available version $VersionDI The original system version $VersionOR does not match. Exiting..." "\t**********\n********** ERROR:  Versión disponible $VersionDI La versión del sistema original $VersionOR no coincide. Saliendo..."
      help
    else
      echoe "--> It will install..." "  -->  Se va a instalar..."
    fi
  fi
done

# 3-Instalar openmediavault-kernel
Analiza openmediavault-kernel
if [ "${VersionOR}" ] && [ "${VersIdem}" = "OK" ] && [ "${InstII}" = "NO" ]; then
  InstalaPlugin openmediavault-kernel
  # Instalar Kernel proxmox si no se ha deshabilitado la opción y estaba instalado
  if [ $OpKern ]; then
    KernelOR=$(awk '{print $3}' "${Ruta}${ORB[Unamea]}" | awk -F "." '/pve$/ {print $1"."$2}')
    KernelIN=$(uname -r | awk -F "." '/pve$/ {print $1"."$2}')
    if [ "${KernelOR}" ] && [ ! "${KernelOR}" = "${KernelIN}" ]; then
      echoe "Installing proxmox kernel ${KernelOR}" "Instalando kernel proxmox ${KernelOR}"
      cp -a /usr/sbin/omv-installproxmox /tmp/installproxmox
      sed -i 's/^exit 0.*$/echo "Completado"/' /tmp/installproxmox
      . /tmp/installproxmox "${KernelOR}"
      rm /tmp/installproxmox
      echoe "Kernel proxmox ${KernelOR} installed." "Kernel proxmox ${KernelOR} instalado."
      if [ "${OpRebo}" ]; then
        echoe "\nAuto reboot option enabled.\nTo use the new kernel the system will be rebooted.\nThe regeneration will continue in the background.\nDo not shut down the server." "\nOpción reinicio automático activada.\nPara utilizar el nuevo kernel se va a reiniciar el sistema.\nLa regeneración continuará en segundo plano.\nNo apagues el servidor."
        echoe 10 "\nTo   ABORT RESET   press a key within 10 seconds..." "\nPara   ABORTAR REINICIO   presiona una tecla antes de 10 segundos..."
        if [ "${Tecla}" ]; then
          echoe "Reboot aborted.\n" "Reinicio abortado.\n"
        else
          Creasysreboot
          systemctl enable omv-regen-reboot.service
          echoe 3 "Reboot service enabled." "Servicio de reinicio habilitado."
          echoe "Rebooting..." "Reiniciando..."
          reboot
          exit
        fi
      fi
      echoe "\nAuto reboot option disabled.\nTo use the new kernel you must reboot the system manually.\n\n\033[0;32m To complete the regeneration -> AFTER REBOOT RUN AGAIN omv-regen regenerates\n\n\033 [0m Leaving..." "\nOpción reinicio automático deshabilitada.\nPara utilizar el nuevo kernel debes reiniciar el sistema manualmente.\n\n\033[0;32m Para completar la regeneración -> DESPUES DE REINICIAR EJECUTA DE NUEVO omv-regen regenera\n\n\033[0m Saliendo..."
      exit
    fi
  fi
fi

# MONTAR SISTEMAS DE ARCHIVOS.

# 4-Instala sharerootfs. Regenera fstab (Sistemas de archivos EXT4 BTRFS mdadm)
Analiza openmediavault-sharerootfs
if [ "${InstII}" = "NO" ]; then
  echoe "Mounting filesystems..." "Montando sistemas de archivos..."
  InstalaPlugin openmediavault-sharerootfs
  Regenera system fstab
  # Cambia UUID disco de sistema si es nuevo
  echoe "Configuring openmediavault-sharerootfs..." "Configurando openmediavault-sharerootfs..."
  uuid="79684322-3eac-11ea-a974-63a080abab18"
  if [ "$(omv_config_get_count "//mntentref[.='${uuid}']")" = "0" ]; then
    omv-confdbadm delete --uuid "${uuid}" "conf.system.filesystem.mountpoint"
  fi
  apt-get install --reinstall openmediavault-sharerootfs
fi

# 5-Instalar openmediavault-zfs. Importar pools. (Sistemas de archivos ZFS)
Analiza openmediavault-zfs
if [ "${VersionOR}" ] && [ "${VersIdem}" = OK ] && [ "${InstII}" = "NO" ]; then
  InstalaPlugin openmediavault-zfs
  for i in $(awk 'NR>1{print $1}' "${Ruta}${ORB[Zpoollist]}"); do
    zpool import -f "$i"
  done
  Modulos zfs
fi

# 6-Instalar mergerfs
Analiza openmediavault-mergerfs
if [ "${VersionOR}" ] && [ "${VersIdem}" = OK ] && [ "${InstII}" = "NO" ]; then
  InstalaPlugin openmediavault-mergerfs
  # Modulos
  
  
fi

# 7-Instalar remotemount
Analiza openmediavault-remotemount
if [ "${VersionOR}" ] && [ "${VersIdem}" = OK ] && [ "${InstII}" = "NO" ]; then
  InstalaPlugin openmediavault-remotemount
  # Modulos
  
  
fi

# REGENERAR RESTO DE GUI. INSTALAR DOCKER Y COMPLEMENTOS

# 8-Restaurar archivos. Regenerar Usuarios. Carpetas compartidas. Smart. Servicios. Red. omv-extras (docker).
Dif=$(diff "${Ruta}${Shadow}" "${Shadow}")
if [ "${Dif}" ]; then
  echoe "Restoring files..." "Restaurando archivos..."
  rsync -av "${Ruta}"/ / --exclude "${Config}" --exclude /ORB_*
  echoe "Regenerating users..." "Regenerando usuarios..."
  Regenera usermanagement homedirectory
  Regenera usermanagement users
  Regenera usermanagement groups
  echoe "Regenerating shared folders..." "Regenerando carpetas compartidas..."
  Regenera system shares
  echoe "Regenerating SMART..." "Regenerando SMART..."
  Regenera services smart
  echoe "Regenerating Services..." "Regenerando Servicios..."
  Regenera services nfs
  Regenera services rsync
  Regenera services smb
  Regenera services ssh
  Regenera system email
  Regenera system notification
  Regenera system syslog
  echoe "Regenerating Network..." "Regenerando Red..."
  Regenera network dns
  Regenera network proxy
  Regenera network iptables
  echoe "Preparing database configurations (may take time)..." "Preparando configuraciones de la base de datos (puede tardar)..."
  omv-salt stage run prepare
  echoe "Updating database configurations (may take time)..." "Actualizando configuraciones de la base de datos (puede tardar)..."
  omv-salt stage run deploy
fi

# 9-Instalar docker en la ubicacion original si estaba instalado y no está instalado
DockerOR=$(awk '/docker.service/ {print $2}' "${Ruta}${ORB[Systemctl]}")
DockerII=$(systemctl list-unit-files | grep docker.service | awk '{print $2}')
if [ "${DockerOR}" ] && [ ! "${DockerII}" ]; then
  echoe "Installing docker..." "Instalando docker..."
  echoe "Regenerating omvextras..." "Regenerando omvextras..."
  Regenera system omvextras
  DockerII=$(systemctl list-unit-files | grep docker.service | awk '{print $2}')
  if [ ! "${DockerII}" ]; then
    LeeEtiqueta dockerStorage
    dockerStorage="${EtiqOR}"
    cp -a /usr/sbin/omv-installdocker /tmp/installdocker
    sed -i 's/^exit 0.*$/echo "Salida installdocker"/' /tmp/installdocker
    . /tmp/installdocker "${dockerStorage}"
    rm /tmp/installdocker
    echoe "Docker installed." "Docker instalado."
  fi
fi

# 10-Instalar resto de complementos
for i in "${ListaInstalar[@]}"; do
  Analiza "$i"
  if [ "${VersIdem}" = OK ] && [ "${InstII}" = "NO" ]; then
    InstalaPlugin "$i"
  fi
done

# Instalar paquetes de apttools
# Extraer symlinks base de datos y crear

omv-salt stage run prepare
omv-salt stage run deploy

# Elimina archivos temporales
[ -f "${ConfTmp}ps" ] && rm "${ConfTmp}ps"
[ -f "${ConfTmp}" ] && rm "${ConfTmp}"

IpAC=$(hostname -I | awk '{print $1}')
IpOR=$(awk '{print $1}' "${Ruta}${ORB[HostnameI]}")
if [ ! "${IpOR}" = "${IpAC}" ]; then
  echoe 10 "It will regenerate the network interface and restart the server.\nAfter restart you will be able to access from IP ${IpOR}\n\nPress any key within 10 seconds to  ABORT  network configuration." "Se va a regenerar la interfaz de red y reiniciar el servidor.\nDespués de reiniciar podrás acceder desde la IP ${IpOR}\n\nPresiona cualquier tecla antes de 10 segundos para  ABORTAR  la configuración de red."
  if [ "${Tecla}" ]; then
    Tecla=""
    echoe "\nNetwork configuration aborted.\n\nSystem regeneration finished!!\n\nIP after reboot will remain ${IpAC} Rebooting...\n" "\nConfiguración de red abortada.\n\nLa regeneración del sistema ha finalizado!!\n\nLa IP después de reiniciar seguirá siendo ${IpAC} Reiniciando...\n"
    reboot
    echoe 3 "" ""
    exit
  fi
fi

echoe "Configuring network..." "Configurando red..."
Regenera network interfaces
echoe "\n\nSystem regeneration finished!!\n\nIP after reboot will be ${IpOR} Rebooting..." "\n\nLa regeneración del sistema ha finalizado!!\n\nLa IP después de reiniciar será ${IpOR} Reiniciando..."
reboot
echoe 3 "" ""
exit