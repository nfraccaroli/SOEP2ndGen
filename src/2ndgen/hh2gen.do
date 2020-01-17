********************************************************************************
*                                                                              *
* Filename: hh2gen.do                                                          *
* Decription: .do file to generate all the demographics and relevant variables *
*   both at household level and at individual level when possible of the       *
*   identified second-generation head of household (as assigned), indicated    *
*   partner and the immigrant parents of the head of household from the        *
*   different datasets included in the German Socio-Economic Panel.            *
*                                                                              *
********************************************************************************

loc filename = "hh2gen"

********************************************************************************
* Log Opening Programs, and Settings                                           *
********************************************************************************

* open log file
capture log using "${LOG_PATH}/${DIR_NAME}_`filename'_${T_STRING}", text replace

********************************************************************************
* Step 1: starting from the second-generation panel, we want to retrieve the   *
*   household identifier for each individual in this panel, to identify all    *
*   the individuals belonging to that household.                               *
********************************************************************************

* use the second-generation panel
u "${DATA_PATH}/2ndgenindv34soep.dta", replace
merge 1:1 pid syear using "${SOEP_PATH}/ppathl.dta", ///
    keepus(hid) keep(match) nogen
duplicates drop hid, force
keep hid

* filter the tracking dataset by hid retrieving the unique identifiers
merge 1:m hid using "${SOEP_PATH}/ppathl.dta", ///
    keepus(pid syear parid sex gebjahr hid cid gebmonat piyear) ///
    keep(match) nogen

* add information of indirect ancestry for whom in the household is
*   second-generation, later we will record it also for direct migrants
merge 1:1 pid syear using "${DATA_PATH}/2ndgenindv34soep.dta", ///
    keep(master match) nogen

********************************************************************************
* Step 2: calculate age. From pgen we get the month of the interview, we use   *
*   it to compare with month of birth and, together with year of interview and *
*   year of birth, we obtain the actual age at time of interview. Where month  *
*   is missing, we just use the year of survey or year of interview.           *
********************************************************************************

* from pgen we get the month of the interview, but we cannot match 
*   all the individuals in the sample
merge 1:1 pid syear using "${SOEP_PATH}/pgen.dta", ///
    keepus(pgmonth) keep(master match) nogen    
* replace negative flags in the variables indicating month and year of birth
*   and month and year of interview + substitute year of interview with
*   survey year when missing
replace gebjahr  = .     if gebjahr  < 0
replace gebmonat = .     if gebmonat < 0
replace pgmonth  = .     if pgmonth  < 0
replace piyear   = .     if piyear   < 0
replace piyear   = syear if missing(piyear)
* generate age using interview timing and year and month of birth
g age = piyear - gebjahr if gebmonat < pgmonth
replace age = piyear - gebjahr - 1 if gebmonat >= pgmonth
replace age = piyear - gebjahr     if missing(pgmonth) | missing(gebmonat)

* fix gender
g female = (sex == 2) if !missing(sex) | !inlist(sex, -1, -3)

********************************************************************************
* Step 3: some demographics. Marital Status, Occupation, Education.            *
********************************************************************************

