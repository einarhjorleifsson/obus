# obus — TODO

**Status:** Rebuilt 2026-08-31 from an empty `R/`; length-weight added
2026-09-02. Thirteen exported functions, `R CMD check` clean (0/0/0), 243 tests
passing including the online schema check. **All eight tables are published**
and verified against the full archive. The DATRAS/DATRASextra interop
harnesses in `data-raw/` pass 11/11 and 25/25.

*This file tracks outstanding work only. Dated development history — what was
done, when, and why — lives in `DEVLOG.md`; settled design lives in
`AGENTS.md`. The split was made 2026-09-04, when this file had reached 1,156
lines of which four fifths was history; the convention follows opus's.*

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

## Later

- [ ] **DATRASextra's `mid_lengths` is one bin width high, and neither CHECK
      script notices.** `R/weight.R:641` and `R/length.R:572` compute
      `cm_breaks[-1] + dls/2`. With `addSpectrum()`'s `cut(..., right = FALSE)`,
      bin *j* is `[cm_breaks[j], cm_breaks[j+1])`, so its midpoint is
      `cm_breaks[j] + dls[j]/2` — one bin lower. `:576` then rewrites only the
      last element to the lower-bound form, which is itself evidence the two
      conventions are mixed. Confirmed against the bin definition, not measured
      against data.

      This is a **live loose end, not a note**: both `data-raw/CHECK_datras_*.R`
      run DATRASextra's stack unmodified and pass 11/11 and 25/25 without
      touching it, so obus's own evidence does not cover it. Either extend a
      CHECK script to catch it or raise it with DATRASextra.

- [ ] **Embed metadata in the derived parquet files** — dict for obus's own
      columns, provenance carrying the source archive's `dict_sha256`, and a
      machine-readable grain. Design decision recorded at the end of this file
      (2026-09-04); needs the opus-side writer first.

- [ ] **HH positions carry two traps that swept-area work will walk into.**
      Measured on the published archive 2026-09-02 over 150,217 hauls, while
      writing `datrasdoodle2`'s HH chapter. Nothing is wrong in obus today —
      obus computes nothing from these fields yet — but whatever builds
      `dr_impute_spread()` / towed distance needs both facts up front.

      1. **31,038 hauls (20.7%) have no haul (end) position at all** — only
         `ShootLatitude`/`ShootLongitude`. Any distance-from-positions
         calculation needs a documented fallback for a fifth of the archive.

      2. **2,780 hauls record an end position identical to the shoot
         position**, which yields a *zero-distance tow* — a plausible-looking
         number rather than an honest `NA`, which is the more dangerous of the
         two failure modes. This has historically been flagged as a Norwegian
         quirk; that undersells it badly. By country, share of hauls with an
         identical pair, against the share recorded at one-decimal precision:

         | country | hauls | identical | 1-decimal |
         |---|---:|---:|---:|
         | RU | 1,059 | **41.8%** | 11.0% |
         | EE | 306 | **40.2%** | 12.4% |
         | NO | 1,746 | 14.3% | 3.6% |
         | LV | 1,255 | 12.5% | 2.8% |
         | GB-SCT | 12,280 | 8.4% | 5.8% |
         | PL | 2,166 | 6.7% | 2.4% |

         The precision column is there to kill the innocent explanation:
         if identical pairs were a rounding artefact, the 1-decimal share
         would have to be at least as large as the identical share. It is
         three to four times *smaller* on every affected country. So these
         are fine-grained positions that have been **copied**, almost
         certainly the shoot position written into both slots — not coarse
         positions colliding with themselves.

      Recommended treatment when the time comes: an identical pair is a
      *missing* end position, not a zero-length tow. Worth a `dr_check_*`-style
      report rather than a silent repair, per the house rule.

- [ ] **`CA` is fetched by `DATASET_species.R` but nothing else uses it.**
      It contributes aphia codes to the species lookup and is otherwise
      untouched. An `age`/`length` product would be the natural next thing
      to build, and `dr_add_id()` already works on it unchanged.

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

## Open, not resolved

- [ ] **Can-Mar `SpeciesValidity = "5"` rows carry real length data**, unlike
      every other survey. ICES documents this as unresolved. Separately,
      Can-Mar's lost raising factor is 30,214 of the 73,596 real disagreements
      (41%), median gap 13 fish, 98% one-directional — a documented
      provider-side conversion, not something obus can fix.

      Original reasoning, kept for the record: ICES's row-level formula is fully derivable from `HL_length`:
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

## Metadata on the derived tables (design decision, 2026-09-04)

**Recorded, not implemented.** Raised while considering a datrasdoodle2 chapter
on how a consumer reads the archive's metadata.

### The measured asymmetry

Every raw file is self-describing; none of obus's published files are. Measured
2026-09-04 with `parquet_kv_metadata()` over the live server:

