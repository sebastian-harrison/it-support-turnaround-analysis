let
    Cohort=Table.Buffer(Table.SelectRows(CaseData, each [in_cohort]=1)),
    FixedThreshold=Cohort{0}[slow_threshold_days],
    Median=(xs as list) as nullable number => let v=List.RemoveNulls(xs) in if List.IsEmpty(v) then null else List.Median(v),
    P90=(xs as list) as nullable number => let v=List.RemoveNulls(xs) in if List.IsEmpty(v) then null else List.Percentile(v,0.9,[PercentileMode=PercentileMode.ExcelInc]),
    Sum=(xs as list) as number => let v=List.Sum(List.RemoveNulls(xs)) in if v=null then 0 else v,
    Ratio=(n as number,d as number) as nullable number => if d=0 then null else n/d,
    Stats=(input as table) as record =>
        let t=Table.Buffer(input), n=Table.RowCount(t), r=Table.Buffer(Table.SelectRows(t,each [resolution_eligible]=1)), c=Table.Buffer(Table.SelectRows(t,each [closure_eligible]=1)), p=Table.Buffer(Table.SelectRows(t,each [paired_eligible]=1)), known=List.Count(List.RemoveNulls(t[reassigned_flag])),slow=Sum(t[slow_resolution_flag]), missing=Table.Buffer(Table.SelectRows(t,each [resolved_at]=null)),present=Table.Buffer(Table.SelectRows(t,each [resolved_at]<>null)),latest=List.Max(List.RemoveNulls(t[closed_at]),null)
        in [case_count=n,resolution_eligible=Table.RowCount(r),resolution_coverage=Ratio(Table.RowCount(r),n),median_resolution_days=Median(r[resolution_days]),p90_resolution_days=P90(r[resolution_days]),closure_eligible=Table.RowCount(c),median_closure_days=Median(c[closure_days]),p90_closure_days=P90(c[closure_days]),paired_eligible=Table.RowCount(p),paired_median_resolution_days=Median(p[resolution_days]),paired_median_closure_days=Median(p[closure_days]),median_post_resolution_days=Median(p[post_resolution_days]),p90_post_resolution_days=P90(p[post_resolution_days]),known_reassignments=known,reassignment_coverage=Ratio(known,n),reassigned_cases=Sum(t[reassigned_flag]),reassigned_rate=Ratio(Sum(t[reassigned_flag]),known),reopened_cases=Sum(t[reopened_flag]),slow_cases=if slow=null then 0 else slow,slow_rate=Ratio(if slow=null then 0 else slow,Table.RowCount(r)),slow_threshold_days=FixedThreshold,missing_resolution_count=Table.RowCount(missing),missing_resolution_median_closure_days=Median(missing[closure_days]),present_resolution_median_closure_days=Median(present[closure_days]),latest_closure_serial=if latest=null then null else Duration.TotalDays(latest-#datetime(1899,12,30,0,0,0))],
    Rows=(sectionName as text,scope as text,group as text,stats as record,den as nullable number,rank as nullable number) as list => List.Transform(Record.FieldNames(stats),(m)=>[key=sectionName & "|" & scope & "|" & (if rank=null then group else Text.From(rank)) & "|" & m,#"section"=sectionName,scope=scope,group=group,metric=m,value=Record.Field(stats,m),denominator=den,review_rank=rank]),
    Scopes={ [name="All priorities",data=Cohort], [name="Moderate priority only",data=Table.SelectRows(Cohort,each [first_priority]="3 - Moderate")], [name="Category 42",data=Table.SelectRows(Cohort,each [first_category]="Category 42")] },
    ScopeRows=List.Buffer(List.Combine(List.Transform(Scopes,(s)=>Rows("scope",s[name],"All",Stats(s[data]),Table.RowCount(s[data]),null)))),
    Bands={"0","1","2","3+","Unknown"},
    BandRows=List.Combine(List.Transform(List.FirstN(Scopes,2),(s)=>List.Combine(List.Transform(Bands,(b)=>let t=Table.SelectRows(s[data],each [reassignment_band]=b) in Rows("band",s[name],b,Stats(t),Table.RowCount(t),null))))),
    CategoryRowsFor=(scope as text,t as table) as list =>
        let
            allSlow=Sum(t[slow_resolution_flag]),
            statNames=Record.FieldNames(Stats(Table.FirstN(t,0))),
            gr0=Table.Group(t,{"first_category"},{{"stats",each Stats(_),type record},{"data",each Table.Buffer(_),type table}}),
            gr=Table.Buffer(Table.ExpandRecordColumn(gr0,"stats",statNames,statNames)),
            addEligible=Table.AddColumn(gr,"eligible",each [resolution_eligible],Int64.Type),
            addSlow=Table.AddColumn(addEligible,"slow",each [slow_cases],Int64.Type),
            material=Table.Sort(Table.SelectRows(addSlow,each [eligible]>=30),{{"slow",Order.Descending},{"eligible",Order.Descending},{"first_category",Order.Ascending}}),
            ranked=Table.AddIndexColumn(material,"rank",1,1,Int64.Type),
            small=Table.AddColumn(Table.SelectRows(addSlow,each [eligible]<30),"rank",each null,type nullable number),
            combined=Table.Combine({ranked,small}),
            records=Table.ToRecords(combined)
        in List.Combine(List.Transform(records,(g)=>
            let d=g[data],sl=Table.SelectRows(d,each [slow_resolution_flag]=1),extras=[slow_share=Ratio(g[slow],if allSlow=null then 0 else allSlow),slow_band0=Table.RowCount(Table.SelectRows(sl,each [reassignment_band]="0")),slow_band1=Table.RowCount(Table.SelectRows(sl,each [reassignment_band]="1")),slow_band2=Table.RowCount(Table.SelectRows(sl,each [reassignment_band]="2")),slow_band3plus=Table.RowCount(Table.SelectRows(sl,each [reassignment_band]="3+")),slow_band_unknown=Table.RowCount(Table.SelectRows(sl,each [reassignment_band]="Unknown")),review_eligible=if g[eligible]>=30 then 1 else 0],label=if g[first_category]=null then "Unknown category" else g[first_category]
            in Rows("category",scope,label,Record.Combine({Record.SelectFields(g,statNames),extras}),g[eligible],g[rank]))),
    CategoryRows=List.Combine(List.Transform(List.FirstN(Scopes,2),each CategoryRowsFor(_[name],_[data]))),
    PriorityGroups=Table.Group(Cohort,{"first_priority"},{{"stats",each Stats(_),type record}}),
    MissingPriorityRows=List.Combine(List.Transform(Table.ToRecords(PriorityGroups),(g)=>Rows("missing_by_priority","All priorities",if g[first_priority]=null then "Unknown priority" else g[first_priority],g[stats],g[stats][case_count],null))),
    Compare=(t as table) as record =>
        let z=Table.SelectRows(t,each [reassignment_band]="0"),h=Table.SelectRows(t,each [reassignment_band]="3+"),ze=Table.SelectRows(z,each [resolution_eligible]=1),he=Table.SelectRows(h,each [resolution_eligible]=1),zn=Table.RowCount(ze),hn=Table.RowCount(he),zm=Median(ze[resolution_days]),hm=Median(he[resolution_days])
        in [cases0=Table.RowCount(z),cases3plus=Table.RowCount(h),eligible0=zn,eligible3plus=hn,coverage0=Ratio(zn,Table.RowCount(z)),coverage3plus=Ratio(hn,Table.RowCount(h)),median0_days=zm,median3plus_days=hm,difference_days=if zm=null or hm=null then null else hm-zm,comparison_supported=if zn>=30 and hn>=30 then 1 else 0],
    Strata=Table.Group(Cohort,{"first_category","first_priority"},{{"data",each _,type table},{"comparison",each Compare(_),type record}}),
    EligibleStrata=Table.SelectRows(Strata,each [comparison][comparison_supported]=1),
    WithCombined=Table.AddColumn(EligibleStrata,"combined_cases",each [comparison][cases0]+[comparison][cases3plus],Int64.Type),
    Top=Table.FirstN(Table.Sort(WithCombined,{{"combined_cases",Order.Descending},{"first_category",Order.Ascending},{"first_priority",Order.Ascending}}),3),
    StratumRows=List.Combine(List.Transform(Table.ToRecords(Top),(g)=>let stable=Table.SelectRows(g[data],each [priority_changed]=0 and [category_changed]=0),label=g[first_category] & " / " & g[first_priority] in Rows("stratum","All priorities",label,g[comparison],g[combined_cases],null) & Rows("stratum_stable","All priorities",label,Compare(stable),Table.RowCount(stable),null))),
    Output=Table.Buffer(Table.FromRecords(ScopeRows & BandRows & CategoryRows & MissingPriorityRows & StratumRows, type table [key=text,#"section"=text,scope=text,group=text,metric=text,value=nullable number,denominator=nullable number,review_rank=nullable number])),
    Unique=if Table.RowCount(Output)<>List.Count(List.Distinct(Output[key])) then error "Duplicate analysis lookup keys." else Output
in
    Unique
