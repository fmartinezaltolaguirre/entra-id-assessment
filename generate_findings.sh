#!/bin/bash

set -euo pipefail

OUTDIR="./output"

APPLICATIONS="${OUTDIR}/applications.json"
OWNERS="${OUTDIR}/owners.json"
SECRETS="${OUTDIR}/secrets.json"
CERTIFICATES="${OUTDIR}/certificates.json"
PERMISSIONS="${OUTDIR}/permissions_enriched.json"
REDIRECTS="${OUTDIR}/redirect_uris.json"
ENTERPRISE="${OUTDIR}/enterprise_apps.json"

FINDINGS="${OUTDIR}/findings.json"

echo
echo "========================================="
echo " ENTRA ID - FINDINGS ENGINE"
echo "========================================="
echo

echo "[]" > "${FINDINGS}"

TMP=$(mktemp)

echo "[]" > "${TMP}"

##################################################
# Aplicaciones sin Owner
##################################################

echo "[INFO] Analizando aplicaciones sin propietario..."

jq -r '.[].id' "${APPLICATIONS}" | while read -r APP_ID
do

    HAS_OWNER=$(
        jq \
            --arg id "${APP_ID}" \
            '[ .[] | select(.ApplicationObjectId==$id) ] | length' \
            "${OWNERS}"
    )

    if [ "${HAS_OWNER}" -eq 0 ]; then

        APP_NAME=$(
            jq -r \
            --arg id "${APP_ID}" \
            '.[] | select(.id==$id) | .displayName' \
            "${APPLICATIONS}"
        )

        jq -n \
          --arg app "${APP_NAME}" \
          '{
             Severity:"HIGH",
             Category:"Governance",
             Application:$app,
             Finding:"Application without owner"
           }' \
           > /tmp/finding.json

        jq -s 'add' \
            "${TMP}" \
            <(jq -s '.' /tmp/finding.json) \
            > /tmp/findings_merge.json

        mv /tmp/findings_merge.json "${TMP}"
    fi

done

##################################################
# Secretos expirados
##################################################

echo "[INFO] Analizando secretos..."

jq '
.[]
| select(.Status=="EXPIRED")
| {
    Severity:"CRITICAL",
    Category:"Secrets",
    Application:.ApplicationName,
    Finding:"Expired secret"
  }
' "${SECRETS}" |
jq -s '.' > /tmp/secrets_findings.json

jq -s 'add' \
    "${TMP}" \
    /tmp/secrets_findings.json \
    > /tmp/findings_merge.json

mv /tmp/findings_merge.json "${TMP}"

##################################################
# Secretos próximos a expirar
##################################################

jq '
.[]
| select(.Status=="EXPIRING_SOON")
| {
    Severity:"HIGH",
    Category:"Secrets",
    Application:.ApplicationName,
    Finding:"Secret expires within 90 days"
  }
' "${SECRETS}" |
jq -s '.' > /tmp/secrets_warning.json

jq -s 'add' \
    "${TMP}" \
    /tmp/secrets_warning.json \
    > /tmp/findings_merge.json

mv /tmp/findings_merge.json "${TMP}"

##################################################
# Certificados próximos a expirar
##################################################

echo "[INFO] Analizando certificados..."

jq '
.[]
| select(.Status=="EXPIRING_SOON")
| {
    Severity:"HIGH",
    Category:"Certificates",
    Application:.ApplicationName,
    Finding:"Certificate expires within 90 days"
  }
' "${CERTIFICATES}" |
jq -s '.' > /tmp/cert_findings.json

jq -s 'add' \
    "${TMP}" \
    /tmp/cert_findings.json \
    > /tmp/findings_merge.json

mv /tmp/findings_merge.json "${TMP}"

##################################################
# Redirect URI de riesgo alto
##################################################

echo "[INFO] Analizando Redirect URIs..."

jq '
.[]
| select(.Risk=="HIGH")
| {
    Severity:"HIGH",
    Category:"RedirectUri",
    Application:.ApplicationName,
    Finding:( "Risky Redirect URI: " + .RedirectUri )
  }
' "${REDIRECTS}" |
jq -s '.' > /tmp/redirect_findings.json

jq -s 'add' \
    "${TMP}" \
    /tmp/redirect_findings.json \
    > /tmp/findings_merge.json

mv /tmp/findings_merge.json "${TMP}"

##################################################
# Permisos críticos
##################################################

echo "[INFO] Analizando permisos críticos..."

jq '
.[]
| select(.RiskCategory=="CRITICAL")
| {
    Severity:"CRITICAL",
    Category:"Permissions",
    Application:.ApplicationName,
    Finding:( "Critical permission: " + .PermissionName )
  }
' "${PERMISSIONS}" |
jq -s '.' > /tmp/perm_critical.json

jq -s 'add' \
    "${TMP}" \
    /tmp/perm_critical.json \
    > /tmp/findings_merge.json

mv /tmp/findings_merge.json "${TMP}"

##################################################
# Enterprise Apps deshabilitadas
##################################################

echo "[INFO] Analizando Enterprise Apps..."

jq '
.[]
| select(.AccountEnabled == false)
| {
    Severity:"MEDIUM",
    Category:"EnterpriseApp",
    Application:.DisplayName,
    Finding:"Disabled Enterprise Application"
  }
' "${ENTERPRISE}" |
jq -s '.' > /tmp/enterprise_findings.json

jq -s 'add' \
    "${TMP}" \
    /tmp/enterprise_findings.json \
    > /tmp/findings_merge.json

mv /tmp/findings_merge.json "${TMP}"

##################################################
# Guardado
##################################################

cp "${TMP}" "${FINDINGS}"

TOTAL=$(jq length "${FINDINGS}")

CRITICAL=$(jq '[.[] | select(.Severity=="CRITICAL")] | length' "${FINDINGS}")

HIGH=$(jq '[.[] | select(.Severity=="HIGH")] | length' "${FINDINGS}")

MEDIUM=$(jq '[.[] | select(.Severity=="MEDIUM")] | length' "${FINDINGS}")

echo
echo "========================================="
echo " RESUMEN"
echo "========================================="
echo "[OK] Findings totales : ${TOTAL}"
echo "[OK] CRITICAL         : ${CRITICAL}"
echo "[OK] HIGH             : ${HIGH}"
echo "[OK] MEDIUM           : ${MEDIUM}"
echo "[OK] Fichero          : ${FINDINGS}"
echo
