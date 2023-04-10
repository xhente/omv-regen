#!/bin/bash

# Script para regenerar un sistema OMV
# Este script instalará complementos y usuarios existentes y restaurará la configuración.
# Se debe realizar previamente una instalación y actualización de Openmediavault.
# Debe existir un backup previo generado por regen-omv-backup en una carpeta accesible.
# Formato de uso    regen-omv-regenera PATH_TO_BACKUP
# Por ejemplo       regen-omv-regenera /home/backup230401

[ $(cut -b 7,8 /etc/default/locale) = es ] && Id=esp
declare -A Backup
Backup[VersPlugins]='VersionPlugins'
Backup[VersKernel]='VersionKernel'
Backup[VersOMV]='VersionOMV'
Backup[Usuarios]='Usuarios'
Backup[Red]='Red'
Backup[BaseDatos]='config.xml'
Backup[ArchPasswd]='etc/passwd'
Backup[ArchShadow]='etc/shadow'
Ruta=$1
declare -a ComplemInstalar
Extras=0
Kernel=0
ZFS=0
Shareroot=0
VersionKernel=0
VersionKernel=$(uname -r | awk -F "." '/pve$/ {print $1"."$2 }')
URL="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master"
confCmd="omv-salt deploy run"


if [[ $(id -u) -ne 0 ]]; then
  [ ! $Id ] && echo "This script must be executed as root or using sudo." || echo "Este script se debe ejecutar como root o usando sudo."
  exit
fi

if [ ! "$(lsb_release --codename --short)" = "bullseye" ]; then
  [ ! $Id ] && echo "Unsupported version.  Only OMV 6.x. are supported.  Exiting..." || echo "Versión no soportada.   Solo está soportado OMV 6.x.   Saliendo..."
  exit
fi

# Comprobar si la arquitectura es la misma y si los discos están conectados.
#                              ¡¡REVISAR ESTO!!       Copiado de openmediavault-kernel
case "$(/usr/bin/arch)" in
  *amd64*|*x86_64*)
    echo "Supported kernel found"
    ;;
  *)
    echo "Unsupported kernel and/or processor"
    exit 1
    ;;
esac

# Inicia regeneración
[ $Id ] && echo -e "\n       <<< Regenerando el sistema >>>" || echo -e "\n       <<< TRADUCCION >>>"

# Actualizar sistema
if ! omv-upgrade; then
  echo "failed updating system"
  exit
fi

# Comprobar si están todos los archivos del backup
if [ "$1" ] && [ ! "$2" ]; then
  for i in ${Backup[@]}; do
    if [ ! -f "${Ruta}/$i" ]; then
      [ $Id ] && echo ">>>    El archivo $1/$i no existe.\n>>>    Asegúrate de introducir la ruta correcta." || echo ">>>    TRADUCCION"
      exit
    fi
  done
else
  [ $Id ] && echo -e "\n      Escribe la ruta después del comando  -> regen-omv-regenera.sh /path_to/backup\n      Si hay espacios usa comillas -> regen-omv-regenera.sh \"/path to/backup\"\n" || echo -e "\nTRADUCCION"
    exit
fi

# Comprobar versiones. Comprobar si existía omv-extras, kernel y zfs
for i in $(awk '{print NR}' $1/${Backup[BackupComplementos]})
do
  ComplemInstalar[i]=$(awk -v i="$i" 'NR==i{print $1}' $1/${Backup[BackupComplementos]})
  VersionOriginal=$(awk -v i="$i" 'NR==i{print $2}' $1/${Backup[BackupComplementos]})
  VersionDisponible=$(apt-cache policy "$ComplemInstalar[i]" | awk -F ": " 'NR==2{print $2}')
  if [ ComplemInstalar[i] = "openmediavault-omvextrasorg" ]; then
    Extras=1
  fi
  if [ ComplemInstalar[i] = "openmediavault-kernel" ]; then
    Kernel=1
  fi
  if [ ComplemInstalar[i] = "openmediavault-ZFS" ]; then
    ZFS=1
  fi
  if [ ComplemInstalar[i] = "openmediavault-sharerootfs" ]; then
    Shareroot=1
  fi
  if [ "$VersionOriginal" != "$VersionDisponible" ]; then
    echo "La versión del backup $ComplemInstalar[i] $VersionOriginal no coincide con la versión que se va a instalar $ComplemInstalar[i] $VersionDisponible"
    while true; do
      read -p "Forzar la regeneración puede provocar errores de configuración ¿quieres forzar? (yes/no): " yn
      case $yn in
        [yY]* ) break;;
        [nN]* ) exit;;
        * ) echo "Responde yes o no: ";;
      esac
    done
  fi
