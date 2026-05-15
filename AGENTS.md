# obus Package — Agent Memory

**Package:** obus  
**Location:** `/Users/einarhj/R/Pakkar/obus`  
**Purpose:** Fast, tidy access to ICES DATRAS (trawl survey) data.
Eliminates local data maintenance; provides consistent column types,
standardized units, and unique haul identifiers.

------------------------------------------------------------------------

## Loading for Development

``` r

devtools::load_all("/Users/einarhj/R/Pakkar/obus")
```

------------------------------------------------------------------------

## Key Data Objects (in `data/`)

| Object | Rows | Description |
|----|----|----|
| `dr_lookup_fields` | ~292 | Type lookup table: `table`, `new`, `old`, `format`, `description`. Used internally by `.dr_settypes()`. Regenerate by sourcing `data-raw/DATASET_lookup_fields.R`. |
| `dr_lookup_species` | 2000+ | Aphia ID ↔︎ latin + common name mapping. Source: worrms + HL/CA parquet. Regenerate via `data-raw/DATASET_species.R`. |
| `dr_lookup_vocabulary` | ~10 300 | Valid codes for DATRAS categorical fields, sourced from the ICES vocabulary server. Columns: `old`, `new`, `key`, `description`, `type`, `type_desc`. Covers all `dr_lookup_fields` old-style names except Month/Quarter/Year. Regenerate via `data-raw/DATASET_vocabulary.R`. |
| `dr_coastline` | — | Coastline geometry for DATRAS survey area. Source: rnaturalearth. |

**Git LFS tracks `data/*.rda`** via `.gitattributes` — after
`usethis::use_data(..., overwrite = TRUE)`, verify the file is staged as
actual content, not just a pointer.

------------------------------------------------------------------------

## Data Retrieval: `dr_get()`

``` r

dr_get(recordtype, surveys = NULL, years = 1965:2030, quarters = 1:4,
       aphia = NULL, from = "parquet", quiet = TRUE)
```

