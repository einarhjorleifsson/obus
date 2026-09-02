------------------------------------------------------------------------

# obus — DATRAS Access Layer for R

**Status:** Rebuilt from an empty `R/`, 2026-08-31. **Version:** 2026.08

------------------------------------------------------------------------

## What obus provides

obus reads the raw ICES DATRAS exchange tables that the sibling `opus`
package stages, and builds the derived catch tables on top of them.

**Two connections, one engine.**

1. **`dr_con_raw(table)`** — lazy DuckDB view over
   `https://heima.hafro.is/~einarhj/datras/raw/{HH,HL,CA,LT}.parquet`:
   opus's current field names exactly as staged, no `.id`, nothing derived.
2. **`dr_con(type)`** — lazy DuckDB view over what obus itself builds and
   publishes at `https://heima.hafro.is/~einarhj/datras/`: `HH` (raw plus
   `.id`), `species`, `HL_length`, `HL_summary`.

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

------------------------------------------------------------------------

## Scope

**Supported:** `HH`, `HL`, `CA`, `LT` via `dr_con_raw()`; `HH`, `species`,
`HL_length`, `HL_summary`, `hl_flag`, `hl_flag_code`, `length_weight`,
`length_type_conversion` via `dr_con()`.

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
`BITS:1991:1:DE:06S1:H20:33:28`. `NA` fields are skipped, not rendered as
the string `"NA"`. That convention is not fidelity to any standard — there
isn't one — only to what the archive already stores, so a full rebuild
stays free to change it, all at once.

**`.dr_concat_ws()` exists because `paste()` cannot be trusted here.**
`dplyr` resolves `paste(sep=)` differently per backend: eagerly R renders
`NA` as the literal `"NA"`; lazily dbplyr translates to DuckDB's
`CONCAT_WS()`, which drops `NA`. `.id` is the join key between HH, HL and
CA, so it must come out identical either way.

**Measured on the full archive, 2026-08-31.** HH 150,217 hauls, `.id`
unique, zero `NA`, zero orphan HL rows. HL 14,423,771 rows. species 2,022
Valid_Aphia (15 not WoRMS-accepted, 11 forwarding elsewhere — the same counts
the retired build measured in July). HL_length 13,996,129 rows.
HL_summary 2,291,449 rows.

**Neither catch table's grain is what its documentation used to claim, and
both were fixed in the docs rather than the code.**
- `HL_length` is keyed by `.id x Valid_Aphia x length_mm x SpeciesSex x LengthType`.
  4,074 groups (0.03%) split on `LengthType`, `SpeciesValidity` or
  `accuracy`. These are genuinely separate counts and must not be
  collapsed.
- `HL_summary` is keyed by `.id x Valid_Aphia x SpeciesValidity`. 1,219 groups
  (0.05%) split — and 97% of the sub-groups that do are the
  repeated-total pattern of Working Principle 5, not a real split. Summing
  `n_haul`/`w_haul` per `.id x Valid_Aphia` without collapsing first
  double-counts them. **Open decision, see `TODO.md`.**

**The cross-check that says the port is faithful.** `HL_summary`'s
`n_haul` (from `TotalNumber`) and `HL_length`'s summed length classes are
computed from different fields by different routes, so their disagreement
rate is the sharpest single test that both tables were built correctly.
Fresh build: 67,296 of 1,925,733 groups (3.49%). The retired
implementation measured 3.5% over 1,920,932. The residual is real data —
intrinsic to `DataType == "C"` plus rounding noise from non-integer
`SubsamplingFactor` — not a defect.

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

**`obus_retired` is a reference, never a source of settled fact.** It is
archived intact at `../obus_retired`. Several of its own documented
"facts" turned out to be stale — including, concretely, the published
parquet it left on the server. Re-verify anything found there.
