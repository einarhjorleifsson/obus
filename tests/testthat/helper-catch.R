# Synthetic hauls, species and catch shared by the dr_add_catch() and
# dr_summarise_*() tests. Alpha is caught in h1 (two records, as HL allows),
# h2 (a record with no value) and h4; Beta in h5 only.

hauls <- function() {
  data.frame(
    .id     = c("h1", "h2", "h3", "h4", "h5", "h6"),
    Survey  = "S",
    Year    = c(2000L, 2000L, 2000L, 2001L, 2001L, 2001L),
    Quarter = 1L,
    stringsAsFactors = FALSE
  )
}

species <- function() {
  data.frame(Valid_Aphia = c(1L, 2L), latin = c("Alpha alpha", "Beta beta"),
             stringsAsFactors = FALSE)
}

# Alpha: caught in h1 (two records, as HL allows), h2 (a record with no value),
# and in 2001 in h4. Beta: caught nowhere in 2000, in h5 in 2001.
catch_source <- function() {
  data.frame(
    .id = c("h1", "h1", "h2", "h4", "h5"),
    Valid_Aphia = c(1L, 1L, 1L, 1L, 2L),
    SpeciesValidity = c("1", "5", "1", "1", "1"),
    n_totalnumber      = c(3, 2, NA, 4, 7),
    n_totalnumber_hour = c(6, 4, NA, 8, 14),
    n_haul             = c(3, 2, NA, 4, 7),
    w_haul             = c(30, 20, NA, 40, 70),
    w_hour             = c(60, 40, NA, 80, 140),
    stringsAsFactors = FALSE
  )
}
