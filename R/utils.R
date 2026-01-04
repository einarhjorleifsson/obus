check_url_exists <- function(urls) {
  sapply(urls, function(file_url) {
    con <- url(file_url)
    result <- try(open(con), silent = TRUE)
    exists <- !inherits(result, "try-error")
    if (exists) close(con)
    exists
  })
}

check_nas_and_zeros <- function(x, y) {
  dplyr::case_when(x == 0 & y == 0 ~ "0_0",
                   is.na(x) & y == 0 ~ "na_0",
                   x == 0 & is.na(y) ~ "0_na",
                   is.na(x) & is.na(y) ~ "na_na",
                   dplyr::near(x, y) == TRUE ~ "near",
                   dplyr::near(x, y) == FALSE ~ "different",
                   .default = "something else")
}
