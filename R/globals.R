# Column names used unquoted inside dplyr verbs. Declared so `R CMD check`
# does not report them as undefined globals -- they are data columns, not
# objects, and are resolved by dplyr's data mask (or by dbplyr's SQL
# translation) at call time.
# `:=` is rlang's dynamic-name operator, used by .dr_coalesce_with_provenance_lazy()
# to build mutate() calls over caller-supplied column names.
#' @importFrom rlang :=
NULL

utils::globalVariables(c(
  # haul key
  ".id", "Survey", "Year", "Quarter", "Country", "Platform", "Gear",
  "StationName", "HaulNumber",
  # HH
  "HaulValidity", "DataType", "HaulDuration",
  # HL
  "Valid_Aphia", "SpeciesSex", "SpeciesValidity", "SpeciesCategory", "TotalNumber",
  "SpeciesCategoryWeight", "SubsamplingFactor", "NumberAtLength",
  "LengthCode", "LengthClass", "LengthType", "DevelopmentStage",
  # species lookup
  "latin", "species", "rank",
  # derived
  "length_mm", "length_cm", "accuracy", "n_haul", "n_hour",
  "n_haul_raw", "n_hour_raw", "w_haul", "w_hour", "w_haul_raw", "w_hour_raw", ".wgt_cat",
  "n_totalnumber", "n_totalnumber_hour", ".n_ok", ".h_ok", ".w_ok", ".wh_ok", ".n_raw", ".h_raw",
  "raised", "sex_expected", "reconciles", "n_f", "n_m", "p_females", ".r_raw", ".r_ok",
  "n_measured", ".has_length",
  # length-weight: the coefficient lookup, the conversion lookup and what the
  # apply step derives from them
  "a", "b", "lw_source", "lw_scope", "n_ca", "r2", "sigma", "length_bearing",
  "length_cm_mid", "length_cm_tl", "length_type_source",
  "from_type", "intercept", "slope",
  "IndividualWeight", "w_ind", "w_haul_pred", "w_hour_pred",
  "w_modelled", "w_measured", "n_rows", "data", "fit", "glance", "n_len"
))
