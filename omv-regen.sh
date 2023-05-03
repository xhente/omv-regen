#!/bin/bash
# -*- ENCODING: UTF-8 -*-

# This file is licensed under the terms of the GNU General Public
# License version 3. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

Back=""
Rege=""
Ruta=""
OpDias=7
OpFold=""
OpUpda=""
OpKern=1
OpRebo=""
declare -A ORB
ORB[Dpkg]='/ORB_Dpkg'
ORB[DpkgOMV]='/ORB_DpkgOMV'
ORB[Unamea]='/ORB_Unamea'
ORB[Zpoollist]='/ORB_Zpoollist'
ORB[Systemctl]='/ORB_Systemctl'
ORB[HostnameI]='/ORB_HostnameI'
Config="/etc/openmediavault/config.xml"
Passwd="/etc/passwd"
Shadow="/etc/shadow"
Group="/etc/group"
Subuid="/etc/subuid"
Subgid="/etc/subgid"
Passdb="/var/lib/samba/private/passdb.tdb"
declare -a Archivos=("$Config" "$Passwd" "$Shadow" "$Group" "$Subuid" "$Subgid" "$Passdb")
declare -a Directorios=("/home" "/etc/libvirt")
ConfTmp="/etc/openmediavault/config.rg"
Fecha=$(date +%y%m%d_%H%M)
cont=0
declare -a ListaInstalar
KernelOR=""
KernelIN=""
Inst="/usr/sbin/omv-regen"
Sysreboot="/etc/systemd/system/omv-regen-reboot.service"
ORBackup="/ORBackup"
URL="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master"
Sucio="/var/lib/openmediavault/dirtymodules.json"
IpOR=""
IpAC=""
Comando=""
Habilit=""
. /etc/default/openmediavault

[ "$(cut -b 7,8 /etc/default/locale)" = es ] && Sp=1

# NODOS DE LA BASE DE DATOS
# La primera variables esla ruta del nodo. (nulo -> no hay nodo en la base de datos)
# Las siguientes variables son los módulos a actualizar con salt

# Interfaz GUI
declare -A Config
Config[webadmin]="/config/webadmin monit nginx"
Config[time]="/config/system/time chrony cron timezone"
Config[email]="/config/system/email cronapt mdadm monit postfix smartmontools"
Config[notification]="/config/system/notification cronapt mdadm monit smartmontools"
Config[powermanagement]="/config/system/powermanagement cpufrequtils cron systemd-logind"
Config[monitoring]="/config/system/monitoring collectd monit rrdcached"
Config[crontab]="/config/system/crontab cron"
Config[certificates]="/config/system/certificates certificates"
Config[apt]="/config/system/apt"
Config[dns]="/config/system/network/dns avahi hostname hosts postfix systemd-networkd"
Config[interfaces]="/config/system/network/interfaces avahi halt hosts issue systemd-networkd"
Config[proxy]="/config/system/network/proxy apt profile"
Config[iptables]="/config/system/network/iptables iptables"
Config[hdparm]="/config/system/storage/hdparm hdparm"
Config[smart]="/config/services/smart smartmontools"
Config[fstab]="/config/system/fstab initramfs mdadm collectd fstab monit quota"
Config[shares]="/config/system/shares systemd"
Config[nfs]="/config/services/nfs avahi collectd fstab monit nfs quota"
Config[rsync]="/config/services/rsync rsync avahi rsyncd"
Config[smb]="/config/services/smb avahi samba"
Config[ssh]="/config/services/ssh ssh avahi samba"
Config[homedirectory]="/config/system/usermanagement/homedirectory samba"
Config[users]="/config/system/usermanagement/users postfix rsync samba systemd ssh"
Config[groups]="/config/system/usermanagement/groups rsync samba systemd"
Config[syslog]="/config/system/syslog rsyslog"

# Complementos
Config[openmediavault-omvextras]="/config/system/omvextras omvextras"
Config[openmediavault-anacron]="/config/services/anacron anacron"
Config[openmediavault-apttool]="/config/services/apttool"
Config[openmediavault-autoshutdown]="/config/services/autoshutdown autoshutdown"
Config[openmediavault-backup]="/config/system/backup cron"
Config[openmediavault-borgbackup]="/config/services/borgbackup borgbackup"
Config[openmediavault-clamav]="/config/services/clamav clamav"
Config[openmediavault-compose]="/config/services/compose compose"
Config[openmediavault-cputemp]="nulo"
Config[openmediavault-diskstats]="nulo"
Config[openmediavault-downloader]="/config/services/downloader"
Config[openmediavault-fail2ban]="/config/services/fail2ban fail2ban"
Config[openmediavault-filebrowser]="/config/services/filebrowser avahi filebrowser"
Config[openmediavault-flashmemory]="nulo"
Config[openmediavault-forkeddaapd]="/config/services/daap forked-daapd monit"
Config[openmediavault-ftp]="/config/services/ftp avahi monit proftpd"
Config[openmediavault-kernel]="nulo"
Config[openmediavault-kvm]="/config/services/kvm"
Config[openmediavault-locate]="nulo"
Config[openmediavault-luksencryption]="nulo luks"
Config[openmediavault-lvm2]="nulo collectd fstab monit quota"
Config[openmediavault-mergerfs]="/config/services/mergerfs collectd fstab mergerfs monit quota"
Config[openmediavault-minidlna]="/config/services/minidlna minidlna"
Config[openmediavault-nut]="/config/services/nut collectd monit nut"
Config[openmediavault-onedrive]="/config/services/onedrive onedrive"
Config[openmediavault-owntone]="/config/services/owntone owntone"
Config[openmediavault-photoprism]="/config/services/photoprism avahi photoprism"
Config[openmediavault-remotemount]="/config/services/remotemount collectd fstab monit quota remotemount"
Config[openmediavault-resetperms]="/config/services/resetperms"
Config[openmediavault-rsnapshot]="/config/services/rsnapshot rsnapshot"
Config[openmediavault-s3]="/config/services/minio avahi minio"
Config[openmediavault-sftp]="/config/services/sftp sftp"
Config[openmediavault-shairport]="/config/services/shairport monit shairport-sync"
Config[openmediavault-sharerootfs]="nulo"
Config[openmediavault-snapraid]="/config/services/snapraid snapraid"
Config[openmediavault-snmp]="/config/services/snmp snmpd"
Config[openmediavault-symlinks]="/config/services/symlinks"
Config[openmediavault-tftp]="/config/services/tftp avahi tftpd-hpa"
Config[openmediavault-tgt]="/config/services/tgt tgt"
Config[openmediavault-usbbackup]="/config/services/usbbackup usbbackup"
Config[openmediavault-wakealarm]="/config/system/wakealarm wakealarm"
Config[openmediavault-wetty]="/config/services/wetty avahi wetty"
Config[openmediavault-wireguard]="/config/services/wireguard wireguard"
Config[openmediavault-wol]="/config/services/wol"
Config[openmediavault-zfs]="nulo zfszed collectd fstab monit quota nfs samba sharedfolders systemd tftpd-hpa"

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export LANG=C.UTF-8
export LANGUAGE=C
export LC_ALL=C.UTF-8

