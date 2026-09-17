------------------------------------------------------------------------

# obus — DATRAS Access Layer for R

**Status:** Rebuilt from an empty `R/`, 2026-08-31; length-weight added
2026-09-02; `n_measured` on `HL_length`, eight-field `.id` and the published
`HL`/`CA` added 2026-09-03; `dr_get()` and `dr_get_datras()` added
2026-09-09. **Version:** 2026.08 — 15 exported functions, all ten published
tables live, `R CMD check` 0/0/0.

------------------------------------------------------------------------

## What obus provides

obus reads the raw ICES DATRAS exchange tables that the sibling `opus`
package stages, and builds the derived catch tables on top of them.

**Two connections, one engine.**

1. **`dr_con_raw(table)`** — lazy DuckDB view over
   `https://heima.hafro.is/~einarhj/datras/raw/{HH,HL,CA,LT}.parquet`:
   opus's current field names exactly as staged, no `.id`, nothing derived.
2. **`dr_con(type)`** — lazy DuckDB view over what obus itself builds and
   publishes at `https://heima.hafro.is/~einarhj/datras/`: `HH`, `HL` and
   `CA` (each raw plus `.id`, nothing else), `species`, `HL_length`,
   `HL_summary`, `hl_flag`, `hl_flag_code`, `length_weight`,
   `length_type_conversion`.

Both open onto the **same** DuckDB connection (duckdbfs's cached one), and
that is load-bearing, not incidental: `dr_HL_length()`/`dr_HL_summary()`
join a raw HL against `dr_con("species")`, and dbplyr refuses to join two
lazy tables on different connections. Verified 2026-08-31 —
`opus::op_con()` keeps its own private DBI connection, so calling it
directly from `dr_con_raw()` makes that join fail with "`x` and `y` must
share the same source." `dr_con_raw()` therefore delegates the part that
is genuinely opus's knowledge (**where** the archive root is, and the
invariant that it must be a directory named `raw`) to `opus::op_archive()`,
and opens the file itself.

obus does NOT maintain its own field-name or type knowledge.

------------------------------------------------------------------------

## What the project does

obus is the R access layer for ICES DATRAS — the "with the spec" half of a
two-package split. opus owns *what a DATRAS field is called and what type
it is*; obus owns *getting it into R and doing something with it*.

obus's practical driver is **`datrasdoodle2`** (a sibling project). When a
design choice is unclear, prefer what that consumer actually needs over
speculative generality.

------------------------------------------------------------------------

## Working Principles

**1. Names come from opus — never guessed, never re-derived.** obus has no
dependency on `icesDatras`. The raw archive already carries opus's current
names; obus reads them as they are.

**2. obus invents no field names.** The derived tables carry opus's current
names exactly as the raw archive stages them, so one vocabulary runs from
raw through to the published products and a join between them needs no
name mapping. obus briefly renamed `Valid_Aphia -> aphia` and
`SpeciesSex -> sex`; that was dropped 2026-09-01 because the benefit was
cosmetic while the cost was permanent -- a `by =` mapping on every
raw-to-derived join, a naming layer `op_crosswalk()` could not describe,
and a latent ambiguity, since ICES's legacy `Sex` maps to `SpeciesSex` in
HL but `IndividualSex` in CA.

**3. Sentinel values are never scrubbed automatically.** `-9` and the
other DATRAS sentinel codes pass through unchanged. opus's own history
documents a real incident where a blanket sentinel-to-`NA` scrub destroyed
a majority-real column (`HH.Tickler`: 78% of rows carry a real documented
code) before anyone noticed — and once scrubbed, the evidence needed to
notice it is gone. Converting a sentinel is a per-field, evidence-based
decision, never a blanket rule, and is not implemented here at all.

**4. Verify empirically, against the real archive, before trusting a
claim.** Everything asserted in this file and in the roxygen was measured,
not reasoned about. Two examples from the 2026-08-31 rebuild, neither of
which was anticipated:
   - The then-published `HL_standardised.parquet` disagreed with a fresh
     build on 33 of 4,880 NS-IBTS 2022 Q1 groups, always by a factor of two.
     The *published file* was stale: it predated the `SpeciesCategory` fix
     its own source code documents. Checking the direction of the difference
     is what distinguished "my port is broken" from "the reference is old."
     (That file was deleted from the server 2026-09-11.)
   - Both catch tables had a **finer grain than their own documentation
     claimed** (see below). Found by counting distinct grain tuples, not
     by reading the code.

**5. A repeated total is the recurring failure mode of this data.** DATRAS
repeats one species-level total identically across sub-rows that look like
a split. It has now been found three times over, in `sex`, in
`SpeciesCategory`, and — still unhandled — in `SpeciesValidity`. Any new
grouping dimension added to `dr_HL_summary()` should be assumed guilty
until measured.

**6. R and SQL disagree about `NA`, so anything that aggregates or joins is
assumed to differ between the two backends until checked both ways.** Two
bugs in one pass came from this and nothing else: `NULL = NULL` is *unknown*
in SQL, so every `NA`-`sex` row failed to match its own expectation and fell
to the fallback collapse (fixed with `na_matches = "na"`); and
`sum(x, na.rm = TRUE)` over an all-`NA` group is `0` in R but `NULL` in SQL,
which silently converted the deliberate zero-duration `NA` straight back into
the false `0` it was meant to prevent — on the eager path only. The
aggregations now carry an explicit non-`NA` counter and restore `NA` when
nothing was present, which also settles the 672,065 rows with no recorded
weight as `NA` on both paths: *not weighed* is not *weighed nothing*. The
synthetic tests run eager and the build runs lazy; keeping both is what
catches these, so neither may be dropped for the other.