* retrieve some information about employment and education from the pgen
* TODO: why do we lose 3000 observations? not in pbr_exit, abroad?
merge 1:1 pid syear using "${SOEP_PATH}/pgen.dta", ///
    keepus(                                                                ///
        pgfamstd  /* marital status in survey year                      */ ///
        pgstib    /* occupational position                              */ ///
        pgemplst  /* employment status                                  */ ///
        pglfs     /* labour force status                                */ ///
        pgbilzeit /* amount of education or training in years (see tab) */ ///
        pgisced97 /* ISCED-1997 classification of education             */ ///
        pgpsbil   /* school-leaving degree level                        */ ///
        pgpsbila  /* school-leaving degree level outside DE             */ ///
        pgpsbilo  /* school-leaving degree level GDR                    */ ///
        pgpbbila  /* vocational degree outside DE                       */ ///
        pgpbbil01 /* type of vocational degree (if any)                 */ ///
        pgpbbil02 /* type of college degree (if any)                    */ ///
        pgpbbil03 /* type of non vocational degree                      */ ///
        pgfield   /* field of tertiary degree (if any)                  */ ///
        pgdegree  /* type of tertiary degree (if any)                   */ ///
        pgtraina  /* apprenticeship - two-digit occupation (KLDB92)     */ ///
        pgtrainb  /* vocational school - two-digit occupation (KLDB92)  */ ///
        pgtrainc  /* higher voc. school - two-digit occupation (KLDB92) */ ///
        pgtraind  /* civ. servant train - two-digit occupation (KLDB92) */ ///
        pgisco?8  /* ISCO-88(08) Industry Classification                */ ///
        pgegp88   /* Last Reached EGP Value (Erikson et al. 1979, 1983) */ ///
        pgnace    /* industry occupation (NACE 1.1)                     */ ///
        pglabnet  /* current monthly net labour income in euro          */ ///
    ) keep(master match) nogen

* married and not separated, or registered same-sex relationship
* there is some lack of information about marriage status
g married = (pgfamstd == 1 | pgfamstd > 5) ///
    if !missing(pgfamstd) | (pgfamstd < 0 & pgfamstd != 2)

* employment indicator variable from employment and labour force status
g employed = (pgemplst != 5) ///
    if !missing(pgemplst) & !inlist(pgemplst, -1, -3)
* self-employed indicator variable
g selfemp = inrange(pgstib, 410, 433) ///
    if !missing(pgstib) & !inlist(pgstib, -1, -3)
* civil servant indicator variable 
g civserv = inrange(pgstib, 550, 640) ///
    if !missing(pgstib) & !inlist(pgstib, -1, -3)
* in education indicator variable from occupational position
g ineduc = (pgstib == 11) ///
    if !missing(pgstib) & !inlist(pgstib, -1, -3)
* retirement indicator, some individuals are pre-65 retired
g retired = (pgstib == 13) ///
    if !missing(pgstib) & !inlist(pgstib, -1, -3)

* education in years is available only for those who studied in Germany (?)
g yeduc = pgbilzeit if !inlist(pgbilzeit, -1, -2) & !missing(pgbilzeit)

