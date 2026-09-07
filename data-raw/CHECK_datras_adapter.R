# Can DATRAS/DATRASextra run on obus's published tables instead of raw HL?
#
# Run by hand. This builds a `datras_raw` object whose HL comes ONLY from
# HL_length + HL_summary (never from raw HL), then runs DATRASextra's own
# downstream functions on it, unmodified, and compares against the same
# functions run on DATRASextra's bundled `dab`.
#
# The adapter below is the whole "minor tweak": one opus::op_rename() call,
# DATRAS's five derived HH columns, and a reshape of the two catch tables into
# the one long HL frame DATRAS expects. ~60 lines, no arithmetic on counts.
#
# CA is out of scope by construction -- obus publishes no CA-derived table, so
# nothing age- or individual-weight-based is testable here.

suppressMessages({
  library(dplyr)
  ## Needs DATRAS >= 1.1.1 and DATRASextra >= 0.4.0 -- both GitHub-only, and
  ## calc_stratified_index() exists only in the latter:
  ##   remotes::install_github("DTUAqua/DATRAS/DATRAS")
  ##   remotes::install_github("tokami/DATRASextra")
  ## Verified against 1.1.1 / 0.4.0 on 2026-09-04: adapter 11/11, interop 25/25.
  ## (This used to pkgload::load_all() the repos from absolute paths, which
  ## only worked on one machine.)
  library(DATRAS)
  library(DATRASextra)
})
library(obus)

PASS <- 0L; FAIL <- 0L
ok <- function(label, passed, detail = "") {
  if (isTRUE(passed)) PASS <<- PASS + 1L else FAIL <<- FAIL + 1L
  cat(sprintf("  [%s] %-52s %s\n", if (isTRUE(passed)) "OK  " else "DIFF", label, detail))
}
hdr <- function(x) cat(sprintf("\n== %s %s\n", x, strrep("=", max(0, 62 - nchar(x)))))

