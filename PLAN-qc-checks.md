# Plan: a QC check suite for HH, HL and CA

**Drafted:** 2026-09-08. **Status:** proposal, pseudocode only, nothing built.
**Spans two packages.** Field-level rules (vocabulary, range, required,
sentinel) are *spec* and belong in **opus**; structural, arithmetic and
distributional rules are *analysis* and belong in **obus**. Sections are
tagged `[opus]` / `[obus]`.

Every number in §2 was measured against the live archive on 2026-09-08; the
provenance of every rule in §3 is named. Nothing here is inferred from the
DATRAS package or from `obus_retired`.

---

## 0. The elephant, located

The premise was that ICES's upload screening is a black box. It is **mostly
not** — three ICES publications between them describe the check set, and one of
them is an inventory with ICES's own verdict on each check. What is missing is
the current *implementation*, not the *design*.

### 0.1 What is published

| Source | What it gives | Where |
|---|---|---|
| **WKDATR 2013, Annex 5** — "Review of field ranges and error checks" | **The check inventory.** Over 80 check messages, each tagged `Validity` / `range` / `crosscheck` / `outlier`, with the fields it applies to, plus a colour-coded ICES verdict (`ok`, `check does not seem correct`, `question about the check`). Then **per-survey, per-field check tables** for BITS, BTS and NS-IBTS × HH/HL/CA — 370 rows, 142 with numeric bounds, each carrying `error`/`warning` and a "should -9 be allowed?" column. | `imbus/DATRAS/external/WKDATR13.md`, Annex 5 (pp. 29–40); extracted to `WKDATR13_field_ranges.csv` |
| **D2.2 "Field Dependency" guideline** | **The count chain, authoritatively.** `SubsampledNumber = SUM(NumberAtLength)`; `TotalNumber = SubsampledNumber × SubsamplingFactor`. Plus the `DataType` → `SubsamplingFactor` rules, pseudocategories, and the `SpeciesValidity` 1/4/7 field-dependency table. | `imbus/DATRAS/external/D2.2 exchange data guideline for data use of Field Dependency.md` |
| **WKDATR 2013, §3.2.1.3 + §3.2.2.1** | **Four checks ICES agreed to add**, with worked examples, plus three it asked the survey groups to run. See §0.4 — they overlap the families below almost exactly. | `WKDATR13.md`, report pp. 7–11 |
| **WKDATR 2013, Annex 4** | ICES's own **inventory of 27 DATRAS issues** (19 product, 8 submission), each with theme, survey, agreed solution, owner and status. | extracted to `WKDATR13_issues.csv` |
| **WKDATR 2013, Annex 4c** | Which **DATRAS products each survey group was to check** — 10 products × 12 surveys, 44 Y of 120. | extracted to `WKDATR13_products_by_survey.csv` |
| **WKDATR 2013, §3.1** | Four product-level defects ICES documented in its own products — see §0.5. Includes the statement that DATRAS products **ignored `LngtCode`** when aggregating length. | `WKDATR13.md`, report pp. 4–7 |
| **WKDATR 2013, Annex 6** | The **27 actions** WKDATR agreed, each cross-referenced to the section it came from. Doubles as an index of every finding anyone was meant to act on. | extracted to `WKDATR13_actions.csv` |
| **DATSU `rptChk.aspx`** | The **check-message templates still in production**, for the formats DATSU screens today. Public, no token: `https://datsu.ices.dk/web/rptChk.aspx?Dataset=<id>`. | live |

DATRAS's own FAQ states the position plainly: files pass DATSU, "screening
includes many logical, value, and vocabulary checks", critical errors block
upload, warnings do not, and "the list of survey-specific DATSU checks for each
survey can be found via DATSU Checks."

### 0.2 What is genuinely not available

- **DATRAS is no longer in DATSU's public format list.** Scanned dataset IDs
  1–200 on `rptChk.aspx` on 2026-09-08: 38 formats are listed and **none is
  DATRAS**. Trawl-survey screening has moved behind the DATRAS upload page.
- **The `getListQCChecks` API — which returns each check's actual T-SQL
  expression — is down.** Every `GET` on `https://datsu.ices.dk/api/` returns
  `400 "There was an exception"` (`getDataverIDs`, `getRecordIDs/{id}`,
  `getListQCChecks/{id}`), so `icesDatsuQC::runQCChecks()` cannot run either.
  The OpenAPI spec at `/api/swagger/v1/swagger.json` is served and lists the
  endpoints, so this reads as a broken backend, not a withdrawn service. **Worth
  a retry, and worth asking ICES about** — if it comes back for DATRAS's format
  ID, the check set arrives as executable SQL and most of §3.1–§3.6 below is a
  port rather than a design.
- Three formats do reuse DATRAS-lineage record types and their check text is
  readable today: **157 Stomach Content** (`HH - Haul Information`), **154
  Fecundity** (`HH`), **168 DC-Collecting Bags** (`HL`, `CA - SMALK`). Useful as
  a template for message wording and error/warning typing, not as the DATRAS set.

### 0.3 The asymmetry that shapes everything below

ICES screens the **exchange file at submission**. obus reads the **archive after
ingest**. These are not the same object, and the difference partitions the
check set three ways:

- **Unavailable to obus** — field counts, blank/empty lines, delimiter
  detection, "too few fields in HL records", one-country-per-file,
  one-ship-per-file. The file is gone; only its parsed content survives.
- **Re-runnable by obus** — vocabulary, range, required, key uniqueness,
  referential integrity, field dependency, the count chain, plausibility. This
  is the bulk, and §3 is about these.
- **Only visible to obus** — anything ICES runs as a *warning*, or does not run
  at all, or ran under a rule that has since changed. **This is the valuable
  part.** A check suite that only reproduces the blocking errors will find
  nothing: by construction, no record carrying one is in the archive. The suite
  earns its keep on the warnings that were waved through and on the periods
  screened under weaker rules.

### 0.4 ICES proposed four of these checks itself, in 2013

WKDATR §3.2.1.3, "Additional checks on submission" — "*Four simple checks were
agreed as a first pass*", aimed at trapping "*significant anomalies*" and
explicitly **not** replicating national checking:

1. **HL: `SUM(NumberAtLength)` vs reported `TotalNumber`**, per
   **Haul/Species/Sex/Category**. Worked example, 607,831 vs 605,358 — a
   2,473-fish gap. *That grain is ICES's own*, and it independently corroborates
   both §3.7's grain and `KEY_HL_DUP`: **`CatIdentifier` is part of the key.**
2. **HL: Sample Weight-Condition Index** per Haul/Species/Category/Sex — predict
   a crude weight per fish, sum over the length frequency, compare to the
   reported sample weight. ICES proposed **`W = L³`**; obus's `length_weight`
   fits `a` and `b` per species, so §3.11's check is **strictly better than the
   one ICES specified**. Their framing is worth keeping though: "*best viewed
   graphically*", limits "*for reference only*", "*trap obvious anomalies here,
   not scrutinise the tails of a normal distribution*".