- `surveys = NULL` → defaults to all ICES surveys excluding test surveys
  (via `.dr_default_surveys()`, which calls
  [`icesDatras::getSurveyList()`](https://rdrr.io/pkg/icesDatras/man/getSurveyList.html)
  and drops anything matching `^Test`).
- `aphia = NULL` → defaults to cod (126436), haddock (126437),
  herring (126417) for record types that require species codes (`"CW"`,
  `"IDX"`).

### Record Types

| `recordtype` | Underlying function | Notes |
|----|----|----|
| `"HH"` | parquet / getDATRAS / get_datras_unaggregated_data | Haul header |
| `"HL"` | parquet / getDATRAS / get_datras_unaggregated_data | Catch-at-length (~14M rows) |
| `"CA"` | parquet / getDATRAS / get_datras_unaggregated_data | Catch-at-age (~5.8M rows) |
| `"FL"` | [`icesDatras::getFlexFile`](https://rdrr.io/pkg/icesDatras/man/getFlexFile.html) | Flex file; iterates per survey×year×quarter |
| `"LT"` | [`icesDatras::getLTassessment`](https://rdrr.io/pkg/icesDatras/man/getLTassessment.html) | Litter assessment; iterates per survey×year×quarter |
| `"CPUEL"` | [`icesDatras::getCPUELength`](https://rdrr.io/pkg/icesDatras/man/getCPUELength.html) | CPUE per length per haul per hour; scalar args only per call; slow (~30s/combination) |
| `"CPUEA"` | [`icesDatras::getCPUEAge`](https://rdrr.io/pkg/icesDatras/man/getCPUEAge.html) | CPUE per age per haul per hour; xsi:nil artifact cleaned per-df before bind |
| `"CW"` | [`icesDatras::getCatchWgt`](https://rdrr.io/pkg/icesDatras/man/getCatchWgt.html) | Catch weight; `aphia` required (or defaults); years/quarters passed as vectors; NA in CatchWgt = species absent from haul |
| `"IDX"` | [`icesDatras::getIndices`](https://rdrr.io/pkg/icesDatras/man/getIndices.html) | Age-based survey indices; `aphia` required (or defaults); iterates per survey×year×quarter×species (all scalar); IDX column `PlusGr` renamed to `PlusGrAge` |

### `from` argument (HH/HL/CA only)

| `from` | Source | Notes |
|----|----|----|
| `"parquet"` | URL-hosted parquet (default) | Fastest; all surveys; no filtering |
| `"new"` | `get_datras_unaggregated_data` | Range strings; per-survey tryCatch |
| `"old"` | `getDATRAS` | Legacy; per-survey tryCatch |

`from` is ignored for FL, LT, CPUEL, CPUEA, CW, IDX.

------------------------------------------------------------------------

## Raw ICES Tables: `dr_con_raw()`

``` r

dr_con_raw(table = "HH")
```

Returns a lazy `duckdbfs` tibble connected to “as-is” ICES parquet files
with original old-style column names (Ship, HaulNo, ShootLat, etc.).
Valid tables: `"HH"`, `"HL"`, `"CA"`, `"FL"`, `"LT"`, `"CPUEL"`,
`"CPUEA"`, `"CW"`, `"IDX"`. Use when you need unmodified ICES output.

------------------------------------------------------------------------

## Tidy DuckDB Connection: `dr_con()`

``` r

dr_con(type, trim = TRUE, url = "https://heima.hafro.is/~einarhj/datras", quiet = TRUE)
```

Returns a lazy `duckdbfs` tibble of tidied parquet data. Types accepted:
`"HH"`, `"HL"`, `"CA"`, `"species"`, `"haul"`, `"dictionary"`,
`"vocabulary"`, `"cpuelength"`.

------------------------------------------------------------------------

## Transformation Functions

All return the same object type as input (pipeable). Work on both data
frames and DuckDB lazy tables where noted.

| Function | Input cols | Output col | Notes |
|----|----|----|----|
| `dr_add_id(d, base)` | Survey, Year, Quarter, Country, Platform, Gear, StationName, HaulNumber | `.id` | `base = "new"` (default) or `"old"` |
| `dr_add_date(d)` | Year, Month, Day | `date` | Works on DuckDB too |
| `dr_add_starttime(d)` | Year, Month, Day, StartTime / TimeShot | `time` (POSIXct) | Parses HHMM |
| `dr_add_length_cm(d, ...)` | LengthCode, LengthClass | `length_cm` | LengthCode “.” or “0” → /10; “1”,“2”,“5” → as-is |
| `dr_add_length_mm(d, ...)` | LengthCode, LengthClass | `length_mm` | Inverse of above |
| `dr_add_n_and_cpue(d, ...)` | DataType, NumberAtLength, HaulDuration, SubsamplingFactor, .id | `n_haul`, `n_hour` | DataType “C” uses different formula |
| `dr_add_record_type(d)` | LengthClass, n_haul, SpeciesSex, DevelopmentStage, TotalNumber, etc. | `record_type` (int) | 15 types + 99 catch-all; see `hl_record_type_lookup` |
| `dr_translate(d, dictionary, from, to)` | — | renamed cols | Renames columns using a from/to dictionary; defaults `from = "old"`, `to = "new"` |

### `dr_translate` and `dr_lookup_fields`

Typical usage to rename raw (old-style) columns to tidy (new-style):

``` r

dictionary <- dr_lookup_fields |> select(old, new) |> distinct()
dr_con_raw("HH") |> dr_translate(dictionary, from = "old", to = "new")
```

**Reversibility caveat:** 7 `new` names map to more than one `old` name;
`dr_translate(..., from = "new", to = "old")` silently picks the first
match. Affected names:

| `new`            | `old` options                                     |
|------------------|---------------------------------------------------|
| `Platform`       | `Ship` (HH/HL/CA) · `Platform` (FL)               |
| `BottomDepth`    | `Depth` (HH/FL) · `BottomDepth` (LT)              |
| `HaulNumber`     | `HaulNo` (HH/HL/CA) · `HaulNumber` (LT)           |
| `StationName`    | `StNo` (HH) · `StationName` (LT)                  |
| `RecordHeader`   | `RecordType` (CA) · `RecordHeader` (FL)           |
| `NumberAtLength` | `HLNoAtLngt` (HL) · `CANoAtLngt` (CA)             |
| `SpeciesCode`    | `SpecCode` (HL/CA) · `SpeciesCode` (some entries) |

For reliable new→old translation, filter the dictionary to a specific
`table` first.

------------------------------------------------------------------------

## Product Functions (`R/dr_products.R`)

Both functions accept raw HH and HL tables with **old-style column
names** (as returned by [`dr_get()`](reference/dr_get.md) or the raw
parquets). They share the same filtering arguments and zero-fill
convention.

### Shared arguments

| Argument | Default | Meaning |
|----|----|----|
| `hh` | — | DATRAS HH table (new-style names, from [`dr_get()`](reference/dr_get.md) default or [`dr_con()`](reference/dr_con.md)) |
| `hl` | — | DATRAS HL table (new-style names) |
| `haulval` | `"V"` | `HaulValidity` codes to retain (valid hauls) |
| `specval` | `1L` | `SpeciesValidity` codes to retain (standard species records) |
| `zerofill` | `FALSE` | Add explicit zero rows for species absent from a haul but observed in the same Survey/Year/Quarter |
| `diag` | `FALSE` | Return pre-aggregation table for QC/diagnostic inspection (both functions) |

### `dr_cpue_by_length(hh, hl, haulval, specval, zerofill, diag)`

CPUE per length class per haul per species. One row per `.id` ×
`ValidAphiaID` × `length_mm`.

| Output column | Description |
|----|----|
| `.id` | 8-field haul key: `Survey:Year:Quarter:Country:Platform:Gear:StationName:HaulNumber` |
| `.id2` | 6-field key matching ICES CPUEL: `Survey:Year:Quarter:Platform:Gear:HaulNumber` |
| `Survey`, `Year`, `Quarter` | Survey metadata |
| `ValidAphiaID` | Valid WoRMS AphiaID |
| `length_mm` | Length class in mm (converted from `LengthClass` via `LengthCode`) |
| `n_hour` | CPUE: numbers per hour, summed across `SpeciesSex` and `SpeciesCategory` |

- Zero-fill rows have `length_mm = NA`, `n_hour = 0`.
- `diag = TRUE` skips the SpeciesSex/SpeciesCategory aggregation and
  returns per-row data with `SpeciesSex`, `SpeciesCategory`,
  `NumberAtLength`, `SubsamplingFactor`, `DataType`, `HaulDuration`,
  `n_haul`, `n_hour`. Useful for diagnosing duplicate rows or
  sex-mixing.
- When `zerofill = TRUE` the aggregated CPUE is collected into memory;
  the function returns a data frame (not lazy).

### `dr_cpue_by_haul(hh, hl, haulval, specval, zerofill, diag)`

Haul-level catch totals (numbers and weights). Operates directly on
`TotalNumber` and `SpeciesCategoryWeight` from HL — independent of
`dr_cpue_by_length`. Deduplicates to one row per
species/sex/SpeciesCategory group (collapsing repeated length rows),
applies DataType-aware scaling, then sums across `SpeciesSex` and
`SpeciesCategory`. One row per `.id` × `ValidAphiaID`.

| Output column | Description |
|----|----|
| `.id`, `.id2`, `Survey`, `Year`, `Quarter`, `ValidAphiaID` | Same as `dr_cpue_by_length` |
| `n_haul` | Total estimated numbers caught per haul (from `TotalNumber`) |
| `n_hour` | Total numbers per hour of hauling |
| `w_haul` | Total catch weight per haul in grams (from `SpeciesCategoryWeight`) |
| `w_hour` | Total catch weight per hour of hauling in grams |

- `w_haul`/`w_hour` are `NA` when `SpeciesCategoryWeight` was not
  recorded for all sex/category groups of a species in that haul.
- Zero-fill rows have all four metrics set to `0`.
- `diag = TRUE` skips aggregation and returns the deduplicated, scaled
  table at the species/sex/SpeciesCategory level, retaining `DataType`,
  `HaulDuration`, `TotalNumber`, `SpeciesCategoryWeight`. Useful for
  spotting inconsistent `TotalNumber` values or unexpected sex/category
  structure.
- `n_haul`/`n_hour` from this function may differ slightly from values
  derived by summing `dr_cpue_by_length` output, because `TotalNumber`
  and `sum(NumberAtLength × SubsamplingFactor)` can diverge due to
  rounding in submitted data.

### Common pipeline

``` r

# New-style parquets (no /old/ in path)
hh <- duckdbfs::open_dataset("https://heima.hafro.is/~einarhj/datras/HH.parquet") |>
  dplyr::filter(Survey == "NS-IBTS", Year == 2023, Quarter == 1)
hl <- duckdbfs::open_dataset("https://heima.hafro.is/~einarhj/datras/HL.parquet") |>
  dplyr::filter(Survey == "NS-IBTS", Year == 2023, Quarter == 1)

# Length-disaggregated CPUE
cpue <- dr_cpue_by_length(hh, hl)

# Same, with zero-fill
cpue_zf <- dr_cpue_by_length(hh, hl, zerofill = TRUE)

# Haul-level totals with weights (no length breakdown)
catch <- dr_cpue_by_haul(hh, hl)

# Diagnostic: inspect SpeciesSex / SpeciesCategory structure (dr_cpue_by_length)
dr_cpue_by_length(hh, hl, diag = TRUE) |>
  dplyr::filter(ValidAphiaID == 126417) |>
  dplyr::collect()

# Diagnostic: inspect TotalNumber / SpeciesCategoryWeight structure (dr_cpue_by_haul)
dr_cpue_by_haul(hh, hl, diag = TRUE) |>
  dplyr::filter(ValidAphiaID == 126417) |>
  dplyr::collect()
```

### Design notes

- Both functions filter HH to `HaulVal %in% haulval` before joining, so
  invalid hauls are excluded from HL.
- `SpecVal %in% as.character(specval)` is applied to HL (the parquet
  stores `SpecVal` as character).
- Sex is always aggregated away in the standard output. `diag = TRUE`
  exposes the Sex/CatIdentifier breakdown for QC.
- The `.id2` field (6-field key lacking Country and StationName) exists
  solely for comparison with the ICES CPUEL product, which omits those
  fields. Use `.id` for all joining within obus. Note: the ICES CPUEL
  product uses old-style names (`Ship`, `HaulNo`) while `.id2` is now
  built from new-style names (`Platform`, `HaulNumber`); these match
  numerically in well-formed data but may diverge in edge cases.
- `dr_cpue_by_length` derives counts from `HLNoAtLngt × SubFactor`;
  `dr_cpue_by_haul` uses `TotalNo` directly. These should be equal for
  well-formed data but can diverge slightly due to rounding in submitted
  records.

------------------------------------------------------------------------

## Quality Control Functions (`R/dr_check.R`)

All `dr_check_*` functions accept a collected data frame or a
`tbl_duckdb_connection` (collected internally where needed). They
**never throw on failure** — they report results in a standard one-row
tibble:

| Column     | Type | Description                      |
|------------|------|----------------------------------|
| `check`    | chr  | Name of the check                |
| `table`    | chr  | Which DATRAS table was inspected |
| `n_fail`   | int  | Number of failing rows / groups  |
| `n_total`  | int  | Total rows / groups evaluated    |
| `pct_fail` | dbl  | Percentage failing               |
| `detail`   | chr  | Human-readable failure breakdown |

**Column name defaults follow new-style names** (as returned by
[`dr_get()`](reference/dr_get.md) default /
[`dr_con()`](reference/dr_con.md)). Pass old-style names explicitly via
the column arguments when working on tables from
[`dr_con_raw()`](reference/dr_con_raw.md) or `dr_get(from = "old")`.

| Function | Table | What it checks |
|----|----|----|
| `dr_check_sentinels(d, table_label)` | any | Numeric/integer columns for surviving `-9` sentinel values (should have been replaced with `NA` on fetch) |
| `dr_check_subfactor(hl, DataType, SubsamplingFactor)` | HL | `SubsamplingFactor` constraints: R → ≥ 1, S → \> 1, C → == 1. NA SubsamplingFactor always fails. For old-style tables pass `SubsamplingFactor = SubFactor`. |
| `dr_check_totalno(hl, DataType, TotalNumber, SubsamplingFactor, NumberAtLength, Species, Sex, SpeciesCategory, tol)` | HL | Per-group arithmetic: R/S → `TotalNumber ≈ sum(NumberAtLength) × SubsamplingFactor`; C → `TotalNumber ≈ sum(NumberAtLength)`. Tolerance `tol = 0.5` fish. `Species` defaults to `ValidAphiaID`; `Sex` defaults to `SpeciesSex` (HL). For old-style pass column overrides. |
| `dr_check_all(hh, hl, ca, ...)` | HH/HL/CA | Convenience wrapper: runs sentinel checks on each supplied table, plus subfactor and totalno on HL. Returns all results bound into one tibble. Both HH and HL must have `.id` added first. |

### Known QC baseline (NS-IBTS 2024 Q1)

From testing on NS-IBTS 2024 Q1 (~14k HH rows, ~667k HL rows): -
**Sentinels:** 0 failures in both HH and HL — fetchers are cleaning `-9`
correctly. - **SubsamplingFactor:** ~6 failures (0.015%) — all
`SubsamplingFactor = NA` under DataType R (Norwegian and Dutch vessels).
These produce `NA` in `n_haul` downstream. - **TotalNumber:** ~72
failures (1.1%) — all DataType C records; diffs of 1–20 fish; consistent
with CPUE-to-count back-conversion rounding in ICES submissions.
Expected.

------------------------------------------------------------------------

## Internal Architecture (`R/dr_get.R`)

### `.dr_settypes(d, name_col, recordheader)`

Applies column types from `dr_lookup_fields`. Called per data frame
before `bind_rows` in all fetchers.

- `name_col = "new"` → new-style names (parquet/new API); this is the
  default
- `name_col = "old"` → old-style names (getDATRAS, FL, LT, CW, CPUEL,
  CPUEA, IDX)
- `recordheader`: filter to specific `table` value, or `NULL` to use all
- Replaces literal `"NA"` strings with real `NA` before coercion
- `-9` sentinel values replaced with `NA` in fetchers (not here)

### Internal fetch helpers

| Helper | Pattern |
|----|----|
| `.dr_fetch_parquet(recordtype)` | Single [`arrow::read_parquet()`](https://arrow.apache.org/docs/r/reference/read_parquet.html) from URL |
| `.dr_fetch_old(recordtype, surveys, years, quarters, quiet)` | `map(surveys, getDATRAS)` with tryCatch; `.dr_settypes(name_col = "old")` |
| `.dr_fetch_new(recordtype, surveys, years, quarters, quiet)` | `map(surveys, get_datras_unaggregated_data)` with range strings |
| `.dr_fetch_flex(surveys, years, quarters, quiet)` | `expand_grid` × `pmap` per survey×year×quarter; `.dr_settypes(name_col = "old", recordheader = "FL")` |
| `.dr_fetch_lt(surveys, years, quarters, quiet)` | Same pattern; strips xsi:nil from all cols; borrows types from all tables; `.dr_settypes(name_col = "old")` |
| `.dr_fetch_cpue_length(surveys, years, quarters, quiet)` | Same pattern; `.dr_settypes(name_col = "old", recordheader = "CPUEL")` per df |
| `.dr_fetch_cpue_age(surveys, years, quarters, quiet)` | Same pattern; strips `xsi:nil="true"` and coerces Age\_\* **per df before `bind_rows`**; `.dr_settypes(name_col = "old", recordheader = "CPUEA")` |
| `.dr_fetch_catch_wgt(surveys, years, quarters, aphia, quiet)` | `map(surveys, getCatchWgt)`; years/quarters as vectors; `.dr_settypes(name_col = "old")` per df |
| `.dr_fetch_indices(surveys, years, quarters, aphia, quiet)` | `expand_grid` × `pmap` per survey×year×quarter×species; renames `PlusGr` → `PlusGrAge`; same Age\_\* cleanup as CPUEA; `.dr_settypes(name_col = "old", recordheader = "IDX")` per df |
| `.dr_default_surveys()` | Returns `getSurveyList()` minus entries matching `^Test` (case-insensitive) |
| `.dr_default_aphia()` | Returns `c(126436L, 126437L, 126417L)` — cod, haddock, herring |

------------------------------------------------------------------------

## `dr_lookup_fields` — Schema and Regenerating

Columns: `table` (record type), `new` (new-style column name from
`get_datras_unaggregated_data`), `old` (old-style column name from
`getDATRAS` and derived products), `format` (“chr”/“int”/“dbl”),
`description`.

The `new` column is filled in for derived tables (CPUEL, CPUEA, IDX) by
matching their `old` names against the HH/HL/CA source mapping. Columns
with no HH/HL/CA counterpart (e.g. `AphiaID`, `Species`, `ShootLon`,
`LngtClas`, `DateTime`, `CPUE_number_per_hour`) remain `NA` in `new`.

To regenerate after editing type specs or when the ICES field list
changes:

``` r

source("data-raw/DATASET_lookup_fields.R")
```

The script fetches from the ICES web service, applies `case_when` fixes
for known type ambiguities, appends hand-curated entries for FL, LT,
CPUEL, CPUEA, and IDX, then fills missing `new` values from the HH/HL/CA
source mapping. Type priority rule: **chr \> dbl \> int**.

Key type fixes applied in `case_when` (using `old` names): -
`HaulNumber` → `int` - `Distance` → `dbl` - `StationName` → `chr` -
`CANoAtLngt` → `dbl` (consistent with `HLNoAtLngt`)

------------------------------------------------------------------------

## DATRAS Domain Knowledge (relevant to code flow)

> Full field/unit reference: `docs_external/DATRAS_field_reference.md`

### Haul join key

HH/HL/CA records share their first 11 fields. The meaningful join subset
is: **Survey · Year · Quarter · Country · Platform · Gear · StationName
· HaulNumber** (new-style) or **Survey · Year · Quarter · Country · Ship
· Gear · StNo · HaulNo** (old-style).
[`dr_add_id()`](reference/dr_add_id.md) constructs `.id` from these
fields; it auto-detects naming style.

### DataType (HH field — governs HL arithmetic)

| DataType | Meaning | SubsamplingFactor | NumberAtLength |
|----|----|----|----|
| `R` | Raw/sorted; some species sub-sampled | ≥ 1 | count in sub-sample |
| `S` | Unsorted bulk sub-sampled | \> 1 | count in sub-sample |
| `C` | Already raised to 1 hr haul | 1 | **CPUE (count per hour)** — not a raw count |
| `P` | Size-stratified (pseudocategory); sorted catch split into size strata, each with its own SpeciesCategory and SubsamplingFactor | ≥ 1 per stratum | count in sub-sample for that stratum |

[`dr_add_n_and_cpue()`](reference/dr_add_n_and_cpue.md) formulas: -
R/S/P: `n_haul = NumberAtLength × SubsamplingFactor`;
`n_hour = n_haul / HaulDuration × 60` - C:
`n_haul = NumberAtLength × SubsamplingFactor × HaulDuration / 60`
(back-convert CPUE → per-haul count);
`n_hour = NumberAtLength × SubsamplingFactor`

### LengthClass units depend on LengthCode

| LengthCode          | Unit of LengthClass    |
|---------------------|------------------------|
| `"."` or `"0"`      | mm (divide by 10 → cm) |
| `"1"`, `"2"`, `"5"` | cm (use as-is)         |

[`dr_add_length_cm()`](reference/dr_add_length_cm.md) and
[`dr_add_length_mm()`](reference/dr_add_length_mm.md) encode this rule.

### Species codes across eras

| `SpecCodeType` | Scheme                  | Era        |
|----------------|-------------------------|------------|
| `W`            | WoRMS AphiaID (current) | Post ~2010 |
| `T`            | ITIS TSN                | Historical |
| `N`            | NODC                    | Historical |

All codes mapped to `ValidAphiaID` (WoRMS) in HL/CA for cross-era joins.
Use `ValidAphiaID` rather than `SpeciesCode` / `SpecCode` when joining
across years.

### SpeciesValidity — species validity

Only `SpeciesValidity = 1` records are used for DATRAS derived products
(CPUE, indices). Other codes indicate calibration hauls, partial
sampling, etc. Raw HL/CA includes all values. Filter to
`SpeciesValidity == 1` when replicating official product calculations.
(Old-style name: `SpecVal`)

### CPUE zeroes in derived products

A CPUE zero means the species was **absent** from that haul but was
observed by at least one country in the same survey/year/quarter. The
zero-record is inserted automatically by ICES. Distinct from `NA`.

### Age plus groups

Age-based products cap at a survey/species-specific plus group set by
the responsible expert group.

| Survey  | Plus group for standard spp.             |
|---------|------------------------------------------|
| NS-IBTS | Age_6 (all fish 6+ → Age_6)              |
| Others  | Up to Age_10 (CPUEA/IDX) or Age_15 (IDX) |

### Day/Night

Daytime = 15 min before sunrise → 15 min after sunset. NOAA solar
calculator used for shoot position + date.

### Weights and distances — key units

| Field (old) | Unit |
|----|----|
| `SubWgt`, `CatCatchWgt`, `IndWgt` | **Grams** |
| `Depth`, `Distance`, `WingSpread`, `DoorSpread`, `Warplngt` | Metres |
| `HaulDur` | Minutes |
| `GroundSpeed`, `SpeedWater` | Knots |
| `SurTemp`, `BotTemp` | Celsius |
| `SurSal`, `BotSal` | PSU |
| `TimeShot` | hhmm (GMT) — parsed by [`dr_add_starttime()`](reference/dr_add_starttime.md) |
| `ShootLat/Long`, `HaulLat/Long` | Degree.Decimal Degree |

------------------------------------------------------------------------

## Known Issues / Gotchas

- **LT field name mismatch:** The ICES web service returns LT entries
  with new-style `old` values (e.g. `Platform`, `HaulNumber`) that do
  not match actual column names from `getLTassessment()` (e.g. `Ship`,
  `HaulNo`). Those entries don’t fire in `.dr_settypes()`. Flagged in
  code comments.
- **CPUEA / IDX / LT xsi:nil artifact:** Columns with no data arrive
  with names like `` `Age_6 xsi:nil="true"` `` or
  `` `Tickler xsi:nil="true"` ``. The fetcher strips this suffix from
  **all** column names per df before `bind_rows`. For CPUEA/IDX, Age\_\*
  are also coerced to numeric in the same step.
- **IDX PlusGr → PlusGrAge:** The `PlusGr` column in IDX output is
  renamed to `PlusGrAge` in `.dr_fetch_indices()` to avoid conflict with
  CA’s `PlusGr` chr flag (“+”).
- **Sex in derived tables:** CPUEL, CPUEA, IDX return a `Sex` column
  (old-style name). The fill-in maps it to `IndividualSex` (from CA)
  because CA’s entry is encountered first — but the HL mapping would
  give `SpeciesSex`. The correct new-style name for Sex in these derived
  products is unresolved; it remains a known ambiguity.
- **CW NAs:** `CatchWgt = NA` means species was absent from that haul
  (not missing data). ~40% NA is typical for a two-species query.
- **CPUEL is slow:** ~30s per survey/year/quarter API call.
- **IDX returns no rows silently:** If a species has no indices defined
  for a given survey/quarter (e.g. herring in NS-IBTS Q1), `tryCatch`
  drops the result silently. Expected behaviour.
- **Git LFS:** `data/*.rda` tracked by LFS. After
  [`usethis::use_data()`](https://usethis.r-lib.org/reference/use_data.html),
  verify the file is staged as actual content, not just a pointer.

------------------------------------------------------------------------

## Outstanding Issues

Issues discovered during the new-style naming refactor that warrant
future attention.

1.  **`SpeciesSex` vs `IndividualSex` ambiguity for Sex column.** HL
    uses `SpeciesSex`; CA uses `IndividualSex`.
    [`dr_check_totalno()`](reference/dr_check_totalno.md) now defaults
    to `SpeciesSex`, which is correct for HL but wrong for CA-based
    checks. The `dr_check_*` functions were designed for HL and are not
    tested on CA tables. Clarify scope and add CA support if needed.

2.  **`.id` prerequisite in
    [`dr_check_totalno()`](reference/dr_check_totalno.md) is not
    validated.** The function groups by `.id` internally but does not
    check that `.id` is present, producing a confusing error message if
    missing. Either add an upfront check with a clear message, or have
    [`dr_check_all()`](reference/dr_check_all.md) call
    [`dr_add_id()`](reference/dr_add_id.md) on the supplied tables
    before passing them to the check functions.

3.  **`dr_get(from = "parquet")` vs `from = "old"/"new"` return
    different schemas — undocumented.** The `from` argument changes not
    just the data source but the output column naming convention:
    `"parquet"` and `"new"` → new-style; `"old"` → old-style. This
    schema difference is not currently documented in
    [`dr_get()`](reference/dr_get.md). Should be made explicit (and
    ideally all paths should return new-style names).

4.  **`dr_cpue_by_*` `.id2` field now uses new-style names; ICES CPUEL
    product uses old-style.** `.id2` is now
    `Survey:Year:Quarter:Platform:Gear:HaulNumber`. The ICES CPUEL
    parquet (raw) uses `Survey:Year:Quarter:Ship:Gear:HaulNo`. Joins
    between `.id2` and CPUEL will usually succeed because
    `Platform == Ship` and `HaulNumber == HaulNo` numerically, but this
    is not guaranteed in all edge cases. Consider adding a note to the
    `dr_cpue_by_*` documentation, or building `.id2` from the ICES-side
    fields explicitly for comparison purposes.

5.  **[`dr_con()`](reference/dr_con.md) `trim` parameter is silently
    ignored for non-HL/CA types.** A warning is only emitted when
    `quiet = FALSE`. Users who pass `trim = FALSE` to a `dr_con("HH")`
    call get the full table with no indication that `trim` was ignored.
    Should either always warn or document the behaviour more clearly.

6.  **[`dr_add_n_and_cpue()`](reference/dr_add_n_and_cpue.md) requires
    `.id` and `DataType` but does not use `.id` internally.** `.id` is
    in the `required_vars` check but is not actually used in the
    computation. This was presumably a guard to ensure the table has
    been joined correctly, but it’s misleading and will cause spurious
    failures on valid inputs that lack `.id`. Remove `.id` from the
    required column check or document why it’s enforced.

7.  **No auto-detection of naming style in `dr_cpue_by_*`.** Unlike
    [`dr_add_id()`](reference/dr_add_id.md), the product functions do
    not detect old vs new style and fail with a column-not-found error
    if given old-style data. A deprecation shim (checking for `Platform`
    vs `Ship`) would provide backward compatibility during the
    transition period.

8.  **Test coverage for `dr_check_*` needs updating.** The `tests/`
    directory should be reviewed: any tests that pass old-style column
    names to [`dr_check_subfactor()`](reference/dr_check_subfactor.md)
    or [`dr_check_totalno()`](reference/dr_check_totalno.md) will now
    fail because the defaults changed. Update test fixtures to use
    new-style names or add explicit column-override arguments.

------------------------------------------------------------------------

## Typical Workflow

``` r

library(obus)

# Full parquet download
hh <- dr_get("HH")
hl <- dr_get("HL")

# Prepare HH
hh <- hh |> dr_add_id() |> dr_add_date() |> dr_add_starttime()

# Prepare HL
hl <- hl |>
  dr_add_id() |>
  dr_add_length_cm() |>
  dr_add_n_and_cpue() |>
  dr_add_record_type()

# Specific survey, recent years, via new API
hh_ns <- dr_get("HH", surveys = "NS-IBTS", years = 2020:2024, from = "new")

# Flex file
fl <- dr_get("FL", surveys = "NS-IBTS", years = 2020:2023, quarters = 1)

# CPUE by length
cpuel <- dr_get("CPUEL", surveys = "NS-IBTS", years = 2018, quarters = 1)

# CPUE by age
cpuea <- dr_get("CPUEA", surveys = "NS-IBTS", years = 2018, quarters = 1)

# Catch weight (defaults to cod/haddock/herring if aphia omitted)
cw <- dr_get("CW", surveys = "NS-IBTS", years = 2018, quarters = 1,
             aphia = c(126436, 126437))  # cod, haddock

# Survey indices (defaults to cod/haddock/herring if aphia omitted)
idx <- dr_get("IDX", surveys = "NS-IBTS", years = 2018, quarters = 1,
              aphia = c(126436, 126437))

# Raw ICES tables (old-style column names)
dr_con_raw("HH") |> dplyr::filter(Year == 2020) |> dplyr::collect()

# Translate raw old-style names to new-style
dictionary <- dr_lookup_fields |> dplyr::select(old, new) |> dplyr::distinct()
dr_con_raw("HH") |> dr_translate(dictionary, from = "old", to = "new")

# Lazy DuckDB query on tidy parquet
dr_con("HL") |>
  dplyr::filter(Survey == "NS-IBTS", Year >= 2020) |>
  dplyr::collect()

# QC checks on new-style data (dr_get / dr_con)
hh_ns <- dr_get("HH", surveys = "NS-IBTS", years = 2024, quarters = 1)
hl_ns <- dr_get("HL", surveys = "NS-IBTS", years = 2024, quarters = 1)

hh_ns <- hh_ns |> dr_add_id()
hl_ns <- hl_ns |> dr_add_id() |>
  dplyr::left_join(dplyr::select(hh_ns, .id, DataType), by = ".id")

dr_check_all(hh = hh_ns, hl = hl_ns)

# QC checks on old-style raw data (dr_con_raw) — pass column overrides
hh_raw <- dr_con_raw("HH") |> dplyr::filter(Survey == "NS-IBTS", Year == 2024, Quarter == 1) |> dplyr::collect()
hl_raw <- dr_con_raw("HL") |> dplyr::filter(Survey == "NS-IBTS", Year == 2024, Quarter == 1) |> dplyr::collect()

hh_raw <- hh_raw |> dr_add_id()
hl_raw <- hl_raw |> dr_add_id() |>
  dplyr::left_join(dplyr::select(hh_raw, .id, DataType), by = ".id")

dr_check_all(hh = hh_raw, hl = hl_raw,
             SubsamplingFactor = SubFactor,
             TotalNumber = TotalNo, NumberAtLength = HLNoAtLngt,
             Species = Valid_Aphia, Sex = Sex, SpeciesCategory = CatIdentifier)
```
