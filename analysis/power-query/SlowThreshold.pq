(optional prepared as nullable table) => let
    Source = if prepared=null then PreparedCases() else prepared,
    Eligible = List.Buffer(List.RemoveNulls(Source[cohort_resolution_days])),
    Result = if List.IsEmpty(Eligible) then error "No cohort cases eligible for resolution-time analysis." else List.Percentile(Eligible,0.9,[PercentileMode=PercentileMode.ExcelInc])
in
    Result
