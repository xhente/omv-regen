#!/bin/bash

# Crea la carpeta /home/regen y copia en ella los scripts
# Otorgar permisos de ejecución->
#         chmod +x /home/regen/regen-omv-backup.sh
#         chmod +x /home/regen/regen-omv-regenera.sh
# Programa una tarea diaria en la GUI que ejecute->   /home/regen/regen-omv-backup.sh /[PATH_TO_BACKUP]
# Reemplaza /[PATH_TO_BACKUP] por la ruta a tu carpeta de backups.
# Consejo;) Programa una tarea semanal con notificaciones y una diaria sin notificaciones.

# Copy this text file to    /home/regen-omv.sh
# Make the file executable with   chmod +x /home/regen-omv.sh
# Schedule a daily task in the GUI that executes   /home/regen.sh /PATH_TO_BACKUP
# Replace /PATH_TO_BACKUP with the path to your backup folder.
# Tip;) Schedule a weekly task with notifications and a daily one without notifications.

# Los backups se conservan durante 7 días. Modifica Dias para variarlo.
# Backups are kept for 7 days. Modify Dias to vary it.
Dias=7

declare -a Origen=( "/home" "/etc/libvirt/qemu" "/etc/wireguard" )
VersPlugins=VersionPlugins
VersKernel=VersionKernel
VersOMV=VersionOMV
Usuarios=Usuarios
Red=Red
BaseDatos=config.xml
Fecha=$(date +%y%m%d_%H%M)
[ $(cut -b 7,8 /etc/default/locale) = es ] && Id=esp

if [[ $(id -u) -ne 0 ]]; then
  [ ! $Id ] && echo "This script must be executed as root or using sudo.  Exiting..." || echo "Este script se debe ejecutar como root o usando sudo.  Saliendo..."
  exit
fi

if [ ! "$(lsb_release --codename --short)" = "bullseye" ]; then
  [ ! $Id ] && echo "Unsupported version.  Only OMV 6.x. are supported.  Exiting..." || echo "Versión no soportada.   Solo está soportado OMV 6.x.   Saliendo..."
  exit
fi

for i in $@; do 
  if [ ! -d "$i" ]; then
    [ ! $Id ] && echo "Path $i not found.  The first parameter is the path of the backup, the following are additional folders to copy to backup.  Use quotes if there are spaces.  Exiting..." || echo "La ruta $i no existe.  El primer parámetro es la ruta del backup, los siguientes son carpetas adicionales para copiar al backup.  Utiliza comillas si hay espacios.  Saliendo..."
    exit
  fi
done

if [[ -n $1 ]]; then
  Ruta=$1
  shift
  Destino="$Ruta/regen/ROB_${Fecha}"
  mkdir -p "${Destino}"
else  
  [ ! $Id ] && echo "The first parameter is the path of the backup.  Use quotes if there are spaces.  Exiting..." || echo "El primer parámetro es la ruta del backup, los siguientes son carpetas adicionales para copiar al backup.  Utiliza comillas si hay espacios.  Saliendo..."
  exit
fi

[ ! $Id ] && echo -e "\n       <<< Backup to regenerate system dated ${Fecha} >>>" || echo -e "\n       <<< Backup para regenerar sistema de fecha ${Fecha} >>>"
[ ! $Id ] && echo -e "\n       Backups older than ${Dias} days will be deleted.\n       To keep it change the prefix to ROB_${Fecha}\n" || echo -e "\n       Se eliminarán los backups de más de ${Dias} días.\n       Para conservarlo cambia el prefijo a ROB_${Fecha}\n"

[ ! $Id ] && echo ">>>    Extracting database to ${Destino}..." || echo ">>>    Extrayendo base de datos a ${Destino}..."
rsync -av /etc/openmediavault/config.xml "${Destino}"/

[ ! $Id ] && echo ">>>    Creating plugin list..." || echo ">>>    Creando lista de complementos..."
dpkg -l | awk '/openmediavault-/ {print $2"\t"$3}' > "${Destino}"/"${VersPlugins}"
sed -i '/keyring/d' "${Destino}"/"${VersPlugins}"
cat "${Destino}"/"${VersPlugins}"

