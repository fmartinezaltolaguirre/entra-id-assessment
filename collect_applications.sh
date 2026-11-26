#!/bin/bash

set -e

OUTDIR="./output"

mkdir -p "$OUTDIR"

echo "[INFO] Exportando aplicaciones..."

az ad app list --all > "$OUTDIR/applications.json"

TOTAL=$(jq length "$OUTDIR/applications.json")

echo "[OK] Aplicaciones exportadas: $TOTAL"
echo "[OK] Fichero: $OUTDIR/applications.json"
