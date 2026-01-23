library(tidyverse)



fil <- "https://www.ices.dk/data/Documents/DATRAS/Survey_DatrasDatasetVersion_Equivalences.xlsx"
download.file(fil, destfile = "data-raw/Survey_DatrasDatasetVersion_Equivalences.xlsx")
fil <- "https://www.ices.dk/data/Documents/DATRAS/DATRAS_NewHeaders_Lookup_Dec2024.xlsx"
download.file(fil, destfile = "data-raw/DATRAS_NewHeaders_Lookup_Dec2024.xlsx")
library(readxl)

fil <- "data-raw/DATRAS_NewHeaders_Lookup_Dec2024.xlsx"
sheets <- excel_sheets(fil)
res <- map2(fil, sheets, read_excel)
variables <-
  bind_rows(res) |>
  select(recordtype = RecordHeader,
         new = FieldName,
         old = FieldNameOld,
         status = FieldComparisonStatus)
type <-
  variables |>
  select(new, old) |>
  distinct()
lh <- function(recordtype = "HH") {
  x <- icesDatras:::.datras_column_classes(recordtype)
  bind_rows(tibble(new = unlist(x$character)) |> mutate(type = "character"),
            tibble(new = unlist(x$integer)) |> mutate(type = "integer"),
            tibble(new = unlist(x$numeric)) |> mutate(type = "numeric")) |>
    mutate(recordtype = recordtype)
}
type <- bind_rows(lh("HH"), lh("HL"), lh("CA"))
type |> distinct(new, type, .keep_all = TRUE) |> group_by(new) |> mutate(n = n()) |> ungroup() |> filter(n > 1)
variables <- variables |> left_join(type) |> filter(type != "FL")
lookup_table <- variables

hh_order <-
  tibble(new =
           c("RecordHeader", "Survey", "Quarter", "Country", "Platform",
             "Gear", "SweepLength", "GearExceptions", "DoorType", "StationName",
             "HaulNumber", "Year", "Month", "Day", "StartTime", "DepthStratum",
             "HaulDuration", "DayNight", "ShootLatitude", "ShootLongitude",
             "HaulLatitude", "HaulLongitude", "StatisticalRectangle", "BottomDepth",
             "HaulValidity", "HydrographicStationID", "StandardSpeciesCode",
             "BycatchSpeciesCode", "DataType", "NetOpening", "Rigging", "Tickler",
             "Distance", "WarpLength", "WarpDiameter", "WarpDensity", "DoorSurface",
             "DoorWeight", "DoorSpread", "WingSpread", "Buoyancy", "KiteArea",
             "GroundRopeWeight", "TowDirection", "SpeedGround", "SpeedWater",
             "SurfaceCurrentDirection", "SurfaceCurrentSpeed", "BottomCurrentDirection",
             "BottomCurrentSpeed", "WindDirection", "WindSpeed", "SwellDirection",
             "SwellHeight", "SurfaceTemperature", "BottomTemperature", "SurfaceSalinity",
             "BottomSalinity", "ThermoCline", "ThermoClineDepth", "CodendMesh",
             "SecchiDepth", "Turbidity", "TidePhase", "TideSpeed", "PelagicSamplingType",
             "MinTrawlDepth", "MaxTrawlDepth", "SurveyIndexArea", "EDOM",
             "ReasonHaulDisruption", "DateofCalculation"))
hh_order |>
  left_join(variables |> filter(recordtype == "HH"))

dr_con("HL", trim = FALSE) |>
  select(NumberAtLength) |>
  collect() |>
  mutate(n = as.integer(NumberAtLength)) |>
  filter(is.na(n) & !is.na(NumberAtLength))





# column class -----------------------------------------------------------------
url <- "https://www.ices.dk/data/Documents/DATRAS/DATRAS_Field_descriptions_and_example_file_May2022.xlsx"
tmp <- tempfile()
utils::download.file(url, destfile = tmp)

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
