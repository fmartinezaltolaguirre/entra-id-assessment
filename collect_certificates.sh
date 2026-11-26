#!/bin/bash

set -euo pipefail

OUTDIR="./output"

APPS_FILE="${OUTDIR}/applications.json"
CERTS_FILE="${OUTDIR}/certificates.json"

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
echo " ENTRA ID - RECOLECCIÓN DE CERTIFICADOS"
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
        --arg app "${APP_NAME}" \
        --arg appid "${APP_ID}" \
        --arg objectid "${APP_OBJECT_ID}" '
        [
          .keyCredentials[]? |
          {
            ApplicationName: $app,
            ApplicationId: $appid,
            ApplicationObjectId: $objectid,
            KeyId: (.keyId // ""),
            DisplayName: (.displayName // ""),
            Type: (.type // ""),
            Usage: (.usage // ""),
            StartDate: (.startDateTime // ""),
            EndDate: (.endDateTime // "")
          }
        ]
        ' \
        > /tmp/certs_part.json

    jq -s 'add' \
        "${TMP}" \
        /tmp/certs_part.json \
        > /tmp/certs_merge.json

    mv /tmp/certs_merge.json "${TMP}"

done

cp "${TMP}" "${CERTS_FILE}"

echo
echo "[INFO] Calculando expiraciones..."

jq '
map(
  . as $c
  |
  (
    (
      (
        .EndDate
        | sub("\\.[0-9]+Z$"; "Z")
        | fromdateiso8601
      )
      -
      now
    ) / 86400
  ) | floor as $days
  |
  $c + {
      DaysRemaining: $days,
      Status:
      (
        if $days < 0 then
          "EXPIRED"
        elif $days < 30 then
          "WARNING"
        elif $days < 90 then
          "EXPIRING_SOON"
        else
          "ACTIVE"
        end
      )
    }
)
' "${CERTS_FILE}" \
> /tmp/certs_final.json

mv /tmp/certs_final.json "${CERTS_FILE}"

TOTAL_CERTS=$(jq length "${CERTS_FILE}")

ACTIVE=$(jq '[.[] | select(.Status=="ACTIVE")] | length' "${CERTS_FILE}")

EXPIRING=$(jq '[.[] | select(.Status=="EXPIRING_SOON")] | length' "${CERTS_FILE}")

WARNING=$(jq '[.[] | select(.Status=="WARNING")] | length' "${CERTS_FILE}")

EXPIRED=$(jq '[.[] | select(.Status=="EXPIRED")] | length' "${CERTS_FILE}")

echo
echo "========================================="
echo " RESUMEN"
echo "========================================="
echo "[OK] Certificados encontrados : ${TOTAL_CERTS}"
echo "[OK] Activos                 : ${ACTIVE}"
echo "[OK] < 90 días               : ${EXPIRING}"
echo "[OK] < 30 días               : ${WARNING}"
echo "[OK] Expirados               : ${EXPIRED}"
echo "[OK] Fichero                 : ${CERTS_FILE}"
echo
