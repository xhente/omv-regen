#!/bin/bash
# -*- ENCODING: UTF-8 -*-

Back=""
Rege=""
Ruta=""
OpDias=7
OpExpz=""
OpForz=""
OpKern=1
declare -A Bp
Bp[VersPlug]='/VersionPlugins'
Bp[VersKern]='/VersionKernel'
Bp[VersOMV]='/VersionOMV'
Bp[Config]='/etc/openmediavault/config.xml'
Bp[Passwd]='/etc/passwd'
Bp[Shadow]='/etc/shadow'
declare -a Origen=( "/home" "/etc/libvirt/qemu" "/etc/wireguard" )
Fecha=$(date +%y%m%d_%H%M)
VersionOR=""
VersionDI=""
InstaladoII=""
Instalado=""
Versiones=""
confCmd="omv-salt deploy run"
cont=0
sucio=0
Kernel=""
ZFS=""
Compose=""
Shareroot=""
Apttool=""
declare -a ListaInstalar
declare -a ListaDesinst

[ "$(cut -b 7,8 /etc/default/locale)" = es ] && Sp=1
echoe () { [ ! "$Sp" ] && echo -e "$1" || echo -e "$2"; }

help () {
  echo -e "                                                                                       "
  echo -e "               HELP FOR USING OMV-REGEN      (BACKUP AND REGENERATE)                   "
  echo -e "                                                                                       "
  echo -e "  - omv-regen regenerates an OMV system from a clean install by restoring the existing "
  echo -e "  configurations to the original system.                                               "
  echo -e "  - Install omv-regen on the original system and make a backup, then install OMV on an "
  echo -e "  empty disk without configuring anything, then install omv-regen and mount the backup "
  echo -e "  on a flash drive, then regenerate. The version available on the internet must match. "
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
  echo -e "              -e        Export ZFS pools. Do this only if you are going to regenerate  "
  echo -e "                        immediately.                                                   "
  echo -e "          [folders]     Optional folders to add to the backup. Separate with spaces.   "
  echo -e "                        Use quotes for paths with spaces.                              "
  echo -e "_______________________________________________________________________________________"
  echo -e "    omv-regen regenera PATH_TO_BACKUP [OPTIONS]                                        "
  echo -e "                                                                                       "
  echo -e "      Options and parameters:                                                          "
  echo -e "        PATH_TO_BACKUP  Path where the backup is stored with the data to regenerate.   "
  echo -e "              -f        Force regeneration without version matching.                   "
  echo -e "                        It is only possible if the difference is minimal.              "
  echo -e "                        Its use is not recommended. A new backup is preferable.        "
  echo -e "              -k        Skip installing the proxmox kernel.                            "
  echo -e "                                                                                       "
  exit
}

# Analizar estado de plugin. Versiones y instalación
Analiza () {
  VersionOR=""; VersionDI=""; InstaladoII=""
  VersionOR=$(awk -v i="$1" '$1 == i {print $2}' "${Ruta}${Bp[VersPlug]}")
  VersionDI=$(apt-cache madison "$1" | awk '{print $3}')
  InstaladoII=$(dpkg -l | awk -v i="$1" '$2 == i { print $1 }')
  if [ "${InstaladoII}" == "ii" ]; then Instalado=SI; else Instalado=NO; fi
  if [ "${VersionOR}" = "${VersionDI}" ]; then Versiones=SI; else Versiones=NO; fi
}

# Instalar complemento
InstalaPlugin () {
  echoe "Install $1 plugin" "Instalando el complemento $1"
  if ! apt-get --yes install "$1"; then
    echoe "Failed to install $1 plugin." "No se pudo instalar el complemento $1."
    "${confCmd}" "$1"
    apt-get --yes --fix-broken install
  fi
}

# Root
if [[ $(id -u) -ne 0 ]]; then
  echoe "This script must be executed as root or using sudo.  Exiting..." "Este script se debe ejecutar como root o usando sudo.  Saliendo..."
  help
fi

# Eliminar programación de ejecución tras reinicio
[ -f /etc/cron.d/omv-regen-reboot ] && rm /etc/cron.d/omv-regen-reboot

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
[ -d "${2}" ] && Ruta="$2" || help
shift 2

if [ $Back ]; then
  while getopts "d:ehv" opt; do
    case "$opt" in
      d)
        OpDias=$OPTARG
        echoe "TRADUCCION" "Se eliminarán los backups de mas de $OpDias días de antigüedad."
        ;;
      e)
        OpExpz=1
        echoe "TRADUCCION" "Se van a exportar los pools ZFS existentes."
        ;;
      h)
        help
        ;;
      *)
        echoe "Invalid command." "Comando inválido."
        help
        ;;
    esac
  done
