# Resolving `species` -------------------------------------------------------------
#
# One argument, two spellings: latin names ("Gadus morhua") or numeric
# `Valid_Aphia` codes, both as in dr_con("species"). Resolved against the
# published lookup so a typo fails with the offending names, not with an empty
# result several steps downstream.

# The whole lookup is 2,000 rows; it is read once per session.
.dr_species_all <- function() {
  .dr_open_value("species_all", function() {
    dplyr::collect(dplyr::select(dr_con("species"), Valid_Aphia, latin))
  })
}

#' Resolve `species` to rows of the species lookup
#'
#' @param species Character latin names or numeric `Valid_Aphia` codes.
#' @param call The environment whose call is reported in an error.
#' @return A lazy table on obus's connection with `Valid_Aphia` and `latin`,
#'   restricted to `species`.
#' @noRd
.dr_species <- function(species, call = rlang::caller_env()) {
  if (is.factor(species)) species <- as.character(species)
  if (!(is.character(species) || is.numeric(species)) || length(species) == 0L ||
      anyNA(species)) {
    cli::cli_abort(
      c("{.arg species} must be latin names or {.field Valid_Aphia} codes.",
        "x" = "Got {.obj_type_friendly {species}}."),
      call = call)
  }
  by <- if (is.numeric(species)) "Valid_Aphia" else "latin"
  if (is.numeric(species)) species <- as.integer(species)

  all     <- .dr_species_all()
  found   <- all[all[[by]] %in% species, ]
  unknown <- setdiff(species, found[[by]])
  if (length(unknown) > 0L) {
    cli::cli_abort(
      c("Unknown {cli::qty(unknown)}species: {.val {unknown}}.",
        "i" = "Names are the {.field latin} column of {.code dr_con(\"species\")}."),
      call = call)
  }

  aphia <- found$Valid_Aphia
  dr_con("species") |>
    dplyr::filter(Valid_Aphia %in% !!aphia) |>
    dplyr::select(Valid_Aphia, latin)
}
