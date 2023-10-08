(English version below)

# omv-regen 2.0

¿NECESITAS HACER UN RESPALDO O RESTAURAR LA CONFIGURACIÓN DE OMV? ESTA ES LA SOLUCIÓN.

ESTADO: Estable.

## INSTALACIÓN

Copia y pega la siguiente linea en una terminal y ejecútala.

```
wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | bash
```

   - PASO 1. Crea un backup del sistema original con omv-regen.
   - PASO 2. Haz una instalación nueva de OMV en el disco que quieras y conecta las unidades de datos.
   - PASO 3. Utiliza omv-regen para clonar las configuraciones desde el backup en el nuevo sistema. 

## CAMBIOS RESPECTO DE LA VERSION 1.0

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
  - Selección de complementos según sean o no esenciales. Si hay una actualización en un complemento no esencial se instalará y no se regenerará, pero la regeneración terminará.
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
   - Si se da el caso anterior omv-regen decidirá si se puede omitir o no la instalación de ese complemento. 
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

  2 - `omv-regen backup` - Realiza un backup muy ligero de los datos esenciales para regenerar las configuraciones de un sistema OMV. Puedes incluir carpetas opcionales, incluso de tus discos de datos, y definir el destino. Ejecuta `omv-regen` en línea de comando y la interfaz te guiará para configurar los parámetros y guardarlos. Después puedes ejecutar el backup desde los menús o desde CLI con el comando: `omv-regen backup` Puedes configurar una tarea programada en la GUI de OMV que ejecute el comando `omv-regen backup` y gestionarlo desde allí. 

  3 - `omv-regen regenera` - Regenera un sistema completo OMV con sus configuraciones originales a partir de una instalación nueva de OMV y el backup del sistema original realizado con omv-regen backup. Ejecuta `omv-regen` en línea de comando y la interfaz te guiará para configurar los parámetros y ejecutar la regeneración. Después puedes ejecutarla desde el menú o desde CLI con el comando: `omv-regen regenera` 

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
# omv-regen

DO YOU NEED TO BACKUP OR RESTORE THE OMV CONFIGURATION? THIS IS THE SOLUTION.


STATE: Stable.

## INSTALLATION:

Copy and paste the following line in a terminal and run it.

```
wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | bash
```

## PROGRAM FUNCTIONS:

1 - `omv-regen backup` - Makes a backup of essential data to regenerate the configurations of an OMV system.

2 - `omv-regen regenera` - Regenerates a complete OMV system with its original configurations from a fresh installation of OMV and the previous backup.

## PROCEDURE:
- Install omv-regen on the original system and make a backup with omv-regen backup.
- Do a clean install of OMV, don't configure anything. You can use another disk. Remember to connect the data disks.
- Mount a flash drive with the backup or copy it directly to a root folder.
- Install omv-regen on the new system and run omv-regen regenera.
- When the process is finished you will have the system with a clean installation and configured as the original.

## BACKUP FEATURES:
- Stores the system database and some configuration files needed for regeneration. It takes up very little space and is done in a matter of seconds.
- Backups are kept for 7 days by default. This is configurable.
- To run the script you can schedule a backup in the OMV GUI in scheduled tasks simply by typing the appropriate command for your case.
- By default, the folders /home and /etc/libvirt (if it exists) are copied.
- You can add custom folders to the backup.
- If you want to keep a backup version permanently edit the ORB_ prefix of the subfolder. That version will not be removed.
- Run omv-regen help to see the available help.
- If you do not specify any directory, the backup will be made in /ORBackup

