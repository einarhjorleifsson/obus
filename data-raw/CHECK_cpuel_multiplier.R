# Live check: what does ICES's OWN CPUEL product do about DataType "C"?
#
# Run by hand. Nothing here is package code and nothing is published. This is
# the reproducible form of the evidence cited in two places that otherwise
# assert it:
#
#   data-raw/hl_flag_code.csv    CNT_C_SUBFACTOR_CONFLICT, CNT_SF_RESET
#   opus  inst/DATRAS-known-issues.yaml   hl_datatype_c_with_subfactor_gt1
#
# THE QUESTION. Under DataType "C", how many multipliers raise HLNoAtLngt to a
# catch? Three sources, and they do not agree:
#
#   WKABSENS 2021, 3.3 step 17   ONE  -- "Multiplier = HaulDur/60 if DataType
#                                        in ('C'); Multiplier = SubFactor if
#                                        DataType in ('S','R')"
#   DATRAS pkg, before 2023      ONE  -- exactly the line above, in code
#   DATRAS pkg, 880bit 553       TWO  -- 2023-04-11, over the note "some BITS
#                                        hauls (all LT and some DK) have
#                                        dataType C but SubFactor>1"
#   obus dr_add_n_and_cpue()     TWO
#
# obus followed WKABSENS for one commit in September 2026 and reverted. This
# script is what should have been run first. It asks CPUEL -- the ICES Data
# Centre's own published CPUE-per-length-per-haul product -- which answer it
# gives, on the 36 hauls where the two answers differ.
#
# WHY CPUEL SETTLES IT. It is ICES's production code, not a workshop recipe and
# not a third party's. If CPUE_number_per_hour matches the two-multiplier figure
# then the Data Centre applies two, and WKABSENS -- an ICES publication --
# documents a rule ICES itself does not follow.
#
# SECTION 3 IS THE ONE THAT MATTERS ANALYTICALLY. Having established what CPUEL
# does under "C", it asks the harder question: does CPUEL ever reconcile the
# length rows against TotalNo? Answered on the CNT_SF_RESET population, where
# the two disagree by a median factor of ~2.7.
#
# Needs network access only -- no DATRAS/DATRASextra, unlike the other two
# CHECK scripts. Run after DATASET_hl_flag.R, since it reads hl_flag.

suppressMessages(library(dplyr))
library(obus)

PASS <- 0L; FAIL <- 0L
ok <- function(label, passed, detail = "") {
  if (isTRUE(passed)) PASS <<- PASS + 1L else FAIL <<- FAIL + 1L
  cat(sprintf("  [%s] %-56s %s\n", if (isTRUE(passed)) "OK  " else "DIFF",
              label, detail))
}
note <- function(...) cat(sprintf("  [note] %s\n", sprintf(...)))
hdr  <- function(x) cat(sprintf("\n== %s %s\n", x, strrep("=", max(0, 66 - nchar(x)))))

# CPUEL is not an obus table -- Tier 2 is out of scope for dr_con() -- so it is
# opened directly. Local build outputs are used for obus's side when present so
# the check can run against an unpublished rebuild.
CPUEL <- "https://heima.hafro.is/~einarhj/datras/CPUEL.parquet"
LOCAL <- "data-raw/to_https"
src <- function(tbl) {
  f <- file.path(LOCAL, paste0(tbl, ".parquet"))
  if (file.exists(f)) duckdbfs::open_dataset(f) else dr_con(tbl)
}

cpuel <- duckdbfs::open_dataset(CPUEL)
flag  <- src("hl_flag")
len   <- src("HL_length")
hl    <- src("HL")

# CPUEL's own key. It ships no Country or StNo, but the staged copy carries the
# same eight-field `.id` obus builds, so the join is direct rather than the
# lossy Survey:Year:Quarter:Ship:Gear:HaulNo match the raw product forces.
#
# CPUEL is filtered to SpeciesValidity 1 and aggregated over sex and category,
# so obus's side is reduced to match before any comparison.
cells <- function(code) {
  tgt <- flag |> filter(code == !!code) |> distinct(.id, Valid_Aphia)
  o <- len |>
    semi_join(tgt, by = c(".id", "Valid_Aphia")) |>
    filter(SpeciesValidity == "1") |>
    group_by(.id, Valid_Aphia, length_mm) |>
    summarise(obus = sum(n_hour, na.rm = TRUE), .groups = "drop")
  i <- cpuel |>
    semi_join(tgt, by = c(".id", "aphia" = "Valid_Aphia")) |>
    group_by(.id, aphia, length_mm) |>
    summarise(cpuel = sum(n_hour, na.rm = TRUE), .groups = "drop")
  inner_join(o, i, by = c(".id", "Valid_Aphia" = "aphia", "length_mm")) |>
    filter(obus > 0, cpuel > 0) |>
    collect()
}
# Relative, because CPUE values span several orders of magnitude and an
# absolute half-fish tolerance is meaningless once a rate is in the thousands.
agree <- function(d) mean(abs(d$cpuel - d$obus) <= pmax(0.5, 1e-4 * d$obus))

