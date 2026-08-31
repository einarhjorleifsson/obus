------------------------------------------------------------------------

# obus — DATRAS Access Layer for R

**Status:** Active rebuild (2026-08-23 onward). **Version:** 2026.08

------------------------------------------------------------------------

## What obus provides

obus gives R users two ways to get ICES DATRAS trawl-survey data, plus the
utilities that make each usable:

1. **`dr_get()`** — an eager fetch. `source = "parquet"` (default) reads
   the full, pre-built archive hosted at `heima.hafro.is`; `source =
   "xml"` fetches live, directly from ICES's own DATRAS web service, for
   survey/year/quarter combinations too recent to be in the archive yet.
2. **`dr_con()`** — a lazy DuckDB connection to the same hosted parquet
   files (plus lookup tables: `species`, `length_weight`, `swept_area`).
   Nothing downloads until `collect()`; `{dplyr}` verbs push down to SQL.

Both return the same column *names* for the same table, regardless of
source — `dr_settypes()`/`dr_translate()` (opus-backed, see Data Sources
below) apply opus's own curated Tier 1 spec to the live "xml" path.

**They do NOT currently return the same column *types*, and this file
used to claim they did.** Measured 2026-08-28 (NS-IBTS 2022 Q1, both
sources): 7 class mismatches in HL, 6 in CA, plus `.id` present only in
the parquet. The cause is not a bug in either path — opus maintains two
independent type systems (WSDL physical types, which the archive is
built from; curated semantic types, which `op_field_spec()` reports and
`dr_settypes()` applies), and nothing reconciles them. The earlier
wording here also had the direction backwards: `dr_settypes()` makes the
xml path match *opus*, not "the archive's own conventions." Tracked in
`TODO.md`; the reconciliation decision belongs to opus.

obus does NOT maintain its own field-name/type knowledge. It sources both
from the sibling `opus` package's curated DATRAS specs. See Data Sources.

------------------------------------------------------------------------

## What the project does

obus is the **R access layer** for ICES DATRAS data — the "with the spec"
half of a two-package split (see `opus`'s own `AGENTS.md`, whose Decision
Gate names this exact boundary: "*with* the spec → belongs in obus/imbus").
opus owns *what a DATRAS field is called and what type it is*; obus owns
*getting the data into R, consistently, regardless of how fresh it needs
to be*, plus whatever domain logic (derived products, joins, unit
conversions) gets built on top.

obus's own practical driver is **`datrasdoodle2`** (a sibling project) —
the near-term measure of obus doing its job well is whether it makes that
tool enjoyable to build and use, not abstract API completeness. When a
design choice is unclear, prefer what that consumer actually needs over
speculative generality.

1. **One consistent shape, two speeds — an aim, not yet a fact.** The
   parquet archive is fast but can lag; the live XML path is slow but
   current. Same rename pipeline, so column *names* agree; column
   *types* currently do not (see above and `TODO.md`). Downstream code
   does still have to care which source it got until that's resolved.
2. **Delegates spec knowledge, keeps fetch/domain logic.** Field names and
   types come from `opus`; obus's own layer is limited to fetching,
   deriving, and joining.
3. **Never invents a fact opus or ICES already owns.** obus's own naming
   layer (`aphia`, `sex`, `age`) is deliberately small and explicit,
   because everything else is opus's or ICES's to define.

------------------------------------------------------------------------

## Working Principles

**1. Types and names come from opus — never from `icesDatras`, never
guessed.** obus has zero dependency on the `icesDatras` R package (removed
2026-08-28 — see Key Facts). `dr_settypes()` and the translate step in
`dr_get()` read `opus::op_field_spec()` for every Tier 1 field's current
name, legacy name, and type. If opus doesn't know a field, obus doesn't
either — it stays whatever raw type the fetch produced, not a guess.

