#!/bin/bash
# -*- ENCODING: UTF-8 -*-

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
Inst="/usr/sbin/omv-regen"
Sysreboot="/etc/systemd/system/omv-regen-reboot.service"
ORBackup="/ORBackup"
URL="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master"
confCmd="omv-salt deploy run"

[ "$(cut -b 7,8 /etc/default/locale)" = es ] && Sp=1

# Muestra el mensaje en español o inglés según el sistema.
# $1 opcional segundos de espera. Pulsar una tecla sale y devuelve 1, si no se pulsa es "".
echoe () {
  Tecla=""
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    [ ! "$Sp" ] && echo -e "$2" || echo -e "$3"
    read -t$1 -n1 -r -p "" Tecla
    if [ "$?" -eq "0" ]; then
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
  echo -e "  - Use omv-regen install     to install omv-regen on your system.             "
  echo -e "  - Use omv-regen backup      to store the necessary information to regenerate."
  echo -e "  - Use omv-regen regenerate  to run a system regeneration from a clean OMV.   "
  echo -e "_______________________________________________________________________________"
  echo -e "                                                                               "
  echo -e "   omv-regen install                                                           "
  echo -e "                     Enable the command on the system.                         "
  echo -e "                     1.Make this file executable with    ->  chmod +x omv-regen"
  echo -e "                     2.Run it with the install parameter ->  omv-regen install "
  echo -e "                     3.Delete this file.                                       "
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
  echo -e "    -o     Enable optional folder backup. Spaces to separate (can use quotes). "
  echo -e "                                                                               "
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
    "${confCmd}" "$1"
    apt-get --yes --fix-broken install
    apt-get update
    if ! apt-get --yes install "$1"; then
      "${confCmd}" "$1"
      apt-get --yes --fix-broken install
      echoe "Failed to install $1 plugin. Exiting..." "El complemento $1 no se pudo instalar. Saliendo..."
      exit
    fi
  fi
}

# Extraer entrada de la base de datos
LeeConfig () {
  Etiqueta=$1
  ValorConfig=$(cat "${Ruta}${Config}" | sed -n "s:.*<${Etiqueta}>\(.*\)</$Etiqueta>.*:\1:p")
}

# Instalar omv-regen
InstalarOR (){
  if [ ! $0 = "${Inst}" ];then
    if [ -f "${Inst}" ]; then
      rm "${Inst}"
    fi
    touch "${Inst}"
    cp -a $0 "${Inst}"
    chmod +x "${Inst}"
    echoe "\n  omv-regen has been installed. You can delete the installation file.\n" "\n  omv-regen se ha instalado. Puedes eliminar el archivo de instalación.\n"
  else
    echoe "\n  omv-regen was already installed.\n" "\n  omv-regen ya estaba instalado.\n"
  fi
  echoe "Showing the usage:\n" "Mostrando el uso:\n"
  help
}

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
ExecStart=$Comando

[Install]
WantedBy=multi-user.target" > "${Sysreboot}"
}

# Root
if [[ $(id -u) -ne 0 ]]; then
  echoe "This script must be executed as root or using sudo.  Exiting..." "Este script se debe ejecutar como root o usando sudo.  Saliendo..."
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

# Almacenar argumentos de ejecución.
Comando=$0
for i in "$@"; do
  Comando="${Comando} $i"
done

# Release 6.x.
if [ ! "$(lsb_release --codename --short)" = "bullseye" ]; then
  echoe "Unsupported version.  Only OMV 6.x. are supported.  Exiting..." "Versión no soportada.   Solo está soportado OMV 6.x.   Saliendo..."
  help
