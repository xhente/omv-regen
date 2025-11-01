#!/bin/bash
# -*- ENCODING: UTF-8 -*-

# This file is licensed under the terms of the GNU General Public
# License version 3. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

# omv-regen
# Utilidad de copia de seguridad y restauración de la configuración de OpenMediaVault
# OpenMediaVault configuration backup and restore utility

set -e

##################################################
# omv-regen_install.sh
##################################################
# Instalador dinámico para seleccionar la versión correcta de omv-regen
# Detecta Debian/OMV y descarga la versión según corresponda
##################################################
# Dynamic installer to select the correct omv-regen version
# Detects Debian/OMV and downloads the corresponding version
##################################################




##################################################
# VERSION EN DESARROLLO
##################################################
# VERSION UNDER DEVELOPMENT
##################################################




Logo_omvregen="\
\n┌───────────────┐                                         \
\n│               │     ┌────────────┐     ┌──────────────┐ \
\n│   omv-regen   │ >>> │   backup   │ >>> │   regenera   │ \
\n│               │     └────────────┘     └──────────────┘ \
\n└───────────────┘                                         "

# Variables
OR_script_file="/usr/local/bin/omv-regen"
URL_BASE="https://raw.githubusercontent.com/xhente/omv-regen/master"
Apt_updated=0
# shellcheck disable=SC2016
DEBIAN_CODENAME__or=$(env -i bash -c '. /etc/os-release; echo $VERSION_CODENAME')
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
        SCRIPT_NAME="omv-regen_7x.sh"
        ;;
    trixie)
        SCRIPT_NAME="omv-regen_8x.sh"
        ;;
    *)
        echoe ">>> Versión no soportada: ${DEBIAN_CODENAME__or}.   Solo está soportado Debian 11, Debian 12 y Debian 13.  Saliendo ..." \
              ">>> Unsupported version: ${DEBIAN_CODENAME__or}.   Only Debian 11, Debian 12 and Debian 13 are supported.  Exiting ..."
        exit 1
        ;;
esac

# Instalar dependencias necesarias
# Install necessary dependencies
InstalarPaquete dialog
InstalarPaquete wget

# Descargar e instalar
# Download and install
URL="$URL_BASE/$SCRIPT_NAME"
echoe ">>> Instalando omv-regen desde $URL ..." \
      ">>> Installing omv-regen from $URL ..."

[ -f "$OR_script_file" ] && rm -f "$OR_script_file"

if wget -q -O - "$URL" >"$OR_script_file"; then
    grep -q "omv-regen" "$OR_script_file" || {
        echoe ">>> ERROR: Archivo descargado inválido o corrupto." \
              ">>> ERROR: Invalid or corrupted file downloaded."
        rm -f "$OR_script_file"
        exit 1
    }
    chmod +x "$OR_script_file"
    echoe ">>> omv-regen se ha instalado correctamente." \
          ">>> omv-regen has been successfully installed."
    echoe ">>> Iniciando omv-regen ..." \
          ">>> Starting omv-regen ..."
    sleep 2
    exec bash "$OR_script_file" reset
else
    echoe ">>> ERROR: Fallo descargando omv-regen desde $URL." \
          ">>> ERROR: Failed to download omv-regen from $URL."
    exit 1
fi
