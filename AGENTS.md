# obus — DATRAS access layer for R

**Status (2026-10-06):** version 2026.10. All ten published tables are live,
`R CMD check` is clean and the tests pass. Open work is in `TODO.md`. Dated
history — measurements, and how things were found — is in `DEVLOG.md`, and
earlier versions of this file are in git.

------------------------------------------------------------------------

## What obus is

obus is the R access layer for ICES DATRAS. **opus** (`../opus`) owns what a
DATRAS field is called and what type it is, and ships the raw archive with its
dictionary in each file's footer. **obus** owns getting the data into R, the
derived catch tables, and the verbs that turn them into products. obus keeps no
field-name or type knowledge of its own.

**Two connections, one DuckDB connection.**

1. **`dr_con_raw(table)`** — a lazy view over
   `https://heima.hafro.is/~einarhj/datras/raw/{HH,HL,CA,LT}.parquet`: opus's
   field names exactly as staged, no `.id`, nothing derived.
2. **`dr_con(table)`** — a lazy view over what obus builds and publishes at
   `https://heima.hafro.is/~einarhj/datras/`: `HH`, `HL` and `CA` (each the raw
   table plus `.id`), `species`, `HL_length`, `HL_summary`, `hl_flag`,
   `hl_flag_code`, `length_weight`, `length_type_conversion`.

Both open on duckdbfs's cached connection, and that is load-bearing: the
builders join a raw table against `dr_con("species")`, and dbplyr refuses to
join lazy tables on different connections. `opus::op_con()` keeps a private DBI
connection, so `dr_con_raw()` takes from opus only what is opus's knowledge —
where the archive is, and that it must be a directory named `raw`
(`opus::op_archive()`) — and opens the file itself.

**datrasdoodle2** (`../datrasdoodle2`), the book, is obus's practical driver: it
decides what is worth a verb. Correctness of what already exists comes before
building towards it.

------------------------------------------------------------------------

## Working principles

**1. Names come from opus — never guessed, never re-derived.** obus has no
dependency on `icesDatras`. The raw archive carries opus's current names, and
obus reads them as they are.

**2. obus invents no field names.** The derived tables carry opus's names as the
raw archive stages them (`Valid_Aphia`, `SpeciesSex`, …), so one vocabulary
runs from raw to the published products and a join needs no name mapping. A
renaming layer would also hide a real ambiguity: ICES's legacy `Sex` is
`SpeciesSex` in HL but `IndividualSex` in CA. The columns obus creates (`.id`,
`length_mm`, `length_cm`, `accuracy`, `n_haul`, `n_hour`, `n_measured`,
`w_haul`, …) are its own, and named as such.

**3. Sentinel values are never scrubbed automatically.** `-9` and the other
DATRAS sentinels pass through unchanged. A blanket sentinel-to-`NA` scrub can
destroy a column whose values are mostly real codes (`HH.Tickler`), and once
scrubbed the evidence is gone. Converting a sentinel is a per-field,
evidence-based decision, and none is implemented here.

**4. Verify against the real archive before trusting a claim.** Learn what one
row is by counting distinct tuples, not by reading code. When a fresh build and
a reference disagree, the direction of the difference tells "the code is wrong"
from "the reference is stale".

**5. A repeated total is the recurring failure mode of this data.** DATRAS
repeats one species-level total identically across sub-rows that look like a
split — across `SpeciesSex`, across `SpeciesCategory`, and across
`SpeciesValidity`. Treat any grouping dimension as guilty until measured:
summing across a repeated total double-counts it.

**6. R and SQL disagree about `NA`, so anything that aggregates or joins differs
between the two backends until checked both ways.** `NULL = NULL` is unknown in
SQL, so joins on nullable keys use `na_matches = "na"`. `sum(x, na.rm = TRUE)`
over an all-`NA` group is `0` in R and `NULL` in SQL, so aggregations carry an
explicit non-`NA` counter and restore `NA` when nothing was present: *not
weighed* is not *weighed nothing*. The synthetic tests run eager and the build
runs lazy; keep both.

