# ---------------------------------------------------------------------------
# Build a DATRASraw object from obus's published tables.
#
# WHY THIS EXISTS. {DATRAS} has no constructor to call. Every documented entry
# point -- readExchange(), readExchangeDir(), readICES(), getDatrasExchange(),
# downloadExchange(), and DATRASextra::read_datras() which wraps them -- parses
# a DATRAS exchange file, and write_datras() writes one back, so even the round
# trip goes through the CSV parser. The function that derives everything a
# DATRASraw carries beyond the submitted columns, addExtraVariables(), is not
# exported. obus therefore reproduces that derivation rather than calling it;
# .dr_lngtcode_cm below and the six HH columns in .dr_datras_hh() are copied
# from its body, and the two renames in .dr_datras_ca() from renameDATRAS().
#
# WHY {DATRAS} IS NOT AN IMPORT. Constructing the object needs no {DATRAS} code
# at all. A DATRASraw is a three-element list -- CA, HH, HL, in that order,
# because {DATRAS} indexes it positionally as x[[1]], x[[2]], x[[3]] -- carrying
# a class attribute, and DATRASextra:::.add_class_datras() is exactly
# `class(x) <- c("datras_raw", "DATRASraw")`. {DATRAS} is used here for one
# optional column (Roundfish, which lives in a CSV inside the package) and is
# Suggests, not Imports.
#
# THE ONE TRAP. {DATRAS} declares S3method("$", DATRASraw), and that method is
# `x[[2]][[name, exact = FALSE]]` -- it redirects x$foo into the HH table. R
# registers it when the NAMESPACE is LOADED, not when it is attached, so
# loadNamespace("DATRAS") is enough and library() is not needed. Before it is
# registered x$HH is the HH table and x$HaulDur is NULL; after, the reverse.
# Everything below therefore uses [[ ]]. Note that the requireNamespace() call
# in dr_get_datras() loads the namespace itself, so on a machine that has
# {DATRAS} installed the object always comes back with the methods live.
# ---------------------------------------------------------------------------

# LngtClas -> cm multiplier, from DATRAS::addExtraVariables(). NOT bin width:
# codes "." and "0" record LengthClass in mm, "1"/"2"/"5" in cm, so this
# rescales, and getAccuracyCM()'s c(0.1, 0.5, 1, 2, 5) is a different quantity.
.dr_lngtcode_cm <- c("." = 0.1, "0" = 0.1, "1" = 1, "2" = 1, "5" = 1)

# obus's `accuracy` (cm) -> ICES LngtCode. A bijection on the five valid codes.
.dr_code_of_accuracy <- c("0.1" = ".", "0.5" = "0", "1" = "1", "2" = "2", "5" = "5")

# DATRAS's own type conventions: factors wherever a string lives, Year and
# Quarter as factors, and haul.id levelled on HH so that subset() stays
# consistent across the three tables.
.dr_facify <- function(d, lev) {
  for (k in names(d)) if (is.character(d[[k]])) d[[k]] <- factor(d[[k]])
  d[["haul.id"]] <- factor(as.character(d[["haul.id"]]), levels = lev)
  d[["Year"]]    <- factor(d[["Year"]])
  d[["Quarter"]] <- factor(d[["Quarter"]])
  as.data.frame(d)
}

# Roundfish area, keyed on StatRec. Only obtainable from {DATRAS}'s own CSV, so
# it is added when the package is installed and left out when it is not.
.dr_add_roundfish <- function(hh) {
  f <- system.file("roundfish.csv", package = "DATRAS")
  if (!nzchar(f)) return(hh)
  rf <- utils::read.table(f, stringsAsFactors = FALSE)
  hh[["Roundfish"]] <- factor(rf[[1]][match(as.character(hh[["StatRec"]]), rf[[2]])])
  hh
}


# HH -- renamed to the legacy ICES names {DATRAS} expects, plus the six columns
# addExtraVariables() derives and DATRASextra's defaults read. Takes an already
# collected HH in opus's current names.
.dr_datras_hh <- function(hh) {
  hh <- opus::op_rename(as.data.frame(hh), "HH", to = "legacy")
  if (nrow(hh) == 0L)
    stop("dr_get_datras(): no hauls matched. Check `survey`, `years`, ",
         "`quarters`, `haulval` and `stdspec`.", call. = FALSE)

  dplyr::mutate(
    hh,
    haul.id    = .id,
    lon        = ShootLong,
    lat        = ShootLat,
    abstime    = Year + (Month - 1) / 12 + (Day - 1) / 365,
    timeOfYear = (Month - 1) / 12 + (Day - 1) / 365,
    # opus stages TimeShot as character so HHMM keeps its leading zero.
    TimeShotHour = as.integer(as.integer(TimeShot) / 100) +
                   (as.integer(TimeShot) %% 100) / 60
  )
}


