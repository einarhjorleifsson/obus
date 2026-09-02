
# obus

<!-- badges: start -->

<!-- badges: end -->

obus is the R access layer for the ICES DATRAS trawl-survey archive. It
reads the raw exchange tables that the sibling
[opus](https://github.com/einarhjorleifsson/opus) package stages, and
builds the derived catch tables on top of them.

Field names and types are opus’s to define; obus does not keep its own
copy of that knowledge. What obus adds is the haul key (`.id`), the
species lookup, two catch tables, a per-record issue-flag table, and the
length-weight coefficients needed to turn a length frequency into a
weight.

## Install

``` r
# install.packages("pak")
pak::pak("einarhjorleifsson/obus")
```

## Two connections

Everything is lazy: a `dr_con*()` call opens a DuckDB view over a remote
parquet file and downloads nothing until `dplyr::collect()`.

``` r
library(obus)
library(dplyr)

# the raw opus archive -- HH, HL, CA, LT, exactly as staged
dr_con_raw("HH")

# what obus builds from it -- HH (+ .id), species, HL_length, HL_summary,
# hl_flag, hl_flag_code, length_weight, length_type_conversion
dr_con("HL_summary")
```

## The two catch tables

`dr_HL_length()` is the length-frequency table: one row per haul x
species x length x sex x measurement type, covering only species that
were actually measured.

`dr_HL_summary()` is the per-haul species roster: one row per haul x
species x species-validity, covering *every* species recorded for the
haul, measured or not. Its `n_totalnumber` is the total DATRAS
*reported* for the species (`TotalNumber`) — deliberately named apart
from `dr_HL_length()`’s `n_haul`, which reaches the same quantity by
raising the measured length frequencies. The two disagree for about 3.4%
of haul x species groups, and that disagreement is a genuine data signal
worth checking, not a bug.

``` r
dr_con("HL_summary") |>
  filter(Survey == "NS-IBTS", Year == 2022, Quarter == 1, SpeciesValidity == "1") |>
  select(.id, latin, species, n_totalnumber, w_haul, n_measured) |>
  collect()
```

Both are published, pre-computed, on the obus server. To recompute
either from the raw archive:

``` r
hh <- dr_con_raw("HH") |> dr_add_id()
hl <- dr_con_raw("HL") |> dr_add_id()

dr_HL_summary(hh, hl, haulval = "1")
```

Neither table filters on `HaulValidity` or `SpeciesValidity` as
published – both are carried as columns so that the choice stays the
caller’s.

## Weight from length

`dr_HL_length()` gives numbers at length; `length_weight` gives the
coefficients for `W = a * L^b`, resolved per species through a ranked
cascade – a fit on obus’s own CA weight-at-length data where there is
one, then FishBase for finfish, SeaLifeBase for invertebrates, and a
generic constant as the floor. Every row records which tier answered, in
`lw_source`, so no predicted weight is ever anonymous. Taxa where a
power law is not meaningful (jellyfish, sponges, worms) are labelled
`not_applicable` rather than given a fish default.

**`LengthClass` is the lower boundary of a length bin, not a length** –
ICES says so for HL and CA alike. `W = a * L^b` is convex, so predicting
from the lower bound under-estimates, by 15.8% at 10 cm and 5.1% at 30
cm with 1 cm bins. `dr_add_length_mid()` takes the midpoint, and
`dr_add_predicted_weight()` defaults to that column, so skipping the
step errors rather than quietly returning low weights.

``` r
dr_con("HL_length") |>
  filter(Survey == "NS-IBTS", Year == 2022, Quarter == 1) |>
  dr_add_length_mid() |>
  dr_add_predicted_weight() |>          # w_ind, w_haul_pred, w_hour_pred
  collect()
```

`dr_compare_length_weight()` checks the result against the measured
`w_haul` in `dr_HL_summary()`. It reports a mismatch and never resolves
one: a discrepancy can mean the coefficients are wrong *or* that the
reported weight is, and there is no principled way to pick a winner
between two independent measurements.

## Building the published files

`data-raw/` holds the scripts that produce what the server serves. They
are run by hand, `DATASET_species.R` first, and none of them publishes
anything:

``` r
source("data-raw/DATASET_species.R")                 # -> species.parquet
source("data-raw/DATASET_products.R")                # -> HH, HL_length, HL_summary
source("data-raw/DATASET_hl_flag.R")                 # -> hl_flag, hl_flag_code
source("data-raw/DATASET_length_weight.R")           # -> length_weight.parquet
source("data-raw/DATASET_length_type_conversion.R")  # -> length_type_conversion.parquet
```

`DATASET_length_weight.R` needs `species.parquet` but not the products,
so it can run before or after `DATASET_products.R`. Publishing is a
manual `scp`.