**7. ICES's own documents are the evidence for what a field means — and read
what is already recorded before measuring anything.**
- The evidence is `../imbus/DATRAS/external/` — the field descriptions, the
  DATRAS FAQ, the SISP manuals, the index-calculation steps, the workshop and
  working-group reports — and opus's YAMLs, which carry ICES's field text and
  code labels (`inst/DATRAS-ices.yaml`, `inst/DATRAS-imbus.yaml`).
- Where a converted `.md` twin carries added commentary (the D2.2 guideline),
  cite the original.
- Where ICES contradicts itself, say so rather than pick a side (`TotalNumber`,
  under "The catch tables").
- Authored `.qmd` files and `obus_retired` are pointers to where to look, not
  evidence.
- Before measuring, check this file, `DEVLOG.md`,
  `vignettes/articles/catch-tables.qmd`, the book and the sibling repos. Most
  questions about this data have been asked before. Findings are written up in
  the catch-tables article.

**8. A number in prose is a liability unless it carries an argument.** Measure
everything; write down only what argues. Numbers do three jobs:
- an **invariant** ("unique at this key") belongs in a test that fails when it
  stops being true, and the sentence carries no number;
- a **load-bearing finding** is usually a qualitative claim wearing a number
  (*only*, *none*, *exactly one*): write the stable claim, and keep the dated
  count as evidence in `DEVLOG.md`; if the claim ever breaks, that is a finding;
- a **denominator** is backdrop, and goes.

The test: if the number were 10% different, would the sentence change? Where
magnitude matters, prefer a ratio. `DEVLOG.md` keeps frozen, dated numbers; the
catch-tables article puts load-bearing numbers inline so they re-measure on
render; this file and `TODO.md` carry invariants and qualitative claims. The
general mechanism — pin a snapshot, make findings measurable, recompute as a
diff — is scoped in `PLAN-qc-checks.md` §7.

**9. A quirk earns attention in proportion to whether it moves a product, or
can manufacture a finding.** obus and datrasdoodle2 have two audiences who want
opposite things. The **downstream analyst** wants a few broad products — CPUE by
year, the length distribution over time, the probability of capture, and maps
of each — and is not interested in DATRAS's quirks for their own sake. The
**quirk specialist** (survey coordinators, data managers, QC) works in exactly
those details, and with a concern the analyst does not share: that *their* data
get misread and then used for an agenda other than their own. Every use of the
data has an agenda, the survey scientists' included, though theirs is rarely
stated as one; obus and the book take no side between them. Their job is to make
the limits of the data visible to everyone. Most quirks are real but touch a
minority of the data, and many do not move the broad products at all. Some
touch very little and still manufacture a finding.

So the first question about any quirk is two-sided: **does it change one of
those products, for which species and surveys, and by how much — and could it
produce a trend, a contrast or a map that is not there?** The same test runs the
other way: a quirk can be invoked to dismiss a finding that in fact survives it
("the data are full of problems"). Showing that a product does *not* move is as
much an answer as showing that it does.
- **If it moves a product or can manufacture a finding**, it is a design input.
  A verb handles it (the zero-fill, the `DataType` rule, the lower-bound length
  class), refuses (mixed `accuracy` in `dr_hl_collapse()`), or carries the field
  that lets the analyst see it, and the book shows it where the analyst would
  otherwise walk into it. The cases the book turns on are all of this kind: a
  squid "colonising" the North Sea that is the survey starting to record
  invertebrates; Baltic plaice "twenty-five times" more abundant that is
  `DataType` and gear; an OSPAR decline that depends on whether a species was
  recorded at all (`StandardSpeciesCode`, `BycatchSpeciesCode`).
- **If it does neither**, it is documented in full for the specialist —
  `hl_flag`, the catch-tables article, this file, `DEVLOG.md`, the book's
  appendices — and shapes neither the API nor the book's main text.

Both audiences are served, from different places, and the second home is not a
lesser one: it is where a specialist checks that a claim made from their data
survives the details. The worked example is the two routes to a haul total
(under "The catch tables"): for fish they barely differ, for invertebrates they
differ a lot, so what it changes is which route a column comes from and how it
is named, not a warning attached to every summary. Measuring "does it move the
product, can it make one up" comes before a quirk is written up anywhere a
downstream user will read it.

