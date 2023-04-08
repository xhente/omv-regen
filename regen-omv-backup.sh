#!/bin/bash

# Guarda este archivo de texto en   /home/regen-omv.sh
# Convierte el archivo en ejecutable con   chmod +x /home/regen-omv.sh
# Programa una tarea diaria en la GUI que ejecute   /home/regen.sh /PATH_TO_BACKUP
# Reemplaza /PATH_TO_BACKUP por la ruta a tu carpeta de backups.
# Consejo;) Programa una tarea semanal con notificaciones y una diaria sin notificaciones.

# Copy this text file to    /home/regen-omv.sh
# Make the file executable with   chmod +x /home/regen-omv.sh
# Schedule a daily task in the GUI that executes   /home/regen.sh /PATH_TO_BACKUP
# Replace /PATH_TO_BACKUP with the path to your backup folder.
# Tip;) Schedule a weekly task with notifications and a daily one without notifications.

# Los backups se conservan durante 7 días. Modifica Dias para variarlo.
# Backups are kept for 7 days. Modify Dias to vary it.
Dias=7

# Personaliza las carpetas "/foo" que quieres respaldar
# Customize the "/foo" folders you want to back up
declare -a Origen=( "/home" "/etc/libvirt/qemu" "/etc/wireguard" )

Fecha=$(date +%y%m%d_%H%M)
[ $(cut -b 7,8 /etc/default/locale) = es ] && Id=esp

[ $Id ] && echo -e "\n       <<< Backup para regenerar sistema de fecha $Fecha >>>" || echo -e "\n       <<< Backup to regenerate system dated $Fecha >>>"

if [ "$1" ] && [ ! "$2" ]; then
  Destino="$1/regen_omv/R_O_$Fecha"
  mkdir -p "$Destino"
  [ $Id ] && echo -e "\n       Se eliminarán los backups de más de $Dias días.\n       Para conservarlo cambia el prefijo a R_O_$Fecha\n" || echo -e "\n       Backups older than $Dias days will be deleted.\n       To keep it change the prefix to R_O_$Fecha\n"
  else
    [ $Id ] && echo -e "\n                  ¡¡ NO SE HA HECHO EL BACKUP !!\n\n       Escribe la ruta después del comando  -> regen-omv.sh /path_to/backup\n       Si hay espacios usa comillas -> regen-omv.sh \"/path to/backup\"\n" || echo -e "\n                  THE BACKUP HAS NOT BEEN DONE !!\n\n       Write the backup path after the command -> regen-omv.sh /path_to/backup\n       If there are spaces use quotes -> regen-omv.sh \"/path to/backup\"\n"
    exit
fi

[ $Id ] && echo ">>>    Extrayendo base de datos a $Destino..." || echo ">>>    Extracting database to $Destino..."
rsync -av /etc/openmediavault/config.xml "$Destino"/

[ $Id ] && echo ">>>    Creando lista de complementos..." || echo ">>>    Creating plugin list..."
dpkg -l | awk '/openmediavault/ {print $2"\t"$3}' > "$Destino"/Lista_complementos
sed -i '/keyring/d' "$Destino"/Lista_complementos
cat "$Destino"/Lista_complementos

[ $Id ] && echo ">>>    Creando lista de usuarios y UIDs..." || echo ">>>    Creating list of users and UIDs..."
awk -F ":" 'length($3) == 4 {print $3"\t"$1}' /etc/passwd | tee "$Destino"/Lista_usuarios

[ $Id ] && echo ">>>    Extrayendo red..." || echo ">>>    Extracting network..."
cat /etc/openmediavault/config.xml | sed -n 's:.*<address>\(.*\)</address>.*:\1:p' | tee "$Destino"/Red

if [ "${Origen[0]}" ]; then
  [ $Id ] && echo ">>>    Copiando carpetas personalizadas..." || echo ">>>    Copying custom folders..."
  for i in "${Origen[@]}"; do
    [ $Id ] && echo ">>>    Copiando datos de $i..." || echo ">>>    Copying data from $i..."
    if [ ! -d "$i" ]; then
      [ $Id ] && echo ">>>    La carpeta $i no existe en el origen. ¡No se copia!" || echo ">>>    The folder $i does not exist in the source. It is not copied!"
    else
      mkdir -p "$Destino$i"
      rsync -av --delete "$i"/ "$Destino$i"
    fi
  done
else
  [ $Id ] && echo ">>>    No se han definido carpetas personalizadas en el origen." || echo ">>>    No custom folders are defined in the source."
fi

[ $Id ] && echo ">>>    Eliminando backups de más de $Dias días..." || echo ">>>    Deleting backups larger than $Dias days..."
# PUEDE SER PELIGROSO modificar la siguiente línea. Asegúrate de lo que cambias.
# It MAY BE DANGEROUS to modify the following line. Make sure what you change.
find "$1/regen_omv"/ -maxdepth 1 -type d -name "R_O_*" -mtime "+$Dias" -exec rm -rv {} +
# -mmin = minutos  ///  -mtime = dias

[ $Id ] && echo -e "\n       ¡Hecho!\n" || echo -e "\n       Done!\n"