else
  while getopts "fhkv" opt; do
    case "$opt" in
      f)
        OpForz=1
        echoe "TRADUCCION" "Se forzará la regeneración si las versiones no coinciden"
        ;;
      h)
        help
        ;;
      k)
        OpKern=""
        echoe "TRADUCCION" "No se instalará el kernel proxmox"
        ;;
      *)
        echoe "Invalid command." "Comando inválido."
        help
        ;;
    esac
  done
fi

shift $((OPTIND -1))
if [[ -n "$Rege" && -n $1 ]]; then
  echoe "Invalid command." "Comando inválido."
  help
else
  for i in "$@"; do
    if [ -d "$i" ]; then
      echoe "TRADUCCION" "La carpeta $i se va a copiar."
    else  
      echoe "TRADUCCION" "La carpeta $i no existe o no es accesible."
      help
    fi
  done
fi

# EJECUTA BACKUP
if [ $Back ]; then
  Destino="${Ruta}/omv-regen/ORB_${Fecha}"
  echoe ">>>    Copying data to ${Destino}..." ">>>    Copiando datos a ${Destino}..."
  [ -d "${Destino}" ] && rm "${Destino}"
  mkdir -p "${Destino}/etc/openmediavault"
  cp -av "${Bp[Config]}" "${Destino}${Bp[Config]}"
  cp -av "${Bp[Passwd]}" "${Destino}${Bp[Passwd]}"
  cp -av "${Bp[Shadow]}" "${Destino}${Bp[Shadow]}"
  
  echoe ">>>    Creating plugin list..." ">>>    Creando lista de complementos..."
  dpkg -l | awk '/openmediavault/ {print $2"\t"$3}' > "${Destino}${Bp[VersPlug]}"
  sed -i '/keyring/d' "${Destino}${Bp[VersPlug]}"
  cat "${Destino}${Bp[VersPlug]}"

  echoe ">>>    Extracting kernel version..." ">>>    Extrayendo versión del kernel..."
  uname -r | tee "${Destino}${Bp[VersKern]}"

  echoe ">>>    Extracting OMV version..." ">>>    Extrayendo versión de OMV..."
  dpkg -l | awk '$2 == "openmediavault" { print $2" "$3 }'| tee "${Destino}${Bp[VersOMV]}"

  for i in "${Origen[@]}"; do
    if [ -d "$i" ]; then
      echoe ">>>    Copying data from $i..." ">>>    Copiando datos de $i..."
      mkdir -p "${Destino}$i"
      rsync -av "$i"/ "${Destino}$i"
    fi
  done

  while [ "$*" ]; do
    echoe ">>>    Copying data from $1..." ">>>    Copiando datos de $1..."
    mkdir -p "${Destino}/OptionalFolders$1"
    rsync -av "$1"/ "${Destino}/OptionalFolders$1"
    shift
  done

  echoe ">>>    Deleting backups larger than ${Dias} days..." ">>>    Eliminando backups de más de ${Dias} días..."
  find "${Ruta}/omv-regen/" -maxdepth 1 -type d -name "ORB_*" -mtime "+$OpDias" -exec rm -rv {} +
  # -mmin = minutos  ///  -mtime = dias
  
  if [ $OpExpz ]; then
    # EXPORTAR POOLS ZFS
    # Extraer nombre de los pools desde la base de datos y guardar en archivo
    echoe "TRADUCCION" "Exportando pools ZFS"
    #
    #
    #
    #
    #
  fi

  echoe "\n       Done!\n" "\n       ¡Hecho!\n"

  exit
fi

# EJECUTA REGENERACION DE SISTEMA

# Archivos del backup
for i in "${Bp[@]}"; do
  if [ ! -f "${Ruta}$i" ]; then
    echoe "TRADUCCION" "Falta el archivo $i en ${Ruta}.  Saliendo..."
    help
  fi
done

# Versión de OMV original
Analiza "openmediavault"
if [ "${Versiones}" = "NO" ]; then
  echoe "TRADUCCION" "La versión de OMV del servidor original no coincide.  Saliendo..."
  help
fi

# Actualizar sistema
if ! omv-upgrade; then
  echoe "Failed updating system" "Error actualizando el sistema.  Saliendo..."
  help
fi

