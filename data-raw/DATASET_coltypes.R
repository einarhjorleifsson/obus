library(tidyverse)

# column class -----------------------------------------------------------------
url <- "https://www.ices.dk/data/Documents/DATRAS/DATRAS_Field_descriptions_and_example_file_May2022.xlsx"
tmp <- tempfile()
download.file(url, destfile = tmp)

hh <-
  readxl::read_excel(path  = tmp, sheet = "HH") |>
  mutate(DataType = ifelse(Field == "Year", "int", DataType))
hl <-
  readxl::read_excel(path  = tmp, sheet = "HL") |>
  mutate(DataType = ifelse(Field == "Year", "int", DataType))
ca <-
  readxl::read_excel(path  = tmp, sheet = "CA") |>
  mutate(DataType = ifelse(Field == "Year", "int", DataType))


dr_coltypes <-
  bind_rows(hh |> select(Field, DataType) |>   mutate(record = "HH"),
            hl |> select(Field, DataType) |>   mutate(record = "HL"),
            ca |> select(Field, DataType) |>   mutate(record = "CA")) |>
  rename(field = Field,
         type = DataType) |>
  distinct() |>
  mutate(type = case_when(type == "char" ~ "chr",
                          str_starts(type, "dec") ~ "dbl",
                          .default = type))

flex <-
  icesDatras::getFlexFile(survey = "NS-IBTS",
                          year = 2020,
                          quarter = 1)
fl <-
  tibble(field = names(flex)) |>
  left_join(dr_coltypes |> select(field, type) |> distinct()) |>
  mutate(
    type =
      case_when(
        !is.na(type) ~ type,
                          field == "Survey" ~ "chr",
                          field == "ICESArea" ~ "chr",
                          field == "Cal_DoorSpread" ~ "dbl",
                          field == "DSflag" ~ "chr",          # likely integer (0 or 1)
                          field == "Cal_WingSpread" ~ "dbl",
                          field == "WSflag" ~ "chr",          # likely integer (0 or 1)
                          field == "Cal_Distance" ~ "dbl",
                          field == "DistanceFlag" ~ "chr",    # likely integer (0 or 1)
                          field == "SweptAreaDSKM2" ~ "dbl",
                          field == "SweptAreaWSKM2" ~ "dbl",
                          .default = "Something else"),
    record = "FL")

dr_coltypes <-
  bind_rows(dr_coltypes,
            fl)

usethis::use_data(dr_coltypes, overwrite = TRUE)
