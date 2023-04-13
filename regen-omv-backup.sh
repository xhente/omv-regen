#!/bin/bash

# Copia los scripts en /home
# Otorgar permisos de ejecución->
#         chmod +x /home/omv-regen-backup.sh
#         chmod +x /home/omv-regen-regenera.sh
# Programa una tarea diaria en la GUI que ejecute->   /home/omv-regen-backup.sh /[PATH_TO_BACKUP]
# Reemplaza /[PATH_TO_BACKUP] por la ruta a tu carpeta de backups.
# Consejo;) Programa una tarea semanal con notificaciones y una diaria sin notificaciones.

# Copy this text file to    /home/regen-omv.sh
# Make the file executable with   chmod +x /home/regen-omv.sh
# Schedule a daily task in the GUI that executes   /home/regen.sh /PATH_TO_BACKUP
# Replace /PATH_TO_BACKUP with the path to your backup folder.
# Tip;) Schedule a weekly task with notifications and a daily one without notifications.

# Days that backups are kept, by default 7.
# Días que se conservan los backups, por defecto 7.
Dias=7

# Carpetas que se copian por defecto.
declare -a Origen=( "/home" "/etc/libvirt/qemu" "/etc/wireguard" )

# Archivos generados en el backup.
VersPlugins=/VersionPlugins
VersKernel=/VersionKernel
VersOMV=/VersionOMV
Usuarios=/Usuarios
Red=/Red
BaseDatos=/etc/openmediavault/config.xml
ArchPasswd=/etc/passwd
ArchShadow=/etc/shadow


# OPCION EXPORTAR POOL ZFS


# Variables de entorno
Fecha=$(date +%y%m%d_%H%M)
[ $(cut -b 7,8 /etc/default/locale) = es ] && Sp=1
echoe () { [ ! $Sp ] && echo -e $1 || echo -e $2; }

if [[ $(id -u) -ne 0 ]]; then
  echoe "This script must be executed as root or using sudo.  Exiting..." "Este script se debe ejecutar como root o usando sudo.  Saliendo..."
  exit
fi

if [ ! "$(lsb_release --codename --short)" = "bullseye" ]; then
  echoe "Unsupported version.  Only OMV 6.x. are supported.  Exiting..." "Versión no soportada.   Solo está soportado OMV 6.x.   Saliendo..."
  exit
fi

for i in $@; do 
  if [ ! -d "$i" ]; then
    echoe "Path $i not found.  The first parameter is the path of the backup, the following are additional folders to copy to backup.  Use quotes if there are spaces.  Exiting..." "La ruta $i no existe.  El primer parámetro debe ser la ruta del backup, los siguientes son carpetas adicionales para copiar al backup.  Utiliza comillas si hay espacios.  Saliendo..."
    exit
  fi
done

if [[ -n $1 ]]; then
  Ruta="$1"
  shift
  Destino="${Ruta}/omv-regen/ORB_${Fecha}"
else
  echoe "The first parameter is the path of the backup.  Use quotes if there are spaces.  Exiting..." "El primer parámetro debe ser la ruta del backup.  Utiliza comillas si hay espacios.  Saliendo..."
  exit
fi

echoe "\n       <<< Backup to regenerate system dated ${Fecha} >>>" "\n       <<< Backup para regenerar sistema de fecha ${Fecha} >>>"
echoe "\n       Backups older than ${Dias} days will be deleted.\n       To keep it change the prefix to ROB_${Fecha}\n" "\n       Se eliminarán los backups de más de ${Dias} días.\n       Para conservarlo cambia el prefijo a ROB_${Fecha}\n"

echoe ">>>    Copying data to ${Destino}..." ">>>    Copiando datos a ${Destino}..."
mkdir -p "${Destino}/etc/openmediavault"
cp -av "${BaseDatos}" "${Destino}${BaseDatos}"
cp -av "${ArchPasswd}" "${Destino}${ArchPasswd}"
cp -av "${ArchShadow}" "${Destino}${ArchShadow}"
cp -av /home/omv-regen-backup.sh "${Destino}"/omv-regen-backup.sh
cp -av /home/omv-regen-regenera.sh "${Destino}"/omv-regen-regenera.sh

echoe ">>>    Creating plugin list..." ">>>    Creando lista de complementos..."
dpkg -l | awk '/openmediavault/ {print $2"\t"$3}' > "${Destino}${VersPlugins}"
sed -i '/keyring/d' "${Destino}${VersPlugins}"
cat "${Destino}${VersPlugins}"

echoe ">>>    Creating list of users and UIDs..." ">>>    Creando lista de usuarios y UIDs..."
awk -F ":" 'length($3) == 4 {print $3"\t"$1}' /etc/passwd | tee "${Destino}${Usuarios}"

echoe ">>>    Extracting network..." ">>>    Extrayendo red..."
cat "${Destino}${BaseDatos}" | sed -n 's:.*<address>\(.*\)</address>.*:\1:p' | awk 'NR==2{print $0}' | tee "${Destino}${Red}"

echoe ">>>    Extracting kernel version..." ">>>    Extrayendo versión del kernel..."
uname -r | tee "${Destino}${VersKernel}"

