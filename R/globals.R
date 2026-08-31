# Column names used unquoted inside dplyr verbs. Declared so `R CMD check`
# does not report them as undefined globals -- they are data columns, not
# objects, and are resolved by dplyr's data mask (or by dbplyr's SQL
# translation) at call time.
utils::globalVariables(c(
  # haul key
  ".id", "Survey", "Year", "Quarter", "Country", "Platform", "Gear",
  "StationName", "HaulNumber",
  # HH
  "HaulValidity", "DataType", "HaulDuration",
  # HL
  "aphia", "sex", "SpeciesValidity", "SpeciesCategory", "TotalNumber",
  "SpeciesCategoryWeight", "SubsamplingFactor", "NumberAtLength",
  "LengthCode", "LengthClass", "LengthType", "DevelopmentStage",
  # species lookup
  "latin", "species", "rank",
  # derived
  "length_mm", "length_cm", "accuracy", "n_haul", "n_hour",
  "n_haul_raw", "n_hour_raw", "w_haul", "w_hour", "w_haul_raw", "w_hour_raw",
  "n_totalnumber", "n_totalnumber_hour", ".n_ok", ".h_ok", ".w_ok", ".wh_ok", ".n_raw", ".h_raw",
  "raised", "sex_expected", "reconciles", "n_f", "n_m", "p_females",
  "n_measured", ".has_length"
))
