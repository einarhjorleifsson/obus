# obus development log

Dated development history: root causes, verification evidence, and the
reasoning behind non-obvious decisions. `AGENTS.md` documents obus's
*current* state (working principles, scope, architecture) and does not
carry this kind of narrative; `TODO.md` tracks only what's currently open.
Git commit messages remain the most granular record -- entries here are a
longer-form, human-browsable index of the same history.

Chronological, oldest first (new entries get appended at the bottom, like a
lab notebook).

This file was split out of `TODO.md` on 2026-09-04, which had grown to 1,156
lines of which four fifths was history. The convention follows opus's, which
had already made the same split.

---

## 2026-08-31 -- verification record against the full archive

The HL logic was re-derived from `obus_retired`'s final state and checked
against ICES primary documentation. What was done and found:

- **`obus_retired` master is the authoritative version.** All HL work was done
  on `explore/hl-tidy-redesign` and fast-forward merged (branch tips
  identical). `claude/jolly-lumiere-bffdbc` is 12 commits behind, pre-split,
  and still carries bug #1 unfixed. No dangling commit touches HL code. Its
  worktree is gone.
- **All 21 synthetic regression tests ported and passing** — they encode all
  three bugs `obus_retired` found and fixed.
- **All 4 hand-verified real-data cases from its dev notes pass** on the full
  archive (Can-Mar sex duplication → 2; BITS cross-sex collision → 4; NS-IBTS
  SpeciesCategory 11+12 → 660; NS-IBTS weight dedup → matches).
- **Mismatch composition tracks the benchmark**: R 44,625 / C 21,862 / S 135 /
  P 60 against the retired R 44,568 / C 21,865 / S 134 / P 62.

### Bugs found and fixed in this pass

0. **`DataType == "R"` + missing `SubsamplingFactor` was coalesced to 1.**
   Inherited from the DATRAS R package. The official field descriptions make
   the field **mandatory**, define `1` as the specific claim *not subsampled*,
   and instruct submitters that a field with no information is submitted as
   `-9` — so `NA` means "no information", a different statement from `1`. The
   coalesce silently converted "raising factor unknown" into "catch fully
   measured", understating `n_haul` wherever the true factor exceeded 1. Now
   propagates `NA`. Costs 24,298 length rows (0.17%), 0.003% of total
   `n_haul`; 98% Can-Mar. Note the earlier figures quoted from
   `obus_retired`'s notes (5.35% of BTS's R rows, 2.46% of NS-IBTS's) counted
   *all* R rows including catch-totals rows that never reach the arithmetic —
   restricted to length rows, BTS is zero and NS-IBTS is 37 (0.00%).

1. **`NULL = NULL` in the lazy reconciliation join (serious, mine).** SQL
   treats `NULL = NULL` as unknown, so every NA-`sex` row — 54% of HL — failed
   to match its own length-derived expectation, never reconciled, and fell to
   the fallback collapse, undercounting. `obus_retired` never hit this because
   its build collected eagerly first; making the build fully lazy made the SQL
   semantics live. Its own dev notes flag the same trap, but only for
   validation scripts. Fixed with `na_matches = "na"` (renders as
   `IS NOT DISTINCT FROM`). Caught by the BITS gold case returning 3, not 4.
2. **`DevelopmentStage` missing from the record key.** ICES defines
   `TotalNumber` and `SpeciesCategoryWeight` per *"haul, species, sex, devstage
   and subsampling category"*; `obus_retired` cites the same five-part key in
   its own notes but its code used four. 289 groups span >1 devstage, 21 with
   colliding `TotalNumber` (+29 fish archive-wide). Now in the key for counts,
   and a grain column on `HL_length` (5,476 groups were being summed together).
   Weight is deliberately still not keyed on devstage or sex — DATRAS
   demonstrably repeats one weight across those rows whatever its spec says.
3. **`n_measured`/`p_females` computed at the wrong grain.** Both were computed
   at `.id x aphia` and joined onto a `.id x aphia x SpeciesValidity` table, so
   the same value was repeated onto every record-type row — the exact mixing
   ICES warns against. Now computed at the table's own grain. Visible fix: the
   BITS case reports `n_measured` 219 on the validity-`"1"` row that carried
   the lengths and `0` on the validity-`"4"` "total number only" row; both
   previously said 219.

### Both tables are now exactly unique at the ICES record key

Verified 0 duplicated groups: `HL_length` at `.id x aphia x length_mm x
length_cm x accuracy x LengthType x sex x DevelopmentStage x SpeciesValidity`
(14,001,605 rows); `HL_summary` at `.id x aphia x SpeciesValidity`.

### The benchmark statistic is knife-edge — do not over-read it

13,829 groups sit at a difference of **exactly 0.5**, so the `> 0.5` tolerance
`obus_retired` measured its 3.5% at lands directly on a cluster. The count
drifts ~±10 between identical runs purely from the order DuckDB's parallel
`sum()` adds length classes. **Superseded 2026-08-31** — the tolerance framing was itself the wrong tool.
See "Where the two routes disagree" in `vignettes/articles/catch-tables.qmd`:
compare in submission units and count whole fish. 89.01% reconcile exactly,
7.14% differ by less than one fish (arithmetic, excluded), and **3.85% differ
by at least one fish** — the figure to quote.

## 2026-08-31 -- `-9` in HL: what it means, and why it is NULL

Raised while asking whether the NA-in-joins problem should be solved by
keeping `-9`. It should not, and the reason turns out to be a deliberate,
well-drawn opus policy rather than a loss.

**The meanings**, read from the dictionary embedded in the parquet footer
(`opus::op_enums("HL", column = ...)`):

    SpeciesSex        -9 = "not sampled"      (vs U = "Unidentified")
    DevelopmentStage  -9 = "No information"

**The raw archive contains zero `-9` in HL** — not in the character join keys
and not in any numeric field. Every one is NULL.

