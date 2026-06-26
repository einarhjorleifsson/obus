# Assign Survey Strata to Hauls by Position

Spatially joins haul shoot positions to survey area polygons, adding one
or more area attribute columns to the haul table.

## Usage

``` r
dr_assign_area(
  d,
  areas = NULL,
  lon = "ShootLongitude",
  lat = "ShootLatitude",
  keep_cols = "AreaName",
  quiet = TRUE
)
```

## Arguments

- d:

  An HH data frame or lazy `tbl_duckdb_connection`.

- areas:

  `NULL` (use
  [`dr_lookup_areas`](https://einarhjorleifsson.github.io/obus/reference/dr_lookup_areas.md)),
  an `sf` object (data frame path), or a `tbl_duckdb_connection` (DuckDB
  path).

- lon:

  Longitude column name in `d`. Default `"ShootLongitude"` (new-style).
  Old-style: `"ShootLong"`.

- lat:

  Latitude column name in `d`. Default `"ShootLatitude"` (new-style).
  Old-style: `"ShootLat"`.

- keep_cols:

  Character vector of column names from `areas` to append to `d`.
  Default `"AreaName"`. The geometry column (`geom` / `geometry`) is
  never included.

- quiet:

  Logical. If `TRUE` (default), suppresses progress messages.

## Value

`d` with `keep_cols` appended. Hauls outside all polygons get `NA`. For
the DuckDB path the result is a new lazy table; for the data frame path
it is a `data.frame`. Overlapping polygons in `areas` may produce
duplicate rows.

## Two-path design

The function follows a strict type convention:

- Data frame path:

  When `d` is a collected `data.frame`, `areas` must be an `sf` object
  (or `NULL`, which uses the bundled
  [`dr_lookup_areas`](https://einarhjorleifsson.github.io/obus/reference/dr_lookup_areas.md)).
  The join is done with
  [`sf::st_join()`](https://r-spatial.github.io/sf/reference/st_join.html).

- DuckDB path:

  When `d` is a `tbl_duckdb_connection`, `areas` must be a
  `tbl_duckdb_connection` (or `NULL`, which auto-converts
  [`dr_lookup_areas`](https://einarhjorleifsson.github.io/obus/reference/dr_lookup_areas.md)
  via a temporary FlatGeobuf file). The join is executed entirely inside
  DuckDB using `ST_Within(ST_Point(lon, lat), geom)` — no data is moved
  to R. The result is a new lazy table.

## Providing custom areas

Supply your own `sf` polygon layer (data frame path) or
`tbl_duckdb_connection` (DuckDB path) as `areas`. Any column(s) named in
`keep_cols` are appended. Common sources:

- [`dr_get_areas()`](https://einarhjorleifsson.github.io/obus/reference/dr_get_areas.md)
  for live full-resolution ICES polygons.

- `duckdbfs::open_dataset("https://.../areas.fgb")` for the server
  FlatGeobuf — the DuckDB path requires the geometry column to be named
  `geom`.

- Any user-supplied `sf` or spatial file opened as a duckdb connection.

## Survey filtering

Whenever both `d` and `areas` contain a `Survey` column the join is
additionally constrained to `h.Survey = a.Survey`, preventing
false-positive matches where surveys have geographically overlapping
strata. This applies whether `areas` is the default
[`dr_lookup_areas`](https://einarhjorleifsson.github.io/obus/reference/dr_lookup_areas.md)
or a custom object (e.g. the server FlatGeobuf). To suppress it, drop or
rename the `Survey` column from `areas` before passing.

## FlatGeobuf on server

A full-resolution FlatGeobuf is available at
`https://heima.hafro.is/~einarhj/datras/areas.fgb` (all Valid classes).
Use it with:


    areas_con <- duckdbfs::open_dataset(
      "https://heima.hafro.is/~einarhj/datras/areas.fgb"
    )
    hh_con |> dr_assign_area(areas = areas_con)

## See also

[`dr_get_areas`](https://einarhjorleifsson.github.io/obus/reference/dr_get_areas.md),
[`dr_lookup_areas`](https://einarhjorleifsson.github.io/obus/reference/dr_lookup_areas.md),
[`dr_add_id`](https://einarhjorleifsson.github.io/obus/reference/dr_add_id.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# ── Data frame path ────────────────────────────────────────────────────────
hh <- dr_get("HH", surveys = "NS-IBTS", years = 2023, quarters = 1) |>
  dr_add_id()
hh |> dr_assign_area()                             # default bundled strata
hh |> dr_assign_area(areas = dr_get_areas("NS-IBTS", valid = 1))  # live fetch
hh |> dr_assign_area(areas = my_sf, keep_cols = "zone_id")        # custom

# ── DuckDB path ────────────────────────────────────────────────────────────
hh_con <- duckdbfs::open_dataset("https://.../HH.parquet") |>
  dplyr::filter(Survey == "NS-IBTS", Year == 2023) |>
  dr_add_id()
hh_con |> dr_assign_area()          # auto-converts dr_lookup_areas

# server FlatGeobuf, filtered to Valid = 1 before passing
areas_con <- duckdbfs::open_dataset(
  "https://heima.hafro.is/~einarhj/datras/areas.fgb"
) |> dplyr::filter(Valid == 1L)
hh_con |> dr_assign_area(areas = areas_con)
} # }
```
