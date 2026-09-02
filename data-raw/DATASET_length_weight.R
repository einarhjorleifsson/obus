# Build length_weight.parquet: one row per Valid_Aphia with length-weight
# coefficients (a, b) for W(g) = a * L(cm)^b, plus the provenance label saying
# which tier of the cascade supplied them.
#
# The cascade, finest evidence first, collapsed by .dr_coalesce_with_provenance()
# (R/dr_resolve.R):
#
#   ca_fit               obus's own CA individual-weight-at-length data
#   fishbase_bayes       FishBase estimate(), finfish only
#   sealifebase_species  SeaLifeBase per-study records, invertebrates
#   sealifebase_genus      "     "    pooled over the genus
#   sealifebase_family     "     "    pooled over the family
#   default_constant     a = 0.01, b = 3 -- finfish floor
#
# and two non-value states that record WHY a species has no coefficient rather
# than inventing one: `unresolved` (in scope, nothing matched) and
# `not_applicable` (a taxon where W = a*L^b is not meaningful at all).
#
# LENGTHS ARE BIN MIDPOINTS, both here and at apply time. DATRAS LengthClass is
# the lower boundary of a length bin -- ICES's field descriptions say so for HL
# and CA alike -- so a fit on raw LengthClass inflates `a` to compensate for a
# length that is on average half a bin too short. See dr_add_length_mid().
#
# Run after DATASET_species.R (this reads species.parquet for the taxonomy and
# the query names). It does NOT need HL_length: `length_bearing` is derived
# straight from raw HL, which keeps the build acyclic -- species -> length_weight
# -> products, rather than needing products to build species' companion table.
#
# Requires network: WoRMS is already spent by then, but this hits FishBase and
# SeaLifeBase via rfishbase. Output: data-raw/to_https/length_weight.parquet
# (publish by hand).

source("data-raw/build_helpers.R")

dr_cache_raw(c("HL", "CA"))

CONST_A <- 0.01
CONST_B <- 3

species <- dr_con("species", path = DR_OUT) |> dplyr::collect()

# ---- taxonomic scope: where is W = a*L^b meaningful? ------------------------
# A power law needs a consistent linear body dimension and a weight that scales
# with it. True for finfish, and for the few invertebrate groups measured on a
# standard dimension (cephalopod mantle, decapod carapace, mollusc shell). NOT
# true for jellyfish, sponges, echinoderms, worms or algae, where either the
# "length" is undefined or the weight is mostly water or shell.
#
# These lists are a domain decision, deliberately explicit and editable rather
# than inferred from the taxonomy, and matched against species$class.
FISH_CLASSES      <- c("Teleostei", "Actinopteri", "Actinopterygii",
                       "Elasmobranchii", "Holocephali", "Chondrichthyes",
                       "Chondrostei", "Myxini", "Petromyzonti", "Cephalaspidomorphi")
INVERT_LW_CLASSES <- c("Cephalopoda", "Malacostraca", "Bivalvia", "Gastropoda")

scope <- species |>
  dplyr::distinct(Valid_Aphia, class) |>
  dplyr::mutate(lw_scope = dplyr::case_when(
    class %in% FISH_CLASSES      ~ "fish",
    class %in% INVERT_LW_CLASSES ~ "invert",
    TRUE                         ~ "none"
  ))

applicable <- scope$Valid_Aphia[scope$lw_scope != "none"]

# ---- which species a prediction is ever applied to --------------------------
# Only species that appear WITH A LENGTH are ever fed to W = a*L^b. Coefficients
# for haul-only species are harmless but never used, so coverage is reported
# over this set and the expensive SeaLifeBase resolution targets only it.
#
# Taken from raw HL under dr_HL_length()'s own two filters rather than from
# HL_length.parquet. Same answer (verified: 1,176 either way), and it keeps this
# script independent of the products build.
length_bearing <- dr_con_raw("HL", path = DR_RAW) |>
  dplyr::filter(NumberAtLength != 0, !is.na(LengthClass), !is.na(Valid_Aphia)) |>
  dplyr::distinct(Valid_Aphia) |>
  dplyr::collect() |>
  dplyr::pull(Valid_Aphia)

message(sprintf("scope: %d fish, %d LW-applicable invert, %d not applicable | %d length-bearing",
                sum(scope$lw_scope == "fish"), sum(scope$lw_scope == "invert"),
                sum(scope$lw_scope == "none"), length(length_bearing)))