**7. Only ICES's own published documents are evidence for what a field
means.** That is `~/R/Pakkar/imbus/DATRAS/external/` — chiefly
`DATRAS_Field_descriptions_and_example_file_December2025.xlsx` (including its
`General Notes` sheet), the SISP manuals, and the ICES workshop and
working-group reports. The authored `.qmd` files one directory up, and
anything in `obus_retired`, are pointers to where to look, not evidence.
Findings get written up in `vignettes/articles/catch-tables.qmd`. (Standing rule
since 2026-08-31; it lived in `TODO.md` until the 2026-09-04 split, where it
was the only entry that was a rule rather than a task.)

**8. The archive grows, so a number in prose is a liability unless it is
carrying an argument.** This does not soften Principle 4 — it is its other
half. Measure everything; *write down* only what argues. A number that was
never the argument is not evidence of rigour, it is an unfunded maintenance
commitment.

Every count obus states goes stale on the next
DATRAS refresh, and re-measuring them all is unbounded work that nobody will
do twice — the same failure §7 of `PLAN-qc-checks.md` diagnoses for opus's
curated findings, which "cannot be re-measured, because their extents are
prose". It has already produced a live contradiction there (the CA-orphan
rate recorded as 305,276 of 5,968,027 in `DATRAS-data-dict.yaml` and 288,581
of 5,865,076 in `DATRAS-known-issues.yaml`, with neither naming an archive),
and a smaller one here: `HL_summary`'s `.id x Valid_Aphia` group count
appears as 2,290,203 in the article and 2,290,235 in `dr_con()`'s roxygen,
two vintages of the same quantity, sitting near a row count of 2,291,457 that
reads like a third.

The cure is not to count less. It is to notice that these numbers do three
different jobs, and only one of them needs re-measuring:

- **An invariant** — "0 duplicated groups at the eight-field key" — is a
  property that must hold forever, not a measurement. Prose is the wrong
  home: it belongs in a test that fails when it stops being true, and the
  sentence should read "unique at this key" with no number at all.
- **A load-bearing finding** — "exactly one record in the archive is ever
  converted", "Can-Mar is the only survey with length data on validity-`5`
  rows" — is where the number carries the argument. But look at what these
  actually are: qualitative claims wearing a number. *Only. Exactly one.
  None. Never.* The qualitative form survives archive growth; the count does
  not. Write the stable claim and let the count be dated evidence under it —
  and if the qualitative claim ever breaks, that is a **finding**, not
  staleness.
- **A denominator** — "of 14,001,605 rows" — is backdrop. It is always stale
  and no conclusion moves when it changes. This is the bean-counting, and it
  is most of them.

The test to apply to any number before writing it: **if this were 10%
different, would the sentence change?** If not, it should not be a number.
Where magnitude genuinely matters, prefer the **ratio**, which is stable
under growth, over the count, which is not: `0.031%` survives the next
refresh and `4,051 groups` does not.

Per file, because the four have different jobs:

- **`DEVLOG.md` — leave it alone.** It is a dated lab notebook, and frozen
  numbers are *correct* there. It is what makes stripping the others safe,
  because the evidence stays preserved at a date.
- **`vignettes/articles/catch-tables.qmd`** — it already runs 26 evaluated
  chunks against the live archive and uses inline `` `r ` `` for exactly none
  of its 115 hard-coded prose numbers. Load-bearing numbers belong inline, so
  they re-measure on render and a change shows up in the diff instead of
  rotting; denominators should go. The trade, which is real: the `.qmd` then
  cannot be read as text without rendering, and a render takes minutes
  against the live server.
- **This file** — numbers here should be invariants, so a figure that needs
  refreshing is a sign the claim was the wrong shape.
- **`TODO.md`** — "done looks like" must not depend on a count.

The general mechanism is already scoped in `PLAN-qc-checks.md` §7 (pin a
snapshot, make the findings measurable, recompute as a **diff** rather than a
flag table). It was written for the 13 YAML findings; it generalises to prose
numbers for free, and building it is what turns "the counts are stale" from a
chore into an output.

------------------------------------------------------------------------

## Scope

**Supported:** `HH`, `HL`, `CA`, `LT` via `dr_con_raw()`; `HH`, `HL`, `CA`,
`species`, `HL_length`, `HL_summary`, `hl_flag`, `hl_flag_code`,
`length_weight`, `length_type_conversion` via `dr_con()`.

`HH`, `HL` and `CA` exist under **both** connections (`HL`/`CA` added
2026-09-03). `dr_con_raw("HL")` and `dr_con("HL")` return the same rows and
the same columns bar one — `dr_con()`'s carries `.id` — and nothing else is
touched: opus's names, sentinels intact. Proven per rebuild with DuckDB
`EXCEPT` over every column, both directions, 0 rows differing on all three.
They exist so a consumer joining HL or CA to HH does not pay `dr_add_id()`
over 14.4M and 6.0M rows every time. Their columns are deliberately **not**
pinned in `PUBLISHED_SCHEMA` — those names are opus's, and a second copy here
is what Working Principle 1 forbids. The contract tested instead is the
relation `dr_con(tbl) == dr_con_raw(tbl) + ".id"`.