# Instalar omv-extras si existía y no está instalado
Analiza "openmediavault-omvextrasorg"
if [ "${Versiones}" = "SI" ] && [ "${Instalado}" = "NO" ]; then
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
      if [[ "${Instalado}" = "NO" ]]; then
        echoe "omv-extras failed to install correctly.  Trying to fix with ${confCmd} ..." "omv-extras no se pudo instalar correctamente. Intentando corregir con ${confCmd} ..."
        if "${confCmd}" omvextras; then
          echoe "Trying to fix apt ..." "Tratando de corregir apt..."
          apt-get --yes --fix-broken install
        else
          echoe "${confCmd} failed and openmediavault-omvextrasorg is in a bad state." "${confCmd} falló y openmediavault-omvextrasorg está en mal estado."
          exit 3
        fi
      fi
      Analiza "openmediavault-omvextrasorg"
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
for i in $(awk '{print NR}' "${Ruta}${Bp[VersPlug]}")
do
  Plugin=$(awk -v i="$i" 'NR==i{print $1}' "${Ruta}${Bp[VersPlug]}")
  Analiza "${Plugin}"
  if [ "${Instalado}" = "NO" ]; then
    echoe "TRADUCCION" "Versiones $Versiones \tInstalado $Instalado \t${Plugin} \c"
    case "${Plugin}" in
      *"kernel" ) ;;
      *"zfs" ) ;;
      *"compose" ) ;;
      * )
        (( cont++ ))
        ListaInstalar[cont]="${Plugin}"
        ;;
    esac
    # Marcar complementos sucios. Desinstalar al final
    if [ "${Versiones}" = "NO" ]; then
      # AÑADIR CONDICION. SI LA DIFERENCIA DE VERSION ES FUERTE CONDICIONAR A $OpForz
      # Si la primera columna de version es igual y $OpForz=1 
      #   Instalar
      # sino
      #   echoe "TRADUCCION" "Las versiones no coinciden. Saliendo..."
      #   help
      #fi
      #
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

# Opción forzar
if [ ! $OpForz ]; then
  # AÑADIR CONDICION. SI LA DIFERENCIA DE VERSION ES FUERTE CONDICIONAR A $OpForz
      # Si la primera columna de version es igual y $OpForz=1 
      #   Instalar
      # sino
      #   echoe "TRADUCCION" "Las versiones no coinciden. Saliendo..."
      #   help
      #fi
  echoe "TRADUCCION" "No se puede realizar la regeneración. Hay versiones de paquetes no coincidentes con el servidor de origen."
  help
fi

# Instalar openmediavault-kernel
Analizar openmediavault-kernel
if [ "${Versiones}" = SI ] && [ "${Instalado}" = "NO" ]; then
  InstalaPlugin openmediavault-kernel
fi

# Instalar Kernel proxmox si omv-kernel no está sucio
if  [ ! "${Kernel}" = "11" ] && [ $OpKern ]; then
  VersKernelOri=$(awk -F "." '/pve$/ {print $1"."$2 }' "${Ruta}${Bp[VersKern]}")
  VersionKernelIns=$(uname -r | awk -F "." '/pve$/ {print $1"."$2 }')
  if [ "${VersKernelOri}" ] && [ ! "${VersKernelOri}" = "${VersionKernelIns}" ]; then
    echoe "Installing proxmox kernel" "Instalando kernel proxmox"
    source /usr/sbin/omv-installproxmox "${VersKernelOri}"
    #
    #
    # SOLUCIONAR EXIT AL FINAL DEL PROGRAMA LLAMADO
    #
    #
    [ ! -f /etc/cron.d/regen-reboot ] && touch /etc/cron.d/regen-reboot
    echo "@ reboot root /home/omv-regen-regenera.sh $Ruta" >> /etc/cron.d/regen-reboot
    reboot
  fi
fi

# Instalar openmediavault-zfs. Importar pools.
Analiza openmediavault-zfs
if [ "${Versiones}" = SI ] && [ "${Instalado}" = "NO" ]; then
  InstalaPlugin openmediavault-zfs
  if ! zpool import -a; then
    zpool import -f
  fi
fi

##############################################################################
echo hasta aquí
exit
##############################################################################

# DOCKER
# Averiguar donde estaba docker
# Montar sistema de archivos de docker
# Instalar docker
# Instalar compose


# Instalar resto de complementos
for i in ListaInstalar[@]
do
  InstalaPlugin $i
done


# Generar usuarios

# Sustituir base de datos e implementar
omv-salt stage run prepare
omv-salt stage run deploy

# Reinstalar openmediavault-sharerootfs
Analiza sharerootfs
if [ "$Instalado" = "SI" ]; then
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