# obus — TODO

**Status (2026-09-17):** Sixteen exported functions, `R CMD check` clean
(0/0/0), 387 tests passing including the online schema check. **All ten tables
are published** and verified live against the code's schema (re-checked
2026-09-08). The DATRAS/DATRASextra interop harnesses in `data-raw/` pass
11/11 and 25/25 — the adapter they test is now `dr_get_datras()` itself, not a
script-local copy. What was built when is in `DEVLOG.md`.

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

## Later

- [ ] **Embed metadata in the derived parquet files.** Design settled
      2026-09-04 and written up in `AGENTS.md`; needs the opus-side writer
      exported first. Done looks like: every file obus publishes answers
      `parquet_kv_metadata()` with a dict for obus's own columns, a provenance
      block carrying the source archive's `dict_sha256`, and a
      machine-readable grain.

- [ ] **Raise `mid_lengths` with DATRASextra, or catch it in a CHECK script.**
      All three sites are in **`DATRASextra/R/weight.R`** — `:572` in
      `.get_wgt_one_custom()`, `:641` in `.get_wgt_one_lookup()`, `:688` in
      `.get_wgt_one_ca()` — and each computes `cm_breaks[-1] + dls/2`. But
      with `addSpectrum()`'s `cut(..., right = FALSE)` bin *j* is
      `[cm_breaks[j], cm_breaks[j+1])`, so that expression is the upper bound
      plus half a bin width: the midpoint of the bin *above*. Confirmed
      against the bin definition, not measured against data.

      **The correct form is already in the file, applied to one bin.** At
      `:576` and `:692` the plus-group branch rewrites the last element as
      `cm_breaks[nl-1] + dls[nml-1]/2` — the lower-bound form — so the two
      conventions are mixed inside single functions rather than merely across
      them. `.get_wgt_one_lookup()` has no such branch at all, which is worth
      naming separately in any report.

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

- [ ] **Swept area: decide the method, then ship a thin wrapper.** Parked
      2026-09-11 pending a science call. Two methods — ICES WKSAE-DATRAS
      sr.2021.10 and FishGlob — disagree by construction, so obus cannot pick
      one on engineering grounds. Excluding beam trawls (for which the spread
      *is* the beam width), they cover 62.3% and 79.5% of the 106,154 hauls
      needing a spread model; 17.0% get neither. **That choice is the only
      blocker**; the design and the measurements behind it are settled in
      `DEVLOG.md` (2026-09-11) and `AGENTS.md`.

      Done looks like: the WKSAE rule table served alongside `hl_flag_code`
      and `length_type_conversion` — publish the *rules*, compute the
      *values*, because a per-haul table goes stale on every archive refresh —
      plus `dr_add_swept_area(hh, method = )` wrapping DATRASextra rather than
      reimplementing it, and a `dr_check_*` for the coverage neither method
      reports.

- [ ] **Re-key `length_type_conversion` — it currently fires on ONE record.**
      Measured 2026-09-11. Both rows are keyed `from_type = 4`, and exactly
      one record in the 14,001,605-row archive is ever converted, because
      `LengthType` is `NA` on 70.74% of `HL_length` and `dr_add_length_tl()`
      reads `NA` as Total Length. The table is structurally inert, and adding
      rows without re-keying changes nothing. FishGlob keys its equivalent on
      **taxon alone** — a claim about how a species is measured in practice
      rather than about what a submitter typed — which is why theirs applies.

      It matters because obus does not decline to predict for the affected
      taxa; it predicts from the wrong length, by 19x to 118x. Full figures
      and the candidate source (21 taxa cited to Mindel et al. 2016, to be
      verified against the paper before adoption) are in `DEVLOG.md`
      (2026-09-11).

      Done looks like: the lookup re-keyed on taxon, the assume-TL default
      made explicit rather than silent, and a stated position on Standard
      Length, for which no conversion exists at all.

- [ ] **Start the QC check suite.** `PLAN-qc-checks.md` is a proposal —
      twelve check families, pseudocode only, nothing built — and it carries
      its own start sequence in section 7, which begins with the snapshot and
      the measurable extents rather than with checks. Its section 8 holds the
      labelled hypotheses that have a stated test and no owner.
