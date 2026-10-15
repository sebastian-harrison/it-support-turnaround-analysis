"""Export the saved Excel case table and reference metrics for Tableau."""

import argparse
import collections
import csv
import datetime as dt
import math
from pathlib import Path
import xml.etree.ElementTree as ET
from zipfile import ZipFile

import openpyxl

ROOT = Path(__file__).resolve().parents[1]
WORKBOOK = ROOT / "Service_Operations.xlsx"
DATE_FORMAT = "%d/%m/%Y %H:%M"
TOLERANCE = 1e-6


def read_table(workbook, sheet_name, table_name):
    with ZipFile(WORKBOOK) as package:
        definitions = [
            ET.fromstring(package.read(name))
            for name in package.namelist()
            if name.startswith("xl/tables/") and name.endswith(".xml")
        ]
    definition = next(item for item in definitions if item.get("name") == table_name)
    rows = list(workbook[sheet_name][definition.get("ref")])
    headers = [cell.value for cell in rows[0]]
    return [dict(zip(headers, (cell.value for cell in row))) for row in rows[1:]]


def percentile(values, fraction):
    ordered = sorted(values)
    position = (len(ordered) - 1) * fraction
    lower, upper = math.floor(position), math.ceil(position)
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower)


def close_enough(actual, expected):
    return (
        actual is not None
        and expected is not None
        and abs(actual - expected) <= TOLERANCE
    )


def require(condition, message):
    if not condition:
        raise ValueError(message)


def compare_source(cases, source_path):
    events = collections.defaultdict(list)
    with source_path.open(newline="", encoding="utf-8") as source:
        for row_number, event in enumerate(csv.DictReader(source), 1):
            updated_at = dt.datetime.strptime(event["sys_updated_at"], DATE_FORMAT)
            modification = int(event["sys_mod_count"])
            events[event["number"]].append(
                (updated_at, modification, row_number, event)
            )

    require(set(events) == {case["case_id"] for case in cases},
            "Incident IDs differ between the event file and Excel.")

    for case in cases:
        ordered = sorted(events[case["case_id"]])
        first, final = ordered[0], ordered[-1]
        expected = (
            first[2], final[2], len(ordered),
            None if first[3]["priority"] == "?" else first[3]["priority"],
            None if first[3]["category"] == "?" else first[3]["category"],
            int(final[3]["reassignment_count"]),
        )
        actual = tuple(case[field] for field in (
            "first_source_row", "final_source_row", "source_event_count",
            "first_priority", "first_category", "reassignment_count",
        ))
        require(actual == expected,
                f"First or final event selection differs for {case['case_id']}.")


def compare_durations(cases):
    intervals = [
        ("closure_days", "opened_at", "closed_at"),
        ("resolution_days", "opened_at", "resolved_at"),
        ("post_resolution_days", "resolved_at", "closed_at"),
    ]
    for case in cases:
        for measure, start, end in intervals:
            if case[measure] is None:
                continue
            days = (case[end] - case[start]).total_seconds() / 86400
            require(close_enough(case[measure], days),
                    f"{measure} differs from the dates for {case['case_id']}.")


def scope_metrics(rows):
    resolution = [row["resolution_days"] for row in rows
                  if row["resolution_eligible"] == 1]
    closure = [row["closure_days"] for row in rows
               if row["closure_eligible"] == 1]
    paired = [row for row in rows if row["paired_eligible"] == 1]
    known = [row for row in rows if row["reassigned_flag"] is not None]
    return {
        "case_count": len(rows),
        "resolution_eligible": len(resolution),
        "resolution_coverage": len(resolution) / len(rows),
        "median_resolution_days": percentile(resolution, 0.5),
        "p90_resolution_days": percentile(resolution, 0.9),
        "median_closure_days": percentile(closure, 0.5),
        "p90_closure_days": percentile(closure, 0.9),
        "paired_eligible": len(paired),
        "paired_median_resolution_days": percentile(
            [row["resolution_days"] for row in paired], 0.5),
        "paired_median_closure_days": percentile(
            [row["closure_days"] for row in paired], 0.5),
        "median_post_resolution_days": percentile(
            [row["post_resolution_days"] for row in paired], 0.5),
        "reassigned_rate": sum(row["reassigned_flag"] for row in known) / len(known),
    }


