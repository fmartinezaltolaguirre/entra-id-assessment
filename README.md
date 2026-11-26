# Entra ID Assessment

Herramienta de evaluación del entorno de Microsoft Entra ID.

## Ejecución completa

```bash
chmod +x *.sh
./run_assessment.sh
./run_assessment.sh --subscription "<subscription-name-or-id>"
./run_assessment.sh --output-dir "/ruta/salida"
./run_assessment.sh --dry-run
```

El orquestador valida las dependencias, comprueba la sesión de Azure y ejecuta todos los módulos antes de generar el informe Excel.

## Dependencias

- Bash
- Azure CLI
- jq
- Python 3
- pandas
- xlsxwriter

## Seguridad

Los archivos generados pueden contener identificadores, propietarios y configuración sensible. El directorio `output/` debe permanecer excluido del control de versiones y no debe compartirse sin una revisión previa.