# ---- tier 1: fit from obus's own CA data ------------------------------------
# Single-fish records only (NumberAtLength == 1), where IndividualWeight is
# unambiguously one fish's weight -- CA's NumberAtLength is an age-length-key
# raising count, so a row above 1 aggregates several fish. That restriction is
# nearly free: such rows are ~92% of weight-bearing CA records and span the same
# length range, so species it costs the fit simply fall through to FishBase.
#
# No mined source does a self-fit at all -- FishGlob and the MSFD pipeline go
# straight to FishBase even where contemporaneous CA pairs exist. It ranks first
# because a same-programme fit is stronger evidence than any external database,
# and because it is automatically in the same length convention as the HL data
# it gets applied to.
ca_raw <- dr_con_raw("CA", path = DR_RAW) |>
  dr_add_length_cm() |>
  dr_add_length_mid() |>
  dplyr::filter(!is.na(IndividualWeight), IndividualWeight > 0,
                !is.na(length_cm_mid), length_cm_mid > 0,
                NumberAtLength == 1) |>
  dplyr::select(Valid_Aphia, length_cm = length_cm_mid, IndividualWeight) |>
  dplyr::collect()

ca_fit <- .dr_lw_fit_ca(dplyr::filter(ca_raw, Valid_Aphia %in% applicable)) |>
  dplyr::select(Valid_Aphia, a, b, n_ca, r2, sigma)

message(sprintf("ca_fit: %d in-scope species fitted from %s CA rows.",
                nrow(ca_fit), format(nrow(ca_raw), big.mark = ",")))

# ---- the name to query the external databases with --------------------------
# FishBase and SeaLifeBase are keyed by scientific name, so a WoRMS-superseded
# code must be queried under the name WoRMS now forwards it to. The DATRAS
# Valid_Aphia stays the join key throughout; the name is only a lookup handle.
species$query_name <- dplyr::coalesce(species$worms_name, species$latin)

# ---- tier 2: FishBase estimate() for finfish --------------------------------
# One Bayesian (a, b) per species, already borrowing down genus/family for
# data-poor species -- so for finfish it subsumes both the taxonomy cascade and
# the multi-study aggregation in one call. There is no SeaLifeBase equivalent.
fish_names <- species[species$Valid_Aphia %in% scope$Valid_Aphia[scope$lw_scope == "fish"] &
                        !is.na(species$query_name),
                      c("Valid_Aphia", "query_name")]
names(fish_names)[2] <- "name"
fish_names <- as.data.frame(fish_names[!duplicated(fish_names$Valid_Aphia), ])

message("rfishbase::estimate() ...")
est      <- rfishbase::estimate(unique(fish_names$name))   # server default = fishbase
fishbase <- .dr_lw_from_estimate(as.data.frame(est), fish_names)
message(sprintf("fishbase: %d of %d finfish species matched an estimate.",
                nrow(fishbase), nrow(fish_names)))

# ---- tier: SeaLifeBase for invertebrates (species -> genus -> family) -------
# SeaLifeBase records are DIMENSION-specific -- Type is a mantle length, a
# carapace length or width, a shell length, never a total length -- so each
# target carries the dimension DATRAS measures for it, and records on any other
# dimension are dropped rather than mismatched.
CLASS_DIM <- list(Cephalopoda = "ML", Malacostraca = "CL",
                  Bivalvia = "ShL", Gastropoda = "ShL")

# True crabs (Brachyura) are measured by DATRAS on carapace WIDTH; every other
# Malacostraca group CLASS_DIM covers (shrimp, lobsters, hermits) is carapace
# LENGTH. No rank column distinguishes them in species.parquet, so this is an
# explicit family override, editable as new mismatches turn up.
BRACHYURA_FAMILIES <- c("Cancridae", "Portunidae", "Majidae", "Pirimelidae",
                        "Xanthidae", "Atelecyclidae", "Geryonidae", "Grapsidae")

invert_names <- species[
  species$Valid_Aphia %in% scope$Valid_Aphia[scope$lw_scope == "invert"] &
    species$Valid_Aphia %in% length_bearing & !is.na(species$query_name),
  c("Valid_Aphia", "query_name", "class", "genus", "family")]
names(invert_names)[2] <- "name"
invert_names <- as.data.frame(invert_names[!duplicated(invert_names$Valid_Aphia), ])

invert_names$dim <- dplyr::if_else(
  invert_names$family %in% BRACHYURA_FAMILIES, "CW",
  unname(unlist(CLASS_DIM)[invert_names$class])
)

message("rfishbase::length_weight(server = 'sealifebase') ...")
slb_sp_rec  <- rfishbase::length_weight(unique(invert_names$name),
                                        server = "sealifebase")
slb_species <- .dr_lw_from_sealifebase(as.data.frame(slb_sp_rec),
                                       invert_names[, c("Valid_Aphia", "name", "dim")])

