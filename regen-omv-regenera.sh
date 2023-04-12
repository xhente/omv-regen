#!/bin/bash

# Script para regenerar un sistema OMV
# Este script instalará complementos y usuarios existentes y restaurará la configuración.
# Se debe realizar previamente una instalación y actualización de Openmediavault.
# Debe existir un backup previo generado por regen-omv-backup en una carpeta accesible.
# Formato de uso    regen-omv-regenera PATH_TO_BACKUP
# Por ejemplo       regen-omv-regenera /home/backup230401

[ $(cut -b 7,8 /etc/default/locale) = es ] && Sp=1
echoe () { [ ! $Sp ] && echo -e $1 || echo -e $2; }

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

# ELIMINAR PROGRAMACION DE EJECUCION TRAS REINICIO


# Función instalar complemento
InstallPlugin () {
  echoe "Install $1 plugin" "Instalando el complemento $1"
  if ! apt-get --yes install "$1"; then
    echoe "Failed to install $1 plugin." "No se pudo instalar el complemento $1."
    ${confCmd} "$1"
    apt-get --yes --fix-broken install
  else
    PlugII=$(dpkg -l | awk -v i="$1" '$2 == "i" { print $1 }')
    if [[ ! "${PlugII}" == "ii" ]]; then
      echoe "Failed to install $1 plugin or is in a bad state." "El complemento $1 no se pudo instalar o está en mal estado."
      ${confCmd} "$1"
      apt-get --yes --fix-broken install
    fi
  fi
}

# Root
if [[ $(id -u) -ne 0 ]]; then
  echoe "This script must be executed as root or using sudo." "Este script se debe ejecutar como root o mediante sudo."
  exit
fi

# Versión OMV
if [ ! "$(lsb_release --codename --short)" = "bullseye" ]; then
  echoe "Unsupported version.  Only OMV 6.x. are supported.  Exiting..." "Versión no soportada.   Solo está soportado OMV 6.x.   Saliendo..."
  exit
fi

# Ruta backup
if [ -z "$Ruta" ]; then
  echoe "TRADUCCION" "Escribe la ruta del backup después del comando->  regen-omv-regenera.sh /PATH_TO/BACKUP"
  exit
else
  if [ "$1" ]; then
    echoe "TRADUCCION" "Si hay espacios en la ruta del backup usa comillas->  regen-omv-regenera.sh \"/PATH TO/BACKUP\""
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

# Archivos del backup
for i in ${Backup[@]}; do
  if [ ! -f "${Ruta}$i" ]; then
    echoe "TRADUCCION" "El archivo $i no existe en ${Ruta}.  Saliendo..."
    exit
  fi
done

# Versión de OMV original
VersionOrig=$(awk '{print $2}' ${Ruta}${Backup[VersOMV]})
VersionDisp=$(apt-cache policy "openmediavault" | awk -F ": " 'NR==2{print $2}')
if [ ! "${VersionOrig}" = "${VersionDisp}" ]; then
  echoe "TRADUCCION" "La versión de OMV es ${VersionDisp}  No coincide con la versión del sistema original ${VersionOrig}   No se puede continuar.  Saliendo..."
  exit
fi

# Actualizar sistema
if ! omv-upgrade; then
  echoe "Failed updating system" "Error actualizando el sistema"
  exit
fi

# Instalar omv-extras si existía y no está instalado
ExtrasOri=$(grep -i "openmediavault-omvextras" ${Ruta}${Backup[VersPlugins]})
ExtrasIns=$(dpkg -l | awk '$2 == "openmediavault-omvextrasorg" { print $1 }')
if [ "${ExtrasOri}" ] && [ ! "${ExtrasIns}" == "ii" ]; then
  echoe "Downloading omv-extras.org plugin for openmediavault 6.x ..." "Descargando el complemento omv-extras.org para openmediavault 6.x ..."
  File="openmediavault-omvextrasorg_latest_all6.deb"
  if [ -f "${File}" ]; then
    rm ${File}
  fi
  wget ${URL}/${File}
  if [ -f "${File}" ]; then
    if ! dpkg --install ${File}; then
      echoe "Installing other dependencies ..." "Instalando otras dependencias ..."
      apt-get --yes --fix-broken install
      omvextrasInstall=$(dpkg -l | awk '$2 == "openmediavault-omvextrasorg" { print $1 }')
      if [[ ! "${omvextrasInstall}" == "ii" ]]; then
        echoe "omv-extras failed to install correctly.  Trying to fix with ${confCmd} ..." "omv-extras no se pudo instalar correctamente. Intentando corregir con ${confCmd} ..."
        if ${confCmd} omvextras; then
          echoe "Trying to fix apt ..." "Tratando de corregir apt..."
          apt-get --yes --fix-broken install
        else
          echoe "${confCmd} failed and openmediavault-omvextrasorg is in a bad state." "${confCmd} falló y openmediavault-omvextrasorg está en mal estado."
          exit 3
        fi
      fi
      omvextrasInstall=$(dpkg -l | awk '$2 == "openmediavault-omvextrasorg" { print $1 }')
      if [[ ! "${omvextrasInstall}" == "ii" ]]; then
        echoe "openmediavault-omvextrasorg package failed to install or is in a bad state." "El paquete openmediavault-omvextrasorg no se pudo instalar o está en mal estado."
        exit 3
      fi
    fi
    echoe "Updating repos ..." "Actualizando repositorios..."
    omv-salt deploy run omvextras
    Extras=1
  else
    echoe "There was a problem downloading the package." "Hubo un problema al descargar el paquete."
    exit
  fi