3. **CA: Individual Weight Condition Index**, the same on observed weights.
4. **Number vs weight over a time series** — catches **g/kg unit errors**. Their
   example: megrim at 5 g/fish in 1990 rising to 6,305 g/fish in 2009. This one
   was **missing from §3 and is now added** as `BIO_MEAN_WEIGHT_SHIFT`. Note it
   is inherently a *regime* check: "*this can be reviewed over a time-series as
   well as within a survey year*."

§3.2.2.1 then asks the survey groups to run three more, each landing in a family
below:

- **Species coding** — DATRAS moved TSN → AphiaID in 2012, so "*some unintended
  errors in species recording may have occurred*"; cross-check 2012–13 species
  against a 2000–2010 historic list. A concrete, era-aware `vocab` check.
- **DataType and Subfactor** — ICES Data Centre had already found "*non-
  consistent input for the DataType-Subfactor combination*" and was to supply a
  list **by survey-year-quarter-country**. The same finding as
  `data-raw/CHECK_cpuel_multiplier.R`, at the same grain as §3.12.
- **Speed, distance, haul duration, shooting/hauling positions** — §3.9 + §3.10.

**What this means for the plan.** These families were arrived at here
independently and then found to match what ICES itself proposed — reassuring
about the design, but also the sharpest argument for building it: the checks
were **agreed in 2013 and the archive still shows the problems**. Agreement is
not implementation. The value is not in proposing them again; it is in running
them over the whole archive and reporting by year, which is the one thing a
submission-time check cannot do.

### 0.5 What §3.1 says about ICES's own products

Section 3.1 is not about submission checks — it is ICES recording four defects
in the **products it publishes**. Three matter directly here.

**Length units were not honoured in aggregation (§3.1.1).** "*Some species are
measured to the mm below, others to the half cm below, and others to the cm
below. The current products do not reflect this difference.*" Action 1 in Annex
6 is for the Data Centre "*to take the measurement unit as provided in
`LngtCode` as the leading unit for the aggregation of length data*". Two things
follow:

- It is ICES's own confirmation that **`LengthClass` is a lower bound** — "to
  the mm/half cm/cm *below*" — for every unit, which is what opus's YAML already
  says and what `dr_add_length_mid()` depends on.
- It means the published length products were, as of 2013, aggregating across
  mixed units. obus carries `LengthCode` through to `HL_length` and so does not
  inherit this, but it is a reason to treat any ICES length product from that
  era as suspect rather than as a reference to reconcile against.

**BITS positions were allocated to the wrong subdivisions (§3.1.2).** Found by
"*a consistency check between DATRAS products and the survey group
calculation*". The fix proposed is polygon-based assignment, with all historical
assignments cross-checked "*either directly or by proxy (i.e. comparing
haul-based cpue values)*", and — worth noting for §3.9's severity — "*any
breaches of the polygon rules raises an error, not a warning*". So BITS
`AreaCode`/subdivision before that fix landed is a **documented defect, not a
hypothesis**.

**Re-submission silently changes products (§3.1.3).** End-users asked for
versioning. Table 3.1 is ICES's own template for reporting the effect of a
re-submission, and its grain is
`survey × country × year × quarter × subarea × species`, with a **`Difference`**
column and upload/calculation dates for both versions. That is §3.12's design,
specified by ICES in 2013 — including the point that what matters is the
*difference*, not the new value alone.

**And §3.1.4 states the gap plainly:** "*for pre-existing DATRAS products there
are no clear quality checks available at present*", with checking split into
"*(1) the data selection made, (2) the algorithm itself, (3) the outcome*". That
three-way split is a good frame for the whole suite: §3.1–§3.8 check the
outcome, `CHECK_cpuel_multiplier.R` checks an algorithm, and the data selection
is what `HaulValidity`/`SpeciesValidity` filtering decides.

### 0.6 Nothing in Annex 6 is recorded as done

Annex 6 lists **27 actions** across 19 sections, with columns `Nr | Description |
Section | Who | When | Status`. ICES Data Centre owns 12, the survey-group
chairs 11. **Every one of the 27 `Status` cells is blank.**

