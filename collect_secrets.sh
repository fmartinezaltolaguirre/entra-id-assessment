#!/bin/bash

set -euo pipefail

OUTDIR="./output"

APPS_FILE="${OUTDIR}/applications.json"
SECRETS_FILE="${OUTDIR}/secrets.json"

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
echo " ENTRA ID - RECOLECCIÓN DE SECRETOS"
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
          .passwordCredentials[]? |
          {
            ApplicationName: $app,
            ApplicationId: $appid,
            ApplicationObjectId: $objectid,
            SecretName: (.displayName // ""),
            KeyId: (.keyId // ""),
            StartDate: (.startDateTime // ""),
            EndDate: (.endDateTime // "")
          }
        ]
        ' \
        > /tmp/secrets_part.json

    jq -s 'add' \
        "${TMP}" \
        /tmp/secrets_part.json \
        > /tmp/secrets_merge.json

    mv /tmp/secrets_merge.json "${TMP}"

done

cp "${TMP}" "${SECRETS_FILE}"

echo
echo "[INFO] Calculando expiraciones..."

jq '
map(
  . as $s
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
  $s + {
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
' "${SECRETS_FILE}" \
> /tmp/secrets_final.json

mv /tmp/secrets_final.json "${SECRETS_FILE}"

TOTAL_SECRETS=$(jq length "${SECRETS_FILE}")

ACTIVE=$(jq '[.[] | select(.Status=="ACTIVE")] | length' "${SECRETS_FILE}")

EXPIRING=$(jq '[.[] | select(.Status=="EXPIRING_SOON")] | length' "${SECRETS_FILE}")

WARNING=$(jq '[.[] | select(.Status=="WARNING")] | length' "${SECRETS_FILE}")

EXPIRED=$(jq '[.[] | select(.Status=="EXPIRED")] | length' "${SECRETS_FILE}")

echo
echo "========================================="
echo " RESUMEN"
echo "========================================="
echo "[OK] Secretos encontrados : ${TOTAL_SECRETS}"
echo "[OK] Activos             : ${ACTIVE}"
echo "[OK] < 90 días           : ${EXPIRING}"
echo "[OK] < 30 días           : ${WARNING}"
echo "[OK] Expirados           : ${EXPIRED}"
echo "[OK] Fichero             : ${SECRETS_FILE}"
echo
