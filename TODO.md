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

- [ ] **No test suite.** `Suggests` and `Config/testthat/edition: 3` are in
      place; `tests/` does not exist. The natural first tests are the ones
      already run by hand: `.id` identical eagerly and lazily (the whole
      reason `.dr_concat_ws()` exists, and currently protected by nothing),
      `dr_add_length_cm()`/`dr_add_n_and_cpue()` on a small fixture, and
      the grain counts above as regression guards.

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

- [ ] **Sentinel-to-`NA` conversion** remains unimplemented and blocked on
      opus: opus ships `inst/DATRAS-known-issues.yaml` with `sentinels:`
      keys, and `op_sentinels()`/`op_strip_sentinels()`/`op_sentinel_policy()`
      now exist to read it. Worth re-checking whether that unblocks a
      per-field, evidence-based pass here — but it stays opt-in, never a
      blanket rule (AGENTS.md Working Principle 3).

- [ ] **Possible truncated submission upstream — NS-IBTS 2022 Q1 HL is
      exactly 32,767 rows (2^15 − 1).** Still true in the raw archive
      (confirmed 2026-08-31). Neighbouring quarters of the same survey run
      44k–52k. Not an obus bug and nothing here works around it; a
      candidate for opus's known-issues registry and one targeted question
      to ICES.

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

- [ ] **32 rows carry `Inf` `n_hour`/`w_hour`** — all
      `NS-IBTS:2018:1:GB-SCT:748S:GOV`, where `HaulDuration == 0`. Known and
      documented in `obus_retired`'s notes, never fixed there either. HH also
      has 51 NA and **2 negative** `HaulDuration` (min −514). Decide whether
      `n_hour` should be `NA` rather than `Inf` when duration is 0 — it is a
      real silent `Inf` in published output.
- [ ] **Can-Mar `SpeciesValidity = "5"` rows carry real length data**, unlike
      every other survey. ICES documents this as unresolved. Can-Mar is also
      the single largest contributor to the mismatch count (31,989 of 66,674),
      driven by its separately-documented 2021-22 historical conversion.
- [ ] **`HL_summary`'s `n_haul` comes from `TotalNumber`, but ICES's guidance
      is `n_haul = Σ(NumberAtLength × SubsamplingFactor)`** and it defines
      `TotalNo = SUM(HLNoAtLngt)`. The two are the same quantity when a
      submission is self-consistent — the 3.44% is exactly where they are not.
      Using `TotalNumber` is defensible (it is the only value for bulk-only
      species) but it is a real design choice worth revisiting, not a given.