[ ! $Id ] && echo ">>>    Creating list of users and UIDs..." || echo ">>>    Creando lista de usuarios y UIDs..."
awk -F ":" 'length($3) == 4 {print $3"\t"$1}' /etc/passwd | tee "${Destino}"/"${Usuarios}"

[ ! $Id ] && echo ">>>    Extracting network..." || echo ">>>    Extrayendo red..."
cat "${Destino}"/"${BaseDatos}" | sed -n 's:.*<address>\(.*\)</address>.*:\1:p' | awk 'NR==2{print $0}' | tee "${Destino}"/"${Red}"

[ ! $Id ] && echo ">>>    Extracting kernel version..." || echo ">>>    Extrayendo versión del kernel..."
uname -r | tee "${Destino}"/"${VersKernel}"

[ ! $Id ] && echo ">>>    Extracting OMV version..." || echo ">>>    Extrayendo versión de OMV..."
dpkg -l | awk '$2 == "openmediavault" { print $2" "$3 }'| tee "${Destino}"/"${VersOMV}"

[ ! $Id ] && echo ">>>    Copying regen scripts..." || echo ">>>    Copiando scripts regen..."
cp -av /home/regen-omv-backup.sh "${Destino}"/regen-omv-backup.sh
cp -av /home/regen-omv-regenera.sh "${Destino}"/regen-omv-regenera.sh

while [ "$*" ]; do
  [ ! $Id ] && echo ">>>    Copying data from $1..." || echo ">>>    Copiando datos de $1..."
  mkdir -p "${Destino}$1"
  rsync -av "$1"/ "${Destino}$1"
  shift
done

for i in ${Origen[@]}; do
  [ ! $Id ] && echo ">>>    Copying data from $i..." || echo ">>>    Copiando datos de $i..."
  mkdir -p "${Destino}$i"
  rsync -av "$i"/ "${Destino}$i"
done

[ ! $Id ] && echo ">>>    Deleting backups larger than ${Dias} days..." || echo ">>>    Eliminando backups de más de ${Dias} días..."
# PUEDE SER PELIGROSO modificar la siguiente línea. Asegúrate de lo que cambias.
# It MAY BE DANGEROUS to modify the following line. Make sure what you change.
find "$Ruta/regen"/ -maxdepth 1 -type d -name "ROB_*" -mtime "+$Dias" -exec rm -rv {} +
# -mmin = minutos  ///  -mtime = dias

[ ! $Id ] && echo -e "\n       Done!\n" || echo -e "\n       ¡Hecho!\n"

Msp="${Destino}"/Leeme; touch $Msp
Men="${Destino}"/Readme; touch $Men

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
echo -e "EJECUTA EL ARCHIVO regen-omv-regenera.sh que está dentro del backup.                 " >> "$Msp"
echo -e "  - Usa la ruta del backup como parámetro -> regen-omv-regenera.sh [PATH_TO_BACKUP]  " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "En este momento es imperativo tomarse una cerveza y esperar pacientemente.           " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "                     __________________________________________                      " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "  LISTA DE COMPLEMENTOS INSTALADOS Y NÚMERO DE VERSIÓN                               " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
cat "${Destino}"/"${VersPlugins}" >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "                     __________________________________________                      " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "  LISTA DE USUARIOS Y UIDs                                                           " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
cat "${Destino}"/"${Usuarios}" >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "                     __________________________________________                      " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "  RED                                                                                " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
cat "${Destino}"/"${Red}" >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"

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
cat "${Destino}"/"${VersPlugins}" >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "                     __________________________________________                      " >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "  LIST OF USERS AND UIDs                                                             " >> "$Men"
echo -e "                                                                                     " >> "$Men"
cat "${Destino}"/"${Usuarios}" >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "                     __________________________________________                      " >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "  NETWORK                                                                            " >> "$Men"
echo -e "                                                                                     " >> "$Men"
cat "${Destino}"/"${Red}" >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "                                                                                     " >> "$Men"
