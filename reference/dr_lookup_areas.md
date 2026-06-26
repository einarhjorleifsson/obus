# DATRAS Survey Area Polygons (Valid Strata)

An `sf` object containing the named survey strata (Valid = 1) for all
DATRAS surveys available from the ICES GIS service. Geometries are
simplified to a 0.01° tolerance (~1 km) to keep the package size
manageable; they are accurate enough for haul-in-polygon assignment.

## Usage

``` r
dr_lookup_areas
```

## Format

An object of class `sf` (inherits from `data.frame`) with 236 rows and 8
columns.

## Source

<https://gis.ices.dk/gis/rest/services/ICES_Datasets/Datras_service_prod/MapServer/0>

## Details

For full-resolution polygons or Valid = 0 features, fetch live with
[`dr_get_areas`](https://einarhjorleifsson.github.io/obus/reference/dr_get_areas.md).

A simple feature collection with 236 features and 7 fields (EPSG:4326):

- Survey:

  Survey acronym (e.g. `"NS-IBTS"`).

- AreaName:

  Stratum / area name within the survey.

- SubareaName:

  Sub-area name (often `NA`).

- Description:

  Human-readable description (often `NA`).

- Valid:

  Always `1` in this dataset (named strata only).

- SurveyCode:

  Internal integer survey code.

- Year:

  Year string; only populated for surveys with year-specific areas.

## See also

[`dr_get_areas`](https://einarhjorleifsson.github.io/obus/reference/dr_get_areas.md),
[`dr_assign_area`](https://einarhjorleifsson.github.io/obus/reference/dr_assign_area.md)
