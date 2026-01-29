# https://github.com/ices-tools-prod/icesDatras/issues/35

#' Get Survey Indices for All Years
#'
#' Get age-based indices of abundance by species and survey.
#'
#' @param survey the survey acronym, e.g. NS-IBTS.
#' @param quarter the quarter of the year the survey took place, i.e. 1, 2, 3 or 4.
#' @param species the Aphia species code for the species of interest.
#' @param quiet Boolean (default FALSE)
#'
#' @examples
#' \dontrun{
#' haddock_aphia <- icesVocab::findAphia("haddock")
#' index <- getIndicesAllYears(survey = "NS-IBTS", quarter = 3, species = haddock_aphia)
#' str(index)
## 94 sec (home)
## 21 sec (office)
#' }
#'
#' @export

getIndicesAllYears <- function(survey, quarter, species, quiet=FALSE) {
  # check survey name
  if (!icesDatras::checkSurveyOK(survey)) return(FALSE)

  # loop over years
  out <- lapply(icesDatras::getSurveyYearList(survey), function(y) {
    if (!quiet)
      message("* ", y)
    z <- suppressMessages(icesDatras::getIndices(survey = survey, year = y,
                                     quarter = quarter, species = species))
    if (identical(z, FALSE))
      return(NULL)
    names(z) <- sub(" .*", "", names(z))   # remove garbage trails from colnames
    names(z) <- sub("Age_", "", names(z))  # rename Age_0 to 0
    z
  })
  out <- do.call(rbind, out)

  # extract columns of main interest
  out <- out[c("Year", 0:15)]
  out <- out[sapply(out, function(x) !all(is.na(x)))]

  # return
  out
}

#' Get Survey Indices for All Years
#'
#' Get age-based indices of abundance by species and survey.
#'
#' @param survey the survey acronym, e.g. NS-IBTS.
#' @param quarter the quarter of the year the survey took place, i.e. 1, 2, 3 or 4.
#' @param species the Aphia species code for the species of interest.
#' @param quiet Boolean (default FALSE)
#'
#' @return
#' A data frame containing Year in the first column and ages in subsequent columns.
#'
#' @examples
#' \dontrun{
#' haddock_aphia <- icesVocab::findAphia("haddock")
#' index <- getIndicesAllYears2(survey = "NS-IBTS", quarter = 3, species = haddock_aphia)
#' str(index)
#' }
#'
#' @export

getIndicesAllYears2 <- function(survey, quarter, species, quiet=FALSE) {
  # check survey name
  if (!icesDatras::checkSurveyOK(survey)) return(FALSE)

  dov <- icesDatras::getDatrasDataOverview(survey)[[survey]]
  as.integer(rownames(dov)[as.logical(dov[,quarter])])

  # loop over years
  out <- lapply(icesDatras::getSurveyYearList(survey), function(y) {
    message("* ", y)
    z <- suppressMessages(icesDatras::getIndices(survey = survey, year = y,
                                     quarter = quarter, species = species))
    if (identical(z, FALSE))
      return(NULL)
    names(z) <- sub(" .*", "", names(z))  # remove garbage trails from colnames
    z
  })

  do.call(rbind, out)

  # return
  out
}
