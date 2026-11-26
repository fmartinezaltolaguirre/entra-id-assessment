#!/bin/bash

set -Eeuo pipefail

OUTDIR="${OUTDIR:-./output}"
SUBSCRIPTION=""
DRY_RUN=false

usage() {
    cat <<'EOF'
Uso: ./run_assessment.sh [opciones]

Opciones:
  --output-dir DIR       Directorio de salida (predeterminado: ./output)
  --subscription NAME    Suscripción de Azure que se debe seleccionar
  --dry-run              Ejecuta comprobaciones sin recopilar datos
  -h, --help             Muestra esta ayuda
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)
            OUTDIR="$2"
            shift 2
            ;;
        --subscription)
            SUBSCRIPTION="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "[ERROR] Opción desconocida: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

for command_name in az jq python3; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "[ERROR] Falta la dependencia requerida: $command_name" >&2
        exit 1
    fi
done

if ! az account show >/dev/null 2>&1; then
    echo "[ERROR] Inicie sesión con 'az login' antes de ejecutar la evaluación." >&2
    exit 1
fi

if [[ -n "$SUBSCRIPTION" ]]; then
    az account set --subscription "$SUBSCRIPTION"
fi

TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)

mkdir -p "$OUTDIR"

printf '[INFO] Tenant: %s\n' "$TENANT_ID"
printf '[INFO] Subscription: %s\n' "$SUBSCRIPTION_NAME"
printf '[INFO] Output: %s\n' "$OUTDIR"

if [[ "$DRY_RUN" == true ]]; then
    echo '[OK] Comprobaciones completadas. No se recopilaron datos.'
    exit 0
fi

scripts=(
    collect_applications.sh
    collect_enterprise_apps.sh
    collect_owners.sh
    collect_secrets.sh
    collect_certificates.sh
    collect_permissions.sh
    collect_permission_catalog.sh
    enrich_permissions.sh
    collect_redirect_uris.sh
    generate_findings.sh
)

for script in "${scripts[@]}"; do
    if [[ ! -f "$(dirname "$0")/$script" ]]; then
        echo "[ERROR] No se encontró $(dirname "$0")/$script" >&2
        exit 1
    fi

    echo "[RUN] $script"
    OUTDIR="$OUTDIR" "$(dirname "$0")/$script"
done

OUTDIR="$OUTDIR" python3 "$(dirname "$0")/build_excel.py"

printf '[OK] Evaluación completada. Informe: %s/EntraID_Application_Assessment.xlsx\n' "$OUTDIR"
