# omv-regen

(English version below)

ESTADO: Estable.

INSTALACIÓN: Copia y pega la siguiente linea en una terminal y ejecútala.

wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | bash

AGRADECIMIENTOS: Gracias a Aaron Murray (Ryecoaaron). Sin tu apoyo esto no sería posible.

FUNCIONES DEL PROGRAMA:

1 - omv-regen backup - Realiza un backup de datos esenciales para regenerar las configuraciones de un sistema OMV.

2 - omv-regen regenera - Regenera un sistema completo OMV con sus configuraciones originales a partir de una instalación nueva de OMV y el backup anterior.

PROCEDIMIENTO:
- Instala omv-regen en el sistema original y haz un backup con omv-regen backup.
- Haz una instalación limpia de OMV, no configures nada. Puedes utilizar otro disco. Recuerda conectar los discos de datos.
- Monta un pendrive con el backup o copialo directamente a una carpeta en root.
- Instala omv-regen en el sistema nuevo y ejecuta omv-regen regenera.
- Cuando termine el proceso tendrás el sistema con una instalado limpia y configurado como el original.

CARACTERÍSTICAS BACKUP:
- Almacena la base de datos del sistema y algunos archivos de configuración neesarios para la regeneración. Ocupa muy poco espacio y se hace en cuestión de segundos.
- Los backups se conservan durante 7 días por defecto. Esto es configurable.
- Puedes programar un backup en la GUI de OMV en tareas programadas simplemente escibiendo el comando adecuado para tu caso.
- Por defecto se copian las carpetas /home y /etc/libvirt (si existe).
- Puedes añadir carpetas personalizadas al backup.
- Si quieres conservar una versión de backup permanentemente edita el prefijo ORB_ de la subcarpeta. Esa versión no se eliminará.
- Ejecuta omv-regen help para ver la ayuda disponible.

CARACTERÍSTICAS REGENERA:
- Regenera un sistema completo desde cero como si lo hicieras en la GUI manualmente, siguiendo el orden establecido en el sistema original.
- Se puede utilizar una unidad de disco diferente para hacer la nueva instalación de OMV. De hecho es aconsejable hacerlo para poder volver al sistema original en caso de necesidad.
- Se instalará el kernel proxmox si existía en el sistema original.
- Opcionalmente puedes saltar la instalación del kernel proxmox.
- Opcionalmente puedes activar el reinicio automático después de instalar el kernel y la regeneración continuará en segundo plano.
- Se reconocerán y montarán automáticamente todos tus discos y sistemas de archivos que existían en el sistema original compatibles con OMV.
- Se regenerarán todas las configuraciones establecidas en la GUI de OMV y las configurará en el sistema automáticamente.
- El backup debe estar actualizado. Idealmente realizar el backup e inmediatamente después realizar la regeneración. Las versiones de paquetes respaldadas deben coincidir con las disponibles para su descarga.
- Se instalarán omv-extras y docker si existían en el sistema original.
- Todos los complementos que existían en el sistema original serán instalados y regenerados. En los complementos basados en podman se regenerarán las configuraciones de la GUI. Las configuraciones del propio contenedor, al igual que los contenedores docker, deben ser respaldadas por otros medios.
- Si quieres evitar la instalación y regeneración de algún complemento que tenías instalado puedes editar el archivo ORB_DpkgOMV y eliminar la linea correspondiente. El complemento no se instalará.
- Todas las configuraciones manuales realizadas en CLI y paquetes instalados manualmente serán omitidas durante la regeneración. Utiliza openmediavault-apttool y openmediavault-symlinks en el sistema original si los necesitas para conservar ciertas configuraciones especiales, después haz el backup.
- El último paso de la regeneración es la configuración de red y el sistema se reiniciará. Después de eso perderás la conexión si tu IP es distinta. En pantalla tendrás la nueva IP. Si quieres evitar perder la conexión establece la misma IP del sistema original antes de lanzar la regeneración.