# HL -- from HL_length + HL_summary only, never from raw HL. The two published
# catch tables carry everything DATRAS's HL needs and nothing DATRAS reads is
# lost in the split; CHECK_datras_adapter.R is the 11/11 demonstration.
.dr_datras_hl <- function(hh, len, smry) {
  keep <- function(x) dplyr::filter(as.data.frame(x), .id %in% hh[["haul.id"]])
  len  <- keep(len)
  smry <- keep(smry)

  totals <- dplyr::select(smry, haul.id = .id, Valid_Aphia, SpeciesValidity,
                          TotalNo = n_totalnumber, CatCatchWgt = w_haul)

  hl_len <- dplyr::transmute(
    len,
    haul.id = .id, Survey, Year, Quarter, Valid_Aphia,
    Species     = latin,
    SpecCode    = Valid_Aphia,
    SpecVal     = as.integer(SpeciesValidity),
    SpeciesValidity,
    Sex         = dplyr::coalesce(SpeciesSex, ""),
    DevStage    = DevelopmentStage,
    LenMeasType = LengthType,
    LngtCode    = unname(.dr_code_of_accuracy[as.character(accuracy)]),
    LngtClas    = as.integer(dplyr::if_else(accuracy <= 0.5, length_mm,
                                            as.integer(length_mm / 10L))),
    LngtCm      = length_cm,
    HLNoAtLngt  = n_measured,
    # DATRAS's Count IS obus's n_haul: both are the raised number at length.
    Count       = n_haul,
    # SubFactor is not in the published grain -- the raised count already
    # carries it, and nothing downstream reads it. Reported where it is
    # recoverable so the column is not a lie.
    SubFactor   = n_haul / n_measured
  )

  # Species recorded for a haul but never measured have no HL_length row, so
  # they come from HL_summary with a missing length -- which is how DATRAS
  # itself carries them, and what species richness needs.
  hl_bulk <- dplyr::transmute(
    dplyr::anti_join(smry, dplyr::distinct(len, .id, Valid_Aphia, SpeciesValidity),
                     by = c(".id", "Valid_Aphia", "SpeciesValidity")),
    haul.id = .id, Survey, Year, Quarter, Valid_Aphia,
    Species = latin, SpecCode = Valid_Aphia,
    SpecVal = as.integer(SpeciesValidity), SpeciesValidity,
    Sex = "", DevStage = NA_character_, LenMeasType = NA_character_,
    LngtCode = NA_character_, LngtClas = NA_integer_, LngtCm = NA_real_,
    HLNoAtLngt = NA_real_, Count = NA_real_, SubFactor = NA_real_
  )

  hl <- dplyr::bind_rows(hl_len, hl_bulk)
  hl <- dplyr::left_join(hl, totals,
                         by = c("haul.id", "Valid_Aphia", "SpeciesValidity"),
                         na_matches = "na")
  hl <- dplyr::left_join(hl, dplyr::select(hh, haul.id, HaulDur, DataType),
                         by = "haul.id")
  dplyr::select(hl, -SpeciesValidity)
}


# CA -- raw + .id, renamed to legacy, then the two renames renameDATRAS() does
# on top of that (LngtClass -> LngtClas, CANoAtLngt -> NoAtALK) and the three
# columns addExtraVariables() derives for the age table.
.dr_datras_ca <- function(hh, ca, species) {
  if (is.null(ca) || nrow(ca) == 0L) return(NULL)
  ca <- opus::op_rename(as.data.frame(ca), "CA", to = "legacy")

  # 5.13% of CA archive-wide carries no haul key that resolves (StationName and
  # HaulNumber both missing, so .id ends ":NA:NA"). DATRAS repairs some of
  # these in fixMissingHaulIds() by guessing a haul among candidates; obus does
  # not guess -- it drops them and says how many.
  n_all <- nrow(ca)
  ca <- ca[ca[[".id"]] %in% hh[["haul.id"]], , drop = FALSE]
  n_orphan <- n_all - nrow(ca)
  if (n_orphan > 0L)
    message("dr_get_datras(): dropped ", format(n_orphan, big.mark = ","),
            " of ", format(n_all, big.mark = ","),
            " CA rows that match no haul in HH.")
  if (nrow(ca) == 0L) return(NULL)

  names(ca)[names(ca) == "LngtClass"]  <- "LngtClas"
  names(ca)[names(ca) == "CANoAtLngt"] <- "NoAtALK"

  sp <- dplyr::select(as.data.frame(species), Valid_Aphia, latin)
  ca <- dplyr::left_join(ca, sp, by = "Valid_Aphia")

  dplyr::mutate(
    ca,
    haul.id = .id,
    Species = latin,
    LngtCm  = unname(.dr_lngtcode_cm[as.character(LngtCode)]) * LngtClas,
    # DATRAS insists CA carries StatRec under that name, not AreaCode.
    StatRec = AreaCode
  )
}