def validate(cases, analysis, source_path):
    cohort = [case for case in cases if case["in_cohort"] == 1]
    require(len(cases) == len({case["case_id"] for case in cases}) == 24918,
            "The prepared table must contain 24,918 distinct incidents.")
    require(sum(case["source_event_count"] for case in cases) == 141712,
            "Source event counts differ from the historical dataset.")
    require(len(cohort) == 24437, "The reporting population must contain 24,437 incidents.")
    require(sum(case["resolved_at"] is None for case in cohort) == 1537,
            "Missing resolution dates differ from the historical dataset.")

    for field in (
        "date_issue", "counter_mismatch", "key_conflict", "source_parse_errors",
        "opening_changed", "closure_changed",
    ):
        require(all(case[field] == 0 for case in cases),
                f"The prepared table contains an issue in {field}.")

    compare_source(cases, source_path)
    compare_durations(cases)
    reference = {row["key"]: row["value"] for row in analysis}
    scopes = {
        "All priorities": cohort,
        "Moderate priority only": [case for case in cohort
                                   if case["first_priority"] == "3 - Moderate"],
        "Category 42": [case for case in cohort
                        if case["first_category"] == "Category 42"],
    }
    for scope, rows in scopes.items():
        for metric, value in scope_metrics(rows).items():
            key = f"scope|{scope}|All|{metric}"
            require(close_enough(value, reference.get(key)),
                    f"The saved {metric} differs from the case data for {scope}.")

    threshold = percentile(
        [case["resolution_days"] for case in cohort
         if case["resolution_eligible"] == 1], 0.9)
    for case in cases:
        eligible = case["in_cohort"] == 1 and case["resolution_eligible"] == 1
        expected_flag = int(case["resolution_days"] >= threshold) if eligible else None
        require(close_enough(case["slow_threshold_days"], threshold)
                and case["slow_resolution_flag"] == expected_flag,
                f"The slow-case definition differs for {case['case_id']}.")
    return cohort


def export(cohort, analysis):
    destination = ROOT / "data/tableau"
    destination.mkdir(parents=True, exist_ok=True)
    with (destination / "cases.csv").open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=list(cohort[0]))
        writer.writeheader()
        for case in cohort:
            writer.writerow({
                key: value.isoformat(sep=" ") if isinstance(value, dt.datetime)
                else value.isoformat() if isinstance(value, dt.date) else value
                for key, value in case.items()
            })
    with (destination / "controls.csv").open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=["scope", "metric", "excel_value"])
        writer.writeheader()
        for row in analysis:
            if row["section"] == "scope":
                writer.writerow({
                    "scope": row["scope"], "metric": row["metric"],
                    "excel_value": row["value"],
                })


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "incident_event_log.csv",
                        help="Path to the original event CSV.")
    args = parser.parse_args()
    if not args.source.is_file():
        parser.error("Download incident_event_log.csv or supply its path with --source.")

    workbook = openpyxl.load_workbook(WORKBOOK, read_only=True, data_only=True)
    try:
        cases = read_table(workbook, "Cases", "CaseData")
        analysis = read_table(workbook, "Analysis", "AnalysisData")
    finally:
        workbook.close()
    try:
        cohort = validate(cases, analysis, args.source)
    except ValueError as error:
        raise SystemExit(f"Export stopped: {error}") from error
    export(cohort, analysis)
    print(f"Exported {len(cohort):,} cases and reference metrics to data/tableau.")


if __name__ == "__main__":
    main()
