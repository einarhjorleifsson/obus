# ggplot2 and lazy tables ----------------------------------------------------------------
#
# ggplot2 cannot aggregate in the database: given a lazy table it quietly
# collects every row into R (verified with ggplot2 4.0.3: `ggplot(lazy)` builds
# without an error and holds the whole table). The published HL tables run to
# millions of rows, so that is a trap, and this turns it into a message.

#' @exportS3Method ggplot2::fortify
fortify.tbl_lazy <- function(model, data, ...) {
  cli::cli_abort(c(
    "ggplot2 would pull every row of this lazy table into R.",
    "i" = "Summarise it first, e.g. {.code dr_summarise_occurrence(...)} and {.code autoplot()}, or {.code dplyr::collect()} the part you need.",
    "i" = "A lazy table is a query that has not been run yet; {.code collect()} runs it."
  ), call = NULL)
}
