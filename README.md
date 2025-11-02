
**ENGLISH VERSION BELOW**


```
   ┌───────────────┐
   │               │     ┌────────────┐     ┌──────────────┐
   │   omv-regen   │ >>> │   backup   │ >>> │   regenera   │
   │               │     └────────────┘     └──────────────┘
   └───────────────┘
```

# 🌀 omv-regen

**Utilidad de Backup y Restauración de la configuración de OpenMediaVault**

## 📥 INSTALACIÓN

Copia y pega la siguiente linea en una terminal y ejecútala como *root* o con *sudo*.

```
wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | sudo bash
```

* **PASO 1.** Crea un backup del sistema original con `omv-regen`
* **PASO 2.** Haz una instalación nueva de OMV o Debian y conecta las unidades de datos originales.
* **PASO 3.** Utiliza `omv-regen` para regenerar las configuraciones del sistema original al nuevo sistema desde el backup.


<img width="818" height="450" alt="omv-regen_7-1_es" src="https://github.com/user-attachments/assets/41580cc0-c466-4eda-9f16-69cdd4639f54" />


## INTRODUCCIÓN

Desde su nacimiento en abril de 2023, *omv-regen* ha sido una herramienta concebida para migrar configuraciones de OpenMediaVault entre sistemas.
Sin embargo, su alcance estaba limitado por la disponibilidad en línea de las versiones de los paquetes.
Hoy, con la llegada de la versión 7.1, esa limitación queda atrás.
Esta versión introduce la capacidad de almacenar y reutilizar los paquetes desde un repositorio local,
haciendo posible una regeneración completa y fiel al sistema original, incluso meses después.

omv-regen deja así de ser una simple utilidad de migración y se convierte en una auténtica **solución de backup y restauración** sin límites de tiempo.
La inestimable ayuda de Aaron Murray y ChatGPT —a quienes expreso mi sincero agradecimiento— ha sido fundamental para alcanzar este hito.

Chente
(Octubre de 2025)

## QUÉ ES OMV-REGEN

* *omv-regen* es una **utilidad desarrollada en bash** que se ejecuta desde línea de comandos (CLI) y dispone de interfaz gráfica mediante *dialog*.
* Permite hacer y programar backups de la configuración de OpenMediaVault (OMV) y usar estos backups para **migrar o regenerar** la configuración en otro sistema limpio de OMV o Debian.

* NOTA: omv-regen **no permite actualizar entre versiones principales de OMV** (por ejemplo, de OMV 6 a OMV 7). Para eso, utiliza siempre el procedimiento oficial: `omv-release-upgrade`. omv-regen solo puede regenerar configuraciones dentro de la **misma versión principal** de OMV.

Comandos principales:

* `omv-regen`          → Abre la interfaz gráfica principal. 
* `omv-regen backup`   → Realiza un backup de la configuración de OMV.
* `omv-regen ayuda`    → Accede a los cuadros de diálogo con la ayuda completa.

## VENTAJAS RESPECTO A UN BACKUP CONVENCIONAL

* Capacidad de recuperar un sistema corrupto si los archivos esenciales están en buen estado y puedes generar un backup.
* El backup es muy ligero, solo ocupa algunos megas de capacidad, lo que permite conservar múltiples versiones con facilidad.
* Permite regenerar un sistema **amd64 en uno ARM** o viceversa, teniendo en cuenta las limitaciones de arquitectura de algunos complementos.
* Una regeneración proporciona un **sistema limpio**, puesto que parte de un sistema limpio. 
* Permite **migrar de hardware** sin limitaciones manteniendo las configuraciones de OpenMediaVault.

## LIMITACIONES DE OMV-REGEN

* Las configuraciones realizadas en CLI no se trasladarán al nuevo sistema, solo se respaldan las configuraciones de la GUI de OMV.
* No se trasladan las configuraciones internas de los complementos basados en *podman*, como Filebrowser o Photoprism — respáldalos por otros medios.
* *omv-regen* **no es un sistema de backup de datos**. Su objetivo es preservar la **configuración del sistema**, no el contenido de los discos de datos.

