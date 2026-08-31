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

- [ ] **`dr_add_n_and_cpue()` returns `NA` for `DataType == "-9"` and for
      any unrecognised code, silently.** Correct, but a submission with an
      unexpected `DataType` would vanish into `NA` with no signal. Worth a
      count-and-warn if it ever matters.

- [ ] **The raw archive has no `.id`; obus builds it on every read.** Fine
      at this scale (14M rows, a few seconds). If it stops being fine, the
      right fix is upstream in opus's own consolidation, not a cache here.

- [ ] **`CA` is fetched by `DATASET_species.R` but nothing else uses it.**
      It contributes aphia codes to the species lookup and is otherwise
      untouched. An `age`/`length` product would be the natural next thing
      to build, and `dr_add_id()` already works on it unchanged.

- [x] **Sentinel handling needs nothing from obus** — resolved 2026-08-31.
      opus applies its own `op_sentinels()` policy when building the raw
      archive, so `-9` is already resolved before obus reads it, per a
      documented and coherent rule. See the `-9` section below. obus must not
      re-introduce sentinels locally: it cannot tell which NULLs were `-9`.

- [ ] **Possible truncated submission upstream — NS-IBTS 2022 Q1 HL is
      exactly 32,767 rows (2^15 − 1).** Still true in the raw archive
      (confirmed 2026-08-31). Neighbouring quarters of the same survey run
      44k–52k. Not an obus bug and nothing here works around it; a
      candidate for opus's known-issues registry and one targeted question
      to ICES.

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
`sum()` adds length classes. Quote **`> 0.51`: 66,310 (3.44%)**, which is
stable; `> 0.5` gives ~66,674 and is kept only for comparison to the 66,629.

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
      every other survey. ICES documents this as unresolved. Can-Mar is also
      the single largest contributor to the mismatch count (30,220 of 64,542,
      47%), driven by its separately-documented 2021-22 historical conversion.
      It is likewise 98% of the rows affected by the missing-SubsamplingFactor
      change. Any serious attempt to reduce the residual starts here.
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
