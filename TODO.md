# obus — TODO

**Status:** Rebuilt 2026-08-31 from an empty `R/`. Nine exported functions,
`R CMD check` clean (0/0/0), all three product parquets built and verified
locally against the full archive. **Nothing is published yet.**

---

## Done

- [x] `dr_con_raw()` / `dr_con()` — lazy DuckDB views over `datras/raw` and
      `datras`, both on one connection so raw ⋈ derived joins work
- [x] `dr_add_id()` — the eight-field haul key, new names only, with the
      backend-consistent NA-skipping concat
- [x] `dr_add_length_mm()`, `dr_add_length_cm()`, `dr_add_n_and_cpue()`,
      `dr_join_species()`
- [x] `dr_HL_length()`, `dr_HL_summary()` — ported from `obus_retired`
      including the per-sex `TotalNumber` reconciliation and the
      `SpeciesCategory` fallback fix
- [x] `data-raw/DATASET_species.R` — `species.parquet` rebuilt from scratch
      off WoRMS; 2,022 aphia, all resolving
- [x] `data-raw/DATASET_products.R` — `HH`, `HL_length`, `HL_summary`,
      built entirely lazily
- [x] **Verified against the full archive**: `.id` unique over 150,217
      hauls, zero NA, zero orphan HL rows; `HL_length` reproduces the
      published `HL_standardised` exactly on NS-IBTS 2022 Q1 (29,752 rows,
      zero differences); the summary-vs-length cross-check lands at 3.49%,
      against the 3.5% the retired implementation measured
- [x] `R CMD check`: 0 errors, 0 warnings, 0 notes

---

## Immediate

- [ ] **Publish.** All four files are in `data-raw/to_https/` and none are
      on the server. `species.parquet` and `HH.parquet` *overwrite* what is
      already published, so this is not purely additive — the currently
      published `HH.parquet` is the previous generation.

      ```
      scp data-raw/to_https/{species,HH,HL_length,HL_summary}.parquet \
          einarhj@heima.hafro.is:~/public_html/datras/
      ```

      Note `HL_standardised.parquet` stays on the server, stale and now
      superseded. Decide whether to delete it or leave it; it is
      demonstrably wrong (see below) and nothing in this obus reads it.

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

## Later

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


- [ ] **`CA` is fetched by `DATASET_species.R` but nothing else uses it.**
      It contributes aphia codes to the species lookup and is otherwise
      untouched. An `age`/`length` product would be the natural next thing
      to build, and `dr_add_id()` already works on it unchanged.

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

      1. **HH is down too.** 249 hauls, against 325-387 in every other year
         2014-2026. A truncated HL would leave HH untouched.
      2. **Rows per haul is normal** — 131.6, inside the 117-145 range of
         neighbouring years. Regressing rows on hauls over the other twelve
         years predicts 37,755 rows for 249 hauls, 95% PI 25,207-50,303.
         Observed 32,767 sits inside it, so there is no shortfall to explain.
      3. **No truncated tail.** A file cut mid-stream would leave its last
         hauls abnormally short. The 2022 rows-per-haul distribution
         (min 3, median 129, max 344) matches 2021 (1 / 134 / 259) and 2023
         (3 / 142.5 / 263) — and 2022's *maximum* is the largest of the three.

      **What actually happened: reduced survey effort, concentrated in two
      countries.** NS-IBTS Q1 hauls, 2021 -> 2022 -> 2023: DE 67 -> **10** ->
      22; GB-SCT 61 -> **15** -> 54; DK 45 -> 27 -> 45. FR/NL/NO/SE are flat.
      Across all surveys in 2022, GB-SCT ran 307 hauls against 428 in 2021
      (-28%), so its reduction was fleet-wide; DE's total was steady
      (461 -> 428), so its shortfall was specific to NS-IBTS Q1.

      The original reasoning contained a base-rate error worth remembering:
      "it is the only one of 971 groups sitting on exactly that value" is not
      evidence of anything — nearly every specific row count is hit at most
      once. The question that settles it is whether the count is anomalous
      *given the haul count*, and it is not.

## Official docs are the authority (standing rule, 2026-08-31)

Only ICES's own published documents count as evidence for what a field means:
`~/R/Pakkar/imbus/DATRAS/external/` — chiefly
`DATRAS_Field_descriptions_and_example_file_December2025.xlsx` (including its
`General Notes` sheet), the SISP manuals, and the ICES workshop/working-group
reports. The authored `.qmd` files one directory up, and anything in
`obus_retired`, are pointers to where to look, not evidence. Findings are
written up in `vignettes/datras-conventions.Rmd`.

