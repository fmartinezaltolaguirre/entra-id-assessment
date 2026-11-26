#!/bin/bash

set -euo pipefail

OUTDIR="./output"

SP_FILE="${OUTDIR}/enterprise_apps.json"

echo
echo "========================================="
echo " ENTRA ID - ENTERPRISE APPLICATIONS"
echo "========================================="
echo

echo "[INFO] Obteniendo Service Principals..."

az ad sp list --all > /tmp/service_principals.json

TOTAL=$(jq length /tmp/service_principals.json)

echo "[INFO] Service Principals encontrados: ${TOTAL}"

echo
echo "[INFO] Transformando información..."

jq '
[
 .[]
 |
 {
   DisplayName: (.displayName // ""),
   ServicePrincipalId: (.id // ""),
   ApplicationId: (.appId // ""),
   ServicePrincipalType: (.servicePrincipalType // ""),
   AccountEnabled: (.accountEnabled // false),
   PublisherName: (.publisherName // ""),
   AppOwnerOrganizationId: (.appOwnerOrganizationId // ""),
   PreferredSingleSignOnMode: (.preferredSingleSignOnMode // ""),
   Homepage: (.homepage // ""),
   ReplyUrls: (.replyUrls // []),
   Tags: (.tags // [])
 }
]
' /tmp/service_principals.json \
> "${SP_FILE}"

echo
echo "[INFO] Generando estadísticas..."

ENABLED=$(jq '[.[] | select(.AccountEnabled == true)] | length' "${SP_FILE}")

DISABLED=$(jq '[.[] | select(.AccountEnabled == false)] | length' "${SP_FILE}")

SAML=$(jq '[.[] | select(.PreferredSingleSignOnMode == "saml")] | length' "${SP_FILE}")

OIDC=$(jq '[.[] | select(.PreferredSingleSignOnMode == "oidc")] | length' "${SP_FILE}")

echo
echo "========================================="
echo " RESUMEN"
echo "========================================="
echo "[OK] Enterprise Applications : ${TOTAL}"
echo "[OK] Habilitadas            : ${ENABLED}"
echo "[OK] Deshabilitadas         : ${DISABLED}"
echo "[OK] SAML                   : ${SAML}"
echo "[OK] OIDC                   : ${OIDC}"
echo "[OK] Fichero                : ${SP_FILE}"
echo

