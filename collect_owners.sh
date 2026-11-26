#!/bin/bash

set -euo pipefail

OUTDIR="./output"
APPS_FILE="${OUTDIR}/applications.json"
OWNERS_FILE="${OUTDIR}/owners.json"

if [ ! -f "${APPS_FILE}" ]; then
    echo "[ERROR] No existe ${APPS_FILE}"
    exit 1
fi

TMP=$(mktemp)

echo "[]" > "${TMP}"

TOTAL=$(jq length "${APPS_FILE}")

echo
echo "========================================="
echo " ENTRA ID - RECOLECCIÓN DE PROPIETARIOS "
echo "========================================="
echo
echo "[INFO] Aplicaciones encontradas: ${TOTAL}"
echo

CURRENT=0

jq -c '.[]' "${APPS_FILE}" |
while read -r APP
do

    CURRENT=$((CURRENT + 1))

    APP_NAME=$(echo "${APP}" | jq -r '.displayName // "UNKNOWN"')
    APP_OBJECT_ID=$(echo "${APP}" | jq -r '.id')
    APP_ID=$(echo "${APP}" | jq -r '.appId')

    printf "[%03d/%03d] %s\n" \
        "${CURRENT}" \
        "${TOTAL}" \
        "${APP_NAME}"

    RESPONSE=$(az rest \
        --method GET \
        --url "https://graph.microsoft.com/v1.0/applications/${APP_OBJECT_ID}/owners" \
        2>/dev/null || echo '{"value":[]}')

    echo "${RESPONSE}" |
    jq \
        --arg app "${APP_NAME}" \
        --arg appid "${APP_ID}" \
        --arg objectid "${APP_OBJECT_ID}" '
        [
            .value[]? |
            {
                ApplicationName: $app,
                ApplicationId: $appid,
                ApplicationObjectId: $objectid,
                OwnerId: .id,
                OwnerName: .displayName,
                UserPrincipalName: (
                    .userPrincipalName // ""
                ),
                Mail: (
                    .mail // ""
                ),
                OwnerType: (
                    ."@odata.type" // ""
                )
            }
        ]
    ' > /tmp/owners_part.json

    jq -s 'add' \
        "${TMP}" \
        /tmp/owners_part.json \
        > /tmp/owners_merge.json

    mv /tmp/owners_merge.json "${TMP}"

done

cp "${TMP}" "${OWNERS_FILE}"

TOTAL_OWNERS=$(jq length "${OWNERS_FILE}")

echo
echo "========================================="
echo " RESUMEN "
echo "========================================="
echo "[OK] owners.json generado"
echo "[OK] Registros de propietarios: ${TOTAL_OWNERS}"
echo "[OK] Fichero: ${OWNERS_FILE}"
echo