# FUNCIONES

# Funciones OMV
. /usr/share/openmediavault/scripts/helper-functions

# Muestra el mensaje en español o inglés según el sistema.
# Opcional $1 = segundos de espera.
# Si hay espera -> Pulsar una tecla sale y devuelve Tecla=1, si no se pulsa Tecla="".
echoe () {
  Tecla=""
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    [ ! "$Sp" ] && echo -e "$2" || echo -e "$3"
    read -t"$1" -n1 -r -p "" Tecla
    if [ $? -eq 0 ]; then
      Tecla=1
    else
      Tecla=""
    fi
  else
    [ ! "$Sp" ] && echo -e "$1" || echo -e "$2"
  fi
}

help () {
  echo -e "\e[32m                                                                         "
  echo -e "_______________________________________________________________________________"
  echo -e "                                                                               "
  echo -e "              HELP FOR USING OMV-REGEN    (BACKUP AND REGENERATE)              "
  echo -e "                                                                               "
  echo -e "  - omv-regen   regenerates an OMV system from a clean install by restoring the"
  echo -e "    existing configurations to the original system.                            "
  echo -e "  - Install omv-regen on the original system, update and make a backup. Install"
  echo -e "    OMV on an empty disk without configuring anything.  Mount a backup, install"
  echo -e "    omv-regen and then regenerate. The version available on the internet of the"
  echo -e "    plugins and OMV must match.                                                "
  echo -e "  - Use omv-regen             to enable omv-regen on your system.              "
  echo -e "  - Use omv-regen backup      to store the necessary information to regenerate."
  echo -e "  - Use omv-regen regenerate  to run a system regeneration from a clean OMV.   "
  echo -e "_______________________________________________________________________________"
  echo -e "                                                                               "
  echo -e "   omv-regen       -->       Install and enable the command on the system.     "
  echo -e "_______________________________________________________________________________"
  echo -e "                                                                               "
  echo -e "   omv-regen backup   [OPTIONS]   [/folder_one \"/folder two\" /folder ... ]   "
  echo -e "                                                                               "
  echo -e "                                                                               "
  echo -e "    -b     Set the path to store the subfolders with [-b]ackups.               "
  echo -e "                                                                               "
  echo -e "    -d     Sets the [-d]ays of age of the saved backups (default 7 days).      "
  echo -e "                          You can edit the ORB_ prefix to keep a version.      "
  echo -e "    -h     Help.                                                               "
  echo -e "                                                                               "
  echo -e "    -o     Enable [-o]ptional folder backup. (by default /home /etc/libvirt)   "
  echo -e "                          Spaces to separate (can use quotes).                 "
  echo -e "    -u     Enable automatic system [-u]pdate before backup.                    "
  echo -e "_______________________________________________________________________________"
  echo -e "                                                                               "
  echo -e "   omv-regen regenera   [OPTIONS]   [/backup_folder]                           "
  echo -e "                                                                               "
  echo -e "                                                                               "
  echo -e "    -b     Sets path where the [-b]ackup created by omv-regen is stored.       "
  echo -e "                                                                               "
  echo -e "    -h     Help                                                                "
  echo -e "                                                                               "
  echo -e "    -k     Skip installing the proxmox [-k]ernel.                              "
  echo -e "                                                                               "
  echo -e "    -r     Enable automatic [-r]eboot if needed (create reboot service).       "
  echo -e "_______________________________________________________________________________"
  echo -e "                                                                          \e[0m"
  echo ""
  [ ! "$Sp" ] && echo -e "$1" || echo -e "$2"
  echo ""
  exit
}

# Analizar estado de paquete. Instalación y versiones.
Analiza () {
  VersionOR=""
  VersionDI=""
  InstII=""
  VersIdem=""
  VersionOR=$(awk -v i="$1" '$2 == i {print $3}' "${Ruta}${ORB[DpkgOMV]}")
  VersionDI=$(apt-cache madison "$1" | awk 'NR==1{print $3}')
  InstII=$(dpkg -l | awk -v i="$1" '$2 == i {print $1}')
  if [ "${InstII}" == "ii" ]; then
    InstII=OK
  else
    InstII=NO
  fi
  if [ "${VersionOR}" = "${VersionDI}" ]; then
    VersIdem=OK
  else
    VersIdem=NO
  fi
}

# Instalar paquete
Instala () {
  echoe "\nInstall $1 \n" "\nInstalando $1\n"
  if ! apt-get --yes install "$1"; then
    apt-get --yes --fix-broken install
    apt-get update
    if ! apt-get --yes install "$1"; then
      apt-get --yes --fix-broken install
      echoe "Failed to install $1. Exiting..." "$1 no se pudo instalar. Saliendo..."
      exit
    fi
  fi
}

# Extraer valor de una entrada de la base de datos
LeeValor () {
  ValorOR=""
  ValorAC=""
  NumVal=""
  echoe "Reading the value of $1 in original database..." "Leyendo el valor de $1 en la base de datos original..."
  ValorOR="$(xmlstarlet select --template --value-of "$1" --nl ${Ruta}${Config})"
  echoe "Reading the value of $1 in actual database..." "Leyendo el valor de $1 en la base de datos actual..."
  ValorAC="$(xmlstarlet select --template --value-of "$1" --nl ${Config})"
  NumVal="$(echo "${ValorAC}" | awk '{print NR}' | sed -n '$p')"
  echoe "The number of values ​​is ${NumVal}" "El número de valores es ${NumVal}"
}

# Lee campos completos entre todas las etiquetas del nodo $1/$2
LeeNodo () {
  NodoOR=""
  NodoAC=""
  NodoTM=""
  LinNodoOR=""
  echoe "Reading original node $1 ..." "Leyendo nodo original $1 ..."
  NodoOR="$(xmlstarlet select --template --copy-of "$1" --nl ${Ruta}${Config})"
  LinNodoOR="$(echo "${NodoOR}" | awk 'END {print NR}')"
  echoe "The original node $1 has ${LinNodoOR} lines." "El nodo original $1 tiene ${LinNodoOR} líneas."
  echoe "Reading actual node $1 ..." "Leyendo nodo actual $1 ..."
  NodoAC="$(xmlstarlet select --template --copy-of "$1" --nl ${Config})"
  if [ -f "${ConfTmp}" ]; then
    echoe "Reading temporary node $1 ..." "Leyendo nodo temporal $1 ..."
    NodoTM="$(xmlstarlet select --template --copy-of "$1" --nl ${ConfTmp})"
  else
    echoe "The temporary node of $1 is empty." "El nodo temporal de $1 está vacío."
  fi
}

