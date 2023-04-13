#!/bin/bash

# Script para regenerar un sistema OMV
# Este script instalará complementos y usuarios existentes y restaurará la configuración.
# Se debe realizar previamente una instalación y actualización de Openmediavault.
# Debe existir un backup previo generado por regen-omv-backup en una carpeta accesible.
# Formato de uso    regen-omv-regenera PATH_TO_BACKUP
# Por ejemplo       regen-omv-regenera /home/backup230401

[ $(cut -b 7,8 /etc/default/locale) = es ] && Sp=1
echoe () { [ ! $Sp ] && echo -e $1 || echo -e $2; }

Ruta=$1; shift
declare -A Backup
Backup[VersPlugins]='/VersionPlugins'
Backup[VersKernel]='/VersionKernel'
Backup[VersOMV]='/VersionOMV'
Backup[Usuarios]='/Usuarios'
Backup[Red]='/Red'
Backup[BaseDatos]='/etc/openmediavault/config.xml'
Backup[ArchPasswd]='/etc/passwd'
Backup[ArchShadow]='/etc/shadow'
VersionOR=""
VersionDI=""
InstaladoII=""
Instalado=""
Versiones=""
cont=0
sucio=0
Kernel=0
ZFS=0
Compose=0
Shareroot=0
Apttool=0
declare -a ListaInstalar
declare -a ListaDesinst
VersionKernel=""
URL="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master"
confCmd="omv-salt deploy run"

# Eliminar programación de ejecución tras reinicio
[ -f /etc/cron.d/regen-reboot ] && rm /etc/cron.d/regen-reboot

# Analizar estado de plugin. Versiones y instalación
Analizar () {
  VersionOR=""; VersionDI=""; InstaladoII=""
  VersionOR=$(awk -v i="$1" '$1 == i {print $2}' "${Ruta}${Backup[VersPlugins]}")
  VersionDI=$(apt-cache madison "$1" | awk '{print $3}')
  InstaladoII=$(dpkg -l | awk -v i="$1" '$2 == i { print $1 }')
  if [ "${InstaladoII}" == "ii" ]; then Instalado=SI; else Instalado=NO; fi
  if [ "${VersionOR}" = "${VersionDI}" ]; then Versiones=SI; else Versiones=NO; fi
}

