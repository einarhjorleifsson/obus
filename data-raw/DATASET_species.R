# Valid_Aphia latin lookup

## get all combination of speccodetype, speccode and valid_aphia ---------------
species <-
  dplyr::bind_rows(
    duckdbfs::open_dataset("https://heima.hafro.is/~einarhj/datras/HL.parquet") |>
      dplyr::select(ValidAphiaID) |>
      dplyr::distinct() |>
      dplyr::collect(),
    duckdbfs::open_dataset("https://heima.hafro.is/~einarhj/datras/CA.parquet") |>
      dplyr::select(ValidAphiaID) |>
      dplyr::distinct() |>
      dplyr::collect()) |>
  dplyr::distinct() |>
  dplyr::mutate(ValidAphiaID = as.integer(ValidAphiaID))

latin <- worrms::wm_id2name_(id = species$ValidAphiaID)
species_en <- worrms::wm_common_id_(id = species$ValidAphiaID)

dr_latin_aphia <-
  tibble::tibble(aphia = names(latin), latin = unlist(latin)) |>
  dplyr::left_join(species_en |>
                     filter(language == "English") |>
                     group_by(Valid_Aphia = id) |>
                     slice(1) |>
                     ungroup() |>
                     select(aphia = Valid_Aphia, species = vernacular),
                   by = dplyr::join_by(aphia)) |>
  dplyr::mutate(aphia = as.integer(aphia))

# add to package ---------------------------------------------------------------
# dr_latin_aphia <- dr_latin_aphia
usethis::use_data(dr_latin_aphia, overwrite = TRUE)