fi

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
    echoe "TRADUCCION" "Argumento inválido. Solo puede ser backup, regenera o install."
    help
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
          echoe "TRADUCCION" "El backup se almacenará en ${Ruta}"
        else
          echoe "TRADUCCION" "La carpeta ${OPTARG} no existe. Saliendo..."
          help
        fi
        ;;
      d)
        if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
          OpDias=$OPTARG
          echoe "TRADUCCION" "Se eliminarán los backups de mas de $OpDias días de antigüedad."
        else
          echoe "TRADUCCION" "La opción -d debe ser un número. Saliendo..."
          help
        fi
        ;;
      h)
        help
        ;;
      o)
        if [ -d "${OPTARG}" ]; then
          OpFold="${OPTARG}"
          echoe "TRADUCCION" "La carpeta ${OpFold} se va a copiar."
        else
          echoe "TRADUCCION" "La carpeta ${OPTARG} no existe. Saliendo..."
          help
        fi
        ;;
      u)
        OpUpda=1
        echoe "TRADUCCION" "Se va a actualizar el sistema antes de hacer el backup."
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
          echoe "TRADUCCION" "Se ha establecido ${Ruta} como origen de datos."
        else
          echoe "TRADUCCION" "La carpeta ${OPTARG} no existe. Saliendo..."
          help
        fi
        ;;
      h)
        help
        ;;
      k)
        OpKern=""
        echoe "TRADUCCION" "No se instalará el kernel proxmox."
        ;;
      r)
        OpRebo=1
        echoe 3 "TRADUCCION" "Se reiniciará automáticamente el sistema después de instalar un kernel."
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
        echoe "TRADUCCION" "La carpeta $i se va a copiar."
      else
        echoe "TRADUCCION" "La carpeta $i no existe. Saliendo..."
        help
      fi
    done
  else
  echoe "TRADUCCION" "Para elegir carpetas opcionales debes seleccionar la opción -o"
  help
  fi
fi

if [ "$Back" ] && [ ! "${Ruta}" ]; then
  echoe "TRADUCCION" "No se ha establecido carpeta para el backup. Se almacenará en ${ORBackup}"
  if [ ! -d "${ORBackup}" ]; then
    mkdir -p "${ORBackup}"
  fi
  Ruta="${ORBackup}"
fi

if [ "$Rege" ]; then
  if [ "$2" ]; then
    echoe "TRADUCCION" "Argumento inválido $2 Saliendo..."
    help
  else
    if [ "$1" ]; then
      if [ "${Ruta}" ]; then
        echoe "TRADUCCION" "Argumento inválido $1 Saliendo..."
        help
      else
        if [ -d "$1" ]; then
          Ruta="$1"
          echoe "TRADUCCION" "Se ha establecido ${Ruta} como origen de datos."
        else
          echoe "TRADUCCION" "La carpeta $1 no existe. Saliendo..."
          help
        fi
      fi
    else
      if [ ! "${Ruta}" ]; then
        echoe "TRADUCCION" "Falta la ruta de origen del backup para regenerar. Saliendo..."
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
  if [ -d "${Destino}" ]; then
    rm "${Destino}"
  fi
  mkdir -p "${Destino}"

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
  cat "${Destino}${ORB[Dpkg]}" | awk '{print $2" "$3}'

  # Crea registro uname -a
  echoe ">>>    Extracting system info (uname -a)..." ">>>    Extrayendo información del sistema (uname -a)..."
  uname -a | tee "${Destino}${ORB[Unamea]}"

  # Crea registro zpool list
  echoe ">>>    Extracting zfs info (zpool list)..." ">>>    Extrayendo información de zfs (zpool list)..."
  zpool list | tee "${Destino}${ORB[Zpoollist]}"

  # Crea registro docker systemctl
  echoe "TRADUCCION" ">>>    Extrayendo información de systemd (systemctl)..."
  systemctl list-unit-files | tee "${Destino}${ORB[Systemctl]}"

  # Copia directorios opcionales
  echoe ">>>    Copying optional $OpFold directory..." ">>>    Copiando directorio opcional $OpFold..."
  mkdir -p "${Destino}/ORB_OptionalFolders$OpFold"
  rsync -av "$OpFold"/ "${Destino}/ORB_OptionalFolders$OpFold"
  while [ "$*" ]; do
    echoe ">>>    Copying optional $1 directory..." ">>>    Copiando directorio opcional $1..."
    mkdir -p "${Destino}/ORB_OptionalFolders$OpFold"
    rsync -av "$1"/ "${Destino}/ORB_OptionalFolders$1"
    shift
  done

  # Elimina backups antiguos
  echoe ">>>    Deleting backups larger than ${OpDias} days..." ">>>    Eliminando backups de hace más de ${OpDias} días..."
  find "${Ruta}/" -maxdepth 1 -type d -name "ORB_*" -mtime "+$OpDias" -exec rm -rv {} +
  # Nota:   -mmin = minutos  ///  -mtime = dias
  
  echoe "\n       Backup completed!\n" "\n       ¡Backup completado!\n"
  exit
fi

