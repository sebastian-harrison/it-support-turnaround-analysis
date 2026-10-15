() => let
    SourcePath = "/absolute/path/to/incident_event_log.csv",
    Source = Csv.Document(File.Contents(SourcePath), [Delimiter=",", Columns=36, Encoding=65001, QuoteStyle=QuoteStyle.Csv]),
    Headers = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    Indexed = Table.AddIndexColumn(Headers, "source_row", 1, 1, Int64.Type),
    Kept = Table.SelectColumns(Indexed, {"number","incident_state","opened_at","sys_updated_at","sys_mod_count","resolved_at","closed_at","priority","category","assignment_group","reassignment_count","reopen_count","source_row"}),
    Missing = Table.ReplaceValue(Kept, "?", null, Replacer.ReplaceValue, List.RemoveItems(Table.ColumnNames(Kept), {"source_row"})),
    Dates = {"opened_at","sys_updated_at","resolved_at","closed_at"},
    Counters = {"sys_mod_count","reassignment_count","reopen_count"},
    ParseDate = (v as nullable text) as record => if v=null then [Value=null, Failed=false] else let p=try DateTime.FromText(v, [Culture="en-GB"]) in [Value=if p[HasError] then null else p[Value], Failed=p[HasError]],
    ParseCounter = (v as nullable text) as record => if v=null then [Value=null, Failed=false] else let p=try Number.FromText(v, "en-GB"), bad=if p[HasError] then true else p[Value]<0 or Number.RoundDown(p[Value])<>p[Value] in [Value=if bad then null else Int64.From(p[Value]), Failed=bad],
    Flagged = Table.AddColumn(Missing, "parse_error_count", each let r=_, checks=List.Transform(Dates, (c)=>ParseDate(Record.Field(r,c))[Failed]) & List.Transform(Counters, (c)=>ParseCounter(Record.Field(r,c))[Failed]) in List.Count(List.Select(checks, each _)), Int64.Type),
    Parsed = Table.TransformColumns(Flagged, List.Transform(Dates, (c)=>{c, each ParseDate(_)[Value], type nullable datetime}) & List.Transform(Counters, (c)=>{c, each ParseCounter(_)[Value], Int64.Type})),
    InvalidKeys = Table.SelectRows(Parsed, each [number]=null or [opened_at]=null or [sys_updated_at]=null or [sys_mod_count]=null),
    Result = if Table.RowCount(InvalidKeys)>0 then error "Missing or invalid incident/order keys. Inspect RawEvents before selecting case records." else Parsed
in
    Result