Msp="$Destino"/Leeme; touch $Msp
Men="$Destino"/Readme; touch $Men

echo -e "                     __________________________________________                      " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "                     PARA REGENERAR EL SISTEMA HAZ LO SIGUIENTE                      " >> "$Msp"
echo -e "                     __________________________________________                      " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "ACTUALIZA EL SISTEMA ORIGINAL Y HAZ UN BACKUP con este script.                       " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "INSTALA OMV en tu servidor y actualiza (puedes usar un disco diferente).             " >> "$Msp"
echo -e "  - Conecta los discos de datos.                                                     " >> "$Msp"
echo -e "  - Instala los complementos de la lista a continuación.                             " >> "$Msp"
echo -e "      - Si tenías docker instálalo ahora.                                            " >> "$Msp"
echo -e "      - Si usas ZFS cambia el kernel a proxmox.                                      " >> "$Msp"
echo -e "  - No configures nada.                                                              " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "CREA LOS USUARIOS de la lista siguiendo el orden de sus UID. Primero el 1000...      " >> "$Msp"
echo -e "  - Puedes cambiar las contraseñas si las has perdido. No son necesarias.            " >> "$Msp"
echo -e "  - Cambia la contraseña del usuario admin, ahora es la predeterminada.              " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "REEMPLAZA LA BASE DE DATOS de Openmediavault.                                        " >> "$Msp"
echo -e "  - Copia el archivo config.xml de tu backup a /etc/openmediavault/config.xml        " >> "$Msp"
echo -e "  - Implementa la nueva configuración, ejecuta estos comandos:                       " >> "$Msp"
echo -e "          omv-salt stage run prepare                                                 " >> "$Msp"
echo -e "          omv-salt stage run deploy                                                  " >> "$Msp"
echo -e "  - Espera unos minutos y reinicia.                                                  " >> "$Msp"
echo -e "  - Si tienes sistemas de archivo ZFS importa el pool desde la GUI.                  " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "HAS ACABADO. Inicia tus contenedores y ya te puedes tomar una cerveza. Salud.        " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "                     __________________________________________                      " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "  LISTA DE COMPLEMENTOS INSTALADOS Y NÚMERO DE VERSIÓN                               " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
cat "$Destino"/Lista_complementos >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "                     __________________________________________                      " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "  LISTA DE USUARIOS Y UIDs                                                           " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
cat "$Destino"/Lista_usuarios >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "                     __________________________________________                      " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "  RED                                                                                " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
sed -n '2p' "$Destino"/Red >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e "                                                                                     " >> "$Msp"
echo -e " Más información aquí. https://forum.openmediavault.org/index.php?thread/47111-how-to-regenerate-a-complete-omv-system/" >> "$Msp"


echo -e "                      _________________________________________                      " >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "                      TO REGENERATE THE SYSTEM DO THE FOLLOWING                      " >> "$Men"
echo -e "                      _________________________________________                      " >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "UPDATE THE ORIGINAL SYSTEM AND MAKE A BACKUP with this script.                       " >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "INSTALL OMV on your server and update (you can use a different disk).                " >> "$Men"
echo -e "  - Connect the data disks.                                                          " >> "$Men"
echo -e "  - Install the plugins from the list below.                                         " >> "$Men"
echo -e "      - If you had docker, install it now.                                           " >> "$Men"
echo -e "      - If you are using ZFS, change the kernel to proxmox.                          " >> "$Men"
echo -e "  - Do not configure anything.                                                       " >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "CREATE THE USERS in the list following the order of their UIDs. First the 1000...    " >> "$Men"
echo -e "  - You can change the passwords if you have lost them. They are not necessary.      " >> "$Men"
echo -e "  - Change the password of the admin user, it is now the default.                    " >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "REPLACES THE OPENMEDIAVAULT DATABASE.                                                " >> "$Men"
echo -e "  - Copy the config.xml file from your backup to /etc/openmediavault/config.xml      " >> "$Men"
echo -e "  - Deploy the new configuration, run these commands:                                " >> "$Men"
echo -e "          omv-salt stage run prepare                                                 " >> "$Men"
echo -e "          omv-salt stage run deploy                                                  " >> "$Men"
echo -e "  - Wait a few minutes and reboot.                                                   " >> "$Men"
echo -e "  - If you have ZFS file systems import the pool from the GUI.                       " >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "You've finished. Start your containers and you can already have a beer. Cheers.      " >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "                     __________________________________________                      " >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "  LIST OF INSTALLED PLUG-INS AND VERSION NUMBER                                      " >> "$Men"
echo -e "                                                                                     " >> "$Men"
cat "$Destino"/Lista_complementos >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "                     __________________________________________                      " >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "  LIST OF USERS AND UIDs                                                             " >> "$Men"
echo -e "                                                                                     " >> "$Men"
cat "$Destino"/Lista_usuarios >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "                     __________________________________________                      " >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "  NETWORK                                                                            " >> "$Men"
echo -e "                                                                                     " >> "$Men"
sed -n '2p' "$Destino"/Red >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e "                                                                                     " >> "$Men"
echo -e " More information here. https://forum.openmediavault.org/index.php?thread/47111-how-to-regenerate-a-complete-omv-system/" >> "$Men"