**That is opus policy, and it is principled.** `op_sentinels()` carries a
`resolution$labels_meaning_absent` list — "not known", "not available",
"not provided", **"not sampled"**, "missing value", **"no information"**,
"unknown", "na" — and nulls any `-9` whose vocabulary label matches. Both HL
labels match it literally. The complementary `resolution$keep` list preserves
`-9` for exactly three fields, and the line between them is coherent:

| field | `-9` label | kept? |
|---|---|---|
| `HH/LT Tickler` | "No ticklers are allowed" | keep — asserts a fact about the gear |
| `CA AgePlusGroup` | "No plus group" | keep — asserts a fact about the reading |
| `HH/LT DataType` | "Invalid hauls" | keep — asserts a classification |
| `HL SpeciesSex` | "not sampled" | null — asserts the *absence* of an observation |
| `HL DevelopmentStage` | "No information" | null — asserts nothing |

Keep a sentinel that states something; null one that states nothing. Nothing
to raise upstream, and nothing for obus to change.

**It also validates obus's own documentation.** `dr_HL_length()`'s roxygen
says `sex` is `NA` for "never assessed" and keeps `"U"` (assessed,
undetermined) distinct from it. Given `-9` = "not sampled" nulls to `NA`,
that reading is exactly right — the `NA` level of the `sex` grain is a
meaningful category, not merely missing data, which is why it earns its own
row rather than being dropped.

**Still not a reason to use `-9` as a join key.** `na_matches = "na"` is
exact, explicit, and renders as SQL's own `IS NOT DISTINCT FROM`.
Substituting a sentinel to make `=` work would put a non-value into the value
space of numeric fields that are summed (`TotalNumber`,
`SpeciesCategoryWeight`), silently corrupting totals rather than merely
failing to match — trading a loud join bug for a quiet arithmetic one.

## 2026-08-31 -- the HL_summary/HL_length disagreement, properly classified

Redone after the first attempt used relative-magnitude buckets — which is the
error `obus_retired`'s own notes warn about: a summary statistic cannot tell
arithmetic apart from a miscount. Full write-up in
`vignettes/articles/catch-tables.qmd`. Two method points that did the work:

1. **Compare in submission units.** `DataType == "C"` scales both sides by
   `HaulDuration/60`, so a real one-fish gap in a 30-minute haul reads as 0.5
   and hides under any sub-unit tolerance. The earlier 3.37% figure was wrong
   in both directions — it counted sub-unit arithmetic as disagreement *and*
   missed real C-type gaps.
2. **A sub-unit gap is arithmetic, categorically.** A non-integer raising
   factor on integer counts cannot give an integer; the reported
   `TotalNumber` is one. No magnitude judgment needed, and it belongs out of
   the statistic entirely.

Result: 89.01% exact, 7.14% arithmetic (excluded), **3.85% real** (73,596
groups). And the real part is two populations, which any single statistic
blends into a meaningless middle:

- **1-2 fish, direction ~50/50** (32,034 groups, 44%) — two independent counts
  of one haul. Not an error in either table.
- **6-50 fish, 81-86% one-directional** (3,891 groups, 5%) — systematic
  under-raising. **The part actually worth chasing.**
- **Can-Mar** (30,214, 41%) — median 13 fish, 98% directional, known
  provider-side conversion.
- **>50 fish** (462, 0.6%) — direction *flips*, 61.5% length-sum-higher; NSSS
  100% and PT-IBTS 95%. Consistent with duplicated length rows.

- [x] **Schema-pin test added** (`tests/testthat/test-published-schema.R`,
      2026-09-01). Pins the published column names of HL_summary, HL_length,
      hl_flag, hl_flag_code and species, the dr_con()/dr_con_raw() table sets,
      and `.id`'s value. Verified by simulating a `w_haul` -> `w_catch` rename;
      it fails with a column-by-column diff.

      **Scope corrected the same day.** This was first justified as the defence
      against silent renames, using `n_haul` -> `n_totalnumber` as the example.
      That example does not hold. `n_haul` in HL_length is a DIFFERENT quantity
      (raised length frequency) from HL_summary's reported `TotalNo`, and every
      `n_haul` reference in imbus and datrasdoodle2 turned out to be to the
      length-derived one, which never changed. Distinct names for distinct
      quantities was a fix, not a hazard. The rename broke nothing.

      What the test is actually worth: a guard against ACCIDENTAL renames and
      reorderings during refactoring, and — via its online half — against a
      published file drifting behind its source, which did happen here.

- [ ] **Schedule a render of the consumers. This, not schema pinning, is the
      real fix.** The drift that actually broke imbus and datrasdoodle2 was
      REMOVED FUNCTIONS (`dr_HL_standardised()` x30, `dr_get()` x15, the
      `dr_check_*` family), and those fail loudly the moment anything runs
      them. Nothing noticed because nothing re-executes obus: measured across
      imbus, **0 obus calls inside executable chunks, 53 in prose**. A weekly
      CI render of either consumer would have caught the lot on day one.

- [ ] **Chase the 6-50 fish directional bucket (~3,900 groups).** Same
      signature as Can-Mar's lost raising factor but in surveys with no known
      conversion event. This is the real open question, and it is two orders
      of magnitude smaller than the headline rate made it look.

## 2026-09-01 -- official-document audit

15-agent audit of every ICES primary source in `imbus/DATRAS/external`, with two
adversarial verifiers re-checking quotes against sources and recomputing every
figure. Written up in `vignettes/articles/catch-tables.qmd`. Headlines:

**obus reads the documents correctly; the documents are the broken party.**
`TotalNo=SUM(HLNoAtLngt)` in the field descriptions is a defect, disproved from
inside the same workbook: its own `Example file` sheet shows
`TotalNumber = 9766.059` against `sum(NumberAtLength) = 237`, `NoMeas = 237`,
`SubFactor = 41.207` — i.e. 237 x 41.207, the *raised* sum. Corroborated by the
FAQ's DataType R rule, its Annex I, and both its worked examples. The stale
fragment survives a March-2024 rewrite of the same cell.

