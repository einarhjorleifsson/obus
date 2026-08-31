# obus — TODO

**Status:** Tier 1 (HH, HL, CA, LT) works end-to-end via `dr_get()`/
`dr_con()`, opus-backed, zero `icesDatras` dependency. Rebuild started
2026-08-23, aiming at the same functional scope as `obus_retired` (see
`AGENTS.md`) — this file tracks what's re-verified and rebuilt so far vs.
what's still only a documented ambition.

**Priority: make what already exists correct.** The four exported
functions and the obus↔opus coupling come first. Derived products and
anything downstream wait until the current surface is verified — a small
correct package beats a larger one resting on unchecked assumptions
(`AGENTS.md` Working Principle 6).

**Latest:** 2026-08-28 — resurrected `dr_settypes()`/`dr_translate()` on
opus specs, dropped `icesDatras` entirely, dropped Tier 2 (FL, CPUEL,
CPUEA, IDX) + `HL_standardised` support. Later the same day: `tibble`
dropped from package code, `R CMD check` brought to a clean 0/0/0, and a
correctness pass over the existing four functions started (below),
which found a real parquet-vs-xml type divergence.

---

## Done

- [x] `dr_get()` — HH/HL/CA/LT via parquet or live ICES XML;
      `submission_status` via live SOAP
- [x] `dr_con()` — lazy DuckDB connection, HH/HL/CA/LT + species/
      length_weight/swept_area
- [x] `dr_settypes()`/`dr_translate()` resurrected, sourced from
      `opus::op_field_spec()` (new opus export, added alongside this)
