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

- [ ] **DECISION — collapse `SpeciesValidity` in `dr_HL_summary()`?**
      This is the one open correctness question, and it is the same bug
      the retired package already fixed twice, recurring one dimension
      over. Measured on the full archive 2026-08-31:

      - 1,219 of 2,290,227 haul × species groups (0.05%) report the same
        species under more than one `SpeciesValidity` code.
      - Of the 2,716 `SpeciesCategory`/`sex` sub-groups spanning more than
        one code, **2,642 (97%) repeat an identical `TotalNumber`** across
        them. Only 74 genuinely differ.
      - Typical shape: a full set of length rows under one code, plus one
        extra length-free row under another carrying the same
        `TotalNumber`/`SpeciesCategoryWeight` again. Confirmed on
        `BITS:2008:1:DK:26D4:TVL:206:30` / aphia 126425 — eight length rows
        at `SpeciesValidity == "1"` plus a ninth, empty, at `"4"`, both
        emitting `n_haul = 2764`, `w_haul = 31496`.

      Consequence as built: summing `n_haul` or `w_haul` per `.id × aphia`
      double-counts those groups. Currently documented, not fixed.

      The minimal fix mirrors the `SpeciesCategory` one exactly — drop
      `SpeciesValidity` from the fallback's `distinct()` key and from
      `already_claimed`, and out of the `hl_counts`/`hl_weights` grouping.
      What needs deciding first is what a collapsed row then reports for
      `SpeciesValidity`: the most-valid code present, the code that carried
      the length data, or a list. That is a contract change, not a bug fix,
      which is why it is a decision and not a checkbox.

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
