# https://git-lfs.com
open_dataset("/home/hafri/einarhj/public_html/data/datras/HH.parquet") |>
  mutate(survey = paste0(Survey, "-", Quarter),
         .after = .id) |>
  write_dataset("inst/datras/HH.parquet")
