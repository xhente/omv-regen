# omv-regen

Estado: Inacabado

Funciones del programa:

1 - omv-regen backup - Realiza un backup de datos esenciales para regenerar las configuraciones de un sistema OMV. Almacena la base datos,
versiones de paquetes instalados, información de usuarios, y estado general del sistema en muy poco espacio.

2 - omv-regen regenera - Regenera un sistema completo OMV con sus configuraciones originales a partir de una instalación nueva de OMV y el backup anterior.

Características:

- Se puede utilizar una unidad de disco diferente para hacer la nueva instalación de OMV.

- Admite kernel proxmox y todos los sistemas de archivos soportados por OMV.

- El backup debe estar actualizado. Las versiones de paquetes instalados deben coincidir en el sistema original y el sistema
nuevo que se va a regenerar. Si una versión de un paquete ya no está disponible para su descarga no se podrá regenerar.

Instalación: 

Copia y pega la siguiente linea en una terminal y ejecútala.

wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | bash

Agradecimientos:

Gracias a Aaron Murray (Ryecoaaron). Sin tu apoyo esto no sería posible.

_____________________________________________________________________________________________________________________

Status: Unfinished

Program features:

1 - omv-regen backup - Make a backup of essential data to regenerate the configurations of an OMV system. It stores the database, installed
package versions, user information, and general system status in very little space.

2 - omv-regen regenera - Regenerates a complete OMV system with its original configurations from a new installation of OMV and the previous backup.

Characteristics:

- A different drive can be used to do the new OMV installation.

- Supports proxmox kernel and all OMV supported file systems.

- The backup must be updated. The versions of installed packages must match on the original system and the
new that is going to regenerate. If a version of a package is no longer available for download, it cannot be regenerated.

Install: 

Copy and paste the following line into a terminal and run it.

wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh | bash

Thanks:

Thanks to Aaron Murray (Ryecoaaron). Without your support this would not be possible.