Nota: Ver mas abajo un esquema de la configuración de ejecución
_____________________________________________________________________________________________________________________

STATE: Stable.

INSTALLATION: Copy and paste the following line in a terminal and run it.

wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | bash

ACKNOWLEDGMENTS: Thanks to Aaron Murray (Ryecoaaron). Without your support this would not be possible.

PROGRAM FUNCTIONS:

1 - omv-regen backup - Makes a backup of essential data to regenerate the configurations of an OMV system.

2 - omv-regen regenera - Regenerates a complete OMV system with its original configurations from a fresh installation of OMV and the previous backup.

PROCEDURE:
- Install omv-regen on the original system and make a backup with omv-regen backup.
- Do a clean install of OMV, don't configure anything. You can use another disk. Remember to connect the data disks.
- Mount a flash drive with the backup or copy it directly to a root folder.
- Install omv-regen on the new system and run omv-regen regenera.
- When the process is finished you will have the system with a clean installation and configured as the original.

BACKUP FEATURES:
- Stores the system database and some configuration files needed for regeneration. It takes up very little space and is done in a matter of seconds.
- Backups are kept for 7 days by default. This is configurable.
- You can schedule a backup in the OMV GUI in scheduled tasks simply by typing the appropriate command for your case.
- By default, the folders /home and /etc/libvirt (if it exists) are copied.
- You can add custom folders to the backup.
- If you want to keep a backup version permanently edit the ORB_ prefix of the subfolder. That version will not be removed.
- Run omv-regen help to see the available help.

REGENERATE FEATURES:
- Regenerate a complete system from scratch as if you did it in the GUI manually, following the order set in the original system.
- A different drive can be used to do the new OMV installation. In fact, it is advisable to do so to be able to return to the original system in case of need.
- The proxmox kernel will be installed if it existed on the original system.
- Optionally you can skip the proxmox kernel installation.
- Optionally you can activate automatic reboot after installing the kernel and the regeneration will continue in the background.
- All your disks and file systems that existed in the original OMV compatible system will be automatically recognized and mounted.
- All the configurations established in the OMV GUI will be regenerated and it will configure them in the system automatically.
- The backup must be updated. Ideally make the backup and immediately after make the regeneration. Supported package versions must match those available for download.
- omv-extras and docker will be installed if they existed on the original system.
- All plugins that existed in the original system will be installed and regenerated. In podman based plugins the GUI settings will be regenerated. The configurations of the container itself, just like docker containers, must be backed up by other means.
- If you want to avoid the installation and regeneration of a plugin that you had installed, you can edit the ORB_DpkgOMV file and delete the corresponding line. The plugin will not install.
- All manual configurations done in CLI and manually installed packages will be skipped during regeneration. Use openmediavault-apttool and openmediavault-symlinks on the original system if you need them to preserve certain special settings, then make the backup.
- The last step of the regeneration is the network configuration and the system will reboot. After that you will lose the connection if your IP is different. On the screen you will have the new IP. If you want to avoid losing the connection, set the same IP of the original system before launching the regeneration.

______________________________________________________________________________________________________________________


![CONFIGURACION OMV-REGEN_Página_1](https://user-images.githubusercontent.com/110301854/235881940-e20fefe6-471e-44fb-a0a5-e0ff85c68e6c.jpg)

![CONFIGURACION OMV-REGEN_Página_2](https://user-images.githubusercontent.com/110301854/235882073-edef0daa-653f-496b-92de-e1883e401416.jpg)

![CONFIGURACION OMV-REGEN_Página_3](https://user-images.githubusercontent.com/110301854/235882138-5c189117-1840-4f04-88b4-59f9f67e48e1.jpg)

[CONFIGURACION OMV-REGEN.pdf](https://github.com/xhente/omv-regen/files/11381266/CONFIGURACION.OMV-REGEN.pdf)

[CONFIGURACION OMV-REGEN.ods](https://github.com/xhente/omv-regen/files/11381321/CONFIGURACION.OMV-REGEN.ods)