# ---------------------------------------------------------------------------
hdr("1. scope: which surveys does CPUEL cover at all?")
# Not a formality. 99.9% of CNT_SF_RESET is Can-Mar, and if Can-Mar is absent
# here then ICES computes no CPUE product from it -- which is the mechanism
# behind "nobody has ever found this", not a guess about attention.
cov <- cpuel |> count(Survey) |> collect() |> arrange(desc(n))
note("CPUEL covers %d surveys: %s", nrow(cov), paste(sort(cov$Survey), collapse = ", "))
ok("Can-Mar is absent from CPUEL", !"Can-Mar" %in% cov$Survey,
   sprintf("so its %s flagged records get no ICES product",
           format(flag |> filter(code == "CNT_SF_RESET") |> count() |> pull(n),
                  big.mark = ",")))

# ---------------------------------------------------------------------------
hdr("2. DataType C: one multiplier or two?")
conf <- flag |> filter(code == "CNT_C_SUBFACTOR_CONFLICT") |> distinct(.id)
n_conf <- conf |> count() |> pull(n)
n_in   <- conf |> semi_join(distinct(cpuel, .id), by = ".id") |> count() |> pull(n)
ok("every conflict haul is in CPUEL", n_in == n_conf,
   sprintf("%d of %d", n_in, n_conf))

# obus's n_hour under "C" is NumberAtLength * SubsamplingFactor (two
# multipliers). Dividing by the declared factor reconstructs what WKABSENS's
# single-multiplier recipe would have published, so both candidates are
# compared against CPUEL on the same cells.
d <- cells("CNT_C_SUBFACTOR_CONFLICT") |>
  inner_join(
    hl |> semi_join(conf, by = ".id") |>
      group_by(.id, Valid_Aphia) |>
      summarise(ssf = max(SubsamplingFactor, na.rm = TRUE), .groups = "drop") |>
      collect(),
    by = c(".id", "Valid_Aphia")) |>
  mutate(one_mult = obus / ssf)

r2 <- median(d$cpuel / d$obus)
r1 <- median(d$cpuel / d$one_mult)
note("%s matched cells over %d hauls, SubFactor %.2f to %.2f",
     format(nrow(d), big.mark = ","), n_conf, min(d$ssf), max(d$ssf))
note("median CPUEL / two-multiplier : %.4f", r2)
note("median CPUEL / one-multiplier : %.4f   (= median SubFactor %.4f)",
     r1, median(d$ssf))
ok("CPUEL matches the TWO-multiplier figure", abs(r2 - 1) < 0.01,
   sprintf("ratio %.4f", r2))
ok("CPUEL does NOT match the one-multiplier figure", abs(r1 - 1) > 0.1,
   sprintf("ratio %.4f", r1))