| file | `datras:dict` | `provenance` | `sentinels` | `coverage` | `known_issues` |
|---|--|--|--|--|--|
| `raw/{HH,HL,CA,LT}.parquet` | yes, 59 KB on HH | yes | yes | yes | yes |
| `{HH,HL,CA}.parquet` | — | — | — | — | — |
| `HL_length.parquet`, `HL_summary.parquet` | — | — | — | — | — |
| `species`, `length_weight`, `hl_flag` | — | — | — | — | — |

All five blocks are JSON. opus's provenance is a build receipt:

```json
{"table":"HH","n_rows":150217,"n_cols":69,"source":"ICES DATRAS ASMX web service",
 "built_utc":"2026-08-29T19:19:21Z","opus_version":"0.2.0","opus_git_sha":"00d9b7f",
 "dict_sha256":"d74c9e38…","writer":"nanoparquet 0.5.1",
 "pipeline":"archive_02_download -> … -> archive_06_consolidate"}
```

And opus reads it **out of the file**, not from the installed package —
`op_dict()`, `op_provenance()`, `op_coverage()`, `op_known_issues()`,
`op_catalog()`, `op_keys()`, `op_relationships()` and `op_definitions()` all
resolve through `.op_kv(table, "datras:dict", path)` (`opus/R/archive.R:71`).
`op_sentinels()` is the deliberate exception: no `path` argument, so it is
opus's *policy*, while a file's `datras:sentinels` records what was applied to
that file. `dict_sha256` ties the two together.

### The decision

A three-way split, chosen so that one access idiom keeps working across the
whole server directory:

1. **Format and writer belong to opus.** It owns how a DATRAS-family parquet
   describes itself. If obus invents its own key names or JSON shapes then
   `op_dict()` stops working on half the published files and a consumer needs
   two idioms for one folder. opus should export the writer, or at minimum the
   block schema.
2. **Content for the derived columns belongs to obus.** `n_haul`, `n_hour`,
   `n_measured`, `length_mm`, `length_cm`, `length_cm_mid`, `accuracy`,
   `w_haul` and `.id` are obus's own inventions. Working Principle 1 forbids
   re-deriving *DATRAS* names; it says nothing against documenting columns obus
   created, and not documenting them is the worse outcome.
3. **`dict_sha256` of the source archive is non-negotiable.** Today, given
   `HL_length.parquet`, there is no way to tell which archive build produced
   it.

**Why (3) is the load-bearing one.** This project has already been bitten by
exactly the failure it prevents: the server root held retired-era `HL.parquet`,
`CA.parquet` and `LT.parquet` carrying abandoned renames and *filtered* row
counts, and nothing noticed for weeks because `dr_con()` simply refused the
names (see "The server root still carries retired-era files no build script
owns" in `AGENTS.md`). A provenance block makes a stale file self-evident
rather than invisible.

**Grain should go in too.** Neither catch table's grain was what its
documentation claimed, and both were fixed in the docs rather than the code. A
machine-readable grain block is testable; prose in `AGENTS.md` is not.

### Implementation notes

Feasible cheaply and it preserves the streaming property — nothing needs
`collect()`ing. Verified 2026-09-04 on duckdb 1.5.5: `COPY … (FORMAT PARQUET,
KV_METADATA {key: 'value'})` is supported and round-trips through
`parquet_kv_metadata()`. `data-raw/build_helpers.R:56` is currently

```r
duckdbfs::write_dataset(x, out, options = "COMPRESSION 'zstd'")
```

**Resolved 2026-09-04 by test — no fallback needed, and only
`build_helpers.R` is affected.** `duckdbfs::write_dataset()` builds
`options_vec <- c(format_by, partition_by, allow_overwrite, options)` and
collapses it with `glue_collapse(sep = ", ")` into the `COPY` parens
(duckdbfs 0.1.2), so a multi-element `options` **vector or list** is forwarded
verbatim. Verified on a lazy `tbl_duckdb_connection` input, exactly what
`dr_write()` passes:

| case | result |
|---|---|
| single option (today's call) | ok, 0 kv blocks |
| `c("COMPRESSION 'zstd'", "KV_METADATA {test: 'hello'}")` | ok, 1 block |
| quoted key + JSON value | ok, round-trips |
| two keys in one `KV_METADATA` block | ok, 2 blocks |
| `list()` instead of `c()` | ok |

glue does **not** choke on the literal braces in `KV_METADATA {…}`, and the
table stays lazy — no `collect()`.

**One escaping trap, worth writing into the helper rather than rediscovering
at build time.** These are single-quoted SQL literals, and
`datras:known_issues` is 8 KB of English prose, so apostrophes are close to
certain. A raw apostrophe fails with `Parser Error: syntax error at or near
"s"`. Do not hand-roll `gsub("'", "''", …)`; use DBI:

```r
clause <- paste0("KV_METADATA {'datras:known_issues': ",
                 DBI::dbQuoteString(con, json), "}")
duckdbfs::write_dataset(x, out, options = c("COMPRESSION 'zstd'", clause))
```

Verified byte-identical on round-trip through `parquet_kv_metadata()` with a
payload containing `ICES's` and `don't`.