## CÓMO HACER BACKUPS CON OMV-REGEN

* Conéctate por SSH a tu servidor o con un monitor y teclado, instala y ejecuta `omv-regen`
* Configura la carpeta de almacenamiento de backups; por defecto es `/ORBackup`
* Por defecto, se programa un backup diario a las 03:00 h. Puedes modificarlo en la GUI de OMV, en Tareas Programadas.
* También puedes ejecutar un backup manual desde la GUI de *omv-regen*.
* Puedes añadir carpetas adicionales al backup, configúralo en la GUI de *omv-regen*.
* Utiliza las carpetas adicionales para conservar carpetas existentes fuera del entorno de OMV.
* Desactiva el *modo silencio* para notificaciones detalladas.
* Siempre recibirás una notificación si se produce un error.
* Cada backup está formado por varios archivos etiquetados con la fecha y hora de su creación y contiene:
   * Un archivo `.regen.tar`  con los elementos necesarios para la regeneración.
   * Un archivo `.sha56`      para verificar la integridad del backup.
   * Un archivo `.user#.tar`  por cada carpeta de usuario incluida en el backup.

## CÓMO REGENERAR UN SISTEMA

* Conéctate por SSH o con un monitor y teclado, instala y ejecuta `omv-regen`
* Haz un backup del sistema actual y cópialo fuera del servidor (por ejemplo, con WinSCP o a un pendrive).
* Para regenerar, necesitas una instalación limpia de OMV. Dos opciones:
   * Usar la ISO de OMV: instala OMV sin actualizar el sistema; *omv-regen* actualizará a la versión correcta del backup.
   * Instalar Debian mínimo (64 bits) y dejar que *omv-regen* instale OMV en la versión del backup.
* Se recomienda usar un disco nuevo para la instalación y conservar el original como copia de seguridad.
* Copia el backup a una carpeta del servidor.
* Configura la ruta del backup e inicia la regeneración.
   * Si quieres omitir la instalación de algún complemento selecciónalo en la GUI de *omv-regen regenera* antes de iniciar.
* El sistema se reiniciará automáticamente, puedes ejecutar `omv-regen` en cualquier momento para ver el log en vivo.
* Al finalizar, recibirás un correo con el resultado y podrás comprobar en la GUI de OMV que todo se ha restaurado correctamente.

## INSTALACIÓN Y REGENERACIÓN DESDE LA ISO DE OPENMEDIAVAULT

* Instala OpenMediaVault con la ISO correspondiente a la versión (6.0/7.0) que necesites.
* No actualices el sistema, deja que lo haga *omv-regen* para adecuar las versiones a las del sistema original.
* Instala *omv-regen*:
  ```
  wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | bash
  ```
* Copia el backup al servidor, inicia `omv-regen` y ejecuta la regeneración.

## INSTALACIÓN Y REGENERACIÓN DESDE DEBIAN

* Si tu hardware es ARM o no puedes instalar desde la ISO, usa este procedimiento.
* Instala la versión de **Debian Lite de 64 bits** (sin entorno gráfico) que necesites:
   * Para OMV6 → Debian 11 (Bullseye)
   * Para OMV7 → Debian 12 (Bookworm)
* Durante la instalación, selecciona únicamente el paquete SSH para instalar.
* Una vez finalizada la instalación, inicia sesión con tu usuario y activa *root*:
  ```
  sudo -i
  passwd root   # Establece una contraseña segura para root
  ```
* Activa el acceso SSH para el usuario *root*:
  ```
  nano /etc/ssh/sshd_config
  ```
* Busca y modifica las siguientes líneas:
  ```
  PermitRootLogin yes
  PasswordAuthentication yes
  ```
* Guarda los cambios y reinicia el servicio:
  ```
  systemctl restart ssh
  ```
* Ahora puedes conectarte al servidor desde otro equipo con *root*, por ejemplo con *PuTTY* o *WinSCP*.
* Instala *wget* y *omv-regen*:
  ```
  apt-get update
  apt-get upgrade -y 
  apt-get install wget -y
  wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | bash
  ```
