#!/bin/bash

set -euo pipefail

OUTDIR="./output"

APPS_FILE="${OUTDIR}/applications.json"
PERMISSIONS_FILE="${OUTDIR}/permissions.json"

if [ ! -f "${APPS_FILE}" ]; then
    echo "[ERROR] No existe ${APPS_FILE}"
    exit 1
fi

TMP=$(mktemp)

echo "[]" > "${TMP}"

TOTAL=$(jq length "${APPS_FILE}")

CURRENT=0

echo
echo "========================================="
echo " ENTRA ID - RECOLECCIÓN DE PERMISOS API"
echo "========================================="
echo
echo "[INFO] Aplicaciones encontradas: ${TOTAL}"
echo

jq -c '.[]' "${APPS_FILE}" |
while read -r APP
do

    CURRENT=$((CURRENT + 1))

    APP_NAME=$(echo "${APP}" | jq -r '.displayName // "UNKNOWN"')
    APP_ID=$(echo "${APP}" | jq -r '.appId')
    APP_OBJECT_ID=$(echo "${APP}" | jq -r '.id')

    printf "[%03d/%03d] %s\n" \
        "${CURRENT}" \
        "${TOTAL}" \
        "${APP_NAME}"

    echo "${APP}" |
    jq \
        --arg app "$APP_NAME" \
        --arg appid "$APP_ID" \
        --arg objectid "$APP_OBJECT_ID" '
        [
          .requiredResourceAccess[]? as $resource
          |
          $resource.resourceAccess[]?
          |
          {
            ApplicationName: $app,
            ApplicationId: $appid,
            ApplicationObjectId: $objectid,
            ResourceAppId: $resource.resourceAppId,
            PermissionId: .id,
            PermissionType: .type
          }
        ]
        ' \
        > /tmp/permissions_part.json

    jq -s 'add' \
        "${TMP}" \
        /tmp/permissions_part.json \
        > /tmp/permissions_merge.json

    mv /tmp/permissions_merge.json "${TMP}"

done

cp "${TMP}" "${PERMISSIONS_FILE}"

echo
echo "[INFO] Clasificando riesgos..."

jq '
map(
    . +
    {
      RiskLevel:
      (
        if .PermissionType == "Role"
        then "HIGH"
        elif .PermissionType == "Scope"
        then "MEDIUM"
        else "UNKNOWN"
        end
      )
    }
)
' "${PERMISSIONS_FILE}" \
> /tmp/permissions_final.json

mv /tmp/permissions_final.json "${PERMISSIONS_FILE}"

TOTAL_PERMISSIONS=$(jq length "${PERMISSIONS_FILE}")

HIGH=$(jq '[.[] | select(.RiskLevel=="HIGH")] | length' "${PERMISSIONS_FILE}")

MEDIUM=$(jq '[.[] | select(.RiskLevel=="MEDIUM")] | length' "${PERMISSIONS_FILE}")

echo
echo "========================================="
echo " RESUMEN"
echo "========================================="
echo "[OK] Permisos encontrados : ${TOTAL_PERMISSIONS}"
echo "[OK] Riesgo HIGH         : ${HIGH}"
echo "[OK] Riesgo MEDIUM       : ${MEDIUM}"
echo "[OK] Fichero             : ${PERMISSIONS_FILE}"
echo