# Sustituye nodo de la base de datos actual por el existente en la base de datos original y aplica cambios en módulos salt
Regenera () {
  InOR=""
  FiOR=""
  InAC=""
  FiAC=""
  LoAC=""
  NmInOR=""
  NmFiOR=""
  NmInAC=""
  NmFiAC=""
  NodoOR=""
  NodoAC=""
  NodoTM=""
  NodoGen=""
  LinNodoGen=""
  Gen=""
  Salt="aplicar"
  Nodo="$(echo "$1" | awk '{print $1}')"
  Padre="$(echo "${Nodo}" | awk -F "/" '{print $(NF-1)}')"
  Etiqueta="$(echo "${Nodo}" | awk -F "/" '{print $NF}')"
  if [ "${Nodo}" = "nulo" ]; then
    echoe "No node to regenerate has been defined in the database." "No se ha definido nodo para regenerar en la base de datos."
  else
    [ -f "${ConfTmp}ori" ] && rm -f "${ConfTmp}ori"
    cp -a "${Config}" "${ConfTmp}ori"
    echoe "\nRegenerating node ${Nodo} of the database\n" "\nRegenerando nodo ${Nodo} de la base de datos\n"
    omv_config_delete "${Etiqueta}"
    LeeNodo "${Nodo}"
    if [ "${NodoOR}" = "" ]; then
      echoe "The ${Nodo} node does not exist in the original database --> The database is not modified and no changes are applied to salt." "El nodo ${Nodo} no existe en la base de datos original --> No se modifica la base de datos ni se aplican cambios en salt."
      Salt=""
    elif [ "${NodoOR}" = "${NodoAC}" ]; then
      echoe "${Nodo} node matches original and current databases --> The database is not modified and no changes are applied to salt." "El nodo ${Nodo} coincide en la base de datos original y la actual --> No se modifica la base de datos ni se aplican cambios en salt."
      Salt=""
    else
      echoe "Regenerating ${Nodo}..." "Regenerando ${Nodo}..."
      NmInOR="$(awk "/<${Etiqueta}>/ {print NR}" "${Ruta}${Config}" | awk '{print NR}' | sed -n '$p')"
      echoe "${Etiqueta} has ${NmInOR} possible starts in original database." "${Etiqueta} tiene ${NmInOR} posibles inicios en la base de datos original."
      NmFiOR="$(awk "/<\/${Etiqueta}>/ {print NR}" "${Ruta}${Config}" | awk '{print NR}' | sed -n '$p')"
      echoe "${Etiqueta} has ${NmFiOR} possible endings in original database." "${Etiqueta} tiene ${NmFiOR} posibles finales en la base de datos original."
      NmInAC="$(awk "/<${Etiqueta}>/ {print NR}" "${Config}" | awk '{print NR}' | sed -n '$p')"
      if [ "${NmInAC}" = "" ]; then
        NmInAC="$(awk "/<${Etiqueta}\/>/ {print NR}" "${Config}" | awk '{print NR}' | sed -n '1p')"
        if [ "${NmInAC}" = "" ]; then
          echoe "${Etiqueta} does not exist in the current database. Generating ${Etiqueta} ..." "${Etiqueta} no existe en la base de datos actual. Generando ${Etiqueta} ..."
          sed -i "s/<\/${Padre}>/<${Etiqueta}>\n<\/${Etiqueta}>\n<\/${Padre}>/g" "${Config}"
          NmInAC="$(awk "/<${Etiqueta}>/ {print NR}" "${Config}" | awk '{print NR}' | sed -n '1p')"
        else
          echoe "${Etiqueta} starts and ends on the same line in current database. Inserting line..." "${Etiqueta} inicia y finaliza en la misma línea en la base de datos actual. Insertando línea..."
          sed -i "s/<${Etiqueta}\/>/<${Etiqueta}>\n<\/${Etiqueta}>/g" "${Config}"
        fi
      fi
      echoe "${Etiqueta} has ${NmInAC} possible starts in current database." "${Etiqueta} tiene ${NmInAC} posibles inicios en la base de datos actual."
      NmFiAC="$(awk "/<\/${Etiqueta}>/ {print NR}" "${Config}" | awk '{print NR}' | sed -n '$p')"
      echoe "${Etiqueta} has ${NmFiAC} possible endings in current database." "${Etiqueta} tiene ${NmFiAC} posibles finales en la base de datos actual."
      LoAC="$(awk 'END {print NR}' "${Config}")"
      echoe "Current database has ${LoAC} lines in total." "La base de datos actual tiene ${LoAC} líneas en total."
      IO=0
      Gen=""
      while [ $IO -lt ${NmInOR} ]; do
        [ "${Gen}" ] && break
        ((IO++))
        InOR="$(awk "/<${Etiqueta}>/ {print NR}" "${Ruta}${Config}" | awk -v i=$IO 'NR==i {print $1}')"
        echoe "Checking start of ${Etiqueta} in original database in line ${InOR}..." "Comprobando inicio de ${Etiqueta} en la base de datos original en linea ${InOR}..."
        FO=0
        while [ $FO -lt ${NmFiOR} ]; do
          [ "${Gen}" ] && break
          ((FO++))
          FiOR="$(awk "/<\/${Etiqueta}>/ {print NR}" "${Ruta}${Config}" | awk -v i=$FO 'NR==i {print $1}')"
          echoe "Checking end of ${Etiqueta} in original database in line ${FiOR}..." "Comprobando final de ${Etiqueta} en la base de datos original en linea ${FiOR}..."
          IA=0
          while [ $IA -lt ${NmInAC} ]; do
            [ "${Gen}" ] && break
            ((IA++))
            InAC="$(awk "/<${Etiqueta}>/ {print NR}" ${Config} | awk -v i=$IA 'NR==i {print $1}')"
            echoe "Checking start of ${Etiqueta} in current database in line ${InAC}..." "Comprobando inicio de ${Etiqueta} en la base de datos actual en línea ${InAC}..."
            FA=0
            while [ $FA -lt ${NmFiAC} ]; do
              ((FA++))
              FiAC="$(awk "/<\/${Etiqueta}>/ {print NR}" "${Config}" | awk -v i=$FA 'NR==i {print $1}')"
              echoe "Checking end of ${Etiqueta} in current database in line ${FiAC}..." "Comprobando final de ${Etiqueta} en la base de datos actual en línea ${FiAC}..."
              echoe "Creating temporary database..." "Creando base de datos temporal..."
              [ -f "${ConfTmp}" ] && rm -f "${ConfTmp}"
              cp -a "${Config}" "${ConfTmp}"
              sed -i '1,$d' "${ConfTmp}"
              awk -v IA="${InAC}" 'NR==1, NR==IA-1 {print $0}' "${Config}" > "${ConfTmp}"
              if [ "${InOR}" -eq "${FiOR}" ]; then
                NodoGen="$(awk -v IO="${InOR}" 'NR==IO {print $0}' "${Ruta}${Config}")"
              else
                NodoGen="$(awk -v IO="${InOR}" -v FO="${FiOR}" 'NR==IO, NR==FO {print $0}' "${Ruta}${Config}")"
              fi
              LinNodoGen="$(echo "${NodoGen}" | awk 'END {print NR}')"
              echo "${NodoGen}" >> "${ConfTmp}"
              awk -v FA="${FiAC}" -v LA="${LoAC}" 'NR==FA+1, NR==LA {print $0}' "${Config}" >> "${ConfTmp}"
              echoe "Generated ${Nodo} node from line ${InOR} to line ${FiOR} has ${LinNodoGen} lines." "El nodo ${Nodo} generado desde línea ${InOR} hasta línea ${FiOR} tiene ${LinNodoGen} líneas."
              echoe "Comparing ${Nodo} of temporary database with the original database..." "Comparando ${Nodo} de base de datos temporal con la base de datos original..."
              LeeNodo "${Nodo}"
              if [ "${NodoOR}" = "${NodoTM}" ] && [ "${LinNodoOR}" = "${LinNodoGen}" ]; then
                Gen="OK"
                echoe "The ${Nodo} node in temporary and original database are the same." "El nodo ${Nodo} coincide en la base de datos temporal y la original."
                break
              else
                echoe "\nGenerating new temporary database for ${Nodo} node ..." "\nGenerando nueva base de datos temporal para el nodo ${Nodo} ..."
              fi
            done
          done
        done
      done
      if [ ! "${Gen}" ]; then
        echoe "Failed to regenerate ${Nodo} node in the current database. Exiting..." "No se ha podido regenerar el nodo ${Nodo} en la base de datos actual. Saliendo..."
        rm -f "${Config}"
        cp -a "${ConfTmp}ori" "${Config}"
        exit
      else
        echoe "Regenerating ${Nodo} node in database ..." "Regenerando nodo ${Nodo} en base de datos ..."
        cp -a "${Config}" "${ConfTmp}ps"
        rm -f "${Config}"
        cp -a "${ConfTmp}" "${Config}"
        echoe "${Nodo} node regenerated in the database." "Nodo ${Nodo} regenerado en la base de datos."
      fi
    fi
  fi
  # Aplica cambios a los modulos seleccionados
  if [ "${Salt}" ]; then
    echoe "Applying configuration changes to salt modules..." "Aplicando cambios de configuración en los módulos salt..."
    Num="$(echo "$1" | awk '{print NF}')"
    if [ "${Num}" = "1" ]; then
      echoe "There are no configuration changes to apply to salt modules." "No hay cambios de configuración para aplicar en los módulos salt."
    else
      c=1
      while [ ${c} -lt ${Num} ]; do
   	    ((c++))
        Modulo="$(echo "$1" | awk -v c=${c} '{print $c}')"
        echoe "Configuring salt ${Modulo}..." "Configurando salt ${Modulo}..."
        omv-salt deploy run --quiet "${Modulo}"
        echoe "${Modulo} salt configured." "Salt ${Modulo} configurado."
      done
      Resto="$(cat "${Sucio}")"
      if [[ ! "${Resto}" == "[]" ]]; then
        omv-salt deploy run "$(jq -r .[] ${Sucio} | tr '\n' ' ')"
      fi
      echoe "The configuration of salt modules for the regeneration of the current node is complete..." "La configuración de módulos salt para la regeneración del nodo actual ha finalizado."
    fi
  fi
}

