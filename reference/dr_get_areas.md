# Fetch DATRAS Survey Area Polygons

Downloads DATRAS survey area polygons from the ICES ArcGIS REST service
and returns them as an `sf` object (EPSG:4326). Each row is one spatial
polygon (or multipolygon) associated with a survey's sampling stratum or
individual ICES rectangle.

## Usage

``` r
dr_get_areas(surveys = NULL, valid = NULL, quiet = TRUE)
```

## Arguments

- surveys:

  Character vector of survey acronyms to retain (matched against the
  `Survey` / `DatasetVer` field). `NULL` (default) returns all surveys.

- valid:

  Integer scalar (0 or 1) to filter by the `Valid` flag, or `NULL`
  (default) to return both types.

- quiet:

  Logical. If `TRUE` (default), suppresses progress messages.

## Value

An `sf` object with EPSG:4326 polygons.

## Data source

Data are fetched from:
<https://gis.ices.dk/gis/rest/services/ICES_Datasets/Datras_service_prod/MapServer/0>

## Valid flag

The layer contains two types of polygons per survey:

- **Valid = 1** — named strata / survey sub-areas (e.g. NS-IBTS areas
  1–10). These are the polygons used in DATRAS derived products.

- **Valid = 0** — additional spatial features associated with the survey
  domain (the exact meaning varies by survey).

By default both are returned; filter with `valid = 1` or `valid = 0` to
restrict to one type.

## Columns returned

- Survey:

  Survey acronym (e.g. `"NS-IBTS"`). Renamed from `DatasetVer` in the
  source.

- AreaName:

  Area / stratum name.

- SubareaName:

  Sub-area name (often `NA`).

- Description:

  Human-readable description (often `NA`).

- Valid:

  Integer flag: 1 = named stratum used in DATRAS products; 0 = other
  survey-associated feature.

- SurveyCode:

  Internal integer survey code.

- Year:

  Year string, only populated for surveys with year-specific areas (e.g.
  NS-IDPS).

- geometry:

  Polygon / multipolygon geometry (EPSG:4326).

## Examples

``` r
if (FALSE) { # \dontrun{
# All areas for all surveys
areas <- dr_get_areas()

# Named strata only for NS-IBTS
ns_strata <- dr_get_areas(surveys = "NS-IBTS", valid = 1)

# Valid = 0 features for BITS
bits_v0 <- dr_get_areas(surveys = "BITS", valid = 0)
} # }
```