## Verification record (2026-08-31, full archive)

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
See "Where the two totals disagree" in `vignettes/datras-conventions.Rmd`:
compare in submission units and count whole fish. 89.01% reconcile exactly,
7.14% differ by less than one fish (arithmetic, excluded), and **3.85% differ
by at least one fish** — the figure to quote.

## Open, not resolved

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

- [ ] **Can-Mar `SpeciesValidity = "5"` rows carry real length data**, unlike
      every other survey. ICES documents this as unresolved. Separately,
      Can-Mar's lost raising factor is 30,214 of the 73,596 real disagreements
      (41%), median gap 13 fish, 98% one-directional — a documented
      provider-side conversion, not something obus can fix.
- [x] **RESOLVED — the two tables already give both quantities; nothing to
      add.** ICES's row-level formula is fully derivable from `HL_length`:
      summing its `n_haul` over `.id x aphia x SpeciesValidity` reproduces
      Sum(NumberAtLength x SubsamplingFactor) **exactly** — verified over
      1,925,444 groups with 0 differing, 0 present on only one side. So
      `HL_summary` should NOT carry a second, length-derived total: it would
      duplicate derivable information across two tables, which is precisely
      what the split exists to avoid.

      The division of labour is the right one:
        - `HL_length`, summed  -> the raised length-frequency total (ICES's
          recommended row-level formula)
        - `HL_summary$n_totalnumber` -> the reported `TotalNumber`
        - their disagreement (3.44%) -> visible by construction, which is the
          point

      `HL_summary` earns its `TotalNumber` because it is the *only* universal
      per-species total: 366,013 of its 2,291,457 rows (16%) are species with
      no length data at all, where no length-derived figure exists. The other
      84% have one available on demand.

      The join is clean — `aphia` and `SpeciesValidity` are never NA in
      `HL_summary`, so no `na_matches` is needed for this one:

      ```r
      dr_con("HL_summary") |>
        left_join(
          dr_con("HL_length") |>
            group_by(.id, aphia, SpeciesValidity) |>
            summarise(n_length = sum(n_haul), .groups = "drop"),
          by = c(".id", "aphia", "SpeciesValidity")
        )
      ```

      One caveat worth keeping: `HL_length$n_haul` embeds the documented
      `DataType == "R"` + NA `SubsamplingFactor` -> treat as 1 convention, so
      a naive `NumberAtLength * SubsamplingFactor` done by hand is NOT
      equivalent — it returns NA for those rows (5.35% of BTS's R rows,
      2.46% of NS-IBTS's). Sum `n_haul`; don't re-multiply the raw columns.

### A fourth eager/lazy divergence, found by the new duration tests

`sum(x, na.rm = TRUE)` over an all-`NA` group is **0** in R but **NULL** in
SQL. That silently converted the deliberate zero-duration `NA` straight back
into the false `0` it was meant to prevent — on the eager path only. Both
count and weight aggregations now carry an explicit non-NA counter and restore
`NA` when nothing was present, so the two backends agree. It also settles the
672,065 rows with no recorded weight as `NA` in both: "not weighed" is not
"weighed nothing".

This is the second bug in this pass caused by R and SQL disagreeing about
`NA` (the first was `NULL = NULL` in the joins). Anything aggregating or
joining in these two functions should be assumed to differ between backends
until checked both ways — the synthetic tests run eager, the build runs lazy,
so keeping both is what catches these.

## `-9` in HL: what it means, and why it is NULL (resolved 2026-08-31)

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


## The disagreement, properly classified (2026-08-31)

Redone after the first attempt used relative-magnitude buckets — which is the
error `obus_retired`'s own notes warn about: a summary statistic cannot tell
arithmetic apart from a miscount. Full write-up in
`vignettes/datras-conventions.Rmd`. Two method points that did the work:

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

- [ ] **Chase the 6-50 fish directional bucket (~3,900 groups).** Same
      signature as Can-Mar's lost raising factor but in surveys with no known
      conversion event. This is the real open question, and it is two orders
      of magnitude smaller than the headline rate made it look.


## Official-document audit (2026-09-01)

15-agent audit of every ICES primary source in `imbus/DATRAS/external`, with two
adversarial verifiers re-checking quotes against sources and recomputing every
figure. Written up in `vignettes/articles/datras-conventions.qmd`. Headlines:

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

- [x] **FLAGGED (not fixed) — `w_haul`/`w_hour` inflated for 1,702 haul x species groups
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


## The flag tables (2026-09-01)

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

- [ ] **Publish `hl_flag` and `hl_flag_code`** once the codes are agreed.
- [ ] **`CNT_OTHER` (3,949) and `CNT_DIRECTIONAL` (249) are the unexplained
      residue.** Everything else now has either a mechanism or a reason not to
      worry. This is the remaining analytical question, and it is two orders of
      magnitude smaller than the headline disagreement rate suggested.
