#!/bin/bash
# -*- ENCODING: UTF-8 -*-

Back=""
Rege=""
Ruta=""
OpDias=7
OpUpda=""
OpKern=1
declare -A ROB
ROB[Dpkg]='/ROB_Dpkg'
ROB[Unamea]='/ROB_Unamea'
ROB[Zpoollist]='/ROB_Zpoollist'
Config="/etc/openmediavault/config.xml"
Passwd="/etc/passwd"
Shadow="/etc/shadow"
declare -a Archivos=( "$Config" "$Passwd" "$Shadow" )
declare -a Directorios=( "/home" "/etc/libvirt/qemu" "/etc/wireguard" )
Fecha=$(date +%y%m%d_%H%M)
VersionOR=""
VersionDI=""
InstII=""
VersIdem=""
confCmd="omv-salt deploy run"
cont=0
declare -a ListaInstalar
KernelOR=""
KernelIN=""
URL="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master"
confCmd="omv-salt deploy run"

[ "$(cut -b 7,8 /etc/default/locale)" = es ] && Sp=1
echoe () { [ ! "$Sp" ] && echo -e "$1" || echo -e "$2"; }

help () {
  echo -e "                                                                                       "
  echo -e "               HELP FOR USING OMV-REGEN      (BACKUP AND REGENERATE)                   "
  echo -e "                                                                                       "
  echo -e "  - omv-regen regenerates an OMV system from a clean install by restoring the existing "
  echo -e "  configurations to the original system.                                               "
  echo -e "  - Update the system. Install omv-regen on the original system and make a backup. Then"
  echo -e "  install OMV on an empty disk without configuring anything. Then Install omv-regen and"
  echo -e "  mount the backup on a flash drive, then regenerate.  The version available on the in-"
  echo -e "  ternet must match.                                                                   "
  echo -e "  - Use omv-regen backup      to store the necessary information to regenerate.        "
  echo -e "  - Use omv-regen regenerate  to run a system regeneration from a clean install of OMV."
  echo -e "  - This script must be executed as root or using sudo.                                "
  echo -e "  - Only OMV 6.x. are supported.                                                       "
  echo -e "_______________________________________________________________________________________"
  echo -e "    omv-regen backup PATH_TO_BACKUP [OPTIONS] [/folder1 \"/folder 2\" /folder3...]     "
  echo -e "                                                                                       "
  echo -e "      Options and parameters:                                                          "
  echo -e "        PATH_TO_BACKUP  Path to store the folders with the backups.                    "
  echo -e "              -d        Delete backups older than X days (by default 7 days). You can  "
  echo -e "                        edit a folder's prefix (ROB_) to prevent it from being deleted."
  echo -e "              -u        Update system before backup. Use if it is going to regenerate  "
  echo -e "                        immediately.                                                   "
  echo -e "          [folders]     Optional folders to add to the backup. Separate with spaces.   "
  echo -e "                        Use quotes for paths with spaces.                              "
  echo -e "_______________________________________________________________________________________"
  echo -e "    omv-regen regenera PATH_TO_BACKUP [OPTIONS]                                        "
  echo -e "                                                                                       "
  echo -e "      Options and parameters:                                                          "
  echo -e "        PATH_TO_BACKUP  Path where the backup is stored with the data to regenerate.   "
  echo -e "              -k        Skip installing the proxmox kernel.                            "
  echo -e "                                                                                       "
  exit
}

# Analizar estado de plugin. Instalación y versiones.
Analiza () {
  VersionOR=""
  VersionDI=""
  InstII=""
  VersionOR=$(awk -v i="$1" '$2 == i {print $3}' "${Ruta}${ROB[Dpkg]}")
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
    "${confCmd}" "$1"
    apt-get --yes --fix-broken install
    echoe "Failed to install $1 plugin. Exiting..." "El complemento $1 no se pudo instalar. Saliendo..."
    exit
  fi
}

# Root
if [[ $(id -u) -ne 0 ]]; then
  echoe "This script must be executed as root or using sudo.  Exiting..." "Este script se debe ejecutar como root o usando sudo.  Saliendo..."
  help
fi

# Eliminar programación de ejecución tras reinicio. Recopilar información para reinicio.
if [ -f /etc/cron.d/omvregenreboot ]; then
  rm /etc/cron.d/omvregenreboot
fi
Comando=$0
for i in "$@"; do
  Comando="${Comando} $i"
done

# Release 6.x.
if [ ! "$(lsb_release --codename --short)" = "bullseye" ]; then
  echoe "Unsupported version.  Only OMV 6.x. are supported.  Exiting..." "Versión no soportada.   Solo está soportado OMV 6.x.   Saliendo..."
  help
fi

# Procesa parámetros y argumentos
if [[ $1 == "backup" ]]; then
  Back=1
  echoe  "\n       <<< Backup to regenerate system dated ${Fecha} >>>\n" "\n       <<< Backup para regenerar sistema de fecha ${Fecha} >>>\n"
