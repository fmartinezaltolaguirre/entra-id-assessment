#!/usr/bin/env python3

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

import pandas as pd

SEVERITY_COLORS = {
    "CRITICAL": "#FFC7CE",
    "HIGH": "#FFEB9C",
}


def load_json(path: Path):
    if not path.is_file():
        print(f"[WARN] No existe {path}; se usará una colección vacía.", file=sys.stderr)
        return []

    try:
        with path.open("r", encoding="utf-8") as file:
            data = json.load(file)
    except json.JSONDecodeError as exc:
        raise ValueError(f"JSON inválido en {path}: {exc}") from exc

    if not isinstance(data, (list, dict)):
        raise TypeError(f"Formato inesperado en {path}: se esperaba lista o diccionario")

    return data


def df(data):
    if not data:
        return pd.DataFrame()
    if isinstance(data, dict):
        return pd.DataFrame([data])
    if not isinstance(data, list):
        raise TypeError("Los datos JSON detallados deben ser una lista")
    return pd.DataFrame(data)


def worksheet_autosize(writer, sheet_name, dataframe):
    worksheet = writer.sheets[sheet_name]
    for idx, column in enumerate(dataframe.columns):
        values = dataframe[column].fillna("").astype(str)
        width = max(len(str(column)), values.str.len().max() if len(values) else 0)
        worksheet.set_column(idx, idx, min(width + 4, 80))


def write_table(writer, sheet_name, dataframe, header_format):
    dataframe.to_excel(writer, sheet_name=sheet_name, index=False)
    worksheet = writer.sheets[sheet_name]

    for index, value in enumerate(dataframe.columns):
        worksheet.write(0, index, value, header_format)

    if len(dataframe.columns):
        worksheet.autofilter(0, 0, max(len(dataframe), 1), len(dataframe.columns) - 1)
        worksheet.freeze_panes(1, 0)
        worksheet_autosize(writer, sheet_name, dataframe)


def count_status(records, status):
    return sum(isinstance(record, dict) and record.get("Status") == status for record in records)


def count_field(records, field, value):
    return sum(isinstance(record, dict) and record.get(field) == value for record in records)


def build_summary(applications, enterprise, secrets, certificates, redirects, findings):
    return pd.DataFrame([
        {"Metric": "Report Date", "Value": datetime.now().strftime("%Y-%m-%d %H:%M")},
        {"Metric": "Applications", "Value": len(applications)},
        {"Metric": "Enterprise Applications", "Value": len(enterprise)},
        {"Metric": "Secrets", "Value": len(secrets)},
        {"Metric": "Expired Secrets", "Value": count_status(secrets, "EXPIRED")},
        {"Metric": "Secrets < 90 days", "Value": count_status(secrets, "EXPIRING_SOON")},
        {"Metric": "Certificates", "Value": len(certificates)},
        {"Metric": "Certificates < 90 days", "Value": count_status(certificates, "EXPIRING_SOON")},
        {"Metric": "Redirect URIs", "Value": len(redirects)},
        {"Metric": "High Risk Redirect URIs", "Value": count_field(redirects, "Risk", "HIGH")},
        {"Metric": "Findings", "Value": len(findings)},
        {"Metric": "Critical Findings", "Value": count_field(findings, "Severity", "CRITICAL")},
        {"Metric": "High Findings", "Value": count_field(findings, "Severity", "HIGH")},
    ])


def build_top_risky(findings):
    if not findings:
        return pd.DataFrame(columns=["Application", "Critical", "High", "Medium", "Risk_Score", "Findings"])

    frame = pd.DataFrame(findings)
    if "Application" not in frame.columns or "Severity" not in frame.columns:
        return pd.DataFrame(columns=["Application", "Critical", "High", "Medium", "Risk_Score", "Findings"])

    frame["Application"] = frame["Application"].fillna("UNKNOWN")
    weighted = frame.assign(
        Critical=(frame["Severity"] == "CRITICAL").astype(int) * 10,
        High=(frame["Severity"] == "HIGH").astype(int) * 5,
        Medium=(frame["Severity"] == "MEDIUM").astype(int) * 2,
    )

    top = weighted.groupby("Application", dropna=False).agg(
        Critical=("Critical", "sum"),
        High=("High", "sum"),
        Medium=("Medium", "sum"),
        Findings=("Severity", "count"),
    ).reset_index()
    top["Risk_Score"] = top["Critical"] + top["High"] + top["Medium"]
    return top.sort_values(["Risk_Score", "Findings"], ascending=False).head(25)


def main():
    parser = argparse.ArgumentParser(description="Genera el informe Excel de Entra ID")
    parser.add_argument("--output-dir", default="./output")
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    output_file = output_dir / "EntraID_Application_Assessment.xlsx"

    applications = load_json(output_dir / "applications.json")
    owners = load_json(output_dir / "owners.json")
    secrets = load_json(output_dir / "secrets.json")
    certificates = load_json(output_dir / "certificates.json")
    permissions = load_json(output_dir / "permissions.json")
    permissions_enriched = load_json(output_dir / "permissions_enriched.json")
    redirects = load_json(output_dir / "redirect_uris.json")
    enterprise = load_json(output_dir / "enterprise_apps.json")
    findings = load_json(output_dir / "findings.json")

    summary = build_summary(applications, enterprise, secrets, certificates, redirects, findings)
    top_risky = build_top_risky(findings)

    sheets = {
        "Executive_Summary": summary,
        "Top_Riskiest_Applications": top_risky,
        "Applications": df(applications),
        "Owners": df(owners),
        "Secrets": df(secrets),
        "Certificates": df(certificates),
        "Permissions": df(permissions),
        "Permissions_Enriched": df(permissions_enriched),
        "Redirect_URIs": df(redirects),
        "Enterprise_Apps": df(enterprise),
        "Findings": df(findings),
    }

    with pd.ExcelWriter(output_file, engine="xlsxwriter") as writer:
        workbook = writer.book
        header_format = workbook.add_format({"bold": True, "bg_color": "#1F497D", "font_color": "white", "border": 1})

        for sheet_name, dataframe in sheets.items():
            write_table(writer, sheet_name, dataframe, header_format)

        findings_frame = sheets["Findings"]
        if not findings_frame.empty and "Severity" in findings_frame.columns:
            worksheet = writer.sheets["Findings"]
            severity_column = findings_frame.columns.get_loc("Severity")

            for severity, color in SEVERITY_COLORS.items():
                worksheet.conditional_format(
                    1,
                    severity_column,
                    len(findings_frame),
                    severity_column,
                    {
                        "type": "text",
                        "criteria": "containing",
                        "value": severity,
                        "format": workbook.add_format({"bg_color": color}),
                    },
                )

    print(output_file)


if __name__ == "__main__":
    main()
