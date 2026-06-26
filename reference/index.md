# Package index

## All functions

- [`.dr_cpue_by_haul()`](https://einarhjorleifsson.github.io/obus/reference/dot-dr_cpue_by_haul.md)
  : Haul-level catch totals (numbers and weights) from HH and HL
  exchange data

- [`.dr_cpue_by_length()`](https://einarhjorleifsson.github.io/obus/reference/dot-dr_cpue_by_length.md)
  : Calculate CPUE per length class from HH and HL exchange data

- [`.dr_download()`](https://einarhjorleifsson.github.io/obus/reference/dot-dr_download.md)
  : Download and process DATRAS data to parquet files

- [`.dr_row_classifier()`](https://einarhjorleifsson.github.io/obus/reference/dot-dr_row_classifier.md)
  : Row-Wise Value Classifier

- [`dr_add_date()`](https://einarhjorleifsson.github.io/obus/reference/dr_add_date.md)
  :

  Calculate date based on `Year`, `Month`, and `Day`.

- [`dr_add_id()`](https://einarhjorleifsson.github.io/obus/reference/dr_add_id.md)
  : Generate a unique haul id

- [`dr_add_length_cm()`](https://einarhjorleifsson.github.io/obus/reference/dr_add_length_cm.md)
  :

  Add a standardized `length_cm` column to the input table

- [`dr_add_length_mm()`](https://einarhjorleifsson.github.io/obus/reference/dr_add_length_mm.md)
  :

  Add a standardized `length_mm` column to the input table

- [`dr_add_n_and_cpue()`](https://einarhjorleifsson.github.io/obus/reference/dr_add_n_and_cpue.md)
  : Numbers caught and the CPUE in each length class

- [`dr_add_record_type()`](https://einarhjorleifsson.github.io/obus/reference/dr_add_record_type.md)
  : Classify HL records by measurement type

- [`dr_add_species()`](https://einarhjorleifsson.github.io/obus/reference/dr_add_species.md)
  : Add species names to a DATRAS table

- [`dr_add_starttime()`](https://einarhjorleifsson.github.io/obus/reference/dr_add_starttime.md)
  :

  Calculate timestamp based on `Year`, `Month`, `Day`, and
  `StartTime`/`TimeShot`.

- [`dr_assign_area()`](https://einarhjorleifsson.github.io/obus/reference/dr_assign_area.md)
  : Assign Survey Strata to Hauls by Position

- [`dr_check_all()`](https://einarhjorleifsson.github.io/obus/reference/dr_check_all.md)
  : Run all applicable QC checks and return a combined report

- [`dr_check_sentinels()`](https://einarhjorleifsson.github.io/obus/reference/dr_check_sentinels.md)
  : Check for -9 sentinel values remaining in numeric columns

- [`dr_check_subfactor()`](https://einarhjorleifsson.github.io/obus/reference/dr_check_subfactor.md)
  : Check SubsamplingFactor constraints against DataType

- [`dr_check_totalno()`](https://einarhjorleifsson.github.io/obus/reference/dr_check_totalno.md)
  : Check TotalNumber arithmetic against DataType rules

- [`dr_coastline`](https://einarhjorleifsson.github.io/obus/reference/dr_coastline.md)
  : Simple shoreline for ICES area

- [`dr_con()`](https://einarhjorleifsson.github.io/obus/reference/dr_con.md)
  : Connect to DATRAS Parquet Files

- [`dr_con2()`](https://einarhjorleifsson.github.io/obus/reference/dr_con2.md)
  : Connect to DATRAS Parquet Files

- [`dr_download()`](https://einarhjorleifsson.github.io/obus/reference/dr_download.md)
  : Download DATRAS parquet files

- [`dr_get()`](https://einarhjorleifsson.github.io/obus/reference/dr_get.md)
  : Download and Import DATRAS Data

- [`dr_get_areas()`](https://einarhjorleifsson.github.io/obus/reference/dr_get_areas.md)
  : Fetch DATRAS Survey Area Polygons

- [`dr_hl_haul()`](https://einarhjorleifsson.github.io/obus/reference/dr_hl_haul.md)
  : Haul-level catch totals (numbers and weights) from HH and HL
  exchange data

- [`dr_hl_length()`](https://einarhjorleifsson.github.io/obus/reference/dr_hl_length.md)
  : Zero-filled length-frequency CPUE table from HH and HL exchange data

- [`dr_lookup_areas`](https://einarhjorleifsson.github.io/obus/reference/dr_lookup_areas.md)
  : DATRAS Survey Area Polygons (Valid Strata)

- [`dr_lookup_fields`](https://einarhjorleifsson.github.io/obus/reference/dr_lookup_fields.md)
  : DATRAS field type lookup table

- [`dr_lookup_hl_record_type`](https://einarhjorleifsson.github.io/obus/reference/dr_lookup_hl_record_type.md)
  : HL record type lookup table

- [`dr_lookup_species`](https://einarhjorleifsson.github.io/obus/reference/dr_lookup_species.md)
  : A table of english and latin species names and aphia

- [`dr_lookup_vocabulary`](https://einarhjorleifsson.github.io/obus/reference/dr_lookup_vocabulary.md)
  : ICES vocabulary lookup table for DATRAS fields

- [`dr_settypes()`](https://einarhjorleifsson.github.io/obus/reference/dr_settypes.md)
  : Set column types from the dr_lookup_fields specification

- [`dr_translate()`](https://einarhjorleifsson.github.io/obus/reference/dr_translate.md)
  : Translate column names of a data.frame or lazy tibble using a
  dictionary

- [`getIndicesAllYears()`](https://einarhjorleifsson.github.io/obus/reference/getIndicesAllYears.md)
  : Get Survey Indices for All Years

- [`getIndicesAllYears2()`](https://einarhjorleifsson.github.io/obus/reference/getIndicesAllYears2.md)
  : Get Survey Indices for All Years
