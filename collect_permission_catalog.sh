#!/bin/bash

set -euo pipefail

OUTDIR="./output"

CATALOG_FILE="${OUTDIR}/permission_catalog.json"

echo
echo "========================================="
echo " ENTRA ID - CATÁLOGO DE PERMISOS"
echo "========================================="
echo

echo "[INFO] Buscando Service Principal de Microsoft Graph..."

GRAPH_SP_ID=$(
az ad sp list \
    --filter "appId eq '00000003-0000-0000-c000-000000000000'" \
    --query "[0].id" \
    -o tsv
)

if [ -z "${GRAPH_SP_ID}" ]; then
    echo "[ERROR] No se encontró Microsoft Graph"
    exit 1
fi

echo "[INFO] Service Principal ID: ${GRAPH_SP_ID}"

echo
echo "[INFO] Descargando definición de permisos..."

az rest \
  --method GET \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals/${GRAPH_SP_ID}" \
  > /tmp/graph_sp.json

echo
echo "[INFO] Extrayendo App Roles..."

jq '
[
  .appRoles[]?
  |
  {
    PermissionId: .id,
    PermissionName: .value,
    DisplayName: .displayName,
    Description: .description,
    PermissionType: "Role",
    AdminConsentRequired: true
  }
]
' /tmp/graph_sp.json \
> /tmp/app_roles.json

APP_ROLES=$(jq length /tmp/app_roles.json)

echo "[INFO] App Roles encontrados: ${APP_ROLES}"

echo
echo "[INFO] Extrayendo OAuth2 Scopes..."

jq '
[
  .oauth2PermissionScopes[]?
  |
  {
    PermissionId: .id,
    PermissionName: .value,
    DisplayName: .adminConsentDisplayName,
    Description: .adminConsentDescription,
    PermissionType: "Scope",
    AdminConsentRequired: (
      .type == "Admin"
    )
  }
]
' /tmp/graph_sp.json \
> /tmp/oauth_scopes.json

SCOPES=$(jq length /tmp/oauth_scopes.json)

echo "[INFO] OAuth Scopes encontrados: ${SCOPES}"

echo
echo "[INFO] Construyendo catálogo unificado..."

jq -s 'add' \
    /tmp/app_roles.json \
    /tmp/oauth_scopes.json \
    > "${CATALOG_FILE}"
TOTAL=$(jq length "${CATALOG_FILE}")

echo
echo "========================================="
echo " RESUMEN"
echo "========================================="
echo "[OK] Permisos catalogados : ${TOTAL}"
echo "[OK] App Roles           : ${APP_ROLES}"
echo "[OK] OAuth Scopes        : ${SCOPES}"
echo "[OK] Fichero             : ${CATALOG_FILE}"
echo
