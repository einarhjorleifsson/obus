# Fetch DATRAS field specifications from the ICES web service and save as
# the dr_lookup_fields package data object.
#
# Run this script (source it or run interactively) to regenerate
# data/dr_lookup_fields.rda whenever the ICES field list changes or the
# hand-curated entries below need updating.
#

library(httr2)
library(xml2)
library(dplyr)
library(tidyr)
library(purrr)
library(stringr)
library(tibble)


# HH, HL, CA, FA and LT --------------------------------------------------------
url <- "https://datras.ices.dk/WebServices/DATRASWebService.asmx/getDatrasFieldList"

response <- request(url) |> req_perform()
if (resp_status(response) != 200)
  stop("Failed to fetch field list. Status: ", resp_status(response))

xml_data   <- resp_body_string(response)
parsed_xml <- suppressWarnings(read_xml(xml_data))
ns         <- c(d = "ices.dk.local/DATRAS")

fields <-
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
    # old = if_else(old == "-", NA_character_, old),
    # Normalise ICES format codes to chr/int/dbl
    format = case_when(format == "char"    ~ "chr",
                       format == "decimal" ~ "dbl",
                       .default = format)) |>
  # only a partial list for LT, full list generated below
  filter(table != "LT")

# Correction -------------------------------------------------------------------
fields <- fields |>
  mutate(
    # Year is set as character - for downstream analysis this should be integer
    format = case_when(new == "Year" ~ "int",
    # float should be dbl
                       format == "float" ~ "dbl",
    # make CA new "NumberAtLength" as "dbl", no harm, avoids ambiguity with HL
                       table == "CA" & new == "NumberAtLength" ~ "dbl",
                       table == "FA" & new == "HaulNumber" ~ "int",
                       table == "FA" & new == "StationName" ~ "chr",
                       .default = format),
    # wrong or no description
    description = case_when(table == "FA" & new == "Year" ~ "Cruise year (YYYY)",
                            table == "FA" & new == "HaulNumber" ~ "Sequential numbering of hauls during cruise.",
                            table == "FA" & new == "StationName" ~ "Station number. National coding system, not defined by ICES.",
                            table == "LT" & new == "HaulNumber" ~ "Sequential numbering of hauls during cruise.",
                            table == "LT" & new == "StationName" ~ "Station number. National coding system, not defined by ICES.",
                            table %in% c("CA", "HH", "HL", "LT") & new == "Survey" ~ "Survey code as used in ICES products, see https://vocab.ices.dk/?codetypeguid=016362a4-90be-424b-af01-a37ae58ca023",
                            .default = description),
    # Use lowercase "sex" across HL and CA — a deliberate deviation from the PascalCase convention
    # used elsewhere. HL calls this "SpeciesSex" and CA calls it "IndividualSex" in the ICES field
    # list; these are the same concept with the same vocabulary. "sex" is a temporary canonical name
    # until the ICES Datacenter / DATRAS team resolve the inconsistency in the upstream field list.
    new = case_when(table == "CA" & old == "Sex" & new == "IndividualSex" ~ "sex",
                    table == "HL" & old == "Sex" & new == "SpeciesSex" ~ "sex",
                    # getDatrasFieldList has IndividualAge - see also below for old
                    table == "CA" & new == "IndividualAge" ~ "Age",
                    .default = new),
    old = case_when(table %in% c("CA", "HH", "HL") & new == "Survey" & is.na(old) ~ "Survey",
                    # getDatrasFieldList has AgeRings while icesDatras::getDATRAS returns Age
                    table == "CA" & old == "AgeRings" ~ "Age",
                    .default = old))

# NOTE: The Valid_Aphia or some form of it are not part of the formal
#       field list obtained above Think this is because list is limited to
#       uploading requirements.
#       When user however request e.g. HL and CA from the database, the user
#       gets Valid_Aphia. Guess that is datacenter checked value for
#       what is uploaded as SpeciesCode
#       The issue here is that while HL and CA passes variable name Valid_Aphia
#       the products (cpue by length or age and the indices) return AphiaID
#       Decision: Use "aphia" as the "new" variable within this project.
add <-
  tribble(~table, ~new, ~old, ~format,
          "HL", "aphia", "Valid_Aphia", "int",
          "CA", "aphia", "Valid_Aphia", "int",
          "HH", "DateofCalculation", "DateofCalculation", "int",
          "HL", "DateofCalculation", "DateofCalculation", "int",
          "CA", "DateofCalculation", "DateofCalculation", "int")