# A CONFOUND, and a DOCUMENTED one -- found by this script failing an earlier,
# naiver version of the check below. CPUEL/obus is not unimodal: it piles up at
# 1.00 and again at 1.55, with smaller modes at 1.20 and 1.10.
#
# These are the BITS gear-conversion factors, and ICES documents them plainly:
# "In case of cod (Gadus morhua), conversion factors are used to transfer the
# CPUE values of the national and the small TVS into CPUE values of the large
# TVL" (Indices_Calculation_Steps_BITS, Annex 3, table published at
# https://datras.ices.dk/Documents/Manuals/ConversionFactor_TVL.csv; Oeberst
# 2013, WD 2 in WKBALT). CPUEL applies them; obus does not. So CPUEL is not a
# pure raising of HL, and any cell-level comparison against it has to expect
# this.
#
# THE MEASUREMENT ADJUDICATES AN OPEN DISCREPANCY. vignettes/articles/
# datras-conventions.Rmd records this as D20, classified "Contradiction":
# ICES states the conversion's scope three ways in one document -- cod only,
# unconditionally ("CPUE are converted to standard trawl by multiplying with a
# conversion factor"), and as an undefined "apply fishing power". The data says
# cod only, and says it cleanly. Every one of the 839 Gadus morhua cells here
# carries a non-unit factor and every other species carries exactly 1.00.
#
# The factor is also a step function of length, exactly as Annex 3's
# gear x species x length-class table is shaped:
#
#     1.10   5-24 cm    130 cells
#     1.20  25-29 cm    132 cells
#     1.55  30-90 cm    577 cells
#
# The discriminator below is what the non-unit ratio tracks. A multiplier
# disagreement would track SubFactor; a gear conversion tracks gear x species.
# Either way the conversion multiplies both candidate figures equally, so it
# cannot change which one CPUEL agrees with.
d <- d |> mutate(gear = sub("^([^:]*:){5}([^:]*):.*", "\\2", .id))
modes <- d |> mutate(rr = round(cpuel / obus, 3)) |> count(rr, sort = TRUE)
note("ratio modes: %s", paste(sprintf("%.2f (%s cells)", modes$rr,
                                      format(modes$n, big.mark = ",")),
                              collapse = ", "))
ok("the dominant mode is exactly 1", abs(modes$rr[1] - 1) < 0.001,
   sprintf("%s of %s cells", format(modes$n[1], big.mark = ","),
           format(nrow(d), big.mark = ",")))

# Constant within gear x species (a conversion), not within SubFactor (a
# multiplier). Both measured the same way so the comparison is fair.
consistency <- function(g) {
  x <- d |> group_by(across(all_of(g))) |>
    filter(n() >= 20) |>
    summarise(tight = mean(abs(cpuel / obus - median(cpuel / obus)) < 0.01),
              .groups = "drop")
  mean(x$tight)
}
by_sp <- consistency(c("gear", "Valid_Aphia")); by_sf <- consistency("ssf")
note("ratio is constant within gear x species: %.1f%% of cells", 100 * by_sp)
note("ratio is constant within SubFactor    : %.1f%% of cells", 100 * by_sf)
ok("the non-unit ratio tracks species, not SubFactor", by_sp > by_sf + 0.1,
   sprintf("%.0f%% vs %.0f%% -- a gear conversion, not a raising difference",
           100 * by_sp, 100 * by_sf))

# D20's resolution, as a check rather than a note. 126436 is Gadus morhua.
nonunit <- d |> filter(abs(cpuel / obus - 1) >= 0.01)
cod     <- d |> filter(Valid_Aphia == 126436L)
ok("every non-unit cell is Gadus morhua (D20: scope is cod only)",
   mean(nonunit$Valid_Aphia == 126436L) > 0.99,
   sprintf("%d of %d", sum(nonunit$Valid_Aphia == 126436L), nrow(nonunit)))
ok("and every cod cell is non-unit",
   mean(abs(cod$cpuel / cod$obus - 1) >= 0.01) > 0.99,
   sprintf("%d of %d", sum(abs(cod$cpuel / cod$obus - 1) >= 0.01), nrow(cod)))

# THE ONE NON-COD CELL, chased down 2026-09-07 so nobody spends an hour on it
# again. It is why the two checks above are ">0.99" rather than "==1", and it
# is not an error in either product.
#
# BITS:2010:1:LT:LTDA:TVS:26052:7, Osmerus eperlanus. Raw HL: LengthCode "0"
# (millimetres), classes 95/180/185 mm, one fish each, SubFactor 2, NoMeas 3,
# TotalNo 6 -- internally consistent, and the CNT_C_SUBFACTOR_CONFLICT shape.
#
#   obus    95 -> 2, 180 -> 2, 185 -> 2      total 6/hour
#   CPUEL   90 -> 2, 180 -> 4                total 6/hour
#
# Both agree the haul held 6 smelt per hour. CPUEL floored 95 to 90 and merged
# 185 into the 180 bin; this comparison joins on exact length_mm, so a merged
# bin reads as a ratio of 2. A length-GRID difference, not a raising one.
#
# Archive-wide it is a real but partial property: CPUEL's length grid is not a
# faithful copy of the submitted one. Over BITS, 15,235 obus cells have no
# CPUEL partner at their exact length under the millimetre LengthCodes ("0":
# 13,074, 64.2% of them sub-centimetre; ".": 2,161, 100% sub-centimetre).
#
# Two reasons not to draw a general rule from it. CPUEL is INCONSISTENT --
# under LengthCode "0" it retains sub-centimetre resolution 48.8% of the time,
# so it does not simply floor. And it is NOT what drives the low agreement
# rates measured in section 4: the worst-agreeing group is LengthCode "1"
# (centimetres, 75.6% over 510,933 cells), where binning cannot apply at all.
# That disagreement is the cod gear conversion plus CPUEL's batch vintage.
odd <- nonunit |> filter(Valid_Aphia != 126436L)
if (nrow(odd)) {
  note("non-cod non-unit cells (expected: 1, the length-grid one): %s",
       paste(sprintf("%s aphia %d at %d mm, ratio %.2f", odd$.id, odd$Valid_Aphia,
                     odd$length_mm, odd$cpuel / odd$obus), collapse = "; "))
}

