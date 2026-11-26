#!/bin/bash

set -Eeuo pipefail

OUTDIR="${OUTDIR:-./output}"
APPS_FILE="$OUTDIR/applications.json"
PERMISSIONS_FILE="$OUTDIR/permissions.json"

if [[ ! -f "$APPS_FILE" ]]; then
    echo "[ERROR] No existe $APPS_FILE" >&2
    exit 1
fi

jq -e 'type == "array"' "$APPS_FILE" >/dev/null

TMP_FILE=$(mktemp "$OUTDIR/permissions.XXXXXX.json")
trap 'rm -f "$TMP_FILE"' EXIT

jq '
[
  .[]
  | . as $app
  | ($app.displayName // "UNKNOWN") as $name
  | ($app.appId // "") as $app_id
  | ($app.id // "") as $object_id
  | .requiredResourceAccess[]?
  | . as $resource
  | $resource.resourceAccess[]?
  | {
      ApplicationName: $name,
      ApplicationId: $app_id,
      ApplicationObjectId: $object_id,
      ResourceAppId: ($resource.resourceAppId // ""),
      PermissionId: (.id // ""),
      PermissionType: (.type // "UNKNOWN")
    }
]
| map(. + {
    RiskLevel: (
      if .PermissionType == "Role" then "HIGH"
      elif .PermissionType == "Scope" then "MEDIUM"
      else "UNKNOWN"
      end
    )
  })
' "$APPS_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$PERMISSIONS_FILE"
trap - EXIT

TOTAL_PERMISSIONS=$(jq 'length' "$PERMISSIONS_FILE")
HIGH=$(jq '[.[] | select(.RiskLevel == "HIGH")] | length' "$PERMISSIONS_FILE")
MEDIUM=$(jq '[.[] | select(.RiskLevel == "MEDIUM")] | length' "$PERMISSIONS_FILE")

printf '\n=========================================\n'
printf ' ENTRA ID - RECOLECCIÓN DE PERMISOS API\n'
printf '=========================================\n'
printf '[OK] Permisos encontrados: %s\n' "$TOTAL_PERMISSIONS"
printf '[OK] Riesgo HIGH: %s\n' "$HIGH"
printf '[OK] Riesgo MEDIUM: %s\n' "$MEDIUM"
printf '[OK] Fichero: %s\n' "$PERMISSIONS_FILE"