- [x] Zero `icesDatras` R-package dependency (direct ICES ASMX calls via
      httr2/xml2, mirroring opus's own pattern)
- [x] Tier 2 (FL, CPUEL, CPUEA, IDX) and `HL_standardised` removed from
      `dr_get()`/`dr_con()` — not silently left half-supported
- [x] `tibble` dropped from package code (2026-08-28) —
      `.dr_obus_rename` was the package's one `tibble::` call; now a
      base `as.data.frame(matrix(..., byrow = TRUE))`, verified
      `identical()` to the old `tribble()` output. `tibble` stays a
      `Suggests` because `README.Rmd` still calls it.
- [x] **`R CMD check` clean: 0 errors, 0 warnings, 0 notes**
      (2026-08-28). Needed `AGENTS.md`/`TODO.md` in `.Rbuildignore`.
- [x] **Verified: the parquet archive already carries obus's Tier-3
      names** (2026-08-28). `HL.parquet` has `aphia`/`sex`, not
      `Valid_Aphia`/`SpeciesSex` — so `.dr_fetch_parquet()` is *correct*
      to skip `.dr_obus_rename`, and `AGENTS.md`'s "same names from
      either source" claim holds for HL. Checked directly against the
      live archive, not assumed. (But see the drift risk below.)

## Immediate: correctness of the current surface

- [ ] **BUG — `dr_get()` returns 0 rows silently when ICES is
      unreachable.** Confirmed 2026-08-28 by tracing the path, not
      suspected: with the default `surveys = NULL`, `dr_get()` calls
      `.dr_default_surveys()`, which calls `.dr_fetch_datras_xml()`,
      which swallows *any* request error and returns `data.frame()`.
      Then `data.frame()$Survey` is `NULL`, the `^Test` filter leaves it
      `NULL`, and `dplyr::filter(Survey %in% NULL, ...)` matches nothing
      — so the caller gets an empty result with **no error and no
      warning**, indistinguishable from "no data for that query."
      Two things to fix, arguably separately:
        1. `.dr_default_surveys()` should fail loudly when the survey
           list comes back empty (opus's own
           `.fetch_live_datras_field_list()` sets the precedent: it
           `stop()`s on a short response rather than returning a partial
           one).
        2. `source = "parquet"` shouldn't need a live ICES call at all.
           The archive holds every survey; defaulting to "all surveys"
           is a no-op filter, so the default path currently makes
           `dr_get("HH")` depend on ICES being up for no benefit.
- [ ] **BUG — parquet and xml do NOT return the same types, and
      `AGENTS.md` claims they do.** Ran Working Principle 6's own
      prescribed check on 2026-08-28 (NS-IBTS 2022 Q1, both sources,
      `sapply(x, class)`). Row counts match exactly; **types do not** —
      7 mismatched columns in HL, 6 in CA:

      | field | xml | parquet | opus says |
      |---|---|---|---|
      | `SweepLength` | numeric | integer | `number(quantity)` |
      | `LengthClass` | numeric | integer | `number(quantity)` |
      | `SubsampledNumber` (HL) | numeric | integer | `number(quantity)` |
      | `SubsampleWeight` (HL) | numeric | integer | `number(quantity)` |
      | `SpeciesCategoryWeight` (HL) | numeric | integer | `number(quantity)` |
      | `NumberAtLength` (CA) | numeric | integer | `number(quantity)` |
      | `age` (CA) | numeric | integer | `number(quantity)` |
      | `Year` | integer | numeric | `number(ordinal)` |
      | `DateofCalculation` | integer | **Date** | `number(ordinal)` |

      **Root cause: opus maintains two parallel type systems that have
      never been reconciled, and obus is where they collide.** Neither
      side is simply "wrong" — they answer different questions:

      - The **archive** is typed from ICES's **WSDL physical types**
        (string/int/decimal). opus's own
        `data-raw/archive_00_wsdl_types.R` says so explicitly, and by
        design: "The curated spec (`inst/DATRAS-data-dict.yaml`) plays
        no role here and is never loaded by this file or its callers."
      - The **xml path** is typed from opus's **curated semantic
        types** (`number(quantity)`, `number(ordinal)`, `enum`) via
        `op_field_spec()` → `dr_settypes()`.

      Traced to the physical parquet schema 2026-08-28, which explains
      every row of the table above:
        - `SweepLength`/`LengthClass`/`SubsampleWeight`/etc. are
          **INT32** → R integer, faithfully WSDL `int`. obus casts them
          numeric because opus's YAML calls them `number(quantity)`.
        - `Year` is **INT64** → R numeric, because R has no native
          64-bit integer. Not a typing decision at all, a
          representation artifact.
        - `DateofCalculation` is INT32 carrying a parquet **DATE**
          logical type → R `Date`. Here the archive made a real
          semantic choice that WSDL's bare `int` doesn't express — and
          opus's YAML separately calls it `number(ordinal)`. (The WSDL
          reports plain `int` for all five of these fields, so WSDL
          alone doesn't explain `Year` or `DateofCalculation` either.)

      So `dr_settypes()` is doing exactly what opus's spec tells it to;
      the archive is doing exactly what the WSDL tells it to; and
      nothing reconciles the two. The M01-style override list is *not*
      the fix — these aren't enum-really-int fields, and forcing
      agreement there would just hide the seam.

      **The decision obus needs from opus:** which type system is the
      public contract? Until that's answered, obus can't honestly
      promise source-independent types. Raised in `opus/TODO.md`.

      `DateofCalculation` is the sharpest case and worth settling
      separately: a date stored as a real parquet DATE in the archive,
      typed `number(ordinal)` in the YAML. opus's own
      `op_datras_field_list()` docs already record it as a field ICES
      documents under no name at all (discrepancies #5 and #6).

- [ ] **`.id` is in the parquet archive but not in the xml output.**
      HL is 30 columns from parquet vs 29 from xml; CA is 35 vs 34. The
      extra column is `.id` in both cases — so the 8-field composite key
      listed under "Later" below is *already built* in the archive, and
      the xml path just doesn't construct it. Either build it for xml
      too or document that `.id` is parquet-only; right now the two
      sources silently differ in shape.

- [ ] Extend the same check to LT and to more survey/year/quarter
      combinations — the above is two tables on one survey/quarter, and
      it already found this much.
- [ ] **`.dr_obus_rename` is duplicated knowledge — decide where it
      lives.** The parquet archive is built with `aphia`/`sex` already
      applied, and obus re-derives the same mapping in R for the xml
      path. Two copies of one rule that must agree, with nothing
      checking that they do; if the archive build changes, the xml path
      diverges silently and the check above is the only thing that would
      notice. Either drive both from one source or add an assertion.
- [ ] **Verify `dr_settypes()` actually works on a `tbl_lazy`.** Its
      roxygen documents `d` as "A data frame or `tbl_lazy`", but it
      applies `dplyr::across(dplyr::where(is.character), ...)`, and
      `where()`-style tidyselect on a DuckDB-backed lazy tbl is not
      obviously supported. Currently untested either way — either
      confirm it or narrow the documented contract.
- [ ] **`dr_translate()` silently takes the first match.** It resolves
      renames with `match()`, so a dictionary containing one `from`
      mapped to two different `to` values uses whichever comes first,
      with no warning. Harmless if opus's crosswalk is guaranteed 1:1 —
      but that guarantee isn't asserted anywhere on the obus side.
      Either assert it or document the behaviour.
- [ ] Widen the `dr_settypes()` M01-style override list (`Quarter`,
      `Month`, `Tickler`, `SpeciesCategory`) only if a check turns up
      genuinely enum-really-int fields. Note the 2026-08-28 divergence
      above is *not* of that kind — don't reach for the override list to
      make those columns agree, that would encode the archive's error
      into obus.

## Immediate: obus↔opus coupling

- [ ] **Possible truncated submission in the archive — NS-IBTS 2022 Q1
      HL is exactly 32767 rows (2^15 - 1).** Both the live xml fetch and
      the parquet archive return that identical figure, while every
      neighbouring quarter of the same survey runs 44k-52k
      (2021 Q1: 51151; 2023 Q1: 45752). Scanned the whole HL archive:
      it is the **only** one of 971 survey/year/quarter groups sitting
      on that value, and 115 groups exceed it (max 54712) — so there is
      no global cap, which makes a signed-16-bit truncation specific to
      that submission the most likely reading, though not proven. Worth
      one targeted check against ICES, and a good candidate for opus's
      known-issues registry rather than anything obus should work
      around. Not an obus code bug either way.


- [ ] **Sentinel-to-`NA` conversion** is blocked on an opus-side export
      that doesn't exist. opus *ships* `inst/DATRAS-known-issues.yaml`
      (with `sentinels:` keys) but has **no R function that reads it** —
      confirmed 2026-08-28 by grepping all of `opus/R/`, zero hits. So
      this needs an accessor in opus first, the way `op_field_spec()`
      was added for the data dict, because `AGENTS.md`'s Data Sources
      rule says obus "reads opus's shipped YAMLs through this one
      function and never parses them itself." Propose it in opus rather
      than parsing the YAML here. Until then, raw `-9`/`"-9"` values
      pass through `dr_get()` unchanged, which is the deliberate and
      documented behaviour (Working Principle 2), not an accident.

## Housekeeping

- [ ] **Update `README.Rmd`** to match the current package: drop the FL
      example, drop the `icesDatras::getDATRAS` framing for the xml
      source, and either implement or remove the
      `dr_get_metadata()`/`dr_add_length_cm()`/`dr_add_n_and_cpue()`/
      `.id`/`dr_con("species")` join example it currently shows as
      working.
- [ ] **Test infrastructure**: still no testthat suite, though
      `Suggests` and `Config/testthat/edition: 3` are already in place
      for one. The Immediate items above are the natural first tests.
      (The former "confirm `dbplyr` is actually needed" half of this
      item is resolved: `dbplyr` is in neither `Imports` nor `Suggests`,
      and the clean check raises no unused-Imports NOTE. The NOTE that
      prompted it came from a stale check log predating the source.)

## Later: obus-derived products

Not the current priority — these wait until the surface above is
verified. Carried over from `obus_retired`'s own scope (see `AGENTS.md`'s
"same scope, done better and more spartan"); `README.Rmd` and existing
roxygen cross-links already describe some as part of the package, but
none exist in `R/` yet:

- [ ] `dr_get_metadata()` — read obus-embedded parquet metadata
- [ ] `.id` composite-key construction (Survey/Year/Quarter/Country/
      Platform/Gear/StationName/HaulNumber — the 8-field composite join
      key opus's own data-dict documents for HH/HL/CA/LT)
- [ ] `dr_lookup_species` / `dr_lookup_length_weight` — lookup tables
      backing `dr_con("species")`/`dr_con("length_weight")`
- [ ] `dr_add_length_cm()`, `dr_add_n_and_cpue()` — derived-quantity
      helpers
- [ ] `dr_HL_standardised()`, `dr_catch_weight_by_haul()` — the two
      functions `HL_standardised`'s docs (now removed) and CW's removal
      note already point to. Note `obus_retired` also had a *separate*
      `dr_catch_by_haul()` (`R/dr_products.R:94` vs `:150`); settle
      which of the two obus wants before building either.

## Later: Tier 2 (FL, CPUEL, CPUEA, IDX)

- [ ] Blocked on opus's own Tier 2 curation (`opus/TODO.md`: "Assess WSDL
      coverage... Decide: seed from WSDL or hand-author"). Once that
      lands, follow the same `op_field_spec()`-backed pattern already
      used for Tier 1 — no new obus-side design needed, just re-add the
      record types and fetch helpers.

## Future: Tier 3 (obus's own naming contracts)

- [ ] `.dr_obus_rename` (aphia/sex/age) is a candidate seed for opus's
      own planned "Tier 3: obus contracts" (`opus/TODO.md`) if/when that
      work starts there — coordinate rather than duplicate if it does.
      See the duplication item above: the archive-build pipeline is
      already a second copy of this same mapping.

## Guiding constraint: `datrasdoodle2`

obus's practical driver is making `datrasdoodle2` (a sibling project)
enjoyable to build and use. Treat it as a *vision* of where obus is
headed, not a specification or a recipe — 14 of its 21 chapters are
outline stubs, and its function names are sketches of intent, several
written against `obus_retired`, whose facts `AGENTS.md` says to
re-verify rather than inherit. It's useful for weighting the "Later"
lists once the current surface is correct; it isn't a reason to start
building them now.