# ---------------------------------------------------------------------------
hdr("3. does CPUEL ever reconcile the length rows against TotalNo?")
# CNT_SF_RESET is the population where it would show: SubFactor is declared 1
# while TotalNo implies a real factor (median ~2.7 archive-wide). If CPUEL
# reconciled, it would sit near TotalNo and disagree with obus by that factor.
for (cd in c("CNT_SF_RESET", "CNT_SF_UNRECONCILED")) {
  d2 <- cells(cd)
  if (!nrow(d2)) { note("%s: no cells in CPUEL's surveys", cd); next }
  note("%-20s %s cells, %.1f%% agree, median ratio %.3f", cd,
       format(nrow(d2), big.mark = ","), 100 * agree(d2),
       median(d2$cpuel / d2$obus))
  ok(sprintf("CPUEL reproduces obus on %s", cd),
     abs(median(d2$cpuel / d2$obus) - 1) < 0.01,
     "i.e. it does not correct toward TotalNo")
}

# ---------------------------------------------------------------------------
hdr("4. baseline, so section 3's agreement rate is not over-read")
# CPUEL is a lagging batch product (DateofCalculation on the conflict hauls
# spans 2018 to 2026), so cell-level agreement is well short of 100% even where
# nothing is wrong. The MEDIAN RATIO is the statistic that carries the rule
# question; the agreement rate only says how noisy the vintage is.
base <- len |> filter(Survey == "BITS", SpeciesValidity == "1") |>
  group_by(.id, Valid_Aphia, length_mm) |>
  summarise(obus = sum(n_hour, na.rm = TRUE), .groups = "drop") |>
  inner_join(cpuel |> filter(Survey == "BITS") |>
               group_by(.id, aphia, length_mm) |>
               summarise(cpuel = sum(n_hour, na.rm = TRUE), .groups = "drop"),
             by = c(".id", "Valid_Aphia" = "aphia", "length_mm")) |>
  filter(obus > 0, cpuel > 0) |>
  mutate(country = split_part(.id, ":", 4L)) |>
  group_by(country) |>
  summarise(cells = n(),
            # as.integer() is load-bearing: dbplyr renders mean(<logical>)
            # as AVG(boolean), which DuckDB refuses to bind.
            pct = 100 * mean(as.integer(abs(cpuel - obus) <=
                                          pmax(0.5, 1e-4 * obus)), na.rm = TRUE),
            ratio = median(cpuel / obus), .groups = "drop") |>
  collect() |> arrange(desc(cells))
for (i in seq_len(nrow(base))) {
  note("BITS %-7s %8s cells  %5.1f%% agree  ratio %.3f", base$country[i],
       format(base$cells[i], big.mark = ","), base$pct[i], base$ratio[i])
}
ok("median ratio is 1 for every BITS country", all(abs(base$ratio - 1) < 0.01),
   "no systematic scaling difference anywhere")

# ---------------------------------------------------------------------------
hdr("5. is the gear conversion applied to any species but cod? (D21)")
# Section 2 established the conversion on 36 hauls of one gear. That is far too
# narrow a slice to conclude "cod only", so this runs the same comparison over
# every BITS cell -- ~1.1M of them -- and asks which species CPUEL converts.
#
# It matters because BITS fishes TVS and TVL SIDE BY SIDE IN EVERY YEAR, not
# only across the 2001 standardisation. TVS -> TVL is exactly the conversion
# cod receives (1.10 below 25 cm, 1.20 at 25-29, 1.55 at 30 cm and above), so a
# species without a factor has two uncorrected gears sharing one column, one
# set of units, and no marker distinguishing them.
sp <- src("species") |> select(Valid_Aphia, latin)
all_o <- len |> filter(Survey == "BITS", SpeciesValidity == "1") |>
  group_by(.id, Valid_Aphia, length_mm) |>
  summarise(obus = sum(n_hour, na.rm = TRUE), .groups = "drop")
