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

#' Add `length_cm_mid`, the midpoint of the length bin
#'
#' \code{LengthClass} -- and therefore \code{\link{dr_add_length_cm}}'s
#' \code{length_cm} -- is the \strong{lower boundary} of a length bin, not the
#' length of the fish in it. ICES's field descriptions are explicit for both HL
#' and CA: \emph{"Lower length boundary of the Length class. In cm or mm
#' depending on the LngtCode. E.g. 10-11 cm=10"}. This adds the bin midpoint,
#' \code{length_cm + accuracy / 2}, which is the unbiased point estimate of the
#' length of a fish reported in that bin.
#'
#' \strong{This matters for weight and not much else.} A length-frequency
#' distribution is fine on lower bounds -- that is what a bin label is. But
#' \eqn{W = a L^b} is convex, so predicting weight from the lower bound
#' systematically \emph{under}-estimates it, worst for small fish and wide bins:
#' with the 1 cm bins that carry 59% of the archive's length rows, the shortfall
#' is 15.8% at 10 cm and 5.1% at 30 cm. It does not average out over a haul.
#' \code{\link{dr_add_predicted_weight}} therefore takes this column by default.
#'
#' \code{accuracy} is \code{NA} where \code{LengthCode} is the \code{"-9"}
#' sentinel, and \code{length_cm_mid} is then \code{NA} too: with no bin width
#' there is no midpoint, and falling back to the lower bound would reintroduce
#' the bias silently. No row in the published \code{HL_length} is affected.
#'
#' @param d A data frame or lazy table with \code{length_cm} and
#'   \code{accuracy}, as produced by \code{\link{dr_add_length_cm}} and as
#'   carried by \code{\link{dr_HL_length}}.
#'
#' @return \code{d} with an added \code{length_cm_mid} column.
#' @seealso \code{\link{dr_add_length_cm}}, \code{\link{dr_add_predicted_weight}}
#' @export
dr_add_length_mid <- function(d) {
  .dr_require_cols(d, c("length_cm", "accuracy"), "dr_add_length_mid")
  dplyr::mutate(d, length_cm_mid = length_cm + accuracy / 2)
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
#' A missing \code{SubsamplingFactor} propagates to \code{NA} for every
#' \code{DataType}, including \code{"R"}. This follows ICES's own format
#' documentation rather than the DATRAS R package's convention, and the
#' difference is deliberate: that package treats \code{"R"} plus a missing
#' factor as 1, i.e. "the whole catch was measured". ICES's field descriptions
#' make \code{SubsamplingFactor} \strong{mandatory}, define \code{1} as the
#' specific claim \emph{not subsampled}, and instruct submitters that "for the
#' fields with no information but header, please submit -9" -- which opus nulls
#' as a numeric sentinel. So an \code{NA} here means \emph{no information was
#' supplied}, which is not the same statement as \code{1}, and substituting one
#' for the other would assert a fact the submission does not contain.
#'
#' Archive-wide this affects 24,298 length rows (0.17%), worth 0.003% of
#' total \code{n_haul}; 98% of them are Can-Mar. An invalid (\code{"-9"}) or
#' missing \code{DataType} gives \code{NA} outright, as before.
#'
#' Per ICES: \code{"C"} must report 1, \code{"S"} is always >1, and
#' \code{"R"} is 1 or >1 depending on whether the species was subsampled.
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
        DataType %in% c("R", "P", "S") ~ NumberAtLength * SubsamplingFactor,
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

#' Add species names to a table carrying `Valid_Aphia`
#'
#' Left-joins the WoRMS lookup onto any table with a \code{Valid_Aphia} column, so
#' rows whose code is absent from the lookup are kept with \code{NA} names
#' rather than dropped.
#'
#' @param x A data frame or lazy table with a \code{Valid_Aphia} column.
#' @param species Species lookup. Defaults to \code{dr_con("species")},
#'   collected first when \code{x} is an eager data frame -- dbplyr refuses to
#'   join a data frame against a lazy table.
#'
#' @return \code{x} with the lookup's columns joined on.
#' @export
dr_join_species <- function(x, species = NULL) {
  .dr_require_cols(x, "Valid_Aphia", "dr_join_species")

  if (is.null(species)) {
    species <- dr_con("species")
    if (!inherits(x, "tbl_lazy")) species <- dplyr::collect(species)
  }
  dplyr::left_join(x, species, by = "Valid_Aphia")
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
