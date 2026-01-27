library(tidyverse)
library(icesVocab)
devtools::load_all()

# use dictionary to filter out DATRAS variables and to add new variable name to
#  vocabulary
dictionary <-
  dr_con("dictionary") |>
  collect() |>
  distinct(old, .keep_all = TRUE) |>
  drop_na(old)

type <-
  icesVocab::getCodeTypeList() |>
  as_tibble() |>
  select(type = Key, type_desc = Description)
d <- map(type$type, icesVocab::getCodeList)
names(d) <- type$type
vocabulary <-
  d |>
  bind_rows(.id = "type") |>
  as_tibble() |>
  select(type, key = Key, description = Description) |>
  left_join(type) |>
  select(type, type_desc, everything()) |>
  mutate(variable = type,
         variable =
           case_when(str_starts(variable, "TS_") ~ str_remove(variable, "TS_"),
                     str_starts(variable, "AC_") ~ str_remove(variable, "AC_"),
                     .default = variable))
vocabulary |>
  select(variable, key, description, type, type_desc) |>
  filter(variable %in% dictionary$old) |>
  filter(!variable %in% c("Month", "Quarter", "Year")) |>
  rename(old = variable) |>
  left_join(dictionary |> select(old, new)) |>
  select(old, new, key, everything()) |>
  arrow::write_parquet("/home/hafri/einarhj/public_html/data/datras/vocabulary.parquet")