# Instalar omv-regen
InstalarOR (){
  if [ ! $0 = "${Inst}" ];then
    if [ -f "${Inst}" ]; then
      rm "${Inst}"
    fi
    touch "${Inst}"
    if [ -f "$0" ]; then
      cp -a "$0" "${Inst}"
    else
      Archivo=$(wget -O - https://raw.githubusercontent.com/xhente/omv-regen/master/omv-regen.sh)
      echo "${Archivo}" > "${Inst}"
    fi
    chmod +x "${Inst}"
    help "\n  omv-regen has been installed.\n" "\n  Se ha instalado omv-regen\n"
  else
    help "\n  omv-regen was already installed.\n" "\n  omv-regen estaba ya instalado.\n"
  fi
}

# Crear servicio reboot
Creasysreboot (){
  echoe "Generating reboot service..." "Generando servicio de reinicio..."
  if [ -f "${Sysreboot}" ]; then
    rm "${Sysreboot}"
  fi
  touch "${Sysreboot}"
  echo "[Unit]
Description=reboot omv-regen service
After=network.target network-online.target
Wants=network-online.target

[Service]
ExecStartPre=/bin/sleep 60
ExecStart=${Comando}

[Install]
WantedBy=multi-user.target" > "${Sysreboot}"
}

# VALIDA ENTORNO

# Root
if [[ $(id -u) -ne 0 ]]; then
  help "Run omv-regen with sudo or as root.  Exiting..." "Ejecuta omv-regen con sudo o como root.  Saliendo..."
fi

# Deshabilitar reboot.
if [ -f "${Sysreboot}" ]; then
  Habilit=$(systemctl list-unit-files | grep omv-regen-reboot | awk '{print $2}')
  if [ "${Habilit}" = "enabled" ]; then
    echoe "Disabling reboot..." "Deshabilitando reinicio..."
    systemctl disable omv-regen-reboot.service
  fi
fi

# Release 6.x.
if [ ! "$(lsb_release --codename --short)" = "bullseye" ]; then
  help "Unsupported version.  Only OMV 6.x. are supported.  Exiting..." "Versión no soportada.   Solo está soportado OMV 6.x.   Saliendo..."
fi

# Comprobar si omv-regen está instalado
if [ ! "$0" = "${Inst}" ]; then
  if [ "$1" ]; then
    help "omv-regen is not installed.\nTo install it run omv-regen with no arguments\n" "omv-regen no está instalado.\nPara instalarlo ejecuta omv-regen sin argumentos\n"
  else
    InstalarOR
  fi
fi

# PROCESA ARGUMENTOS

# Almacenar argumentos de ejecución.
Comando="$0"
for i in "$@"; do
  Comando="${Comando} $i"
done

# Procesa primer argumento
case "$1" in
  backup)
    Back=1
    echoe  "\n       <<< Backup to regenerate system dated ${Fecha} >>>\n" "\n       <<< Backup para regenerar sistema de fecha ${Fecha} >>>\n"
    ;;
  regenera)
    Rege=1
    echoe  "\n       <<< Regenerating OMV system >>>\n" "\n       <<< Regenerando sistema OMV >>>\n"
    ;;
  help)
    help
    ;;
  *)
    help "Invalid argument. Exiting..." "Argumento inválido. Saliendo..."
    ;;
esac
shift

# Procesa parámetros backup
if [ $Back ]; then
  while getopts "b:d:ho:u" opt; do
    case "$opt" in
      b)
        if [ -d "${OPTARG}" ]; then
          Ruta="${OPTARG}"
          echoe "The backup will be stored in ${Ruta}" "El backup se almacenará en ${Ruta}"
        else
          help "The folder ${OPTARG} does not exist. Exiting..." "La carpeta ${OPTARG} no existe. Saliendo..."
        fi
        ;;
      d)
        if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
          OpDias=$OPTARG
          echoe "Backups older than $OpDias days will be deleted." "Se eliminarán los backups de mas de $OpDias días de antigüedad."
        else
          help "The -d option must be a number. Coming out..." "La opción -d debe ser un número. Saliendo..."
        fi
        ;;
      h)
        help
        ;;
      o)
        if [ -d "${OPTARG}" ]; then
          OpFold="${OPTARG}"
          echoe "The folder ${OpFold} is to be copied." "La carpeta ${OpFold} se va a copiar."
        else
          help "The folder ${OPTARG} does not exist. Exiting..." "La carpeta ${OPTARG} no existe. Saliendo..."
        fi
        ;;
      u)
        OpUpda=1
        echoe "The system will be updated before making the backup." "Se va a actualizar el sistema antes de hacer el backup."
        ;;
      *)
        help "Invalid argument. Exiting..." "Argumento inválido. Saliendo..."
        ;;
    esac
  done
