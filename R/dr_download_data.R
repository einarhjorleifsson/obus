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