* Copia el backup al servidor (*WinSCP*), inicia `omv-regen` y ejecuta la regeneración. *omv-regen* instalará OMV y continuará la regeneración.

## ALGUNOS CONSEJOS Y NOVEDADES PRÁCTICAS

* **SISTEMA DE BACKUPS:**
   * Los backups ahora se gestionan mediante un sistema de retenciones automáticas: semanal, mensual y anual.
   * Podrás mantener copias históricas sin llenar el disco; las más antiguas se eliminarán de forma segura según tus ajustes.

* **HOOK AUTOMÁTICO:**
   * *omv-regen* instala un hook que garantiza que todos los paquetes necesarios se descarguen junto al backup.
   * Una primera actualización del sistema tras instalar *omv-regen* asegurará que todos los paquetes estén disponibles a partir de ese momento.

* **PROGRAMACIÓN AUTOMÁTICA:**
   * *omv-regen* crea por defecto una tarea diaria de backup, que puedes modificar desde la GUI de OMV.
   * Además, se ejecuta una limpieza semanal automática del hook para mantener el sistema ordenado.

* **CARPETAS OPCIONALES:**
   * Evita incluir carpetas de sistema en los backups opcionales.
   * Asegúrate de que no contengan archivos críticos que puedan afectar al nuevo sistema.

* **COMPLEMENTOS BASADOS EN CONTENEDORES:**
   * *omv-regen* solo respalda las configuraciones visibles en la GUI de OMV.
   * Complementos basados en *podman* como *Filebrowser* o *Photoprism* deben respaldarse manualmente.

* **OPENMEDIAVAULT-APTTOOL:**
   * Si utilizas el complemento *apttool*, los paquetes instalados mediante él se instalarán automáticamente durante la regeneración.

* **SYMLINKS Y CONFIGURACIONES MANUALES:**
   * Los enlaces creados con *omv-symlinks* se regenerarán automáticamente.
   * Los creados manualmente desde CLI deberán volver a configurarse.

* **DOCKER:**
   * Guarda los datos y volúmenes de *Docker* fuera del disco de sistema,
   * preferiblemente en un disco de datos, para evitar pérdidas durante la regeneración.
   * Después de la regeneración levanta los contenedores en la GUI de OMV.

* **DISCOS ENCRIPTADOS:**
   * Si utilizas *omv-luksencryption*, asegúrate de tener configurado `/etc/crypttab` y las claves de descifrado accesibles.
   * *omv-regen* las transferirá al nuevo sistema y gestionará los reinicios necesarios.

* **UNIDAD DE SISTEMA:**
   * Instala el nuevo sistema en una unidad diferente a la original.
   * Así podrás conservar el disco anterior como copia de seguridad ante cualquier imprevisto.

## FUNCIONAMIENTO INTERNO

* **Durante la instalación:**

   * Si el sistema es *Debian* y aún no tiene instalado OMV, se instalará *dialog* previamente.
   * Se configura un hook para capturar en vivo los paquetes instalados por el sistema.
   * Se configura en cron un trabajo de limpieza semanal del hook que actualiza el repositorio local, si no se ha hecho ya durante la semana.
   * Se configura el log de *omv-regen*.
   * Se crea la carpeta `/var/lib/omv-regen` con los archivos de configuración y el repositorio local.
   * Se configura un trabajo programado diario de backup, configurable desde la GUI de OMV.
   * Si el sistema tiene el idioma español, `omv-regen` se ajusta el idioma a español. 

* **Durante la ejecución de un backup:**

   * Aunque no es necesario, puedes activar la actualización automática de OMV.
   * Se actualiza el repositorio local con los paquetes necesarios capturados en el hook y se añaden al backup.
   * Se eliminan los backups obsoletos según las retenciones configuradas. 