fi

# Procesa parámetros regenera
if [ $Rege ]; then
  while getopts "b:hkr" opt; do
    case "$opt" in
      b)
        if [ -d "${OPTARG}" ]; then
          Ruta="${OPTARG}"
          echoe "${Ruta} has been set as data source." "Se ha establecido ${Ruta} como origen de datos."
        else
          help "The folder ${OPTARG} does not exist. Exiting..." "La carpeta ${OPTARG} no existe. Saliendo..."
        fi
        ;;
      h)
        help
        ;;
      k)
        OpKern=""
        echoe "The proxmox kernel will not be installed." "No se instalará el kernel proxmox."
        ;;
      r)
        OpRebo=1
        echoe 3 "It will automatically reboot the system after installing a kernel." "Se reiniciará automáticamente el sistema después de instalar un kernel."
        ;;
      *)
        help "Invalid argument. Exiting..." "Argumento inválido. Saliendo..."
        ;;
    esac
  done
fi

# Procesa resto de argumentos 
shift $((OPTIND -1))
if [ "$Back" ] && [ "$1" ]; then
  if [ "${OpFold}" ]; then
    for i in "$@"; do
      if [ -d "$i" ]; then
        echoe "The folder $i is to be copied." "La carpeta $i se va a copiar."
      else
        help "The folder $i does not exist. Coming out..." "La carpeta $i no existe. Saliendo..."
      fi
    done
  else
  help "Invalid argument. Coming out..." "Argumento inválido. Saliendo..."
  fi
fi

if [ "$Back" ] && [ ! "${Ruta}" ]; then
  echoe "No backup folder has been set. It will be stored in ${ORBackup}" "No se ha establecido carpeta para el backup. Se almacenará en ${ORBackup}"
  if [ ! -d "${ORBackup}" ]; then
    mkdir -p "${ORBackup}"
  fi
  Ruta="${ORBackup}"
fi

if [ "$Rege" ]; then
  if [ "$2" ]; then
    help "Invalid argument $2 Exiting..." "Argumento inválido $2 Saliendo..."
  else
    if [ "$1" ]; then
      if [ "${Ruta}" ]; then
        help "Invalid argument $1 Exiting..." "Argumento inválido $1 Saliendo..."
      else
        if [ -d "$1" ]; then
          Ruta="$1"
          echoe "${Ruta} has been set as data source." "Se ha establecido ${Ruta} como origen de datos."
        else
          help "The folder $1 does not exist. Exiting..." "La carpeta $1 no existe. Saliendo..."
        fi
      fi
    else
      if [ ! "${Ruta}" ]; then
        help "The source path of the backup to rebuild is missing. Exiting..." "Falta la ruta de origen del backup para regenerar. Saliendo..."
      fi
    fi
  fi
fi

# EJECUTA BACKUP

# Opción actualizar
if [ "$OpUpda" ]; then
  if ! omv-upgrade; then
    echoe "Failed updating system. Exiting..." "Error actualizando el sistema.  Saliendo..."
    exit
  fi
fi

if [ $Back ]; then

  # Crea carpeta Destino
  Destino="${Ruta}/ORB_${Fecha}"
  echoe 5 "A backup is going to be made in ${Destino} \nPress any key within 5 seconds to  ABORT" "Se va a realizar un backup en ${Destino} \nPulsa cualquier tecla antes de 5 segundos para  ABORTAR"
  if [ "${Tecla}" ]; then
    help "Exiting..." "Saliendo..."
  else
    if [ -d "${Destino}" ]; then
      rm "${Destino}"
    fi
    mkdir -p "${Destino}"
  fi

# Copia directorios opcionales
  if [ "${OpFold}" ]; then
    echoe ">>>    Copying optional $OpFold directory..." ">>>    Copiando directorio opcional $OpFold..."
    mkdir -p "${Destino}$OpFold"
    rsync -av "$OpFold"/ "${Destino}$OpFold"
    while [ "$*" ]; do
      echoe ">>>    Copying optional ${1} directory..." ">>>    Copiando directorio opcional ${1}..."
      mkdir -p "${Destino}$OpFold"
      rsync -av "${1}"/ "${Destino}${1}"
      shift
    done
  fi

  # Copiar directorios existentes predeterminados
  for i in "${Directorios[@]}"; do
    if [ -d "$i" ]; then
      echoe ">>>    Copying $i directory..." ">>>    Copiando directorio $i..."
      if [ ! -d "${Destino}$i" ]; then
        mkdir -p "${Destino}$i"
      fi
      rsync -av "$i"/ "${Destino}$i"
    fi
  done

  # Copiar archivos predeterminados
  echoe ">>>    Copying files to ${Destino}..." ">>>    Copiando archivos a ${Destino}..."
  for i in "${Archivos[@]}"; do
    if [ ! -d "$(dirname "${Destino}$i")" ]; then
      mkdir -p "$(dirname "${Destino}$i")"
    fi
    cp -apv "$i" "${Destino}$i"
  done

  # Crea registro dpkg
  echoe ">>>    Extracting version list (dpkg)..." ">>>    Extrayendo lista de versiones (dpkg)..."
  dpkg -l | grep openmediavault > "${Destino}${ORB[DpkgOMV]}"
  dpkg -l > "${Destino}${ORB[Dpkg]}"
  awk '{print $2" "$3}' "${Destino}${ORB[DpkgOMV]}"

  # Crea registro uname -a
  echoe ">>>    Extracting system info (uname -a)..." ">>>    Extrayendo información del sistema (uname -a)..."
  uname -a | tee "${Destino}${ORB[Unamea]}"

  # Crea registro zpool list
  echoe ">>>    Extracting zfs info (zpool list)..." ">>>    Extrayendo información de zfs (zpool list)..."
  zpool list | tee "${Destino}${ORB[Zpoollist]}"

  # Crea registro docker systemctl
  echoe ">>>    Extracting information from systemd (systemctl)..." ">>>    Extrayendo información de systemd (systemctl)..."
  systemctl list-unit-files | tee "${Destino}${ORB[Systemctl]}"

  # Crea registro de configuracion de red
  echoe ">>>    Retrieving network information (hostname -I)..." ">>>    Extrayendo información de red (hostname -I)..."
  hostname -I | tee "${Destino}${ORB[HostnameI]}"

  # Elimina backups antiguos
  echoe ">>>    Deleting backups larger than ${OpDias} days..." ">>>    Eliminando backups de hace más de ${OpDias} días..."
  find "${Ruta}/" -maxdepth 1 -type d -name "ORB_*" -mtime "+$OpDias" -exec rm -rv {} +
  # Nota:   -mmin = minutos  ///  -mtime = dias
  
  echoe "\n       Backup completed!\n" "\n       ¡Backup completado!\n"
  exit
