#!/usr/bin/env python3
import json
import pandas as pd

with open("applications_inventory.json","r",encoding="utf-8") as f:
    data=json.load(f)

out="EntraID_Applications.xlsx"
with pd.ExcelWriter(out, engine="openpyxl") as writer:
    pd.DataFrame(data).to_excel(writer,index=False,sheet_name="Applications")

print(f"Generado: {out}")

