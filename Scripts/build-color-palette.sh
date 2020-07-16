#!/bin/sh -eu

#
#  build-color-palette.sh
#  LoopKit
#
#  Copyright © 2020 LoopKit Authors. All rights reserved.
#

SCRIPT="$(basename "${0}")"

error() {
  echo "ERROR: ${*}" >&2
  echo "Usage: ${SCRIPT} <directory>" >&2
  echo "Parameters:" >&2
  echo "  <directory>  directory with color palette " >&2
  exit 1
}

info() {
  echo "INFO: ${*}" >&2
}

if [ ${#} -lt 1 ]; then
  error "Missing arguments"
fi

DIRECTORY="${1}"
shift 1

if [ ${#} -ne 0 ]; then
  error "Unexpected arguments: ${*}"
fi

if [ ! -d "${DIRECTORY}" ]; then 
    error "Directory '${DIRECTORY}' does not exist"
fi

COLOR_PALETTE_DERIVED="${DIRECTORY}/ColorPaletteDerived.xcassets"
COLOR_PALETTE_BASE="${DIRECTORY}/ColorPaletteBase.xcassets"
COLOR_PALETTE_OVERRIDE="${DIRECTORY}/ColorPaletteOverride.xcassets"

info "Building color palette for ${DIRECTORY}..."
rm -rf "${COLOR_PALETTE_DERIVED}"

info "Copying color palette base to the derived color palette..."
cp -av "${COLOR_PALETTE_BASE}" "${COLOR_PALETTE_DERIVED}"

if [ -e "${COLOR_PALETTE_OVERRIDE}" ]; then
  info "Copying color palette override to color palette..."
  for ASSET_PATH in "${COLOR_PALETTE_OVERRIDE}"/*; do
    ASSET_FILE="$(basename "${ASSET_PATH}")"
    rm -rf "${COLOR_PALETTE_DERIVED}/${ASSET_FILE}"
    cp -av "${ASSET_PATH}" "${COLOR_PALETTE_DERIVED}/${ASSET_FILE}"
  done
fi