# ---------------------------------------------------------------------------
# THE ADAPTER
# ---------------------------------------------------------------------------
dr_as_datras <- function(survey, years, quarters, aphia,
                         haulval = "V", stdspec = "1") {

  ## HH -- raw + .id, renamed to ICES legacy names, plus the five columns
  ## DATRAS::addExtraVariables() derives and DATRASextra's defaults expect.
  hh <- dr_con("HH") |>
    filter(Survey == survey, Year %in% years, Quarter %in% quarters,
           HaulValidity %in% haulval, StandardSpeciesCode %in% stdspec) |>
    collect() |>
    opus::op_rename("HH", to = "legacy") |>
    mutate(
      haul.id      = .id,
      lon          = ShootLong,
      lat          = ShootLat,
      abstime      = Year + (Month - 1) / 12 + (Day - 1) / 365,
      timeOfYear   = (Month - 1) / 12 + (Day - 1) / 365,
      ## opus stages TimeShot as character (HHMM keeps its leading zero), so
      ## it needs coercing -- the same assumption that currently breaks
      ## DATRAS::addExtraVariables() on Year.
      TimeShotHour = as.integer(as.integer(TimeShot) / 100) +
                     (as.integer(TimeShot) %% 100) / 60
    )

  ## HL -- from the two published catch tables ONLY.
  len <- dr_con("HL_length") |>
    filter(Survey == survey, Year %in% years, Quarter %in% quarters,
           Valid_Aphia %in% aphia) |> collect() |> filter(.id %in% hh$haul.id)
  smry <- dr_con("HL_summary") |>
    filter(Survey == survey, Year %in% years, Quarter %in% quarters,
           Valid_Aphia %in% aphia) |> collect() |> filter(.id %in% hh$haul.id)

  ## accuracy <-> LngtCode is a bijection on the five valid codes, and
  ## LengthClass is mm-scaled for "." and "0", cm-scaled for "1"/"2"/"5".
  code_of <- c("0.1" = ".", "0.5" = "0", "1" = "1", "2" = "2", "5" = "5")
  totals  <- smry |> select(haul.id = .id, Valid_Aphia, SpeciesValidity,
                            TotalNo = n_totalnumber, CatCatchWgt = w_haul)

  hl_len <- len |>
    transmute(
      haul.id = .id, Survey, Year, Quarter, Valid_Aphia,
      Species     = latin,
      SpecCode    = Valid_Aphia,
      SpecVal     = as.integer(SpeciesValidity),
      SpeciesValidity,
      Sex         = coalesce(SpeciesSex, ""),
      DevStage    = DevelopmentStage,
      LenMeasType = LengthType,
      LngtCode    = unname(code_of[as.character(accuracy)]),
      LngtClas    = as.integer(if_else(accuracy <= 0.5, length_mm,
                                       as.integer(length_mm / 10L))),
      LngtCm      = length_cm,
      HLNoAtLngt  = n_measured,
      ## Count is DATRAS's raised number-at-length, which IS n_haul.
      Count       = n_haul,
      ## SubFactor is not in the published grain; the raised count already
      ## carries it, and nothing downstream reads it. Reported where it is
      ## recoverable so the column is not a lie.
      SubFactor   = n_haul / n_measured
    )

  ## Species recorded for a haul but never measured: no row in HL_length, so
  ## they come from HL_summary with a missing length -- which is exactly how
  ## DATRAS carries them, and what species richness needs.
  hl_bulk <- smry |>
    anti_join(distinct(len, .id, Valid_Aphia, SpeciesValidity),
              by = c(".id", "Valid_Aphia", "SpeciesValidity")) |>
    transmute(
      haul.id = .id, Survey, Year, Quarter, Valid_Aphia,
      Species = latin, SpecCode = Valid_Aphia,
      SpecVal = as.integer(SpeciesValidity), SpeciesValidity,
      Sex = "", DevStage = NA_character_, LenMeasType = NA_character_,
      LngtCode = NA_character_, LngtClas = NA_integer_, LngtCm = NA_real_,
      HLNoAtLngt = NA_real_, Count = NA_real_, SubFactor = NA_real_
    )

  hl <- bind_rows(hl_len, hl_bulk) |>
    left_join(totals, by = c("haul.id", "Valid_Aphia", "SpeciesValidity"),
              na_matches = "na") |>
    left_join(select(hh, haul.id, HaulDur, DataType), by = "haul.id") |>
    select(-SpeciesValidity)

  ## DATRAS's own type conventions: factors everywhere a string lives, Year and
  ## Quarter as factors, haul.id levelled on HH so subset() stays consistent.
  lev <- levels(factor(hh$haul.id))
  facify <- function(d) {
    for (k in names(d)) if (is.character(d[[k]])) d[[k]] <- factor(d[[k]])
    d$haul.id <- factor(as.character(d$haul.id), levels = lev)
    d$Year    <- factor(d$Year)
    d$Quarter <- factor(d$Quarter)
    d
  }
  hh <- facify(hh); hl <- facify(hl)

  d <- list(CA = NULL, HH = as.data.frame(hh), HL = as.data.frame(hl))
  class(d) <- c("datras_raw", "DATRASraw")
  d
}

# ---------------------------------------------------------------------------
hdr("0. build a datras_raw from HL_length + HL_summary")
dab <- get("dab")
APHIA <- 127139L
obj <- dr_as_datras("NS-IBTS", 2020:2023, c(1L, 3L), APHIA)
cat(sprintf("  HH %s rows, %s cols | HL %s rows, %s cols\n",
            nrow(obj[["HH"]]), ncol(obj[["HH"]]),
            nrow(obj[["HL"]]), ncol(obj[["HL"]])))
ok("the object satisfies DATRASextra's own class check",
   !inherits(try(DATRASextra:::.check_class_datras(obj), silent = TRUE), "try-error"))

## Compare on hauls both sides have (`dab` is a stale 2026-03-04 snapshot;
## see CHECK_datras_interop.R section 6).
common <- intersect(as.character(dab[["HH"]]$haul.id),
                    as.character(obj[["HH"]]$haul.id))
sub_common <- function(x) {
  x[["HH"]] <- x[["HH"]][as.character(x[["HH"]]$haul.id) %in% common, ]
  x[["HL"]] <- x[["HL"]][as.character(x[["HL"]]$haul.id) %in% common, ]
  x
}
A <- sub_common(obj)          # obus-backed
B <- sub_common(dab)          # DATRAS-backed
cat(sprintf("  comparing on %s common hauls\n", length(common)))

hdr("1. add_numbers_at_length() -- does the N matrix come out the same?")
A2 <- add_numbers_at_length(A)
B2 <- add_numbers_at_length(B)
NA_ <- A2[["HH"]][["N"]]; NB <- B2[["HH"]][["N"]]
ok("both produce an N matrix", is.matrix(NA_) && is.matrix(NB),
   sprintf("obus %sx%s | dab %sx%s", nrow(NA_), ncol(NA_), nrow(NB), ncol(NB)))
