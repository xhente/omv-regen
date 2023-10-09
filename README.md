
(ENGLISH VERSION BELOW) (ENGLISH VERSION BELOW) (ENGLISH VERSION BELOW) (ENGLISH VERSION BELOW)

(ENGLISH VERSION BELOW) (ENGLISH VERSION BELOW) (ENGLISH VERSION BELOW) (ENGLISH VERSION BELOW)

.

.

# omv-regen 2.0

¿NECESITAS HACER UN RESPALDO O RESTAURAR LA CONFIGURACIÓN DE OMV? ESTA ES LA SOLUCIÓN.

ESTADO: Estable.

## INSTALACIÓN

Copia y pega la siguiente linea en una terminal y ejecútala como root o con sudo.

```
sudo wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | sudo bash
```

   - PASO 1. Crea un backup del sistema original con omv-regen.
   - PASO 2. Haz una instalación nueva de OMV en el disco que quieras y conecta las unidades de datos.
   - PASO 3. Utiliza omv-regen para clonar las configuraciones desde el backup en el nuevo sistema. 


![omv-regen 2 0 esp](https://github.com/xhente/omv-regen/assets/110301854/a1bbfe2e-9c12-485d-b461-16ca2ed15f52)



## CAMBIOS DE LA VERSION 1.0 A LA VERSION 2.0

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
  - Selección de complementos según sean o no esenciales. Si hay una actualización en un complemento no esencial se instalará y no se regenerará, pero la regeneración continuará.
  - Sistema integrado para avisar o actualizar automáticamente omv-regen a elección del usuario. Si hay una regeneración en curso no se actualizará hasta que termine.
  - Elección libre de las carpetas opcionales que se incluyen el backup.
  - Contenido de la ayuda más generoso.

## COMO USAR OMV-REGEN 2.0
omv-regen sirve para regenerar las configuraciones de un sistema openmediavault en una instalación nueva de OMV.

Se podría decir que es una restauración pero decir regeneración es más exacto puesto que se está generando un sistema nuevo. Se reinstala todo el software y se aplican las configuraciones del sistema original. Entrando en detalles, las condiciones para que esto funcione son las siguientes: 
   - Es muy recomendable usar un disco de sistema diferente del original, no es necesario que sea el mismo. 
   - Todos los demás discos deben estar conectados en el momento de hacer la regeneración. 
   - Las versiones de OMV y de los complementos deben coincidir en ambos sistemas, original y nuevo. 

Como consecuencia del punto anterior: 
   - El sistema original debe estar actualizado cuando hagas el backup, no esperes un día para regenerar. 
   - Si se publica alguna actualización de un complemento importante durante el proceso podría detenerse. 
   - Si se da el caso anterior omv-regen decidirá si se puede omitir o no la regeneración de ese complemento. 
   - Ese es el motivo principal por el que es recomendable usar un disco de sistema nuevo y conservar el original. 

El resultado será el siguiente: 
   - Todo lo que está respaldado por la base de datos de OMV se habrá recreado en el sistema nuevo. 
   - Esto incluye docker y contenedores configurados con el complemento compose. Funcionarán como antes. 
   - Incluye todas las configuraciones que hayas hecho en la GUI de OMV, usuarios y contraseñas, sistemas de archivos, etc. 
   - NO incluye cualquier configuración realizada en CLI fuera de OMV. Usa otros medios para respaldar eso. 
   - NO incluye contenedores configurados en Portainer. Deberás recrearlos tu mismo. 
   - Los complementos Filebrowser y Photoprism son contenedores podman. No se respaldarán, usa otros medios.

## FUNCIONES DE OMV-REGEN 2.0

  1 - `omv-regen` - Proporciona acceso a los menús de configuración y ejecución de cualquier función de omv-regen. Desde aquí podrás configurar fácilmente los parámetros para hacer un backup o una regeneración y podrás ejecutar ambos. También podrás gestionar las actualizaciones de omv-regen. 

  2 - `omv-regen backup` - Realiza un backup muy ligero de los datos esenciales para regenerar las configuraciones de un sistema OMV. Puedes incluir carpetas opcionales, incluso de tus discos de datos, y definir el destino. Ejecuta omv-regen en línea de comando y la interfaz te guiará para configurar los parámetros y guardarlos. Después puedes ejecutar el backup desde los menús o desde CLI con el comando: omv-regen backup. Puedes configurar una tarea programada en la GUI de OMV que ejecute el comando omv-regen backup y gestionarlo desde allí. 

  3 - `omv-regen regenera` - Regenera un sistema completo OMV con sus configuraciones originales a partir de una instalación nueva de OMV y el backup del sistema original realizado con omv-regen backup. Ejecuta omv-regen en línea de comando y la interfaz te guiará para configurar los parámetros y ejecutar la regeneración. Después puedes ejecutarla desde el menú o desde CLI con el comando: omv-regen regenera 

  4 - `omv-regen ayuda` - Acceso a los cuadros de diálogo con la ayuda completa de omv-regen.

## PROCEDIMIENTO DE REGENERACION

  - INSTALA OMV-REGEN EN EL SISTEMA ORIGINAL Y HAZ UN BACKUP. Configura un backup en el menú y asegúrate de marcar la opción para actualizar el sistema antes del backup. Se creará un archivo muy ligero empaquetado con tar que incluye todos los archivos e información necesaria para realizar la regeneración. Opcionalmente puedes incluir carpetas personalizadas en el backup. Si lo haces se creará un archivo tar por cada carpeta que selecciones además del archivo anterior. Los archivos de cada backup están etiquetados en el nombre con fecha y hora. Guarda ese backup en alguna parte. WinSCP es una herramienta útil para esto, puedes copiar ese archivo fácilmente a tu escritorio, es un archivo muy pequeño y moverlo es instantáneo. Si configuraste carpetas opcionales copia el resto de archivos también.
  - HAZ UNA INSTALACIÓN NUEVA DE OPENMEDIAVAULT, NO ESPERES. No es posible regenerar si las versiones de los complementos disponibles en internet y las que tenía instalados el sistema original son distintas, esto podría crear conflictos en la base de datos y romper el sistema. Aún cabe la posibilidad de que algún paquete reciba una nueva versión antes de que regeneres. Si ocurre esto omv-regen lo detectará, en ese momento optará por omitir la instalación de ese complemento si es posible, o, si es un complemento que no se puede omitir (como zfs o mergerfs...) se detendrá la regeneración y tendrás que empezar de nuevo. Por lo tanto usa una unidad distinta de la original para instalar OMV y conserva la original, de ese modo siempre puedes volver y hacer un nuevo backup actualizado. Recuerda que puedes instalar openmediavault en un pendrive. Cuando hayas acabado la instalación de OMV no configures nada. Apaga el sistema, conecta los mismos discos de datos que tenía el sistema original e inicia el servidor.
  - COPIA EL BACKUP AL NUEVO OMV, INSTALA OMV-REGEN Y CONFIGURA LA REGENERACION. Crea una carpeta en el disco de sistema y copia el backup en ella. Puedes usar WinSCP o similar para hacer esto por SSH. Instala omv-regen en el nuevo sistema e inícialo para configurar la regeneración en el menú. Los menús te guiarán para configurar la ubicación del backup y otras opciones. Puedes decidir no regenerar la interfaz de red o no instalar el kernel proxmox si estaba instalado en el servidor original. Una vez configurado todo, si los ajustes son válidos te permitirá iniciar la regeneración. En caso contrario te dirá qué es lo que debes cambiar.
  - INICIA LA REGENERACION. Se instalarán todos los complementos que tenías en el sistema original y a medida que se van instalando se va regenerando al mismo tiempo la base de datos con tus configuraciones originales. Si el proceso necesita un reinicio te pedirá que lo hagas tú, después debes ejecutar omv-regen de nuevo y el proceso continuará desde el punto correcto. omv-regen registra el estado de la regeneración, de modo que continuará automáticamente sin hacer nada mas. Si tienes algún corte de luz o similar puedes iniciar el servidor y ejecutar de nuevo omv-regen. Continuará en el punto donde estaba y terminará la regeneración. La duración dependerá de la cantidad de complementos y la velocidad del servidor. Para un caso medio no debería durar mas de 10 o 15 minutos o incluso menos.
  - FINALIZACIÓN. Cuando finalice el proceso te avisará en pantalla y se reiniciará automáticamente. Antes de empezar la regeneración, el menú te dirá cual va a ser la IP del servidor después de la regeneración, puedes anotarla. Al final también saldrá en pantalla pero podrías no verla si no estás atento. Espera a que se reinicie y accede a esa IP. Dependiendo de la configuración de tu red esto podría no ser exacto, en ese caso tendrás que averiguar la IP en tu router o conectándote al servidor con pantalla y teclado. Después del reinicio tendrás el sistema con una instalación limpia y la GUI de OMV configurada exactamente como tenías el sistema original.
  - ¡¡¡¡    RECUERDA BORRAR LA CACHE DE TU NAVEGADOR --> CTRL+MAYS+R    !!!!

## ALGUNOS CONSEJOS

  - CARPETAS OPCIONALES: Si eliges carpetas opcionales asegúrate de que no son carpetas de sistema. O, si lo son, al menos asegúrate de que no dañarán el sistema cuando se copien al disco de OMV. Sería una lástima romper el sistema por esto una vez regenerado.
  - COMPLEMENTOS FILEBROWSER Y PHOTOPRISM: Si utilizas los complementos Filebrowser o Photoprism debes buscar medios alternativos para respaldarlos. Son contenedores podman y omv-regen no los respaldará. omv-regen los instalará y regenerará las configuraciones de la base de datos de OMV, esto incluye las configuraciones de la GUI de OMV, carpeta compartida, puerto de acceso al complemento, etc. Pero las configuraciones internas de los dos contenedores se perderán. Tal vez sea suficiente con incluir la carpeta donde reside la base de datos del contenedor para que omv-regen también la restaure. Esto no garantiza nada, solo es una sugerencia no probada.
  - OPENMEDIAVAULT-APTTOOL: Si tienes algún paquete instalado manualmente, por ejemplo lm-sensors, y quieres que también se instale al mismo tiempo puedes usar el complemento apttool. omv-regen instalará los paquetes que se hayan instalado mediante este complemento.
  - OPENMEDIAVAULT-SYMLINK: De la misma forma que en el caso anterior, si usas symlinks en tu sistema omv-regen los recreará si se generaron con el complemento. Si lo hiciste de forma manual tendrás que volver a hacerlo.
  - INTENTA HACER LA REGENERACION LO ANTES POSIBLE: omv-regen omitirá, si es posible, la instalación de algún complemento si la versión disponible en internet para instalar no coincide con la versión que tenía instalada el servidor original. Esto se podrá hacer siempre que ese complemento no esté relacionado con el sistema de archivos, como pueden ser, mergerfs, zfs o similar, en tal caso la regeneración se detendrá y no podrás continuar. Si esto sucede tendrás que hacer un nuevo backup del sistema original actualizándolo previamente. Para evitar esto NO te demores en hacer la regeneración una vez hayas realizado el backup. omv-regen no te puede avisar antes de empezar a regenerar pues sin omv-extras instalado faltan los repositorios en el sistema para consultar versiones de la mayoría de los complementos.
  - UNIDAD DE SISTEMA DIFERENTE: Por el mismo motivo explicado en el punto anterior es muy recomendable utilizar una unidad de sistema diferente a la original para regenerar. Es muy sencillo usar un pendrive para instalar openmediavault. Si tienes la mala suerte de que se publique una actualización de un paquete esencial entre elmomento del backup y el momento de la regeneración no podrás terminarla, y necesitarás el sistema original para hacer un nuevo backup actualizado.
  - CONTENEDORES DOCKER: Toda la información que hay en el disco de sistema original va a desaparecer. Para conservar los contenedores docker en el mismo estado asegurate de hacer algunas cosas antes. Cambia la ruta de instalación por defecto de docker desde la carpeta /var/lib/docker a una carpeta en alguno de los discos de datos. Configura todos los volumenes de los contenedores fuera del disco de sistema, en alguno de los discos de datos. Estas son recomendaciones generales, pero en este caso con mas motivo, si no lo haces perderás esos datos. Alternativamente puedes añadir la carpeta /var/lib/docker al backup como carpeta opcional.

## OPCIONES DE OMV-REGEN BACKUP 2.0

  - RUTA DE LA CARPETA DE BACKUPS: Esta carpeta se usará para almacenar todos los backups generados. Por defecto esta carpeta es /ORBackup, puedes usar la que quieras pero no uses los discos de datos si pretendes hacer una regeneración, no serán accesibles. Para hacer una regeneración es mejor copiar el backup directamente a tu escritorio con WinSCP o similar y luego copiarla al sistema nuevo. En esta carpeta omv-regen creará un archivo empaquetado con tar para cada backup, etiquetado con la fecha y la hora en el nombre. Si has incluido carpetas opcionales en el backup se crearán archivos adicionales también empaquetados con tar y con la etiqueta user1, user2,... Las subcarpetas tienen el prefijo ORB_ en su nombre. Si quieres conservar alguna versión de backup en particular y que omv-regen no la elimine puedes editar este prefijo a cualquier otra cosa y no se eliminará esa subcarpeta. Puedes utilizar omv-regen para programar backups con tareas programadas en la GUI de OMV. Se aplicará la configuración guardada. Un backup completo con dos carpetas opcionales hecho el día 1 de octubre de 2023 a las 10:38 a.m. podría tener este aspecto:
    - ORB_231001_103828_regen.tar.gz    <-- Archivo con la información de regenera
    - ORB_231001_103828_user1.tar.gz    <-- Archivo con la carpeta opcional 1 de usuario
    - ORB_231001_103828_user2.tar.gz    <-- Archivo con la carpeta opcional 2 de usuario
  - DIAS QUE SE CONSERVAN LOS BACKUPS: Esta opción establece el número de días máximo para conservar backups. Cada vez que hagas un backup se eliminarán todos aquellos existentes en la misma ruta con mas antigüedad de la configurada, mediante el escaneo de fechas de todos los archivos con el prefijo ORB_ Se establece un valor en días. El valor por defecto son 7 días.
  - ACTUALIZAR EL SISTEMA: Esta opción hará que el sistema se actualice automáticamente justo antes de realizar el backup. Asegúrate que esté activa si tu intención es hacer un backup para proceder a una regeneración inmediatamente después. Desactívala si estás haciendo backups programados. El valor establecido debe ser Si/on o No/off.
  - CARPETAS ADICIONALES: Puedes definir tantas carpetas opcionales como quieras que se incluirán en el backup. Útil si tienes información que quieres transferir al nuevo sistema que vas a regenerar. Si copias carpetas con configuraciones del sistema podrías romperlo. Estas carpetas se devolverán a su ubicación original en la parte final del proceso de regeneración. Se crea un archivo tar comprimido para cada carpeta etiquetado de la misma forma que el resto del backup. Puedes incluir carpetas que estén ubicadas en los discos de datos. Puesto que la restauración de estas carpetas se hace al final del proceso, en ese momento todos los sistemas de archivos ya están montados y funcionando.

## OPCIONES DE OMV-REGEN REGENERA 2.0

  - RUTA BACKUP DE ORIGEN: En el menú debes definir la ubicación de esta carpeta. Por defecto será /ORBackup pero puedes elegir la ubicación que quieras. Esta carpeta debe contener al menos un archivo tar generado con omv-regen. Antes de ejecutar una regeneración el programa comprobará que esta carpeta contiene todos los archivos necesarios para la regeneración. Cuando definas una ruta en el menú omv-regen escaneará los archivos de esa ruta y buscará el backup mas reciente. Una vez localizado el backup, omv-regen comprobará que en su interior están todos los archivos necesarios. Si falta algún archivo la ruta no se dará por válida y no se permitirá continuar adelante.
  - INSTALAR KERNEL PROXMOX: Si el sistema original tenía el kernel proxmox instalado tendrás la opción de decidir si quieres instalarlo también en el sistema nuevo o no. Cuando la regeneración esté en funcionamiento, si esta opción está activada se instalará el kernel a mitad de proceso. En ese momento omv-regen te pedirá que reinicies el sistema. Después de eso debes ejecutar de nuevo omv-regen y la regeneración continuará en el punto en que se detuvo. Ten en cuenta que si tienes un sistema de archivos ZFS o usas kvm es recomendable tener este kernel instalado, en caso contrario podrías tener problemas durante la instalación de estos dos complementos. Si desactivas esta opción el kernel proxmox no se instalará en el sistema nuevo.
  - REGENERAR LA INTERFAZ DE RED: Esta opción sirve para omitir la regeneración de la interfaz de red. Si desactivas esta opción no se regenerará la interfaz de red y la IP seguirá siendo la misma que tiene el sistema después del reinicio al final del proceso. Si activas esta opción se regenerará la interfaz de red al final del proceso de regeneración. Si la IP original es distinta de la IP actual deberás conectarte a la IP original después del reinicio para acceder a OMV. El menú te indica cual será esta IP antes de iniciar la regeneración. Cuando finalice la regeneración también la tendrás en pantalla pero podrías no verla si no estás atento.

Nota: Ver mas abajo un esquema de la configuración de ejecución

AGRADECIMIENTOS: Gracias a Aaron Murray por los consejos en el desarrollo de la versión 1.0 de omv-regen.
_____________________________________________________________________________________________________________________
# omv-regen 2.0

DO YOU NEED TO BACKUP OR RESTORE THE OMV CONFIGURATION? THIS IS THE SOLUTION.


STATE: Stable.

## INSTALLATION:

Copy and paste the following line into a terminal and run it as root or with sudo.

```
sudo wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | sudo bash
```


   - STEP 1. Create a backup of the original system with omv-regen.
   - STEP 2. Do a fresh installation of OMV on the disk you want and connect the data drives.
   - STEP 3. Use omv-regen to clone the configurations from the backup to the new system.


![omv-regen 2 0](https://github.com/xhente/omv-regen/assets/110301854/3fd00cda-543c-4811-8712-5492202fc306)



## CHANGES FROM VERSION 1.0 TO VERSION 2.0

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
  - Selection of plugins according to whether or not they are essential. If there is an update on a non-essential plugin it will be installed and not regenerated, but regeneration will continue.
  - Integrated system to automatically notify or update omv-regen at the user's choice. If a regeneration is in progress it will not be updated until it is finished.
  - Free choice of optional folders that are included in the backup.
  - More generous help content.

## HOW TO USE OMV-REGEN 2.0
omv-regen is used to regenerate the configurations of an openmediavault system in a new OMV installation.

You could say that it is a restoration but saying regeneration is more accurate since a new system is being generated. All software is reinstalled and the original system settings are applied. Going into details, the conditions for this to work are the following: 
   - It is highly recommended to use a different system disk than the original, it does not have to be the same one. 
   - All other disks must be connected at the time of regeneration.
   - OMV and plugin versions must match on both the original and new systems.

As a consequence of the previous point:
   - The original system must be updated when you make the backup, do not wait a day to regenerate.
   - If an important plugin update is released during the process it could stop.
   - If the above case occurs, omv-regen will decide whether or not the installation of that plugin can be skipped.
   - That is the main reason why it is advisable to use a new system disk and keep the original one.

The result will be the following:
   - Everything that is backed up by the OMV database will have been recreated on the new system.
   - This includes docker and containers configured with the compose plugin. They will work as before.
   - Includes all the configurations you have made in the OMV GUI, users and passwords, file systems, etc.
   - DOES NOT include any configuration done in CLI outside of OMV. Use other means to support that.
   - DOES NOT include containers configured in Portainer. You will have to recreate them yourself.
   - Filebrowser and Photoprism plugins are podman containers. They will not support each other, use other means.

## OMV-REGEN 2.0 FEATURES

  1 - `omv-regen` - Provides access to the configuration menus and execution of any omv-regen function. From here you can easily configure the parameters to make a backup or a regeneration and you can execute both. You will also be able to manage omv-regen updates. 

  2 - `omv-regen backup` - Performs a very light backup of essential data to regenerate the configurations of an OMV system. You can include optional folders, even from your data disks, and define the destination. Run omv-regen on the command line and the interface will guide you to configure the parameters and save them. You can then run the backup from the menus or from the CLI with the command: omv-regen backup. You can configure a scheduled task in the OMV GUI that runs the command omv-regen backup and manage it from there. 

  3 - `omv-regen regenera` - Regenerates a complete OMV system with its original configurations from a fresh OMV installation and the backup of the original system made with omv-regen backup. Run omv-regen on the command line and the interface will guide you to configure the parameters and run the regeneration. Then you can run it from the menu or from CLI with the command: omv-regen regenera

  4 - `omv-regen help` - Access to dialogs with full omv-regen help.

## REGENERATION PROCEDURE

  - INSTALL OMV-REGEN ON THE ORIGINAL SYSTEM AND MAKE A BACKUP. Set up a backup in the menu and make sure to check the option to update the system before backup. A very lightweight tar packaged archive will be created that includes all the files and information needed to perform the regeneration. You can optionally include custom folders in the backup. If you do this, a tar file will be created for each folder you select in addition to the previous file. The files in each backup are labeled in name with date and time. Save that backup somewhere. WinSCP is a useful tool for this, you can easily copy that file to your desktop, it is a very small file and moving it is instant. If you configured optional folders, copy the rest of the files as well.
  - DO A NEW INSTALLATION OF OPENMEDIAVAULT, DON'T WAIT. It is not possible to regenerate if the versions of the plugins available on the internet and those installed on the original system are different, this could create conflicts in the database and break the system. There is still a chance that some package will receive a new version before you regenerate. If this happens omv-regen will detect it, at which point it will choose to skip installing that plugin if possible, or, if it is a plugin that cannot be bypassed (like zfs or mergerfs...) it will stop regeneration and you will have to start again. Therefore use a different drive than the original one to install OMV and keep the original one, that way you can always go back and make a new updated backup. Remember that you can install openmediavault on a pendrive. When you have finished installing OMV, do not configure anything. Shut down the system, connect the same data disks that the original system had, and start the server.
  - COPY THE BACKUP TO THE NEW OMV, INSTALL OMV-REGEN AND CONFIGURE THE REGENERATION. Create a folder on the system disk and copy the backup to it. You can use WinSCP or similar to do this over SSH. Install omv-regen on the new system and boot it to configure regeneration in the menu. The menus will guide you to configure the backup location and other options. You can decide not to regenerate the network interface or not to install the proxmox kernel if it was installed on the original server. Once everything is configured, if the settings are valid it will allow you to start the regeneration. Otherwise it will tell you what you should change.
  - REGENERATION BEGINS. All the plugins that you had in the original system will be installed and as they are installed, the database will be regenerated at the same time with your original configurations. If the process needs a restart it will ask you to do it, then you must run omv-regen again and the process will continue from the correct point. omv-regen records the status of the regeneration, so it will continue automatically without doing anything else. If you have a power outage or similar, you can start the server and run omv-regen again. It will continue where it was and the regeneration will end. The duration will depend on the number of plugins and the speed of the server. For an average case it should not last more than 10 or 15 minutes or even less.
  - COMPLETION. When the process is finished, it will notify you on the screen and it will restart automatically. Before starting the regeneration, the menu will tell you what the server's IP will be after the regeneration, you can write it down. In the end it will also appear on the screen but you might not see it if you are not paying attention. Wait for it to reboot and access that IP. Depending on your network configuration this may not be exact, in which case you will have to find out the IP on your router or by connecting to the server with a screen and keyboard. After the reboot you will have the system with a clean installation and the OMV GUI configured exactly as you had the original system.
  - REMEMBER TO CLEAR YOUR BROWSER'S CACHE --> CTRL+SHIFT+R    !!!!

## SOME ADVICES

  - OPTIONAL FOLDERS: If you choose optional folders make sure they are not system folders. Or, if they are, at least make sure they won't harm your system when copied to the OMV disk. It would be a shame to break the system for this once regenerated.
  - FILEBROWSER AND PHOTOPRISM PLUGINS: If you use the Filebrowser or Photoprism plugins you should find alternative means to back them up. They are podman containers and omv-regen will not support them. omv-regen will install them and regenerate the OMV database configurations, this includes the OMV GUI configurations, shared folder, plugin access port, etc. But the internal configurations of the two containers will be lost. It may be enough to include the folder where the container database resides so that omv-regen will restore it as well. This does not guarantee anything, it is just an untested suggestion.
  - OPENMEDIAVAULT-APTTOOL: If you have a package installed manually, for example lm-sensors, and you want it to also be installed at the same time you can use the apttool plugin. omv-regen will install packages that have been installed using this plugin.
  - OPENMEDIAVAULT-SYMLINK: In the same way as in the previous case, if you use symlinks in your system omv-regen will recreate them if they were generated with the plugin. If you did it manually you will have to do it again.
  - TRY TO DO THE REGENERATION AS SOON AS POSSIBLE: omv-regen will skip, if possible, the installation of any plugin if the version available on the Internet to install does not match the version that the original server had installed. This can be done as long as this plugin is not related to the file system, such as mergerfs, zfs or similar, in which case the regeneration will stop and you will not be able to continue. If this happens you will have to make a new backup of the original system, updating it previously. To avoid this, DO NOT delay doing the regeneration once you have made the backup. omv-regen cannot notify you before starting to regenerate because without omv-extras installed there are no repositories in the system to consult versions of most of the plugins.
  - DIFFERENT SYSTEM UNIT: For the same reason explained in the previous point, it is highly recommended to use a different system unit than the original one to regenerate. It is very easy to use a pendrive to install openmediavault. If you are unlucky enough that an update to an essential package is released between the time of the backup and the time of the rebuild, you will not be able to finish it, and you will need the original system to make a new updated backup.
  - DOCKER CONTAINERS: All the information on the original system disk will disappear. To keep your docker containers in the same state make sure you do a few things first. Change the default docker installation path from the /var/lib/docker folder to a folder on one of the data disks. Configure all container volumes off the system disk, on one of the data disks. These are general recommendations, but in this case even more so, if you don't do it you will lose that data. Alternatively you can add the /var/lib/docker folder to the backup as an optional folder.

## OMV-REGEN BACKUP 2.0 OPTIONS

  - BACKUP FOLDER PATH: This folder will be used to store all the backups generated. By default this folder is /ORBackup, you can use whatever you want but do not use the data disks if you intend to do a regeneration, they will not be accessible. To do a regeneration it is better to copy the backup directly to your desktop with WinSCP or similar and then copy it to the new system. In this folder omv-regen will create a tar-packaged archive for each backup, labeled with the date and time in the name. If you have included optional folders in the backup, additional files will be created, also packaged with tar and labeled user1, user2,... Subfolders have the ORB_ prefix in their name. If you want to keep a particular backup version and not have omv-regen delete it, you can edit this prefix to anything else and that subfolder will not be deleted. You can use omv-regen to schedule backups with scheduled tasks in the OMV GUI. The saved settings will be applied. A complete backup with two optional folders done on October 1, 2023 at 10:38 a.m. could look like this:
    - ORB_231001_103828_regen.tar.gz    <-- File with regenera information
    - ORB_231001_103828_user1.tar.gz    <-- File with optional user folder 1
    - ORB_231001_103828_user2.tar.gz    <-- File with optional user folder 2
  - DAYS BACKUPS ARE KEPT: This option establishes the maximum number of days to keep backups. Every time you make a backup, all those existing in the same path that are older than the configured one will be eliminated, by scanning the files of all the files with the ORB_ prefix. A value is established in days. The default value is 7 days.
  - UPDATE SYSTEM: This option will cause the system to update automatically just before performing the backup. Make sure it is active if your intention is to make a backup to proceed with a regeneration immediately afterwards. Disable it if you are doing scheduled backups. The set value must be Yes/on or No/off.
  - ADDITIONAL FOLDERS: You can define as many optional folders as you want that will be included in the backup. Useful if you have information that you want to transfer to the new system that you are going to regenerate. If you copy folders with system settings you could break it. These folders will be returned to their original location in the final part of the regeneration process. A compressed tar file is created for each folder labeled the same as the rest of the backup. You can include folders that are located on the data disks. Since the restoration of these folders is done at the end of the process, at that point all file systems are already mounted and working.

## OMV-REGEN OPTIONS REGENERA 2.0

  - SOURCE BACKUP PATH: In the menu you must define the location of this folder. By default it will be /ORBackup but you can choose the location you want. This folder must contain at least one tar file generated with omv-regen. Before executing a regeneration, the program will check that this folder contains all the files necessary for the regeneration. When you define a path in the menu omv-regen will scan the files in that path and look for the most recent backup. Once the backup is located, omv-regen will check that all the necessary files are inside. If any file is missing, the route will not be considered valid and you will not be allowed to continue further.
  - INSTALL PROXMOX KERNEL: If the original system had the proxmox kernel installed you will have the option to decide if you want to also install it on the new system or not. When regeneration is running, if this option is enabled it will install the kernel mid-process. At that point omv-regen will ask you to reboot the system. After that you have to run omv-regen again and the regeneration will continue from the point where it stopped. Keep in mind that if you have a ZFS file system or use kvm it is recommended to have this kernel installed, otherwise you could have problems installing these two plugins. If you disable this option the proxmox kernel will not be installed on the new system.
  - REGENERATE THE NETWORK INTERFACE: This option is used to skip regenerating the network interface. If you deactivate this option, the network interface will not be regenerated and the IP will remain the same as the system's after the reboot at the end of the process. If you activate this option, the network interface will be regenerated at the end of the regeneration process. If the original IP is different from the current IP you will need to connect to the original IP after the reboot to access OMV. The menu tells you what this IP will be before starting the regeneration. When the regeneration ends you will also have it on the screen but you may not see it if you are not attentive.

ACKNOWLEDGMENTS: Thanks to Aaron Murray for advice in developing version 1.0 of omv-regen.
______________________________________________________________________________________________________________________


![CONFIGURACION OMV-REGEN_2 0_Página_1](https://github.com/xhente/omv-regen/assets/110301854/82def122-6edd-45e9-b7b2-144f184e9845)
![CONFIGURACION OMV-REGEN_2 0_Página_2](https://github.com/xhente/omv-regen/assets/110301854/b5baec28-827e-4b07-adfa-f1fa0efe267a)
![CONFIGURACION OMV-REGEN_2 0_Página_3](https://github.com/xhente/omv-regen/assets/110301854/45fecf09-c8d7-468c-8f20-36a1740e9bd8)
[CONFIGURACION OMV-REGEN_2.0.pdf](https://github.com/xhente/omv-regen/files/12840372/CONFIGURACION.OMV-REGEN_2.0.pdf)
[CONFIGURACION OMV-REGEN_2.0.ods](https://github.com/xhente/omv-regen/files/12840373/CONFIGURACION.OMV-REGEN_2.0.ods)