* **Durante la regeneración:**

   * Se permite omitir la instalación de complementos no esenciales.
   * Se configura un servicio para reanudar la regeneración automáticamente tras cada reinicio.
      * Puedes ejecutar `omv-regen` en cualquier momento para ver el log en vivo.
   * Se desinstala *apparmor* si está presente.
   * Si OMV no está instalado, *omv-regen* instala OMV utilizando el script de instalación de OMV de Aaron Murray.
      * Esta instalación añade *omv-extras* al sistema, incluso si no estaba en el sistema original.
   * Se instalan las versiones del sistema original de OMV y complementos y se retienen hasta finalizar.
   * Se sustituyen partes de la base de datos siguiendo un orden lógico y ejecutando comandos de *SaltStack* para aplicar configuraciones.
   * Al finalizar, se liberan las retenciones y se actualiza el sistema a la última versión de cada paquete.

* **Características especiales:**

   * *omv-regen* impide la ejecución de dos instancias simultáneas, excepto durante la regeneración para poder ver el log en vivo.

## NOTAS Y RECOMENDACIONES

* **Requisitos mínimos:** Sistema Debian u OMV de 64 bits y conexión a Internet estable.
   * Se recomienda ejecutar `omv-regen` como *root*.

* **Logs y seguimiento:**
   * Los registros de ejecución se guardan en `/var/log/omv-regen.log`
   * Si la regeneración se interrumpe, puedes reanudarla ejecutando de nuevo `omv-regen`

* **Compatibilidad de versiones:**
   * `omv-regen regenera` requiere que la versión de OMV sea igual o inferior a la del sistema original.
      * No actualices OMV, deja que lo haga *omv-regen*, o deja que *omv-regen* instale OMV desde Debian.
      * Una vez completado el proceso, *omv-regen* actualizará el sistema con seguridad.

* **Copias de seguridad:**
   * Guarda siempre una copia del backup fuera del servidor antes de iniciar la regeneración.
   * No borres el backup original hasta confirmar que el nuevo sistema funciona correctamente.

* **Seguridad:**
   * *omv-regen* no realiza modificaciones en los discos de datos; solo en el sistema.
   * Verifica que todos los discos originales estén conectados antes de iniciar la regeneración.
   * Recuperación manual: Si una regeneración se detiene con algún problema de instalación.
      * Limpia la regeneración actual desde la GUI de *omv-regen* para desbloquear las versiones de paquetes.
      * A partir de ese momento el sistema queda en tus manos.

* **Consideraciones para sistemas con tarjeta SD (Raspberry Pi y similares)**
   * Durante la regeneración del sistema, omv-regen realiza **operaciones intensivas de lectura y escritura**.
   * En dispositivos que utilizan almacenamiento flash (como tarjetas SD o eMMC), este proceso puede provocar un **desgaste significativo** y acortar la vida útil del medio.
   * Sistemas con 2 GB de RAM pueden experimentar inestabilidad, especialmente al aplicar múltiples cambios de configuración o reiniciar servicios, ya que el uso de swap aumenta el riesgo de fallos y de desgaste adicional de la tarjeta SD.
   * Recomendaciones:
      * Realiza la regeneración sobre un SSD conectado por USB siempre que sea posible.
      * Si usas una SD, utiliza una de alta calidad y evita regeneraciones repetidas en la misma tarjeta.
      * Considera usar modelos con 4 GB de RAM o más para una mayor estabilidad.

* **Soporte:**
   * Para dudas o incidencias, consulta el foro oficial de OpenMediaVault.
   * Recuerda incluir los últimos registros del log para obtener ayuda más rápida.

* **Nota final:**
   * *omv-regen* ha sido diseñado para ofrecer una restauración fiable y automatizada.
   * No obstante, úsalo bajo tu responsabilidad y revisa siempre los mensajes antes de confirmar cada paso.


Espero que omv-regen te haya resultado útil, si quieres puedes invitarme a un café. ¡Muchas gracias!

