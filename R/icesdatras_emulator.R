# survey <- "NS-IBTS"
# year <- 2025
# quarter <- 1

#' @export
.dr_get_cpue_length <- function(survey, year, quarter) {
  lh_id <- function(d) {
    d |>
      dplyr::mutate(.id2 = paste(Survey, Year, Quarter, Ship, Gear, HaulNo, sep = ":"))
  }
  d <-
    icesDatras::getCPUELength(survey, year, quarter) |>
    dplyr::mutate(time = lubridate::dmy_hms(DateTime)) |>
    lh_id()
  hh <-
    icesDatras::getDATRAS("HH", survey, year, quarter) |>
    dr_add_starttime() |>
    lh_id() |>
    dr_add_id(base = "old") |>
    dplyr::select(.id, .id2, time)
  out <-
    d |>
    dplyr::as_tibble() |>
    dplyr::left_join(hh) |>
    dplyr::mutate(Sex = as.character(Sex)) |>
    # be explicit
    dplyr::rename(latin = Species,
                  SpeciesSex = Sex,
                  length_mm = LngtClas,
                  n_hour = CPUE_number_per_hour)

  if(nrow(d) != nrow(out)) stop("We have different number of rows")

  return(out)

}

