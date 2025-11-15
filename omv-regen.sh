#!/bin/bash
# -*- ENCODING: UTF-8 -*-

# This file is licensed under the terms of the GNU General Public
# License version 3. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

# omv-regen
# Utilidad de copia de seguridad y restauración de la configuración de OpenMediaVault
# OpenMediaVault configuration backup and restore utility

##################################################
# omv-regen_install.sh
##################################################
# Instalador dinámico para seleccionar la versión correcta de omv-regen
# Detecta Debian/OMV y descarga la versión según corresponda
##################################################
# Dynamic installer to select the correct omv-regen version
# Detects Debian/OMV and downloads the corresponding version
##################################################

Logo_omvregen="\
\n┌───────────────┐                                         \
\n│               │     ┌────────────┐     ┌──────────────┐ \
\n│   omv-regen   │ >>> │   backup   │ >>> │   regenera   │ \
\n│               │     └────────────┘     └──────────────┘ \
\n└───────────────┘                                         "

# Variables
OR_script_file="/usr/sbin/omv-regen"
OR_dir="/var/lib/omv-regen"
OR_ajustes_file="${OR_dir}/settings/omv-regen.settings"
URL_OMVREGEN="https://raw.githubusercontent.com/xhente/omv-regen/master"
Apt_updated=0
# shellcheck disable=SC2016
DEBIAN_CODENAME__or=$(
    codename_os=$(env -i bash -c '. /etc/os-release; echo $VERSION_CODENAME')
    codename_dpkg=$(dpkg --status tzdata 2>/dev/null | awk -F'[:-]' '/Provides/{print $NF}' | tr -d ' ')
    [[ -n "$codename_dpkg" && "$codename_dpkg" != "$codename_os" ]] && echo "$codename_dpkg" || echo "$codename_os"
)
Idioma="en"
if locale -a 2>/dev/null | grep -q '^es_'; then
    Idioma="es"
fi

# Función de mensaje bilingüe
# Bilingual messaging function
echoe() {
    local msg_es="$1" msg_en="$2"
    if [[ "$Idioma" = "en" && -n "$msg_en" ]]; then
        echo -e "$msg_en"
    else
        echo -e "$msg_es"
    fi
}

# Dependencia mínima
# Minimum dependency
InstalarPaquete() {
    local paquete="$1"
    if ! command -v "$paquete" >/dev/null 2>&1; then
        echoe ">>> Dependencia faltante, instalando $paquete ..." \
              ">>> Missing dependency, installing $paquete ..."
        if [[ $Apt_updated -eq 0 ]]; then
            apt-get update -qq || {
                echoe ">>> ERROR: Fallo actualizando repositorios." \
                      ">>> ERROR: Failure updating repositories."
                exit 1
            }
            Apt_updated=1
        fi
        apt-get --yes install "$paquete" >/dev/null 2>&1 || {
            echoe ">>> ERROR: Fallo instalando $paquete." \
                  ">>> ERROR: Error installing $paquete."
            exit 1
        }
    fi
}

echoe "\n$Logo_omvregen \n"

# Ejecutar como root
# Run as root
[[ $(id -u) -ne 0 ]] && { echoe ">>> Ejecuta omv-regen como root. Saliendo ..." \
                                ">>> Run omv-regen as root. Exiting ..."; exit 1; } 

# Seleccionar script según versión
# Select script according to version
case "$DEBIAN_CODENAME__or" in
    bullseye|bookworm)
        SCRIPT="omv-regen_6_7.sh"
        ;;
    trixie)
        SCRIPT="omv-regen_8.sh"
        ;;
    *)
        echoe ">>> Versión no soportada: ${DEBIAN_CODENAME__or}.   Solo está soportado Debian 11 (OMV 6.x), Debian 12 (OMV 7.x) y Debian 13 (OMV 8.x).  Saliendo ..." \
              ">>> Unsupported version: ${DEBIAN_CODENAME__or}.   Only Debian 11 (OMV 6.x), Debian 12 (OMV 7.x) and Debian 13 (OMV 8.x) are supported.  Exiting ..."
        exit 1
        ;;
esac

# Instalar dependencias necesarias
# Install necessary dependencies
InstalarPaquete dialog
InstalarPaquete wget

# Descargar e instalar
# Download and install
echoe ">>> Instalando omv-regen desde $URL_OMVREGEN/$SCRIPT ..." \
      ">>> Installing omv-regen from $URL_OMVREGEN/$SCRIPT ..."
mv "$OR_script_file" "$OR_script_file"Old 2>/dev/null || true
if wget -q -O "$OR_script_file" "$URL_OMVREGEN/$SCRIPT"; then
    grep -q "omv-regen" "$OR_script_file" || {
        echoe ">>> ERROR: Archivo descargado inválido o corrupto." \
              ">>> ERROR: Invalid or corrupted file downloaded."
        rm -f "$OR_script_file"
        mv "$OR_script_file"Old "$OR_script_file" 2>/dev/null || true
        exit 1
    }
    chmod +x "$OR_script_file"
    rm -f "$OR_script_file"Old 2>/dev/null || true
    rm -f "$OR_ajustes_file" 2>/dev/null || true
    echoe "\n>>> Instalación completada. Puedes ejecutar 'omv-regen' en cualquier momento.\n" \
          "\n>>> Installation completed. You can now run 'omv-regen' at any time.\n"
else
    echoe ">>> ERROR: Fallo descargando omv-regen desde $URL_OMVREGEN/$SCRIPT." \
          ">>> ERROR: Failed to download omv-regen from $URL_OMVREGEN/$SCRIPT."
    mv "$OR_script_file"Old "$OR_script_file" 2>/dev/null || true
    exit 1
fi
exit 0
