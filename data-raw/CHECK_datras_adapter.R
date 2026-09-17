# Can DATRAS/DATRASextra run on obus's published tables instead of raw HL?
#
# Run by hand. This builds a `datras_raw` object whose HL comes ONLY from
# HL_length + HL_summary (never from raw HL), then runs DATRASextra's own
# downstream functions on it, unmodified, and compares against the same
# functions run on DATRASextra's bundled `dab`.
#
# The adapter is the whole "minor tweak": one opus::op_rename() call, DATRAS's
# derived HH columns, and a reshape of the two catch tables into the one long
# HL frame DATRAS expects. No arithmetic on counts. It used to be defined
# below; it now ships as obus::dr_get_datras(), and this script is what
# validates it.
#
# CA is out of scope here (`ca = FALSE`) -- obus publishes no CA-derived
# table, so nothing age- or individual-weight-based is testable against the
# two catch tables, which is what this script is about.

suppressMessages({
  library(dplyr)
  ## Needs DATRAS >= 1.1.1 and DATRASextra >= 0.4.0 -- both GitHub-only, and
  ## calc_stratified_index() exists only in the latter:
  ##   remotes::install_github("DTUAqua/DATRAS/DATRAS")
  ##   remotes::install_github("tokami/DATRASextra")
  ## Verified against 1.1.1 / 0.4.0 on 2026-09-04: adapter 11/11, interop
  ## 25/25; re-run 2026-09-11 against the shipped dr_get_datras(), still 11/11
  ## with every gap 0.
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
# THE ADAPTER is now obus::dr_get_datras(), promoted out of this script on
# 2026-09-09 -- it had also been pasted verbatim into
# datrasdoodle2/interoperability.qmd, so there were three copies to drift.
# This script is what validates it, so it deliberately calls the SHIPPED
# function rather than a local definition.
#
# haulval/stdspec are passed explicitly because the packaged defaults are NULL
# (obus does not filter unless asked); `dab` came through clean_datras(), which
# applies both, so matching it needs them named.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
hdr("0. build a datras_raw from HL_length + HL_summary")
dab <- get("dab")
APHIA <- 127139L
obj <- dr_get_datras("NS-IBTS", 2020:2023, c(1L, 3L), aphia = APHIA,
                    ca = FALSE, haulval = "V", stdspec = "1")
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

hdr("7. row-count identity -- HL is HL_length + HL_summary's bulk-only rows")
# AGENTS.md states this as a relation rather than as row counts, because the
# identity survives the archive growing and the counts do not (Working
# Principle 8). This is where it is actually checked.
#
# The filters are not re-specified: the haul set comes from obj's own HH and
# the species from APHIA, which is exactly what .dr_datras_hl()'s keep() and
# .dr_datras_fetch()'s by_species() apply. Re-typing survey/years/quarters
# here would be a second copy to drift, and a mis-filtered check is worse
# than none.
ids <- obj[["HH"]][["haul.id"]]
src_len <- dr_con("HL_length") |>
  dplyr::filter(.id %in% ids, Valid_Aphia %in% APHIA) |>
  dplyr::collect()
src_smry <- dr_con("HL_summary") |>
  dplyr::filter(.id %in% ids, Valid_Aphia %in% APHIA) |>
  dplyr::collect()
n_len  <- nrow(src_len)
n_bulk <- nrow(dplyr::anti_join(
  src_smry, dplyr::distinct(src_len, .id, Valid_Aphia, SpeciesValidity),
  by = c(".id", "Valid_Aphia", "SpeciesValidity")))

ok("HL row count is HL_length + HL_summary bulk-only, exactly",
   nrow(obj[["HL"]]) == n_len + n_bulk,
   sprintf("HL %s | HL_length %s + bulk-only %s = %s",
           nrow(obj[["HL"]]), n_len, n_bulk, n_len + n_bulk))

# Stronger than the total: the two sources must land on the right side of the
# LngtCm split, so a compensating error in both cannot pass.
ok("the length/no-length split matches the two sources row for row",
   sum(!is.na(obj[["HL"]]$LngtCm)) == n_len &&
     sum(is.na(obj[["HL"]]$LngtCm)) == n_bulk,
   sprintf("with length %s (expect %s) | without %s (expect %s)",
           sum(!is.na(obj[["HL"]]$LngtCm)), n_len,
           sum(is.na(obj[["HL"]]$LngtCm)), n_bulk))

# The sibling identity -- CA is raw CA minus its HH-orphans -- is NOT checked
# here: this script runs ca = FALSE by design (see the header), so there is no
# CA component to count. Verified by hand per-survey 2026-09-17 (NIGFS, exact).

hdr(sprintf("RESULT: %d checks passed, %d showed a difference", PASS, FAIL))