fi

# EJECUTA REGENERACION DE SISTEMA

# FASE 0 - COMPROBACIONES

echoe 10 "\n\nThe REGENERATION OF THE CURRENT SYSTEM will be executed from ${Ruta} \nPress any key within 10 seconds to  ABORT....." "\n\nSe va a ejecutar la  REGENERACION DEL SISTEMA ACTUAL  desde ${Ruta} \nPulsa cualquier tecla antes de 10 segundos para  ABORTAR....."
if [ "${Tecla}" ]; then
  help "Aborted regeneration. Exiting..." "Regeneración abortada. Saliendo..."
fi

# Comprobar backup
for i in "${ORB[@]}"; do
  if [ ! -f "${Ruta}$i" ]; then
    help "Missing file $i in ${Ruta}. Coming out..." "Falta el archivo $i en ${Ruta}.  Saliendo..."
  fi
done

# Actualizar sistema
if ! omv-upgrade; then
  echoe "Failed updating system.  Exiting..." "Error actualizando el sistema.  Saliendo..."
  exit
fi

# Versión de OMV original
Analiza "openmediavault"
if [ "${VersIdem}" = "NO" ]; then
  help "The OMV version of the original server does not match.  Exiting..." "La versión de OMV del servidor original no coincide.  Saliendo..."
fi

# FASE 1 - Regenerar configuraciones básicas.
Dif=""
Dif="$(diff "${Ruta}${Passwd}" ${Passwd})"
if [ "${Dif}" ]; then
  cp -apv "${Ruta}${Passwd}" "${Passwd}"
  echoe "\nRegenerating basic system settings...\n" "\nRegenerando configuraciones básicas del sistema...\n"
  Regenera "${Config[time]}"
  Regenera "${Config[certificates]}"
  Regenera "${Config[webadmin]}"
  Regenera "${Config[powermanagement]}"
  Regenera "${Config[monitoring]}"
  Regenera "${Config[crontab]}"
  Regenera "${Config[apt]}"
  Regenera "${Config[syslog]}"
  echoe "Preparing database configurations ... ... ..." "Preparando configuraciones de la base de datos ... ... ..."
  omv-salt stage run prepare --quiet
  echoe "Updating database configurations ... ... ..." "Actualizando configuraciones de la base de datos ... ... ..."
  omv-salt stage run deploy --quiet
fi

# FASE 2 - Instalar omv-extras.
Analiza "openmediavault-omvextrasorg"
if [ "${VersionOR}" ] &&  [ "${InstII}" = "NO" ]; then
  echoe "\nInstalling omv-extras...\n" "\nInstalando omv-extras...\n"
  echoe "Downloading omv-extras.org plugin for openmediavault 6.x ..." "Descargando el complemento omv-extras.org para openmediavault 6.x ..."
  File="openmediavault-omvextrasorg_latest_all6.deb"
  if [ -f "${File}" ]; then
    rm ${File}
  fi
  wget "${URL}/${File}"
  if [ -f "${File}" ]; then
    if ! dpkg --install ${File}; then
      echoe "Installing other dependencies ..." "Instalando otras dependencias ..."
      apt-get --yes --fix-broken install
      Analiza "openmediavault-omvextrasorg"
      if [[ "${InstII}" = "NO" ]]; then
        echoe "omv-extras failed to install correctly.  Trying to fix with omv-salt deploy run ..." "omv-extras no se pudo instalar correctamente. Intentando corregir con omv-salt deploy run ..."
        if omv-salt deploy run --quiet omvextras; then
          echoe "Trying to fix apt ..." "Tratando de corregir apt..."
          apt-get --yes --fix-broken install
        else
          echoe "omv-salt deploy run failed and openmediavault-omvextrasorg is in a bad state. Exiting..." "omv-salt deploy run falló y openmediavault-omvextrasorg está en mal estado. Saliendo..."
          exit 3
        fi
      fi
      Analiza "openmediavault-omvextrasorg"
      if [[ "${InstII}" = "NO" ]]; then
        echoe "openmediavault-omvextrasorg package failed to install or is in a bad state. Exiting..." "El paquete openmediavault-omvextrasorg no se pudo instalar o está en mal estado. Saliendo..."
        exit 3
      fi
    fi
    echoe "Updating repos ..." "Actualizando repositorios..."
    omv-salt deploy run --quiet omvextras
  else
    echoe "There was a problem downloading the package. Exiting..." "Hubo un problema al descargar el paquete. Saliendo..."
    exit
  fi
fi

# FASE 3 - Analizar versiones y complementos especiales.
echoe "\nAnalyzing original system plugins...\n" "\nAnalizando complementos del sistema original...\n"
cont=0
for i in $(awk '{print NR}' "${Ruta}${ORB[DpkgOMV]}"); do
  Plugin=$(awk -v i="$i" 'NR==i{print $2}' "${Ruta}${ORB[DpkgOMV]}")
  Analiza "${Plugin}"
  if [ "${InstII}" = "NO" ]; then
    echoe "Versions $VersIdem \tInstalled $InstII \t${Plugin} \c" "Versiones $VersIdem \tInstalado $InstII \t${Plugin} \c"
    case "${Plugin}" in
      *"kernel" ) ;;
      *"sharerootfs" ) ;;
      *"zfs" ) ;;
      *"lvm2" ) ;;
      *"mergerfs" ) ;;
      *"snapraid" ) ;;
      *"remotemount" ) ;;
      *"symlinks" ) ;;
      *"apttool" ) ;;
      *"kvm" ) ;;
      * )
        (( cont++ ))
        ListaInstalar[cont]="${Plugin}"
        ;;
    esac
    if [ "${VersIdem}" = "NO" ]; then
      echoe "\t************\n********** ERROR: Available version $VersionDI The original system version $VersionOR does not match. Exiting..." "\t**********\n********** ERROR:  Versión disponible $VersionDI La versión del sistema original $VersionOR no coincide. Saliendo..."
      exit
    else
      echoe "--> It will install..." "  -->  Se va a instalar..."
    fi
  fi
done