elif [[ $1 == "regenera" ]]; then
  Rege=1
  echoe  "\n       <<< Regenerating OMV system >>>\n" "\n       <<< Regenerando sistema OMV >>>\n"
else  
  help
fi

if [ -d "${2}" ]; then
  Ruta="$2"
  shift 2
else
  echoe "TRADUCCION" "La ruta $2 no existe. Saliendo..."
  help
fi

if [ $Back ]; then
  while getopts "d:hu" opt; do
    case "$opt" in
      d)
        OpDias=$OPTARG
        echoe "TRADUCCION" "Se eliminarán los backups de mas de $OpDias días de antigüedad."
        ;;
      h)
        help
        ;;
      u)
        OpUpda=1
        ;;
      *)
        echoe "Invalid argument. Exiting..." "Argumento inválido. Saliendo..."
        help
        ;;
    esac
  done
fi

if [ $Rege ]; then
  while getopts "hk" opt; do
    case "$opt" in
      h)
        help
        ;;
      k)
        OpKern=""
        echoe "TRADUCCION" "No se instalará el kernel proxmox."
        ;;
      *)
        echoe "Invalid argument. Exiting..." "Argumento inválido. Saliendo..."
        help
        ;;
    esac
  done
fi

shift $((OPTIND -1))
if [[ -n "$Rege" && -n $1 ]]; then
  echoe "$1 Invalid argument. Exiting..." "$1 Argumento inválido. Saliendo..."
  help
else
  for i in "$@"; do
    if [ -d "$i" ]; then
      echoe "TRADUCCION" "La carpeta $i se va a copiar."
    else  
      echoe "TRADUCCION" "La carpeta $i no existe o no es accesible. Saliendo..."
      help
    fi
  done
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
  Destino="${Ruta}/omv-regen/ROB_${Fecha}"
  if [ -d "${Destino}" ]; then
    rm "${Destino}"
  fi
  mkdir -p "${Destino}"

  # Copiar directorios existentes de la lista
  for i in "${Directorios[@]}"; do
    if [ -d "$i" ]; then
      echoe ">>>    Copying $i directory..." ">>>    Copiando directorio $i..."
      if [ ! -d "${Destino}$i" ]; then
        mkdir -p "${Destino}$i"
      fi
      rsync -av "$i"/ "${Destino}$i"
    fi
  done

  # Copiar archivos de la lista
  echoe ">>>    Copying files to ${Destino}..." ">>>    Copiando archivos a ${Destino}..."
  for i in "${Archivos[@]}"; do
    if [ ! -d "$(dirname "${Destino}$i")" ]; then
      mkdir -p "$(dirname "${Destino}$i")"
    fi
    cp -apv "$i" "${Destino}$i"
  done

  # Crea registro dpkg
  echoe ">>>    Extracting version list (dpkg)..." ">>>    Extrayendo lista de versiones (dpkg)..."
  dpkg -l | grep openmediavault > "${Destino}${ROB[Dpkg]}"
  cat "${Destino}${ROB[Dpkg]}" | awk '{print $2" "$3}'

  # Crea registro uname -a
  echoe ">>>    Extracting system info (uname -a)..." ">>>    Extrayendo información del sistema (uname -a)..."
  uname -a | tee "${Destino}${ROB[Unamea]}"

  # Crea registro zpool list
  echoe ">>>    Extracting zfs info (zpool list)..." ">>>    Extrayendo información de zfs (zpool list)..."
  zpool list | tee "${Destino}${ROB[Zpoollist]}"
    
  # Copia directorios opcionales
  while [ "$*" ]; do
    echoe ">>>    Copying optional $1 directory..." ">>>    Copiando directorio opcional $1..."
    rsync -av "$1"/ "${Destino}/ROB_OptionalFolders$1"
    shift
  done

  # Elimina backups antiguos
  echoe ">>>    Deleting backups larger than ${OpDias} days..." ">>>    Eliminando backups de hace más de ${OpDias} días..."
  find "${Ruta}/omv-regen/" -maxdepth 1 -type d -name "ROB_*" -mtime "+$OpDias" -exec rm -rv {} +
  # Nota:   -mmin = minutos  ///  -mtime = dias
  
  echoe "\n       Backup completed!\n" "\n       ¡Backup completado!\n"
  exit
fi

# EJECUTA REGENERACION DE SISTEMA

# Comprobar backup
for i in "${ROB[@]}"; do
  if [ ! -f "${Ruta}$i" ]; then
    echoe "TRADUCCION" "Falta el archivo $i en ${Ruta}.  Saliendo..."
    help
  fi
done

# Versión de OMV original
Analiza "openmediavault"
if [ "${VersIdem}" = "NO" ]; then
  echoe "TRADUCCION" "La versión de OMV del servidor original no coincide.  Saliendo..."
  help
fi

# Actualizar sistema
if ! omv-upgrade; then
  echoe "Failed updating system. Exiting..." "Error actualizando el sistema.  Saliendo..."
  exit
fi

