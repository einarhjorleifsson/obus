# Drawing the summaries ---------------------------------------------------------------
#
# A ggplot is a table plus a mapping, so the substance is the table and the
# drawing is a thin last step: autoplot() reads the summary's own attributes
# (what it is, and which columns it was grouped by, in order) and picks the
# plain geom that fits. No cosmetic arguments; add scale_*(), theme_*() and
# labs() as usual. ggplot2 cannot summarise a lazy table, so these never see
# one: the verbs return ordinary tibbles.

#' @importFrom ggplot2 autoplot
#' @export
ggplot2::autoplot

#' Draw a summary
#'
#' Draws the result of [dr_summarise_hauls()], [dr_summarise_occurrence()],
#' [dr_summarise_cpue()] or [dr_summarise_length()] as a ggplot, which you can
#' add to as usual.
#'
#' @details
#' The summary remembers the columns it was grouped by, in the order you wrote
#' them, and they decide the figure:
#'
#' * **one** grouping column is the x-axis: a line with its interval when it is
#'   numeric (a year), a point with an interval otherwise (a survey), bars for
#'   [dr_summarise_hauls()];
#' * **two** are x and y: tiles coloured by the statistic, with a combination
#'   that has no hauls left blank (not zero) and the y-axis ordered by the
#'   first x each category appears at, so surveys read as a staircase;
#' * **`cell_lon` and `cell_lat`** (from [dr_add_cell()]) are a map: tiles on a
#'   coastline, and any other grouping columns become panels;
#' * a numeric column beside the cell, usually the year, turns the map into a
#'   small time series inside each rectangle, drawn as points on one shared scale
#'   with the latest value in red. The numeric column can be anything ordered (a year, a length class, a depth band) and the statistic any of the four;
#' * more columns become panels, and so does the species when there are
#'   several.
#'
#' For probability of capture the colour scale is fixed from 0 to 1, so figures
#' compare, and a tile fades with the number of hauls behind it. For
#' [dr_summarise_length()] the x-axis is the length class and the first
#' grouping column is the colour.
#'
#' @param object A summary from one of the `dr_summarise_*()` functions.
#' @param ... Not used.
#' @param top For the point-in-rectangle map only: a function that takes the
#'   plotted values and returns where the shared height scale ends. The default
#'   is the 95th percentile, so one extreme rectangle does not flatten the rest;
#'   values above it are drawn at the top. Use `max` to see everything.
#'   Probability of capture always ends at 1.
#'
#' @return A ggplot object.
#' @export
#' @method autoplot dr_summary
#'
#' @examples
#' \dontrun{
#' dr_con("HH") |> dr_summarise_hauls(Year, Survey) |> autoplot()
#'
#' dr_con("HH") |>
#'   dr_summarise_occurrence("Raja clavata", Year, Survey) |>
#'   autoplot()
#'
#' dr_con("HH") |>
#'   dr_add_cell() |>
#'   dr_summarise_occurrence("Raja clavata", cell_lon, cell_lat) |>
#'   autoplot()
#' }
autoplot.dr_summary <- function(object, ...,
                                top = function(y) stats::quantile(y, 0.95, na.rm = TRUE)) {
  rlang::check_dots_empty()
  if (!is.function(top)) cli::cli_abort("{.arg top} must be a function of the values, such as {.code max}.")
  stat <- attr(object, "statistic")
  by   <- attr(object, "by")
  if (is.null(stat) || is.null(by)) {
    cli::cli_abort("This summary has lost its attributes; rebuild it with a {.code dr_summarise_*()} function.")
  }

  panels_species <- "latin" %in% names(object) && length(unique(object$latin)) > 1L

  if (all(c("cell_lon", "cell_lat") %in% by)) {
    return(.dr_autoplot_map(object, stat, setdiff(by, c("cell_lon", "cell_lat")),
                            panels_species, top))
  }
  if (stat == "length") return(.dr_autoplot_length(object, by, panels_species))

  facets <- c(if (length(by) > 2L) by[-(1:2)], if (panels_species) "latin")
  p <- switch(
    as.character(min(length(by), 3L)),
    "0" = .dr_plot_single(object, stat),
    "1" = .dr_plot_x(object, stat, by[[1]]),
    .dr_plot_tile(object, stat, by[[1]], by[[2]])
  )
  p + .dr_facets(facets) + ggplot2::theme_bw()
}

