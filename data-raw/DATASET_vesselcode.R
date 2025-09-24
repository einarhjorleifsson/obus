library(tidyverse)

## Vessel codes https://vocab.ices.dk/?ref=315 -------------------------------------------------

reco <-
  read.csv("data-raw/RECO_Export_09-26-2023-06-26-45.csv", colClasses = "character")  %>%
  dplyr::rename_all(tolower) %>%
  dplyr::select(
    code,
    vessel = description) %>%
  dplyr::mutate(
    vessel = ifelse(code=="29JR", "JOSE RIOJA", vessel)
  )
save(reco, file="data/reco.rda")
usethis::use_data(reco, overwrite=TRUE)

