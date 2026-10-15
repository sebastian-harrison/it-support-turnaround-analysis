# Reproduce the analysis

The Excel workbook and packaged Tableau workbook contain saved data and can be opened without the original event file. Refreshing the analysis requires Microsoft Excel with Power Query, Tableau Desktop and Python 3.

Install the Python dependencies from the repository folder:

```sh
python3 -m pip install -r analysis/requirements.txt
```

## Source data

Download *Incident management process enriched event log* from [UCI dataset 498](https://archive.ics.uci.edu/dataset/498/incident+management+process+enriched+event+log). Extract `incident_event_log.csv` into the repository folder. The raw file is excluded from version control.

The analysis uses the source version with 141,712 events and 24,918 incidents. Its SHA-256 is:

```text
fd184bbfd62329cfe093e99da2ea7071905f2ead91900b448eb2635870821bef
```

## Refresh Excel

1. Open `Service_Operations.xlsx`. In the Power Query editor, open **RawEvents > Advanced Editor** and set `SourcePath` to the downloaded CSV's full path. The saved query contains a placeholder path.
2. Refresh **CaseData**, then **AnalysisData**, allowing each query to finish. **RawEvents**, **PreparedCases** and **SlowThreshold** remain connection-only functions.
3. Refresh the PivotTable on **Analysis**, then use **Formulas > Calculate Now**. The workbook uses manual calculation.
4. Inspect the **Checks** sheet and save. The report covers 24,437 incidents opened from March through May 2016.

The query source is also available in `analysis/power-query/`. The **Report** print area is `A1:L30`, landscape Letter, fitted to one page. Export that sheet to update `Service_Operations_Report.pdf`.

## Export the case data

After refreshing and saving Excel, run:

```sh
python3 analysis/export_cases.py
```

The exporter compares the saved case table with the original events and recalculates the reference metrics before writing `data/tableau/cases.csv` and `controls.csv`. It stops if the source or calculations differ from the report's historical dataset. To use a raw file stored elsewhere, pass `--source` followed by its path.

## Update Tableau

Open `Service_Operations.twbx` in Tableau Desktop. Reconnect its text data source to `data/tableau/cases.csv` and refresh it. Compare the overall figures with `controls.csv`, then use the category selector to inspect the turnaround measures. The category ranking always covers all categories.

Save the packaged workbook with **All categories** selected. Export the dashboard through **Dashboard > Export Image** to update `images/tableau_dashboard.png`.

## Recreate the figures

```sh
python3 analysis/render_figures.py
```

This produces the two PNG figures used in the README from the saved case export. Changes to the source data also require reassessing the written findings.