------------------------------------------------------------------------

## Design rules

The surface is **get -> add -> summarise -> `autoplot()`**: every step returns a
plain tibble, and the last draws it. Each rule that can be checked is a test in
`tests/testthat/test-design.R`.

- **Tidyverse design to the letter:** `dr_` + snake_case verbs, families share a
  prefix (`dr_add_*`, `dr_summarise_*`), first argument `data` (the access
  functions take `table`), descriptors then `...` (bare grouping columns, as in
  `dplyr::count()`; first = x, second = y or colour, species = panels), optional
  arguments after the dots, no `missing()`, no cosmetic plot arguments.
- **One vocabulary:** `table`, `species` (Latin names or numeric `Valid_Aphia`),
  `survey`, `years`, `quarters`, `haulval`, `conf`. Old spellings survive only as
  `lifecycle::deprecated()` arguments; `dr_HL_*`, `dr_add_length_mm`,
  `dr_add_n_and_cpue` and `dr_join_species` are deprecated wrappers that warn
  and delegate to internal copies.
- **dplyr verbs only, lazy or in memory, identical results** (Principle 6). The
  exported functions and the book contain no SQL. The verbs aggregate in DuckDB,
  collect the small summary, and compute intervals in R from counts and sums
  (Wilson for occurrence; a normal approximation floored at 0 for CPUE).
- **No custom stat or geom.** `ggplot(lazy_tbl)` silently collects every row and
  ggplot2's stats run after that, so nothing can aggregate in the database
  through ggplot2. `fortify.tbl_lazy` therefore aborts with a pointer to the
  verbs.
- **Maps are tables of cells.** `dr_add_cell(size = c(1, 0.5))` is the ICES
  rectangle grid, edge-safe (the quotient is rounded before `floor()`, as in
  `ramb::rb_midpoint()`); any verb groups by `cell_lon`/`cell_lat`, and
  `autoplot()` draws the coastline. A numeric column beside the cell (usually the
  year) turns the map into a small series in each rectangle, on one shared
  height scale set by `autoplot(top = )`, a function of the plotted values that
  defaults to the 95th percentile so that one extreme rectangle does not flatten
  the rest. Occurrence is always 0 to 1. Tiles carry no fade for the number of
  hauls; `n_hauls` is in the table for anyone who wants to filter on it.
- **Zeros:** `dr_add_catch(zeros = "hauls")` is literal (every haul passed in);
  `"reported"` is ICES's product rule (the species reported in that survey, year
  and quarter; DATRAS FAQ). The species list is always the caller's explicit
  argument; obus never guesses what was looked for.