# Instalar omv-extras si existía y no está instalado
Analiza "openmediavault-omvextrasorg"
if [ "${VersionOR}" ] && [ "${InstII}" = "NO" ]; then
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
        echoe "omv-extras failed to install correctly.  Trying to fix with ${confCmd} ..." "omv-extras no se pudo instalar correctamente. Intentando corregir con ${confCmd} ..."
        if "${confCmd}" omvextras; then
          echoe "Trying to fix apt ..." "Tratando de corregir apt..."
          apt-get --yes --fix-broken install
        else
          echoe "${confCmd} failed and openmediavault-omvextrasorg is in a bad state. Exiting..." "${confCmd} falló y openmediavault-omvextrasorg está en mal estado. Saliendo..."
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
    "${confCmd}" omvextras
  else
    echoe "There was a problem downloading the package. Exiting..." "Hubo un problema al descargar el paquete. Saliendo..."
    exit
  fi
fi

# Analizar versiones y complementos especiales
cont=0
for i in $(awk '{print NR}' "${Ruta}${ROB[Dpkg]}")
do
  Plugin=$(awk -v i="$i" 'NR==i{print $2}' "${Ruta}${ROB[Dpkg]}")
  Analiza "${Plugin}"
  if [ "${InstII}" = "NO" ]; then
    echoe "Versions $VersIdem \tInstalled $InstII \t${Plugin} \c" "Versiones $VersIdem \tInstalado $InstII \t${Plugin} \c"
    case "${Plugin}" in
      *"kernel" ) ;;
      *"zfs" ) ;;
      * )
        (( cont++ ))
        ListaInstalar[cont]="${Plugin}"
        ;;
    esac
    if [ "${VersIdem}" = "NO" ]; then
      echoe "TRADUCCION" "\t**********\n********** ERROR:  Versión disponible $VersionDI La versión del sistema original $VersionOR no coincide. Saliendo..."
      help
    else
      echoe "TRADUCCION" "  -->  Se va a instalar..."
    fi
  fi
done

# Instalar openmediavault-kernel
Analiza openmediavault-kernel
if [ "${VersIdem}" = "OK" ] && [ "${InstII}" = "NO" ]; then
  InstalaPlugin openmediavault-kernel
fi

# Instalar Kernel proxmox
if [ $OpKern ]; then
  KernelOR=$(awk '{print $3}' "${Ruta}${ROB[Unamea]}" | awk -F "." '/pve$/ {print $1"."$2}')
  KernelIN=$(uname -r | awk -F "." '/pve$/ {print $1"."$2}')
  if [ "${KernelOR}" ] && [ ! "${KernelOR}" = "${KernelIN}" ]; then
    echoe "Installing proxmox kernel" "Instalando kernel proxmox"
    source /usr/sbin/omv-installproxmox "${KernelOR}"
    #
    #
    # SOLUCIONAR EXIT AL FINAL DEL PROGRAMA LLAMADO
    #
    #
    if [ ! -f /etc/cron.d/omvregenreboot ]; then
      touch /etc/cron.d/omvregenreboot
    fi
    echo "@ reboot ${Comando}" >> /etc/cron.d/omvregenreboot
    reboot
  fi
fi

# Instalar openmediavault-zfs. Importar pools.
Analiza openmediavault-zfs
if [ "${VersIdem}" = OK ] && [ "${InstII}" = "NO" ]; then
  InstalaPlugin openmediavault-zfs
  zpool import -f
fi

# Instalar resto de complementos
for i in "${ListaInstalar[@]}"; do
  Analiza "$i"
  if [ "${VersIdem}" = OK ] && [ "${InstII}" = "NO" ]; then
    InstalaPlugin "$i"
  fi
done

# Restaurar configuración del servidor original si no se ha hecho ya
if [ "$(diff "$Ruta$Passwd" = "$Passwd")" ]; then
  echoe "TRADUCCION" "Implementando configuración del servidor original..."
  rsync -av "${Ruta}" "/" --exclude ROB_*
  omv-salt stage run prepare
  omv-salt stage run deploy
  
  # Reinstalar openmediavault-sharerootfs
  source /usr/share/openmediavault/scripts/helper-functions
  uuid="79684322-3eac-11ea-a974-63a080abab18"
  if [ "$(omv_config_get_count "//mntentref[.='${uuid}']")" = "0" ]; then
    omv-confdbadm delete --uuid "${uuid}" "conf.system.filesystem.mountpoint"
  fi
  apt-get install --reinstall openmediavault-sharerootfs
  # Mover docker a su sitio
  # Conseguir los grupos de los usuarios
  # Instalar paquetes de apttools
  # Extraer symlinks base de datos y crear

#  if [ ! -f /etc/cron.d/omvregenreboot ]
#    touch /etc/cron.d/omvregenreboot
#  fi
#  echo "@ reboot ${Comando}" >> /etc/cron.d/omvregenreboot
  reboot

fi

echoe "\n       Regeneration completed!\n" "\n       ¡Regeneración completada!\n"
exit



