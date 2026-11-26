#!/bin/bash

set -e

OUTDIR="./output"

mkdir -p "${OUTDIR}"

echo "[+] Obteniendo Tenant ID..."

TENANT_ID=$(az account show --query tenantId -o tsv)

echo "[+] Tenant: ${TENANT_ID}"

echo "[+] Obteniendo aplicaciones..."

az ad app list --all > "${OUTDIR}/applications_raw.json"

echo "[+] Generando inventario..."

jq --arg tenant "${TENANT_ID}" '
[
 .[] |
 {
   DisplayName: .displayName,
   ApplicationId: .appId,
   ObjectId: .id,
   TenantId: $tenant,
   CreatedDateTime: .createdDateTime,
   SignInAudience: .signInAudience,
   PublisherDomain: .publisherDomain
 }
]
' "${OUTDIR}/applications_raw.json" \
> "${OUTDIR}/applications_inventory.json"

echo "[+] Inventario generado:"
echo "    ${OUTDIR}/applications_inventory.json"
