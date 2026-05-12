# Fetch DATRAS field specifications from the ICES web service and save as
# the dr_lookup_fields package data object.
#
# Run this script (source it or run interactively) to regenerate
# data/dr_lookup_fields.rda whenever the ICES field list changes or the
# hand-curated entries below need updating.

library(httr2)
library(xml2)
library(dplyr)
library(tidyr)
library(purrr)
library(stringr)
library(tibble)

url <- "https://datras.ices.dk/WebServices/DATRASWebService.asmx/getDatrasFieldList"

response <- request(url) |> req_perform()
if (resp_status(response) != 200)
  stop("Failed to fetch field list. Status: ", resp_status(response))

xml_data   <- resp_body_string(response)
parsed_xml <- suppressWarnings(read_xml(xml_data))
ns         <- c(d = "ices.dk.local/DATRAS")

dr_lookup_fields <-
  xml_find_all(parsed_xml, "//d:Cls_Datras_FieldList", ns = ns) |>
  map_df(~ tibble(
    table       = xml_text(xml_find_first(.x, "./d:RecordHeader", ns = ns)),
    new         = xml_text(xml_find_first(.x, "./d:FieldName",    ns = ns)),
    old         = xml_text(xml_find_first(.x, "./d:FieldNameOld", ns = ns)),
    format      = xml_text(xml_find_first(.x, "./d:DataFormat",   ns = ns)),
    description = xml_text(xml_find_first(.x, "./d:Description",  ns = ns))
  )) |>
  mutate(
    across(everything(), str_trim),
    old = if_else(old == "-", NA_character_, old),
    # Normalise ICES format codes to chr/int/dbl
    format = case_when(format == "char"    ~ "chr",
                       format == "decimal" ~ "dbl",
                       .default = format),
    # Year is always int; Distance is always dbl
    format = case_when(new == "Year"     ~ "int",
                       new == "Distance" ~ "dbl",
                       .default = format),
    # Ensure Survey has an old name
    old = case_when(new == "Survey" ~ "Survey",
                    .default = old),
    # Resolve known type ambiguities across record types (priority: chr > dbl > int)
    format = case_when(old == "Distance"    ~ "dbl",
                       old == "HaulNumber"  ~ "int",
                       old == "StationName" ~ "chr",
                       old == "CANoAtLngt"  ~ "dbl",
                       .default = format)
  )

# Hand-curated entries not covered by the ICES web service -----------------
# FL: columns returned by icesDatras::getFlexFile()
# LT: columns returned by icesDatras::getLTassessment() not in the web service
#     NOTE: the web service returns LT entries with new-style old values
#     (Platform, StationName, HaulNumber) that do NOT match actual getLTassessment()
#     column names (Ship, StNo, HaulNo) — those entries therefore don't fire in
#     dr_settypes(). The entries below cover what getLTassessment() actually returns.
# CPUEL/CPUEA/IDX: derived products from icesDatras; no web service coverage.
#     Age_0..Age_15 for CPUEA and IDX are added programmatically below.

