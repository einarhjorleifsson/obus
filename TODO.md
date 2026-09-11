# obus — TODO

**Status:** Rebuilt 2026-08-31 from an empty `R/`; length-weight added
2026-09-02; `dr_get()` and `dr_get_datras()` added 2026-09-09. Fifteen
exported functions, `R CMD check` clean (0/0/0), 337 tests passing including
the online schema check. **All ten tables are published** and verified live
against the code's schema (re-checked 2026-09-08). The DATRAS/DATRASextra
interop harnesses in `data-raw/` pass 11/11 and 25/25 — the adapter they test
is now `dr_get_datras()` itself, not a script-local copy.

*This file tracks outstanding work only.* Dated development history — what was
done, when, and why — lives in `DEVLOG.md`; settled design lives in
`AGENTS.md`; stated-but-untested hypotheses live in `PLAN-qc-checks.md`.

**The intake rule, because this file has now overrun twice.** It was split on
2026-09-04 at 1,156 lines, four fifths of which was history. One week later it
was back to 439 lines, of which 54 were work — seven eighths. The rule that
would have caught both: **an entry that has no next action is not a TODO.** If
it records what was measured, it is `DEVLOG.md`. If it constrains what anyone
may build next, it is `AGENTS.md`. If it names a test nobody has run, it is
`PLAN-qc-checks.md`. Keep each item to the action, why it matters, and what
done looks like — the evidence lives at the pointer, not here.

---

## Immediate

- [ ] **Delete two orphan files from the server root.** Neither is produced by
      any current build script and nothing in obus reads either, so they sit
      there looking current. Re-confirmed live 2026-09-08.

      | file | rows | why it is wrong |
      |---|---:|---|
      | `HL_standardised.parquet` | 15,483,270 | the deprecated stacked shape, carrying the abandoned `aphia` rename and a `type` column. Superseded by `HL_length` + `HL_summary`. |
      | `LT.parquet` | 79,451 | retired-era build at the *root*; `dr_con_raw("LT")` reads `raw/LT.parquet`, which is the live one. |

      ```
      ssh einarhj@heima.hafro.is 'rm ~/public_html/datras/{HL_standardised,LT}.parquet'
      ```

      `CPUEL.parquet` at the root is **not** in this list — see `AGENTS.md`.

## Later

- [ ] **Embed metadata in the derived parquet files.** Design settled
      2026-09-04 and written up in `AGENTS.md`; needs the opus-side writer
      exported first. Done looks like: every file obus publishes answers
      `parquet_kv_metadata()` with a dict for obus's own columns, a provenance
      block carrying the source archive's `dict_sha256`, and a
      machine-readable grain.

- [ ] **Raise `mid_lengths` with DATRASextra, or catch it in a CHECK script.**
      `R/weight.R:641` and `R/length.R:572` compute `cm_breaks[-1] + dls/2`,
      but with `addSpectrum()`'s `cut(..., right = FALSE)` bin *j* is
      `[cm_breaks[j], cm_breaks[j+1])`, so its midpoint is one bin lower.
      `:576` then rewrites only the last element to the lower-bound form,
      which is itself evidence the two conventions are mixed. Confirmed
      against the bin definition, not measured against data.

      This is live rather than a note: both `data-raw/CHECK_datras_*.R` run
      DATRASextra's stack unmodified and pass 11/11 and 25/25 without touching
      it, so obus's own evidence does not cover it.

- [ ] **Build a CA-derived product — an `age`/`length` table the way
      `HL_length` is for catch.** The record layer is already proven to
      travel: `dr_get_datras(ca = TRUE)` assembles CA into a `DATRASraw`, and
      an age-length key built from obus's parquet is identical to one built
      from the exchange file. `dr_add_id()` works on CA unchanged.

      Two things to carry in, both measured 2026-09-09: `rawALK()` errors
      whenever `Age` has `NA`s (its own guard propagates the NA) — it fails on
      DATRASextra's bundled `dab` too, so it is a DATRAS bug, not ours; and
      empty `Year` factor levels survive `subset()`, so years with no ageing
      trip the per-year guard until dropped.

- [ ] **Give towed distance a documented fallback before building swept
      area.** A fifth of the archive has no end position at all, and 2,780
      hauls record an end position identical to the shoot position, which
      yields a plausible-looking zero-distance tow rather than an honest `NA`.
      Both traps and the evidence are in `AGENTS.md`; the decision to make is
      what `dr_impute_spread()` does about each, and the house rule says a
      `dr_check_*` report rather than a silent repair.

- [ ] **Start the QC check suite.** `PLAN-qc-checks.md` is a proposal —
      twelve check families, pseudocode only, nothing built — and it carries
      its own start sequence in section 7, which begins with the snapshot and
      the measurable extents rather than with checks. Its section 8 holds the
      labelled hypotheses that have a stated test and no owner.