echoe ">>>    Extracting OMV version..." ">>>    Extrayendo versión de OMV..."
dpkg -l | awk '$2 == "openmediavault" { print $2" "$3 }'| tee "${Destino}${VersOMV}"

for i in ${Origen[@]}; do
  if [ -d "$i" ]; then
    echoe ">>>    Copying data from $i..." ">>>    Copiando datos de $i..."
    mkdir -p "${Destino}$i"
    rsync -av "$i"/ "${Destino}$i"
  fi
done

while [ "$*" ]; do
  echoe ">>>    Copying data from $1..." ">>>    Copiando datos de $1..."
  mkdir -p "${Destino}/PersonalFolders$1"
  rsync -av "$1"/ "${Destino}/PersonalFolders$1"
  shift
done

echoe ">>>    Deleting backups larger than ${Dias} days..." ">>>    Eliminando backups de más de ${Dias} días..."
# PUEDE SER PELIGROSO modificar la siguiente línea. Asegúrate de lo que cambias.
# It MAY BE DANGEROUS to modify the following line. Make sure what you change.
find "${Ruta}/omv-regen/" -maxdepth 1 -type d -name "ORB_*" -mtime "+$Dias" -exec rm -rv {} +
# -mmin = minutos  ///  -mtime = dias

echoe "\n       Done!\n" "\n       ¡Hecho!\n"

if [ ! $Sp ]; then
  Men="${Destino}/Readme"; touch $Men
  echo -e "                      _________________________________________                      " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "                      TO REGENERATE THE SYSTEM DO THE FOLLOWING                      " >> "$Men"
  echo -e "                      _________________________________________                      " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "UPDATE THE ORIGINAL SYSTEM AND MAKE A BACKUP with this script.                       " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "You've finished. Start your containers and you can already have a beer. Cheers.      " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "                     __________________________________________                      " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "  LIST OF INSTALLED PLUG-INS AND VERSION NUMBER                                      " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  cat "${Destino}${VersPlugins}" >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "                     __________________________________________                      " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "  LIST OF USERS AND UIDs                                                             " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  cat "${Destino}${Usuarios}" >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "                     __________________________________________                      " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "  NETWORK                                                                            " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  cat "${Destino}${Red}" >> "$Men"
  echo -e "                                                                                     " >> "$Men"
  echo -e "                                                                                     " >> "$Men"
else
  Msp="${Destino}/Leeme"; touch $Msp
  echo -e "                     __________________________________________                      " >> "$Msp"
  echo -e "                                                                                     " >> "$Msp"
  echo -e "                     PARA REGENERAR EL SISTEMA HAZ LO SIGUIENTE                      " >> "$Msp"
  echo -e "                     __________________________________________                      " >> "$Msp"
  echo -e "                                                                                     " >> "$Msp"
  echo -e "ACTUALIZA EL SISTEMA ORIGINAL Y HAZ UN BACKUP con este script.                       " >> "$Msp"
  echo -e "                                                                                     " >> "$Msp"
  echo -e "INSTALA OMV en tu servidor y actualiza (puedes usar un disco diferente).             " >> "$Msp"
  echo -e "  - Conecta los discos de datos. No configures nada.                                 " >> "$Msp"
  echo -e "                                                                                     " >> "$Msp"
  echo -e "EJECUTA EL ARCHIVO omv-regen-regenera.sh que está dentro del backup.                 " >> "$Msp"
  echo -e "  - Usa la ruta del backup como parámetro -> omv-regen-regenera.sh [PATH_TO_BACKUP]  " >> "$Msp"
  echo -e "                                                                                     " >> "$Msp"
  echo -e "En este momento es imperativo tomarse una cerveza y esperar pacientemente.           " >> "$Msp"
  echo -e "                                                                                     " >> "$Msp"
  echo -e "                     __________________________________________                      " >> "$Msp"
  echo -e "                                                                                     " >> "$Msp"
  echo -e "  LISTA DE COMPLEMENTOS INSTALADOS Y NÚMERO DE VERSIÓN                               " >> "$Msp"
  echo -e "                                                                                     " >> "$Msp"
  cat "${Destino}${VersPlugins}" >> "$Msp"
  echo -e "                                                                                     " >> "$Msp"
  echo -e "                     __________________________________________                      " >> "$Msp"
  echo -e "                                                                                     " >> "$Msp"
  echo -e "  LISTA DE USUARIOS Y UIDs                                                           " >> "$Msp"
  echo -e "                                                                                     " >> "$Msp"
  cat "${Destino}${Usuarios}" >> "$Msp"
  echo -e "                                                                                     " >> "$Msp"
  echo -e "                     __________________________________________                      " >> "$Msp"
  echo -e "                                                                                     " >> "$Msp"
  echo -e "  RED                                                                                " >> "$Msp"
  echo -e "                                                                                     " >> "$Msp"
  cat "${Destino}${Red}" >> "$Msp"
  echo -e "                                                                                     " >> "$Msp"
  echo -e "                                                                                     " >> "$Msp"
fi