**2. Sentinel values are never scrubbed automatically — this is
non-negotiable, not a style choice.** `-9` (and other DATRAS sentinel
codes) pass through `dr_get()`/`dr_settypes()` completely unchanged in
value, only re-typed. opus's own development history
(`opus/articles/technical-notes.qmd` §4) documents a real incident where a
blanket sentinel-to-NA scrub silently destroyed a majority-real column
(`HH.Tickler`: 78% of rows carry a real, documented code, not a missing
value) before anyone could catch it — once scrubbed, the evidence needed
to notice is gone. Converting a sentinel to `NA` is a per-field,
evidence-based decision (opus's own `sentinels:` registry,
`DATRAS-known-issues.yaml`), never a blanket rule — and not yet
implemented here at all (see TODO.md).

**3. Two independently-maintained naming authorities can, and do,
disagree — verify, don't assume.** `icesDatras`'s own `new_names = TRUE`
convention and opus's own curated current names are two separate schemes
that happen to agree most of the time. They don't always: CA's age field
is `IndividualAge` under one, `Age` under the other — confirmed by direct
inspection during the 2026-08-28 `icesDatras` removal, not assumed from
either source's own documentation. Any new rename/type assumption gets
checked against opus's real, installed output before it's trusted, the
same way.

**4. Scope discipline: fully support a table, or don't expose it at
all.** obus supports exactly the DATRAS tables opus has curated (Tier 1:
HH, HL, CA, LT) — Tier 2 (FL, CPUEL, CPUEA, IDX) is removed from
`dr_get()`/`dr_con()` entirely rather than left reachable in a
permanently-untyped, permanently-untranslated state. Reintroduce a table
when opus curates it, not before.

**5. obus's own naming conventions are a thin, explicit, final layer —
never conflated with opus's or ICES's own names.** `aphia`/`sex`/`age`
(`.dr_obus_rename` in `R/dr_get.R`) are obus's own invented names, applied
*after* opus's own rename and `dr_settypes()`, not part of either. opus's
own `AGENTS.md`/`TODO.md` call this pattern "Tier 3: obus contracts" and
have deliberately deferred building it themselves — this table is a
candidate seed for that, not a permanent fixture of obus.

**6. Verify empirically, against live/real data, before trusting a naming
or typing claim.** A parquet-vs-xml class-consistency check (any
survey/year/quarter, both sources, `sapply(x, class)`) is the standard way
to catch a wrong assumption before it ships — this is how the
`Month`/`Tickler` type-override gap was caught 2026-08-28, not by reading
a spec, and how the larger WSDL-vs-curated type divergence was found the
same day. Both were invisible to anyone reading only the specs; run the
check rather than reasoning about what the spec implies.

------------------------------------------------------------------------

## Task

Give R users one consistent, reasonably fast way to get real DATRAS data,
correctly named and typed, whether from the archive or live from ICES —
and build the domain-specific tooling (joins, derived quantities, unit
conversions) on top that a generic client shouldn't have to know about, in
service of making `datrasdoodle2` (and anything else built on obus)
straightforward to write.

**obus does NOT:**
- Decide what a DATRAS field is called or what type it is — that's opus's
  job (Working Principle 1).
- Maintain its own copy of ICES's field/type metadata, or fetch it via the
  `icesDatras` R package.
- Silently reinterpret sentinel values as missing (Working Principle 2).
- Expose a table opus hasn't curated (Working Principle 4).

### Decision Gate: New Work

Before adding to obus, ask:
1. Is this about *what a field is called or typed*? → That's opus's job;
   propose it there, or add an obus-side override only with a documented,
   verified reason (see the `.dr_obus_rename`/`dr_settypes()` override
   lists for the pattern).
2. Is this about *getting data into R* (fetch, connect, cache) or *doing
   something with it* (derive, join, convert)? → Both belong in obus; keep
   fetch/connect logic and domain logic in separate functions regardless.