done

# Instalar omv-extras si existía y no está instalado
omvextrasInstall=$(dpkg -l | awk '$2 == "openmediavault-omvextrasorg" { print $1 }')
if [[ "${omvextrasInstall}" == "ii" ]]; then
  Extras=0
fi
if [ $Extras = "1" ]; then
  echo "Downloading omv-extras.org plugin for openmediavault 6.x ..."
  File="openmediavault-omvextrasorg_latest_all6.deb"
  if [ -f "${File}" ]; then
    rm ${File}
  fi
  wget ${URL}/${File}
  if [ -f "${File}" ]; then
    if ! dpkg --install ${File}; then
      echo "Installing other dependencies ..."
      apt-get --yes --fix-broken install
      omvextrasInstall=$(dpkg -l | awk '$2 == "openmediavault-omvextrasorg" { print $1 }')
      if [[ ! "${omvextrasInstall}" == "ii" ]]; then
        echo "omv-extras failed to install correctly.  Trying to fix with ${confCmd} ..."
        if ${confCmd} omvextras; then
          echo "Trying to fix apt ..."
          apt-get --yes --fix-broken install
        else
          echo "${confCmd} failed and openmediavault-omvextrasorg is in a bad state."
          exit
        fi
      fi
      omvextrasInstall=$(dpkg -l | awk '$2 == "openmediavault-omvextrasorg" { print $1 }')
      if [[ ! "${omvextrasInstall}" == "ii" ]]; then
        echo "openmediavault-omvextrasorg package failed to install or is in a bad state."
        exit
      fi
    fi
    echo "Updating repos ..."
    # apt-get update
    omv-salt deploy run omvextras
  else
    echo "There was a problem downloading the package."
    exit
  fi
fi

# Instalar complementos
for i in ComplemInstalar[@]
do
  if [ ! $ComplemInstalar[i] = "openmediavault" ] && [ ! $ComplemInstalar[i] = "openmediavault-omvextrasorg" ]; then
    echo "Install $ComplemInstalar[i]"
    if ! apt-get --yes install "$ComplemInstalar[i]"; then
      echo "failed to install $ComplemInstalar[i] plugin."
      ${confCmd} "$ComplemInstalar[i]"
      apt-get --yes --fix-broken install
      exit
    else
      CompII=$(dpkg -l | awk '$2 == "$ComplemInstalar[i]" { print $1 }')
      if [[ ! "${CompII}" == "ii" ]]; then
        echo "$ComplemInstalar[i] plugin failed to install or is in a bad state."
        exit
      fi
    fi
  fi
done

# Instalar Kernel proxmox si estaba en el sistema original
if [ $Kernel = "1" ]; then
  # Definir el parámetro $1 como kernel a instalar
  source /usr/sbin/omv-installproxmox
fi

  # Averiguar version de kernel original e instalar
fi

# Instalar openmediavault-ZFS si estaba en el sistema original e importar pools
if [ $ZFS = "1" ]; then
  # Importar pools
fi

# Generar usuarios

# Sustituir base de datos e implementar
omv-salt stage run prepare
omv-salt stage run deploy

# Reinstalar openmediavault-sharerootfs
if [ $Shareroot = "1" ]; then
  source /usr/share/openmediavault/scripts/helper-functions
  uuid="79684322-3eac-11ea-a974-63a080abab18"
  if [ "$(omv_config_get_count "//mntentref[.='${uuid}']")" = "0" ]; then
    omv-confdbadm delete --uuid "${uuid}" "conf.system.filesystem.mountpoint"
  fi
  apt-get install --reinstall openmediavault-sharerootfs
fi

# Reiniciar
reboot