# Package index

## All functions

- [`.dr_download()`](dot-dr_download.md) : Download and process DATRAS
  data to parquet files

- [`.dr_row_classifier()`](dot-dr_row_classifier.md) : Row-Wise Value
  Classifier

- [`dr_add_date()`](dr_add_date.md) :

  Calculate date based on `Year`, `Month`, and `Day`.

- [`dr_add_id()`](dr_add_id.md) : Generate a unique haul id

- [`dr_add_length_cm()`](dr_add_length_cm.md) :

  Add a standardized `length_cm` column to the input table

- [`dr_add_length_mm()`](dr_add_length_mm.md) :

  Add a standardized `length_mm` column to the input table

- [`dr_add_n_and_cpue()`](dr_add_n_and_cpue.md) : Numbers caught and the
  CPUE in each length class

- [`dr_add_record_type()`](dr_add_record_type.md) : Classify HL records
  by measurement type

- [`dr_add_starttime()`](dr_add_starttime.md) :

  Calculate timestamp based on `Year`, `Month`, `Day`, and
  `StartTime`/`TimeShot`.

- [`dr_check_all()`](dr_check_all.md) : Run all applicable QC checks and
  return a combined report

- [`dr_check_sentinels()`](dr_check_sentinels.md) : Check for -9
  sentinel values remaining in numeric columns

- [`dr_check_subfactor()`](dr_check_subfactor.md) : Check
  SubsamplingFactor constraints against DataType

- [`dr_check_totalno()`](dr_check_totalno.md) : Check TotalNumber
  arithmetic against DataType rules

- [`dr_coastline`](dr_coastline.md) : Simple shoreline for ICES area

- [`dr_con()`](dr_con.md) : Establish a DuckDB Connection to DATRAS
  Datasets

- [`dr_con_raw()`](dr_con_raw.md) : Connect to Raw ICES DATRAS Tables

- [`dr_cpue_by_haul()`](dr_cpue_by_haul.md) : Haul-level catch totals
  (numbers and weights) from HH and HL exchange data

- [`dr_cpue_by_length()`](dr_cpue_by_length.md) : Calculate CPUE per
  length class from HH and HL exchange data

- [`dr_download()`](dr_download.md) : Download DATRAS parquet files

- [`dr_get()`](dr_get.md) : Download and Import DATRAS Data

- [`dr_lookup_fields`](dr_lookup_fields.md) : DATRAS field type lookup
  table

- [`dr_lookup_species`](dr_lookup_species.md) : A table of english and
  latin species names and aphia

- [`dr_lookup_vocabulary`](dr_lookup_vocabulary.md) : ICES vocabulary
  lookup table for DATRAS fields

- [`dr_settypes()`](dr_settypes.md) : Set column types from the
  dr_lookup_fields specification

- [`dr_translate()`](dr_translate.md) : Translate column names of a
  data.frame or lazy tibble using a dictionary

- [`getIndicesAllYears()`](getIndicesAllYears.md) : Get Survey Indices
  for All Years

- [`getIndicesAllYears2()`](getIndicesAllYears2.md) : Get Survey Indices
  for All Years

- [`hl_record_type_lookup`](hl_record_type_lookup.md) : Lookup table for
  HL record types