**ICES's own index procedures never read `TotalNo`** (zero hits in
`Indices_Calculation_Steps_IBTS/BITS`); they raise the length frequencies —
which is `dr_HL_length()`. But it is NOT true that ICES never consumes it:
WKDATR13 (2013) 3.2.1.3 agreed exactly this comparison as a submission check,
with a worked 2,473-fish example, and WKABSENS 2021 step 17a uses `TotalNo` as
a fallback. What no document states is what a *user* should do when the two
disagree.

**`TotalNo`'s scope is documented three incompatible ways** — FAQ (2014 on) per
species x sex x category; spreadsheet (<=2023) haul x species; spreadsheet
(2024 on) per species x sex x devstage x category. Both submitter conventions
are in the archive with nothing marking which a row follows. obus's hybrid
dedup is an arbitration between mutually exclusive published rules, not a
deviation from one.

**obus's DataType C handling has published precedent** — WKABSENS 2021 3.3
step 17 gives the HaulDur/60 multiplier verbatim. One genuine divergence: its C
multiplier is HaulDur/60 *only*, with no `SubFactor` term, where obus also
multiplies by `SubsamplingFactor`.

- [x] **FIXED for DataType P (2026-09-01) — was inflated for 1,702 haul x species groups
      (428,460,564 g, 1.81% of all weight mass).** Weight repeated across
      `SpeciesCategory` is summed once per category. Under `DataType` P this is
      the documented convention ("CatCatchweight value is same in each
      subcategory"), so 1,491 P groups are affected — close to 29% of all P
      weight mass, because sub-category sampling is used precisely on the big
      catches. A further 211 R groups are affected and are **undocumented**,
      135 of them NS-IBTS 2025 Q3 GB platform 74E9. Worked case:
      `NS-IBTS:2016:1:GB-SCT:748S:GOV:12:12` aphia 126437 returns
      `w_haul = 210,600 g` for a 105,300 g catch.

      **A fix must be DataType-conditional.** For `R` the NL control case in
      ICES's own worked spreadsheet proves summing weight over `CatIdentifier`
      is correct (ratio 1.0), so simply dropping `SpeciesCategory` from the key
      would break `R`. The count path is unaffected: for all 1,491 P blocks the
      underlying length frequencies differ.

      Left unfixed deliberately — the user's instruction is that the functions
      stay as they are pending a decision.

- [ ] **Verify the published parquets against a fresh build.** `data-raw/raw`
      and `data-raw/to_https` were cleaned during the audit. The server copies
      carry the current schema (`n_totalnumber`, `DevelopmentStage`), but a
      rebuild is needed to confirm they match the current code byte-for-byte.

## 2026-09-01 -- the flag tables

`hl_flag.parquet` + `hl_flag_code.parquet`, built by
`data-raw/DATASET_hl_flag.R` from `data-raw/hl_flag_code.csv`. Long format,
one row per `.id x aphia x code`, only for records that carry a code; the
lookup is a 15-row CSV that is edited by hand and is where the judgement sits.

Kept as separate files rather than columns in the products: `HL_length` is
~200 MB, and the flags encode current *understanding* while the data does not
change, so revising a code costs a 12 MB republish rather than a 200 MB one.

**`kind` is the column to filter on**, because most flagged records are not
defects:

| kind | groups | meaning |
|---|---|---|
| `property` | 1,050,534 | a fact about the record (no lengths, no weight, factor absent) |
| `intrinsic` | 185,246 | the two totals legitimately differ; neither table is wrong |
| `suspect` | 20,332 | likely a submission problem, direction known |
| `unexplained` | 4,296 | flagged, mechanism not established |
| `inflated` | 1,700 | obus's own output overstates a value |

Only **22,031 of 2,291,457 groups (0.96%)** carry `inflated` or `suspect`.

ICES's D2.2 guideline settled two things the codes rest on: the count chain is
`NumberAtLength --SUM--> SubsampledNumber --x SubsamplingFactor--> TotalNumber`
(so obus's raising is right and `TotalNo=SUM(HLNoAtLngt)` is the error), and
the DataType P raising factor IS category weight / sample weight, which is
*why* the category weight repeats across pseudocategory rows.

- [x] **Published `hl_flag` and `hl_flag_code`** (2026-09-01 21:05 GMT). Verified
      against the server: 1,262,108 rows, 15 codes, `kind` breakdown matches the
      local build, spot-check on the worked weight case returns the right codes.
      `dr_con("hl_flag")` and `dr_con("hl_flag_code")` work with no `path`.

      **The `kind` assignments are accepted as they stand**, including the two
      that were flagged as arguable: `CNT_RAISE_LOST` = `suspect` (20,004 groups,
      overwhelmingly Can-Mar, with an explicit "prefer the reported total"
      recommendation) and `CNT_C_SMALL` = `intrinsic` (10,004 groups, a heuristic
      that cannot be proven per individual record). Do not reopen these without
      new evidence.
- [ ] **`CNT_OTHER` (3,949) and `CNT_DIRECTIONAL` (249) are the unexplained
      residue.** Everything else now has either a mechanism or a reason not to
      worry. This is the remaining analytical question, and it is two orders of
      magnitude smaller than the headline disagreement rate suggested.

## 2026-09-01 -- the DataType P weight fix

`dr_HL_summary()` now deduplicates catch weight on the **main** category under
`DataType == "P"`, not on the reported `CatIdentifier`.

ICES's own guidance makes this structural: a pseudocategory's raising factor
**is** category weight / sample weight (290.1 / 122.1988 = 2.374 in its worked
haddock example), so the category weight necessarily sits on every
pseudocategory row. `CatIdentifier` is a two-part code under `P` — verified,
every P code in the archive is exactly two digits (11-14, 21-23, 31).

**Effect: 1,458 groups changed, 409,946,801 g removed (1.73% of all `w_haul`
mass), every change a decrease and none an increase.** The worked case
`NS-IBTS:2016:1:GB-SCT:748S:GOV:12:12` aphia 126437 went from 210,600 g to
105,300 g for a 105,300 g catch. `HL_length` and `n_totalnumber` are untouched;
the count cross-check is unchanged at 3.85%.

Two regression tests, both from ICES's worked examples: the haddock case
(expects `991 + 290100`, not `+ 290100` twice) and the `R` control case
(expects 1,950 + 572,030 **summed**, guarding against over-collapsing).

**Deliberately NOT extended to `DataType R`.** 209 groups there also repeat a
weight across categories, but the cause is not established: 135 are a single
vessel-year (NS-IBTS 2025 GB 74E9), and of the 29 where `TotalNumber` differs,
some ties are implausible (two categories both exactly 9992 g) and some
plausible (two tiny catches both 12 g). Worth 485,711 g, 0.1% of the P defect.
They stay flagged. A `TotalNumber`-based discriminator was considered and
rejected — `TotalNo` and `CatCatchWgt` are independent fields, and one
repeating says nothing reliable about the other.

## 2026-09-01 -- published

All six parquets republished after the DataType P weight fix, and verified
against the server: worked case `w_haul` = 105,300 g (was 210,600), row counts
match the local build on all five tables, and the flag lookup is consistent
with the data again.

Two flag codes were re-tiered by the fix:

| code | was | now | why |
|---|---|---|---|
| `WGT_CAT_REPEAT_P` | `inflated` | `property` | obus collapses these correctly now; the repetition is a real feature of the submission, but `w_haul` is right |
| `WGT_CAT_REPEAT_R` | `inflated` | `unexplained` | "inflated" claimed more than is known — whether summing those 209 is wrong is unresolved |

**There are no `inflated` records left**, because obus no longer inflates
anything. Defect-flagged groups (`suspect`): 22,031 -> 20,332.

## 2026-09-01 -- `n_haul` in HL_summary

`HL_summary` now carries **both** routes to a catch total, side by side:

| column | source | meaning |
|---|---|---|
| `n_totalnumber` | reported `TotalNo` | what the submission declares |
| `n_haul` | Sum(`NumberAtLength` x `SubFactor`) | what the length frequencies reconstruct |
| `n_measured` | Sum `NumberAtLength` | how many fish were measured |

Same name as in `HL_length` on purpose: it is the same quantity computed the
same way, summed to this grain. `NA` where the species has no length data
(379,201 rows) or its raising factor is unknown.

**Why, having earlier argued against it.** Derivability was the wrong test —
`n_measured` is equally derivable and is stored anyway. The deciding points:
the derivation is a trap (a naive `left_join()` to `HL_length` fans out and
silently multiplies, so it must be a grouped sum); and the whole `hl_flag`
table exists to surface this disagreement, so making a user do a grouped join
to see its size was backwards. The 3.85% is now `n_totalnumber - n_haul`.

Cost: HL_summary 49.5 -> 53.3 MB. Verified zero disagreement with
`sum(HL_length$n_haul)` over 1,912,256 groups.

## 2026-09-01 -- dropped obus's own field names

The derived tables now carry opus's current names exactly as the raw archive
stages them. `Valid_Aphia` and `SpeciesSex` throughout; the former
`aphia`/`sex` renames are gone.

**Why.** The benefit was cosmetic — `aphia` reads better than `Valid_Aphia`.
The costs were permanent:

- every raw-to-derived join needed `by = c("Valid_Aphia" = "aphia")`
- a third naming layer that `op_crosswalk()` could not describe, so the
  authoritative mapping was incomplete by construction
- `dr_HL_summary()` errored on raw data unless the caller knew to rename first
- ICES's legacy `Sex` maps to `SpeciesSex` in HL but `IndividualSex` in CA —
  two genuinely different measurements (visual vs by dissection) that a single
  `sex` column would have flattened the moment a CA product appeared

It also cut against obus's own stated principle: never invent a fact opus or
ICES already owns.

**Timing.** Consumers referenced `aphia` 111 times, but were already broken
(30 dead `dr_HL_standardised()` calls in datrasdoodle2, 53 stale references in
imbus) and need rewriting regardless. The marginal cost was near zero on the
day the tables were first published, and rises from here.

### A collision the change exposed

Renaming the key to `Valid_Aphia` put it one capital letter away from
`valid_aphia`, the species lookup's WoRMS-forwarding column — two genuinely
different things (the code as submitted vs the currently accepted code; e.g.
124635 *Leptopentacta elongata* forwards to 1474372 *Paraleptopentacta
elongata*). Confusing them would silently join the wrong species.

So the WoRMS columns took a prefix: `status`/`valid_aphia`/`valid_name` ->
`worms_status`/`worms_aphia`/`worms_name`. Nothing now distinguishes two
meanings by capitalisation alone.

Note the latent trap in ICES's own name: `Valid_Aphia` means *the
datacenter-resolved code*, NOT *the currently-valid code*.

### Also fixed

`DATASET_species.R` now retries a failed WoRMS chunk with backoff. One
transient 500 anywhere in ~40 sequential requests previously discarded the
whole sweep several minutes in — observed on 2026-09-01, where the failing id
resolved perfectly on its own moments later.

Verified after rebuild: species unchanged in content (2,022 codes, 15
non-accepted, 11 forwarding), and the cross-check identical at 89.01% / 7.14% /
3.85% — the rename changed names, not values.

---

## 2026-09-02 -- length-weight, rebuilt

Regenerated from `obus_retired`'s cascade, keyed on `Valid_Aphia`, published as
its own table rather than folded into `species`. Verified end to end: the build
runs, and `dr_compare_length_weight()` on NS-IBTS 2015 Q1 reproduces the retired
build's headline numbers on the same data — **7,145 haul × species, median ratio
1.046, 27.4% outside ±25%** against retired's 7,145 / 1.04 / 27%.

Tier coverage over the 1,176 length-bearing species (retired's figures in
brackets): `ca_fit` 242 [244], `fishbase_bayes` 527 [525], `sealifebase_species`
61 [61], `_genus` 52 [51], `_family` 50 [47], `default_constant` 172 [172],
`unresolved` 29 [28], `not_applicable` 43 [43].

- [x] **Published 2026-09-02.** `length_weight.parquet` and
      `length_type_conversion.parquet` are live. Verified after upload: both
      byte-identical to the local build (2,022 and 2 rows), tier coverage
      matches, and `test-published-schema.R`'s online test now runs all seven
      tables and passes. Test suite 209 pass / 0 fail / 0 skip; `R CMD check`
      `Status: OK` (0/0/0) once `^docs$` was added to `.Rbuildignore` — that
      NOTE was pre-existing, not caused by this work.

      Note that commit `3ae5580`'s message says "R CMD check: 1 error" and
      explains it as the stale server file. True when written, stale now --
      publishing cleared it.

- [ ] **The midpoint fix shifted the external tiers, and nobody has arbitrated
      it.** `LengthClass` is a bin's lower boundary, so weights are now
      predicted from `length_cm_mid` (see AGENTS.md, Key Facts). `ca_fit`
      absorbed the change — its own coefficients moved with it (median `a`
      −15.1%, `b` +1.31%) and its median ratio is unchanged at 1.04, on 86% of
      the comparisons. The tiers fitted elsewhere did not.

      Isolated properly — one build, one set of coefficients, only `length_col`
      changing, NS-IBTS 2015 Q1. (Do NOT compare against the figures in
      `obus_retired`'s `dev/length_weight_notes.qmd`: those predate a different
      archive and a different FishBase snapshot, so the difference there is not
      attributable to the length convention.)

      | tier | n | lower bound | midpoint | lift |
      |---|---:|---:|---:|---:|
      | `ca_fit` | 6174 | 0.995 | 1.038 | 2.9% |
      | `fishbase_bayes` | 381 | 0.986 | 1.063 | 5.8% |
      | `sealifebase_species` | 301 | 1.068 | 1.149 | 9.5% |
      | `sealifebase_genus` | 154 | 1.346 | 1.454 | 2.2% |
      | `default_constant` | 82 | 1.174 | 1.434 | 20.6% |
      | `sealifebase_family` | 53 | 0.785 | 0.798 | 2.5% |

      The `ca_fit` row is not a retired-vs-new comparison — both its columns use
      the new midpoint-fitted coefficients, so its lower-bound column pairs them
      with a length convention they were not fitted under. `default_constant`
      moves most because its species are smallest: median 5.5 cm in 1 cm bins,
      where the correction is ~30%, against `ca_fit`'s 20 cm in 0.5 cm bins at
      ~4%.

      **This is not a regression to tune away.** External coefficients are
      fitted on actual measured fish, so feeding them the midpoint is the
      correct operation and the previous ~1.0 was two errors cancelling. But it
      leaves a real open question — whether the residual over-prediction is
      FishBase's coefficients, the reported `SpeciesCategoryWeight`, or both —
      and the house rule is to surface a two-measurement mismatch, not to pick
      a winner. `dr_add_predicted_weight(exclude_tiers = ...)` is the caller's
      lever meanwhile.

      One thing that did improve: `sealifebase_genus`'s median ratio is 1.45,
      against the 3.94 the retired build reported. Not attributed — the
      archive, SeaLifeBase's own contents and the length convention all changed
      at once, and no one has separated them.

- [ ] **The midpoint assumes lengths are uniform within a bin.** They are not
      quite: a declining length-frequency puts slightly more fish below the
      midpoint. The bias from that is second-order (~0.03% at 30 cm with 1 cm
      bins, against the 5.1% the lower bound cost) and correcting it means
      assuming a within-bin distribution. Recorded, not planned.

- [ ] **`datrasdoodle2`'s chapter 09 (`09-weight-from-length.qmd`) is stale.**
      It calls `dr_lookup_length_weight` (an eager `.rda` that no longer
      exists — it is `dr_con("length_weight")` now), `dr_con("CA")` (now
      `dr_con_raw("CA")`) and `aphia` (now `Valid_Aphia`), and predicts from
      `length_cm` throughout. Nothing re-executes obus, so none of this fails
      until someone renders it.

---

## 2026-09-04 -- the engine question: duckdbfs, and duckplyr rejected
### The engine question, which arrived with it: drop duckdbfs?

**Tested 2026-09-04, works.** `duckdbfs` appears in the shipped package
exactly twice — `duckdbfs::open_dataset(full_path)` at `R/dr_con.R:63` and
`:174` — and both call sites pass a **single resolved file path**. Nothing
duckdbfs exists for is used: no partitioning, no globbing, no S3, no
multi-file datasets, because every obus path is one unpartitioned parquet.

A ~12-line replacement on plain `DBI` + `dbplyr` + `duckdb` passed six checks
against the live archive:

| check | result |
|---|---|
| lazy table | `tbl_duckdb_connection`, same class duckdbfs returns |
| verbs push to SQL | `SELECT COUNT(*) … FROM read_parquet('https://…') WHERE …` |
| NS-IBTS 2022 Q1 hauls | 249 |
| **cross-file join** (raw HL x `species.parquet`) | whiting 4151, herring 3444, haddock 3069 |
| identical to duckdbfs | `TRUE` |
| local path | works |

```r
.e <- new.env(parent = emptyenv())
dr_conn <- function() {
  if (is.null(.e$con) || !DBI::dbIsValid(.e$con)) {
    .e$con <- DBI::dbConnect(duckdb::duckdb())
    try(DBI::dbExecute(.e$con, "INSTALL httpfs"), silent = TRUE)
    DBI::dbExecute(.e$con, "LOAD httpfs")
  }
  .e$con
}
dr_open <- function(p) dplyr::tbl(dr_conn(),
  dbplyr::sql(paste0("SELECT * FROM read_parquet('", p, "')")))
```

**Not a dependency-trimming argument.** duckdbfs imports `DBI, dbplyr, dplyr,
duckdb, fs, glue`; obus would declare `DBI`, `dbplyr`, `duckdb` explicitly and
shed only `fs` and `glue`. Two light packages. The real reasons are:

1. **obus would own the invariant it calls load-bearing.** `AGENTS.md` states
   that both connections resolving to one DuckDB connection "is load-bearing,
   not incidental" — and that currently rests on another package's internal
   cache.
2. **The dependency graph would become honest.** The whole architecture
   discussion is about DBI connections and dbplyr join semantics, and obus
   declares none of DBI, dbplyr or duckdb; it declares duckdbfs and receives
   them by accident.
3. **The metadata work above wants direct `COPY` control anyway.** Assembling
   raw SQL fragments and handing them to a wrapper that comma-collapses them is
   odd layering, and the `dbQuoteString()` escaping trap sits right there.

### Correction, written after implementing it (2026-09-04)

**The case above overstated itself, and the record should say so.** Two of the
three arguments did not survive being tested.

1. **"Nothing duckdbfs exists for is used" was wrong.** That judgement came
   from evaluating the *dataset abstraction* — partitioning, globbing, S3 —
   which is genuinely unused. It missed the **connection registry**, which was
   the real value: a shared cached connection meant obus's tables could be
   joined to anything else a user opened with duckdbfs, with no ceremony.
   Dropping it broke cross-package interop, which surfaced only when the user
   asked whether datrasdoodle2 still worked —
   `appendix-cpuel-vs-standardised.qmd` failed with "`x` and `y` must share the
   same source". Two new exports (`dr_duckdb()`, `dr_parquet()`) exist to
   rebuild an obus-only version of what duckdbfs provided globally.
2. **"The metadata work needs raw `COPY`" is largely void.** Tested earlier the
   same day: `duckdbfs::write_dataset(options = c("COMPRESSION 'zstd'",
   "KV_METADATA {…}"))` works, five cases including JSON payloads and multiple
   keys in one block. duckdbfs would have carried the metadata work. What
   remains of the objection is layering aesthetics, not capability.
3. **Only "obus should own the invariant it calls load-bearing" stands**, and
   it is a modest argument on its own.

**What obus now maintains that duckdbfs maintained for it:** the connection
registry, connection lifecycle and `.onUnload`, extension install/load, the
`shared_home` argument-position trap, SQL literal escaping, and lazy httpfs
loading — around 70 lines plus two exports, in exchange for shedding two light
packages (`fs`, `glue`). The tell is that most of the work after the decision
was re-solving problems duckdbfs had already solved, including the
`shared_home` trap that opus had also fallen into (`dbConnect(..., shared_home
= FALSE)` is a no-op; it belongs to `duckdb::duckdb()` — fixed in opus
2026-09-04, where the explicit `INSTALL httpfs` is load-bearing because
`autoinstall_known_extensions` defaults to FALSE).

**Had the registry been assessed properly up front, the recommendation would
have been:** keep duckdbfs for the connection, use a raw `COPY` only in
`dr_write()` for the metadata. That is still the cheapest position if this is
ever revisited.

**Why it was reverted the same day, and what this paragraph used to claim.**
It previously read "left in place — reverting would cost more than it
recovers", citing the removal build's own verification: `HL_length`
byte-equivalent to the reference build (14,001,605 rows, `EXCEPT` 0 both
directions, 207.8 MB), 243 tests passing, `R CMD check` 0/0/0. Every one of
those numbers was true and **none of them touched the property that mattered**,
because cross-package interop is not observable from inside obus's own test
suite — which is precisely where the failure was. That is the lesson worth
keeping: a verification that cannot see the thing you broke is not evidence.
`duckdbfs` stays. The durable product of the exercise is the accessor that
should have existed all along — `dr_duckdb()` and `dr_parquet()`, exported
2026-09-04 — plus the raw `COPY` in `dr_write()`, which is kept for SQL
literal escaping at the point the literal is built, not for capability.

**The regression, which is not hypothetical — it happened.** A user could
join `dr_con("HH")` to their own `duckdbfs::open_dataset(...)` because both
landed on duckdbfs's shared cache. The private connection broke that with
exactly the error `AGENTS.md` documents ("`x` and `y` must share the same
source"), and it surfaced from *outside* obus, in datrasdoodle2's CPUEL
appendix. Hence the two exports: `dr_duckdb()`, so a local frame can be
`copy_to()`'d onto the connection, and `dr_parquet()`, so an arbitrary file
opens on it too. Nine test call sites moved off
`duckdbfs::cached_connection()` onto the accessor and their skips moved from
`"duckdbfs"` to `"duckdb"` — churn, though the tests arguably should not have
depended on a third party's cache in the first place.

### Going all the way to duckplyr: tested and NO (2026-09-04)

duckplyr 1.2.1 installed on the user's instruction and run against the real
local archive (`data-raw/raw`, HL 14.4M rows). The read side works; **the
package's own core does not translate**, and the argument for switching
inverts once measured.

**What works.** Remote and local parquet via
`read_parquet_duckdb(path, prudence = "stingy")`; the return is a
`prudent_duckplyr_df / duckplyr_df / tbl_df / data.frame` — a data.frame
subclass, not a `tbl_lazy`. Same answers as dbplyr (249 NS-IBTS 2022 Q1 hauls
both routes). The **cross-file join works** — raw HL x `species.parquet` gives
whiting 4151, herring 3444, haddock 3069, identical to the dbplyr POC.
`compute_parquet(x, path, options = list(COMPRESSION = "zstd"))` writes.

**What does not translate**, tested one operation at a time on a stingy frame:

| translates | does **not** translate |
|---|---|
| `as.integer()`, `if_else()`, `coalesce()`, `n_distinct()`, `count()`, `select()`, logical ops | `as.character()`, `paste0()`, `paste()`, `sprintf()`, `format()`, `nchar()`, `toupper()`, `substr()`, `as.numeric()`, **`case_when()`**, `first()` in `summarise()` |

**That blocks obus at step one.** `dr_add_id()` fails immediately —
`.dr_concat_ws()` needs `as.character()` and `paste0()`, so `.id`, the join key
both catch tables are built on, cannot be constructed. `dr_add_length_cm()`,
`dr_add_length_mm()`, `n_haul` and `n_hour` are all `case_when()`, so they are
blocked too. Nothing downstream of those runs. The full-build test got three
green lines (reading the inputs) and then stopped.

There is an irony worth recording: `.dr_concat_ws()` exists **because**
`paste(sep=)` resolves differently in eager R than through dbplyr's
`CONCAT_WS()`. duckplyr cannot translate `paste()` at all.

**The escape hatch is the disqualifying part, not the rescue.** Under
`prudence = "lavish"` the pipeline completes — `dr_add_id()` on 150,217 HH rows
in 1.3s — but with `fallback_config(info = TRUE)` the mechanism is plain:

```
Error processing duckplyr query with DuckDB, falling back to dplyr.
Caused by error in `dplyr::mutate()`:
! Can't translate function `as.character()`.
```

followed by **seven more** falling back on `case_when()`. Eight R-side
fallbacks in one call to one obus function.

**So the prize this file claimed is backwards.** The stated argument for
duckplyr was that one evaluation engine would delete the eager/lazy divergence
class that `.dr_concat_ws()` and `.dr_coalesce_with_provenance()` exist to work
around. In fact duckplyr would run obus's pipeline through **both** engines —
DuckDB where it can, R where it cannot — which is *more* engine mixing than
today, at a boundary that is invisible unless fallback info is switched on. The
current dbplyr arrangement at least puts the boundary where obus chose it and
tests both sides deliberately.

**Verdict: not viable for obus as written.** Not "a verb sweep" as this file
previously guessed — the gap is the string and `case_when()` families, which is
most of what obus's derived columns are made of. Rewriting around it would mean
expressing every derived column in `if_else()`/`coalesce()`/`as.integer()`, and
`.id` has no expression at all without string concatenation.

**Asked and answered: would `tidyr::unite()` do it instead of
`.dr_concat_ws()`?** No, and nothing else does either. Tested 2026-09-04 on a
stingy frame — every route to a concatenated key fails:

| route | result |
|---|---|
| `tidyr::unite()` | `Materialization is disabled, use collect()…` |
| `stringr::str_c()` | not translated |
| `stringr::str_glue()` | not translated |
| `glue::glue()` | blocked on `as.character()` |
| `concat()` — DuckDB's own name | not translated |
| `concat_ws()` — DuckDB's own name | not translated |

The decisive detail is the last two rows: **duckplyr does not pass unknown
functions through to SQL.** It works from a closed allowlist, so naming
DuckDB's native `concat_ws` does not reach it. There is no expression for `.id`
under `stingy` in 1.2.1.

`unite()`'s failure is also broader in kind, and worth knowing separately:
it is not a translation gap but the fact that **tidyr verbs are not part of the
duckplyr backend at all** — they operate on the data frame and therefore force
materialisation. obus's own tidyr surface is small (`tidyr::nest()` in
`dr_length_weight.R:70`, and one doc reference to `tidyr::separate()`), but any
future lazy pipeline reaching for a tidyr verb would hit this rather than a
missing translation.

**Revisit only when duckplyr gains string and `case_when()` translation.**
Worth a re-test at each release; the read-side story is otherwise good and the
`stingy` failure mode is genuinely well designed — it names the unsupported
function at the call site, which is how this was diagnosed in minutes.

**Unaffected by any of this:** dropping duckdbfs for plain
`DBI`/`dbplyr`/`duckdb` (tested, works, previous subsection) and the metadata
work, which needs raw `COPY` either way. duckplyr's `compute_parquet()` also
cannot write `KV_METADATA` — all four syntaxes fail with
`Expected kv_metadata argument to be a STRUCT`, because duckplyr renders option
values as SQL scalars and DuckDB needs an unquoted struct literal.

### Downstream

A datrasdoodle2 chapter on reading the archive's metadata is still only
proposed: the archive is readable without any R package (`SELECT decode(value)
FROM parquet_kv_metadata(…)`), and `datras:known_issues` ships a record of the
archive's own defects — its first entry is `sentinel_replacement_data_loss`,
severity `opus-internal`. It would suit an early chapter that the known-issues
chapter later collects from.

What *did* get written that day was a different chapter: datrasdoodle2's
`interoperability.qmd`, drafted from the two `data-raw/CHECK_datras_*.R`
harnesses and live-verified on every render — the `N` matrix, `HaulN`,
`HaulWgt`, `SweptArea` and a stratified index all identical whether the source
is `HL_length` + `HL_summary` or a `DATRASraw` read from the exchange file.
The three survey documents that used to sit at this repo's top level went there
too, as a parked appendix, before the branch holding them was deleted.

## 2026-09-04 -- resolved TODO items, moved out of TODO.md

Eleven items that were carrying `[x]` in `TODO.md` -- a file whose header
says it tracks outstanding work only. Each is a finding with its reasoning,
so they belong here rather than being deleted. Verbatim, in the order they
appeared, grouped by the section they came from.

The `## Done` section went too, unmoved: nine checkbox lines inventorying
what obus exports and what was verified, all of it already stated better in
`AGENTS.md`'s Implementation and "Measured on the full archive" sections.

- [x] **RESOLVED — `SpeciesValidity` stays in the grain.** Settled against
      ICES's own documentation (`~/R/Pakkar/imbus/DATRAS/`), not inference:
      `SpeciesValidity` is a *record type* field, the HL format deliberately
      allows several per species per haul, and the docs state plainly that
      aggregating over `.id x aphia` without it "silently mixes record types."
      Archive measurement independently reproduces ICES's own reported
      pattern (commonest pairs `{1,5}` and `{4,7}`). Filtering to one code
      makes `.id x aphia` exactly unique. **Caveat: Can-Mar** puts real length
      data on `"5"` rows, so filtering to `"1"` there discards genuine data —
      treat Can-Mar separately.

- [x] **Test suite exists** — 24 tests in `tests/testthat/`, ported from
      `obus_retired` and extended, running inside `R CMD check`. They encode
      all three of the retired package's bugs plus this pass's five. Crucially
      they run **eager** while the build runs **lazy**, which is what caught
      both R/SQL `NA` divergences; keep both paths.

- [x] ~~**Drop `duckdbfs` for plain `DBI`/`dbplyr`/`duckdb`.**~~
      **Implemented and reverted, both on 2026-09-04.** The dataset
      abstraction is genuinely unused, but the *connection registry* is not,
      and a private connection broke cross-package joins silently. What
      survives is the position the correction below arrives at: keep
      `duckdbfs` for the connection, export an accessor (`dr_duckdb()`,
      `dr_parquet()`), and use a raw `COPY` only in `dr_write()` for the
      metadata. That is what the tree does as of 2026-09-07. Full account in
      the section at the end.

- [x] ~~Decide whether to go all the way to `duckplyr`.~~ **Tested
      2026-09-04: no.** duckplyr 1.2.1 does not translate `as.character()`,
      `paste0()`/`paste()` or `case_when()`, so `dr_add_id()` and every
      derived-column function are blocked; under `lavish` it completes only by
      falling back to R eight times in one call. Re-test when the string and
      `case_when()` families land. Full findings in the section at the end.

- [x] **CHECKED — `DataType == "-9"` is benign.** 40 hauls archive-wide, and
      **every one is independently `HaulValidity == "I"`** — the vocabulary's
      "Invalid hauls" and the haul-validity flag agree completely, with no
      contradicting case. They carry 32 HL rows and **zero length rows**, so
      they contribute nothing to `HL_length`; their 32 `HL_summary` rows come
      out all-`NA` because the underlying `TotalNumber`/weights are themselves
      absent. Spread thinly over BITS, FR-CGFS, NS-IBTS and EVHOE, 2004-2018.
      No warning needed; callers wanting them gone can pass
      `haulval = "V"`.

- [x] **CLOSED — the `.id` item was misleadingly worded and is a non-issue.**
      It referred only to the *raw* archive (`datras/raw/*.parquet`), which
      ships without `.id`, so `data-raw/DATASET_products.R` computes it with
      `dr_add_id()` during a rebuild. Every **published** obus table —
      `HH`, `HL_length`, `HL_summary` — carries `.id` as a stored column;
      nothing recomputes it at read time, and `dr_con()` users never pay for
      it. The build cost is seconds, once per rebuild.

- [x] **Sentinel handling needs nothing from obus** — resolved 2026-08-31.
      opus applies its own `op_sentinels()` policy when building the raw
      archive, so `-9` is already resolved before obus reads it, per a
      documented and coherent rule. See the `-9` section below. obus must not
      re-introduce sentinels locally: it cannot tell which NULLs were `-9`.

- [x] **RESOLVED — NS-IBTS 2022 Q1 is not truncated; 32,767 is a
      coincidence.** Investigated 2026-08-31. The suspicion was that HL had
      been cut at exactly 2^15-1 rows. It had not: the survey was simply
      smaller that year, and the row count is exactly what the haul count
      predicts.

- [x] **RESOLVED — `Inf` from `HaulDuration <= 0`.** An hourly rate is
      undefined with no time fished, so `*_hour` is now `NA`, not `Inf`.
      `DataType == "C"` is the mirror image — it reports a rate directly, so
      there the rate survives and the per-haul figure goes `NA` instead of a
      plausible-looking `0`. Verified: 0 `Inf` and 0 `NaN` anywhere in either
      table. Only 7 hauls with duration <= 0 actually carry HL rows (6 `P`,
      1 `R`) — exactly the 7 `obus_retired` named — so the `C` and negative
      guards are correct but touch no published row today; they protect
      future submissions. The 2 negative-duration hauls (Can-Mar 2017, both
      already `HaulValidity == "I"`) likewise have no HL rows.

- [x] **RESOLVED — `n_haul` renamed to `n_totalnumber` in `HL_summary`.** By
      design it is the *reported* `TotalNumber`, while `dr_HL_length()`'s
      `n_haul` reaches the same conceptual quantity by raising measured length
      frequencies. Calling both `n_haul` invited exactly the confusion the
      3.44% disagreement makes material. `n_hour` follows as
      `n_totalnumber_hour`. `w_haul`/`w_hour` keep their names —
      `SpeciesCategoryWeight` is their only possible source, so there is no
      competing quantity to confuse them with.

- [x] **SUPERSEDED 2026-09-01 — `n_haul` added to `HL_summary`.** The earlier
      "nothing to add" reasoning was inconsistent: `HL_summary` already carried
      `n_measured`, the raw un-raised sum of `NumberAtLength`, so the table
      already crossed the length-path boundary. It carried the un-raised length
      count but not the raised one, which is the only figure directly
      comparable to `n_totalnumber`. That was arbitrary. Verified after the
      change: zero of 1,912,256 groups differ from summing `HL_length`.
