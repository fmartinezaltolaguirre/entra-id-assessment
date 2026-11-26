#!/bin/bash

set -euo pipefail

OUTDIR="./output"

PERMISSIONS_FILE="${OUTDIR}/permissions.json"
CATALOG_FILE="${OUTDIR}/permission_catalog.json"
OUTPUT_FILE="${OUTDIR}/permissions_enriched.json"

echo
echo "========================================="
echo " ENTRA ID - ENRIQUECIMIENTO DE PERMISOS"
echo "========================================="
echo

if [ ! -f "${PERMISSIONS_FILE}" ]; then
    echo "[ERROR] No existe ${PERMISSIONS_FILE}"
    exit 1
fi

if [ ! -f "${CATALOG_FILE}" ]; then
    echo "[ERROR] No existe ${CATALOG_FILE}"
    exit 1
fi

echo "[INFO] Permisos originales..."

TOTAL=$(jq length "${PERMISSIONS_FILE}")

echo "[INFO] Registros: ${TOTAL}"

jq \
    --slurpfile catalog "${CATALOG_FILE}" '
    map(
        . as $perm
        |
        (
            $catalog[0]
            |
            map(
                select(
                    .PermissionId == $perm.PermissionId
                )
            )
            |
            first
        ) as $match
        |
        $perm +
        {
            PermissionName:
                ($match.PermissionName // "UNKNOWN"),

            DisplayName:
                ($match.DisplayName // "UNKNOWN"),

            Description:
                ($match.Description // "UNKNOWN"),

            AdminConsentRequired:
                ($match.AdminConsentRequired // false),

            RiskCategory:
            (
                if (
                    ($match.PermissionName // "")
                    |
                    test(
                        "Directory.ReadWrite.All|RoleManagement.ReadWrite.Directory|Application.ReadWrite.All|AppRoleAssignment.ReadWrite.All"
                    )
                )
                then "CRITICAL"

                elif (
                    ($match.PermissionName // "")
                    |
                    test(
                        "Directory.Read.All|AuditLog.Read.All|Group.Read.All|User.Read.All"
                    )
                )
                then "HIGH"

                elif (
                    ($match.PermissionType // "") == "Role"
                )
                then "MEDIUM"

                else "LOW"
                end
            )
        }
    )
    ' \
    "${PERMISSIONS_FILE}" \
    > "${OUTPUT_FILE}"

echo
echo "[INFO] Resumen de criticidad"

jq '
group_by(.RiskCategory)
|
map(
    {
        Risk: .[0].RiskCategory,
        Count: length
    }
)
' "${OUTPUT_FILE}"

echo

CRITICAL=$(jq '[.[] | select(.RiskCategory=="CRITICAL")] | length' "${OUTPUT_FILE}")

HIGH=$(jq '[.[] | select(.RiskCategory=="HIGH")] | length' "${OUTPUT_FILE}")

MEDIUM=$(jq '[.[] | select(.RiskCategory=="MEDIUM")] | length' "${OUTPUT_FILE}")

LOW=$(jq '[.[] | select(.RiskCategory=="LOW")] | length' "${OUTPUT_FILE}")

echo "========================================="
echo " RESUMEN"
echo "========================================="
echo "[OK] CRITICAL : ${CRITICAL}"
echo "[OK] HIGH     : ${HIGH}"
echo "[OK] MEDIUM   : ${MEDIUM}"
echo "[OK] LOW      : ${LOW}"
echo "[OK] Fichero  : ${OUTPUT_FILE}"
echo