`LT` is served raw-only, on purpose: it is litter data, unrelated to the
catch tables, and nothing asks for it. `dr_con_raw("LT")` reads
`raw/LT.parquet`, which is the live one; a retired-era copy at the server
*root* was deleted 2026-09-11 — see below.

------------------------------------------------------------------------

## Two layers: the record layer and the analysis layer

**`HH`, `HL`, `CA` are the record layer.** The exchange tables exactly as opus
staged them, plus `.id`. Nothing aggregated, nothing dropped, sentinels intact.

**`HL_length` and `HL_summary` are the analysis layer**, derived from HL. They
are *not* redundant with the record layer, and conflating the two is the
mistake this section exists to prevent.

**The analysis layer is faithful.** Verified archive-wide 2026-09-03,
`HL_length`'s `n_haul` reproduces the DATRAS R package's own `Count` across
every species and survey:

| | |
|---|---|
| haul × species × length cells | 13,214,965 |
| exact matches | 13,191,109 |
| cells off by ≥ 0.5 fish | **0** |
| max gap | 2.9e-11 (floating point) |
| in `HL_length` but not raw HL | **0** |
| in raw HL but not `HL_length` | 23,856 — all where `n_haul` is `NA` |

Those 23,856 (0.18%) are the documented missing-`SubsamplingFactor` rule:
DATRAS assumes 1, obus returns `NA` because ICES makes the field mandatory.
A choice, not an error.

**The analysis layer is NOT lossless.** 13,957,390 of 14,001,605 `HL_length`
rows (99.68%) come from exactly one raw HL row; 44,215 aggregate several, and
there `SubsamplingFactor` (42,089 rows) and `SpeciesCategory` (43,989 rows)
are collapsed away. Also absent at this grain: `SubsampledNumber`,
`SubsampleWeight`, `SpeciesCodeType`, per-category `SpeciesCategoryWeight`
(`w_haul` is summed to the species) and sex-specific weight — the last being a
property of the source data, not of the split.

**Which to reach for:**

| task | layer |
|---|---|
| length spectra, numbers/biomass per haul, CPUE, stratified indices, species composition | analysis (`HL_length` + `HL_summary`) |
| subsampling QC, anything keyed on `SpeciesCategory`, per-category weights, provenance, rebuilding an exchange file | record (`HL`) |
| age, individual weight, maturity, ALKs | record (`CA`) — obus publishes no CA-derived table, but `dr_get_datras()` assembles one for {DATRAS} |

The first row is demonstrated, not asserted: `dr_get_datras()` builds a
`datras_raw` whose HL comes only from the two derived tables, and
`data-raw/CHECK_datras_adapter.R` runs DATRASextra's own downstream functions
on it unmodified — 11/11 checks, every one max gap 0, including an identical
stratified index. `data-raw/CHECK_datras_interop.R` is the field-by-field
comparison, 25/25.

**`dr_get_datras()` is the only way into a `DATRASraw` that is not an exchange
file.** {DATRAS} publishes no constructor: `readExchange()`,
`readExchangeDir()`, `readICES()`, `getDatrasExchange()`, `downloadExchange()`
and `DATRASextra::read_datras()` all parse one, `write_datras()` writes one
back rather than serialising, and `addExtraVariables()` — which derives
everything beyond the submitted columns — is unexported. obus therefore
reproduces that derivation. It needs no {DATRAS} code to do it: a `DATRASraw`
is a three-element list (CA, HH, HL, positionally) with a class attribute, and
`DATRASextra:::.add_class_datras()` is exactly
`class(x) <- c("datras_raw", "DATRASraw")`. {DATRAS} is `Suggests`, used only
for the optional `Roundfish` column, which lives in a CSV inside that package.

