library(tidyverse)
library(obus)
cn_hh <- dr_con("HH") |> colnames() |> as_tibble()
cn_hl <- dr_con("HL") |> colnames() |> as_tibble()
cn_ca <- dr_con("CA") |> colnames() |> as_tibble()
cn <-
  bind_rows(cn_hh |> mutate(table = "hh"),
            cn_hl |> mutate(table = "hl"),
            cn_ca |> mutate(table = "ca")) |>
  rename(cn = value)

library(tidyverse)
library(icesVocab)

type_list <-
  icesVocab::getCodeTypeList() |>
  as_tibble() |>
  select(type = Key, type_desc = Description) |>
  filter(str_starts(type, "TS_"))

d <-
  map(type_list$type, icesVocab::getCodeList)
names(d) <- type_list$type
ices_code_list <-
  bind_rows(d, .id = "type") |>
  as_tibble() |>
  select(type, Key, Description, LongDescription) |>
  left_join(type_list) |>
  select(type, type_desc, everything())
ices_vocabulary <-
  cn |>
  mutate(type = paste0("TS_", cn)) |>
  left_join(ices_code_list)
colnames(ices_vocabulary) <- tolower(colnames(ices_vocabulary))

ices_vocabulary |>
  filter(cn == "DataType") |>
  select(key, description) |>
  knitr::kable()
ices_vocabulary |>
  filter(cn == "SpecVal") |>
  select(key, description) |>
  knitr::kable()