# FASE 4 - Instalar kernel proxmox
Analiza openmediavault-kernel
if [ "${VersionOR}" ] && [ "${VersIdem}" = "OK" ] && [ "${InstII}" = "NO" ]; then
  Instala openmediavault-kernel
  if [ ! $OpKern ]; then
    echoe "Skip proxmox kernel option enabled. Kernel will not be installed." "Opción saltar kernel proxmox habilitada. No se instalará kernel."
  else
    KernelOR=$(awk '{print $3}' "${Ruta}${ORB[Unamea]}" | awk -F "." '/pve$/ {print $1"."$2}')
    KernelIN=$(uname -r | awk -F "." '/pve$/ {print $1"."$2}')
    if [ "${KernelOR}" ] && [ ! "${KernelOR}" = "${KernelIN}" ]; then
      echoe "\nInstalling proxmox kernel ${KernelOR}\n" "\nInstalando kernel proxmox ${KernelOR}\n"
      cp -a /usr/sbin/omv-installproxmox /tmp/installproxmox
      sed -i 's/^exit 0.*$/echo "Completado"/' /tmp/installproxmox
      . /tmp/installproxmox "${KernelOR}"
      rm /tmp/installproxmox
      echoe "Kernel proxmox ${KernelOR} installed." "Kernel proxmox ${KernelOR} instalado."
      if [ "${OpRebo}" ]; then
        echoe "\nAuto reboot option enabled.\nTo use the new kernel the system will be rebooted.\nThe regeneration will continue in the background.\nDo not shut down the server until it is rebooted a second time." "\nOpción reinicio automático activada.\nPara utilizar el nuevo kernel se va a reiniciar el sistema.\nLa regeneración continuará en segundo plano.\nNo apagues el servidor hasta que se reinicie por segunda vez."
        echoe 10 "\nTo   ABORT RESET   press a key within 10 seconds..." "\nPara   ABORTAR REINICIO   presiona una tecla antes de 10 segundos..."
        if [ "${Tecla}" ]; then
          echoe "Reboot aborted.\n" "Reinicio abortado.\n"
        else
          Creasysreboot
          systemctl enable omv-regen-reboot.service
          echoe 3 "Reboot service enabled." "Servicio de reinicio habilitado."
          echoe "Rebooting..." "Reiniciando..."
          reboot
          exit
        fi
      fi
      echoe "\nAuto reboot option disabled.\nTo use the new kernel you must reboot the system manually.\n\n\033[0;32m To complete the regeneration -> AFTER REBOOT RUN AGAIN omv-regen regenerates\n\n\033 [0m Leaving..." "\nOpción reinicio automático deshabilitada.\nPara utilizar el nuevo kernel debes reiniciar el sistema manualmente.\n\n\033[0;32m Para completar la regeneración -> DESPUES DE REINICIAR EJECUTA DE NUEVO omv-regen regenera\n\n\033[0m Saliendo..."
      exit
    fi
  fi
fi

# FASE 5 - MONTAR SISTEMAS DE ARCHIVOS.

