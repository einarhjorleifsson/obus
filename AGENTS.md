------------------------------------------------------------------------

# obus — DATRAS Access Layer for R

**Status:** Rebuilt from an empty `R/`, 2026-08-31; length-weight added
2026-09-02; `n_measured` on `HL_length`, eight-field `.id` and the published
`HL`/`CA` added 2026-09-03. **Version:** 2026.08 — 13 exported functions, all
ten published tables live, `R CMD check` 0/0/0.

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
   - The published `HL_standardised.parquet` disagrees with a fresh build
     on 33 of 4,880 NS-IBTS 2022 Q1 groups, always by a factor of two. The
     *published file* is stale: it predates the `SpeciesCategory` fix its
     own source code documents. Checking the direction of the difference
     is what distinguished "my port is broken" from "the reference is old."
   - Both catch tables have a **finer grain than their own documentation
     claimed** (see below). Found by counting distinct grain tuples, not
     by reading the code.

**5. A repeated total is the recurring failure mode of this data.** DATRAS
repeats one species-level total identically across sub-rows that look like
a split. It has now been found three times over, in `sex`, in
`SpeciesCategory`, and — still unhandled — in `SpeciesValidity`. Any new
grouping dimension added to `dr_HL_summary()` should be assumed guilty
until measured.

**6. Only ICES's own published documents are evidence for what a field
means.** That is `~/R/Pakkar/imbus/DATRAS/external/` — chiefly
`DATRAS_Field_descriptions_and_example_file_December2025.xlsx` (including its
`General Notes` sheet), the SISP manuals, and the ICES workshop and
working-group reports. The authored `.qmd` files one directory up, and
anything in `obus_retired`, are pointers to where to look, not evidence.
Findings get written up in `vignettes/datras-conventions.Rmd`. (Standing rule
since 2026-08-31; it lived in `TODO.md` until the 2026-09-04 split, where it
was the only entry that was a rule rather than a task.)

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
catch tables, and nothing asks for it. Note the server root still holds a
retired-era `LT.parquet` that no build script produces — see below.

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
| age, individual weight, maturity, ALKs | record (`CA`) — obus publishes no CA-derived table |

The first row is demonstrated, not asserted: `data-raw/CHECK_datras_adapter.R`
builds a `datras_raw` whose HL comes only from the two derived tables and runs
DATRASextra's own downstream functions on it unmodified — 11/11 checks, every
one max gap 0, including an identical stratified index.
`data-raw/CHECK_datras_interop.R` is the field-by-field comparison, 25/25.

**Deliberately absent** — every one of these existed in `obus_retired` and
was left out, not overlooked: `dr_get()` (eager fetch, live XML,
submission status), `dr_settypes()`/`dr_translate()`, `dr_HL_standardised()`
(the deprecated union of the two catch tables), `dr_add_record_type()`,
`dr_add_starttime()`, `swept_area`, the areas/shapes lookups, and all of the
`dr_check_*` family. Reintroduce one when something real needs it.

`length_weight` was on that list until 2026-09-02 and came back, with its
`length_type_conversion` companion and the shared `.dr_resolve.R` cascade
primitive.

------------------------------------------------------------------------

## Implementation

**Exported** (`R/`):
- `dr_con_raw(table, path, quiet)`, `dr_con(type, path, quiet)` — `R/dr_con.R`
- `dr_add_id(d)` — `R/dr_add_id.R`
- `dr_add_length_mm(d)`, `dr_add_length_cm(d)`, `dr_add_length_mid(d)`,
  `dr_add_n_and_cpue(d)`, `dr_join_species(x, species)` —
  `R/dr_transformation.R`
- `dr_HL_length(hh, hl, species, haulval)`,
  `dr_HL_summary(hh, hl, species, haulval)` — `R/dr_standardize.R`
- `dr_add_length_tl(catch, conv, length_col)`,
  `dr_add_predicted_weight(catch, lw, length_col, bias_correct, exclude_tiers)`,
  `dr_compare_length_weight(len, smry, lw, tol, flag)` — `R/dr_length_weight.R`

**Internal:** `.dr_resolve_parquet_path()`, `.dr_concat_ws()`,
`.dr_hh_cols_for_hl()`, `.dr_require_cols()`, `.dr_maybe_collect()`;
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

(The HL_length figure here read 13,996,129 until 2026-09-03 — exactly 5,476
short, which is the count of groups that split on `DevelopmentStage`. It was
a pre-`DevelopmentStage`-grain number left behind; the roxygen already
carried 14,001,605.)

**Neither catch table's grain is what its documentation used to claim, and
both were fixed in the docs rather than the code.**
- `HL_length` is keyed by `.id x Valid_Aphia x length_mm x accuracy x
  LengthType x SpeciesSex x DevelopmentStage x SpeciesValidity` -- eight
  fields, 0 duplicated groups over all 14,001,605 rows (re-verified
  2026-09-08). Every one is load-bearing; leaving one out introduces
  duplicated groups: `SpeciesSex` 741,219, `DevelopmentStage` 5,476,
  `LengthType` 3,909, `accuracy` 15, `SpeciesValidity` 15. These are
  genuinely separate counts and must not be collapsed. (`length_cm` is
  `length_mm / 10`, carried for convenience, not part of the key.)
- `HL_summary` is keyed by `.id x Valid_Aphia x SpeciesValidity`. 1,219 groups
  (0.05%) split — and 97% of the sub-groups that do are the
  repeated-total pattern of Working Principle 5, not a real split. Summing
  `n_haul`/`w_haul` per `.id x Valid_Aphia` without collapsing first
  double-counts them. **Open decision, see `TODO.md`.**

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

**Two lookups at one grain, kept in two files.** `species` and `length_weight`
are both exactly one row per `Valid_Aphia`, and merging them was considered and
rejected: they rebuild against different remotes (WoRMS vs FishBase/
SeaLifeBase), so a merged table has a partial-rebuild failure mode where half
the columns silently vanish; and `species` is WoRMS fact while `length_weight`
is obus's own modelled inference, which is why it carries `lw_source`, `r2`
and `sigma` at all. The build cycle that looked like it would force the issue
does not exist — `length_bearing` comes straight from raw HL, not from
`HL_length` (verified identical, 1,176 either way).

**The server root still carries retired-era files no build script owns.**
Found 2026-09-03 by the new `dr_con(tbl) == dr_con_raw(tbl) + ".id"` test,
which failed before publication and turned out to be reporting the *server*,
not the code. Before this rebuild the root held `HL.parquet`, `CA.parquet`
and `LT.parquet` from `obus_retired`, carrying its abandoned renames
(`aphia`, `sex`, `age`), `Survey`/`Year` appended out of position, and
**filtered row counts** — HL 14,400,747 against raw's 14,423,771, CA
5,966,950 against 5,968,027. `dr_con()` refused those names, so nothing in
obus read them and nothing noticed. This rebuild overwrites `HL` and `CA`.
`LT.parquet` is not overwritten by any script and should be deleted from the
server, not left to look current.

**`obus_retired` is a reference, never a source of settled fact.** It is
archived intact at `../obus_retired`. Several of its own documented
"facts" turned out to be stale — including, concretely, the published
parquet it left on the server. Re-verify anything found there.
