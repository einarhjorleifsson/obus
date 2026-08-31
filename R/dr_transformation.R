# Derived-quantity helpers -----------------------------------------------------
#
# The minimum set dr_HL_length() and dr_HL_summary() need, and nothing more.
# All four take opus's current field names and only those -- no `LengthCode =`
# style column arguments, because with one naming scheme there is nothing left
# to point them at.

#' Add `length_cm` and `accuracy`
#'
#' Converts \code{LengthClass} to centimetres using \code{LengthCode}, and
#' records the measurement resolution that code implies.
#'
#' @param d A data frame or lazy table with \code{LengthCode} and
#'   \code{LengthClass}.
#'
#' @return \code{d} with two added columns:
#'   \describe{
#'     \item{\code{length_cm}}{Length class in cm.}
#'     \item{\code{accuracy}}{Resolution in cm: \code{"."} 0.1, \code{"0"} 0.5,
#'       \code{"1"} 1, \code{"2"} 2, \code{"5"} 5.}
#'   }
#' @seealso \code{\link{dr_add_length_mm}}
#' @export
dr_add_length_cm <- function(d) {
  .dr_require_cols(d, c("LengthCode", "LengthClass"), "dr_add_length_cm")

  d |>
    dplyr::mutate(
      length_cm = dplyr::case_when(
        LengthCode == "-9"              ~ NA_real_,
        LengthCode %in% c(".", "0")     ~ LengthClass / 10,
        LengthCode %in% c("1", "2", "5") ~ LengthClass * 1.0,
        TRUE                            ~ NA_real_
      ),
      accuracy = dplyr::case_when(
        LengthCode == "." ~ 0.1,
        LengthCode == "0" ~ 0.5,
        LengthCode == "1" ~ 1.0,
        LengthCode == "2" ~ 2.0,
        LengthCode == "5" ~ 5.0,
        TRUE              ~ NA_real_
      )
    )
}

#' Add `length_mm`
#'
#' Converts \code{LengthClass} to millimetres using \code{LengthCode}.
#'
#' @inheritParams dr_add_length_cm
#' @return \code{d} with an added integer \code{length_mm} column.
#' @seealso \code{\link{dr_add_length_cm}}
#' @export
dr_add_length_mm <- function(d) {
  .dr_require_cols(d, c("LengthCode", "LengthClass"), "dr_add_length_mm")

  d |>
    dplyr::mutate(
      length_mm = dplyr::case_when(
        LengthCode == "-9"               ~ NA_integer_,
        LengthCode %in% c(".", "0")      ~ as.integer(LengthClass),
        LengthCode %in% c("1", "2", "5") ~ as.integer(LengthClass) * 10L,
        TRUE                             ~ NA_integer_
      )
    )
}

# icesVocab - DataType
#   |key |description                               |
#   |:---|:-----------------------------------------|
#   |-9  |Invalid hauls                             |
#   |C   |Data calculated as CPUE (number per hour) |
#   |P   |Pseudocategory sampling                   |
#   |R   |Data by haul                              |
#   |S   |Sub sampled data                          |

#' Numbers caught per haul and per hour, at length
#'
#' Raises \code{NumberAtLength} to a whole-haul count (\code{n_haul}) and an
#' hourly rate (\code{n_hour}), according to how the submission reports its
#' catch (\code{DataType}).
#'
#' @details
#' For \code{DataType == "R"} (data by haul) a missing
#' \code{SubsamplingFactor} is treated as 1 -- absence of a subsampling factor
#' means the full catch was measured. This matches the DATRAS R package's own
#' convention. For every other \code{DataType} a missing
#' \code{SubsamplingFactor} propagates to \code{NA}, and an invalid
#' (\code{"-9"}) or missing \code{DataType} gives \code{NA} outright.
#'
#' @param d DATRAS length table (HL) with \code{DataType}, \code{HaulDuration},
#'   \code{NumberAtLength} and \code{SubsamplingFactor}. \code{DataType} and
#'   \code{HaulDuration} live in HH, so this runs after the join to HH.
#'
#' @return \code{d} with added \code{n_haul} and \code{n_hour} columns.
#' @export
dr_add_n_and_cpue <- function(d) {
  .dr_require_cols(d, c("DataType", "NumberAtLength", "HaulDuration",
                        "SubsamplingFactor"), "dr_add_n_and_cpue")

  d |>
    dplyr::mutate(
      n_haul = dplyr::case_when(
        # A "C" submission reports an hourly rate, so a per-haul count is only
        # recoverable by multiplying back up by the duration -- undefined when
        # that duration is 0 or negative. Without this the arithmetic silently
        # returns 0 (or a negative count), which is worse than an error: it
        # looks like a real observation.
        DataType == "C" & HaulDuration <= 0 ~ NA_real_,
        DataType == "C"  ~ NumberAtLength * SubsamplingFactor * HaulDuration / 60,
        DataType == "R"  ~ NumberAtLength * dplyr::coalesce(SubsamplingFactor, 1),
        DataType == "P"  ~ NumberAtLength * SubsamplingFactor,
        DataType == "S"  ~ NumberAtLength * SubsamplingFactor,
        TRUE             ~ NA_real_
      )
    ) |>
    dplyr::mutate(
      n_hour = dplyr::case_when(
        # "C" already IS an hourly rate -- it is reported, not derived, so it
        # survives a bad duration intact and must not be discarded.
        DataType == "C"   ~ NumberAtLength * SubsamplingFactor,
        # Everywhere else the rate is derived by dividing by the duration,
        # which is undefined at 0 (yields Inf) and meaningless when negative
        # (yields a negative rate). Archive-wide: 217 hauls at 0, 2 negative
        # (both Can-Mar 2017, already flagged HaulValidity "I").
        HaulDuration <= 0 ~ NA_real_,
        TRUE              ~ n_haul / HaulDuration * 60
      )
    )
}

#' Add species names to a table carrying `aphia`
#'
#' Left-joins the WoRMS lookup onto any table with an \code{aphia} column, so
#' rows whose code is absent from the lookup are kept with \code{NA} names
#' rather than dropped.
#'
#' @param x A data frame or lazy table with an \code{aphia} column.
#' @param species Species lookup. Defaults to \code{dr_con("species")},
#'   collected first when \code{x} is an eager data frame -- dbplyr refuses to
#'   join a data frame against a lazy table.
#'
#' @return \code{x} with the lookup's columns joined on.
#' @export
dr_join_species <- function(x, species = NULL) {
  .dr_require_cols(x, "aphia", "dr_join_species")

  if (is.null(species)) {
    species <- dr_con("species")
    if (!inherits(x, "tbl_lazy")) species <- dplyr::collect(species)
  }
  dplyr::left_join(x, species, by = dplyr::join_by(aphia == aphia))
}

# One error message shape for every helper above.
.dr_require_cols <- function(d, cols, fn) {
  missing_vars <- setdiff(cols, colnames(d))
  if (length(missing_vars) > 0) {
    stop(fn, ": missing required columns: ",
         paste(missing_vars, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}
