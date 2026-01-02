icesVocab::getCodeList("SpecWoRMS") |>
  dplyr::select(Valid_Aphia = Key, latin = Description) |>
  dplyr::as_tibble() |>
  dplyr::mutate(Valid_Aphia = as.integer(Valid_Aphia)) |>
  readr::write_rds("garbage/species_worms.rds")
readr::read_rds("garbage/species_worms.rds") |>
  duckdbfs::write_dataset("/home/hafri/einarhj/public_html/datras/species_worms.parquet")