all_i <- cpuel |> filter(Survey == "BITS") |>
  group_by(.id, aphia, length_mm) |>
  summarise(cpuel = sum(n_hour, na.rm = TRUE), .groups = "drop")
per_sp <- inner_join(all_o, all_i,
                     by = c(".id", "Valid_Aphia" = "aphia", "length_mm")) |>
  filter(obus > 0, cpuel > 0) |>
  mutate(nonunit = if_else(abs(cpuel / obus - 1) >= 0.01, 1L, 0L)) |>
  group_by(Valid_Aphia) |>
  summarise(cells = n(), pct = 100 * mean(nonunit, na.rm = TRUE), .groups = "drop") |>
  left_join(sp, by = "Valid_Aphia") |>
  collect() |> arrange(desc(cells)) |> head(8)
for (i in seq_len(nrow(per_sp))) {
  note("%-30s %8s cells  %5.1f%% converted", per_sp$latin[i],
       format(per_sp$cells[i], big.mark = ","), per_sp$pct[i])
}
cod_row <- per_sp |> filter(Valid_Aphia == 126436L)
oth     <- per_sp |> filter(Valid_Aphia != 126436L)
ok("cod is gear-converted", nrow(cod_row) == 1 && cod_row$pct > 50,
   sprintf("%.1f%% of %s cells", cod_row$pct, format(cod_row$cells, big.mark = ",")))
ok("no other species is", all(oth$pct < 5),
   sprintf("max %.1f%% (%s)", max(oth$pct), oth$latin[which.max(oth$pct)]))

# The conversion table is the other half of the evidence: it is published per
# gear x species x length class, and it contains a single species. Read from
# imbus's copy of the ICES corpus when available -- optional, so the script
# still runs standalone.
tbl <- "~/R/Pakkar/imbus/DATRAS/external/BITS_ConversionFactor_to_TVL.csv"
if (file.exists(path.expand(tbl))) {
  cf <- utils::read.csv(path.expand(tbl), skip = 1, stringsAsFactors = FALSE)
  note("%s: %s rows, %d gears, species = %s", basename(tbl),
       format(nrow(cf), big.mark = ","), length(unique(cf$Gear)),
       paste(unique(cf$Species), collapse = ", "))
  ok("the published table itself covers exactly one species",
     length(unique(cf$Species)) == 1 && unique(cf$Species) == "Gadus morhua",
     sprintf("%d distinct", length(unique(cf$Species))))
} else {
  note("conversion table not found at %s -- skipping its check", tbl)
}

# The exposure. If TVS and TVL only straddled 2001 this would be a historical
# footnote; they do not.
gearsplit <- len |> filter(Survey == "BITS", Year >= 2001,
                           Valid_Aphia %in% c(127143L, 126436L)) |>
  inner_join(src("HH") |> select(.id, Gear), by = ".id") |>
  filter(Gear %in% c("TVS", "TVL")) |>
  count(Valid_Aphia, Gear) |> collect() |>
  group_by(Valid_Aphia) |> mutate(pct = 100 * n / sum(n)) |> ungroup()
for (a in c(126436L, 127143L)) {
  g <- gearsplit |> filter(Valid_Aphia == a)
  note("%-7s post-2001 gear split: %s", if (a == 126436L) "cod" else "plaice",
       paste(sprintf("%s %.0f%%", g$Gear, g$pct), collapse = " / "))
}
ok("both gears are still in use after 2001, for both species",
   all(gearsplit$pct > 5),
   "so the uncorrected gear effect is current, not historical")

# ---------------------------------------------------------------------------
hdr("6. does CPUEL preserve the submitted length grid? (D22)")
# Section 2's note explains one cell. This asserts the archive-wide shape of it,
# so D22's figures are reproducible rather than quoted.
#
# The claim has three parts, and the last two exist to STOP the first being
# over-read -- which is how it was over-read the first time round:
#   a) sub-centimetre classes are disproportionately dropped from CPUEL's grid
#   b) but CPUEL does not floor uniformly, so no rule can be stated
#   c) and this is NOT what drives cell disagreement -- the worst-agreeing
#      group is centimetre-coded data, where binning cannot apply at all
#
# Keyed on the LengthCode each haul x species was actually submitted under.
# Mixed-code groups are dropped rather than guessed at (a few hundred).
lc <- hl |> filter(!is.na(LengthClass), NumberAtLength != 0) |>
  group_by(.id, Valid_Aphia) |>
  summarise(lc = min(LengthCode, na.rm = TRUE), nlc = n_distinct(LengthCode),
            .groups = "drop") |>
  filter(nlc == 1)

