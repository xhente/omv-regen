#!/bin/bash

# Script para regenerar un sistema OMV
# Este script instalará complementos y usuarios existentes y restaurará la configuración.
# Se debe realizar previamente una instalación y actualización de Openmediavault.
# Debe existir un backup previo generado por regen-omv-backup en una carpeta accesible.
# Formato de uso    regen-omv-regenera PATH_TO_BACKUP
# Por ejemplo       regen-omv-regenera /home/backup230401

Sp=1; [ $(cut -b 7,8 /etc/default/locale) = es ] && Sp=""
declare -A Backup
Backup[VersPlugins]='/VersionPlugins'
Backup[VersKernel]='/VersionKernel'
Backup[VersOMV]='/VersionOMV'
Backup[Usuarios]='/Usuarios'
Backup[Red]='/Red'
Backup[BaseDatos]='/etc/openmediavault/config.xml'
Backup[ArchPasswd]='/etc/passwd'
Backup[ArchShadow]='/etc/shadow'
Ruta=$1; shift
Extras=0
Kernel=0
ZFS=0
Shareroot=0
VersionKernel=""
URL="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master"
confCmd="omv-salt deploy run"


if [[ $(id -u) -ne 0 ]]; then
  [ $Sp ] && echo "This script must be executed as root or using sudo." || echo "Este script se debe ejecutar como root o mediante sudo."
  exit
fi

if [ ! "$(lsb_release --codename --short)" = "bullseye" ]; then
  [ $Sp ] && echo "Unsupported version.  Only OMV 6.x. are supported.  Exiting..." || echo "Versión no soportada.   Solo está soportado OMV 6.x.   Saliendo..."
  exit
fi

if [ -z "$Ruta" ]; then
  [ $Sp ] && echo "TRADUCCION" || echo "Escribe la ruta del backup después del comando->  regen-omv-regenera.sh /PATH_TO/BACKUP"
  exit
else
  if [ "$1" ]; then
    [ $Sp ] && echo "TRADUCCION" || echo "Si hay espacios en la ruta del backup usa comillas->  regen-omv-regenera.sh \"/PATH TO/BACKUP\""
    exit
  fi
fi

# Comprobar si la arquitectura es la misma y si los discos están conectados.
#                              ¡¡REVISAR ESTO!!       Copiado de openmediavault-kernel
#case "$(/usr/bin/arch)" in
#  *amd64*|*x86_64*)
#    echo "Supported kernel found"
#    ;;
#  *)
#    echo "Unsupported kernel and/or processor"
#    exit 1
#    ;;
#esac

# Comprobar si están todos los archivos del backup
for i in ${Backup[@]}; do
  if [ ! -f "${Ruta}$i" ]; then
    [ $Sp ] && echo "TRADUCCION" || echo "El archivo $i no existe en ${Ruta}.  Saliendo..."
    exit
  fi
done

# Comprobar versión de OMV
VersionOrig=$(awk '{print $2}' ${Ruta}${Backup[VersOMV]})
VersionDisp=$(apt-cache policy "openmediavault" | awk -F ": " 'NR==2{print $2}')
if [ ! "${VersionOrig}" = "${VersionDisp}" ]; then
  [ $Sp ] && echo "TRADUCCION" || echo "La versión disponible de OMV es ${VersionDisp}  No coincide con la versión del sistema original ${VersionOrig}   No se puede continuar.  Saliendo..."
  exit
fi

# Comprobar versiones de complementos. Comprobar si existía omv-extras, kernel y zfs
# NOTA: ¿Posibilidad de continuar sin instalar uno de los complementos? 
for i in $(awk '{print NR}' ${Ruta}${Backup[VersPlugins]})
do
  Plugin=$(awk -v i="$i" 'NR==i{print $1}' ${Ruta}${Backup[VersPlugins]})
  VersionOrig=$(awk -v i="$i" 'NR==i{print $2}' ${Ruta}${Backup[VersPlugins]})
  VersionDisp=$(apt-cache policy "$Plugin" | awk -F ": " 'NR==2{print $2}')
  case "${Plugin}" in
    *"omvextrasorg" ) Extras=1 ;;
    *"kernel" ) Kernel=1 ;;
    *"zfs" ) ZFS=1 ;;
    *"sharerootfs" ) Shareroot=1 ;;
  esac
  if [ "$VersionOrig" != "$VersionDisp" ]; then
    [ $Sp ] && echo "TRADUCCION" || echo "La versión disponible para instalar el complemento $Plugin es $VersionDisp  No coincide con la versión del sistema original $VersionOrig   Forzar la regeneración en estas condiciones puede provocar errores de configuración."
    while true; do
      [ $Sp ] && read -p "TRADUCCION" yn || read -p "Se recomienda abortar la regeneración ¿quieres abortar? (si/no): " yn
      case $yn in
        [yYsS]* ) [ $Sp ] && echo "Exiting..." || echo "Saliendo..."; exit ;;
        [nN]* ) break;;
        * ) [ $Sp ] && echo "TRADUCCION" || echo "Responde si o no: " ;;
      esac
    done
  fi
done

# Inicia regeneración
[ $Sp ] && echo -e "\n       <<< TRADUCCION >>>" || echo -e "\n       <<< Regenerando el sistema >>>"

# Actualizar sistema
if ! omv-upgrade; then
  echo "failed updating system"
  exit
fi

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

# Instalar openmediavault-kernel si estaba instalado
if [ "${Kernel}" = 1 ]; then
  echo "Instalando openmediavault-kernel"
  
  Kernel=0
fi

# Instalar Kernel proxmox si estaba en el sistema original
VersionKernel=$(awk -F "." '/pve$/ {print $1"."$2 }' "${Ruta}${Backup[VersKernel]}")
if [ "${VersionKernel}" ]; then
  echo "Instalando kernel proxmox"

  # Definir el parámetro $1 como kernel a instalar para entrar al script
  source /usr/sbin/omv-installproxmox
fi

# SI SE HA CAMBIADO EL KERNEL ES NECESARIO REINICIAR


# Instalar complementos
for i in ComplemInstalar[@]
do
  if [ ! "$i" = "openmediavault" ] && [ ! "$i" = "openmediavault-omvextrasorg" ]; then
    echo "Install $i"
    if ! apt-get --yes install "$i"; then
      echo "failed to install $i plugin."
      ${confCmd} "$i"
      apt-get --yes --fix-broken install
      exit
    else
      CompII=$(dpkg -l | awk '$2 == "$i" { print $1 }')
      if [[ ! "${CompII}" == "ii" ]]; then
        echo "$i plugin failed to install or is in a bad state."
        exit
      fi
    fi
  fi
done





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