#!/bin/bash

set -euo pipefail

OUTDIR="./output"

APPS_FILE="${OUTDIR}/applications.json"
REDIRECTS_FILE="${OUTDIR}/redirect_uris.json"

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
echo " ENTRA ID - RECOLECCIÓN DE REDIRECT URIS"
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

        (.web.redirectUris[]? |
          {
            ApplicationName: $app,
            ApplicationId: $appid,
            ApplicationObjectId: $objectid,
            Type: "Web",
            RedirectUri: .
          }
        ),

        (.spa.redirectUris[]? |
          {
            ApplicationName: $app,
            ApplicationId: $appid,
            ApplicationObjectId: $objectid,
            Type: "SPA",
            RedirectUri: .
          }
        ),

        (.publicClient.redirectUris[]? |
          {
            ApplicationName: $app,
            ApplicationId: $appid,
            ApplicationObjectId: $objectid,
            Type: "PublicClient",
            RedirectUri: .
          }
        )

      ]
      ' > /tmp/redirect_part.json

    jq -s 'add' \
      "${TMP}" \
      /tmp/redirect_part.json \
      > /tmp/redirect_merge.json

    mv /tmp/redirect_merge.json "${TMP}"

done

cp "${TMP}" "${REDIRECTS_FILE}"

echo
echo "[INFO] Analizando riesgos..."

jq '
map(
  . +
  {
    Risk:
      (
        if (.RedirectUri | test("^http://"))
        then "HIGH"

        elif (.RedirectUri | test("localhost"))
        then "MEDIUM"

        elif (.RedirectUri | test("\\*"))
        then "HIGH"

        elif (
            (.RedirectUri | test("enaire\\.es")) |
            not
        )
        then "MEDIUM"

        else
          "LOW"
        end
      )
  }
)
' "${REDIRECTS_FILE}" \
> /tmp/redirect_final.json

mv /tmp/redirect_final.json "${REDIRECTS_FILE}"

TOTAL_REDIRECTS=$(jq length "${REDIRECTS_FILE}")

HIGH=$(jq '[.[] | select(.Risk=="HIGH")] | length' "${REDIRECTS_FILE}")

MEDIUM=$(jq '[.[] | select(.Risk=="MEDIUM")] | length' "${REDIRECTS_FILE}")

LOW=$(jq '[.[] | select(.Risk=="LOW")] | length' "${REDIRECTS_FILE}")

echo
echo "========================================="
echo " RESUMEN"
echo "========================================="
echo "[OK] Redirect URIs : ${TOTAL_REDIRECTS}"
echo "[OK] Riesgo HIGH   : ${HIGH}"
echo "[OK] Riesgo MEDIUM : ${MEDIUM}"
echo "[OK] Riesgo LOW    : ${LOW}"
echo "[OK] Fichero       : ${REDIRECTS_FILE}"
echo
