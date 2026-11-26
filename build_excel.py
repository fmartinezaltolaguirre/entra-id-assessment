#!/usr/bin/env python3

import json
import os
from pathlib import Path
from datetime import datetime

import pandas as pd


INPUT_DIR = "./output"
OUTPUT_FILE = "./output/EntraID_Application_Assessment.xlsx"


def load_json(filename):
    file_path = os.path.join(INPUT_DIR, filename)

    if not os.path.exists(file_path):
        print(f"[WARN] No existe {filename}")
        return []

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as ex:
        print(f"[ERROR] {filename}: {ex}")
        return []


def create_dataframe(data):
    if not data:
        return pd.DataFrame()

    if isinstance(data, dict):
        data = [data]

    return pd.DataFrame(data)


def autosize_columns(writer, sheet_name, dataframe):
    worksheet = writer.sheets[sheet_name]

    for idx, column in enumerate(dataframe.columns):
        max_length = max(
            dataframe[column].astype(str).map(len).max(),
            len(column)
        )

        worksheet.set_column(idx, idx, min(max_length + 5, 80))


def create_summary_sheet(writer, stats):
    summary_df = pd.DataFrame(stats)

    summary_df.to_excel(
        writer,
        sheet_name="Executive_Summary",
        index=False
    )

    worksheet = writer.sheets["Executive_Summary"]

    worksheet.set_column("A:A", 40)
    worksheet.set_column("B:B", 20)


def calculate_summary(
    applications,
    owners,
    secrets,
    certificates,
    findings,
    enterprise_apps
):

    total_apps = len(applications)

    apps_with_owner = len(
        set(
            x.get("ApplicationId")
            for x in owners
            if x.get("ApplicationId")
        )
    )

    apps_without_owner = max(
        total_apps - apps_with_owner,
        0
    )

    expired_secrets = sum(
        1 for s in secrets
        if str(s.get("Status", "")).lower() == "expired"
    )

    expiring_secrets = sum(
        1 for s in secrets
        if str(s.get("Status", "")).lower() in [
            "warning",
            "expiring"
        ]
    )

    expired_certs = sum(
        1 for c in certificates
        if str(c.get("Status", "")).lower() == "expired"
    )

    critical_findings = sum(
        1 for x in findings
        if str(x.get("Severity", "")).upper() == "CRITICAL"
    )

    high_findings = sum(
        1 for x in findings
        if str(x.get("Severity", "")).upper() == "HIGH"
    )

    return [
        {
            "Metric": "Report generated",
            "Value": datetime.now().strftime(
                "%Y-%m-%d %H:%M:%S"
            )
        },
        {
            "Metric": "Registered Applications",
            "Value": total_apps
        },
        {
            "Metric": "Enterprise Applications",
            "Value": len(enterprise_apps)
        },
        {
            "Metric": "Applications without owner",
            "Value": apps_without_owner
        },
        {
            "Metric": "Expired secrets",
            "Value": expired_secrets
        },
        {
            "Metric": "Secrets expiring soon",
            "Value": expiring_secrets
        },
        {
            "Metric": "Expired certificates",
            "Value": expired_certs
        },
        {
            "Metric": "Critical findings",
            "Value": critical_findings
        },
        {
            "Metric": "High findings",
            "Value": high_findings
        }
    ]


def main():

    applications = load_json("applications.json")
    owners = load_json("owners.json")
    permissions = load_json("permissions.json")
    consent_grants = load_json("consent_grants.json")
    redirect_uris = load_json("redirect_uris.json")
    secrets = load_json("secrets.json")
    certificates = load_json("certificates.json")
    enterprise_apps = load_json("enterprise_apps.json")
    federation = load_json("federation.json")
    findings = load_json("findings.json")

    summary = calculate_summary(
        applications,
        owners,
        secrets,
        certificates,
        findings,
        enterprise_apps
    )

    Path(INPUT_DIR).mkdir(
        parents=True,
        exist_ok=True
    )

    with pd.ExcelWriter(
        OUTPUT_FILE,
        engine="xlsxwriter"
    ) as writer:

        workbook = writer.book

        header_format = workbook.add_format(
            {
                "bold": True,
                "bg_color": "#1F4E78",
                "font_color": "white",
                "border": 1
            }
        )

        sheets = {
            "Applications": applications,
            "Owners": owners,
            "API_Permissions": permissions,
            "Consent_Grants": consent_grants,
            "Redirect_URIs": redirect_uris,
            "Secrets": secrets,
            "Certificates": certificates,
            "Enterprise_Applications": enterprise_apps,
            "Federation": federation,
            "Findings": findings
        }

        summary_df = pd.DataFrame(summary)

        summary_df.to_excel(
            writer,
            sheet_name="Executive_Summary",
            index=False
        )

        summary_ws = writer.sheets[
            "Executive_Summary"
        ]

        for col_num, value in enumerate(
            summary_df.columns
        ):
            summary_ws.write(
                0,
                col_num,
                value,
                header_format
            )

        summary_ws.set_column("A:A", 45)
        summary_ws.set_column("B:B", 25)

        for sheet_name, data in sheets.items():

            df = create_dataframe(data)

            df.to_excel(
                writer,
                sheet_name=sheet_name,
                index=False
            )

            worksheet = writer.sheets[
                sheet_name
            ]

            for col_num, value in enumerate(
                df.columns.values
            ):
                worksheet.write(
                    0,
                    col_num,
                    value,
                    header_format
                )

            if len(df) > 0:
                worksheet.autofilter(
                    0,
                    0,
                    len(df),
                    len(df.columns) - 1
                )

                worksheet.freeze_panes(1, 0)

                autosize_columns(
                    writer,
                    sheet_name,
                    df
                )

        print("")
        print("=" * 60)
        print("Entra ID Assessment generado")
        print("=" * 60)
        print(OUTPUT_FILE)
        print("")


if __name__ == "__main__":
    main()
