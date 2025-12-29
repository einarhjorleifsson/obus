#' Retrieve DATRAS Station (HH) Table
#'
#' Retrieve DATRAS station (HH) data for a given survey, year(s), and quarter(s).
#' This function is a wrapper around \code{icesDatras::getDATRAS(record = "HH", ...)} that ensures variable types are properly set.
#'
#' @param survey A character string, the survey acronym (e.g., \code{"NS-IBTS"}).
#' @param years An integer vector of years (e.g., \code{2010} or \code{2005:2010}).
#' @param quarters An integer vector of quarters (1, 2, 3, or 4).
#' @param quiet Logical; if \code{TRUE} (default), suppress messages.
#'
#' @return A tibble with station data or an empty tibble if no data is available.
#' @export
dr_getHH <- function(survey, years, quarters, quiet = TRUE) {

  if(quiet) {
    suppressMessages(
      tmp <-
        icesDatras::getDATRAS(record = "HH",
                              survey = survey[1],
                              years = years,
                              quarters = quarters))
  } else {
    tmp <-
      icesDatras::getDATRAS(record = "HH",
                            survey = survey[1],
                            years = years,
                            quarters = quarters)
  }

  if(inherits(tmp, "data.frame")) {
    tmp[tmp == -9] <- NA        # convert all -9 to NA

    tmp <-
      tmp |>
      tibble::as_tibble() |>
      dr_settypes() |>
      dplyr::mutate(
        TimeShot = stringr::str_pad(TimeShot, width = 4, side = "left", pad = "0"),
        TimeShot = paste0(stringr::str_sub(TimeShot, 1, 2),
                          ":",
                          stringr::str_sub(TimeShot, 3, 4)),
        .timeshot = lubridate::ymd_hm(paste(Year, Month, Day, TimeShot)),
        DateofCalculation = lubridate::ymd(DateofCalculation)
      )

    return(tmp)
  } else {
    return(tibble::tibble())
  }
}

#' Retrieve DATRAS Length (HL) Table
#'
#' Retrieve DATRAS length (HL) data for a given survey, year(s), and quarter(s).
#' This function is a wrapper around \code{icesDatras::getDATRAS(record = "HL", ...)} that ensures variable types are properly set.
#'
#' @param survey A character string, the survey acronym (e.g., \code{"NS-IBTS"}).
#' @param years An integer vector of years (e.g., \code{2010} or \code{2005:2010}).
#' @param quarters An integer vector of quarters (1, 2, 3, or 4).
#' @param quiet Logical; if \code{TRUE} (default), suppress messages.
#'
#' @return A tibble with station data or an empty tibble if no data is available.
#' @export
dr_getHL <- function(survey, years, quarters, quiet = TRUE) {

  if(quiet) {
    suppressMessages(
      tmp <-
        icesDatras::getDATRAS(record = "HL",
                              survey = survey[1],
                              years = years,
                              quarters = quarters))
  } else {
    tmp <-
      icesDatras::getDATRAS(record = "HL",
                            survey = survey[1],
                            years = years,
                            quarters = quarters)
  }

  if(inherits(tmp, "data.frame")) {
    tmp[tmp == -9] <- NA        # convert all -9 to NA
    tmp <-
      tmp |>
      tibble::as_tibble() |>
      dr_settypes() |>
      dplyr::mutate(DateofCalculation = lubridate::ymd(DateofCalculation))
    return(tmp)
  } else {
    return(tibble::tibble())
  }
}

#' Retrieve DATRAS Age (CA) Table
#'
#' Retrieve DATRAS age (CA) data for a given survey, year(s), and quarter(s).
#' This function is a wrapper around \code{icesDatras::getDATRAS(record = "CA", ...)} that ensures variable types are properly set.
#'
#' @param survey A character string, the survey acronym (e.g., \code{"NS-IBTS"}).
#' @param years An integer vector of years (e.g., \code{2010} or \code{2005:2010}).
#' @param quarters An integer vector of quarters (1, 2, 3, or 4).
#' @param quiet Logical; if \code{TRUE} (default), suppress messages.
#'
#' @return A tibble with station data or an empty tibble if no data is available.
#' @export
dr_getCA <- function(survey, years, quarters, quiet = TRUE) {

  if(quiet) {
    suppressMessages(
      tmp <-
        icesDatras::getDATRAS(record = "CA",
                              survey = survey[1],
                              years = years,
                              quarters = quarters)
    )
  } else {
    tmp <-
      icesDatras::getDATRAS(record = "CA",
                            survey = survey[1],
                            years = years,
                            quarters = quarters)
  }

  if(inherits(tmp, "data.frame")) {
    tmp[tmp == -9] <- NA        # convert all -9 to NA
    tmp <-
      tmp |>
      tibble::as_tibble() |>
      dr_settypes() |>
      dplyr::mutate(DateofCalculation = lubridate::ymd(DateofCalculation))
    return(tmp)
  } else {
    return(tibble::tibble())
  }
}