bits_o <- len |> filter(Survey == "BITS", SpeciesValidity == "1") |>
  group_by(.id, Valid_Aphia, length_mm) |>
  summarise(obus = sum(n_hour, na.rm = TRUE), .groups = "drop")
bits_i <- cpuel |> filter(Survey == "BITS") |>
  group_by(.id, aphia, length_mm) |>
  summarise(cpuel = sum(n_hour, na.rm = TRUE), .groups = "drop")

# (a) obus cells with no CPUEL partner AT THAT EXACT LENGTH, on hauls CPUEL
# covers -- so a missing haul is never counted as a missing length.
orph <- bits_o |> inner_join(lc, by = c(".id", "Valid_Aphia")) |>
  anti_join(bits_i, by = c(".id", "Valid_Aphia" = "aphia", "length_mm")) |>
  semi_join(distinct(bits_i, .id), by = ".id") |>
  mutate(sub = if_else(length_mm %% 10L != 0L, 1L, 0L)) |>
  group_by(lc) |>
  summarise(orphans = n(), pct_sub = 100 * mean(sub, na.rm = TRUE), .groups = "drop") |>
  collect() |> arrange(desc(orphans))
for (i in seq_len(nrow(orph))) {
  note("LengthCode %-3s %7s orphaned cells, %5.1f%% sub-centimetre",
       orph$lc[i], format(orph$orphans[i], big.mark = ","), orph$pct_sub[i])
}
mm <- orph |> filter(lc %in% c("0", ".")); cm <- orph |> filter(lc == "1")
ok("sub-cm classes are disproportionately orphaned under mm codes",
   nrow(mm) == 2 && all(mm$pct_sub > 50),
   sprintf("%s orphans, %.0f-%.0f%% sub-cm",
           format(sum(mm$orphans), big.mark = ","), min(mm$pct_sub), max(mm$pct_sub)))
ok("and not at all under the centimetre code", nrow(cm) == 1 && cm$pct_sub < 1,
   sprintf("%.1f%% of %s", cm$pct_sub, format(cm$orphans, big.mark = ",")))

# (b) and (c) together, from the matched cells.
matched <- inner_join(bits_o, bits_i,
                      by = c(".id", "Valid_Aphia" = "aphia", "length_mm")) |>
  filter(obus > 0, cpuel > 0) |> inner_join(lc, by = c(".id", "Valid_Aphia")) |>
  mutate(m   = if_else(abs(cpuel - obus) <= pmax(0.5, 1e-4 * obus), 1L, 0L),
         sub = if_else(length_mm %% 10L != 0L, 1L, 0L)) |>
  group_by(lc) |>
  summarise(cells = n(), pct_agree = 100 * mean(m, na.rm = TRUE),
            pct_sub = 100 * mean(sub, na.rm = TRUE), .groups = "drop") |>
  collect() |> arrange(desc(cells))
for (i in seq_len(nrow(matched))) {
  note("LengthCode %-3s %9s matched, %5.1f%% agree, %5.1f%% sub-centimetre",
       matched$lc[i], format(matched$cells[i], big.mark = ","),
       matched$pct_agree[i], matched$pct_sub[i])
}
mm0 <- matched |> filter(lc == "0")
ok("CPUEL does NOT floor uniformly -- no rule can be stated",
   nrow(mm0) == 1 && mm0$pct_sub > 20 && mm0$pct_sub < 80,
   sprintf("retains sub-cm on %.1f%% of LengthCode 0 cells", mm0$pct_sub))
worst <- matched$lc[which.min(matched$pct_agree)]
ok("binning is NOT the driver: worst agreement is the cm code",
   worst == "1" && matched$pct_sub[matched$lc == "1"] < 1,
   sprintf("LengthCode 1 at %.1f%% agreement with 0%% sub-cm cells",
           min(matched$pct_agree)))

hdr(sprintf("RESULT: %d checks passed, %d showed a difference", PASS, FAIL))
