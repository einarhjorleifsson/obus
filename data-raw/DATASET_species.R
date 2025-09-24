library(tidyverse)

# Species joins ----------------------------------------------------------------

## get all combination of speccodetype, speccode and valid_aphia --------------
fil <- fs::dir_ls("~/stasi/datras/data-raw/datras", glob = "*_hl.rds")
hl <-
  map_df(fil, read_rds) |> tidydatras::dr_tidy() |>
  mutate(aphia = case_when(!is.na(valid_aphia) & valid_aphia != "0" ~ valid_aphia,
                           speccodetype == "W" ~ speccode,
                           TRUE ~ NA_character_),
         aphia = as.integer(aphia))
fil <- fs::dir_ls("~/stasi/datras/data-raw/datras", glob = "*_ca.rds")
ca <-
  map_df(fil, read_rds) |>
  tidydatras::dr_tidy() |>
  mutate(aphia = case_when(!is.na(valid_aphia) & valid_aphia != "0" ~ valid_aphia,
                           speccodetype == "W" ~ speccode,
                           TRUE ~ NA_character_),
         aphia = as.integer(aphia))
sp <-
  bind_rows(hl |> select(speccodetype, speccode, valid_aphia, aphia) |> distinct(),
            ca |> select(speccodetype, speccode, valid_aphia, aphia) |> distinct()) |>
  distinct() |>
  rename(type = speccodetype, code = speccode)
# tests
sp |> filter(is.na(aphia))
sp |> filter(valid_aphia == "0")

##   there is a repeat of aphia, may be ok but would be Kosher to check why
sp$aphia |> na.omit() |> unique() |> length()
sp |>
  group_by(aphia) |>
  mutate(n.rep = n()) |>
  filter(n.rep > 1) |>
  arrange(aphia)

## trial with DATRASWebService -------------------------------------------------

pfix <- "https://datras.ices.dk/WebServices/DATRASWebService.asmx/getSpecies?codename=aphia&code="
res <-
  tibble::tibble(aphia = sp$aphia |> na.omit() |> unique()) |>
  dplyr::mutate(q = paste0(pfix, aphia),
                raw = map(q, icesDatras:::readDatras))
# write_rds(res, "tmp_res.rds")
dws <-
  res |>
  # this record won't parse
  slice(-114) |>
  mutate(parsed = map(raw, icesDatras:::parseDatras)) |>
  select(parsed) |>
  unnest(parsed) |>
  select(aphia, latin = latinname) |>
  distinct() |>
  # the record 114 added again, manual lookup on ices webpage
  add_row(aphia = 127178, latin = "Coregonus albula")

# tests
dws |> count(aphia) |> filter(n > 1)
dws |> count(latin) |> filter(n > 1)

# tests
sp |>
  left_join(dws) |>
  filter(is.na(latin))
hl |>
  left_join(dws) |>
  filter(is.na(latin)) |>
  pull(speccode) |>
  unique()
ca |>
  left_join(dws) |>
  filter(is.na(latin)) |>
  pull(speccode) |>
  unique()

aphia_latin <- dws
usethis::use_data(aphia_latin)