* college degree information for Germany is messy, so I am using the
*   clear ISCED97 classification provided in the dataset
g college = (inlist(pgisced97, 5, 6)) if !missing(pgisced97)
* abitur is high school degree at the end of gymnasium
g hsdegree = (college == 1 | pgisced97 == 4) if !missing(pgisced97)
* vocational education for Germany is also messy, so I am using ISCED97
*   including middle vocational and higher vocational education
g voceduc = (inlist(pgisced97, 3, 4)) if !missing(pgisced97)
* business and economics related education or training, we use the different
*   categories in apprenticeship, vocational training and civil service training
*   together with the type of tertiary education
local stubvar = "a b c d"
foreach i in `stubvar' {
    g aux`i' = ( ///
        inrange(pgtrain`i', 6700, 6709) | inrange(pgtrain`i', 6910, 6919) | ///
        inrange(pgtrain`i', 7040, 7049) | inrange(pgtrain`i', 7530, 7545) | ///
        inrange(pgtrain`i', 7711, 7739) | inrange(pgtrain`i', 8810, 8819) | ///
        inlist(pgtrain`i', 7501, 7502, 7503, 7511, 7512, ///
            7513, 7572, 7854, 7855, 7856) ///
    ) if !missing(pgtrain`i') & !inlist(pgtrain`i', -1, -3)
}

g aux0 = inlist(pgfield, 29, 30, 31) ///
    if !missing(pgfield) & !inlist(pgfield, -1, -3)
* education or training in financial-related subjects
egen etecon = rowmax(aux0 auxa auxb auxc auxd)
drop aux?

* job prestige classification : the lower the better (?)
*   we use EGP Scale (Erikson et al. 1983) because it is the most complete info)
g egp = pgegp88 if !missing(pgegp88) & pgegp88 > 0

* finance-related job based on ISCO codes
g finjob = (inlist(pgisco88, 1231, 2410, 2411, 2419, 2441, 3429, 4121, ///
    4122, 4214, 4215) | inrange(pgisco88, 3410, 3413) | inrange(pgisco88, ///
    3419, 3421) | inlist(pgisco08, 1211, 1346, 2631, 3311, ///
    3312, 3334, 4213, 4214, 4312) | inlist(pgnace, 65, 66, 67, 70))

* monthly net labour income, mostly not imputed
g pnetinc = pglabnet if pglabnet >= 0

* keep just the generated variables
drop pg* sex gebmonat piyear

********************************************************************************
* Step 4: Identification of the head of household as defined in the GSOEP,     *
*   household information from the individual level for relevant members in    *
*   the households (excluding kids, still in education or retired), average    *
*   values at household level when relevant and some variables as such.        *
********************************************************************************

* the head of the household is defined as the person who knows best about
*   the general conditions under which the household acts and is supposed
*   to answer this questionnaire in each given year
merge 1:1 pid syear using "${SOEP_PATH}/pbrutto.dta", ///
    keepus(stell_h) keep(master match) nogen

* we do have a problem here that also comes from the previous step: missing
*   individuals in pgen are also missing in pbrutto, we are going to drop them
*   since we do not have useful information to exploit
drop if missing(stell_h)

* exclude if household head is not second-generation
g flag_h = (stell_h == 0 & !missing(ancestry))
bys hid syear : egen aux = total(flag_h)
keep if aux == 1
drop flag_h aux

* TODO: given monthly income, identify who has an economic role in the family

* number of household members
bys hid syear: egen hsize = count(pid)

* number of kids in the household

* drop if not head of household, head younger than 18

********************************************************************************
* Step 5: Information about head of household and partner's parents.           *
********************************************************************************




********************************************************************************
* Step 6: Household level variables.                                           *
********************************************************************************





* drop if still in education?
* drop if pgstib == 11

* number of adults in the household
* number of children in the household (count after indicator variable)

* prima finisci a tirare fuori demographics dell'head of household
* poi fai quelle della sposa e quelle di eventuali figli nel nucleo aventi un
* ruolo negli asset della famiglia
* non sappiamo ancora chi è head of household, tiriamo su tutti
* droppiamo quelli che sono ancora in education eventualmente?

* poi fai bioparen length of stay 

* poi household level in riga con assets e liabilities

* poi household level con le cose messe in riga assets e liabilities
* I don't really care about marital status as long as there is a partner
* I care more about how many figli a carico

* trovare un codice per le demo di husband, spouse e figli eventuali 

* parents time of immigration, length of stay in Germany

******


* retrieve relationship with the head of household from pbrutto dataset
* the head of the household is defined as the person who knows best about
*   the general conditions under which the household acts and is supposed
*   to answer this questionnaire in each given year
merge 1:1 pid syear using "${SOEP_PATH}/pbrutto.dta", ///
    keepus(stell_h) keep(master match) nogen
keep if stell_h == 0 
rename (pid parid ancestry) (hpid pid hancestry)
replace pid = . if pid == -2
drop stell_h

preserve
keep if missing(pid)
tempfile subset
save `subset'
restore

drop if missing(pid)

merge 1:1 pid syear using "${SOEP_PATH}/ppathl.dta", ///
    keepus(corigin migback) keep(master match) nogen

merge 1:1 pid syear using "${DATA_PATH}/2ndgenindv34soep.dta", ///
    keepus(ancestry) keep(master match) nogen

replace ancestry = corigin if migback != 3
rename (ancestry migback pid) (sancestry smigback spid)

keep hpid syear ?ancestry ?native ?secgen gebjahr age smigback

* retrieve demographics for the head of household