Two things the function inherits and cannot fix, both documented on it.
{DATRAS}'s derived quantities are `haul` × `length` matrices on HH with no
species dimension, so everything from `add_numbers_at_length()` onward is one
species at a time — and because HL keeps `Valid_Aphia` untouched, subsetting
*after* deriving looks like it worked and does not (`HaulN` measured 19× too
high on DATRASextra's own `mini`). And `$.DATRASraw` redirects `x$foo` into
HH with partial matching, registered when the namespace *loads*, not when it
is attached — so use `x[["HH"]]`.

**Deliberately absent** — every one of these existed in `obus_retired` and
was left out, not overlooked: `dr_settypes()`/`dr_translate()`,
`dr_HL_standardised()` (the deprecated union of the two catch tables),
`dr_add_record_type()`, `dr_add_starttime()`, `swept_area`, the areas/shapes
lookups, and all of the `dr_check_*` family. Reintroduce one when something
real needs it.

`length_weight` was on that list until 2026-09-02 and came back, with its
`length_type_conversion` companion and the shared `.dr_resolve.R` cascade
primitive.

`dr_get()` was on it until 2026-09-09 and came back as a **different
function**. The retired one fetched from the live XML service and reported
submission status; this one is `dr_con()` + `collect()` against the published
parquet, and exists to name the lazy/eager boundary rather than to hide it.
Nothing of the live-service half came back with it.

`swept_area` is the next candidate: bringing the family back is an open item
in `TODO.md` as of 2026-09-11, pending rather than decided. The whole of it —
`dr_impute_distance()`, `dr_impute_depth()`, `dr_impute_spread()`,
`dr_add_midpoint()`, `dr_join_beam_width()`, `dr_add_swept_area()`,
`dr_add_density()` — is in `obus_retired/R/dr_swept_area.R` and nothing of it
is in obus today, so any reference to one of those names here describes
retired code, not something callable.

------------------------------------------------------------------------

## Implementation

**Exported** (`R/`):
- `dr_con_raw(table, path, quiet)`, `dr_con(type, path, quiet)`,
  `dr_get(type, survey, years, quarters, ...)` — `R/dr_con.R`
- `dr_add_id(d)` — `R/dr_add_id.R`
- `dr_add_length_mm(d)`, `dr_add_length_cm(d)`, `dr_add_length_mid(d)`,
  `dr_add_n_and_cpue(d)`, `dr_join_species(x, species)` —
  `R/dr_transformation.R`
- `dr_HL_length(hh, hl, species, haulval)`,
  `dr_HL_summary(hh, hl, species, haulval)` — `R/dr_standardize.R`
- `dr_get_datras(survey, years, quarters, aphia, ca, haulval, stdspec)` —
  `R/dr_get_datras.R`
- `dr_add_length_tl(catch, conv, length_col)`,
  `dr_add_predicted_weight(catch, lw, length_col, bias_correct, exclude_tiers)`,
  `dr_compare_length_weight(len, smry, lw, tol, flag)` — `R/dr_length_weight.R`

**Internal:** `.dr_resolve_parquet_path()`, `.dr_concat_ws()`,
`.dr_hh_cols_for_hl()`, `.dr_require_cols()`, `.dr_maybe_collect()`;
`.dr_datras_fetch()` and the pure `.dr_as_datras_build()` with its
`.dr_datras_hh()`/`.dr_datras_hl()`/`.dr_datras_ca()` helpers, split so the
reshape is testable offline the way `dr_HL_length()` is (`R/dr_get_datras.R`);
`.dr_coalesce_with_provenance()` (`R/dr_resolve.R`, eager + lazy) and the
length-weight tier producers `.dr_lw_fit_ca()`, `.dr_lw_from_estimate()`,
`.dr_lw_consensus()`, `.dr_lw_from_sealifebase()`.

`NAMESPACE` is roxygen2-generated; never hand-edit it.

**`data-raw/`** builds what the server serves. Run by hand, in order;
neither script publishes anything.
- `build_helpers.R` — local mirror of the raw archive (`data-raw/raw`,
  gitignored), zstd parquet writer, both gitignored output paths
- `DATASET_species.R` — distinct `Valid_Aphia` from raw HL and CA -> WoRMS
  (`wm_id2name_`, `wm_common_id_`, chunked `wm_record`) -> `species.parquet`
- `DATASET_products.R` — raw HH/HL -> `HH`, `HL_length`, `HL_summary`,
  entirely lazily; DuckDB streams straight to parquet, nothing is
  `collect()`ed
- `DATASET_length_weight.R` — raw CA + raw HL + `species.parquet` -> FishBase /
  SeaLifeBase -> `length_weight.parquet`. Runs after `DATASET_species.R` and
  is independent of `DATASET_products.R`
- `DATASET_length_type_conversion.R` — two traced Macrouridae PAFL factors ->
  `length_type_conversion.parquet`. No network

------------------------------------------------------------------------

## Key Facts

**DATRAS is not big data, and `dr_get()`'s NULL defaults rest on measuring
that** (2026-09-09, 24 GB Mac, one table at a time with `gc()` between).
Unfiltered `collect()`: `HL` 14,423,771 x 30 in 12.1s / 2.9 GB; `HL_length`
14,001,605 x 18 in 25.0s / 1.8 GB; `CA` 5,968,027 x 35 in 5.5s / 1.5 GB;
`HL_summary` 2,291,457 in 6.9s; `HH` 150,217 x 70 in 1.0s; `species` 0.6s.
Every published table, end to end, under a minute. So `dr_get()` does not warn
about an unfiltered pull -- there is nothing to warn about.

`dr_get_datras(survey = NULL)` is the one call that is genuinely heavy, and
not because of the download: 63.5s wall, **peak RSS 10.4 GB** for a 2.7 GB
object (CA 5,662,051 x 40, HH 150,217 x 77, HL 14,367,618 x 21), zero swaps.
The ~4x transient is the reshape -- `bind_rows` over 14M rows, two joins, and
factorising every character column -- not the collect. It completes on a
24 GB machine with roughly 10 GB free; it is the wrong thing to run on 16 GB.
The row counts double as a check: CA is 5,968,027 - 305,976 orphans, and HL is
HL_length's 14,001,605 + 366,013 bulk-only rows from `HL_summary`.

**The `head()` caution applies to the RAW archive only.** `dr_con_raw("HL") |>
head(3)` costs 7-8s against 0.4s for `dr_con("HL")`: a bare `LIMIT` has no
predicate to push down and opus's raw row groups are large, while obus's own
parquet, written by `build_helpers.R`'s zstd writer, does not inherit it. An
earlier note in this file put the raw figure at ~43s; re-measured 2026-09-09
and not reproducible.


**`.id` is obus's, not ICES's.** Eight fields joined with `:` —
`Survey:Year:Quarter:Country:Platform:Gear:StationName:HaulNumber`, e.g.
`BITS:1991:1:DE:06S1:H20:33:28`.

**It always has eight fields (changed 2026-09-03; `NA` fields used to be
skipped).** An `NA` field is written as the literal `"NA"`, which makes `.id`
byte-identical to the DATRAS R package's `haul.id` — verified set-identical
over all 150,217 hauls — and splittable back into the eight key columns.
Three measured reasons the skipping had to go:
- **Not splittable.** 6,899 of 150,217 hauls (4.59%) gave a 7-field `.id`,
  so a positional `separate()` shifted `HaulNumber` into `StationName`'s slot.
- **Self-consistent for HL only by luck.** HH and HL carry `NA StationName`
  on the *same* hauls, so both sides skipped the same field and still
  matched (0 orphans). CA does not: 305,276 rows have `HaulNumber` missing
  too — never `NA` in HH — giving 280 six-field ids matching no haul.
- **A live collision mode.** With two nullable fields,
  `StationName=NA, HaulNumber=k` and `StationName=k, HaulNumber=NA` skip to
  the same string. Measured 0 collisions across HH/HL/CA, but one
  submission from real.

`"NA"` and not `"-9"`: opus has already nulled `-9` as a sentinel, so writing
it back manufactures a value the archive does not contain and is
indistinguishable from a genuine `StationName` of `-9` — Working Principle 3
runs the other way. Verified unambiguous: no `StationName` in HH, HL or CA is
`"NA"`, `"-9"`, `""`, or contains a `":"`. An all-`NA` key still yields `NA`
rather than eight tokens, as a guard; the first six fields are never `NA` in
any of the three tables, so it cannot currently fire.

**`.dr_concat_ws()` exists because `paste()` cannot be trusted here.**
`dplyr` resolves `paste(sep=)` differently per backend: eagerly R renders
`NA` as the literal `"NA"`; lazily dbplyr translates to DuckDB's
`CONCAT_WS()`, which drops `NA`. `.id` is the join key between HH, HL and
CA, so it must come out identical either way — so the `NA` token is
substituted *before* concatenating and no `NA` ever reaches `paste0()`.
Every case is tested on both backends.

**CA's 5.13% is the submissions' fault, and is published intact.** 305,976
of 5,968,027 CA rows match no HH haul; 305,276 of those have both
`StationName` and `HaulNumber` missing, so `.id` ends `":NA:NA"` and
identifies no haul. `DATASET_products.R` prints the figure per build but does
not enforce it — filtering would be obus inventing a rule. An `inner_join`
to HH drops them silently, so `anti_join` first if it matters.

**Measured on the full archive, 2026-08-31.** HH 150,217 hauls, `.id`
unique, zero `NA`, zero orphan HL rows. HL 14,423,771 rows. species 2,022
Valid_Aphia (15 not WoRMS-accepted, 11 forwarding elsewhere — the same counts
the retired build measured in July). HL_length 14,001,605 rows.
HL_summary 2,291,457 rows.

**Both catch tables' grain is asserted in code, not just documented.**
`PUBLISHED_GRAIN` in `tests/testthat/test-published-schema.R` is checked
twice — against the code on synthetic fixtures, and against the **published
files**, where both counts push down to SQL so the 14M-row tables cost the
same as the 19-row one. It is there because the grain was wrong in the
roxygen twice, and both times was fixed in the docs rather than in the code;
a wrong key in a test fails, a wrong key in a sentence does not.
- `HL_length` is keyed by `.id x Valid_Aphia x length_mm x accuracy x
  LengthType x SpeciesSex x DevelopmentStage x SpeciesValidity` -- eight
  fields, 0 duplicated groups over all 14,001,605 rows (re-verified
  2026-09-08). Every one is load-bearing; leaving one out introduces
  duplicated groups: `SpeciesSex` 741,219, `DevelopmentStage` 5,476,
  `LengthType` 3,909, `accuracy` 15, `SpeciesValidity` 15. These are
  genuinely separate counts and must not be collapsed *accidentally* --
  `dr_HL_collapse()` (2026-09-17) is the deliberate route, and exists because
  a hand-rolled `group_by()` loses the guards. (`length_cm` is
  `length_mm / 10`, carried for convenience, not part of the key.)
- `HL_summary` is keyed by `.id x Valid_Aphia x SpeciesValidity`. 1,219 groups
  (0.05%) split — and 97% of the sub-groups that do are the
  repeated-total pattern of Working Principle 5, not a real split. Summing
  `n_haul`/`w_haul` per `.id x Valid_Aphia` without collapsing first
  double-counts them.

  **The remedy is to sum across `SpeciesValidity`, not to filter to `"1"`.**
  This file said "for most surveys, filter to `SpeciesValidity == "1"`"
  until 2026-09-17; that was wrong. `SpeciesValidity` is a *record type*, not
  a quality flag — DATRAS deliberately allows several per species per haul,
  lengths on one row and a total-only count on another — so filtering
  discards real records rather than bad ones. Measured: it would drop
  **464,858 of 2,291,457 `HL_summary` records (20.3%)**, and in `HL_length`
  **691,163 of 14,001,605 rows (4.9%), covering 37,302,307 fish**. Can-Mar is
  the only survey that puts real length data on validity-`5` rows (8,863 of
  them, and no other survey has any), so a blanket filter silently deletes one
  survey's measurements. `dr_HL_collapse()` names it as a collapse for exactly
  this reason. The same point is argued from the ICES side in
  `datrasdoodle2`'s `catch-and-length.qmd`, "`SpeciesValidity` separates
  records; it is not a filter".

**obus publishes at the finest grain and reduces on request**, never the
other way round: you can collapse down and never back up. `dr_HL_collapse()`
is that reduction, and the reason it is a verb on the table rather than an
argument on `dr_HL_length()` is that the builder is the minority path --
`dr_con("HL_length")` returns the same 18 columns and is how the table is
actually read. What it exists for is the two guards a downstream `group_by()`
silently loses: the all-`NA` `0`-in-R / `NULL`-in-SQL divergence, and the
`DataType == "C"` rule for `n_measured`. The second needs no `DataType`
column -- `DataType` is haul-level and `.id` is never collapsed, so every row
of a group shares it and the all-`NA` guard reproduces the rule exactly. That
is also why `.id` is refused: collapsing it would break the guard silently.

`accuracy` and `LengthType` are refused **by the data, not by the signature**.
Summing across a 1 cm and a 5 cm bin at the same `length_mm`, or across total
and standard length, invents a count for a bin nobody measured -- but that is
rare rather than universal. Collapsing to `.id x Valid_Aphia x length_mm`
gives 13,214,965 groups, of which 18 mix `accuracy` and 4,051 mix
`LengthType` (0.031%, measured 2026-09-17). So the check errors on exactly
those and lets the rest through, and it is evaluated against the *resulting*
grain rather than the input. `{DATRAS}`'s `addSpectrum()` collapses a mixed
`LngtCode` to the coarsest with only a warning; obus errors and names the
group.

**`HL_summary` deliberately carries no length-derived total**, and that is
settled rather than pending. ICES's row-level formula is fully derivable from
`HL_length`: summing its `n_haul` over `.id x Valid_Aphia x SpeciesValidity`
reproduces `Sum(NumberAtLength x SubsamplingFactor)` exactly — 1,925,444
groups, 0 differing, 0 one-sided. Carrying it in both tables would duplicate
derivable information across two files, which is what the split exists to
avoid. `HL_summary` earns its `TotalNumber` instead because it is the only
*universal* per-species total: 366,013 of its 2,291,457 rows (16%) are species
with no length data at all. Their 3.44% disagreement is visible by
construction, which is the point. When joining the two, sum `n_haul` — do not
re-multiply `NumberAtLength * SubsamplingFactor` by hand, because `n_haul`
embeds the documented `DataType == "R"` + `NA` `SubsamplingFactor` convention
and the hand-rolled version returns `NA` for those rows.

**`HL_length` carries both the raised and the un-raised count** (added
2026-09-03, 18 columns). `n_haul` is `NumberAtLength × SubsamplingFactor`;
`n_measured` is Σ`NumberAtLength` as submitted — the same quantity
`HL_summary` already carried under the same name, one grain finer, so
summing it to that table's grain reproduces that column. Verified over the
1,925,444 comparable groups: NA sets identical (586,884 either way, the
all-`DataType == "C"` groups) and 2,501 groups differing by at most 8.7e-11.
That residual is floating point, not logic — 454,716 raw HL rows carry a
**fractional** `NumberAtLength`, so summing subgroups then re-summing is not
bit-associative, and re-running moves the count by a few dozen either way.

It is a column and not a note because it is **not recoverable from
`n_haul`**: `SubsamplingFactor` is not part of the grain, so one output row
can aggregate several raw rows raised by different factors — 44,215 rows come
from more than one raw row and 42,089 of those span more than one distinct
factor. Where both are known the two differ on 2,044,217 of 9,325,606 rows
(21.9%), which is just how much of the archive was subsampled. `NA` under
`DataType == "C"` for `HL_summary`'s reason (a rate, not a count): 4,651,701
of 14,001,605 rows, measured to be exactly the `"C"` rows and no others.
There is no `0` case here, unlike in `HL_summary` — a species with no length
data has no row in this table at all.

The motivating gap was external: `DATRAS`/`DATRASextra` build `Count`
(= `n_haul`) from `HLNoAtLngt` (= `n_measured`), and with only the raised
figure published, measured-vs-raised QC at length was impossible from
`HL_length` alone.

**The column has since earned itself, and the demonstration is worth keeping**
(measured 2026-09-08 for `datrasdoodle2`'s catch chapter). BITS Q1 plaice on
`DataType == "R"` hauls, where raising means exactly one thing:

| block | mean measured/haul | mean raised/haul | factor |
|---|---:|---:|---:|
| 1995-1999 | 10.2 | 10.2 | **1.00** |
| 2005-2009 | 35.4 | 48.5 | 1.37 |
| 2015-2019 | 63.9 | 151.5 | 2.37 |
| 2025-2029 | 100.9 | 757.8 | **7.51** |

The measured column **plateaus near 100 fish a haul and stops**; the raised
one does not. That is the measuring board saturating — past some catch size
every additional fish goes into the multiplier rather than onto the board,
and plaice sub-sampling in BITS was literally zero before 2000. Over the
series, measured plaice per haul rose 10.5x while raised rose 73.7x.

The general lesson, which is why this sits in AGENTS.md rather than only in
the book: **the raising correction is largest exactly where the signal is
strongest**, so publishing only one of the two counts does not add noise to a
consumer's analysis, it removes the finding. Neither column is recoverable
from the other (see the paragraph above), so both have to be published.

**The cross-check that says the port is faithful.** `HL_summary`'s
`n_haul` (from `TotalNumber`) and `HL_length`'s summed length classes are
computed from different fields by different routes, so their disagreement
rate is the sharpest single test that both tables were built correctly.
Fresh build 2026-09-03: 73,596 of 1,912,556 groups (3.85%), which is the
figure `test-published-schema.R` already quoted. The retired implementation
measured 3.5% over 1,920,932. The residual is real data — intrinsic to
`DataType == "C"` plus rounding noise from non-integer `SubsamplingFactor` —
not a defect.

**Only obus and `DATRASextra` are bin-width aware.** Surveyed across the
mined corpus 2026-09-04: six repositories add a half-bin, but four hardcode
`+0.5`, which is correct only at 1 cm bins — and every one of those four sits
in an ALK or mean-length context, never in a catch-at-length product. So the
ecosystem knows about the half-bin where it computes a mean length and forgets
it where it predicts a weight, which is the gap `dr_add_length_mid()` closes.
`DATRASextra`'s own width-aware version is off by one bin; see `TODO.md`.

**`LengthClass` is the LOWER BOUNDARY of a length bin, not a length.** ICES
says so for HL and CA alike — *"Lower length boundary of the Length class. In
cm or mm depending on the LngtCode. E.g. 10-11 cm=10"* — and opus already
carries it verbatim (`inst/DATRAS-data-dict.yaml:1713` and `:2289`). It is
harmless for a length distribution, where a bin label is exactly what is
wanted, and it is a real bias for weight: \(W = aL^b\) is convex, so the
lower bound under-predicts, worst for small fish and wide bins — 15.8% at
10 cm and 5.1% at 30 cm with the 1 cm bins that carry 59% of `HL_length`.
It does not average out over a haul.

`dr_add_length_mid()` adds `length_cm_mid = length_cm + accuracy/2`, and
`dr_add_predicted_weight()` **defaults to that column**, so a pipeline that
skipped the step errors instead of quietly returning low weights. The CA fit
in `DATASET_length_weight.R` uses midpoints too. Both sides matter: fitting on
lower bounds inflates `a` to compensate, which cancels at apply time only if
the species happens to be reported at the same bin width in both tables —
and the mixes differ (raw HL 39.65% mm / 57.73% cm, raw CA 48.23% / 51.77%).
Found 2026-09-02, after the retired implementation had predicted from the
lower bound throughout.

**HH positions carry two traps, and swept-area work will walk into both.**
Measured over all 150,217 hauls, 2026-09-02. obus computes nothing from these
fields today, so nothing is wrong; whatever builds towed distance needs both
facts before it starts.
- **31,038 hauls (20.7%) have no haul (end) position at all** — only
  `ShootLatitude`/`ShootLongitude`. Any distance-from-positions calculation
  needs a documented fallback for a fifth of the archive.
- **2,780 hauls record an end position identical to the shoot position**,
  which yields a *zero-distance tow* — a plausible-looking number rather than
  an honest `NA`, and the more dangerous of the two. This is usually written
  off as a Norwegian quirk, which undersells it badly: RU 41.8% of hauls and
  EE 40.2%, against NO's 14.3%. The innocent explanation dies on precision —
  if identical pairs were a rounding artefact, the share recorded at one
  decimal would have to be at least as large as the identical share, and it is
  three to four times *smaller* on every affected country. These are
  fine-grained positions that were **copied**, almost certainly the shoot
  position written into both slots.

The function these bite is `dr_impute_distance()`, which does not exist in
obus — it is in `obus_retired/R/dr_swept_area.R`, and resurrecting it is
pending (`TODO.md`). Read it before rebuilding it, because it already answers
the second trap: positions enter at **tier 3 of an 11-tier cascade**
(`haversine_positions`, capped at 10 km), and its `fill()` helper accepts a
tier's value only where it is `> 0`, with the comment "Positive guard prevents
zero-distance artefacts from perfectly coincident positions or zero speed." So
a copied position is demoted to a coarser tier rather than anchoring a
zero-distance tow. Trap one needs nothing special either: a missing end
position simply leaves tier 3 unavailable and the cascade continues.

What is *not* answered is reporting. A haul demoted by that guard is
indistinguishable afterwards from one that never had a position, and the
country pattern above says these are a data-quality signal rather than noise
to route around. So the open piece is coverage — a `dr_check_*` report, per
the house rule that obus reports rather than silently repairs — not the
fallback itself.

**HH's hydrography cannot carry an environmental explanation**, which is worth
knowing before anyone reaches for it. There is **no oxygen field in HH at
all** — absent, not sparse. Coverage of what does exist starts late
(`BottomSalinity` is on 0% of BITS Q1 hauls before 2000). And where the fields
exist they do not discriminate: hauls recorded `HaulValidity == "N"` are
indistinguishable from hauls that fished normally and caught nothing. An
oxygen series has to come from the ICES oceanographic database, a different
archive and outside both packages' scope. What the fields *do* support is a
positive statement — plaice abundance is ordered by `BottomSalinity` within
every longitude band — which is a live rival to an oxygen story rather than a
version of one. Measurements in `DEVLOG.md`, 2026-09-08.

**Two lookups at one grain, kept in two files.** `species` and `length_weight`
are both exactly one row per `Valid_Aphia`, and merging them was considered and
rejected: they rebuild against different remotes (WoRMS vs FishBase/
SeaLifeBase), so a merged table has a partial-rebuild failure mode where half
the columns silently vanish; and `species` is WoRMS fact while `length_weight`
is obus's own modelled inference, which is why it carries `lw_source`, `r2`
and `sigma` at all. The build cycle that looked like it would force the issue
does not exist — `length_bearing` comes straight from raw HL, not from
`HL_length` (verified identical, 1,176 either way).

**The server root carried retired-era files no build script owned, and it is
now clean.** Found 2026-09-03 by the new `dr_con(tbl) == dr_con_raw(tbl) +
".id"` test, which failed before publication and turned out to be reporting
the *server*, not the code. Before this rebuild the root held `HL.parquet`,
`CA.parquet` and `LT.parquet` from `obus_retired`, carrying its abandoned
renames (`aphia`, `sex`, `age`), `Survey`/`Year` appended out of position, and
**filtered row counts** — HL 14,400,747 against raw's 14,423,771, CA
5,966,950 against 5,968,027. `dr_con()` refused those names, so nothing in
obus read them and nothing noticed. This rebuild overwrote `HL` and `CA`, and
the last two orphans — root `LT.parquet` and `HL_standardised.parquet` — were
deleted 2026-09-11 (verified 404; `raw/LT.parquet` and `CPUEL.parquet` still
answer 200).

The standing lesson is the one that outlives the cleanup: **a published file
nothing reads is invisible, not harmless.** `dr_con()`'s refusal to serve the
bad names is exactly what kept them undiscovered for weeks. `CPUEL.parquet` at
the root is *not* an orphan — it is ICES's own product, mirrored deliberately,
and both the article and `datrasdoodle2` read it.

**`obus_retired` is a reference, never a source of settled fact.** It is
archived intact at `../obus_retired`. Several of its own documented
"facts" turned out to be stale — including, concretely, the published
parquet it left on the server. Re-verify anything found there.

------------------------------------------------------------------------

## Metadata on the derived tables — decided 2026-09-04, not implemented

Every raw file opus writes is self-describing; **none of obus's published
files are**. Measured with `parquet_kv_metadata()` over the live server:
`raw/{HH,HL,CA,LT}.parquet` carry all five JSON blocks (`datras:dict` — 59 KB
on HH — plus `provenance`, `sentinels`, `coverage`, `known_issues`), and every
file obus publishes carries none. opus reads those blocks **out of the file**
rather than from the installed package, which is what makes them worth
writing: `op_dict()`, `op_provenance()`, `op_coverage()`, `op_catalog()` and
the rest all resolve through `.op_kv(table, "datras:dict", path)`.

The decision is a three-way split, chosen so that one access idiom keeps
working across the whole server directory:

1. **Format and writer belong to opus.** It owns how a DATRAS-family parquet
   describes itself. If obus invents its own key names or JSON shapes then
   `op_dict()` stops working on half the published files and a consumer needs
   two idioms for one folder. opus should export the writer, or at minimum the
   block schema.
2. **Content for the derived columns belongs to obus.** `n_haul`, `n_hour`,
   `n_measured`, `length_mm`, `length_cm`, `length_cm_mid`, `accuracy`,
   `w_haul` and `.id` are obus's own inventions. Working Principle 1 forbids
   re-deriving *DATRAS* names; it says nothing against documenting columns
   obus created, and not documenting them is the worse outcome.
3. **`dict_sha256` of the source archive is non-negotiable**, and it is the
   load-bearing one. Given `HL_length.parquet` today there is no way to tell
   which archive build produced it — and this project has already been bitten
   by exactly that failure, with retired-era files sitting on the server for
   weeks carrying abandoned renames and filtered row counts, invisible because
   `dr_con()` simply refused the names. A provenance block makes a stale file
   self-evident rather than invisible.

Grain belongs in the block too: a machine-readable grain is testable, and
prose in this file is not.

**It is cheap, and it preserves the streaming property** — nothing needs
`collect()`ing. `COPY … (FORMAT PARQUET, KV_METADATA {key: 'value'})` is
supported on duckdb 1.5.5 and round-trips, and `duckdbfs::write_dataset()`
forwards a multi-element `options` vector verbatim into the `COPY` parens, so
`data-raw/build_helpers.R`'s single `"COMPRESSION 'zstd'"` becomes a vector
and nothing else changes. Verified five ways, including JSON payloads and two
keys in one block, on a lazy input.

**One escaping trap, worth writing into the helper rather than rediscovering
at build time.** These are single-quoted SQL literals and
`datras:known_issues` is 8 KB of English prose, so apostrophes are close to
certain; a raw one fails with `Parser Error: syntax error at or near "s"`.
Do not hand-roll `gsub("'", "''", …)` — use `DBI::dbQuoteString(con, json)`.
Verified byte-identical on round-trip with a payload containing `ICES's` and
`don't`.