#' Build a DATRASraw object from obus's published tables
#'
#' Assembles the three-table \code{DATRASraw} object that \pkg{DATRAS} and
#' \pkg{DATRASextra} consume, reading from the parquet archive rather than from
#' a DATRAS exchange file. The result is accepted by
#' \code{DATRASextra:::.check_class_datras()} and runs \pkg{DATRASextra}'s
#' downstream pipeline unmodified.
#'
#' \strong{Why obus builds this rather than calling \pkg{DATRAS}.} \pkg{DATRAS}
#' publishes no constructor. \code{readExchange()}, \code{readExchangeDir()},
#' \code{readICES()}, \code{getDatrasExchange()}, \code{downloadExchange()} and
#' \code{DATRASextra::read_datras()} all parse a DATRAS exchange file, and
#' \code{write_datras()} writes one back rather than serialising the object, so
#' there is no route in that does not go through the CSV parser. The function
#' that derives everything a \code{DATRASraw} carries beyond the submitted
#' columns, \code{addExtraVariables()}, is unexported. obus therefore
#' reproduces that derivation. Constructing the object needs no \pkg{DATRAS}
#' code -- it is a three-element list with a class attribute -- so \pkg{DATRAS}
#' is \code{Suggests}, used only for the optional \code{Roundfish} column.
#'
#' \strong{HL comes from the two published catch tables, never from raw HL.}
#' \code{HL_length} supplies the measured length classes and \code{HL_summary}
#' the species that were counted or weighed but never measured -- which DATRAS
#' carries as HL rows with a missing length, and which species richness needs.
#' \code{data-raw/CHECK_datras_adapter.R} is the demonstration that nothing
#' DATRAS reads is lost in the split: 11/11 checks, every one max gap 0,
#' including an identical stratified index.
#'
#' \strong{One species at a time, from \code{add_numbers_at_length()} onward.}
#' That is \pkg{DATRAS}'s constraint, not obus's. Its derived quantities live
#' as \code{haul} \eqn{\times} \code{length} matrices on HH with no species
#' dimension, so \code{addSpectrum()} pools whatever species are present (it
#' warns) and \code{rawALK()}/\code{fitALK()}/\code{addNage()} pool them
#' silently.
#'
#' Nothing is \emph{removed} by those functions -- HL keeps \code{Species} and
#' \code{Valid_Aphia} untouched. What is added is an unlabelled sum, and no
#' later step can label it or undo it. That makes the ordering load-bearing
#' rather than stylistic: subset first, \emph{then} derive. Subsetting
#' afterwards looks like it worked and does not, because
#' \code{subset.DATRASraw()} filters whichever component holds the column, and
#' \code{Species} is not in HH -- so CA and HL shrink to one species while
#' \code{N} and \code{HaulN}, which live on HH, keep their pooled values. On
#' \pkg{DATRASextra}'s own \code{mini} that leaves \code{HaulN} 19x too high
#' for the single species HL now claims to hold, with no warning and nothing
#' inconsistent for a check to catch. Pass a single \code{aphia} here, or
#' \code{subset()} before the first \code{add_*()} call.
#'
#' \strong{\code{$} on the result depends on whether \pkg{DATRAS}'s namespace
#' is loaded.} \pkg{DATRAS} registers an S3 method \code{$.DATRASraw} that is
#' \code{x[[2]][[name, exact = FALSE]]}, redirecting \code{x$foo} into the HH
#' table. R registers it on \emph{load}, not on attach, so
#' \code{loadNamespace("DATRAS")} is enough and \code{library()} is not
#' needed -- and this function's own \code{requireNamespace()} call triggers
#' it. With the method live \code{x$HaulDur} works and \code{x$HH} is
#' \code{NULL}; without it, the reverse. Use \code{x[["HH"]]} to reach a
#' table either way.
#'
#' \strong{Haul-level dimensions survive; record-level ones do not.} After
#' \code{add_numbers_at_length()} the \code{N} matrix is
#' \code{haul} \eqn{\times} \code{length}, but each row is still a haul, so
#' anything HH carries -- \code{Year}, \code{Quarter}, \code{Gear},
#' \code{StatRec}, \code{Depth} -- can be split back out with
#' \code{calc_stratified_index(by = ...)}. Nothing does it for you: leaving
#' \code{quarters = NULL} and then taking \code{by = "Year"} pools the
#' quarters into one number without warning (NS-IBTS 2022 cod: 28.8 pooled,
#' against 10.5 in Q1 and 39.5 in Q3). \code{rawALK()} pools them too, and it
#' has no \code{Quarter} guard at all -- fish grow between quarters, so build
#' age-length keys within one. \code{getAccuracyCM()} likewise takes the
#' coarsest \code{LngtCode} across everything in the object.
#'
#' \strong{Getting back out.} There is no inverse in either package: no
#' \code{as.list} method, nothing named \code{as*} in \pkg{DATRAS}, and
#' \pkg{DATRASextra}'s \code{as_table()}/\code{as_long_format()}/
#' \code{as_wide_format()}/\code{as_fishglob()} are all HH-only projections.
#' Three routes, depending on what you want back:
#' \itemize{
#'   \item \strong{The three tables:} \code{unclass(x)} -- it is already a
#'     plain list, so this is the whole of it.
#'   \item \strong{What \pkg{DATRAS} added} (\code{N}, \code{Nage},
#'     \code{HaulN}, \code{HaulWgt}, \code{SweptArea}):
#'     \code{as.data.frame(x, response = "Nage")} or
#'     \code{DATRASextra::as_long_format(x)}. Rejoining to obus is one line,
#'     because \code{.id} and \code{haul.id} paste the same eight fields in
#'     the same order: \code{dplyr::mutate(out, .id = as.character(haul.id))}.
#'   \item \strong{obus's names and parquet types:} \code{\link{dr_con}}.
#'     Do not round-trip for this. Measured on NS-IBTS 2022 Q1, the return leg
#'     preserves the parquet type on 46 of 70 HH columns and 7 of 33 CA
#'     columns -- \code{character} becomes \code{factor} throughout, and
#'     \code{Year}/\code{Quarter} become factors -- and every column that
#'     survives comes back under its legacy ICES name
#'     (\code{Platform} as \code{Ship}, \code{StartTime} as
#'     \code{TimeShot}). That is \pkg{DATRAS}'s own convention, imposed by
#'     \code{readExchange()} too, and \code{subset.DATRASraw()} depends on
#'     it. The parquet is not lost, so read it again rather than rebuilding it.
#' }
#'
#' @param survey Character vector of \code{Survey} codes, e.g. \code{"NS-IBTS"}.
#'   \code{NULL} takes every survey, which is rarely what you want.
#' @param years Integer vector of years. \code{NULL} takes all.
#' @param quarters Integer vector of quarters. \code{NULL} takes all.
#' @param aphia Integer vector of \code{Valid_Aphia} codes. \code{NULL} takes
#'   every species, which is right for species composition and richness and
#'   wrong for anything downstream of \code{add_numbers_at_length()}.
#' @param ca Include the CA (age and individual biology) table? Needed for
#'   age-length keys; \code{FALSE} skips the read.
#' @param haulval Character vector of \code{HaulValidity} codes to retain,
#'   e.g. \code{"V"}. \code{NULL} (default) retains every haul, matching
#'   \code{\link{dr_HL_length}}; obus does not filter unless asked.
#' @param stdspec Character vector of \code{StandardSpeciesCode} values to
#'   retain. \code{NULL} (default) retains every haul.
#'
#' @return A list of three data frames -- \code{CA} (or \code{NULL}),
#'   \code{HH}, \code{HL}, in that order, because \pkg{DATRAS} indexes them
#'   positionally -- with class \code{c("datras_raw", "DATRASraw")}.
#'
#' @seealso \code{\link{dr_con}} for the tables this reads.
#'
#' @examples
#' \dontrun{
#' d <- dr_get_datras("NS-IBTS", years = 2020:2023, quarters = c(1L, 3L),
#'                   aphia = 127139L, haulval = "V")
#'
#' library(DATRASextra)
#' d <- add_numbers_at_length(d)
#' d <- add_total_numbers_by_haul(d)
#' d <- add_swept_area(d)
#' calc_stratified_index(d, cpue_method = "per_swept_area", by = "Year")
#' }
#' @export
dr_get_datras <- function(survey, years = NULL, quarters = NULL, aphia = NULL,
                         ca = TRUE, haulval = NULL, stdspec = NULL) {

  if (!requireNamespace("DATRAS", quietly = TRUE))
    message("dr_get_datras(): {DATRAS} is not installed. The object is still ",
            "built, but `Roundfish` is omitted and, with no $.DATRASraw method ",
            "registered, `$` will not redirect into HH -- use x[[\"HH\"]].")

  tbl <- .dr_datras_fetch(survey, years, quarters, aphia, ca, haulval, stdspec)

  .dr_as_datras_build(hh         = tbl$hh,
                      hl_length  = tbl$hl_length,
                      hl_summary = tbl$hl_summary,
                      ca         = tbl$ca,
                      species    = tbl$species)
}