# Instalar complemento
InstallPlugin () {
  echoe "Install $1 plugin" "Instalando el complemento $1"
  if ! apt-get --yes install "$1"; then
    echoe "Failed to install $1 plugin." "No se pudo instalar el complemento $1."
    "${confCmd}" "$1"
    apt-get --yes --fix-broken install
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
if [ -z "${Ruta}" ]; then
  echoe "TRADUCCION" "Escribe la ruta del backup después del comando->  regen-omv-regenera.sh /PATH_TO/BACKUP"
  exit
else
  if [ "$1" ]; then
    echoe "TRADUCCION" "Si hay espacios en la ruta del backup usa comillas->  regen-omv-regenera.sh \"/PATH TO/BACKUP\""
    exit
  fi
fi

# Archivos del backup
for i in "${Backup[@]}"; do
  if [ ! -f "${Ruta}$i" ]; then
    echoe "TRADUCCION" "El archivo $i no existe en ${Ruta}.  Saliendo..."
    exit
  fi
done

# Versión de OMV original
Analizar "openmediavault"
if [ "${Versiones}" = "NO" ]; then
  echoe "TRADUCCION" "La versiones de OMV no coinciden.  Saliendo..."
  exit
fi

# Actualizar sistema
if ! omv-upgrade; then
  echoe "Failed updating system" "Error actualizando el sistema"
  exit
fi

# Instalar omv-extras si existía y no está instalado
Analizar "openmediavault-omvextrasorg"
if [ "${Versiones}" = "SI" ] && [ "${Instalado}" = "NO" ]; then
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
      Analizar "openmediavault-omvextrasorg"
      if [[ "${Instalado}" = "NO" ]]; then
        echoe "omv-extras failed to install correctly.  Trying to fix with ${confCmd} ..." "omv-extras no se pudo instalar correctamente. Intentando corregir con ${confCmd} ..."
        if ${confCmd} omvextras; then
          echoe "Trying to fix apt ..." "Tratando de corregir apt..."
          apt-get --yes --fix-broken install
        else
          echoe "${confCmd} failed and openmediavault-omvextrasorg is in a bad state." "${confCmd} falló y openmediavault-omvextrasorg está en mal estado."
          exit 3
        fi
      fi
      Analizar "openmediavault-omvextrasorg"
      if [[ "${Instalado}" = "NO" ]]; then
        echoe "openmediavault-omvextrasorg package failed to install or is in a bad state." "El paquete openmediavault-omvextrasorg no se pudo instalar o está en mal estado."
        exit 3
      fi
    fi
    echoe "Updating repos ..." "Actualizando repositorios..."
    "${confCmd}" omvextras
  else
    echoe "There was a problem downloading the package." "Hubo un problema al descargar el paquete."
    exit
  fi
fi

# Analizar versiones y complementos especiales
cont=0; sucio=0
for i in $(awk '{print NR}' "${Ruta}${Backup[VersPlugins]}")
do
  Plugin=$(awk -v i="$i" 'NR==i{print $1}' "${Ruta}${Backup[VersPlugins]}")
  Analizar "${Plugin}"
  if [ "${Instalado}" = "NO" ]; then
    echoe "TRADUCCION" "Versiones $Versiones \tInstalado $Instalado \t${Plugin} \c"
    case "${Plugin}" in
      *"kernel" ) Kernel=1 ;;
      *"zfs" ) ZFS=1 ;;
      *"compose" ) Compose=1 ;;
      *"sharerootfs" ) Shareroot=1 ;;
      *"apttool" ) Apttool=1 ;;
      * )
        (( cont++ ))
        ListaInstalar[$cont]="${Plugin}"
        ;;
    esac
    # Marcar complementos sucios. Desinstalar al final
    if [ "${Versiones}" = "NO" ]; then
      echoe "TRADUCCION" "\t**********\n********** ERROR:  Las versiones no coinciden  -->  Este complemento no se instalará."
      case "${Plugin}" in
        *"kernel" ) Kernel=11 ;;
        *"zfs" ) ZFS=11 ;;
        *"compose" ) Compose=11 ;;
        *"sharerootfs" ) Shareroot=11 ;;
        *"apttool" ) Apttool=11 ;;
        * )
          (( sucio++ ))
          ListaDesinst[$sucio]="${Plugin}"
          ;;
      esac
    else
      echoe "TRADUCCION" "  -->  Se va a instalar"
    fi
  fi
done

# Instalar openmediavault-kernel
Analiza openmediavault-kernel
if [ "${Versiones}" = SI ] && [ "${Instalado}" = "NO" ]; then
  InstallPlugin openmediavault-kernel
fi

# Instalar Kernel proxmox si omv-kernel no está sucio
if  [ ! "${Kernel}" = "11" ]; then
  VersKernelOri=$(awk -F "." '/pve$/ {print $1"."$2 }' "${Ruta}${Backup[VersKernel]}")
  VersionKernelIns=$(uname -r | awk -F "." '/pve$/ {print $1"."$2 }')
  if [ "${VersKernelOri}" ] && [ ! "${VersKernelOri}" = "${VersionKernelIns}" ]; then
    echoe "Installing proxmox kernel" "Instalando kernel proxmox"
    source /usr/sbin/omv-installproxmox "${VersKernelOri}"
    [ ! -f /etc/cron.d/regen-reboot ] && touch /etc/cron.d/regen-reboot
    echo "@ reboot root /home/omv-regen-regenera.sh $Ruta" >> /etc/cron.d/regen-reboot
    reboot
  fi
fi

# Instalar openmediavault-zfs. Importar pools.
Analiza openmediavault-zfs
if [ "${Versiones}" = SI ] && [ "${Instalado}" = "NO" ]; then
  InstallPlugin openmediavault-zfs
  if ! zpool import -a; then
    zpool import -f
  fi
fi

##############################################################################
echo hasta aquí
exit
##############################################################################

# Instalar shareroot y apttool


# DOCKER
# Averiguar donde estaba docker
# Montar sistema de archivos de docker
# Instalar docker
# Instalar compose


# Instalar resto de complementos
for i in ListaInstalar[@]
do
  InstallPlugin $i
done


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

# Desinstalar complementos sucios.

# Reiniciar
reboot