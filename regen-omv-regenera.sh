#!/bin/bash

# Script para regenerar un sistema OMV
# Este script instalará complementos y usuarios existentes y restaurará la configuración.
# Debe existir un backup previo generado por regen-omv-backup.
# Se debe realizar previamente una instalación y actualización de paquetes de OMV.
# Formato de uso    regen-omv-regenera PATH_TO_BACKUP
# Por ejemplo       regen-omv-regenera /home/backup230401

[ $(cut -b 7,8 /etc/default/locale) = es ] && Id=esp
declare -A BArc
BArc=([BCon]='config.xml' [BCom]='Lista_complementos' [BUsu]='Lista_usuarios' [BRed]='Red')


[ $Id ] && echo -e "\n       <<< Regenerando el sistema >>>" || echo -e "\n       <<< TRADUCCION >>>"

# Actualizar sistema
#omv-upgrade

# Comprobar si están todos los archivos del backup
if [ "$1" ] && [ ! "$2" ]; then
  for i in ${BArc[@]}; do
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
for i in $(awk '{print NR}' $1/${BArc[BCom]})
do
  CO=$(awk -v i="$i" 'NR==i{print $1}' $1/${BArc[BCom]})
  VI=$(awk -v i="$i" 'NR==i{print $2}' $1/${BArc[BCom]})
  VP=$(apt-cache policy "$CO" | awk -F ": " 'NR==2{print $2}')
  if [ "$VI" != "$VP" ]; then
    echo "La versión del backup $CO $VI no coincide con la versión que se va a instalar $CO $VP"
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