# What each statistic shows ---------------------------------------------------------
.dr_value <- function(stat) {
  switch(stat,
         hauls      = list(col = "n_hauls", label = "hauls"),
         occurrence = list(col = "p", label = "probability\nof capture"),
         cpue       = list(col = "cpue", label = "numbers\nper hour"),
         length     = list(col = "n_hour", label = "numbers per hour\nper haul"))
}

.dr_facets <- function(vars) {
  if (length(vars) == 0L) return(NULL)
  ggplot2::facet_wrap(ggplot2::vars(!!!rlang::syms(vars)))
}

# fixed 0-1 for a share, so figures compare; a plain sequential scale otherwise
.dr_fill_scale <- function(stat) {
  v <- .dr_value(stat)
  if (stat == "occurrence") {
    ggplot2::scale_fill_viridis_c(name = v$label, limits = c(0, 1),
                                  option = "magma", direction = -1)
  } else {
    ggplot2::scale_fill_viridis_c(name = v$label, option = "magma", direction = -1)
  }
}

# a tile built on few hauls fades, so a share that rests on three hauls does
# not look as sure as one on thirty
.dr_fade_scale <- function() {
  ggplot2::scale_alpha_continuous(name = "hauls\nin tile", range = c(0.35, 1),
                                  limits = c(3, 15), oob = scales::squish)
}

.dr_plot_single <- function(object, stat) {
  v <- .dr_value(stat)
  ggplot2::ggplot(object, ggplot2::aes(x = "all", y = .data[[v$col]])) +
    .dr_interval(object, stat, is_x_numeric = FALSE) +
    ggplot2::labs(x = NULL, y = gsub("\n", " ", v$label))
}

.dr_plot_x <- function(object, stat, x) {
  v <- .dr_value(stat)
  numeric_x <- is.numeric(object[[x]])
  p <- ggplot2::ggplot(object, ggplot2::aes(x = .data[[x]], y = .data[[v$col]]))
  if (stat == "hauls") {
    p <- p + ggplot2::geom_col(fill = "grey35")
  } else {
    p <- p + .dr_interval(object, stat, numeric_x)
  }
  p + ggplot2::labs(x = x, y = gsub("\n", " ", v$label))
}

.dr_interval <- function(object, stat, is_x_numeric) {
  if (stat == "hauls" || !"lower" %in% names(object)) return(ggplot2::geom_point())
  if (is_x_numeric) {
    list(ggplot2::geom_ribbon(ggplot2::aes(ymin = .data$lower, ymax = .data$upper),
                              alpha = 0.2),
         ggplot2::geom_line(), ggplot2::geom_point(size = 1))
  } else {
    ggplot2::geom_pointrange(ggplot2::aes(ymin = .data$lower, ymax = .data$upper))
  }
}

.dr_plot_tile <- function(object, stat, x, y) {
  v <- .dr_value(stat)
  if (!is.numeric(object[[y]])) {
    # order categories by the first x they appear at, earliest at the top
    ord <- stats::reorder(factor(object[[y]]), object[[x]], FUN = min, na.rm = TRUE)
    object[[y]] <- factor(ord, levels = rev(levels(ord)))
  }
  p <- ggplot2::ggplot(object, ggplot2::aes(x = .data[[x]], y = .data[[y]],
                                            fill = .data[[v$col]]))
  p <- if (stat == "hauls") {
    p + ggplot2::geom_tile(colour = "white", linewidth = 0.2)
  } else {
    p + ggplot2::geom_tile(ggplot2::aes(alpha = .data$n_hauls),
                           colour = "white", linewidth = 0.2) + .dr_fade_scale()
  }
  p + .dr_fill_scale(stat) + ggplot2::labs(x = x, y = y)
}