fields <- fields |>
  bind_rows(add)

## Hand-curated entries not covered by the ICES web service --------------------
#   ... because these are product tables??
# FL: columns returned by icesDatras::getFlexFile()
# LT: columns returned by icesDatras::getLTassessment() not in the web service
#     NOTE: the web service returns LT entries with new-style old values
#     (Platform, StationName, HaulNumber) that do NOT match actual getLTassessment()
#     column names (Ship, StNo, HaulNo) — those entries therefore don't fire in
#     dr_settypes(). The entries below cover what getLTassessment() actually returns.
# CPUEL/CPUEA/IDX: derived products from icesDatras; no web service coverage.
#     Age_0..Age_15 for CPUEA and IDX are added programmatically below.


# Note: the "RecordType" is actually stated as HH in
add_fl <- tribble(
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
  "FL",  "ICESArea",             "ICESArea",       "chr",
  "FL",  "SweepLength",          "SweepLngt",      "int",
  "FL",  "BottomDepth",          "Depth",          "int",
  "FL",  "HaulValidity",         "HaulVal",        "chr",
  "FL",  "DataType",             "DataType",       "chr",
  "FL",  "WarpLength",           "Warplngt",       "int",
  "FL",  "DoorSpread",           "DoorSpread",     "dbl",
  "FL",  "WingSpread",           "WingSpread",     "dbl",
  "FL",  "Distance",             "Distance",       "dbl",
  "FL",  "Cal_DoorSpread",       "Cal_DoorSpread", "dbl",
  "FL",  "DSflag",               "DSflag",         "chr",
  "FL",  "Cal_WingSpread",       "Cal_WingSpread", "dbl",
  "FL",  "WSflag",               "WSflag",         "chr",
  "FL",  "Cal_Distance",         "Cal_Distance",   "dbl",
  "FL",  "DistanceFlag",         "DistanceFlag",   "chr",
  "FL",  "SweptAreaDSKM2",       "SweptAreaDSKM2", "dbl",
  "FL",  "SweptAreaWSKM2",       "SweptAreaWSKM2", "dbl",
  "FL",  "DateofCalculation",    "DateofCalculation", "int")

add_lt <- tribble(
  ~table,    ~new,                   ~old,              ~format,
  "LT",  "Survey",               "Survey",         "chr",
  "LT",  "Quarter",              "Quarter",        "int",
  "LT",  "Platform",             "Ship",           "chr",
  "LT",  "Gear",                 "Gear",           "chr",
  "LT",  "Country",              "Country",        "chr",
  "LT",  "StationName",          "StNo",           "chr",
  "LT",  "HaulNumber",           "HaulNo",         "int",
  "LT",  "ShootLatitude",        "ShootLat",       "dbl",
  "LT",  "ShootLongitude",       "ShootLong",      "dbl",
  "LT",  "HaulLatitude",         "HaulLat",        "dbl",
  "LT",  "HaulLongitude",        "HaulLong",       "dbl",
  "LT",  "OSPARArea",            "OSPARArea",      "chr",
  "LT",  "MSFDArea",             "MSFDArea",       "chr",
  # icesDatras::getLTassessment() returns both "BottomDepth" and "Depth" raw
  # columns, byte-for-byte identical (confirmed empirically); ICES's own field
  # list has no LT depth field at all and lists "Depth" only as the legacy
  # name for HH's "BottomDepth". Map only "BottomDepth" here; leave "Depth"
  # unmapped (dr_translate() then leaves it untouched, harmless duplicate) --
  # do NOT also map "Depth" -> "BottomDepth", that collides at rename time.
  "LT",  "BottomDepth",          "BottomDepth",    "int",
  "LT",  "Distance",             "Distance",       "dbl",
  "LT",  "DoorSpread",           "DoorSpread",     "dbl",
  "LT",  "WingSpread",           "WingSpread",     "dbl",
  "LT",  "LTREF",     "LTREF", "chr",
  "LT",  "PARAM",     "PARAM", "chr",
  "LT",  "LTSZC",     "LTSZC", "chr",
  "LT",  "UnitWgt",   "UnitWgt", "chr",
  "LT",  "LT_Weight", "LT_Weight", "dbl",
  "LT",  "UnitItem", "UnitItem", "chr",
  "LT",  "LT_Items", "LT_Items", "int",
  "LT",  "LTSRC",    "LTSRC", "chr",
  "LT",  "TYPPL",    "TYPPL", "chr",
  "LT",  "LTPRP",    "LTPRP", "chr",
  "LT",  "SweepLength",          "SweepLngt",      "int",
  "LT",  "GearEx",               "GearEx",         "chr",
  "LT",  "DoorType", "DoorType", "chr",
  "LT",  "Month",                "Month",          "int",
  "LT",  "Day",                  "Day",            "int",
  "LT",  "StartTime",            "TimeShot",       "chr",
  "LT",  "HaulDuration",         "HaulDur",        "int",
  "LT",  "StatisticalRectangle", "StatRec",        "chr",
  "LT",  "HaulValidity",         "HaulVal",        "chr",
  "LT",  "DataType",             "DataType",       "chr",
  "LT",  "NetOpening",           "Netopening",     "dbl",
  "LT",  "Rigging",              "Rigging",        "chr",
  "LT",  "Tickler",              "Tickler",        "int",
  "LT",  "WarpLength",           "Warplngt",       "int",
  "LT",  "WarpDiameter",         "Warpdia",        "int",
  "LT",  "WarpDensity",          "WarpDen",        "int",
  "LT",  "DoorSurface",          "DoorSurface",    "dbl",
  "LT",  "DoorWeight",           "DoorWgt",        "int",
  "LT",  "TowDirection",         "TowDir",         "int",
  "LT",  "SpeedGround",          "GroundSpeed",    "dbl",
  "LT",  "SpeedWater",           "SpeedWater",     "dbl",
  "LT",  "WindDirection",        "WindDir",        "int",
  "LT",  "WindSpeed",            "WindSpeed",      "int",
  "LT",  "SwellDirection",       "SwellDir",       "int",
  "LT",  "SwellHeight",          "SwellHeight",    "dbl",
  "LT",  "CodendMesh",           "CodendMesh",     "int",
  "LT",  "EEZ",                  "EEZ",            "chr",
  "LT",  "NMArea",               "NMArea",         "chr",
  "LT",  "DateofCalculation",    "DateofCalculation", "int",
  "LT",  "Year",                 "Year",              "int")



