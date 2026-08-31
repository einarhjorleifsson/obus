#' Concatenate columns with a separator, skipping `NA` fields entirely
#'
#' Internal replacement for \code{paste(..., sep = sep)} inside \code{.id}'s
#' \code{mutate()} -- not a general utility, specific to this one need.
#' \code{paste()} cannot be trusted here because \code{dplyr} resolves it
#' differently per backend: on a plain data frame R's own \code{paste()}
#' renders an \code{NA} field as the literal two-character string \code{"NA"},
#' while on a \code{tbl_lazy} \code{dbplyr} translates \code{paste(sep = x)}
#' to DuckDB's \code{CONCAT_WS()}, which drops \code{NA} fields instead.
#' \code{.id} is the join key between HH, HL and CA, so it must come out
#' identical whichever backend computed it; this builds the NA-skipping
#' behaviour explicitly from primitives (\code{is.na()},
#' \code{dplyr::case_when()}, \code{paste0()}) that translate the same way on
#' both.
#'
#' One deliberate departure from raw \code{CONCAT_WS()}: when every field is
#' \code{NA} this returns \code{NA}, not \code{CONCAT_WS()}'s own \code{""}.
#' An empty string would collide every such row onto one \code{.id}, which is
#' worse than reporting honestly that no key could be built.
#'
#' @param d A data frame or \code{tbl_lazy}.
#' @param cols Character vector of column names to concatenate, in order.
#' @param sep Separator string.
#' @return \code{d} with an added (or overwritten) \code{.id} column.
#' @keywords internal
.dr_concat_ws <- function(d, cols, sep = ":") {
  acc <- rlang::sym(cols[1])
  d <- dplyr::mutate(d, .id = as.character(!!acc))
  for (nm in cols[-1]) {
    nxt <- rlang::sym(nm)
    d <- dplyr::mutate(d, .id = dplyr::case_when(
      is.na(.id) & is.na(!!nxt) ~ NA_character_,
      is.na(.id)                ~ as.character(!!nxt),
      is.na(!!nxt)              ~ .id,
      TRUE                      ~ paste0(.id, sep, !!nxt)
    ))
  }
  d
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
#' together for obus's own convenience joining HH to HL and CA. Fields that
#' are \code{NA} (most often \code{StationName}) are skipped rather than
#' rendered as the string \code{"NA"}, matching the convention the published
#' archive already uses; see \code{\link{.dr_concat_ws}} for why that needs
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