.dr_autoplot_map <- function(object, stat, other, panels_species, top) {
  rlang::check_installed("maps", reason = "to draw the coastline.")
  v <- .dr_value(stat)
  glyph <- if (stat != "length") Filter(function(b) is.numeric(object[[b]]), other)[1L]
  if (length(glyph) && !is.na(glyph)) {
    return(.dr_autoplot_glyph(object, stat, glyph, setdiff(other, glyph), panels_species, top))
  }
  step <- function(z) {
    d <- diff(sort(unique(z)))
    if (length(d)) min(d) else 1
  }
  dx <- step(object$cell_lon)
  dy <- step(object$cell_lat)

  p <- ggplot2::ggplot() +
    ggplot2::annotation_map(ggplot2::map_data("world"), fill = "grey80", colour = "grey50")
  p <- if (stat == "hauls") {
    p + ggplot2::geom_tile(data = object, width = dx, height = dy,
                           ggplot2::aes(.data$cell_lon, .data$cell_lat, fill = .data[[v$col]]))
  } else {
    p + ggplot2::geom_tile(data = object, width = dx, height = dy,
                           ggplot2::aes(.data$cell_lon, .data$cell_lat,
                                        fill = .data[[v$col]], alpha = .data$n_hauls)) +
      .dr_fade_scale()
  }
  p + .dr_fill_scale(stat) +
    ggplot2::coord_quickmap(xlim = range(object$cell_lon) + c(-dx, dx) / 2,
                            ylim = range(object$cell_lat) + c(-dy, dy) / 2) +
    ggplot2::labs(x = "longitude", y = "latitude") +
    .dr_facets(c(other, if (panels_species) "latin")) +
    ggplot2::theme_bw()
}

# A small time series inside each rectangle: one point per value of the numeric
# grouping column (a year), the latest in red, on a scale shared by every
# rectangle so heights compare. Drawn by hand, no extra package.
.dr_autoplot_glyph <- function(object, stat, x, other, panels_species, top) {
  rlang::check_installed("maps", reason = "to draw the coastline.")
  v <- .dr_value(stat)
  step <- function(z) {
    d <- diff(sort(unique(z)))
    if (length(d)) min(d) else 1
  }
  dx <- step(object$cell_lon)
  dy <- step(object$cell_lat)
  top <- if (stat == "occurrence") 1 else top(object[[v$col]])
  if (!is.numeric(top) || length(top) != 1L || is.na(top) || top <= 0) top <- 1
  object[[v$col]] <- pmin(object[[v$col]], top)
  xr <- range(object[[x]], na.rm = TRUE)
  span <- max(diff(xr), 1)
  d <- object
  d$.gx <- d$cell_lon - dx * 0.45 + 0.9 * dx * (d[[x]] - xr[[1]]) / span
  d$.base <- d$cell_lat - dy * 0.45
  d$.top <- d$.base + 0.9 * dy * d[[v$col]] / top
  d$.when <- factor(ifelse(d[[x]] == xr[[2]], "latest", "earlier"),
                    levels = c("earlier", "latest"))

  d <- d[!is.na(d[[v$col]]), ]

  ggplot2::ggplot() +
    ggplot2::annotation_map(ggplot2::map_data("world"), fill = "grey80", colour = "grey50") +
    ggplot2::geom_point(data = d, size = 0.4, na.rm = TRUE,
                        ggplot2::aes(x = .data$.gx, y = .data$.top, colour = .data$.when)) +
    ggplot2::scale_colour_manual(name = x, values = c(earlier = "#377EB8", latest = "#E41A1C"),
                                 labels = c(paste0(xr[[1]], "-", xr[[2]] - 1), xr[[2]]),
                                 guide = ggplot2::guide_legend(override.aes = list(size = 2)),
                                 drop = FALSE) +
    ggplot2::coord_quickmap(xlim = range(object$cell_lon) + c(-dx, dx) / 2,
                            ylim = range(object$cell_lat) + c(-dy, dy) / 2) +
    ggplot2::labs(x = "longitude", y = "latitude",
                  caption = paste0("Point height: ", gsub("\n", " ", v$label),
                                   ", same scale in every rectangle (top = ", signif(top, 3), ")")) +
    .dr_facets(c(other, if (panels_species) "latin")) +
    ggplot2::theme_bw()
}

.dr_autoplot_length <- function(object, by, panels_species) {
  v <- .dr_value("length")
  colour <- if (length(by) >= 1L) by[[1]]
  facets <- c(if (length(by) > 1L) by[-1], if (panels_species) "latin")
  p <- ggplot2::ggplot(object, ggplot2::aes(.data$length_cm, .data$n_hour))
  p <- if (is.null(colour)) {
    p + ggplot2::geom_line()
  } else {
    object[[colour]] <- factor(object[[colour]])
    p <- ggplot2::ggplot(object, ggplot2::aes(.data$length_cm, .data$n_hour,
                                              colour = .data[[colour]],
                                              group = .data[[colour]]))
    p + ggplot2::geom_line() + ggplot2::scale_colour_viridis_d(name = colour)
  }
  p + ggplot2::labs(x = "length (cm), lower end of the class",
                    y = gsub("\n", " ", v$label)) +
    .dr_facets(facets) + ggplot2::theme_bw()
}