- **`dr_add_catch()` reads `HL_summary`.** It carries both routes to a haul
  total — `n_totalnumber` and `n_totalnumber_hour` (as submitted), `n_haul`
  (from the length frequencies) — and does not reconcile them (see "The catch
  tables").
- `dr_add_length_tl()` and `dr_hl_collapse()` stay exported: the book and the
  catch-tables article use them.
- `dr_con()` caches its handles, so repeated calls are fast; the first call in a
  session pays for the connection.

------------------------------------------------------------------------

## Scope and the server

- `dr_con_raw()` serves `HH`, `HL`, `CA`, `LT`; `dr_con()` the ten tables above.
  `LT` is served raw only: it is litter data, unrelated to the catch tables.
- `HH`, `HL` and `CA` exist under both connections and differ only by `.id`;
  nothing else is touched. That relation, `dr_con(tbl) == dr_con_raw(tbl) +
  ".id"`, is the tested contract. Their columns are not pinned in
  `PUBLISHED_SCHEMA`, because those names are opus's (Principle 1). They exist
  so that a join to HH does not pay `dr_add_id()` over the whole of HL or CA
  every time.
- **Every file on the server is owned by a build script.** A published file that
  nothing reads is invisible, not harmless: `dr_con()` refuses names it does not
  know, which hides a stale file rather than exposing it. ICES products mirrored
  at the server root (`CPUEL.parquet`, `FL.parquet`) are deliberate; the article
  and the book read them directly, and `dr_con()` does not serve them.
- **`obus_retired`** (`../obus_retired`, local only) is a reference, never a
  source of settled fact. Left out on purpose, and reintroduced only when
  something real needs them: `dr_settypes()`/`dr_translate()`,
  `dr_HL_standardised()`, `dr_add_record_type()`, `dr_add_starttime()`, the areas
  and shapes lookups, the `dr_check_*` family, and the swept-area family
  (`obus_retired/R/dr_swept_area.R`), which waits on a choice of method
  (`TODO.md`). A name from those lists describes retired code, not something
  callable.

------------------------------------------------------------------------

## Record layer and analysis layer

**`HH`, `HL`, `CA` are the record layer**: the exchange tables as opus staged
them, plus `.id`. Nothing aggregated, nothing dropped, sentinels intact.

**`HL_length` and `HL_summary` are the analysis layer**, derived from HL. They
are not redundant with the record layer, and conflating the two is the mistake
to avoid.

- **The analysis layer is faithful.** `HL_length`'s `n_haul` reproduces
  {DATRAS}'s own `Count` for every species and survey; no cell differs by half a
  fish. One divergence is deliberate: where `SubsamplingFactor` was never
  submitted, {DATRAS} assumes 1 and obus returns `NA`, because ICES makes the
  field mandatory.
- **It is not lossless.** Where several raw rows meet in one output row,
  `SubsamplingFactor` and `SpeciesCategory` are collapsed away. Absent at this
  grain: `SubsampledNumber`, `SubsampleWeight`, `SpeciesCodeType`, the
  per-category `SpeciesCategoryWeight` (`w_haul` is summed to the species), and
  sex-specific weight, which the source data do not carry.

| task | layer |
|---|---|
| length spectra, numbers and biomass per haul, CPUE, stratified indices, species composition | analysis (`HL_length` + `HL_summary`) |
| sub-sampling QC, anything keyed on `SpeciesCategory`, per-category weights, provenance, rebuilding an exchange file | record (`HL`) |
| age, individual weight, maturity, age-length keys | record (`CA`); obus publishes no CA-derived table, but `dr_get_datras()` assembles one for {DATRAS} |

The first row is demonstrated, not asserted: `dr_get_datras()` builds a
`datras_raw` whose HL comes only from the two derived tables, and
`data-raw/CHECK_datras_adapter.R` runs DATRASextra's own downstream functions on
it unmodified with identical results, including a stratified index;
`data-raw/CHECK_datras_interop.R` is the field-by-field comparison.

**`dr_get_datras()` is the only way into a `DATRASraw` that is not an exchange
file.** {DATRAS} publishes no constructor: `readExchange()`, `readExchangeDir()`,
`readICES()`, `getDatrasExchange()`, `downloadExchange()` and
`DATRASextra::read_datras()` all parse one, `write_datras()` writes one back, and
`addExtraVariables()`, which derives everything beyond the submitted columns, is
unexported. obus reproduces that derivation without {DATRAS} code: a `DATRASraw`
is a three-element list (CA, HH, HL, positionally) with the class
`c("datras_raw", "DATRASraw")`. {DATRAS} is in `Suggests`, used only for the
optional `Roundfish` column. Two limits are inherited and documented on the
function:
- {DATRAS}'s derived quantities are haul × length matrices on HH with no species
  dimension, so everything from `add_numbers_at_length()` on is one species at a
  time. Subsetting *after* deriving looks as if it worked and does not.
- `$.DATRASraw` redirects `x$foo` into HH with partial matching, registered when
  the namespace loads, not when it is attached: use `x[["HH"]]`.

------------------------------------------------------------------------

## The catch tables

**What one row is, asserted in code.** `PUBLISHED_GRAIN` in
`tests/testthat/test-published-schema.R` checks the grain against the code on
synthetic fixtures and against the published files.
- `HL_length` is unique at `.id × Valid_Aphia × length_mm × accuracy ×
  LengthType × SpeciesSex × DevelopmentStage × SpeciesValidity`, and every one of
  the eight is load-bearing. `length_cm` is `length_mm / 10`, carried for
  convenience and not part of the key.
- `HL_summary` is unique at `.id × Valid_Aphia × SpeciesValidity`.

**`SpeciesValidity` is a record type, and partly a quality flag.** ICES's
vocabulary (labels in opus `inst/DATRAS-imbus.yaml`): 1 representative length
information; 2 lengths only for commercial or assessed species; 4 total number
only; 5 presence/absence only; 6 category catch weight only; 7 numbers and
category catch weights, no lengths; 10 lengths and numbers, no catch weights; 0
invalid. ICES is not consistent about which codes feed its products: the DATRAS
FAQ says only 1, the vocabulary labels say most, the BITS index steps use 1 or
`NULL`, WKABSENS uses 1, 4, 7 and 10. Two consequences:
- **Filtering to `"1"` discards real records**, not bad ones — about a fifth of
  `HL_summary`, and every length measurement of the one survey (Can-Mar) that
  puts real lengths on validity-5 records.
- **But in `HL_summary`, a haul-species with several validity records almost
  always repeats the identical submitted total on each**, the count and the
  catch weight alike (Principle 5): a total is taken once, and summing it
  across `SpeciesValidity` double-counts. The length rows behave the other
  way. `HL_length` never repeats a row across validity codes; where two codes
  share a length class they carry different counts, which are separate samples
  and sum. So reducing `HL_summary` over `SpeciesValidity` needs a rule per
  column, and `dr_add_catch()` applies it. `n_haul` is summed. A submitted
  total (`n_totalnumber`, `w_haul` and their per-hour forms) is taken once
  where its values agree, and summed where they genuinely differ, which is
  rare and unexplained. "Agree" allows for float noise, because the build adds
  category totals in no fixed order.

**obus publishes at the finest grain and reduces on request**, never the other
way round: you can collapse down and never back up. `dr_hl_collapse()` is that
reduction. It is a verb on the table rather than an argument to `dr_hl_length()`
because the builder is the minority path (`dr_con("HL_length")` is how the table
is read), and it exists for the two guards a hand-written `group_by()` loses:
the all-`NA` `0`-in-R / `NULL`-in-SQL divergence, and the `DataType == "C"` rule
for `n_measured`. The second needs no `DataType` column: `DataType` is
haul-level and `.id` is never collapsed, so every row of a group shares it and
the all-`NA` guard reproduces the rule. That is also why collapsing `.id` is
refused. `accuracy` and `LengthType` are refused by the data, not the signature:
summing across a 1 cm and a 5 cm bin at the same `length_mm`, or across total
and standard length, invents a count for a bin nobody measured. Such groups are
rare, so the check errors on exactly those, evaluated against the resulting
grain. {DATRAS}'s `addSpectrum()` collapses a mixed `LngtCode` to the coarsest
with only a warning; obus errors and names the group.

**Two routes to a haul total, published side by side and not reconciled.**
- `HL_summary` carries `n_totalnumber` (from `TotalNumber`, as submitted),
  `n_haul` (the raised length frequencies, Σ `NumberAtLength` ×
  `SubsamplingFactor` with the `DataType` handling) and `n_measured` (Σ
  `NumberAtLength`, un-raised; `NA` for `DataType` C, which is a rate).
  `HL_length` carries `n_haul`, `n_hour` and `n_measured` per length class, and
  summing its `n_haul` to `HL_summary`'s grain reproduces `HL_summary`'s `n_haul`.
  When joining the two, sum `n_haul`; do not re-multiply by hand, because
  `n_haul` embeds the missing-factor rule.
- **ICES's own sources disagree on what `TotalNumber` is.** The field
  description says `TotalNo=SUM(HLNoAtLngt)` (opus `inst/DATRAS-ices.yaml`); the
  DATRAS FAQ, the D2.2 guideline and the IBTSWG 2023 report say `NoMeas ×
  SubFactor`, and the IBTSWG calls the specification ambiguous. The field
  description's own example file settles it for the raised reading: its
  `TotalNumber` is the measured count times the sub-sampling factor. Under that
  reading the two routes should agree. The definition also changed in the March
  2024 field descriptions, from a total per haul and species (repeated across
  categories and sexes, so not summable) to a total per category (summable), and
  the archive spans both regimes with no marker in the data.
- **They part in three ways:** where a species was only counted (validity 4-7,
  recorded explicitly), so the length route cannot see it; by rounding from a
  non-integer `SubsamplingFactor`, which grows with sub-sampling and so with
  time; and where a length distribution was submitted twice, which ICES's upload
  rules forbid (one record per category, species, length class and sex) and
  which doubles the length route while `TotalNumber` stays right. A small
  residue among fish is undiagnosed.
- **Whether it matters depends on the species** (Principle 9). For fish the two
  routes agree closely. For invertebrates — counted, not measured, mostly in the
  beam-trawl and shrimp surveys — the length route sees only part of the catch.
  That is a measurement on the archive; ICES's manuals leave benthos recording
  to the institute (SISP 10 §3.1.1).
- `dr_add_catch()` carries `n_totalnumber`, `n_totalnumber_hour` and `n_haul`. A
  length-route rate per hour is `n_haul / HaulDuration * 60`, not yet a column
  (`TODO.md`). Work that needs the length-derived rate uses `HL_length`'s
  `n_hour`, which is that rate. Any new per-haul column must say which route it
  comes from.
- The disagreement between `n_totalnumber` and `n_haul` is also the sharpest
  check that both tables are built right: two fields, two routes, and a residual
  that is real data, not a defect.

**Measured and raised counts are both published, because neither is recoverable
from the other.** `SubsamplingFactor` is not part of `HL_length`'s grain, so one
row can aggregate raw rows raised by different factors. **The raising correction
is largest exactly where the signal is strongest:** as catches grow, the measured
count plateaus — the measuring board saturates — while the raised count keeps
climbing (BITS plaice; figures in `DEVLOG.md`). Publishing only one count removes
the finding rather than adding noise. `n_measured` re-summed across subgroups is
not bit-identical, because some `NumberAtLength` values are fractional.

------------------------------------------------------------------------

## Lengths

- **`LengthClass` is the lower boundary of a length class, not a length**, in HL
  and CA alike: "Lower length boundary of the Length class. In cm or mm depending
  on the LngtCode. E.g. 10-11 cm=10" (opus `inst/DATRAS-ices.yaml`). That is
  harmless for a length distribution, where a class label is wanted, and a real
  bias for weight: \(W = aL^b\) is convex, so the lower bound under-predicts,
  worst for small fish and wide classes, and it does not average out over a haul.
- `dr_add_length_mid()` adds `length_cm_mid = length_cm + accuracy/2`, and
  `dr_add_predicted_weight()` defaults to that column, so a pipeline that skipped
  the step errors instead of returning low weights. The CA fit in
  `DATASET_length_weight.R` uses midpoints too. Both sides matter: fitting on
  lower bounds inflates `a`, which cancels at prediction only if a species is
  reported at the same class width in both tables, and the width mixes of HL and
  CA differ.
- Most code in the mined corpus adds a hard-coded `+0.5`, right only for 1 cm
  classes and used for mean lengths and age-length keys, never for predicted
  weight. DATRASextra's width-aware version is off by one class (`TODO.md`).

------------------------------------------------------------------------

## The haul identifier `.id`

- **`.id` is obus's, not ICES's:** eight fields joined with `:` —
  `Survey:Year:Quarter:Country:Platform:Gear:StationName:HaulNumber`, e.g.
  `BITS:1991:1:DE:06S1:H20:33:28`.
- **It always has eight fields.** A missing field is written as the literal
  `"NA"`, so `.id` splits back into its eight columns, cannot shift fields or
  collide, and is byte-identical to {DATRAS}'s `haul.id`. `"NA"` and not `"-9"`:
  opus has nulled `-9` as a sentinel, and writing it back would manufacture a
  value the archive does not contain (Principle 3). No `StationName` in HH, HL
  or CA is `"NA"`, `"-9"`, empty, or contains `":"`. An all-`NA` key yields `NA`,
  a guard that cannot currently fire, because the first six fields are never
  `NA`.
- **`.dr_concat_ws()` exists because `paste()` cannot be trusted here:** dplyr
  translates `paste(sep = )` per backend — R renders `NA` as `"NA"`, DuckDB's
  `CONCAT_WS()` drops it. The token is substituted before concatenating, and
  every case is tested on both backends.
- `.id` is unique in HH (asserted in `PUBLISHED_GRAIN`). That every HL row
  matches a haul is not asserted anywhere.
- **CA rows that match no haul are published intact** — about one CA row in
  twenty, almost all missing both `StationName` and `HaulNumber`, so their `.id`
  ends `":NA:NA"`. Filtering them would be obus inventing a rule;
  `DATASET_products.R` prints the share on each build. An `inner_join()` to HH
  drops them silently, so `anti_join()` first if it matters.

------------------------------------------------------------------------

## HH: what swept-area work will meet

obus computes nothing from these fields today; whatever builds towed distance
needs these facts first.
- **About a fifth of hauls have no haul (end) position**, only the shoot
  position, so any distance-from-positions calculation needs a fallback.
- **Some hauls record an end position identical to the shoot position**, which
  yields a plausible zero-distance tow rather than an honest `NA`. It is
  concentrated in a few countries (Russia and Estonia far above Norway), and the
  positions are fine-grained, so they were copied, not rounded.
- `obus_retired`'s distance cascade already guards the second (positions enter
  at one tier, capped, and a tier's value is accepted only if positive); a
  missing end position just leaves that tier out. What is not answered is
  reporting: a haul demoted by the guard is indistinguishable afterwards from one
  that never had a position, so coverage needs a report, per the rule that obus
  reports rather than silently repairs.
- **HH's hydrography cannot carry an environmental explanation.** There is no
  oxygen field at all; `BottomSalinity` starts late (none on BITS Q1 hauls before
  2000); and BITS hauls recorded `HaulValidity == "N"` (no oxygen) are
  hydrographically indistinguishable from hauls that fished normally and caught
  nothing. An oxygen series has to come from the ICES oceanographic database,
  outside both packages' scope. What the fields do support is that plaice
  abundance is ordered by `BottomSalinity` within longitude bands — a rival to an
  oxygen story, not a version of one.
- **`HaulValidity`**: I is invalid; C (calibration) is not used in products; A
  is excluded from indices; BITS products use V and N (DATRAS FAQ;
  `Indices_Calculation_Steps_BITS.md`). The published tables keep every code and
  callers filter.

------------------------------------------------------------------------

## Two lookups at one grain, kept in two files

`species` and `length_weight` are both one row per `Valid_Aphia` and stay
separate. They rebuild against different remotes (WoRMS; FishBase and
SeaLifeBase), so a merged table could lose half its columns in a partial
rebuild; and `species` is WoRMS fact while `length_weight` is obus's modelled
inference, which is why it carries `lw_source`, `r2` and `sigma`.
`length_bearing` comes straight from raw HL, so there is no build cycle forcing
a merge.

------------------------------------------------------------------------

## Size and speed

- **DATRAS is not big data.** Every published table collects unfiltered in under
  a minute on a laptop, so `dr_get()` does not warn about an unfiltered pull
  (timings in `DEVLOG.md`).
- **`dr_get_datras(survey = NULL)` is the one heavy call**, because of the
  reshape (binding, joining, factorising), not the download: it peaks at around
  four times the size of its result and needs roughly 10 GB free. Its tables obey
  two identities that serve as a check: its CA is raw CA minus the HH orphans,
  and its HL is `HL_length` plus `HL_summary`'s records with no length data.
- **`head()` is slow on the raw archive only**: a bare `LIMIT` has no predicate
  to push down and opus's row groups are large; obus's own parquet, written with
  `build_helpers.R`'s writer, is quick.

------------------------------------------------------------------------

## Metadata on the derived tables — decided, not implemented

Every raw file opus writes is self-describing (`datras:dict`, `provenance`,
`sentinels`, `coverage`, `known_issues` blocks in the footer, which `op_dict()`
and the other opus readers take out of the file); none of obus's published files
is. The decision:
1. **The format and the writer belong to opus.** If obus invented its own keys or
   JSON shapes, `op_dict()` would stop working on half the published files. opus
   should export the writer, or at least the block schema.
2. **The content for obus's own columns belongs to obus** (`.id`, `n_haul`,
   `n_hour`, `n_measured`, `length_mm`, `length_cm`, `length_cm_mid`,
   `accuracy`, `w_haul`). Principle 1 forbids re-deriving DATRAS names, not
   documenting the columns obus creates.
