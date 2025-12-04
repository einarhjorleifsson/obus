dr_open_sesame <- function(recordType = "HH") {

  # input arguments check needed
  #  only accept a vector of length 1 and only being one of "HH", "HL" and "CA"

  file_urls <- paste0("https://heima.hafro.is/~einarhj/datras/RecordType=",
                  recordType,
                  "/Year=",
                  1965:format(Sys.Date(), "%Y"),
                  "/part-0.parquet")

  # Check if files exists
  exists <- check_url_exists(file_urls)
  file_urls <- file_urls[exists]

  return(duckdbfs::open_dataset(file_urls))

}