## REGENERATE FEATURES:
- Regenerate a complete system from scratch as if you did it in the GUI manually, following the order set in the original system.
- A different drive can be used to do the new OMV installation. In fact, it is advisable to do so to be able to return to the original system in case of need.
- The proxmox kernel will be installed if it existed on the original system.
- Optionally you can skip the proxmox kernel installation.
- Optionally you can activate automatic reboot after installing the kernel and the regeneration will continue in the background.
- All your disks and file systems that existed in the original OMV compatible system will be automatically recognized and mounted.
- All the configurations established in the OMV GUI will be regenerated and it will configure them in the system automatically.
- Custom environment variables in OMV from CLI will be retrieved from the backup and regenerated on the current system.
- The backup must be updated. Ideally make the backup and immediately after make the regeneration. Supported package versions must match those available for download.
- omv-extras and docker will be installed if they existed on the original system.
- All plugins that existed in the original system will be installed and regenerated. In podman based plugins the GUI settings will be regenerated. The configurations of the container itself, just like docker containers, must be backed up by other means.
- If you want to avoid the installation and regeneration of a plugin that you had installed, you can edit the ORB_DpkgOMV file and delete the corresponding line. The plugin will not install.
- All manual configurations done in CLI and manually installed packages will be skipped during regeneration. Use openmediavault-apttool and openmediavault-symlinks on the original system if you need them to preserve certain special settings, then make the backup.
- The last step of the regeneration is the network configuration and the system will reboot. After that you will lose the connection if your IP is different. On the screen you will have the new IP. If you want to avoid losing the connection, set the same IP of the original system before launching the regeneration. In this step, a message will be displayed on the screen for 10 seconds that allows you to skip the regeneration of the network interface by pressing any key.

ACKNOWLEDGMENTS: Thanks to Aaron Murray for advice on the development of this script.
______________________________________________________________________________________________________________________

![CONFIGURACION OMV-REGEN_Página_1](https://github.com/xhente/omv-regen/assets/110301854/8c22cdb1-3db2-43e8-ab68-2a81e44af6fe)

![CONFIGURACION OMV-REGEN_Página_2](https://github.com/xhente/omv-regen/assets/110301854/086908c1-24f1-42bb-9017-3b7b1d2daca1)

![CONFIGURACION OMV-REGEN_Página_3](https://github.com/xhente/omv-regen/assets/110301854/4a70d777-3af5-44e5-ba65-d4b110b72280)

[CONFIGURACION OMV-REGEN.pdf](https://github.com/xhente/omv-regen/files/11675149/CONFIGURACION.OMV-REGEN.pdf)

[CONFIGURACION OMV-REGEN.ods](https://github.com/xhente/omv-regen/files/11675172/CONFIGURACION.OMV-REGEN.ods)



```
_______________________________________________________________________________

              HELP FOR USING OMV-REGEN    (BACKUP AND REGENERA)

  - omv-regen   regenerates an OMV system from a clean install by restoring the
    existing configurations to the original system.
  - Install omv-regen on the original system, update and make a backup. Install
    OMV on an empty disk without configuring anything.  Mount a backup, install
    omv-regen and then regenerate. The version available on the internet of the
    plugins and OMV must match.
  - Use omv-regen             to enable omv-regen on your system.
  - Use omv-regen backup      to store the necessary information to regenerate.
  - Use omv-regen regenera    to run a system regeneration from a clean OMV.
_______________________________________________________________________________

   omv-regen       -->       Install and enable the command on the system.
_______________________________________________________________________________

   omv-regen backup   [OPTIONS]   [/folder_one "/folder two" /folder ... ]


    -b     Set the path to store the subfolders with [-b]ackups.

    -d     Sets the [-d]ays of age of the saved backups (default 7 days).
                          You can edit the ORB_ prefix to keep a version.
    -h     Help.

    -o     Enable [-o]ptional folder backup. (by default /home /etc/libvirt)
                          Spaces to separate (can use quotes).
    -u     Enable automatic system [-u]pdate before backup.
_______________________________________________________________________________

   omv-regen regenera   [OPTIONS]   [/backup_folder]


    -b     Sets path where the [-b]ackup created by omv-regen is stored.

    -h     Help

    -k     Skip installing the proxmox [-k]ernel.

    -n     Skip [-n]etwork interface regeneration. 

    -r     Enable automatic [-r]eboot if needed (create reboot service).
_______________________________________________________________________________
```
