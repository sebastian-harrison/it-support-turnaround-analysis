() => let
    Source = Table.Buffer(RawEvents()),
    BusinessFields = {"incident_state","opened_at","resolved_at","closed_at","priority","category","assignment_group","reassignment_count","reopen_count"},
    CasesGrouped = Table.Group(Source, {"number"}, {{"case_record", (g as table) as record =>
        let
            s=Table.Sort(g, {{"sys_updated_at",Order.Ascending},{"sys_mod_count",Order.Ascending},{"source_row",Order.Ascending}}),
            f=s{0}, z=Table.Last(s),
            ft=Table.SelectRows(s, each [sys_updated_at]=f[sys_updated_at] and [sys_mod_count]=f[sys_mod_count]),
            zt=Table.SelectRows(s, each [sys_updated_at]=z[sys_updated_at] and [sys_mod_count]=z[sys_mod_count]),
            conflict=Table.RowCount(Table.Distinct(Table.SelectColumns(ft,BusinessFields)))>1 or Table.RowCount(Table.Distinct(Table.SelectColumns(zt,BusinessFields)))>1,
            co=f[opened_at]>=#datetime(2016,3,1,0,0,0) and f[opened_at]<#datetime(2016,6,1,0,0,0),
            ce=if z[closed_at]=null then false else z[closed_at]>=f[opened_at],
            re=if z[resolved_at]=null then false else z[resolved_at]>=f[opened_at],
            pe=if not ce or not re then false else z[resolved_at]<=z[closed_at],
            cd=if ce then Duration.TotalDays(z[closed_at]-f[opened_at]) else null,
            rd=if re then Duration.TotalDays(z[resolved_at]-f[opened_at]) else null,
            pd=if pe then Duration.TotalDays(z[closed_at]-z[resolved_at]) else null,
            rc=z[reassignment_count], oc=z[reopen_count],
            mismatch=rc<>List.Max(List.RemoveNulls(g[reassignment_count])) or oc<>List.Max(List.RemoveNulls(g[reopen_count]))
        in [case_id=f[number],source_event_count=Table.RowCount(g),first_source_row=f[source_row],final_source_row=z[source_row],first_updated_at=f[sys_updated_at],final_updated_at=z[sys_updated_at],first_mod_count=f[sys_mod_count],final_mod_count=z[sys_mod_count],opened_at=f[opened_at],resolved_at=z[resolved_at],closed_at=z[closed_at],final_state=z[incident_state],first_priority=f[priority],final_priority=z[priority],priority_changed=if List.Count(List.Distinct(g[priority]))>1 then 1 else 0,first_category=f[category],final_category=z[category],category_changed=if List.Count(List.Distinct(g[category]))>1 then 1 else 0,final_assignment_group=z[assignment_group],reassignment_count=rc,reassignment_band=if rc=null then "Unknown" else if rc>=3 then "3+" else Text.From(rc),reopen_count=oc,in_cohort=if co then 1 else 0,closure_eligible=if ce then 1 else 0,resolution_eligible=if re then 1 else 0,paired_eligible=if pe then 1 else 0,closure_days=cd,resolution_days=rd,post_resolution_days=pd,reassigned_flag=if rc=null then null else if rc>0 then 1 else 0,reopened_flag=if oc=null then null else if oc>0 then 1 else 0,opening_month=Date.StartOfMonth(Date.From(f[opened_at])),cohort_resolution_days=if co then rd else null,cohort_closure_days=if co then cd else null,cohort_post_resolution_days=if co then pd else null,counter_mismatch=if mismatch then 1 else 0,date_issue=if (z[closed_at]<>null and not ce) or (z[resolved_at]<>null and not re) or (ce and re and not pe) then 1 else 0,key_conflict=if conflict then 1 else 0,opening_changed=if List.Count(List.Distinct(g[opened_at]))>1 then 1 else 0,closure_changed=if List.Count(List.Distinct(g[closed_at]))>1 then 1 else 0,source_parse_errors=List.Sum(g[parse_error_count])], type record}}),
    Expanded = Table.FromRecords(CasesGrouped[case_record]),
    Dates = {"first_updated_at","final_updated_at","opened_at","resolved_at","closed_at"},
    Integers = {"source_event_count","first_source_row","final_source_row","first_mod_count","final_mod_count","priority_changed","category_changed","reassignment_count","reopen_count","in_cohort","closure_eligible","resolution_eligible","paired_eligible","reassigned_flag","reopened_flag","counter_mismatch","date_issue","key_conflict","opening_changed","closure_changed","source_parse_errors"},
    Numbers = {"closure_days","resolution_days","post_resolution_days","cohort_resolution_days","cohort_closure_days","cohort_post_resolution_days"},
    Typed = Table.TransformColumnTypes(Expanded, List.Transform(Dates, each {_,type datetime}) & List.Transform(Integers, each {_,Int64.Type}) & List.Transform(Numbers, each {_,type number}) & {{"opening_month",type date}}),
    Sorted = Table.Sort(Typed, {{"case_id",Order.Ascending}})
in
    Sorted