# Instala openmediavault-sharerootfs. Regenera fstab (Sistemas de archivos EXT4 BTRFS mdadm)
Analiza openmediavault-sharerootfs
if [ "${InstII}" = "NO" ]; then
  echoe "\nMounting filesystems...\n" "\nMontando sistemas de archivos...\n"
  Instala openmediavault-sharerootfs
  Regenera "${Config[hdparm]}"
  Regenera "${Config[fstab]}"
  # Cambia UUID disco de sistema si es nuevo
  echoe "Configuring openmediavault-sharerootfs..." "Configurando openmediavault-sharerootfs..."
  uuid="79684322-3eac-11ea-a974-63a080abab18"
  if [ "$(omv_config_get_count "//mntentref[.='${uuid}']")" = "0" ]; then
    omv-confdbadm delete --uuid "${uuid}" "conf.system.filesystem.mountpoint"
  fi
  apt-get install --reinstall openmediavault-sharerootfs
fi

# Instalar openmediavault-zfs. Importar pools.
Analiza openmediavault-zfs
if [ "${VersionOR}" ] && [ "${VersIdem}" = OK ] && [ "${InstII}" = "NO" ]; then
  Instala openmediavault-zfs
  for i in $(awk 'NR>1{print $1}' "${Ruta}${ORB[Zpoollist]}"); do
    zpool import -f "$i"
  done
  Regenera "${Config[openmediavault-zfs]}"
fi

# Instalar openmediavault-lvm2
Analiza openmediavault-lvm2
if [ "${VersionOR}" ] && [ "${VersIdem}" = OK ] && [ "${InstII}" = "NO" ]; then
  Instala openmediavault-lvm2
  Regenera "${Config[openmediavault-lvm2]}"
fi

# Instalar openmediavault-mergerfs
Analiza openmediavault-mergerfs
if [ "${VersionOR}" ] && [ "${VersIdem}" = OK ] && [ "${InstII}" = "NO" ]; then
  Instala openmediavault-mergerfs
  Regenera "${Config[openmediavault-mergerfs]}"
fi

# Instalar openmediavault-snapraid
Analiza openmediavault-snapraid
if [ "${VersionOR}" ] && [ "${VersIdem}" = OK ] && [ "${InstII}" = "NO" ]; then
  Instala openmediavault-snapraid
  Regenera "${Config[openmediavault-snapraid]}"
fi

# Instalar openmediavault-remotemount
Analiza openmediavault-remotemount
if [ "${VersionOR}" ] && [ "${VersIdem}" = OK ] && [ "${InstII}" = "NO" ]; then
  Instala openmediavault-remotemount
  Regenera "${Config[openmediavault-remotemount]}"
fi

# Instalar openmediavault-symlinks
Analiza openmediavault-symlinks
if [ "${VersionOR}" ] && [ "${VersIdem}" = OK ] && [ "${InstII}" = "NO" ]; then
  Instala openmediavault-symlinks
  Regenera "${Config[openmediavault-symlinks]}"
  LeeValor /config/services/symlinks/symlinks/symlink/source
  if [ ! "${NumVal}" ]; then
    echoe "No symlinks created in original database." "No hay symlinks creados en la base de datos original."
  else
    i=0
    while [ $i -lt ${NumVal} ]; do
      ((i++))
      LeeValor /config/services/symlinks/symlinks/symlink/source
      SymFU=$(echo "${ValorAC}" | awk -v i=$i 'NR==i {print $1}')
      LeeValor /config/services/symlinks/symlinks/symlink/destination
      SymDE=$(echo "${ValorAC}" | awk -v i=$i 'NR==i {print $1}')
      echoe "Creating symlink ${SymFU} ${SymDE}" "Creando symlink ${SymFU} ${SymDE}"
      ln -s "${SymFU}" "${SymDE}"
    done
  fi
fi

# FASE 6 - REGENERAR RESTO DE GUI. INSTALAR DOCKER

# Restaurar archivos. Regenerar Usuarios. Carpetas compartidas. Smart. Servicios. Red. omv-extras (docker).
Dif=$(diff "${Ruta}${Shadow}" "${Shadow}")
if [ "${Dif}" ]; then
  echoe "\nRegenerating the rest of the system...\n" "\nRegenerando el resto del sistema...\n"
  echoe "Restoring files..." "Restaurando archivos..."
  rsync -av "${Ruta}"/ / --exclude "${Config}" --exclude /ORB_*
  echoe "Regenerating users..." "Regenerando usuarios..."
  Regenera "${Config[homedirectory]}"
  Regenera "${Config[users]}"
  Regenera "${Config[groups]}"
  echoe "Regenerating shared folders..." "Regenerando carpetas compartidas..."
  Regenera "${Config[shares]}"
  echoe "Regenerating SMART..." "Regenerando SMART..."
  Regenera "${Config[smart]}"
  echoe "Regenerating Services..." "Regenerando Servicios..."
  Regenera "${Config[nfs]}"
  Regenera "${Config[rsync]}"
  Regenera "${Config[smb]}"
  Regenera "${Config[ssh]}"
  Regenera "${Config[email]}"
  Regenera "${Config[notification]}"
  echoe "Regenerating Network..." "Regenerando Red..."
  Regenera "${Config[dns]}"
  Regenera "${Config[proxy]}"
  Regenera "${Config[iptables]}"
  echoe "Preparing database configurations ... ... ..." "Preparando configuraciones de la base de datos ... ... ..."
  omv-salt stage run prepare --quiet
  echoe "Updating database configurations ... ... ..." "Actualizando configuraciones de la base de datos ... ... ..."
  omv-salt stage run deploy --quiet
fi

# Instalar docker
DockerOR=$(awk '/docker.service/ {print $2}' "${Ruta}${ORB[Systemctl]}")
DockerII=$(systemctl list-unit-files | grep docker.service | awk '{print $2}')
if [ "${DockerOR}" ] && [ ! "${DockerII}" ]; then
  echoe "\nInstalling docker...\n" "\nInstalando docker...\n"
  echoe "Regenerating omvextras..." "Regenerando omvextras..."
  Regenera "${Config[openmediavault-omvextras]}"
  DockerII=$(systemctl list-unit-files | grep docker.service | awk '{print $2}')
  if [ ! "${DockerII}" ]; then
    cp -a /usr/sbin/omv-installdocker /tmp/installdocker
    sed -i 's/^exit 0.*$/echo "Salida installdocker"/' /tmp/installdocker
    . /tmp/installdocker
    rm /tmp/installdocker
  fi
  echoe "Docker installed." "Docker instalado."
fi

# FASE 7 - INSTALAR RESTO DE COMPLEMENTOS

# Instalar apttool (antes que el resto)
Analiza openmediavault-apttool
if [ "${VersionOR}" ] && [ "${VersIdem}" = OK ] && [ "${InstII}" = "NO" ]; then
  Instala openmediavault-apttool
  Regenera "${Config[openmediavault-apttool]}"
  LeeValor /config/services/apttools/packages/package/packagename
  if [ ! "${NumVal}" ]; then
    echoe "There are no packages installed in the original database." "No hay paquetes instalados en la base de datos original."
  else
    i=0
    while [ $i -lt ${NumVal} ]; do
      ((i++))
      Pack=$(echo "${ValorAC}" | awk -v i=$i 'NR==i {print $1}')
      Analiza "${Pack}"
      if [ "${VersionOR}" ] && [ "${InstII}" = "NO" ]; then
        Instala "${Pack}"
      fi
    done
  fi
fi

# Instalar openmediavault-kvm (requiere opción especial de instalación)
Analiza openmediavault-kvm
if [ "${VersionOR}" ] && [ "${VersIdem}" = OK ] && [ "${InstII}" = "NO" ]; then
  echoe "\nInstall openmediavault-kvm \n" "\nInstalando openmediavault-kvm\n"
  if ! apt-get --yes --option DPkg::Options::="--force-confold" install openmediavault-kvm; then
    apt-get --yes --fix-broken install
    apt-get update
    if ! apt-get --yes --option DPkg::Options::="--force-confold" install openmediavault-kvm; then
      apt-get --yes --fix-broken install
      echoe "Failed to install openmediavault-kvm. Exiting..." "openmediavault-kvm no se pudo instalar. Saliendo..."
      exit
    fi
  fi
  Regenera "${Config[openmediavault-kvm]}"
fi

# Instalar resto de complementos
for i in "${ListaInstalar[@]}"; do
  Analiza "$i"
  if [ "${VersIdem}" = "OK" ] && [ "${InstII}" = "NO" ]; then
    Instala "$i" 
    if [ "${Config[$i]}" = "" ]; then
      echoe "\nERROR >>> There is no setting in omv-regen to regenerate the plugin $i\n" "\nERROR >>> No existe la configuración en omv-regen para regenerar el complemento $i\n"
    else
      Regenera "${Config[$i]}"
    fi
  fi
done

# FASE 8 - RECONFIGURAR, ACTUALIZAR, LIMPIAR, CONFIGURAR RED, REINICIAR

# Reconfigurar y actualizar
echoe "Preparing database configurations ... ... ..." "Preparando configuraciones de la base de datos ... ... ..."
omv-salt stage run prepare --quiet
echoe "Updating database configurations ... ... ..." "Actualizando configuraciones de la base de datos ... ... ..."
omv-salt stage run deploy --quiet
omv-upgrade

# Elimina archivos temporales, configura red y reinicia
echoe "Deleting temporary files..." "Eliminando archivos temporales..."
[ -f "${ConfTmp}ps" ] && rm "${ConfTmp}ps"
[ -f "${ConfTmp}ori" ] && rm "${ConfTmp}ori"
[ -f "${ConfTmp}" ] && rm "${ConfTmp}"
[ -f "/tmp/installproxmox" ] && rm /tmp/installproxmox
[ -f "/tmp/installdocker" ] && rm /tmp/installdocker
IpAC=$(hostname -I | awk '{print $1}')
IpOR=$(awk '{print $1}' "${Ruta}${ORB[HostnameI]}")
if [ ! "${IpOR}" = "${IpAC}" ]; then
  echoe 10 "It will regenerate the network interface and restart the server.\n\n\e[32m After restart you will be able to access from IP ${IpOR}\e[0m \n\nPress any key within 10 seconds to  ABORT  network configuration." "Se va a regenerar la interfaz de red y reiniciar el servidor.\n\n\e[32m Después de reiniciar podrás acceder desde la IP ${IpOR}\e[0m \n\nPresiona cualquier tecla antes de 10 segundos para  ABORTAR  la configuración de red."
  if [ "${Tecla}" ]; then
    Tecla=""
    echoe "\nNetwork configuration aborted.\n\nSystem regeneration finished!!\n\n\e[32m IP after reboot will remain ${IpAC}\e[0m If you still need to regenerate the network you can run omv-regen regenerate again after the reboot. Rebooting...\n" "\nConfiguración de red abortada.\n\nLa regeneración del sistema ha finalizado!!\n\n\e[32m La IP después de reiniciar seguirá siendo ${IpAC}\e[0m \n\n Si aún necesitas regenerar la red puedes ejecutar de nuevo omv-regen regenera después del reinicio. Reiniciando...\n"
    reboot
    echoe 3 "" ""
    exit
  fi
fi

echoe "Configuring network..." "Configurando red..."
Regenera "${Config[interfaces]}"
echoe "\n\nSystem regeneration finished!!\n\n\e[32m IP after reboot will be ${IpOR}\e[0m Rebooting..." "\n\nLa regeneración del sistema ha finalizado!!\n\n\e[32m La IP después de reiniciar será ${IpOR}\e[0m Reiniciando..."
reboot
echoe 3 "" ""
exit