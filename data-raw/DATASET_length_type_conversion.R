# Build length_type_conversion.parquet: a non-Total-Length landmark -> Total
# Length conversion, for the DATRAS species measured on a different landmark
# (LengthType != "1").
#
# Weight-from-length is only valid if the length measured is the length the
# coefficients were fitted against. DATRAS's LengthType records the landmark --
# "1" Total Length, "2" Standard Length, "4" Pre-Anal-Fin Length, and others --
# and in HL it is 72% NA, 20% "1", 6.5% "2". So the working assumption is Total
# Length where LengthType is absent, and this table converts the cases where it
# is present, known to differ, and a factor can be cited.
#
# DELIBERATELY NARROW. Every factor here, and every factor missing from here,
# traces to one source: script 7_Species_QA in Marine Scotland Science's "MSFD
# Quality Assured Groundfish Survey Monitoring and Assessment Data Products"
# pipeline (https://github.com/MarineScotlandScience/MSFD-QA-GFSM-A-DP; no
# LICENSE file -- the factors and the idea are cited, no code is reused). That
# script also carries Alepocephalidae (Standard Length), Chimaeridae
# (Pre-Supra-Caudal-Fin Length) and one further Macrourid, but cites none of
# them to a publication. Those are left out rather than attributed to a source
# they do not have; dr_add_length_tl() reports them as "unconverted", which is
# a statement about the evidence, not a silent pass-through.
#
# No network needed -- Valid_Aphia is resolved from species.parquet by name --
# so this can run any time after DATASET_species.R.
#
# Output: data-raw/to_https/length_type_conversion.parquet (publish by hand).

source("data-raw/build_helpers.R")

# TL = intercept + slope * PAFL, with PAFL and TL both in cm.
species_factors <- data.frame(
  latin     = c("Macrourus berglax", "Coryphaenoides rupestris"),
  from_type = c("4", "4"),                 # LengthType 4 = Pre-Anal-Fin Length
  intercept = c(5.232, -1.6368),
  slope     = c(2.3455, 4.7399),
  source    = c("Atkinson 1991", "Atkinson 1981"),
  stringsAsFactors = FALSE
)

species <- dr_con("species", path = DR_OUT) |> dplyr::collect()

name_to_aphia <- as.data.frame(
  species[species$latin %in% species_factors$latin, c("Valid_Aphia", "latin")])

# A silent drop here would publish a table that quietly converts fewer species
# than it claims to, so an unresolved name is a build error, not a warning.
missing_names <- setdiff(species_factors$latin, name_to_aphia$latin)
if (length(missing_names) > 0) {
  stop("species.parquet has no Valid_Aphia for: ",
       paste(missing_names, collapse = ", "), call. = FALSE)
}
if (anyDuplicated(name_to_aphia$latin)) {
  stop("more than one Valid_Aphia resolves to the same latin name -- the merge ",
       "below would fan out.", call. = FALSE)
}

length_type_conversion <- merge(name_to_aphia, species_factors, by = "latin")
length_type_conversion <- length_type_conversion[
  order(length_type_conversion$Valid_Aphia),
  c("Valid_Aphia", "from_type", "intercept", "slope", "source")]

print(length_type_conversion)

dr_write(dplyr::copy_to(duckdbfs::cached_connection(), length_type_conversion,
                        "_obus_length_type_conversion_out", overwrite = TRUE),
         "length_type_conversion")

message("\nPublish with:")
message("  scp data-raw/to_https/length_type_conversion.parquet einarhj@heima.hafro.is:~/public_html/datras/length_type_conversion.parquet")
