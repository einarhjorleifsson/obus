#' Concatenate columns with a separator, writing a token for `NA` fields
#'
#' Internal replacement for \code{paste(..., sep = sep)} inside \code{.id}'s
#' \code{mutate()} -- not a general utility, specific to this one need.
#' \code{paste()} cannot be trusted here because \code{dplyr} resolves it
#' differently per backend: on a plain data frame R's own \code{paste()}
#' renders an \code{NA} field as the literal two-character string \code{"NA"},
#' while on a \code{tbl_lazy} \code{dbplyr} translates \code{paste(sep = x)}
#' to DuckDB's \code{CONCAT_WS()}, which drops \code{NA} fields instead.
#' \code{.id} is the join key between HH, HL and CA, so it must come out
#' identical whichever backend computed it. This substitutes
#' \code{na_token} for every \code{NA} field \emph{before} concatenating, so
#' no \code{NA} ever reaches \code{paste0()} and the two backends cannot
#' disagree about what it does with one.
#'
#' \strong{The field count is fixed, and that is the point} (changed
#' 2026-09-03; it used to skip \code{NA} fields, producing a shorter string).
#' Three things the skipping cost, all measured on the full archive:
#' \itemize{
#'   \item \code{.id} was not splittable. 6,899 of 150,217 HH hauls (4.59%)
#'     produced a 7-field \code{.id}, so a positional
#'     \code{tidyr::separate()} into the eight key names silently shifted
#'     \code{HaulNumber} into the \code{StationName} slot.
#'   \item It was self-consistent for HL only by luck. HH and HL carry
#'     \code{NA StationName} on the \emph{same} hauls, so both sides skipped
#'     the same field and still matched (0 orphan HL rows). CA does not:
#'     305,276 CA rows have \code{HaulNumber} missing too -- a field never
#'     \code{NA} in HH -- giving 280 six-field \code{.id}s that can match no
#'     haul.
#'   \item With two nullable fields it could collide two different hauls:
#'     \code{StationName = NA, HaulNumber = k} and
#'     \code{StationName = k, HaulNumber = NA} skip down to the same string.
#'     Not yet realised (0 collisions across HH, HL and CA), but live.
#' }
#'
#' \code{"NA"} rather than \code{"-9"} deliberately. opus has already nulled
#' \code{-9} as a sentinel, so writing it back would manufacture a value the
#' archive does not contain and would be indistinguishable from a genuine
#' \code{StationName} of \code{-9}; Working Principle 3's direction of travel
#' is never to re-manufacture a sentinel. \code{"NA"} also makes \code{.id}
#' byte-identical to the DATRAS R package's \code{haul.id}, which pastes the
#' same eight fields in the same order and lets \code{NA} render as
#' \code{"NA"} for exactly this reason. Verified unambiguous: no
#' \code{StationName} in HH, HL or CA is \code{"NA"}, \code{"-9"},
#' \code{""}, or contains a \code{":"}.
#'
#' One case still returns \code{NA} rather than a string: when \emph{every}
#' field is \code{NA}. \code{"NA:NA:NA:NA:NA:NA:NA:NA"} would collide every
#' such row onto one \code{.id}, which is worse than reporting honestly that
#' no key could be built. It cannot arise in the current archive -- the first
#' six fields are never \code{NA} in any of the three tables -- and is kept
#' as a guard, not a live branch.
#'
#' @param d A data frame or \code{tbl_lazy}.
#' @param cols Character vector of column names to concatenate, in order.
#' @param sep Separator string.
#' @param na_token String written in place of an \code{NA} field.
#' @return \code{d} with an added (or overwritten) \code{.id} column.
#' @keywords internal
.dr_concat_ws <- function(d, cols, sep = ":", na_token = "NA") {
  acc <- rlang::sym(cols[1])
  d <- dplyr::mutate(
    d,
    .id     = dplyr::if_else(is.na(!!acc), na_token, as.character(!!acc)),
    .dr_any = !is.na(!!acc)
  )
  for (nm in cols[-1]) {
    nxt <- rlang::sym(nm)
    d <- dplyr::mutate(
      d,
      .id     = paste0(.id, sep,
                       dplyr::if_else(is.na(!!nxt), na_token, as.character(!!nxt))),
      .dr_any = .dr_any | !is.na(!!nxt)
    )
  }
  d |>
    dplyr::mutate(.id = dplyr::if_else(.dr_any, .id, NA_character_)) |>
    dplyr::select(-.dr_any)
}

# The eight fields ICES's own exchange tables use to key a haul. Order is
# part of the contract: it is what makes a stored .id comparable to a
# recomputed one.
DR_ID_FIELDS <- c("Survey", "Year", "Quarter", "Country", "Platform",
                  "Gear", "StationName", "HaulNumber")

#' Generate a unique haul id
#'
#' Concatenates the eight join-key fields into a new \code{.id} column, e.g.
#' \code{"BITS:1991:1:DE:06S1:H20:33:28"}.
#'
#' \code{.id} is an obus construct -- ICES/DATRAS has no such field. It is
#' just the fields ICES's own exchange tables use to key a haul, glued
#' together for obus's own convenience joining HH to HL and CA.
#'
#' \strong{It always has eight \code{":"}-separated fields.} A field that is
#' \code{NA} -- in practice \code{StationName}, and in CA also
#' \code{HaulNumber} -- is written as the literal string \code{"NA"}, so
#' \code{.id} can be split back into the eight key columns positionally and
#' so it is byte-identical to the DATRAS R package's \code{haul.id}. This
#' changed on 2026-09-03: \code{NA} fields used to be skipped, which made
#' 4.59% of hauls produce a seven-field \code{.id}. See
#' \code{\link{.dr_concat_ws}} for the measurements behind the change, for
#' why the token is \code{"NA"} and not \code{"-9"}, and for why this needs
#' building by hand rather than leaving to \code{paste()}.
#'
#' Only opus's current field names are accepted. The legacy ICES names
#' (\code{Ship}, \code{StNo}, \code{HaulNo}) are not handled -- rename first
#' with \code{opus::op_rename()} if you have a legacy-named table.
#'
#' @param d A DATRAS table (HH, HL or CA) carrying all eight of \code{Survey},
#'   \code{Year}, \code{Quarter}, \code{Country}, \code{Platform},
#'   \code{Gear}, \code{StationName}, \code{HaulNumber}. Data frame or
#'   \code{tbl_lazy}.
#'
#' @return \code{d} with an additional \code{.id} column.
#' @export
#'
#' @examples
#' data.frame(
#'   Survey = "BITS", Year = 1991L, Quarter = 1L, Country = "DE",
#'   Platform = "06S1", Gear = "H20", StationName = "33", HaulNumber = 28L
#' ) |> dr_add_id()
dr_add_id <- function(d) {
  missing_vars <- setdiff(DR_ID_FIELDS, colnames(d))
  if (length(missing_vars) > 0) {
    stop("dr_add_id: missing columns for the haul key: ",
         paste(missing_vars, collapse = ", "), call. = FALSE)
  }
  .dr_concat_ws(d, DR_ID_FIELDS)
}