fi

# Analizar versiones y complementos especiales
# NOTA: ¿Posibilidad de continuar sin instalar uno de los complementos? 
cont=0
for i in $(awk '{print NR}' ${Ruta}${Backup[VersPlugins]})
do
  Plugin=$(awk -v i="$i" 'NR==i{print $1}' ${Ruta}${Backup[VersPlugins]})
  VersionOri=$(awk -v i="$i" 'NR==i{print $2}' ${Ruta}${Backup[VersPlugins]})
  VersionDis=$(apt-cache madison "$Plugin" | awk '{print $3}')
  case "${Plugin}" in
    *"omvextrasorg" ) ;;
    *"kernel" ) Kernel=1 ;;
    *"zfs" ) ZFS=1 ;;
    *"sharerootfs" ) Shareroot=1 ;;
    *"apttool" ) Apttool=1 ;;
    * )
      (( cont++ ))
      PluginIns[$cont]="${Plugin}"
      ;;
  esac
  if [ "$VersionOri" != "$VersionDis" ]; then
    echoe "TRADUCCION" "La versión disponible para instalar el complemento $Plugin es $VersionDis  No coincide con la versión del sistema original $VersionOri   Forzar la regeneración en estas condiciones puede provocar errores de configuración."
    while true; do
      [ ! $Sp ] && read -p "TRADUCCION" yn || read -p "Se recomienda abortar la regeneración ¿quieres abortar? (si/no): " yn
      case $yn in
        [yYsS]* ) echoe "Exiting..." "Saliendo..."; exit ;;
        [nN]* ) break;;
        * ) echoe "TRADUCCION" "Responde si o no: " ;;
      esac
    done
  fi
done

# Instalar openmediavault-kernel si estaba instalado y si no se ha instalado ya
KernelIns=$(dpkg -l | awk '$2 == "openmediavault-omvextrasorg" { print $1 }')
if [ "${Kernel}" = 1 ] && [ ! "${KernelIns}" == "ii" ]; then
  InstallPlugin openmediavault-kernel
fi

echo bien
exit


# Instalar Kernel proxmox si estaba en el sistema original
VersionKernel=$(awk -F "." '/pve$/ {print $1"."$2 }' "${Ruta}${Backup[VersKernel]}")
if [ "${VersionKernel}" ]; then
  echoe "Installing proxmox kernel" "Instalando kernel proxmox"

  # Definir el parámetro $1 como kernel a instalar para entrar al script
  source /usr/sbin/omv-installproxmox
  # programar ejecucion script tras reinicio
  # reiniciar
fi

# SI SE HA CAMBIADO EL KERNEL ES NECESARIO REINICIAR


# Instalar complementos
for i in ComplemInstalar[@]
do
  if [ ! "$i" = "openmediavault" ] && [ ! "$i" = "openmediavault-omvextrasorg" ]; then
    echoe "Install $i" "Instalando $i"
    if ! apt-get --yes install "$i"; then
      echoe "Failed to install $i plugin." "No se pudo instalar el complemento $i."
      ${confCmd} "$i"
      apt-get --yes --fix-broken install
      exit
    else
      CompII=$(dpkg -l | awk '$2 == "$i" { print $1 }')
      if [[ ! "${CompII}" == "ii" ]]; then
        echoe "$i plugin failed to install or is in a bad state." "El complemento $i no se pudo instalar o está en mal estado."
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