# Valid_Aphia latin lookup

## get all combination of speccodetype, speccode and valid_aphia ---------------
species <-
  dplyr::bind_rows(
    duckdbfs::open_dataset("https://heima.hafro.is/~einarhj/datras/old/HL.parquet") |>
      dplyr::select(aphia = Valid_Aphia) |>
      dplyr::distinct() |>
      dplyr::collect(),
    duckdbfs::open_dataset("https://heima.hafro.is/~einarhj/datras/old/CA.parquet") |>
      dplyr::select(aphia = Valid_Aphia) |>
      dplyr::distinct() |>
      dplyr::collect()) |>
  dplyr::distinct() |>
  dplyr::mutate(aphia = as.integer(aphia))

latin <- worrms::wm_id2name_(id = species$aphia)
species_en <- worrms::wm_common_id_(id = species$aphia)

dr_lookup_species <-
  tibble::tibble(aphia = names(latin), latin = unlist(latin)) |>
  dplyr::mutate(aphia = as.integer(aphia)) |>
  dplyr::left_join(species_en |>
                     dplyr::filter(language == "English") |>
                     dplyr::group_by(aphia = id) |>
                     dplyr::slice(1) |>
                     dplyr::ungroup() |>
                     dplyr::select(aphia, species = vernacular) |>
                     dplyr::mutate(aphia = as.integer(aphia)),
                   by = dplyr::join_by(aphia))

# add to package ---------------------------------------------------------------
# dr_latin_aphia <- dr_latin_aphia
usethis::use_data(dr_lookup_species, overwrite = TRUE)

