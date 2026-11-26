#!/bin/bash

set -Eeuo pipefail

OUTDIR="${OUTDIR:-./output}"
mkdir -p "$OUTDIR"

if ! command -v az >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    echo '[ERROR] Se requieren Azure CLI y jq.' >&2
    exit 1
fi

if ! az account show >/dev/null 2>&1; then
    echo '[ERROR] No hay una sesión Azure activa.' >&2
    exit 1
fi

TMP_FILE=$(mktemp "${OUTDIR}/applications.XXXXXX.json")
trap 'rm -f "$TMP_FILE"' EXIT

TMP_FILE="$TMP_FILE" az ad app list --all \
    | jq 'if type == "array" then . else error("La respuesta no es un array") end' \
    > "$TMP_FILE"

mv "$TMP_FILE" "$OUTDIR/applications.json"
trap - EXIT

TOTAL=$(jq 'length' "$OUTDIR/applications.json")

echo '[INFO] Exportando aplicaciones...'
echo "[OK] Aplicaciones exportadas: $TOTAL"
echo "[OK] Fichero: $OUTDIR/applications.json"