# Genus/family levels pool a target's genus- or family-mates. The full
# SeaLifeBase table is keyed by SpecCode, not name, so fetch it once with its
# taxonomy attached and map each target onto every congener/confamilial.
slb_all <- merge(
  as.data.frame(rfishbase::length_weight(server = "sealifebase"))[, c("SpecCode", "a", "b", "Type")],
  as.data.frame(rfishbase::load_taxa(server = "sealifebase"))[, c("SpecCode", "Species", "Genus", "Family", "Class")],
  by = "SpecCode")

group_name_map <- function(targets, tgt_col, slb_col) {
  res <- do.call(rbind, lapply(which(!is.na(targets[[tgt_col]])), function(i) {
    nms <- unique(slb_all$Species[!is.na(slb_all[[slb_col]]) &
                                    slb_all[[slb_col]] == targets[[tgt_col]][i]])
    if (!length(nms)) return(NULL)
    data.frame(name = nms, Valid_Aphia = targets$Valid_Aphia[i],
               dim = targets$dim[i], stringsAsFactors = FALSE)
  }))
  if (is.null(res)) {
    data.frame(name = character(0), Valid_Aphia = integer(0), dim = character(0))
  } else res
}

slb_genus  <- .dr_lw_from_sealifebase(slb_all, group_name_map(invert_names, "genus",  "Genus"))
slb_family <- .dr_lw_from_sealifebase(slb_all, group_name_map(invert_names, "family", "Family"))
message(sprintf("sealifebase: species=%d, genus=%d, family=%d (of %d length-bearing inverts)",
                nrow(slb_species), nrow(slb_genus), nrow(slb_family), nrow(invert_names)))

# ---- tier: the generic finfish constant floor -------------------------------
# a = 0.01, b = 3 -- the "sensible standard when everything else is dubious",
# expressed as a tier rather than as a special case. Finfish ONLY: a fish
# default is meaningless for a crustacean or a scallop, let alone a sponge.
const_fish <- data.frame(Valid_Aphia = scope$Valid_Aphia[scope$lw_scope == "fish"],
                         a = CONST_A, b = CONST_B)

# ---- collapse the cascade ---------------------------------------------------
resolved <- .dr_coalesce_with_provenance(
  base       = data.frame(Valid_Aphia = sort(unique(scope$Valid_Aphia))),
  tiers      = list(
    list(label = "ca_fit",              data = as.data.frame(ca_fit[, c("Valid_Aphia", "a", "b")])),
    list(label = "fishbase_bayes",      data = fishbase),
    list(label = "sealifebase_species", data = slb_species),
    list(label = "sealifebase_genus",   data = slb_genus),
    list(label = "sealifebase_family",  data = slb_family),
    list(label = "default_constant",    data = const_fish)
  ),
  value_cols = c("a", "b"),
  keys       = "Valid_Aphia",
  source_col = "lw_source"
)

length_weight <- resolved |>
  dplyr::left_join(scope[, c("Valid_Aphia", "lw_scope")], by = "Valid_Aphia") |>
  dplyr::left_join(ca_fit[, c("Valid_Aphia", "n_ca", "r2", "sigma")], by = "Valid_Aphia") |>
  dplyr::mutate(
    lw_source = dplyr::case_when(
      lw_source != "unresolved" ~ lw_source,          # a tier answered
      lw_scope == "none"        ~ "not_applicable",   # LW not meaningful here
      TRUE                      ~ "unresolved"        # in scope, nothing matched
    ),
    Valid_Aphia    = as.integer(Valid_Aphia),
    length_bearing = Valid_Aphia %in% length_bearing
  ) |>
  dplyr::select(Valid_Aphia, a, b, lw_source, n_ca, r2, sigma, length_bearing) |>
  dplyr::arrange(Valid_Aphia)

stopifnot(!anyDuplicated(length_weight$Valid_Aphia),
          all(species$Valid_Aphia %in% length_weight$Valid_Aphia))

# ---- coverage ---------------------------------------------------------------
# Reported over the length-bearing species, the set a prediction is applied to.
# Haul-only species get whatever tier applies but it is never used.
cat("\ncoverage over length-bearing species:\n")
print(dplyr::count(dplyr::filter(length_weight, length_bearing), lw_source))
cat("non-length (haul-only) species:\n")
print(dplyr::count(dplyr::filter(length_weight, !length_bearing), lw_source))

# ---- write ------------------------------------------------------------------
dr_write(dplyr::copy_to(duckdbfs::cached_connection(), length_weight,
                        "_obus_length_weight_out", overwrite = TRUE),
         "length_weight")

message("\nPublish with:")
message("  scp data-raw/to_https/length_weight.parquet einarhj@heima.hafro.is:~/public_html/datras/length_weight.parquet")