3. Does it touch sentinel interpretation? → Needs real evidence (opus's
   `sentinels:` registry, or a fresh check against real data), never a
   blanket rule (Working Principle 2).
4. If uncertain: flag for explicit decision before proceeding.

------------------------------------------------------------------------

## Scope

**Tier 1 (supported): HH, HL, CA, LT.** Full `dr_get()`/`dr_con()` support;
types and ICES-legacy-name translation sourced from `opus::op_field_spec()`.

**Tier 2 (not supported, by design): FL, CPUEL, CPUEA, IDX.** Removed
entirely from `dr_get()`/`dr_con()` 2026-08-28 — opus's own `TODO.md`
tracks its own Tier 2 curation as not-yet-started. Reintroduce once that
lands, following the same opus-backed pattern as Tier 1, not before.

**Not ICES record types at all, unaffected by any of the above:**
- `"submission_status"` (`dr_get()` only) — a live ICES SOAP endpoint, no
  parquet archive, no opus involvement.
- `"species"`, `"length_weight"`, `"swept_area"` (`dr_con()` only) —
  obus's own lookup tables.
- `"HL_standardised"` — obus's own former derived product; removed
  alongside Tier 2 for the same reason (2026-08-28). Revisit once there's
  a concrete need.

**obus-derived products (planned, not yet resurrected in this rebuild —
see TODO.md):** `dr_get_metadata()`, `dr_add_length_cm()`,
`dr_add_n_and_cpue()`, `dr_HL_standardised()`, `dr_catch_weight_by_haul()`,
`.id` composite-key construction, `dr_lookup_species`/
`dr_lookup_length_weight`. All referenced in `README.Rmd`/roxygen
cross-links as the intended shape of the package; none exist in `R/` yet.

------------------------------------------------------------------------

## Data Sources

obus draws on three sources, none of them independently maintained by obus
itself:

1. **`opus`** (github.com/einarhjorleifsson/opus, installed from source —
   see `Remotes:` in `DESCRIPTION`) — the sole authority for Tier 1 field
   names (ICES legacy ↔ opus current) and types, via
   `opus::op_field_spec(table_name)`. obus reads opus's shipped YAMLs
   through this one function and never parses them itself.
