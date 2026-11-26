#!/usr/bin/env python3

import json
from datetime import datetime

import pandas as pd


OUTPUT_DIR = "./output"

OUTPUT_FILE = (
    f"{OUTPUT_DIR}/EntraID_Application_Assessment.xlsx"
)


def load_json(filename):

    try:

        with open(
            f"{OUTPUT_DIR}/{filename}",
            "r",
            encoding="utf-8"
        ) as f:

            return json.load(f)

    except Exception:

        return []


def df(data):

    if not data:
        return pd.DataFrame()

    if isinstance(data, dict):
        return pd.DataFrame([data])

    return pd.DataFrame(data)


def worksheet_autosize(writer, sheet_name, dataframe):

    worksheet = writer.sheets[sheet_name]

    for idx, col in enumerate(dataframe.columns):

        width = max(
            dataframe[col]
            .astype(str)
            .str.len()
            .max(),
            len(col)
        )

        width = min(width + 4, 80)

        worksheet.set_column(idx, idx, width)


def write_table(
        writer,
        sheet_name,
        dataframe,
        header_format):

    dataframe.to_excel(
        writer,
        sheet_name=sheet_name,
        index=False
    )

    worksheet = writer.sheets[sheet_name]

    for c, value in enumerate(dataframe.columns):
        worksheet.write(
            0,
            c,
            value,
            header_format
        )

    if len(dataframe.columns) > 0:

        worksheet.autofilter(
            0,
            0,
            max(len(dataframe), 1),
            len(dataframe.columns) - 1
        )

        worksheet.freeze_panes(1, 0)

        worksheet_autosize(
            writer,
            sheet_name,
            dataframe
        )


def build_summary(
        applications,
        enterprise,
        secrets,
        certs,
        redirects,
        findings):

    return pd.DataFrame(
        [
            {
                "Metric":
                "Report Date",

                "Value":
                datetime.now()
                .strftime("%Y-%m-%d %H:%M")
            },

            {
                "Metric":
                "Applications",

                "Value":
                len(applications)
            },

            {
                "Metric":
                "Enterprise Applications",

                "Value":
                len(enterprise)
            },

            {
                "Metric":
                "Secrets",

                "Value":
                len(secrets)
            },

            {
                "Metric":
                "Expired Secrets",

                "Value":
                len([
                    x
                    for x in secrets
                    if x.get("Status") == "EXPIRED"
                ])
            },

            {
                "Metric":
                "Secrets < 90 days",

                "Value":
                len([
                    x
                    for x in secrets
                    if x.get("Status")
                    == "EXPIRING_SOON"
                ])
            },

            {
                "Metric":
                "Certificates",

                "Value":
                len(certs)
            },

            {
                "Metric":
                "Certificates < 90 days",

                "Value":
                len([
                    x
                    for x in certs
                    if x.get("Status")
                    == "EXPIRING_SOON"
                ])
            },

            {
                "Metric":
                "Redirect URIs",

                "Value":
                len(redirects)
            },

            {
                "Metric":
                "High Risk Redirect URIs",

                "Value":
                len([
                    x
                    for x in redirects
                    if x.get("Risk")
                    == "HIGH"
                ])
            },

            {
                "Metric":
                "Findings",

                "Value":
                len(findings)
            },

            {
                "Metric":
                "Critical Findings",

                "Value":
                len([
                    x
                    for x in findings
                    if x.get("Severity")
                    == "CRITICAL"
                ])
            },

            {
                "Metric":
                "High Findings",

                "Value":
                len([
                    x
                    for x in findings
                    if x.get("Severity")
                    == "HIGH"
                ])
            }
        ]
    )


def build_top_risky(findings):

    if not findings:

        return pd.DataFrame()

    df_findings = pd.DataFrame(findings)

    top = (
        df_findings
        .groupby("Application")
        .size()
        .reset_index(name="Findings")
        .sort_values(
            "Findings",
            ascending=False
        )
    )

    return top.head(25)


def main():

    applications = load_json(
        "applications.json"
    )

    owners = load_json(
        "owners.json"
    )

    secrets = load_json(
        "secrets.json"
    )

    certificates = load_json(
        "certificates.json"
    )

    permissions = load_json(
        "permissions.json"
    )

    permissions_enriched = load_json(
        "permissions_enriched.json"
    )

    redirects = load_json(
        "redirect_uris.json"
    )

    enterprise = load_json(
        "enterprise_apps.json"
    )

    findings = load_json(
        "findings.json"
    )

    summary_df = build_summary(
        applications,
        enterprise,
        secrets,
        certificates,
        redirects,
        findings
    )

    top_df = build_top_risky(
        findings
    )

    with pd.ExcelWriter(
        OUTPUT_FILE,
        engine="xlsxwriter"
    ) as writer:

        workbook = writer.book

        header_format = (
            workbook.add_format(
                {
                    "bold": True,
                    "bg_color": "#1F497D",
                    "font_color": "white",
                    "border": 1
                }
            )
        )

        red = workbook.add_format(
            {
                "bg_color": "#FFC7CE"
            }
        )

        orange = workbook.add_format(
            {
                "bg_color": "#FFEB9C"
            }
        )

        write_table(
            writer,
            "Executive_Summary",
            summary_df,
            header_format
        )

        write_table(
            writer,
            "Top_Riskiest_Applications",
            top_df,
            header_format
        )

        write_table(
            writer,
            "Applications",
            df(applications),
            header_format
        )

        write_table(
            writer,
            "Owners",
            df(owners),
            header_format
        )

        write_table(
            writer,
            "Secrets",
            df(secrets),
            header_format
        )

        write_table(
            writer,
            "Certificates",
            df(certificates),
            header_format
        )

        write_table(
            writer,
            "Permissions",
            df(permissions),
            header_format
        )

        write_table(
            writer,
            "Permissions_Enriched",
            df(permissions_enriched),
            header_format
        )

        write_table(
            writer,
            "Redirect_URIs",
            df(redirects),
            header_format
        )

        write_table(
            writer,
            "Enterprise_Apps",
            df(enterprise),
            header_format
        )

        write_table(
            writer,
            "Findings",
            df(findings),
            header_format
        )

        findings_ws = writer.sheets[
            "Findings"
        ]

        if findings:

            findings_df = pd.DataFrame(
                findings
            )

            severity_col = (
                findings_df.columns
                .get_loc("Severity")
            )

            findings_ws.conditional_format(
                1,
                severity_col,
                len(findings_df),
                severity_col,
                {
                    "type": "text",
                    "criteria":
                    "containing",
                    "value":
                    "CRITICAL",
                    "format":
                    red
                }
            )

            findings_ws.conditional_format(
                1,
                severity_col,
                len(findings_df),
                severity_col,
                {
                    "type": "text",
                    "criteria":
                    "containing",
                    "value":
                    "HIGH",
                    "format":
                    orange
                }
            )

    print()
    print(
        "========================================="
    )
    print(
        " ENTRA ID ASSESSMENT GENERADO"
    )
    print(
        "========================================="
    )
    print()
    print(OUTPUT_FILE)
    print()


if __name__ == "__main__":
    main()