add_cpue_length <- tribble(
  ~table,    ~new,                   ~old,              ~format,
  "CPUEL", "Survey", "Survey",               "chr",
  "CPUEL", "Year", "Year",                 "int",
  "CPUEL", "Quarter", "Quarter",              "int",
  "CPUEL", "Platform", "Ship",                 "chr",
  "CPUEL", "Gear", "Gear",                 "chr",
  "CPUEL", "HaulNumber", "HaulNo",               "int",
  "CPUEL", "HaulDuration", "HaulDur",              "int",
  "CPUEL", "ShootLatitude",  "ShootLat",             "dbl",
  "CPUEL", "ShootLongitude", "ShootLon",             "dbl",
  "CPUEL", "DateTime", "DateTime",             "chr",          # this should then be set as dttm
  "CPUEL", "BottomDepth", "Depth",                "int",
  "CPUEL", "Area", "Area",                 "int",
  "CPUEL", "SubArea", "SubArea",              "chr",
  "CPUEL", "DayNight", "DayNight",             "chr",
  "CPUEL", "aphia", "AphiaID",              "int",
  "CPUEL", "Species", "Species",              "chr",
  "CPUEL", "sex",        "Sex",                  "chr",        # lowercase "sex" — see note above
  "CPUEL", "length_mm", "LngtClas",             "int",
  "CPUEL", "n_hour", "CPUE_number_per_hour", "dbl",
  "CPUEL", "DateofCalculation", "Cal_DateID",           "int")

add_cpuea <- tribble(
  ~table,    ~new,                   ~old,              ~format,
  "CPUEA", NA, "Survey",    "chr",
  "CPUEA", NA, "Year",      "int",
  "CPUEA", NA, "Quarter",   "int",
  "CPUEA", NA, "Ship",      "chr",
  "CPUEA", NA, "Gear",      "chr",
  "CPUEA", NA, "HaulNo",    "int",
  "CPUEA", "ShootLatitude",  "ShootLat",  "dbl",
  "CPUEA", "ShootLongitude", "ShootLon",  "dbl",
  "CPUEA", NA, "DateTime",  "chr",
  "CPUEA", NA, "Depth",     "int",
  "CPUEA", NA, "Area",      "int",
  "CPUEA", NA, "SubArea",   "chr",
  "CPUEA", NA, "DayNight",  "chr",
  "CPUEA", "aphia", "AphiaID",   "int",
  "CPUEA", NA, "Species",   "chr",
  "CPUEA", "sex",  "Sex",   "chr",
  "CPUEA", "DateofCalculation", "Cal_DateID","int")

