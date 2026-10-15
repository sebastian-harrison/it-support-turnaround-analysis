# Metrics and analytical approach

## Population and reporting basis

The report includes incidents opened from **March 1 through May 31, 2016**, including cases resolved or closed later. The latest recorded closure is February 15, 2017.

The source contains 141,712 event records for 24,918 incidents. Excel retains one row per incident. The report and Tableau cover 24,437 incidents, with resolution times available for 22,900. Narrative summaries and headline counts are rounded; analytical tables and calculations retain the original precision.

All comparisons use **calendar days**, including waiting time and weekends. The first recorded priority and category define the comparison groups. Priority reflects impact and urgency. Reassignments may change the support analyst or team.

## Definitions

| Measure | Calculation and population |
| --- | --- |
| Time to resolution | Resolution timestamp minus opening timestamp, where both are known and the interval is nonnegative. |
| Time to recorded closure | Recorded closure timestamp minus opening timestamp, where the interval is valid. |
| Resolution-to-closure interval | Closure minus resolution, calculated for each case with opening ≤ resolution ≤ closure, then summarized. |
| Median | Middle of the individual eligible case durations. |
| 90th percentile | Inclusive interpolation over individual resolution times. The threshold is 15.6086 days, displayed as about 16 days in the findings. Calculations use the unrounded value. |
| Resolution-date coverage | Resolution-eligible cases divided by all cases in the selected population. |
| Reassigned cases | Cases with a final reassignment counter greater than zero, divided by cases with a known counter. |
| Reassignment groups | Final counters of 0, 1, 2 and 3 or more. Unknowns retain an Unknown group. |
| Slow cases | Eligible cohort cases with resolution duration at or above the fixed full-cohort 90th percentile. This threshold is descriptive and is not an SLA. |
| Category slow rate | Slow cases divided by resolution-eligible cases in that category and scope. |
| Category contribution | Category slow cases divided by all slow cases in the report. The dashboard ranking covers all categories. |

The overall closure median uses all closure-eligible cases. The paired comparison uses the same 22,900 cases for both endpoints, giving a closure median of 6.23 days rather than the overall 6.06 days. The median resolution-to-closure interval is calculated from individual intervals; it is not the difference between two medians.

## Case preparation

Power Query interprets day/month/year timestamps explicitly, preserves identifiers as text and treats `?` as unknown. Within each incident it orders events by update timestamp, then numeric modification counter. First and final attributes and source-row references are retained. Conflicting business values at a first/final ordering key stop the query.

Final cumulative reassignment and reopen counters are used once per case. They are not summed across event updates. Missing dates remain blank, and invalid intervals are excluded from the relevant timing measure.

## Comparisons behind the findings

Categories are ranked by slow-case count, with at least 30 resolution-eligible cases required for the displayed ranking. The dashboard shows eight categories; smaller groups remain in the case data.

For reassignment comparisons, category/priority groups must have at least 30 eligible cases in both the zero and three-or-more bands. The three largest eligible groups are selected by their combined case volume before timing differences are examined. These are Categories 42, 26 and 53, all Moderate priority. Median gaps are approximately 6.0, 7.2 and 8.5 days. Repeating the comparison after excluding changes in category or priority gives similar gaps of 5.7, 7.1 and 8.5 days.

The Tableau service-category selection updates headline figures, the reassignment chart, and the resolution-to-closure interval. The category ranking always shows all categories, with slow-case counts and percentages together. The slow-case definition stays the same for every selection. Categories with at least 30 measured cases are available in the selector.

## Interpretation

Resolution dates are missing for 6.3% of the cohort, concentrated in cases without reassignments. Case complexity and unobserved dependencies may influence both reassignment and elapsed time. Coded categories cannot be translated into named services from the public data. The analysis supports case selection and reporting decisions, rather than causal claims, staff-effort measures or estimates of savings.