# The I/O half: everything that touches dr_con(). Kept apart from
# .dr_as_datras_build() so the reshape can be tested offline against synthetic
# frames, the way dr_HL_length() and dr_HL_summary() are -- they take their
# tables as arguments for exactly this reason. Filtering happens here, in
# opus's CURRENT names, before anything is collected.
.dr_datras_fetch <- function(survey, years, quarters, aphia, ca,
                             haulval, stdspec) {
  by_haul <- function(x) {
    if (!is.null(survey))   x <- dplyr::filter(x, Survey %in% survey)
    if (!is.null(years))    x <- dplyr::filter(x, Year %in% years)
    if (!is.null(quarters)) x <- dplyr::filter(x, Quarter %in% quarters)
    x
  }
  by_species <- function(x) {
    x <- by_haul(x)
    if (!is.null(aphia)) x <- dplyr::filter(x, Valid_Aphia %in% aphia)
    dplyr::collect(x)
  }

  hh <- by_haul(dr_con("HH"))
  if (!is.null(haulval)) hh <- dplyr::filter(hh, HaulValidity %in% haulval)
  if (!is.null(stdspec)) hh <- dplyr::filter(hh, StandardSpeciesCode %in% stdspec)

  list(
    hh         = dplyr::collect(hh),
    hl_length  = by_species(dr_con("HL_length")),
    hl_summary = by_species(dr_con("HL_summary")),
    ca         = if (isTRUE(ca)) by_species(dr_con("CA")) else NULL,
    species    = dplyr::collect(dplyr::select(dr_con("species"),
                                              Valid_Aphia, latin))
  )
}


