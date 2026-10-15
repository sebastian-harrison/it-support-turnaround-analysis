let
    Source=Table.Buffer(PreparedCases()),
    ThresholdValue=SlowThreshold(Source),
    Safe=if List.Sum(Source[key_conflict])>0 then error "Conflicting first/final selection keys. Resolve before reporting." else if List.Sum(Source[source_parse_errors])>0 then error "Source parse failures must be investigated before reporting." else Source,
    Flagged=Table.AddColumn(Safe,"slow_resolution_flag",each if [in_cohort]=1 and [resolution_eligible]=1 then (if [resolution_days]>=ThresholdValue then 1 else 0) else null,Int64.Type),
    Threshold=Table.AddColumn(Flagged,"slow_threshold_days",each ThresholdValue,type number)
in
    Threshold