add_index <- tribble(
  ~table,    ~new,                   ~old,              ~format,
  "IDX", NA, "Survey",            "chr",
  "IDX", NA, "Year",              "int",
  "IDX", NA, "Quarter",           "int",
  "IDX", "aphia", "AphiaID",           "int",
  "IDX", NA, "Species",           "chr",
  "IDX", NA, "IndexArea",         "chr",
  "IDX", "sex", "Sex",            "chr",
  "IDX", NA, "PlusGrAge",         "int",
  "IDX", NA, "DateofCalculation", "int"
)



# Age_0..Age_15: dbl for CPUEA and IDX
age_entries <- expand_grid(
  table = c("CPUEA", "IDX"),
  old   = paste0("Age_", 0:15)
) |>
  mutate(new = NA_character_, format = "dbl")

dictionary <- bind_rows(fields, add, add_fl, add_lt, add_cpue_length, add_cpuea, add_index, age_entries)

# Fill missing `new` values in derived tables (CPUEL, CPUEA, IDX, LT) using
# the old→new mapping established for the source record types (HH, HL, CA).
# Columns unique to derived products (DateTime, CPUE_number_per_hour, etc.)
# have no HH/HL/CA counterpart and remain NA in `new`.
source_map <- dictionary |>
  filter(table %in% c("HH", "HL", "CA"), !is.na(new), !is.na(old)) |>
  select(old, new) |>
  # Keep first match per old name — old names are consistent across HH/HL/CA
  distinct(old, .keep_all = TRUE)

dictionary <- dictionary |>
  left_join(source_map, by = "old", suffix = c("", "_fill")) |>
  mutate(new = coalesce(new, new_fill)) |>
  select(-new_fill)

# Hand-curated improved descriptions -------------------------------------------
# description_new: what the field IS and how to use it.
# Code values belong in dr_lookup_vocabulary, not here.
description_new_tbl <- tribble(
  ~table, ~new,                  ~description_new,

  # HH ---
  "HH", "HaulValidity",
    "Validity assessment for the haul. Filter to valid hauls before computing abundance indices.",

  "HH", "DataType",
    "Governs how NumberAtLength, TotalNumber, and SpeciesCategoryWeight in HL must be interpreted. The most common source of silent errors in user code. Must be joined from HH before any HL arithmetic.",

  "HH", "StandardSpeciesCode",
    "Recording tier for the standard species list applied at this haul. Determines which hauls are valid for a given species abundance index; hauls below the required tier must be excluded before zero-filling. Survey-specific; see survey manuals.",

  "HH", "BycatchSpeciesCode",
    "Recording tier for bycatch species at this haul. Paired with StandardSpeciesCode to assess whether a species absence reflects true absence or incomplete protocol coverage. Survey-specific; see survey manuals.",

  # HL ---
  "HL", "SpeciesValidity",
    "Record type indicating what was measured for this species/haul group. Governs which rows to include in derived products; standard products retain only the primary full-record type.",

  "HL", "SpeciesCategory",
    "Size-based subsampling stratum identifier for a species/sex group within a haul. Used when catch is split into size grades with different SubsamplingFactor per stratum. Part of the HL grouping key (.id x aphia x sex x DevelopmentStage x SpeciesCategory).",

  "HL", "SubsamplingFactor",
    "Raise factor for the measured sub-sample. Multiply NumberAtLength by SubsamplingFactor to estimate total catch at that length class. May vary between size strata within the same species/haul group when size-stratified subsampling is applied.",

  "HL", "TotalNumber",
    "Total catch count for the species/sex/SpeciesCategory group. Repeated identically across every length row within the same group - deduplicate before summing. Semantics (per haul vs. per hour) depend on DataType. When size-stratified subsampling is used, reflects the stratum total, not the species-haul total.",

  "HL", "sex",
    "Sex of the measured specimens, determined by visual bulk-catch examination (not dissection; dissection applies in CA). Part of the HL grouping key (.id x aphia x sex x DevelopmentStage x SpeciesCategory). For sexually dimorphic species, males and females appear in separate rows.",

  "HL", "DevelopmentStage",
    "Developmental or maturity stage assessed by external observation. Rarely populated; most rows are NA. Part of the HL grouping key (.id x aphia x sex x DevelopmentStage x SpeciesCategory) when present."
)

dictionary <- dictionary |>
  left_join(description_new_tbl, by = c("table", "new"))

dr_lookup_fields <- dictionary
usethis::use_data(dr_lookup_fields, overwrite = TRUE)