2. **ICES's DATRAS ASMX web service, called directly**
   (`source = "xml"` in `dr_get()`, via `.dr_fetch_datras_xml()` in
   `R/dr_get.R`) — no `icesDatras` R-package dependency (removed
   2026-08-28). The same direct pattern opus itself uses for its own live
   lookups (`opus/AGENTS.md`: "No R-package dependency on either
   `icesDatras` or `icesVocab`").
3. **The hosted parquet archive**
   (`https://heima.hafro.is/~einarhj/datras/`) — `dr_get(source =
   "parquet")` (default) and `dr_con()`'s target. Pre-built, already typed
   and renamed. obus doesn't build this archive; note the matching
   `_legacy.parquet` naming convention shared with opus's own
   `archive_06_split_legacy_new.R` output (`opus/AGENTS.md`'s
   Implementation section) — closely related to, quite possibly the same
   pipeline as, opus's own archive-building scripts, though not confirmed
   1:1 from obus's side.

------------------------------------------------------------------------

## Implementation

**Exported functions** (`R/`):
- `dr_get(recordtype, surveys, years, quarters, source, quiet)` — eager
  fetch, parquet or live XML (`R/dr_get.R`)
- `dr_con(type, path, quiet)` — lazy DuckDB connection to a hosted or
  local parquet file (`R/dr_con.R`)
- `dr_settypes(d, name_col, recordheader)` — cast columns to opus's
  declared types (`R/dr_settypes.R`)
- `dr_translate(d, dictionary, from, to)` — generic rename-by-dictionary
  utility, opus-agnostic (`R/dr_translate.R`)

**Internal helpers** (`R/dr_get.R`, not exported):
- `.dr_fetch_datras_xml(operation, query)` — raw ICES ASMX GET → flat
  character data frame, no renaming/typing/sentinel handling
- `.dr_fetch_xml()` / `.dr_fetch_lt()` / `.dr_fetch_submission_status()` /
  `.dr_fetch_parquet()` — one per record type/source
- `.dr_obus_rename` — the small aphia/sex/age table (Working Principle 5)
- `.dr_default_surveys()` — live survey list, test surveys excluded

**`NAMESPACE` is roxygen2-generated** — every `@export`-tagged function is
live automatically via `roxygen2::roxygenise()`; never hand-edit it.

**This is a from-scratch rebuild, started 2026-08-23, aiming at the same
scope as `obus_retired`, done better and more spartan.** The goal isn't a
narrower product than the retired package attempted (fetch, connect,
derived products, joins, unit conversions — see Scope's "obus-derived
products" list, all real ambitions carried forward) — it's the same
functional ground covered with fewer unverified assumptions and less
speculative surface area. Concretely: verify against real data before
building on a claim (Working Principle 6), and don't add a function,
parameter, or abstraction before something real needs it (no half-built
Tier 2 support, no premature generality in `.dr_obus_rename`). "Spartan"
describes the implementation discipline, not a smaller destination.

The prior obus package itself is archived, intact, at `../obus_retired` —
kept as a local reference, not on GitHub, specifically because several of
its own documented "facts" turned out to be wrong, stale, or never
independently verified, and later work kept building on top of them
before they'd settled. Treat anything found there as a reference to
re-verify against this package's current code and against real
ICES/opus data — a source of what to rebuild and why, never of settled
fact on its own.

------------------------------------------------------------------------

## Key Facts

**Zero `icesDatras` dependency, by design (2026-08-28).** Every live fetch
goes straight to ICES's own ASMX endpoints
(`https://datras.ices.dk/WebServices/DATRASWebService.asmx/...`) via
`httr2`/`xml2`. Confirmed live network access and response shape by
reading `icesDatras`'s own installed source directly (`getDATRAS()`,
`getLTassessment()`, `getSurveyList()`) rather than assuming; ICES pads
several fixed-width fields (e.g. `Platform`, `Gear`) with trailing spaces
on the wire, trimmed in `.dr_fetch_datras_xml()` the same way
`icesDatras`'s own parser always did.

**The `Age`/`IndividualAge` divergence, and why every rename needs
checking, not assuming.** `icesDatras`'s `new_names = TRUE` calls CA's age
field `IndividualAge`; opus's own current name for the same field is
plainly `Age`. The retired obus package's own rename table used
`IndividualAge`, inherited from `icesDatras`'s convention — silently wrong
once `icesDatras` is out of the picture. Caught by direct inspection of
`opus::op_field_spec("CA")`'s real output, not by reading either
project's docs. `.dr_obus_rename`'s `"CA", "Age", "age"` row carries an
inline comment recording this specifically so it doesn't regress.

**The `Quarter`/`Month`/`Tickler`/`SpeciesCategory` type override.** opus
curates these four fields as `type: "enum"` (a labelled code, for
validation purposes) but each is genuinely integer on the wire and in
obus's own parquet archive — opus's own YAML documents this exact,
by-name "M01" divergence. `dr_settypes()` hardcodes the override rather
than inferring it, and says so in a comment; found via the parquet-vs-xml
class-consistency check (Working Principle 6), not anticipated in advance.

**`README.Rmd` describes the target shape of the package, not its current
state.** It documents `dr_get_metadata()`, `dr_add_length_cm()`,
`dr_add_n_and_cpue()`, FL support, and `icesDatras::getDATRAS` as the xml
engine — none of which match this rebuild as of 2026-08-28 (FL is removed
entirely; the xml engine no longer touches `icesDatras`). Needs a rewrite
once the package catches up to it, or vice versa — tracked in `TODO.md`,
not done as part of this pass.
