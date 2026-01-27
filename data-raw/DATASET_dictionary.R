# Here an attempt is made to gather various information related to variables
#  1. Get the full icesVocab
#  2. Mapping of old and new variable names
#. 3. Set variable position for all DATRAS tables - matters for some import functions
#. 4. Identification of variable type/class
#. 5. Description of each variable, some are conditional on other variables

library(tidyverse)
library(readxl)
# library(icesVocab)
devtools::load_all()

# A Mapping of variables -------------------------------------------------------
# Here only map the old to new
## 1. Existing mapping of old and new variable names ---------------------------
#    Note the file below has incomplete list of variables compared with what
#    is returned above
fil <- "data-raw/DATRAS_NewHeaders_Lookup_Dec2024.xlsx"
ices_map <-
  map2(fil, excel_sheets(fil), read_excel) |>
  bind_rows() |>
  select(recordtype = RecordHeader,
         new = FieldName,
         old = FieldNameOld,
         status = FieldComparisonStatus) |>
  # May want to discuss this with Vaishav
  mutate(old = case_when(old == "RecordHeader" ~ "RecordType",
                         old == "-" & new == "Survey" ~ "Survey",
                         is.na(old) & new == "Survey" ~ "Survey",
                         # This may create trouble in joins:
                         old == "-" & new == "EDMO" ~ NA,
                         .default = old)) |>
  filter(recordtype %in% c("HH", "HL", "CA"))

## 2. Get the order of the field names ------------------------------------------
#    This matters in some cases like type arguments when importing (some methods)
# Issues: old "RecordType", new "RecordHeader"
lh <- function(type = "HH") {
  icesDatras::getDATRAS(type, "NS-IBTS", 2025, 1) |> colnames()
}
old <-
  bind_rows(tibble(recordtype = "HH", old = lh("HH")),
            tibble(recordtype = "HL", old = lh("HL")),
            tibble(recordtype = "CA", old = lh("CA"))) |>
  group_by(recordtype) |>
  mutate(old_order = 1:n()) |>
  ungroup()
lh <- function(type = "HH") {
  dr_con(type, trim = FALSE) |> colnames()
}
new <-
  bind_rows(tibble(recordtype = "HH", new = lh("HH")),
            tibble(recordtype = "HL", new = lh("HL")),
            tibble(recordtype = "CA", new = lh("CA"))) |>
  group_by(recordtype) |>
  mutate(new_order = 1:n()) |>
  ungroup()

## 3. merge --------------------------------------------------------------------
map_old_to_new <-
  old |>
  # filter(recordtype %in% c("HH", "HL", "CA")) |>
  left_join(ices_map |> select(-status),
            by = join_by(recordtype, old)) |>
  mutate(new = case_when(is.na(new) & old == "DateofCalculation" ~ "DateofCalculation",
                         is.na(new) & old == "Valid_Aphia" ~ "Valid_Aphia",
                         recordtype == "CA" & old == "Age" ~ "IndividualAge",
                         .default = new))
## 4. add field/variable types and descriptions
fil <- "data-raw/DATRAS_Field_descriptions_and_example_file_December2025.xlsx"
ices_fields <-
  bind_rows(
    read_excel(fil, sheet = 2) |> select(new = Field, type = DataType, description = Description) |> mutate(recordtype = "HH"),
    read_excel(fil, sheet = 3) |> select(new = Field, type = DataType, description = Description) |> mutate(recordtype = "HL"),
    read_excel(fil, sheet = 4) |> select(new = Field, type = DataType, description = 7)  |> mutate(recordtype = "CA"))

dictionary <-
  map_old_to_new |>
  full_join(ices_fields,
            by = join_by(recordtype, new)) |>
  mutate(type = case_when(is.na(type) & new == "DateofCalculation" ~ "int",
                          is.na(type) & new == "Valid_Aphia" ~ "int",
                          .default = type))

dictionary |>
  nanoparquet::write_parquet("/home/hafri/einarhj/public_html/data/datras/dictionary.parquet")