#' Retrieve DATRAS Flex (FL) Table
#'
#' Retrieve DATRAS flex (FL) data for a given survey, year(s), and quarter(s).
#' This function is a wrapper around \code{icesDatras::getDATRAS(record = "FL", ...)} that ensures variable types are properly set.
#'
#' @param surveys A character string, the survey acronym (e.g., \code{"NS-IBTS"}).
#' @param years An integer vector of years (e.g., \code{2010} or \code{2005:2010}).
#' @param quarters An integer vector of quarters (1, 2, 3, or 4).
#' @param quiet Logical; if \code{TRUE} (default), suppress messages.
#'
#' @return A tibble with station data or an empty tibble if no data is available.
#' @export
dr_getFL <- function(surveys, years, quarters, quiet = TRUE) {


  yrs <- years
  qrt <- quarters
  res <- list()
  counter <- 0
  for(s in 1:length(surveys)) {

    for(y in 1:length(yrs)) {

      for(q in 1:length(q)) {


        if(quiet) {
          suppressMessages(
            tmp <-
              icesDatras::getFlexFile(survey = surveys[s],
                                      year = yrs[y],
                                      quarter = qrt[q]))
        } else {
          tmp <-
            icesDatras::getFlexFile(survey = surveys[s],
                                    year = yrs[y],
                                    quarter = qrt[q])
        }


        if(inherits(tmp, "data.frame")) {
          counter <- counter + 1
          res[[counter]] <- tmp |> tibble::as_tibble() |> dr_settypes()
        }
      } # quarter
    } # years
  } # surveys

  out <- dplyr::bind_rows(res)
  if(nrow(out) >= 1) out <- out |> dplyr::mutate(RecordType = "FL")
  return(out)

}


#' Download DATRAS tables
#'
#' Each DATRAS table (HH, HL, CA and FL) is downloaded and saved.
#'
#' @param surveys Survey to get, if none specified get all
#' @param years Years to download, if none specified get all from 1990 onwards. Not yet active.
#' @param quarters Quarters to download, if none specified get all from 1990 onwards. Not yet active.
#' @param outpath The path (default 'data') where saved DATRAS exchange files are stored
#' @param filetype File type (default 'parquet'). Currently inactive.
#' '
#' @return Files on disk
#' @export
#'
dr_download_data <- function(surveys = NULL, years = NULL, quarters = NULL, outpath = "data", filetype = "parquet") {


  if(is.null(surveys)) {
    surveys <- c("BITS", "BTS", "BTS-GSA17", "BTS-VIII",
                 "Can-Mar",   "DWS",       "DYFS",      "EVHOE",
                 "FR-CGFS",   "FR-WCGFS",  "IE-IAMS",   "IE-IGFS",
                 "IS-IDPS",   "NIGFS",     "NL-BSAS",   "NS-IBTS",
                 "NS-IDPS",   "NSSS",      "PT-IBTS",   "ROCKALL",
                 "SCOROC",    "SCOWCGFS",  "SE-SOUND",  "SNS",
                 "SP-ARSA",   "SP-NORTH",  "SP-PORC",   "SWC-IBTS")
  }
  if(is.null(years)) years <- 1965:2028
  if(is.null(quarters)) quarters <- 1:4

  for(i in 1:length(surveys)) {

    hh <-
      dr_getHH(surveys[i], years, quarters)
    if(nrow(hh) >= 1) {
      hh |> dplyr::group_by(RecordType, Survey) |> arrow::write_dataset(path = outpath)
    }

    hl <-
      dr_getHL(surveys[i], years, quarters)
    if(nrow(hl) >= 1) {
      hl |> dplyr::group_by(RecordType, Survey) |> arrow::write_dataset(path = outpath)
    }

    ca <- dr_getCA(surveys[i], years, quarters)
    if(nrow(ca) >= 1) {
      ca |> dplyr::group_by(RecordType, Survey) |> arrow::write_dataset(path = outpath)
    }

    # fl <- dr_getFL(surveys[i], years, quarters)
    # if(nrow(fl) >= 1) {
    #   fl |> dplyr::group_by(RecordType, Survey) |> arrow::write_dataset(path = outpath)
    # }
  }
}
