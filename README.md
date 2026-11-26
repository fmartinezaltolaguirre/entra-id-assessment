# Entra ID Assessment

Herramienta de evaluación del entorno de **Microsoft Entra ID** que recopila información sobre aplicaciones, propietarios, secretos, certificados, permisos, URI de redirección y enterprise applications, genera hallazgos de seguridad y produce un informe Excel consolidado.

## Funcionalidad

El proyecto realiza las siguientes tareas:

- Inventario de aplicaciones registradas en Entra ID.
- Inventario de enterprise applications.
- Relación de propietarios de las aplicaciones.
- Análisis de secretos y certificados.
- Identificación de secretos y certificados próximos a caducar.
- Inventario y enriquecimiento de permisos.
- Clasificación de permisos críticos.
- Análisis de URI de redirección con posibles riesgos.
- Generación de hallazgos por severidad.
- Creación de un archivo Excel con resumen ejecutivo y hojas detalladas.

## Hallazgos generados

El motor de hallazgos detecta, entre otros casos:

| Categoría | Hallazgo |
|---|---|
| Governance | Aplicaciones sin propietario |
| Secrets | Secretos expirados |
| Secrets | Secretos que caducan en menos de 90 días |
| Certificates | Certificados que caducan en menos de 90 días |
| Redirect URI | URI de redirección de alto riesgo |
| Permissions | Permisos críticos |
| Enterprise App | Enterprise applications deshabilitadas |

Los hallazgos utilizan las severidades `CRITICAL`, `HIGH` y `MEDIUM`.

## Requisitos

### Herramientas

- Bash
- Azure CLI
- `jq`
- Python 3
- Dependencias Python:
  - `pandas`
  - `xlsxwriter`

Puede comprobar Azure CLI y crear un entorno virtual con:

```bash
az account show
python3 -m venv .venv
source .venv/bin/activate
pip install pandas xlsxwriter
```

Asegúrese de disponer de permisos suficientes para consultar las aplicaciones, propietarios, credenciales, permisos y enterprise applications del tenant.

## Autenticación

Inicie sesión en Azure antes de ejecutar los scripts:

```bash
az login
az account set --subscription "<subscription-id-or-name>"
```

Los scripts usan el tenant activo obtenido mediante:

```bash
az account show --query tenantId -o tsv
```

## Uso

Desde la raíz del repositorio:

```bash
chmod +x *.sh
./entra_inventory.sh
./collect_applications.sh
./collect_enterprise_apps.sh
./collect_owners.sh
./collect_secrets.sh
./collect_certificates.sh
./collect_permissions.sh
./collect_permission_catalog.sh
./enrich_permissions.sh
./collect_redirect_uris.sh
./generate_findings.sh
python3 build_excel.py
```

Revise los scripts individuales antes de ejecutarlos en el entorno, ya que realizan consultas contra Microsoft Graph mediante Azure CLI y pueden requerir permisos adicionales.

## Salida

Los resultados se guardan en el directorio `output/`.

Ejemplos de archivos generados:

- `applications.json`
- `enterprise_apps.json`
- `owners.json`
- `secrets.json`
- `certificates.json`
- `permissions.json`
- `permissions_enriched.json`
- `redirect_uris.json`
- `findings.json`
- `EntraID_Application_Assessment.xlsx`

El archivo JSON y Excel generado no se incluyen en el repositorio mediante `.gitignore`.

## Informe Excel

El informe `output/EntraID_Application_Assessment.xlsx` contiene las siguientes hojas:

- `Executive_Summary`: resumen ejecutivo y métricas principales.
- `Top_Riskiest_Applications`: aplicaciones con más hallazgos.
- `Applications`: aplicaciones registradas.
- `Enterprise_Apps`: enterprise applications.
- `Owners`: propietarios.
- `Secrets`: secretos y su estado.
- `Certificates`: certificados y su estado.
- `Permissions`: permisos recopilados.
- `Permissions_Enriched`: permisos enriquecidos y clasificados.
- `Redirect_URIs`: URI de redirección y riesgo asociado.
- `Findings`: listado completo de hallazgos.

Las filas de hallazgos críticos y altos están resaltadas mediante formato condicional.

## Estructura del repositorio

```text
.
├── build_excel.py
├── collect_applications.sh
├── collect_certificates.sh
├── collect_enterprise_apps.sh
├── collect_owners.sh
├── collect_permission_catalog.sh
├── collect_permissions.sh
├── collect_redirect_uris.sh
├── collect_secrets.sh
├── enrich_permissions.sh
├── entra_inventory.sh
├── generate_findings.sh
└── output/
```

## Consideraciones de seguridad

- Valide y limite los permisos concedidos a Azure CLI y a las cuentas usadas para ejecutar la evaluación.
- No publiques archivos de `output/` si contienen datos sensibles.
- Trate los identificadores, secretos expuestos, permisos y propietarios como información confidencial.
- Revise los hallazgos con los responsables de identidad y seguridad antes de aplicar cambios.

## Licencia

No se ha definido una licencia en este repositorio. Antes de reutilizar o distribuir el proyecto, contacte con el propietario para aclarar las condiciones de uso.
