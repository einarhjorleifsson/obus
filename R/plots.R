drp_bubble <- function(d) {


  d <-
    d |>
    dplyr::collect()

  ggplot2::ggplot() +
    ggplot2::theme_void() +
    ggplot2::geom_sf(data = dr_coastline) +
    ggplot2::geom_point(data = d,
                        ggplot2::aes(lon1, lat1, size = n),
                        alpha = 0.50, colour = "red") +
    ggplot2::scale_size_area(max_size = 10) +
    ggplot2::coord_sf(xlim = range(d$lon1), ylim = range(d$lat1)) +
    ggplot2::labs(x = NULL, y = NULL) +
    ggplot2::facet_wrap(~ year)
}

drp_length <- function(d) {
  nyrs <- d$Year |> unique() |> length()
  d.sum <-
    d |>
    dplyr::group_by(LngtClass) |>
    dplyr::summarise(n = sum(n) / nyrs)
  ggplot2::ggplot() +
    ggplot2::theme_bw() +
    ggplot2::geom_col(data = d,
                      colour = "black",
                      fill = "black",
                      ggplot2::aes(LngtClass, n)) +
    ggplot2::geom_step(data = d.sum,
                       ggplot2::aes(LngtClass, n),
                       colour = "grey50") +
    ggplot2::facet_wrap(~ Year) +
    ggplot2::labs(x = NULL, y = NULL,
                  caption = "Number of fish by length [cm]")
}
