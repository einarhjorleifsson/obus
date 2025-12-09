# https://git-lfs.com
open_dataset("/home/hafri/einarhj/public_html/datras_latin/HH.parquet") |>
  mutate(survey = paste0(Survey, "-", Quarter),
         .after = .id) |>
  write_dataset("inst/datras/HH.parquet")
