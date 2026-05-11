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
| `dr_fields` | ~214 | Lookup table: RecordHeader, FieldName, FieldNameOld, DataFormat, Description. Used internally for type coercion. |
| `dr_latin_aphia` | 2000+ | Aphia ID ↔︎ latin + common name mapping. Source: worrms. |
| `dr_coastline` | — | Coastline geometry for DATRAS survey area. Source: rnaturalearth. |

`dr_fields` is saved as `data/dr_fields.rda`. **Git LFS tracks
`data/*.rda`** via `.gitattributes` — be aware when updating `.rda`
files; re-save with `usethis::use_data(..., overwrite = TRUE)`.

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
| `"IDX"` | [`icesDatras::getIndices`](https://rdrr.io/pkg/icesDatras/man/getIndices.html) | Age-based survey indices; `aphia` required (or defaults); iterates per survey×year×quarter×species (all scalar) |

### `from` argument (HH/HL/CA only)

| `from` | Source | Notes |
|----|----|----|
| `"parquet"` | URL-hosted parquet (default) | Fastest; all surveys; no filtering |
| `"new"` | `get_datras_unaggregated_data` | Range strings; per-survey tryCatch |
| `"old"` | `getDATRAS` | Legacy; per-survey tryCatch |

`from` is ignored for FL, LT, CPUEL, CPUEA, CW, IDX.

------------------------------------------------------------------------

## DuckDB Connection: `dr_con()`

``` r

dr_con(type, trim = TRUE, url = "https://heima.hafro.is/~einarhj/datras", quiet = TRUE)
```

Returns a lazy `duckdbfs` tibble — pipe dplyr verbs then `collect()`.
Types accepted: `"HH"`, `"HL"`, `"CA"`, `"species"`, `"haul"`,
`"dictionary"`, `"vocabulary"`, `"cpuelength"`.

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
| `dr_translate(d, dictionary, from, to)` | — | renamed cols | Renames columns using a from/to dictionary |

------------------------------------------------------------------------

## Internal Architecture (`R/dr_get.R`)

### `.dr_settypes(d, name_col, recordheader)`

Applies column types from `dr_fields`. Called after fetching data.

- `name_col = "FieldName"` → new-style names (parquet/new API)
- `name_col = "FieldNameOld"` → old-style names (getDATRAS, FL, LT, CW)
- `recordheader`: filter to specific record type, or `NULL` to use all
- Replaces literal `"NA"` strings with real `NA` before coercion
  (suppresses spurious warnings)
- Replaces `-9` sentinel values with `NA` (done in fetchers, not here)

### Internal fetch helpers

| Helper | Pattern |
|----|----|
| `.dr_fetch_parquet(recordtype)` | Single [`arrow::read_parquet()`](https://arrow.apache.org/docs/r/reference/read_parquet.html) from URL |
| `.dr_fetch_old(recordtype, surveys, years, quarters, quiet)` | `map(surveys, getDATRAS)` with tryCatch |
| `.dr_fetch_new(recordtype, surveys, years, quarters, quiet)` | `map(surveys, get_datras_unaggregated_data)` with range strings |
| `.dr_fetch_flex(surveys, years, quarters, quiet)` | `expand_grid` × `pmap` per survey×year×quarter |
| `.dr_fetch_lt(surveys, years, quarters, quiet)` | Same pattern; borrows types from all RecordHeaders |
| `.dr_fetch_cpue_length(surveys, years, quarters, quiet)` | Same pattern; no type coercion (derived product) |
| `.dr_fetch_cpue_age(surveys, years, quarters, quiet)` | Same pattern; strips `xsi:nil="true"` and coerces Age\_\* **per data frame before `bind_rows`** to avoid duplicates across species |
| `.dr_fetch_catch_wgt(surveys, years, quarters, aphia, quiet)` | `map(surveys, getCatchWgt)`; years/quarters as vectors; applies `.dr_settypes(name_col = "FieldNameOld")` |
| `.dr_fetch_indices(surveys, years, quarters, aphia, quiet)` | `expand_grid` × `pmap` per survey×year×quarter×species (all scalar); same Age\_\* cleanup as CPUEA |
| `.dr_default_surveys()` | Returns `getSurveyList()` minus entries matching `^Test` (case-insensitive) |
| `.dr_default_aphia()` | Returns `c(126436L, 126437L, 126417L)` — cod, haddock, herring |

------------------------------------------------------------------------

## `dr_get_fields()`

Fetches current DATRAS field specs from the ICES web service XML
endpoint and returns a tibble. Used to regenerate `dr_fields`. Includes
a hand-curated `add` tribble for FL and LT fields not covered by the web
service, and `case_when` fixes for type ambiguities (`Distance` →
decimal, `HaulNumber` → char, `StationName` → char).

To update `dr_fields` after editing
[`dr_get_fields()`](reference/dr_get_fields.md):

``` r

dr_fields <- dr_get_fields()
usethis::use_data(dr_fields, overwrite = TRUE)
```

------------------------------------------------------------------------

## Known Issues / Gotchas

- **LT field name mismatch:** The ICES web service returns LT field
  specs with new-style `FieldNameOld` values (e.g. `Platform`,
  `HaulNumber`) that do not match actual column names from
  `getLTassessment()` (e.g. `Ship`, `HaulNo`). Those entries don’t fire
  in `.dr_settypes()`. Flagged in code comments.
- **CPUEA / IDX XML nil artifact:** Age columns with no data arrive with
  names like `` `Age_6 xsi:nil="true"` ``. The fetcher strips this
  suffix and coerces Age\_\* to numeric **per data frame before
  `bind_rows`** — if done after, different age structures across species
  produce duplicate column names.
- **CW NAs:** `CatchWgt = NA` means species was absent from that haul
  (not missing data). ~40% NA is typical for a two-species query.
- **CPUEL is slow:** ~30s per survey/year/quarter API call.
- **IDX returns no rows silently:** If a species has no indices defined
  for a given survey/quarter (e.g. herring in NS-IBTS Q1), `tryCatch`
  drops the result silently. This is expected behaviour.
- **Git LFS:** `data/*.rda` tracked by LFS. After
  [`usethis::use_data()`](https://usethis.r-lib.org/reference/use_data.html),
  verify the file is staged as actual content, not just a pointer.

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

# Lazy DuckDB query (efficient for large data)
dr_con("HL") |>
  dplyr::filter(Survey == "NS-IBTS", Year >= 2020) |>
  dplyr::collect()
```
