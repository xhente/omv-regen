
(ENGLISH VERSION BELOW) (ENGLISH VERSION BELOW) (ENGLISH VERSION BELOW) (ENGLISH VERSION BELOW)

(ENGLISH VERSION BELOW) (ENGLISH VERSION BELOW) (ENGLISH VERSION BELOW) (ENGLISH VERSION BELOW)

.

# omv-regen

UTILIDAD PARA MIGRAR LA CONFIGURACIÓN DE OMV A OTRO SISTEMA O
HACER UNA NUEVA INSTALACIÓN DE OMV Y MANTENER LA CONFIGURACIÓN 

ESTADO: Estable. Soporta OMV6 y OMV7.

## INSTALACIÓN

Copia y pega la siguiente linea en una terminal y ejecútala como root o con sudo.

```
sudo wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | sudo bash
```

   - PASO 1. Crea un backup del sistema original con omv-regen.
   - PASO 2. Haz una instalación nueva de OMV en el disco que quieras y conecta las unidades de datos originales.
   - PASO 3. Utiliza omv-regen para migrar las configuraciones del sistema original al nuevo sistema.

![omv-regen_7_esp](https://github.com/xhente/omv-regen/assets/110301854/662d83e2-8c2c-42d9-8d1c-24f6c3687410)


## QUÉ ES OMV-REGEN

   - omv-regen es una utilidad que se ejecuta en línea de comando (CLI) y que sirve para migrar/regenerar las configuraciones realizadas en la interfaz gráfica de usuario (GUI) de un sistema openmediavault (OMV) a otro sistema OMV. Es un script realizado en bash.
   - omv-regen se divide en dos funciones principales, ambas integradas en una interfaz gráfica de usuario, omv regen backup y omv-regen regenera.
   - omv-regen backup -> hace un backup de las configuraciones realizadas en la GUI del sistema original de OMV. Los archivos necesarios para hacer una regeneración del sistema se empaquetan en un archivo tar, fundamentalmente la base de datos y algunos otros archivos del sistema, además de otros generados por omv-regen que contienen información necesaria del sistema.
   - omv-regen regenera -> hace una regeneración de todas las configuraciones de la GUI de OMV del sistema original en un sistema nuevo de OMV a partir del backup realizado con omv-regen backup. Requiere realizar previamente una instalación limpia de OMV, preferiblemente en otro disco o pendrive diferente.

## QUÉ NO ES OMV-REGEN

   - omv-regen no es una utilidad para backup programado y restauración del sistema operativo encualquier momento. Si necesitas un backup de openmediavault que puedas restaurar en cualquier momento utiliza el complemento openmediavault-backup. La razón de esto se explican detalladamente en el apartado "Limitaciones de omv-regen", pero el resumen es que necesitas un backup actualizado para poder restaurar con omv-regen.
   - Alternativamente puedes regenerar el sistema en otra unidad, por ejemplo un pendrive y seguir utilizando el disco/pendrive original, eso te proporcionaría un backup utilizable en cualquier momento.

## OMV-REGEN ES ÚTIL PARA

   - Reinstalar openmediavault en un disco nuevo o un hardware nuevo manteniendo las configuraciones.
   - Migrar openmediavault entre diferentes arquitecturas, por ejemplo de una Raspberry a un sistema x86 o viceversa, pero cuidado, no todos los complementos son compatibles con todas las arquitecturas.
   - Conseguir una instalación limpia de openmediavault tras un cambio de versiones de openmediavault. Si por ejemplo actualizas OMV6 a OMV7 y la actualización da problemas omv-regen puede trasladar la configuración a un sistema limpio.
   - Reinstalar el sistema si se ha vuelto inestable por algún motivo, siempre que la base de datos esté en buen estado y el sistema pueda actualizarse a la última versión disponible.
   - Puedes obtener un sistema en funcionamiento con tu configuración actual y seguir utilizando el sistema original. Solo regenera tu sistema en un pendrive por ejemplo. Eso te proporcionará una copia de seguridad real de tu sistema.

## LIMITACIONES DE OMV-REGEN

   - Las configuraciones realizadas en CLI no se trasladarán al nuevo sistema, se perderán y tendrás que realizarlas de nuevo. omv-regen hace la regeneración a partir de la base de datos de OMV, y esta base de datos solo almacena las configuraciones que se han hecho en la GUI. Un usuario medio lo configurará todo mediante la GUI de OMV pero un usuario avanzado que haga configuraciones personalizadas en CLI debe tener esto en cuenta.
   - Las versiones de openmediavault y de los complementos deben coincidir en el sistema original y el sistema nuevo. Para asegurar esto omv-regen actualizará el sistema original antes de hacer el backup y actualizará el sistema nuevo antes de regenerar. Puede ocurrir que entre el backup y la regeneración se produzca una actualización en los repositorios de OMV. En este caso, si las versiones de openmediavault o de uno de los complementos esenciales (relacionados con los sistemas de archivos) no coinciden la regeneración se detendrá. En este caso debes volver al sistema original y hacer un nuevo backup. Si ocurre eso con cualquier otro complemento no esencial, el complemento se instalará pero no se aplicarán sus configuraciones, la regeneración se completará pero dejando ese complemento listo para configurar manualmente en la GUI de OMV.

## COMO USAR OMV-REGEN

El procedimiento básico se resume en tres pasos, crear un backup, instalar OMV, regenerar la configuración de OMV.
   - PASO 1. Crea un backup del sistema original con omv-regen backup.
      - Inicia sesión por ssh en el sistema original, por ejemplo con putty.
      - Instala omv-regen en el sistema original. Ejecuta `sudo wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | sudo bash`
      - Ejecuta el comando `omv-regen` y sigue las indicaciones de la interfaz gráfica de usuario para crear un backup. Marca la opción para actualizar el sistema antes de hacer el backup. omv-regen creará un archivo comprimido con tar que contiene los archivos necesarios para regenerar el sistema. Si has elegido opcionalmente alguna carpeta se creará otro archivo comprimido por cada carpeta elegida. Los archivos de cada backup están etiquetados en el nombre con fecha y hora.
      - Copia el backup a tu escritorio, por ejemplo con WinSCP. El archivo del backup es muy pequeño y se mueve instantáneamente.
   - PASO 2. Haz una instalación nueva de OMV en el disco que quieras y conecta las unidades de datos originales.
      - Instala openmediavault en un disco o pendrive diferente al original. Conserva el disco original, de esta forma podrás volver al sistema original en cualquier momento.
      - Apaga el sistema. Conecta los discos de datos. Inicia el sistema. No hagas nada mas, no configures nada.
   - PASO 3. Utiliza omv-regen para migrar las configuraciones del sistema original al nuevo sistema.
      - Inicia sesión por ssh en el nuevo sistema, por ejemplo con putty.
      - Instala omv-regen en el nuevo sistema. Ejecuta `sudo wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | sudo bash`
      - Crea una carpeta en el nuevo sistema y copia el backup a esa carpeta, por ejemplo con WinSCP.
      - Ejecuta el comando `omv-regen` y sigue las indicaciones de la interfaz gráfica de usuario para hacer la regeneración. Puedes elegir no configurar la red o no instalar el kernel proxmox si estaba instalado en el sistema original. Es posible que se requiera un reinicio durante el proceso, si es así omv-regen te pedirá hacerlo, después del reinicio ejecuta de nuevo `omv-regen`, el proceso seguirá su curso automáticamente.
      - omv-regen reiniciará el sistema cuando la regeneración finalice. Accede a la GUI de OMV en un navegador y comprueba que todo está como esperabas. Si no puedes acceder presiona Ctrl+Mays+R para borrar la caché del navegador, si es necesario repítelo varias veces.
   - El resultado de la regeneración será el siguiente:
      - Todas las configuraciones realizadas en la GUI de OMV en el sistema original se replicarán en el sistema nuevo. Esto incluye usuarios y contraseñas, sistemas de archivos, docker y contenedores configurados con el complemento compose, etc. Asegúrate de que los datos persistentes de los contenedores residan en un disco independiente, si están en el disco del sistema operativo debes incluir esa carpeta en el backup de omv-regen si no quieres perderlos.
      - NO incluye cualquier configuración realizada en CLI fuera de la GUI de OMV. Usa otros medios para respaldar eso.
      - NO incluye contenedores configurados en Portainer. Deberás recrearlos tu mismo.
      - Los complementos Filebrowser y Photoprism son contenedores podman. No se respaldarán, usa otros medios.
      - Puedes consultar los registros del último mes en el archivo /var/log/omv-regen.log

## FUNCIONES DE OMV-REGEN

  1 - `omv-regen` - Abre la interfaz gráfica con los menús de configuración y ejecución de cualquier función de omv-regen. La GUI te guiará para ejecutar un backup o una regeneración. 

  2 - `omv-regen backup` - Realiza un backup muy ligero de los datos esenciales para regenerar las configuraciones de un sistema OMV. Puedes incluir carpetas opcionales, incluso de tus discos de datos, y definir el destino. Previamente debes configurar los parámetros del backup en la GUI de omv-regen, una vez configurado puedes ejecutar `omv-regen backup` en CLI o programar una tarea en la GUI de OMV para automatizar backups.

  3 - `omv-regen regenera` - Realiza una regeneración de un sistema completo OMV con sus configuraciones originales a partir de una instalación nueva de OMV y el backup del sistema original realizado con omv-regen backup. Ejecuta omv-regen en línea de comando y la interfaz te guiará para configurar los parámetros y ejecutar la regeneración. Después puedes ejecutarla desde el menú o desde CLI con el comando `omv-regen regenera` 

  4 - `omv-regen ayuda` - Acceso a los cuadros de diálogo con la ayuda completa de omv-regen.

## ALGUNOS CONSEJOS

  - CARPETAS OPCIONALES: Si eliges carpetas opcionales asegúrate de que no son carpetas de sistema. O, si lo son, al menos asegúrate de que no dañarán el sistema cuando se copien al disco de OMV. Sería una lástima romper el sistema por esto una vez regenerado.
  - COMPLEMENTOS FILEBROWSER Y PHOTOPRISM: Si utilizas los complementos Filebrowser o Photoprism o cualquier otro basado en podman debes buscar medios alternativos para respaldarlos, omv-regen no los respaldará. omv-regen los instalará y regenerará las configuraciones de la base de datos de OMV, esto incluye las configuraciones de la GUI de OMV, carpeta compartida, puerto de acceso al complemento, etc. Pero las configuraciones internas de los dos contenedores se perderán. Tal vez sea suficiente con incluir la carpeta donde reside la base de datos del contenedor para que omv-regen también la restaure. Esto no garantiza nada, solo es una sugerencia no probada.
  - OPENMEDIAVAULT-APTTOOL: Si tienes algún paquete instalado manualmente, por ejemplo lm-sensors, y quieres que también se instale al mismo tiempo puedes usar el complemento apttool. omv-regen instalará los paquetes que se hayan instalado mediante este complemento.
  - OPENMEDIAVAULT-SYMLINK: Si usas symlinks en tu sistema omv-regen los recreará si se generaron con el complemento. Si lo hiciste de forma manual en CLI tendrás que volver a hacerlo en el sistema nuevo.
  - HAZ LA REGENERACION INMEDIATAMENTE DESPUÉS DEL BACKUP: Debes hacer el backup y de forma inmediata hacer la regeneración para evitar diferencias entre versiones de paquetes. Ver Limitaciones de omv-regen.
  - UNIDAD DE SISTEMA DIFERENTE: Es muy recomendable utilizar una unidad de sistema diferente a la original para instalar OMV en el sistema nuevo. Es muy sencillo usar un pendrive para instalar openmediavault. Si tienes la mala suerte de que se publique una actualización de un paquete esencial entre el momento del backup y el momento de la regeneración no podrás terminar la regeneración, y necesitarás el sistema original para hacer un nuevo backup actualizado.
  - CONTENEDORES DOCKER: Toda la información que hay en el disco de sistema original va a desaparecer. Para conservar los contenedores docker en el mismo estado asegúrate de hacer algunas cosas antes. Cambia la ruta de instalación por defecto de docker desde la carpeta /var/lib/docker a una carpeta en alguno de los discos de datos. Configura todos los volumenes de los contenedores fuera del disco de sistema, en alguno de los discos de datos. Estas son recomendaciones generales, pero en este caso con mas motivo, si no lo haces perderás esos datos. Alternativamente puedes añadir carpetas opcionales al backup.

## OPCIONES DE OMV-REGEN BACKUP

  - RUTA DE LA CARPETA DE BACKUPS: Esta carpeta se usará para almacenar todos los backups generados. Por defecto esta carpeta es /ORBackup, puedes usar la que quieras pero no uses los discos de datos si pretendes hacer una regeneración, no serán accesibles en ese momento. Para hacer una regeneración es mejor copiar el backup directamente a tu escritorio con WinSCP o similar y luego copiarla al sistema nuevo. En esta carpeta omv-regen creará un archivo empaquetado con tar para cada backup, etiquetado con la fecha y la hora en el nombre. Si has incluido carpetas opcionales en el backup se crearán archivos adicionales también empaquetados con tar y con la etiqueta user1, user2,... Las subcarpetas tienen el prefijo ORB_ en su nombre. Si quieres conservar alguna versión de backup en particular y que omv-regen no la elimine puedes editar este prefijo a cualquier otra cosa y no se eliminará esa subcarpeta. Puedes utilizar `omv-regen backup` para programar backups con tareas programadas en la GUI de OMV. Se aplicará la configuración guardada. Un backup completo con dos carpetas opcionales hecho el día 1 de octubre de 2023 a las 10:38 a.m. podría tener este aspecto:
    - ORB_231001_103828_regen.tar.gz    <-- Archivo con la información de regenera
    - ORB_231001_103828_user1.tar.gz    <-- Archivo con la carpeta opcional 1 de usuario
    - ORB_231001_103828_user2.tar.gz    <-- Archivo con la carpeta opcional 2 de usuario
  - DIAS QUE SE CONSERVAN LOS BACKUPS: Esta opción establece el número de días máximo para conservar backups. Cada vez que hagas un backup se eliminarán todos aquellos existentes en la misma ruta con mas antigüedad de la configurada, mediante el escaneo de fechas de todos los archivos con el prefijo ORB_ Se establece un valor en días. El valor por defecto son 7 días.
  - ACTUALIZAR EL SISTEMA: Esta opción hará que el sistema se actualice automáticamente justo antes de realizar el backup. Asegúrate que esté activa si tu intención es hacer un backup para proceder a una regeneración inmediatamente después. Desactívala si estás haciendo backups programados. El valor establecido debe ser Si/on o No/off.
  - CARPETAS ADICIONALES: Puedes definir tantas carpetas opcionales como quieras que se incluirán en el backup. Útil si tienes información que quieres transferir al nuevo sistema que vas a regenerar. Si copias carpetas con configuraciones del sistema podrías romperlo. Estas carpetas se devolverán a su ubicación original en la parte final del proceso de regeneración. Se crea un archivo tar comprimido para cada carpeta etiquetado de la misma forma que el resto del backup. Puedes incluir carpetas que estén ubicadas en los discos de datos. Puesto que la restauración de estas carpetas se hace al final del proceso, en ese momento todos los sistemas de archivos ya están montados y funcionando. La carpeta /root se incluirá por defecto en el backup.

## OPCIONES DE OMV-REGEN REGENERA

  - RUTA BACKUP DE ORIGEN: En el menú debes definir la ubicación de esta carpeta. Por defecto será /ORBackup pero puedes elegir la ubicación que quieras. Esta carpeta debe contener al menos un archivo tar generado con omv-regen. Antes de ejecutar una regeneración el programa comprobará que esta carpeta contiene todos los archivos necesarios para la regeneración. Cuando definas una ruta en el menú omv-regen escaneará los archivos de esa ruta y buscará el backup mas reciente. Una vez localizado el backup, omv-regen comprobará que en su interior están todos los archivos necesarios. Si falta algún archivo la ruta no se dará por válida y no se permitirá continuar adelante.
  - INSTALAR KERNEL PROXMOX: Si el sistema original tenía el kernel proxmox instalado tendrás la opción de decidir si quieres instalarlo también en el sistema nuevo o no. Cuando la regeneración esté en funcionamiento, si esta opción está activada se instalará el kernel a mitad de proceso. En ese momento omv-regen te pedirá que reinicies el sistema. Después de eso debes ejecutar de nuevo omv-regen y la regeneración continuará en el punto en que se detuvo. Ten en cuenta que si tienes un sistema de archivos ZFS o usas kvm es recomendable tener este kernel instalado, en caso contrario podrías tener problemas durante la instalación de estos dos complementos. Si desactivas esta opción el kernel proxmox no se instalará en el sistema nuevo.
  - REGENERAR LA INTERFAZ DE RED: Esta opción sirve para omitir la regeneración de la interfaz de red. Si desactivas esta opción no se regenerará la interfaz de red y la IP seguirá siendo la misma que tiene el sistema después del reinicio al final del proceso. Si activas esta opción se regenerará la interfaz de red al final del proceso de regeneración. Si la IP original es distinta de la IP actual deberás conectarte a la IP original después del reinicio para acceder a OMV. El menú te indica cual será esta IP antes de iniciar la regeneración. Cuando finalice la regeneración también la tendrás en pantalla pero podrías no verla si no estás atento.

## CAMBIOS EN LA VERSION 2.0

  - omv-regen tiene ahora una GUI mediante cuadros de diálogo. Todas las funciones están integradas en la GUI.
  - La configuración ahora es persistente, no es necesario establecer parámetros cada vez.
  - El comando `omv-regen backup` es ahora suficiente para tareas programadas una vez configurados los parámetros en la GUI de omv-regen.
  - El backup ahora se empaqueta con tar, facilitando los movimientos de una carpeta a otra y asegurando que se mantienen los permisos.
  - Mejoras en el control de la regeneración, mejor control del flujo de trabajo.
  - Durante la regeneración se activa backports si es necesario para instalar un complemento.
  - Controles antes del inicio y ayudas en la configuración. Si no está correctamente configurado no se permite iniciar la regeneración.
  - Se ha suprimido el servicio de reinicio, ahora si se instala un kernel se debe reiniciar manualmente. Esto garantiza la visualización del proceso.
  - Si se debe reiniciar durante la regeneración omv-regen registrará el estado del proceso para iniciar automáticamente donde se detuvo.
  - Si hay un corte de energía o cualquier otro problema se puede ejecutar de nuevo omv-regen y continuará donde se detuvo sea donde sea.
  - Selección de complementos según sean o no esenciales. Si hay una actualización en un complemento no esencial el complemento se instalará y no se regenerará, pero la regeneración del sistema continuará.
  - Sistema integrado para avisar o actualizar automáticamente omv-regen a elección del usuario. Si hay una regeneración en curso no se actualizará omv-regen hasta que termine la regeneración del sistema.
  - Elección libre de las carpetas opcionales que se incluyen el backup.
  - Contenido de la ayuda más generoso.

## CAMBIOS EN LA VERSION 7.0

  - omv-regen ahora admite las versiones de Openmediavault 6.x y 7.x
  - Añadido soporte para los nuevos complementos de OMV7.
      - openmediavault-diskclone
      - openmediavault-hosts
      - openmediavault-iperf3
      - openmediavault-md
      - openmediavault-mounteditor
      - openmediavault-podman
      - openmediavault-webdav
  - Instalación selectiva de omv-extras en función de la versión de Openmediavault.

Nota: Ver mas abajo un esquema de la configuración de ejecución

AGRADECIMIENTOS: Gracias a Aaron Murray por sus consejos en el desarrollo de omv-regen.
_____________________________________________________________________________________________________________________

# omv-regen

UTILITY TO MIGRATE OMV CONFIGURATION TO ANOTHER SYSTEM OR
DO A NEW OMV INSTALLATION AND KEEP THE SETTINGS

STATE: Stable. Supports OMV6 and OMV7.

## INSTALLATION:

Copy and paste the following line into a terminal and run it as root or with sudo.

```
sudo wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | sudo bash
```

   - STEP 1. Create a backup of the original system with omv-regen.
   - STEP 2. Do a fresh installation of OMV on the disk you want and connect the original data drives.
   - STEP 3. Use omv-regen to migrate the settings from the original system to the new system.

![omv-regen_7_eng](https://github.com/xhente/omv-regen/assets/110301854/a4201a06-dced-40cc-be7e-d1d947f39abe)

## WHAT IS OMV-REGEN

   - omv-regen is a command line (CLI) utility that is used to migrate/regenerate the configurations made in the graphical user interface (GUI) of one openmediavault (OMV) system to another OMV system. It is a script made in bash.
   - omv-regen is divided into two main functions, both integrated into a graphical user interface, omv regen backup and omv-regen regenera.
   - omv-regen backup -> makes a backup of the configurations made in the GUI of the original OMV system. The files necessary to perform a system regeneration are packaged in a tar file, primarily the database and some other system files, as well as others generated by omv-regen that contain necessary system information.
   - omv-regen regenera -> regenerates all the OMV GUI configurations of the original system on a new OMV system from the backup made with omv-regen backup. It requires previously performing a clean installation of OMV, preferably on a different disk or pendrive.

## WHAT OMV-REGEN IS NOT

   - omv-regen is not a utility for scheduled backup and restore of the operating system at any time. If you need an openmediavault backup that you can restore at any time, use the openmediavault-backup plugin. The reason for this is explained in detail in the "Limitations of omv-regen" section, but the summary is that you need an updated backup to be able to restore with omv-regen.
   - Alternatively, you can regenerate the system on another drive, for example a pendrive, and continue using the original disk/pendrive, which would provide you with a usable backup at any time.

## OMV-REGEN IS USEFUL FOR

   - Reinstall openmediavault on a new disk or new hardware keeping the configurations.
   - Migrate openmediavault between different architectures, for example from a Raspberry to an x86 system or vice versa, but be careful, not all plugins are compatible with all architectures.
   - Get a clean installation of openmediavault after a change of openmediavault versions. If, for example, you update OMV6 to OMV7 and the update causes problems, omv-regen can move the configuration to a clean system.
   - Reinstall the system if it has become unstable for any reason, as long as the database is healthy and the system can be updated to the latest available version.
   - You can get a working system with your current configuration and still use the original system. Just regenerate your system on a pendrive for example. That will provide you with a real backup of your system.

## LIMITATIONS OF OMV-REGEN

   - Configurations made in CLI will not be carried over to the new system, they will be lost and you will have to make them again. omv-regen does the regeneration from the OMV database, and this database only stores the configurations that have been made in the GUI. An average user will configure everything using the OMV GUI but an advanced user doing custom configurations in the CLI should keep this in mind.
   - The openmediavault and plug-in versions must match on the original system and the new system. To ensure this omv-regen will update the original system before doing the backup and will update the new system before regenerating. It may happen that between the backup and the regeneration, an update occurs in the OMV repositories. In this case, if the versions of openmediavault or one of the essential plugins (related to file systems) do not match, the regeneration will stop. In this case you must return to the original system and make a new backup. If that happens with any other non-essential plugin, the plugin will be installed but its configurations will not be applied, the regeneration will complete but leaving that plugin ready to be manually configured in the OMV GUI.

## HOW TO USE OMV-REGEN

The basic procedure is summarized in three steps, create a backup, install OMV, regenerate the OMV configuration.
   - STEP 1. Create a backup of the original system with omv-regen.
      - Log in via ssh on the original system, for example with putty.
      - Install omv-regen on the original system. Run -> `sudo wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | sudo bash`
      - Run the `omv-regen` command and follow the GUI prompts to create a backup. Check the option to update the system before making the backup. omv-regen will create a tar archive containing the files needed to regenerate the system. If you have optionally chosen a folder, another compressed file will be created for each folder chosen. The files in each backup are labeled in name with date and time.
      - Copy the backup to your desktop, for example with WinSCP. The backup file is very small and moves instantly.
   - STEP 2. Do a fresh installation of OMV on the desired disk and connect the original data drives.
      - Install openmediavault on a disk or pendrive different from the original one. Keep the original disk, this way you can return to the original system at any time.
      - Turn off the system. Connect the data disks. Start the system. Don't do anything else, don't configure anything.
   - STEP 3. Use omv-regen to migrate the settings from the original system to the new system.
      - Log in via ssh to the new system, for example with putty.
      - Install omv-regen on the new system. Run -> `sudo wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | sudo bash`
      - Create a folder on the new system and copy the backup to that folder, for example with WinSCP.
      - Run the `omv-regen` command and follow the GUI prompts to do the regeneration. You can choose not to configure networking or not install the proxmox kernel if it was installed on the original system. A reboot may be required during the process, if so omv-regen will ask you to do so, after the reboot run omv-regen again, the process will continue automatically.
      - omv-regen will reboot the system when the regeneration is complete. Access the OMV GUI in a browser and check that everything is as you expected. If you cannot access press Ctrl+Shift+R to clear the browser cache, if necessary repeat it several times.
   - The result of the regeneration will be the following:
      - All configurations made in the OMV GUI on the original system will be replicated on the new system. This includes users and passwords, filesystems, docker and containers configured with the compose plugin, etc. Make sure that the persistent data in the containers resides on a separate disk, if it is on the operating system disk you must include that folder in the omv-regen backup if you do not want to lose it.
      - It does NOT include any configuration done in CLI outside of the OMV GUI. Use other means to support that.
      - Does NOT include containers configured in Portainer. You will have to recreate them yourself.
      - Filebrowser and Photoprism plugins are podman containers. They will not be backed up, use other means.
      - You can check the logs for the last month in the file /var/log/omv-regen.log

## OMV-REGEN FEATURES

  1 - `omv-regen` - Opens the graphical interface with the configuration and execution menus for any omv-regen function. The GUI will guide you to run a backup or regeneration.

  2 - `omv-regen backup` - Performs a very light backup of essential data to regenerate the configurations of an OMV system. You can include optional folders, even from your data disks, and define the destination. You must previously configure the backup parameters in the omv-regen GUI, once configured you can run `omv-regen backup` in the CLI or schedule a task in the OMV GUI to automate backups. 

  3 - `omv-regen regenera` - Regenerates a complete OMV system with its original configurations from a fresh OMV installation and the backup of the original system made with omv-regen backup. Run omv-regen on the command line and the interface will guide you to configure the parameters and run the regeneration. Then you can run it from the menu or from CLI with the command `omv-regen regenera`

  4 - `omv-regen help` - Access to dialogs with full omv-regen help.

## SOME ADVICES

  - OPTIONAL FOLDERS: If you choose optional folders make sure they are not system folders. Or, if they are, at least make sure they won't harm your system when copied to the OMV disk. It would be a shame to break the system for this once regenerated.
  - FILEBROWSER AND PHOTOPRISM PLUGINS: If you use the Filebrowser or Photoprism plugins or any other based on podman you should find alternative means to back them up, omv-regen will not support them. omv-regen will install them and regenerate the OMV database configurations, this includes the OMV GUI configurations, shared folder, plugin access port, etc. But the internal configurations of the two containers will be lost. It may be enough to include the folder where the container database resides so that omv-regen will restore it as well. This does not guarantee anything, it is just an untested suggestion.
  - OPENMEDIAVAULT-APTTOOL: If you have a package installed manually, for example lm-sensors, and you want it to also be installed at the same time you can use the apttool plugin. omv-regen will install packages that have been installed using this plugin.
  - OPENMEDIAVAULT-SYMLINK: If you use symlinks on your system omv-regen will recreate them if they were generated with the plugin. If you did it manually in CLI you will have to do it again in the new system.
  - DO THE REGENERATION IMMEDIATELY AFTER THE BACKUP: You must make the backup and immediately do the regeneration to avoid differences between package versions. See Limitations of omv-regen.
  - DIFFERENT SYSTEM UNIT: It is highly recommended to use a different system drive than the original one to install OMV on the new system. It is very easy to use a pendrive to install openmediavault. If you are unlucky enough that an update to an essential package is released between the time of the backup and the time of the rebuild, you will not be able to finish the rebuild, and you will need the original system to make a new updated backup.
  - DOCKER CONTAINERS: All the information on the original system disk will disappear. To keep your docker containers in the same state make sure you do a few things first. Change the default docker installation path from the /var/lib/docker folder to a folder on one of the data disks. Configure all container volumes off the system disk, on one of the data disks. These are general recommendations, but in this case even more so, if you don't do it you will lose that data. Alternatively you can add optional folders to the backup.

## OMV-REGEN BACKUP OPTIONS

  - BACKUP FOLDER PATH: This folder will be used to store all the backups generated. By default this folder is /ORBackup, you can use whatever you want but do not use the data disks if you intend to do a regeneration, they will not be accessible at that time. To do a regeneration it is better to copy the backup directly to your desktop with WinSCP or similar and then copy it to the new system. In this folder omv-regen will create a tar-packaged archive for each backup, labeled with the date and time in the name. If you have included optional folders in the backup, additional files will be created, also packaged with tar and labeled user1, user2,... The subfolders have the ORB_ prefix in their name. If you want to keep a particular backup version and not have omv-regen delete it, you can edit this prefix to anything else and that subfolder will not be deleted. You can use `omv-regen backup` to schedule backups with scheduled tasks in the OMV GUI. The saved settings will be applied. A full backup with two optional folders made on October 1, 2023 at 10:38 a.m. could look like this:
    - ORB_231001_103828_regen.tar.gz    <-- File with regenera information
    - ORB_231001_103828_user1.tar.gz    <-- File with optional user folder 1
    - ORB_231001_103828_user2.tar.gz    <-- File with optional user folder 2
  - DAYS BACKUPS ARE KEPT: This option establishes the maximum number of days to keep backups. Every time you make a backup, all those existing in the same path that are older than the configured one will be eliminated, by scanning the files of all the files with the ORB_ prefix. A value is established in days. The default value is 7 days.
  - UPDATE SYSTEM: This option will cause the system to update automatically just before performing the backup. Make sure it is active if your intention is to make a backup to proceed with a regeneration immediately afterwards. Disable it if you are doing scheduled backups. The set value must be Yes/on or No/off.
  - ADDITIONAL FOLDERS: You can define as many optional folders as you want that will be included in the backup. Useful if you have information that you want to transfer to the new system that you are going to regenerate. If you copy folders with system settings you could break it. These folders will be returned to their original location in the final part of the regeneration process. A compressed tar file is created for each folder labeled the same as the rest of the backup. You can include folders that are located on the data disks. Since the restoration of these folders is done at the end of the process, at that point all file systems are already mounted and working. The /root folder is included by default in the backup.

## OMV-REGEN REGENERA OPTIONS

  - SOURCE BACKUP PATH: In the menu you must define the location of this folder. By default it will be /ORBackup but you can choose the location you want. This folder must contain at least one tar file generated with omv-regen. Before executing a regeneration, the program will check that this folder contains all the files necessary for the regeneration. When you define a path in the menu omv-regen will scan the files in that path and look for the most recent backup. Once the backup is located, omv-regen will check that all the necessary files are inside. If any file is missing, the route will not be considered valid and you will not be allowed to continue further.
  - INSTALL PROXMOX KERNEL: If the original system had the proxmox kernel installed you will have the option to decide if you want to also install it on the new system or not. When regeneration is running, if this option is enabled it will install the kernel mid-process. At that point omv-regen will ask you to reboot the system. After that you have to run omv-regen again and the regeneration will continue from the point where it stopped. Keep in mind that if you have a ZFS file system or use kvm it is recommended to have this kernel installed, otherwise you could have problems installing these two plugins. If you disable this option the proxmox kernel will not be installed on the new system.
  - REGENERATE THE NETWORK INTERFACE: This option is used to skip regenerating the network interface. If you deactivate this option, the network interface will not be regenerated and the IP will remain the same as the system's after the reboot at the end of the process. If you activate this option, the network interface will be regenerated at the end of the regeneration process. If the original IP is different from the current IP you will need to connect to the original IP after the reboot to access OMV. The menu tells you what this IP will be before starting the regeneration. When the regeneration ends you will also have it on the screen but you may not see it if you are not attentive.

## CHANGES FROM VERSION 2.0

  - omv-regen now has a GUI using dialogs. All functions are integrated into the GUI.
  - Settings are now persistent, no need to set parameters every time.
  - The `omv-regen backup` command is now sufficient for scheduled tasks once the parameters are configured in the omv-regen GUI.
  - Backup is now tar-packaged, making it easier to move from one folder to another and ensuring permissions are maintained.
  - Improvements in regeneration control, better workflow control.
  - During regeneration backports are activated if necessary to install a plugin.
  - Controls before start and help in configuration. If it is not correctly configured, regeneration is not allowed to start.
  - The reboot service has been removed, now if a kernel is installed it must be rebooted manually. This guarantees visualization of the process.
  - If it must be restarted during regeneration omv-regen will record the state of the process to automatically start where it stopped.
  - If there is a power outage or any other problem you can run omv-regen again and it will continue where it stopped wherever.
  - Selection of plugins according to whether or not they are essential. If there is an update to a non-essential plugin the plugin will be installed and not regenerated, but system regeneration will continue.
  - Integrated system to automatically notify or update omv-regen at the user's choice. If a regeneration is in progress, omv-regen will not be updated until the system regeneration is complete.
  - Free choice of optional folders that are included in the backup.
  - More generous help content.

## CHANGES FROM VERSION 7.0

  - omv-regen now supports Openmediavault versions 6.x and 7.x
  - Added support for new OMV7 plugins.
      - openmediavault-diskclone
      - openmediavault-hosts
      - openmediavault-iperf3
      - openmediavault-md
      - openmediavault-mounteditor
      - openmediavault-podman
      - openmediavault-webdav
  - Selective installation of omv-extras depending on the Openmediavault version.

ACKNOWLEDGMENTS: Thanks to Aaron Murray for his advice in developing omv-regen.
______________________________________________________________________________________________________________________


![CONFIGURACION OMV-REGEN_7 0_Página_1](https://github.com/xhente/omv-regen/assets/110301854/5c7f380c-d921-4b67-bd17-f36bff3122aa)
![CONFIGURACION OMV-REGEN_7 0_Página_2](https://github.com/xhente/omv-regen/assets/110301854/05d58167-8a0b-401a-9339-346f99182818)
![CONFIGURACION OMV-REGEN_7 0_Página_3](https://github.com/xhente/omv-regen/assets/110301854/b8db9eab-a253-434c-b633-16fe27a766db)
[CONFIGURACION OMV-REGEN_7.0.pdf](https://github.com/xhente/omv-regen/files/14469128/CONFIGURACION.OMV-REGEN_7.0.pdf)
[CONFIGURACION OMV-REGEN_7.0.ods](https://github.com/xhente/omv-regen/files/14469129/CONFIGURACION.OMV-REGEN_7.0.ods)
