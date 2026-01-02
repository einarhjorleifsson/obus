# Valid_Aphia latin lookup

## get all combination of speccodetype, speccode and valid_aphia ---------------
species <-
  dplyr::bind_rows(
    duckdbfs::open_dataset("/home/hafri/einarhj/public_html/datras/raw/RecordType=HL") |>
      dplyr::select(Valid_Aphia) |>
      dplyr::distinct() |>
      dplyr::collect(),
    duckdbfs::open_dataset("/home/hafri/einarhj/public_html/datras/raw/RecordType=HL") |>
      dplyr::select(Valid_Aphia) |>
      dplyr::distinct() |>
      dplyr::collect()) |>
  dplyr::distinct() |>
  dplyr::mutate(Valid_Aphia = as.integer(Valid_Aphia))

# get latin and english name ---------------------------------------------------
species <-
  dplyr::bind_rows(
    hl |>
      dplyr::select(Valid_Aphia) |>
      dplyr::distinct() |>
      dplyr::collect(),
    ca |>
      dplyr::select(Valid_Aphia) |>
      dplyr::distinct() |>
      dplyr::collect()) |>
  dplyr::distinct() |>
  dplyr::mutate(Valid_Aphia = as.integer(Valid_Aphia))

latin <- worrms::wm_id2name_(id = species$Valid_Aphia)
species_en <- worrms::wm_common_id_(id = species$Valid_Aphia)

dr_latin_aphia <-
  tibble::tibble(Valid_Aphia = names(latin), latin = unlist(latin)) |>
  dplyr::left_join(species_en |>
                     filter(language == "English") |>
                     group_by(Valid_Aphia = id) |>
                     slice(1) |>
                     ungroup() |>
                     select(Valid_Aphia, species = vernacular),
                   by = dplyr::join_by(Valid_Aphia)) |>
  dplyr::mutate(Valid_Aphia = as.integer(Valid_Aphia))

# add to package ---------------------------------------------------------------
usethis::use_data(dr_latin_aphia)