# EJECUTA REGENERACION DE SISTEMA

# Comprobar backup
for i in "${ORB[@]}"; do
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
for i in $(awk '{print NR}' "${Ruta}${ORB[Dpkg]}")
do
  Plugin=$(awk -v i="$i" 'NR==i{print $2}' "${Ruta}${ORB[Dpkg]}")
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
  KernelOR=$(awk '{print $3}' "${Ruta}${ORB[Unamea]}" | awk -F "." '/pve$/ {print $1"."$2}')
  KernelIN=$(uname -r | awk -F "." '/pve$/ {print $1"."$2}')
  if [ "${KernelOR}" ] && [ ! "${KernelOR}" = "${KernelIN}" ]; then
    echoe "Installing proxmox kernel ${KernelOR}" "Instalando kernel proxmox ${KernelOR}"
    cp -a /usr/sbin/omv-installproxmox /tmp/installproxmox
    sed -i 's/^exit 0.*$/echo "0"/' /tmp/installproxmox
    . /tmp/installproxmox "${KernelOR}"
    rm /tmp/installproxmox
    echoe "TRADUCCION" "Kernel proxmox "${KernelOR}" instalado."
    if [ "${OpRebo}" ]; then
      echoe "TRADUCCION" "\nOpción reinicio activada.\nPara utilizar el nuevo kernel se va a reiniciar el sistema.\nLa regeneración continuará en segundo plano.\nNo apagues el servidor."
      echoe 10 "\nPara   ABORTAR REINICIO   presiona una tecla antes de 10 segundos..."
      if [ "${Tecla}" ]; then
        echoe "TRADUCCION" "Reinicio abortado.\n"
      else
        Creasysreboot
        systemctl enable omv-regen-reboot.service
        echoe 3 "TRADUCCION" "Servicio de reinicio habilitado."
        echoe "Rebooting..." "Reiniciando..."
        reboot
        exit
      fi
    fi
    echoe "TRADUCCION" "Opción reinicio deshabilitada.\nPara utilizar el nuevo kernel debes reiniciar el sistema manualmente.\nPara completar la regeneración ejecuta de nuevo omv-regen regenera después de reiniciar.\n Saliendo..."
    exit
  fi
fi

# Instalar openmediavault-zfs. Importar pools.
Analiza openmediavault-zfs
if [ "${VersIdem}" = OK ] && [ "${InstII}" = "NO" ]; then
  InstalaPlugin openmediavault-zfs
  # SOLUCIONAR. ESTE BUCLE NO FUNCIONA.
  for i in $(awk 'NR>1{print $1}' "${Ruta}$ORB[Zpoollist]"); do
    zpool import -f $i 
  done
fi

# Instalar docker en la ubicacion original si estaba instalado y no está instalado
DockerOR=$(cat "${Ruta}"ORB[Systemctl] | grep docker.service | awk '{print $2}')
DockerII=$(systemctl list-unit-files | grep docker.service | awk '{print $2}')
if [ "${DockerOR}" ] && [ ! "${DockerII}" ]; then
  echoe "TRADUCCION" "Instalando docker..."
  LeeConfig "dockerStorage"
  if [ ! "${ValorConfig}" = "/var/lib/docker" ]; then
    #   Montar sistema de archivos en el que estaba docker
    #   Instalar docker
  else
    # Si compose estaba instalado instalar compose 
      # Si no Instala docker en ubicacion predeterminada
  fi
fi

# Instalar resto de complementos
for i in "${ListaInstalar[@]}"; do
  Analiza "$i"
  if [ "${VersIdem}" = OK ] && [ "${InstII}" = "NO" ]; then
    InstalaPlugin "$i"
  fi
done

# Restaurar configuración del servidor original si no se ha hecho ya
if [ "$(diff "$Ruta$Passwd" "$Passwd")" ]; then
  echoe "TRADUCCION" "Implementando configuración del servidor original..."
  rsync -av "${Ruta}"/ "/" --exclude ROB_*
  omv-salt stage run prepare
  omv-salt stage run deploy

  # Reinstalar openmediavault-sharerootfs
  echoe "TRADUCCION" "Configurando openmediavault-sharerootfs..."
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

  echoe "TRADUCCION" "Regeneración completada. Reinicia para aplicar cambios."
  exit
fi

echoe "\n       Done!\n" "\n       ¡Hecho!\n"
exit