#!/bin/bash

# Script para regenerar un sistema OMV
# Este script instalará complementos y usuarios existentes y restaurará la configuración.
# Debe existir un backup previo generado por regen-omv-backup.
# Se debe realizar previamente una instalación y actualización de paquetes de OMV.
# Formato de uso    regen-omv-regenera PATH_TO_BACKUP
# Por ejemplo       regen-omv-regenera /home/backup230401

[ $(cut -b 7,8 /etc/default/locale) = es ] && Id=esp
declare -A ArchivosBackup
ArchivosBackup=([BackupConfig]='config.xml' [BackupComplementos]='Lista_complementos' [BackupUsuarios]='Lista_usuarios' [BRed]='Red')
declare ComplemInstalar

[ $Id ] && echo -e "\n       <<< Regenerando el sistema >>>" || echo -e "\n       <<< TRADUCCION >>>"

# Actualizar sistema
#omv-upgrade

# Comprobar si están todos los archivos del backup
if [ "$1" ] && [ ! "$2" ]; then
  for i in ${ArchivosBackup[@]}; do
    if [ ! -f "$1/$i" ]; then
      [ $Id ] && echo ">>>    El archivo $1/$i no existe.\n>>>    Asegúrate de introducir la ruta correcta." || echo ">>>    TRADUCCION"
      exit
    fi
  done
else
  [ $Id ] && echo -e "\n      No se han encontrado los archivos del backup\n\n       Escribe la ruta después del comando  -> regen-omv-regenera.sh /path_to/backup\n      Si hay espacios usa comillas -> regen-omv-regenera.sh \"/path to/backup\"\n" || echo -e "\nTRADUCCION"
    exit
fi

# Comprobar versiones
for i in $(awk '{print NR}' $1/${ArchivosBackup[BackupComplementos]})
do
  ComplemInstalar[i]=$(awk -v i="$i" 'NR==i{print $1}' $1/${ArchivosBackup[BackupComplementos]})
  VersionOriginal=$(awk -v i="$i" 'NR==i{print $2}' $1/${ArchivosBackup[BackupComplementos]})
  VersionDisponible=$(apt-cache policy "$ComplemInstalar[i]" | awk -F ": " 'NR==2{print $2}')
  if [ ComplemInstalar[i] = "openmediavault-omvextrasorg" ]; then
    Extras=1
  if [ ComplemInstalar[i] = "openmediavault-kernel" ]; then
    Kernel=1
  fi
  if [ ComplemInstalar[i] = "openmediavault-ZFS" ]; then
    ZFS=1
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

# Instalar complementos
if [ $Extras = "1" ]; then
  wget -O - https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/install | bash
fi
for i in ComplemInstalar[@]
do
  if [ ! $ComplemInstalar[i] = "openmediavault-omvextrasorg" ] 
  apt-get install "$ComplemInstalar[i]"
  fi
done

# Instalar Kernel proxmox si estaba en el sistema original
if [ $Kernel = "1" ]; then
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

# Reiniciar
reboot