add <- tribble(
  ~table,    ~new,                   ~old,              ~format,
  "FL",  "RecordHeader",         "RecordHeader",   "chr",
  "FL",  "Survey",               "Survey",         "chr",
  "FL",  "Quarter",              "Quarter",        "int",
  "FL",  "Country",              "Country",        "chr",
  "FL",  "Platform",             "Ship",           "chr",
  "FL",  "Gear",                 "Gear",           "chr",
  "FL",  "HaulNumber",           "HaulNo",         "int",
  "FL",  "Year",                 "Year",           "int",
  "FL",  "Month",                "Month",          "int",
  "FL",  "Day",                  "Day",            "int",
  "FL",  "StartTime",            "TimeShot",       "chr",
  "FL",  "DepthStratum",         "DepthStratum",   "chr",
  "FL",  "HaulDuration",         "HaulDur",        "int",
  "FL",  "DayNight",             "DayNight",       "chr",
  "FL",  "ShootLatitude",        "ShootLat",       "dbl",
  "FL",  "ShootLongitude",       "ShootLong",      "dbl",
  "FL",  "StatisticalRectangle", "StatRec",        "chr",
  "FL",  NA,                     "ICESArea",       "chr",
  "FL",  "SweepLength",          "SweepLngt",      "int",
  "FL",  "BottomDepth",          "Depth",          "int",
  "FL",  "HaulValidity",         "HaulVal",        "chr",
  "FL",  "DataType",             "DataType",       "chr",
  "FL",  "WarpLength",           "Warplngt",       "int",
  "FL",  "DoorSpread",           "DoorSpread",     "dbl",
  "FL",  "WingSpread",           "WingSpread",     "dbl",
  "FL",  "Distance",             "Distance",       "dbl",
  "FL",  NA,                     "Cal_DoorSpread", "dbl",
  "FL",  NA,                     "DSflag",         "chr",
  "FL",  NA,                     "Cal_WingSpread", "dbl",
  "FL",  NA,                     "WSflag",         "chr",
  "FL",  NA,                     "Cal_Distance",   "dbl",
  "FL",  NA,                     "DistanceFlag",   "chr",
  "FL",  NA,                     "SweptAreaDSKM2", "dbl",
  "FL",  NA,                     "SweptAreaWSKM2", "dbl",
  # LT
  "LT",  "BottomDepth",          "BottomDepth",       "int",
  "LT",  NA,                     "DateofCalculation", "int",
  "LT",  NA,                     "OSPARArea",         "chr",
  "LT",  NA,                     "MSFDArea",          "chr",
  "LT",  NA,                     "EEZ",               "chr",
  "LT",  NA,                     "NMArea",            "chr",
  # CPUEL: icesDatras::getCPUELength()
  "CPUEL", NA, "Survey",               "chr",
  "CPUEL", NA, "Year",                 "int",
  "CPUEL", NA, "Quarter",              "int",
  "CPUEL", NA, "Ship",                 "chr",
  "CPUEL", NA, "Gear",                 "chr",
  "CPUEL", NA, "HaulNo",               "int",
  "CPUEL", NA, "HaulDur",              "int",
  "CPUEL", NA, "ShootLat",             "dbl",
  "CPUEL", NA, "ShootLon",             "dbl",
  "CPUEL", NA, "DateTime",             "chr",
  "CPUEL", NA, "Depth",                "int",
  "CPUEL", NA, "Area",                 "int",
  "CPUEL", NA, "SubArea",              "chr",
  "CPUEL", NA, "DayNight",             "chr",
  "CPUEL", NA, "AphiaID",              "int",
  "CPUEL", NA, "Species",              "chr",
  "CPUEL", NA, "Sex",                  "chr",
  "CPUEL", NA, "LngtClas",             "int",
  "CPUEL", NA, "CPUE_number_per_hour", "dbl",
  "CPUEL", NA, "Cal_DateID",           "int",
  # CPUEA: icesDatras::getCPUEAge() — Age_* added below
  "CPUEA", NA, "Survey",    "chr",
  "CPUEA", NA, "Year",      "int",
  "CPUEA", NA, "Quarter",   "int",
  "CPUEA", NA, "Ship",      "chr",
  "CPUEA", NA, "Gear",      "chr",
  "CPUEA", NA, "HaulNo",    "int",
  "CPUEA", NA, "ShootLat",  "dbl",
  "CPUEA", NA, "ShootLon",  "dbl",
  "CPUEA", NA, "DateTime",  "chr",
  "CPUEA", NA, "Depth",     "int",
  "CPUEA", NA, "Area",      "int",
  "CPUEA", NA, "SubArea",   "chr",
  "CPUEA", NA, "DayNight",  "chr",
  "CPUEA", NA, "AphiaID",   "int",
  "CPUEA", NA, "Species",   "chr",
  "CPUEA", NA, "Sex",       "chr",
  "CPUEA", NA, "Cal_DateID","int",
  # IDX: icesDatras::getIndices() — Age_* added below; PlusGr renamed PlusGrAge
  "IDX", NA, "Survey",            "chr",
  "IDX", NA, "Year",              "int",
  "IDX", NA, "Quarter",           "int",
  "IDX", NA, "AphiaID",           "int",
  "IDX", NA, "Species",           "chr",
  "IDX", NA, "IndexArea",         "chr",
  "IDX", NA, "Sex",               "chr",
  "IDX", NA, "PlusGrAge",         "int",
  "IDX", NA, "DateofCalculation", "int"
)

# Age_0..Age_15: dbl for CPUEA and IDX
age_entries <- expand_grid(
  table = c("CPUEA", "IDX"),
  old   = paste0("Age_", 0:15)
) |>
  mutate(new = NA_character_, format = "dbl")

dr_lookup_fields <- bind_rows(dr_lookup_fields, add, age_entries)

# Fill missing `new` values in derived tables (CPUEL, CPUEA, IDX, LT) using
# the old→new mapping established for the source record types (HH, HL, CA).
# Columns unique to derived products (DateTime, CPUE_number_per_hour, etc.)
# have no HH/HL/CA counterpart and remain NA in `new`.
source_map <- dr_lookup_fields |>
  filter(table %in% c("HH", "HL", "CA"), !is.na(new), !is.na(old)) |>
  select(old, new) |>
  # Keep first match per old name — old names are consistent across HH/HL/CA
  distinct(old, .keep_all = TRUE)

dr_lookup_fields <- dr_lookup_fields |>
  left_join(source_map, by = "old", suffix = c("", "_fill")) |>
  mutate(new = coalesce(new, new_fill)) |>
  select(-new_fill)

usethis::use_data(dr_lookup_fields, overwrite = TRUE)