ok("identical length bins", identical(colnames(NA_), colnames(NB)),
   sprintf("%s vs %s bins", ncol(NA_), ncol(NB)))
if (identical(dim(NA_), dim(NB))) {
  M <- NA_[rownames(NB), , drop = FALSE]
  ok("cell values identical", max(abs(M - NB)) == 0,
     sprintf("max gap %s over %s cells", max(abs(M - NB)), length(NB)))
}

hdr("2. add_total_numbers_by_haul() -- HaulN")
A3 <- add_total_numbers_by_haul(A2); B3 <- add_total_numbers_by_haul(B2)
ha <- setNames(as.numeric(A3[["HH"]]$HaulN), as.character(A3[["HH"]]$haul.id))
hb <- setNames(as.numeric(B3[["HH"]]$HaulN), as.character(B3[["HH"]]$haul.id))
ok("HaulN identical per haul", max(abs(ha[names(hb)] - hb)) == 0,
   sprintf("max gap %s over %s hauls", max(abs(ha[names(hb)] - hb)), length(hb)))

hdr("3. add_total_weight_by_haul(lw_source = 'lookup') -- HaulWgt")
A4 <- add_total_weight_by_haul(A3, lw_source = "lookup", per_minute = TRUE)
B4 <- add_total_weight_by_haul(B3, lw_source = "lookup", per_minute = TRUE)
wa <- setNames(as.numeric(A4[["HH"]]$HaulWgt), as.character(A4[["HH"]]$haul.id))
wb <- setNames(as.numeric(B4[["HH"]]$HaulWgt), as.character(B4[["HH"]]$haul.id))
ok("HaulWgt identical per haul", max(abs(wa[names(wb)] - wb)) < 1e-6,
   sprintf("max gap %.3g", max(abs(wa[names(wb)] - wb))))

hdr("4. add_swept_area() then calc_stratified_index()")
A5 <- add_swept_area(A4)
B5 <- add_swept_area(B4)
sa <- setNames(as.numeric(A5[["HH"]]$SweptArea), as.character(A5[["HH"]]$haul.id))
sb <- setNames(as.numeric(B5[["HH"]]$SweptArea), as.character(B5[["HH"]]$haul.id))
ok("SweptArea identical per haul",
   isTRUE(all.equal(unname(sa[names(sb)]), unname(sb))),
   sprintf("max gap %.3g", max(abs(sa[names(sb)] - sb), na.rm = TRUE)))
ia <- calc_stratified_index(A5, value_var = "HaulN", strata_var = "StatRec",
                            cpue_method = "per_hour", by = "Year")
ib <- calc_stratified_index(B5, value_var = "HaulN", strata_var = "StatRec",
                            cpue_method = "per_hour", by = "Year")
cat("  obus-backed index:\n"); print(as.data.frame(ia[, c("Year", "index", "cv")]))
ok("stratified index identical",
   isTRUE(all.equal(ia$index, ib$index)) && isTRUE(all.equal(ia$cv, ib$cv)),
   sprintf("max |index gap| %.3g", max(abs(ia$index - ib$index))))

hdr("5. as_table() and check_lengths()")
ta <- as_table(A5, type = "long"); tb <- as_table(B5, type = "long")
ok("as_table() gives the same shape and columns",
   nrow(ta) == nrow(tb) && identical(names(ta), names(tb)),
   sprintf("%s x %s vs %s x %s", nrow(ta), ncol(ta), nrow(tb), ncol(tb)))
ca <- suppressWarnings(check_lengths(A5, plot = FALSE))
cb <- suppressWarnings(check_lengths(B5, plot = FALSE))
ok("check_lengths() summary statistics identical",
   isTRUE(all.equal(attr(ca, "length_check")$lPars,
                    attr(cb, "length_check")$lPars)))

hdr("6. species richness -- the bulk-only species HL_length alone would lose")
rich <- function(x) {
  hl <- x[["HL"]]
  length(unique(paste(hl$haul.id, hl$Valid_Aphia)))
}
ok("HL carries bulk-recorded species too, not only measured ones",
   sum(is.na(obj[["HL"]]$LngtCm)) > 0,
   sprintf("%s rows have no length (from HL_summary), %s have one",
           sum(is.na(obj[["HL"]]$LngtCm)), sum(!is.na(obj[["HL"]]$LngtCm))))

hdr(sprintf("RESULT: %d checks passed, %d showed a difference", PASS, FAIL))