That is not proof nothing happened — it is a 2013 report, and the status column
was presumably for later use. But combined with §2's measurements it is the
sharpest argument in this document: the count-chain conformance plateau at ~85%
persists in data submitted a decade after action 11 ("*review proposed new
checks on submission*") was agreed. Three actions (25, 26, 27) cross-reference
Annex 4 items, so `WKDATR13_actions.csv` joins to `WKDATR13_issues.csv` on those.

**Use it as a checklist.** For each of the 27, ask whether the archive shows the
action was taken. That is a bounded, concrete piece of work, it needs no new
design, and each answer is either a check that can be retired or a finding worth
sending to ICES.

---

## 1. Design decisions

**1. Flag, never filter.** No check drops or edits a row. Output is a side
table joined by key, exactly as `hl_flag` already is — and for the same two
reasons: revising a code costs a small republish rather than a 200 MB one, and
readers who do not want flags pay nothing.

**2. Reuse `hl_flag`'s `kind` taxonomy — do not invent a second one.** It has
**five** values, already in `data-raw/hl_flag_code.csv`, and the fifth is easy
to miss and matters most:

| kind | groups | what it means |
|---|---|---|
| `property` | 1,050,534 | a fact about the record — no lengths, no weight, factor absent |
| `intrinsic` | 185,246 | the two totals legitimately differ; neither is wrong |
| `suspect` | 20,332 | likely a submission problem, direction known |
| `unexplained` | 4,296 | flagged, mechanism not established |
| `inflated` | 1,700 | **obus's own output overstates a value** |

This is the single most important decision in the document, and it is
load-bearing because of a measured fact: `hl_flag` marks 1,262,108 of
2,291,457 groups, and only **22,031 of all 2,291,457 groups (0.96%)** carry
`suspect` or `inflated`. Better than nine in ten flagged groups are recording a
legitimate property of the sampling design. A suite that reports a bare count of
flagged records reports noise.

`kind` is therefore not a severity synonym — it is a **routing label**, and each
value goes to a different person:

- `suspect` → the survey coordinator. A submission problem with a known direction.
- `unexplained` → the analyst. The rule and the data disagree and nobody has
  worked out why. Small, and the queue where new understanding comes from.
- `inflated` → **obus's own bug queue.** Never escalate this to ICES. opus
  makes the same distinction with its `opus-internal` scope in
  `DATRAS-known-issues.yaml`; keep the two consistent.
- `property` / `intrinsic` → collapse to one line in any report. This is the
  99% and it is not news.

**3. Every rule is era-tagged.** Code lists and rules have changed, and the
changes are documented: `LengthCode` 2 and 5 disallowed from 2004 (BITS/IBTS),
`SpeciesValidity` 9 disallowed from 2004, `HaulValidity` V and N only for TVL/TVS
since 2002, NODC and ITIS TSN species codes retired in favour of AphiaID. A
rule applied outside its era manufactures failures. Each code therefore carries
`era_from` / `era_to`, and a record outside a rule's era is **not checked**, not
failed.

**4. Ranges are per survey, not global.** WKDATR13's range tables are indexed by
survey for a reason: BITS `ShootLat` is 53–66, and the same bound on Can-Mar is
meaningless. `[opus]` The dictionary's 102 `range:` entries are currently
global — that is a real gap, and the fix is a per-survey override block, not a
widened global range, which would silently disable the check everywhere.

**5. Report the whole archive by year; gate pass/fail on a recent window.** §2
is why.

---

## 2. The chronology finding

The suspicion that older data is worse is **correct, strongly, and measurable** —
but it does not license simply discarding the past, and the shape of the decline
is more useful than the fact of it.

**Coverage.** HH spans 1965–2026, 150,217 hauls, 22 surveys per year since 2016.
2026 holds 729 hauls from 3 surveys — a partial year, and it must be excluded
from any trend or gate, not read as a collapse.

**Count-chain conformance by year.** Groups formed at
`.id × Valid_Aphia × SpeciesCategory × SpeciesSex`, testing D2.2's
`TotalNumber = SubsampledNumber × SubsamplingFactor`:

| Period | `SubsampledNumber` present | Count chain holds |
|---|---|---|
| 1977–1995 | 36–88% | **9–26%** |
| 1996–2003 | 47–76% | 36–71% |
| 2004–2008 | 85–86% | 75–80% |
| 2009–2017 | 82–86% | 79–82% |
| 2018–2025 | 79–92% | **84–87%** |

Three things follow, and the third is the one that matters:

1. **The improvement is real and monotone-ish**, and it is not gradual drift —
   it steps at 1996 and again at 2004, which is when the rules themselves
   changed. The `SubsampledNumber` column tells the same story: absent for half
   of all groups 1985–2001, present for ~85% from 2004.
2. **A gate at 2004 is defensible; one at 2009 is comfortable.** Before 1996 the
   documented identity simply does not describe the data, and running the check
   there produces a wall of failures that says nothing about any individual
   record.
3. **Conformance plateaus at ~85% and never approaches 100%.** So the residual
   in recent data is *not* a defect rate — it is the documented sampling
   design showing through: `DataType` C, pseudocategories, `SpeciesValidity`
   4 and 7. This is precisely the `property`-versus-`unexplained` split in
   decision 2, and it is why the target for a modern year is **"no growth in
   `unexplained`"**, never "zero flags".

*Caveat, stated because it bounds the numbers above:* `AGENTS.md` records that
both catch tables have a **finer grain than their documentation claimed**. The
grouping used here may therefore be coarser than HL's true grain, which would
collapse genuinely distinct sub-units and *overstate* non-conformance. Read the
table as an upper bound on failure and a reliable guide to *shape*, not as a
validated per-record rate. Settling the grain is a prerequisite for §3.7, not
for the trend.

---

## 3. The check families

Notation. `flag(CODE, keys...)` appends to `qc_flag` (§4). `era(from, to)`
gates by `Year`. `by_survey(...)` means the threshold is looked up per survey.
Grain: `.id` is obus's eight-field haul key; `row_key` identifies a record
within a table.

### 3.1 Vocabulary — "Field value is invalid" `[opus]`

The largest family and the cheapest. 48 enum fields in the dictionary; opus
already resolves code lists via `op_vocab_get_codes()`.

```
FAMILY vocab
for each (table, field) with type == enum or a resolvable icesVocab key:

  CHECK  VOC_<FIELD>_UNKNOWN                 kind: suspect      severity: error
    era    era(field)                         # per decision 3
    rule   value NOT NULL  AND  value NOT IN codes(field, era = Year)
    emit   flag(VOC_<FIELD>_UNKNOWN, table, row_key, field, value)

  CHECK  VOC_<FIELD>_RETIRED                 kind: property     severity: info
    rule   value IN codes(field) BUT code withdrawn before Year
    note   the interesting direction: a code legal when submitted and not now.
           NOT a defect -- it dates the record. Never severity error.
```

Two traps, both already paid for once in this project:

- **`op_vocab_resolve_datras_key()` exists because vocabulary keys do not
  resolve by field name.** `Survey` resolves to a real icesVocab list of 133
  cross-domain ICES survey IDs (`A1012`-style) that has nothing to do with
  DATRAS's survey acronyms. Resolving by name and trusting the hit would fail
  every HH row. Go through opus's resolver, never `icesVocab::getCodeList(field)`.
- **Sentinels are not vocabulary violations.** `-9` is a legal answer. Worse,
  `HH.Tickler`'s `-9` is a *documented icesVocab code meaning "no ticklers"*
  carried by 78% of HH rows. Exclude sentinels via `op_sentinels()` before this
  family runs, or it reports the archive's most common correct value as broken.

### 3.2 Range — "Not in the range specified" `[opus]` spec, `[obus]` run

Annex 5's tables are now extracted to
`imbus/DATRAS/external/WKDATR13_field_ranges.csv` (370 rows, 142 of them
carrying bounds, by `extract_wkdatr13_ranges.py` in the same directory). Two
things that table settles:

- **The bounds really are per survey.** 16 of the 33 `(record, field)` pairs
  with bounds in more than one survey *disagree* — `ShootLong` is 9..30 for
  BITS, -4..13 for NS-IBTS, -12..10 for BTS; `HaulDur` 0..90 vs 5..90 vs 15..60.
  A single global range would have to be their union, which disables the check
  everywhere. This is the concrete form of the §1.4 gap.
- **Coverage is 3 surveys of the archive's 29.** BITS, BTS and NS-IBTS only. For
  the other 26 there is no published range table, so `RNG_*_NO_BOUND` is not a
  nicety — it is most of the archive.

`field_no` in that file is **offset by one** from today's format: WKDATR13
numbers HH as 1=RecordType, 2=Quarter, with no `Survey` field, which ICES added
later. With `field_no + 1`, 77 of 81 names agree with opus's field order; the
remaining 4 are ICES renames since 2013 (`GearExp`→`GearEx`,
`Stratum`→`DepthStratum`, `BycSpecRecCode`→`BySpecRecCode`, `AgeRings`→`Age`),
carried in the `field_current` column. Both facts were verified against
`op_field_spec()` and opus's legacy dictionary, not inferred from similarity.

```
FAMILY range
source imbus/DATRAS/external/WKDATR13_field_ranges.csv  (filter min != "")
       + the dictionary's 102 range: entries

  CHECK  RNG_<FIELD>_OUT                     kind: suspect      severity: by_survey
    scope  fields with a range for this survey and era
    rule   NOT sentinel(value)  AND  value NOT BETWEEN by_survey(field).min
                                                    AND by_survey(field).max
    emit   flag(RNG_<FIELD>_OUT, table, row_key, field, value, bound_hit)

  CHECK  RNG_<FIELD>_NO_BOUND                kind: property     severity: info
    rule   field has no range for (survey, era)
    note   coverage bookkeeping, not a data finding. Prints as "what is NOT
           being checked", which is the honest denominator for the whole family.
```

**Every range row now carries ICES's verdict on it**, recovered from the
report's cell colours — `verdict` / `fill_hex`, via
`extract_wkdatr13_colours.py`. Only **66% are `ok`**:

| verdict | rows | share |
|---|---|---|
| ok | 246 | 66% |
| **remove check** | 29 | 8% |
| **change from warning to error** | 26 | 7% |
| suggestion for new error-message text | 21 | 6% |
| question about the check | 20 | 5% |
| **change field range** | 16 | 4% |
| correct, but modifications required | 6 | 2% |
| **add check** | 4 | 1% |
| change from error to warning | 2 | 1% |

**A third of ICES's own field-range checks were flagged for change in 2013.**
Porting them without the verdict would ship 29 checks ICES wanted deleted and 26
at the wrong severity. `Quarter is not consistent with Month` is marked
**remove** in all three surveys — which is why `DEP_QUARTER_MONTH` is `info`
here, not an error.

WKDATR13 carries ICES's own doubts about specific bounds — the length-class
minimum is marked "not true, see length class field ranges", `HaulDur` cannot
be `-9` is queried against dummy hauls and historic records with no shooting
time. **Port the verdict with the bound.** A check ICES itself marked wrong in
2013 should ship as `severity: info` with the objection in `meaning`, not as an
error.

### 3.3 Required and sentinel — "Missing values in mandatory field" `[opus]`

```
FAMILY required
source 65 required constraints in the dictionary; WKDATR13's per-field
       "should -9 be allowed?" column

  CHECK  REQ_<FIELD>_NULL                    kind: suspect      severity: error
    rule   value IS NULL  AND  required(field, table, era)

  CHECK  REQ_<FIELD>_SENTINEL                kind: <from policy> severity: warning
    rule   sentinel(value)  AND  NOT sentinel_allowed(field, table, survey, era)
    note   WKDATR13's -9 column is exactly opus's sentinel policy question,
           already answered per field in DATRAS-known-issues.yaml. Join them;
           do not re-derive. Where the two disagree, that disagreement IS the
           finding -- ICES's 2013 intent versus the archive's behaviour.
```

### 3.4 Key uniqueness — "Duplicate value in record constraint" `[obus]`

```
FAMILY key

  CHECK  KEY_HH_DUP                          kind: suspect      severity: error
    rule   count(*) > 1 over HH's 8-field primary key
    source "There is a duplicate haul number in HH-records"

  CHECK  KEY_HL_DUP                          kind: suspect      severity: error
    rule   count(*) > 1 over
             (.id, Valid_Aphia, SpeciesCategory, SpeciesSex, LengthCode,
              LengthClass, ...)
    source WKDATR13 corrects ICES's own statement of this check: the message
           says "not more than one record per species, length class and sex",
           and the verdict is "not true. Should be: not more than one record
           per CatIdentifier, species, lengthclass and sex". SpeciesCategory
           is part of the key. Ship the corrected form.
    note   PREREQUISITE, not a detail: this check IS the grain question from
           the §2 caveat. Determine HL's true grain by counting distinct
           tuples -- as AGENTS.md records was how the last grain surprise was
           found -- before asserting a key here. Getting it wrong makes this
           check and §3.7 both wrong, in the same direction.

  CHECK  KEY_CA_DUP                          kind: suspect      severity: warning
    rule   duplicate over (.id, Valid_Aphia, LengthClass, IndividualSex,
                           IndividualMaturity, Age, FishID)
```

### 3.5 Referential integrity — orphans and childless parents `[obus]`

```
FAMILY link
source WKDATR13: "Child Record with no parent record (Orphan)",
       "Record with no Child Records", "Mandatory record (HH, HL)",
       "CA record with no HL record for species and length class",
       "If haulno in CA; Haulno must be found in HL record"

  CHECK  LNK_HL_ORPHAN                       kind: suspect      severity: error
    rule   HL row whose .id matches no HH row

  CHECK  LNK_CA_ORPHAN                       kind: property     severity: info
    rule   CA row whose .id matches no HH row
    note   ALREADY MEASURED AND ALREADY DOCUMENTED: 305,276 of 5,968,027 CA
           rows (5.12%) carry no haul number and match no HH row --
           ca_haulno_unlinkable_to_hh in DATRAS-known-issues.yaml. These are
           area-grain age data carrying real ages and counts. kind: property,
           and the suite must NOT propose dropping them to make a join
           succeed. What is worth flagging is a CHANGE in that 5.12%.

  CHECK  LNK_HH_NO_CATCH                     kind: property     severity: info
    rule   valid HH row (HaulValidity == "V") with no HL and no CA row
    note   a genuine zero catch is legitimate and must stay kind: property.
           Distinguishing it from a lost HL submission needs the year profile
           in 3.12, not the record.

  CHECK  LNK_CA_NO_HL                        kind: unexplained  severity: warning
    rule   CA (.id, Valid_Aphia, LengthClass) with no matching HL length row
    note   an aged fish at a length the length-frequency never recorded.
```

### 3.6 Field dependency within a record `[opus]` spec, `[obus]` run

```
FAMILY dep
source WKDATR13 "Field A is not consistent with field B"; the D2.2
       SpeciesValidity table; DATSU's live "Field A is inconsistent with
       field B in child record (rel)" template

  CHECK  DEP_LENGTH_UNIT                     kind: suspect      severity: error
    rule   LengthCode == "1"  =>  LengthClass in cm units
           LengthCode == "."  =>  LengthClass in mm units
           LengthCode == "9"  =>  a plus group; LengthClass constant within
                                  (.id, species)
    note   LengthClass is the LOWER BOUND of the bin, for HL and CA alike --
           already in opus's YAML. Any check that treats it as a midpoint is
           wrong, and it biases weight because W = a*L^b is convex.

  CHECK  DEP_SPECVAL_1                       kind: suspect      severity: error
    rule   SpeciesValidity == "1"  =>  NumberAtLength > 0
  CHECK  DEP_SPECVAL_4                       kind: property     severity: info
    rule   SpeciesValidity == "4"  =>  TotalNumber > 0 AND length fields absent
    source D2.2: code 4 = total number only, length fields MAY be -9
  CHECK  DEP_SPECVAL_7                       kind: property     severity: info
    rule   SpeciesValidity == "7"  =>  category weight present, length absent

  CHECK  DEP_QUARTER_MONTH                   kind: property     severity: info
    rule   Quarter != quarter_of(Month)
    note   DO NOT SHIP THIS AS AN ERROR. WKDATR13's verdict on ICES's own
           check is "REMOVE this check. Rename field 'Survey period'; no check
           on month-quarter combination", and the field description says hauls
           outside the calendar quarter may carry the same quarter reference by
           survey-group agreement. Keep it only as a descriptor.

  CHECK  DEP_AREA                            kind: suspect      severity: error
    rule   AreaCode not valid for AreaType            # CA
  CHECK  DEP_MATURITY_SCALE                  kind: suspect      severity: error
    rule   IndividualMaturity not a stage of MaturityScale
    source live DATSU template, dataset 168 record CA
  CHECK  DEP_PLUSGROUP                       kind: suspect      severity: warning
    rule   Age == sentinel  =>  AgePlusGroup == sentinel
           within (.id or area, species): only the oldest age may be plus group
           if a plus group is defined, ALL records at or above it carry it
```

### 3.7 The count chain — the flagship `[obus]`

D2.2 is the authority, and it **contradicts** the field-description
spreadsheets' `TotalNo = SUM(HLNoAtLngt)`, which omits the raising factor. The
spreadsheet is wrong; do not encode it.

```
FAMILY count
grain  the true HL sub-unit grain (see KEY_HL_DUP -- settle it first)

g = HL
    group_by(<sub-unit grain>)
    summarise(len_sum = sum(NumberAtLength),
              sub     = one_of(SubsampledNumber),
              sf      = one_of(SubsamplingFactor),
              tot     = one_of(TotalNumber))

  CHECK  CNT_SUB_NE_LENSUM                   kind: intrinsic    severity: warning
    era    era(1996, NULL)                   # before 1996 the identity does
                                             # not describe the data (see 2)
    rule   sub present AND abs(sub - len_sum) >= 0.5

  CHECK  CNT_CHAIN_BREAK                     kind: unexplained  severity: warning
    era    era(2004, NULL)
    rule   all of sub, sf, tot present AND abs(tot - sub * sf) >= 0.5

  CHECK  CNT_SF_RESET / CNT_RAISE_LOST       kind: suspect
    rule   tot == len_sum  AND  sf > 1
    note   the raising factor is present but was not applied -- so
           TotalNumber / len_sum IS the lost factor. Already in
           hl_flag_code.csv; carry the codes over unchanged.

  CHECK  CNT_DATATYPE_SF                     kind: <split>      severity: warning
    rule   DataType == "S"  AND  sf <= 1     -> suspect      (D2.2: S => sf > 1)
           DataType == "C"  AND  sf >  1     -> property     (see below)
           DataType == "R"  AND  sf <  1     -> suspect
    note   THE ONE PLACE WHERE AN ICES PUBLICATION IS THE WRONG AUTHORITY.
           WKABSENS 2021 s3.3 step 17 says one multiplier under DataType C;
           the DATRAS package said one until 2023 and two after. obus followed
           WKABSENS for one commit and reverted, then settled it empirically
           against CPUEL -- ICES's own published product -- which applies TWO
           (median ratio 1.000 over 1,721 cells). data-raw/CHECK_cpuel_multiplier.R
           is the reproducible form. Encode what the Data Centre DOES.

  CHECK  CNT_REPEATED_TOTAL                  kind: suspect      severity: warning
    rule   for a candidate splitting dimension d, TotalNumber is IDENTICAL
           across all levels of d within (.id, species) while NumberAtLength
           differs
    note   THE RECURRING FAILURE MODE OF THIS DATA. DATRAS repeats one
           species-level total identically across sub-rows that look like a
           split. Found three times over -- in SpeciesSex, in SpeciesCategory,
           and STILL UNHANDLED in SpeciesValidity. Any new grouping dimension
           is guilty until measured. Summing over d silently doubles the catch.
```

### 3.8 The weight chain `[obus]`

```
FAMILY weight
  CHECK  WGT_CAT_REPEAT_P                    kind: property
    rule   SpeciesCategoryWeight identical across pseudocategories
    source D2.2 example 3.3 -- legitimate under DataType P
  CHECK  WGT_CAT_REPEAT_R                    kind: unexplained
    rule   same pattern under DataType R, where it is not explained
  CHECK  WGT_ZERO_WITH_CATCH                 kind: suspect      severity: info
    rule   TotalNumber > 0 AND SpeciesCategoryWeight == 0
    note   WKDATR13's verdict on ICES's "TotalNo = 0 <=> CatchWeight = 0" is
           "not true. It is possible to have weight only." Weight-only records
           are legal. severity: info.
```

### 3.9 Geospatial `[obus]`, needs external layers

```
FAMILY geo
  CHECK  GEO_ON_LAND                         kind: suspect      severity: error
  CHECK  GEO_STATREC_MISMATCH                kind: suspect      severity: warning
    rule   ices_rectangle(ShootLat, ShootLong) != StatRec
    note   WKDATR13 wants this DOWNGRADED from error to warning. Also: the
           StatRec/AreaCode-to-numeric bug (icesDatras < 1.3-1 turned "nnEn"
           rectangles into numbers) is real and was found in the wild -- treat
           StatRec as character throughout or the check compares nonsense.
  CHECK  GEO_AREA_POLYGON                    kind: suspect      severity: error
    rule   AreaCode disagrees with the polygon containing (ShootLat, ShootLong)
           for that AreaType
    source WKDATR 2013 s3.1.2. A DOCUMENTED BITS DEFECT, not a hypothesis:
           stations were allocated to the wrong subdivisions, found by
           comparing DATRAS products against the survey group's own
           calculation. ICES specifies error, not warning. Needs the polygon
           layers -- which is the same dependency that makes this family last.
    note   the cheap proxy ICES itself suggests, when the polygons are not to
           hand: compare haul-based CPUE against the survey group's values.

  CHECK  GEO_DISTANCE_MISMATCH               kind: suspect      severity: warning
    rule   abs(haversine(shoot, haul) - Distance) > 300 m
    note   AGENTS.md records the neighbouring case: hauls whose end position
           is MISSING, not a zero-length tow -- a fifth of the archive has
           none, and 2,780 repeat the shoot position. Separate the two, or
           every missing position reads as a distance error.
  CHECK  GEO_DEPTH_IMPLAUSIBLE               kind: suspect      severity: warning
    rule   Depth outside +/-50% of a bathymetry lookup      # ICES uses ETOPO2
```

`obus` deliberately dropped the areas/shapes lookups. This family is the one
place the suite needs them back — which is a reason to build it last, or to
leave it to a consumer that already carries them.

### 3.10 Temporal and derived `[obus]`

```
FAMILY time
  CHECK  TIM_TIMESHOT_MALFORMED              kind: suspect      severity: error
    rule   TimeShot not 4 digits, or minutes >= 60
  CHECK  TIM_DAYNIGHT_MISMATCH               kind: suspect      severity: warning
    rule   DayNight disagrees with sunrise/sunset at (lat, long, date)
    note   ICES ships the routine: DATRAS_Sunrise_Sunset_Functions.zip in
           imbus/DATRAS/external. WKDATR13 also records that the legal range
           "should also allow civil day/night calculations", so allow a
           twilight band rather than a hard solar cut.
  CHECK  TIM_DUR_IMPLAUSIBLE                 kind: suspect      severity: warning
    rule   HaulDuration inconsistent with Distance / GroundSpeed
    note   REC_DUR_NONPOS is already in hl_flag_code.csv. And WKDATR13's own
           open question -- "what about dummy hauls? and historic information
           without shooting and hauling time?" -- is unanswered, so this stays
           a warning.
```

### 3.11 Biological plausibility `[obus]`

The family DATSU cannot run, because it needs the whole archive rather than one
file. This is where a post-hoc suite adds most.

```
FAMILY bio
  CHECK  BIO_LENGTH_OVER_MAX                 kind: suspect      severity: warning
    rule   length_mm > max_length(species, survey)
    source the per-survey maximum-length list on the DATSU reporting-format
           page. CAVEAT, from ICES's own FAQ: that list is STATIC and has not
           been updated since January 2011. Species added since have no bound,
           so pair every use with RNG_*_NO_BOUND-style coverage reporting.
           WKDATR13 also asks whether the check "can be done at a species
           level" -- it can, and should be.

  CHECK  BIO_LW_OUTLIER                      kind: suspect      severity: warning
    rule   observed weight vs W = a * L^b outside tolerance
    note   ALREADY BUILT: dr_compare_length_weight(len, smry, lw, tol, flag),
           with length_weight and length_type_conversion published. Convert
           length to TL first (dr_add_length_tl) and use the bin LOWER BOUND
           correctly -- L is convex in W, so a midpoint assumption biases the
           residual. This check is a wrapper, not new work.
           ICES provides weight-length outlier graphs at submission as an
           "additional screening tool" -- i.e. advisory, not blocking. So
           records failing it ARE expected in the archive.

  CHECK  BIO_MEAN_WEIGHT_SHIFT               kind: suspect      severity: warning
    rule   per (survey, country, species, year):
             g_per_fish = SpeciesCategoryWeight / TotalNumber
           flag a year whose g_per_fish departs from the series median by
           about an order of magnitude, or by a clean factor of 1000
    source WKDATR 2013 s3.2.1.3 check 4. ICES's own example is megrim at
           5 g/fish in 1990 and 6,305 g/fish in 2009 -- a g/kg unit error.
           A factor of exactly 1000 is the signature, so report the FACTOR
           and not just the outlier, or the unit error is not legible as one.
    note   H-W6 in section 8 carries the neighbouring observation already
           ("g/fish against the species norm for those blocks"), and H-W4
           the realised BITS case. This is their archive-wide form.

  CHECK  BIO_ALK_INCOHERENT                  kind: unexplained  severity: warning
    rule   age-at-length outside the survey's own age-length envelope
  CHECK  BIO_MATURITY_LENGTH                 kind: unexplained  severity: warning
    rule   mature individual far below the species' smallest observed
           maturity length in that survey
```

### 3.12 Regime detection — the check ICES cannot run at all `[obus]`

Not a per-record rule. A per-`(survey, country, year)` time series **on the flag
rates themselves**, and the reason the suite is worth building rather than just
re-running DATSU.

```
FAMILY regime
profile = qc_flag
          join HH on .id
          group_by(survey, country, year, code)
          summarise(rate = n_flagged / n_records)

  CHECK  REG_STEP                            kind: unexplained  severity: warning
    rule   rate(y) differs from the surrounding years by more than a
           break-detection threshold, in one (survey, country, code) cell
    note   a step change is a SUBMISSION or REPROCESSING event, not a
           biological one. This is the family that catches the class of
           problem AGENTS.md records: a published product disagreeing with a
           fresh build on 33 of 4,880 groups, always by a factor of two,
           because the PUBLISHED FILE was stale. Checking the direction of the
           difference is what distinguished "my port is broken" from "the
           reference is old" -- so REG_STEP must report the SIGN and SIZE of
           the step, never just its existence.

  CHECK  REG_COVERAGE_DROP                   kind: suspect      severity: warning
    rule   a (survey, country) that reported for n years reports no hauls,
           or a field populated for n years goes empty
    note   silent loss of a field is invisible per record and obvious in
           profile. Exclude the current partial year (2026: 729 hauls, 3
           surveys) or it fires on everything.

  CHECK  REG_REPROCESSED                     kind: property     severity: info
    rule   DateofCalculation for a record differs between two snapshots
    note   ICES's own reprocessing timestamp, and it is ALREADY IN THE
           ARCHIVE: populated on 138,643 of 150,217 HH rows (92%), 295
           distinct dates. It records WHEN a record was last recalculated,
           and the reprocessing is done in bulk over history -- one 2021
           calculation pass touches 52 distinct data years, one 2025 pass 34.
           Combined with dated snapshots this identifies exactly which records
           were reprocessed between two dates; recomputing the products then
           says what changed. Caveats: it is a LAST date, not a history, so
           repeat resubmissions collapse to one event; it does not say what
           changed; and 11,574 HH rows carry none.
```

**This is the closest thing available to the facility ICES deferred.** §3.1.3
records that end-users asked for the details of changes between an original and
a re-uploaded dataset, and that "*as there is no facility available for this
yet, the request has been added to Section 4.2.1*". It was never built. But
`DateofCalculation` is published per record, so most of it can be reconstructed
from outside — given snapshots to difference. Which is why §7 starts there.

---

## 4. Output shape

Two tables, following `hl_flag` / `hl_flag_code` exactly — long, keyed, and
separate from the data.

```
qc_flag        one row per (record, code). A record with three codes gets
               three rows; nothing is parsed out of a comma-separated string.
  table        "HH" | "HL" | "CA"
  .id          obus's eight-field haul key
  row_key      identifies the record within table (NULL for HH)
  field        the field at fault, or NULL for a multi-field rule
  code         -> qc_flag_code.code
  value        the offending value, as character (for triage)
  observed     numeric side-car: the gap, ratio or residual, so a consumer
               can threshold without recomputing

qc_flag_code   the lookup, hand-written and reviewed -- NOT generated
  code
  family       vocab | range | required | key | link | dep | count | weight |
               geo | time | bio | regime
  kind         property | intrinsic | suspect | unexplained
  severity     error | warning | info
  affects      count | weight | rate | position | age | both | none
  era_from     era_to
  label        one line, in ICES field terms
  meaning      the full prose, INCLUDING any ICES verdict against the check
  source       the ICES document and section, or the obus CHECK_ script
```

Build-time invariants, copied from `DATASET_hl_flag.R` because they have
already earned their place: **no duplicate codes**; **every emitted code is
documented** (`stop()` if not); **documented-but-not-emitted is a message, not
an error** — a rule that stops firing is worth knowing about, not worth
breaking the build over.

`hl_flag` stays as it is: published, stable, and referenced by two articles.
Its 19 codes fold in as families `count` and `weight`, either by union at read
time or by a later migration once `qc_flag` has settled. Do not rename them.

**Report, not table.** The suite's normal output is the profile, not the rows:

```
qc_report(survey, years, families)
  -> per (year, family, kind):  n_records, n_flagged, pct
     with `unexplained` broken out per code, and `property` collapsed to one
     line -- because that is the 99% and it is not news.
```

---

## 5. Where each check lives

| Family | opus | obus |
|---|---|---|
| vocab, range, required/sentinel | **the rule** — dict `values`/`range`/`constraints`, `op_vocab_*`, `op_sentinels()`, era + per-survey overrides as new blocks | runs it over the archive, emits `qc_flag` |
| key, link | keys and `relationships` already declared (8-column composite, `conflicts`) | the counting and the anti-joins |
| dep | the conditional rules, ideally as dict `definitions:` with pre-rendered SQL | runs them |
| count, weight, bio, geo, time, regime | — | **all of it** |

`op_flag_violations()` already adds a `.flag` column for dict-constraint
violations, and `op_validation_problems()` already flattens a report into a data
frame. Families 3.1–3.3 should go through those rather than around them —
`[opus]` gets era- and survey-awareness, and `[obus]` gets a reshape from
`.flag` to `qc_flag`. That is materially less work than a parallel
implementation, and it keeps one vocabulary.

---

## 6. What to build first

Ordered by evidence gained per unit of work, not by family number.

1. **Settle HL's grain** (`KEY_HL_DUP`). It gates §3.7 and it bounds §2. Count
   distinct tuples; do not read it off the documentation, which has been wrong
   about this twice.
2. **Retry the DATSU API and ask ICES about DATRAS's format ID.** If
   `getListQCChecks` returns, most of §3.1–§3.6 becomes a port of executable
   SQL. Cheapest possible action with the largest possible payoff.
3. **`qc_flag_code` for families `count` and `weight` only**, by lifting the 19
   existing `hl_flag` codes into the wider schema. Proves the shape against
   codes whose behaviour is already known, before any new rule is written.
4. **Families 3.1–3.3 via opus**, era- and survey-aware. Highest coverage,
   lowest novelty, and it forces the per-survey range block that §1.4 identifies
   as a live gap.
5. **Walk Annex 6's 27 actions against the archive** (`WKDATR13_actions.csv`).
   No design work, no new code — for each action, does the archive show it was
   taken? Every answer is worth having: either a check to retire, or a finding
   to send ICES. Do this before writing new rules, because it tells you which
   of §3's families are already handled and which never landed.
6. **`regime` (3.12).** Needs nothing external, and it is the only family that
   finds problems in the *archive as a whole* rather than in records.
7. **`bio` (3.11)** — mostly a wrapper over `dr_compare_length_weight()`,
   plus `BIO_MEAN_WEIGHT_SHIFT`, which is cheap and catches unit errors.
8. **`geo` (3.9) last**, or not in obus at all: it is the only family needing
   spatial layers obus deliberately dropped.

**Two standing cautions.**

Do not report a bare flag count. Only 0.96% of all groups carry `suspect` or
`inflated`; a headline count of *flagged* groups would be better than nine
parts noise and would discredit the suite on first contact with a survey
coordinator. Report per `kind`, always.

Do not let a check drive a data change. Every rule here is a hypothesis about
what ICES intended, and WKDATR13 shows ICES disagreeing with a dozen of its own
checks. When a rule and the archive disagree, the rule is the more likely
suspect — and the resolution belongs in the YAML, never in code that quietly
edits or drops rows.

------------------------------------------------------------------------

## 7. How to start

§6 orders the *checks*. This orders the **work**, and the two differ, because
the first thing to build is not a check at all.

**The only criterion that matters on day one is whether iteration 2 is cheap.**
Everything catalogued in §0 failed on exactly that: WKDATR13's 27 actions, its
colour-coded annex, the four checks agreed in §3.2.1.3 — all first iterations,
none ever run a second time, because a second run cost what the first did. A
suite of 12 families that nobody re-runs would be the same failure with better
pseudocode.

So the first build is the ratchet, and it is smaller than the suite, because
the hard part already exists: **13 curated findings in opus's
`DATRAS-known-issues.yaml`.** They took real work to establish. They just
cannot be re-measured, because their extents are prose.

1. **Pin a snapshot** *(hours)*. The archive gets a dated id and a manifest of
   file checksums, and every number anyone states cites one. This is not
   bureaucracy — it is the fix for a live contradiction: the CA-orphan rate is
   recorded as **305,276 of 5,968,027 (5.12%)** in `DATRAS-data-dict.yaml`'s
   relationships block and **288,581 of 5,865,076 (4.92%)** in
   `DATRAS-known-issues.yaml`, and because neither names an archive, nobody can
   say whether that is an improvement or two different snapshots. The
   descriptions disagree too — the dict says "null in the published archive",
   known-issues says "-9, 0 true nulls" and documents the sentinel-scrub bug
   that made it briefly look like null. The dict still carries the pre-fix
   text.

2. **Make the 13 findings measurable** *(a day)*. Each `known_violations` entry
   gains `check_id`, `n`, `denominator`, `snapshot`. No new analysis: the
   numbers are already in the prose, they are just not in fields.

3. **Write the recompute** *(a day or two)*. One query per finding, most a
   single lazy chain over raw tables. The return value is **not a flag table**
   — it is a diff: `finding | recorded n | current n | delta | snapshot pair`.

4. **Run it** *(hours)*. That output is the first artefact in this area that
   can be produced twice.

That is the loop. Everything after is adding rows to a mechanism that already
turns: the WKDATR13 field checks (already extracted, mostly transcription), then
the count-chain families, then the Annex 6 audit as a *generated* report rather
than a written one, then the per-country scorecard — last, because it needs
`kind` routing to be trusted first.

`data-raw/CHECK_wkdatr13_action9.R` is the worked precedent for the audit step:
it answers "did action 9 happen?" for the 26 checks ICES marked *change from
warning to error*, and the answer is **3 consistent with implementation, 5 still
violated, 18 unfalsifiable**. It is also a warning about scope — 18 of 26 cannot
be adjudicated from the archive at all, because compliance was already total.
Any honest audit carries "unfalsifiable" as a first-class verdict.

**What not to do first.** Do not build checks for everything before there is a
baseline to diff against — that yields a flag table nobody reads, which is the
2013 failure in miniature. Do not open with the Annex 6 audit either: without
steps 1–4 underneath it is one more PDF, and that is the disease.

---

## 8. Labelled hypotheses awaiting a test

These are the candidate checks that have a *stated test* but no built check
behind them. They reached this document by a route worth recording: each was
trimmed out of `vignettes/articles/catch-tables.qmd` to keep the article
readable, parked in `TODO.md` because the article was their only home, and
moved here 2026-09-11 because `TODO.md` is for outstanding work and a
hypothesis is not work -- it is a specification for work.

None is a finding. Each names the observation, the rival mechanisms where
there are any, and the measurement that would separate them.

**Where these land in section 3.** H-W4 is already written up as
`BIO_MEAN_WEIGHT_SHIFT` in 3.11, which is the archive-wide form of the BITS
observation below, and `WGT_IMPLAUSIBLE` is the code it would emit. H-W0,
H-W1, H-W3 and H-W8 belong to 3.8, the weight chain. H-C1a/H-C1b and H-W7
belong to 3.7, the count chain. H-W2 is a key-uniqueness question, 3.4.

**Can-Mar's whole-fish disagreement** — 31,047 groups, 41.8% of the residual;
median gap 13 fish, 98% with `TotalNo` higher, 88.2% carrying
`SubsamplingFactor == 1`. Two rival mechanisms, both live:

- **H-C1a — lost raising factor.** A provider-side historical conversion
  dropped the real sub-sampling factor to 1 while `TotalNo` kept the raised
  value, so `TotalNo / length_sum` *is* the lost factor. *Test:* histogram
  `TotalNo / length_sum` over Can-Mar whole-fish groups. Clustering at small
  integers, or a smooth distribution centred well above 1, supports it; a
  distribution centred near 1 with a long tail does not. Stronger still: if
  `CatCatchWgt / SubWgt` recovers a factor above 1 where `SubFactor` reads 1,
  that is close to proof.
- **H-C1b — counted but not measured.** Fish counted into `TotalNo` that never
  entered a length row: a bulk count plus a measured sub-sample, the residual
  never distributed over length classes. *Test:* regress the gap on `TotalNo`
  and on the number of occupied length classes separately. H-C1a predicts the
  gap scales with the length sum; H-C1b predicts it scales with `TotalNo` with
  no length-class term. These separate cleanly.
- **Refuted:** a per-length-class half-fish truncation. `gap / n_length_classes`
  has median 1.000 (Q1 0.333, Q3 3.333), not 0.5, and median gap 13 against
  median 14 occupied classes — far too dispersed for any per-class mechanism.

**Weight-path hypotheses.** All share one instrument that has not been built:
mean weight per fish, `w_haul / n_haul`, stratified by species, which is
biologically bounded within roughly an order of magnitude, so any mechanism
scaling weight without scaling count leaves a self-normalising signature.

- **H-W0 — `SubFactor = CatCatchWgt / SubWgt`.** True arithmetically in the
  Example file (343666 / 8340 = 41.207, and 237 x 41.207 = 9766.059 exactly),
  stated in words nowhere. *Test:* over all HL rows with `SubWgt`,
  `CatCatchWgt` and `SubFactor` populated, compare the ratio with the reported
  factor, stratified by survey x year x `DataType`. This one is still cited in
  the article; the rest below are not.
- **H-W1 — `DataType` C weight standardisation handled asymmetrically.** HL
  row 22 makes `CatCatchWgt` for C a rate. If `w_haul` treats C weights as
  per-haul while `n_haul` back-multiplies C counts by `HaulDuration/60`, then
  `w_haul / n_haul` for C is wrong by `60 / HaulDuration` — roughly a third of
  the archive. *Test:* for the 200 most abundant aphia codes plot median
  g/fish by `DataType`, and within C regress `log(g/fish)` on
  `log(HaulDuration)`. Slope near +1 confirms; near 0 refutes.
- **H-W2 — dropping `SpeciesSex` from the weight key** halves genuinely
  separate per-sex weights that happen to be equal. *Test:* isolate groups with
  >=2 sexes in one `(.id, aphia, SpeciesCategory)` and identical non-zero
  weights; compare their g/fish with single-sex groups of the same species and
  year.
- **H-W3 — `SubWgt` written into `CatCatchWgt` or vice versa.** Adjacent
  fields, both integer grams, only one mandatory. *Test:* H-W0's ratio test
  filtered to ratio ~ 1 and `SubFactor > 1.5`, tabulated by survey x year x
  country.
- **H-W4 — unit errors**, kilograms or 100-gram units in a grams field.
  **A realised case is now located and dated (2026-09-08, found while writing
  datrasdoodle2's plaice chapter).** In **BITS Q1**, catch weight per fish is
  implausible by roughly two orders of magnitude for two country blocks,
  across *every* species checked (cod, plaice, herring):

  | country | affected years | median g/fish in block | first normal year |
  |---|---|---:|---|
  | DK | 1991-1994 | 0.4 - 8.2 | **1995** (201.0) |
  | DE | 1991-2002 | 1.4 - 3.0 | **2003** (224.1) |

  Sweden over the same years reads 155-337 g/fish, which rules out the
  survey, the species and obus's arithmetic and leaves the submission. The
  blocks end abruptly on a year, which is the signature of a corrected
  submission format rather than drift. This matches the IBTSWG 2025
  Table 3.8.1 pattern (`CatCatchWgt` "per 100g (/100)") already cited below.

  **Consequences worth acting on:**
  - `w_haul`/`w_hour` are unusable for BITS before 2003. Any biomass series
    crossing that boundary is wrong by ~100x on most of its early hauls.
  - **No `hl_flag` code fires on it.** The records are internally consistent;
    what fails is a biological plausibility check, and there is no code of
    that kind in the table. Candidate new code — `WGT_IMPLAUSIBLE`, kind
    `suspect`, evidence `derived` — testing `SpeciesCategoryWeight /
    TotalNumber` against a per-species archive-wide reference. That is the
    generic H-W4 test the hypothesis already specifies, now with a known
    positive to validate against.
  - Worth checking whether the same two country blocks are affected in
    the other surveys DE and DK submit to.

  Partly answered: IBTSWG 2025 Table 3.8.1 records a realised case (CEFAS
  NS-IBTS Q1 1978, `TotalNo` "122->244", `CatCatchWgt` "2750->55", comments
  "No per hr (*2)" and "No per hour (*2) per 100g (/100)"). *Test:* per species
  compute the archive-wide median g/fish; per (survey, year, country, platform)
  compute the median ratio to that reference and look for blocks near 1e-3,
  1e-2, 1e2 or 1e3. Discrete blocks confirm; a continuous spread is biology.
- **H-W6 — the 36 P blocks sharing one weight across main categories** are
  either genuinely equal catches or a wider repeat than the pseudo-category
  memo describes. *Test:* g/fish against the species norm for those blocks,
  plus whether `SubWgt` also repeats across main categories — a repeated
  `SubWgt` is much harder to call coincidence.
- **H-W7 — the R duplicates.** The 56 sub-1 kg blocks may be coincidence; the
  153 above 1 kg (matching to the gram, up to 1.9 tonnes, identical
  `TotalNo` in 160 of 209) are not. *Test:* model the coincidence rate — for R
  groups with 2+ categories, what fraction have equal weights as a function of
  weight magnitude?
- **H-W8 — weight with no count.** Groups with a missing `SubFactor` have
  `w_haul` populated and `n_haul` `NA`, so no g/fish diagnostic exists for
  them at all. *Test:* count groups with non-`NA` `w_haul` and `NA` `n_haul`,
  by survey and era. Every g/fish result above is conditioned on excluding
  them, which must be stated.

**Can-Mar `SpeciesValidity = "5"` rows carry real length data**, unlike every
other survey, and ICES documents this as unresolved. Separately, Can-Mar's
lost raising factor accounts for 30,214 of the 73,596 real disagreements
(41%), median gap 13 fish, 98% one-directional -- a documented provider-side
conversion, not something obus can fix. It settles under 3.7 if it settles
anywhere; the H-C1a/H-C1b pair above is the same question asked more
precisely.
