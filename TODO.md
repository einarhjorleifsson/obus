# obus — TODO

Outstanding work only. Settled design is in `AGENTS.md`; dated history and
measurements are in `DEVLOG.md`; stated-but-untested hypotheses are in
`PLAN-qc-checks.md`.

**The intake rule: an entry with no next action is not a TODO.** If it records
what was measured, it goes in `DEVLOG.md`. If it constrains what anyone may build
next, it goes in `AGENTS.md`. If it names a test nobody has run, it goes in
`PLAN-qc-checks.md`. Keep each item to the action, why it matters, and what done
looks like; the evidence lives at the pointer.

---

## Next

- [ ] **Re-render datrasdoodle2 on the fixed `dr_add_catch()`.** It no longer
      double-counts a total repeated across `SpeciesValidity` records, the
      weights included (`DEVLOG.md`, 2026-10-06); the book was rendered on the
      version that did. The change is per haul, concentrated in BTS, Can-Mar,
      NL-BSAS and DYFS. Done looks like: obus reinstalled, the book re-rendered,
      and every number it quotes from `dr_add_catch()` or a `dr_summarise_*()`
      verb re-checked.

- [ ] **Decide what `dr_add_catch()` offers beside the routes it carries.** It
      already has the reported total (`n_totalnumber`, `n_totalnumber_hour`) and
      the length-derived `n_haul`. Candidates: a length-route rate per hour,
      which is just `n_haul / HaulDuration * 60`; `n_measured`; and a has-lengths
      indicator next to `present`, readable straight from `SpeciesValidity` 4-7.
      Why: a downstream user does not know the two routes exist or which one they
      expect. Done looks like: the decision in `AGENTS.md` and, if built,
      datrasdoodle2's `before-the-model` and the stage comparison in
      `standardising-catch` using verbs with their figures unchanged.

- [ ] **Diagnose the fish haul-species pairs where the two routes differ by more
      than rounding and are neither total-only nor duplicated.** A couple of
      percent of fish pairs are unexplained (`DEVLOG.md`, the two-routes entry);
      several BITS plaice cases are `DataType` C. `hl_flag` already codes every
      pair, so start from its `unexplained` kind (`CNT_DIRECTIONAL`,
      `CNT_LEN_HIGH`, `CNT_SF_UNRECONCILED`, `CNT_OTHER`) restricted to fish.
      Done looks like: every such pair classified, the residue named or shown to
      be empty, and any new pattern a code in `hl_flag_code.csv`.

- [ ] **Check that `hl_flag` catches every length distribution submitted
      twice.** `CNT_LEN_DUP` covers it and fires on the documented BITS plaice
      haul, but its duplicate key includes `SpeciesCategory`, so a distribution
      resubmitted under a second category code passes unflagged. Done looks
      like: every pair whose length route is about twice the totals route
      (`DEVLOG.md`, the two-routes entry) carries `CNT_LEN_DUP`, or the ones
      that do not have a code and a test.

- [ ] **Decide which of osmx's plots to port, if any**: a station bubble map that
      draws zero hauls distinctly; a bootstrap interval for CPUE (the verb uses a
      normal approximation, which suits skewed catch poorly); last-N-stations
      monitoring plots; length-weight QC plots. Done looks like: each added as a
      verb or an `autoplot()` branch, or dropped with a reason.

- [ ] **Give `_pkgdown.yml` a `url`.** `pkgdown::check_pkgdown()` stops at "url is
      missing". Needs the published address from the user.

---

## Later

- [ ] **Embed metadata in the derived parquet files.** The design is in
      `AGENTS.md`; it needs the opus-side writer exported first. Done looks like:
      every file obus publishes answers `parquet_kv_metadata()` with a dictionary
      for obus's own columns, a provenance block carrying the source archive's
      `dict_sha256`, and a machine-readable grain.

- [ ] **Raise DATRASextra's weight midpoints, or catch them in a CHECK script.**
      `DATRASextra/R/weight.R` computes `cm_breaks[-1] + dls/2` in
      `.get_wgt_one_custom()`, `.get_wgt_one_lookup()` and `.get_wgt_one_ca()`.
      With `addSpectrum()`'s `cut(..., right = FALSE)` that is the midpoint of the
      class *above*. The plus-group branches in the first and last use the
      lower-bound form, so the two conventions are mixed inside single functions;
      `.get_wgt_one_lookup()` has no such branch. obus's CHECK harnesses run that
      code unmodified, so they do not cover it. Done looks like: an issue raised
      upstream, or a CHECK that fails on it.

- [ ] **Build a CA-derived product**, an age/length table the way `HL_length` is
      for catch. `dr_get_datras(ca = TRUE)` already assembles CA, and an
      age-length key built from obus's tables matches one built from the
      exchange file. Carry in two {DATRAS} traps: `rawALK()` errors whenever
      `Age` has `NA`s, and empty `Year` factor levels survive `subset()`. Done
      looks like: a published table with its grain in `PUBLISHED_GRAIN`.

- [ ] **Swept area: decide the method, then ship a thin wrapper.** ICES's
      WKSAE-DATRAS method and FishGlob's disagree by construction, so obus cannot
      choose on engineering grounds; that science call is the only blocker (the
      design and measurements are in `DEVLOG.md`). Done looks like: the WKSAE rule
      table served beside `hl_flag_code` (publish the rules, compute the values),
      a `dr_add_swept_area(data, method = )` wrapping DATRASextra rather than
      reimplementing it, and a coverage report for the hauls neither method
      reaches.

- [ ] **Re-key `length_type_conversion` on taxon.** Its rows are keyed on a
      submitted `LengthType` that is mostly missing, and `dr_add_length_tl()`
      reads a missing type as total length, so the table almost never fires and
      obus predicts from the wrong length for the affected taxa instead of
      declining. FishGlob keys its equivalent on taxon alone. Done looks like:
      the lookup keyed on taxon (candidate source in `DEVLOG.md`, to be checked
      against the paper), the assume-total-length default made explicit, and a
      stated position on standard length, for which no conversion exists.

- [ ] **Start the QC check suite.** `PLAN-qc-checks.md` is a proposal, nothing
      built, and its section 7 sets the start: the snapshot and the measurable
      extents before any check. Its section 8 holds the hypotheses with a test
      and no owner.
