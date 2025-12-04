check_url_exists <- function(urls) {
  sapply(urls, function(file_url) {
    con <- url(file_url)
    result <- try(open(con), silent = TRUE)
    exists <- !inherits(result, "try-error")
    if (exists) close(con)
    exists
  })
}
