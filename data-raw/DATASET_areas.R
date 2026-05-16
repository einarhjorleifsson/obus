## Regenerate dr_lookup_areas and publish areas.fgb to the server
##
## dr_lookup_areas:
##   - Valid = 1 strata only (named survey areas used in DATRAS products)
##   - Geometries simplified at 0.01 degree tolerance (~1 km) for package size
##   - Full-resolution: fetch live with dr_get_areas()
##
## areas.fgb (server):
##   - Full resolution, only Valid = 1
##   - Fix invalid geometry
##   - Deployed to https://heima.hafro.is/~einarhj/datras/areas.fgb
##   - Readable via DuckDB spatial: INSTALL spatial; LOAD spatial;
##     SELECT * FROM ST_Read('https://heima.hafro.is/~einarhj/datras/areas.fgb')

library(sf)
devtools::load_all()

# ── 1. Package data: Valid=1 strata, simplified ──────────────────────────────

sf::sf_use_s2(FALSE)

dr_lookup_areas <-
  dr_get_areas(quiet = FALSE) |>
  dplyr::filter(Valid == 1L) |>
  sf::st_make_valid() |>
  sf::st_simplify(dTolerance = 0.01, preserveTopology = TRUE) |>
  sf::st_make_valid()

sf::sf_use_s2(TRUE)

usethis::use_data(dr_lookup_areas, overwrite = TRUE)

# ── 2. Server FlatGeobuf: full resolution, only Valid = 1 ─────────────────────

all_areas <-
  dr_get_areas(quiet = FALSE) |>
  filter(Valid == 1)
all_areas |> st_is_valid() |> table()
all_areas <- all_areas |>
  sf::st_make_valid()
all_areas |> st_is_valid() |> table()

sf::st_write(all_areas, "data-raw/areas.fgb",
             driver = "FlatGeobuf", delete_dsn = TRUE)

# Deploy to server (requires SSH access):
#   scp data-raw/areas.fgb einarhj@heima.hafro.is:~/public_html/datras/areas.fgb
#
# Once deployed, load in DuckDB:
#   con <- duckdbfs::cached_connection()
#   DBI::dbExecute(con, "INSTALL spatial; LOAD spatial;")
#   DBI::dbGetQuery(con,
#     "SELECT * FROM ST_Read('https://heima.hafro.is/~einarhj/datras/areas.fgb')")