3. **The source archive's `dict_sha256` is non-negotiable**, so a stale file is
   self-evident rather than invisible. The grain belongs in the block too: a
   machine-readable grain is testable.

It is cheap and keeps the build streaming: DuckDB's parquet writer accepts
key-value metadata and round-trips it, and `duckdbfs::write_dataset()` passes a
multi-element `options` vector through, so `build_helpers.R`'s single
compression option becomes a vector. Quote the JSON with `DBI::dbQuoteString()`,
never a hand-rolled `gsub()`: the known-issues prose contains apostrophes.

------------------------------------------------------------------------

## Implementation

**What lives where** (`R/`). The exported surface is `NAMESPACE` and the
reference index in `_pkgdown.yml`; this is the map, not a second copy of it.
- `dr_con.R` — the two connections, `dr_get()`, and the handle cache.
- `dr_add_id.R`, `dr_transformation.R`, `dr_catch.R`, `dr_cell.R` — the "add"
  verbs. `dr_catch.R` holds `.dr_catch()`, the single engine under
  `dr_add_catch()`, with its catch source injectable so it is testable offline.
  `dr_species.R` resolves Latin names or Aphia codes to the lookup.
- `dr_standardize.R`, `dr_collapse.R` — the builders of the two catch tables and
  the deliberate reduction of them.