#' Assemble a DATRASraw from already-fetched tables
#'
#' The pure half of \code{\link{dr_get_datras}}: it does the renaming,
#' derivation and reshaping, and touches no connection. Exposed as an internal
#' so the transformation can be tested offline against synthetic frames.
#'
#' @param hh,ca Collected \code{HH} and \code{CA} in opus's current field
#'   names, already filtered. \code{ca} may be \code{NULL}.
#' @param hl_length,hl_summary Collected \code{HL_length} and
#'   \code{HL_summary}, already filtered.
#' @param species Two-column lookup with \code{Valid_Aphia} and \code{latin},
#'   used for CA's \code{Species}. Only needed when \code{ca} is given.
#' @return A \code{c("datras_raw", "DATRASraw")} object.
#' @keywords internal
.dr_as_datras_build <- function(hh, hl_length, hl_summary,
                                ca = NULL, species = NULL) {

  hh <- .dr_add_roundfish(.dr_datras_hh(hh))
  hl <- .dr_datras_hl(hh, hl_length, hl_summary)
  if (nrow(hl) == 0L)
    warning("dr_get_datras(): ", nrow(hh), " hauls matched but no HL rows did. ",
            "The object is valid and passes DATRASextra's class check, but ",
            "add_numbers_at_length() and everything downstream of it will ",
            "fail on it. Check `aphia`.", call. = FALSE)
  ca <- .dr_datras_ca(hh, ca, species)

  lev <- levels(factor(hh[["haul.id"]]))
  d <- list(
    CA = if (is.null(ca)) NULL else .dr_facify(ca, lev),
    HH = .dr_facify(hh, lev),
    HL = .dr_facify(hl, lev)
  )
  class(d) <- c("datras_raw", "DATRASraw")
  d
}