[<img alt="buy me  a coffee" width="200px" src="https://cdn.buymeacoffee.com/buttons/v2/default-blue.png" />](https://www.buymeacoffee.com/xhente)

_____________________________________________________________________________________________________________________


```
   ┌───────────────┐
   │               │     ┌────────────┐     ┌──────────────┐
   │   omv-regen   │ >>> │   backup   │ >>> │   regenera   │
   │               │     └────────────┘     └──────────────┘
   └───────────────┘
```

# 🌀 omv-regen

**Backup and Restoration Utility for OpenMediaVault Configuration**

## 📥 INSTALLATION

Copy and paste the following line into a terminal and run it as root or with sudo:

```
wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | sudo bash
```

* **STEP 1.** Create a backup of the original system using `omv-regen`.
* **STEP 2.** Perform a fresh installation of OMV or Debian and connect the original data drives.
* **STEP 3.** Use `omv-regen` to regenerate the configuration of the original system on the new one from the backup.


<img width="818" height="450" alt="omv-regen_7-1_en" src="https://github.com/user-attachments/assets/3b867457-4731-4d98-adfc-a8b6f28c3879" />


## INTRODUCTION

Since its creation in April 2023, *omv-regen* has been a tool designed to migrate OpenMediaVault configurations between systems.
However, its scope was limited by the online availability of package versions.
Today, with the arrival of version 7.1, that limitation is gone.
This version introduces the ability to store and reuse packages from a local repository,
making it possible to fully and faithfully regenerate a system — even months later.

Thus, *omv-regen* is no longer just a migration utility but a true **backup and restoration solution** without time limits.
The invaluable help of Aaron Murray and ChatGPT —to whom I extend my deepest gratitude— has been essential in achieving this milestone.

Chente
(October 2025)

## WHAT IS OMV-REGEN

* *omv-regen* is a **bash-based utility** that runs from the command line (CLI) and provides a graphical interface through *dialog*.
* It allows you to create and schedule backups of your OpenMediaVault (OMV) configuration and use those backups to **migrate or regenerate** the configuration on a clean OMV or Debian system.

* NOTE: omv-regen does **not support upgrading between major OMV versions** (e.g., from OMV 6 to OMV 7). For this, always use the official `omv-release-upgrade` procedure. omv-regen can only regenerate configurations within **the same major OMV version**.

Main commands:

* `omv-regen`          → Opens the main graphical interface.
* `omv-regen backup`   → Creates a backup of the OMV configuration.
* `omv-regen ayuda`    → Opens the help dialogs with full documentation.

## ADVANTAGES OVER A CONVENTIONAL BACKUP

* Can recover a corrupted system as long as essential files are intact and a backup can be created.
* The backup is lightweight, usually only a few megabytes, allowing you to keep multiple versions easily.
* Can regenerate a system from **amd64 to ARM** or vice versa, taking into account plugin architecture limitations.
* A regeneration produces a **clean system**, since it starts from a clean installation.
* Allows **hardware migration** without limitations while preserving all OpenMediaVault configurations.

## LIMITATIONS OF OMV-REGEN

* Custom configurations made from the CLI will not be transferred; only settings made through the OMV GUI are included.
* Internal configurations of *podman*-based plugins (such as Filebrowser or Photoprism) are not included — back them up separately.
* *omv-regen* is **not a data backup system**. Its purpose is to preserve **system configuration**, not data content.

## HOW TO MAKE BACKUPS WITH OMV-REGEN

* Connect via SSH to your server or use a monitor and keyboard, then install and run `omv-regen`.
* Configure the backup storage folder; the default is `/ORBackup`.
* By default, a daily backup is scheduled at 03:00 AM. You can modify this in the OMV GUI under *Scheduled Tasks*.
* You can also manually execute a backup from the *omv-regen* GUI.
* You can add additional folders to the backup; configure them in the *omv-regen* GUI.
* Use additional folders to keep existing folders outside the OMV environment.
* Turn off *silent mode* for detailed notifications.
* You will always receive a notification if an error occurs.
* Each backup consists of several files labeled with the creation date and time and contains:
   * A `.regen.tar`  file with the elements needed for regeneration.
   * A `.sha56`      file to verify backup integrity.
   * A `.user#.tar`  file for each user folder included in the backup.

## HOW TO REGENERATE A SYSTEM

* Connect via SSH or use a monitor and keyboard, install and run `omv-regen`.
* Create a backup of the current system and copy it outside the server (e.g., using WinSCP or to a USB drive).
* To regenerate, you need a clean installation of OMV. Two options:
   * Use the OMV ISO: install OMV without updating the system; *omv-regen* will adjust to the correct backup version.
   * Install minimal Debian (64-bit) and let *omv-regen* install OMV in the version from the backup.
* It is recommended to use a new disk for installation and keep the original as a safety copy.
* Copy the backup to a folder on the server.
* Configure the backup path and start regeneration.
   * If you want to skip installing certain plugins, select them in the *omv-regen regenera* GUI before starting.
* The system will reboot automatically. You can run `omv-regen` at any time to view the live log.
* When finished, you will receive an email with the results and can verify in the OMV GUI that everything has been restored correctly.

## INSTALLATION AND REGENERATION FROM THE OPENMEDIAVAULT ISO

* Install OpenMediaVault with the ISO corresponding to the version (6.0/7.0) you need.
* Do not update the system; let *omv-regen* handle it to match the original versions.
* Install *omv-regen*:
  ```
  wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | bash
  ```
* Copy the backup to the server, start `omv-regen`, and run regeneration.

## INSTALLATION AND REGENERATION FROM DEBIAN

* If your hardware is ARM or you cannot install from the ISO, use this procedure.
* Install the **minimal 64-bit Debian Lite** version you need:
   * For OMV6 → Debian 11 (Bullseye)
   * For OMV7 → Debian 12 (Bookworm)
* During installation, select only the SSH package to install.
* Once installation is complete, log in with your user and enable *root*:
  ```
  sudo -i
  passwd root   # Set a secure password for root
  ```
* Enable SSH access for the *root* user:
  ```
  nano /etc/ssh/sshd_config
  ```
* Find and modify the following lines:
  ```
  PermitRootLogin yes
  PasswordAuthentication yes
  ```
* Save changes and restart the service:
  ```
  systemctl restart ssh
  ```
* You can now connect to the server from another machine as root, using *PuTTY* or *WinSCP*.
* Install *wget* and *omv-regen*:
  ```
  apt-get update
  apt-get upgrade -y
  apt-get install wget -y
  wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | bash
  ```
* Copy the backup to the server (*WinSCP*), start `omv-regen`, and run regeneration. *omv-regen* will install OMV and continue regeneration.

## SOME PRACTICAL TIPS AND NEW FEATURES

* **BACKUP SYSTEM:**
   * Backups are now managed through an automatic retention system: weekly, monthly, and yearly.
   * You can keep historical copies without filling your disk; older ones are safely deleted according to your settings.

* **AUTOMATIC HOOK:**
   * *omv-regen* installs a hook that ensures all required packages are downloaded together with the backup.
   * An initial system update after installing *omv-regen* guarantees that all packages are available from that point on.

* **AUTOMATIC SCHEDULING:**
   * *omv-regen* creates a default daily backup task, which can be modified from the OMV GUI.
   * A weekly automatic cleanup of the hook is also scheduled to keep the system tidy.

* **OPTIONAL FOLDERS:**
   * Avoid including system folders in optional backups.
   * Ensure they do not contain critical files that might affect the new system.

* **CONTAINER-BASED PLUGINS:**
   * *omv-regen* only backs up configurations visible in the OMV GUI.
   * *Podman*-based plugins such as *Filebrowser* or *Photoprism* should be backed up manually.

* **OPENMEDIAVAULT-APTTOOL:**
   * If you use the *apttool* plugin, packages installed through it
   * will be automatically installed during regeneration.

* **SYMLINKS AND MANUAL CONFIGURATIONS:**
   * Links created with *omv-symlinks* will be automatically regenerated.
   * Links created manually from the CLI will need to be reconfigured.

* **DOCKER:**
   * Store *Docker* data and volumes outside the system drive,
   * preferably on a data disk, to prevent loss during regeneration.
   * After regeneration, bring the containers back up through the OMV GUI.

* **ENCRYPTED DRIVES:**
   * If you use *omv-luksencryption*, make sure `/etc/crypttab` and decryption keys are accessible.
   * *omv-regen* will transfer them to the new system and handle necessary reboots.

* **SYSTEM DRIVE:**
   * Install the new system on a different drive than the original.
   * This way, you can keep the old drive as a backup in case of issues.

## INTERNAL OPERATION

* **During installation:**

   * If the system is Debian and OMV is not yet installed, *dialog* will be installed first.
   * A hook is set up to capture installed packages in real-time.
   * A weekly cron job is configured to clean the hook that updates the local repository, if not already done that week.
   * The *omv-regen* log is configured.
   * The `/var/lib/omv-regen` folder is created with configuration files and the local repository.
   * A daily scheduled backup task is configured, editable from the OMV GUI.
   * If the system language is Spanish, *omv-regen* automatically adjusts to Spanish.

* **During backup execution:**

   * Although not required, you can enable automatic OMV updates.
   * The local repository is updated with the necessary packages captured in the hook and added to the backup.
   * Obsolete backups are deleted according to retention settings.

* **During regeneration:**

   * You can skip installing non-essential plugins.
   * A service is configured to automatically resume regeneration after each reboot.
      * You can run `omv-regen` at any time to view the live log.
   * *AppArmor* will be uninstalled if present.
   * If OMV is not installed, it is installed using Aaron Murray’s OMV installation script.
      * This installation includes *omv-extras* even if it was not part of the original system.
   * The original versions of OMV and plugins are installed and held until completion.
   * Parts of the database are replaced in logical order, executing SaltStack commands to apply configurations.
   * At the end, holds are released and the system is safely updated to the latest package versions.

* **Special features:**

   * *omv-regen* prevents multiple instances from running simultaneously, except during regeneration to allow viewing the live log.

## NOTES AND RECOMMENDATIONS

* **Minimum requirements:** Debian or OMV 64-bit system and stable Internet connection.
   * It is recommended to run `omv-regen` as *root*.

* **Logs and monitoring:**
   * Execution logs are saved in `/var/log/omv-regen.log`.
   * If regeneration is interrupted, you can resume it by running `omv-regen` again.

* **Version compatibility:**
   * *omv-regen regenera* requires the OMV version to be equal to or lower than the original system’s version.
   * Do not update OMV; let *omv-regen* do it, or let it install OMV from Debian.
   * Once the process is complete, *omv-regen* will safely update the system.

* **Backups:**
   * Always store a copy of the backup outside the server before starting regeneration.
   * Do not delete the original backup until confirming the new system works properly.

* **Security:**
   * *omv-regen* does not modify data disks; it only affects the system.
   * Verify that all original disks are connected before starting regeneration.

* **Manual recovery:** If regeneration stops due to installation issues:
   * Clean the current regeneration from the *omv-regen* GUI to unlock package versions.
   * From that point, the system is in your hands.

* **Considerations for systems using SD cards (Raspberry Pi and similar devices)**
   * During the system regeneration process, omv-regen performs **intensive read and write operations**.
   * On devices that use flash storage (such as SD or eMMC cards), this process can cause **significant wear** and shorten the lifespan of the storage medium.
   * Systems with 2GB of RAM may experience instability, especially when applying multiple configuration changes or restarting services, as using swap increases the risk of failure and additional wear on the SD card.
   * Recommendations:
      * Whenever possible, perform the regeneration on a USB-connected SSD.
      * If you use an SD card, choose a high-quality one and avoid running multiple regenerations on the same card.
      * Consider using models with 4GB of RAM or more for greater stability.

* **Support:**
   * For questions or issues, visit the official OpenMediaVault forum.
   * Include the latest log entries to get faster help.

* **Final note:**
   * *omv-regen* is designed to provide reliable and automated restoration.
   * However, use it responsibly and always review the messages before confirming each step.


I hope that omv-regen has been useful to you, if you want you can buy me a coffee. Thank you so much!

[<img alt="buy me  a coffee" width="200px" src="https://cdn.buymeacoffee.com/buttons/v2/default-blue.png" />](https://www.buymeacoffee.com/xhente)