- `dr_summarise.R`, `autoplot.R`, `fortify.R` — the summaries, their drawing, and
  the lazy-table guard. Each public verb is split from an internal
  (`.dr_occurrence()`, `.dr_cpue()`, `.dr_length()`) so the statistics are
  testable on synthetic tables.
- `dr_length_weight.R`, `dr_resolve.R` — length-weight, and the shared cascade
  primitive (eager and lazy).
- `dr_get_datras.R` — the adapter to {DATRAS}; a pure reshape split from the
  fetch so it is testable offline.
- `deprecated.R` — the old names, which warn and delegate to internal copies.
- `globals.R` — declared column names.

`NAMESPACE` is roxygen2-generated; never hand-edit it.

**`data-raw/`** builds what the server serves. Run by hand, in order; no script
publishes anything.
- `build_helpers.R` — local mirror of the raw archive (`data-raw/raw`,
  gitignored), the zstd parquet writer, the gitignored output paths.
- `DATASET_species.R` — distinct `Valid_Aphia` from raw HL and CA, resolved
  against WoRMS, to `species.parquet`.
- `DATASET_products.R` — raw HH and HL to `HH`, `HL_length`, `HL_summary`,
  entirely lazily; DuckDB streams straight to parquet.
- `DATASET_length_weight.R` — raw CA, raw HL and `species.parquet`, with FishBase
  and SeaLifeBase, to `length_weight.parquet`. Runs after `DATASET_species.R`.
- `DATASET_length_type_conversion.R` — the traced conversion factors to
  `length_type_conversion.parquet`. No network.
- `DATASET_hl_flag.R` with `hl_flag_code.csv` — the per-record issue codes,
  `hl_flag` and `hl_flag_code`. A flag changes by editing the CSV and re-running
  this script; the catch tables need no rebuild, and the build fails on a code
  the CSV does not document. Filter on `kind` (`property`, `intrinsic`,
  `suspect`, `unexplained`), which says what sort of thing a flag records, not
  how bad it is; most flagged records are properties of the data (a species
  counted but never measured, `CNT_NO_LENGTH`), not defects. obus flags; it does
  not correct.
- `CHECK_*.R` — the {DATRAS} and {DATRASextra} harnesses (`CHECK_datras_adapter.R`,
  `CHECK_datras_interop.R`) and one-off checks against ICES products and
  WKDATR13.
