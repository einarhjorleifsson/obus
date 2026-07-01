
# obus

## Preamble

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

The aim of {obus} is to provide users fast and efficient access to
DATRAS tables with non-ambiguous variables.

That said, {obus} is a temporary experimental package used to explore
various DATRAS data connections and wrapper functions to make life a
little easier for ordinary user. Some of that may be taken up in a more
official package. Or possibly not. So far {obus} does actually very
little.

The package code resides on
[GitHub](https://github.com/einarhjorleifsson/obus) and there is also a
[package website](https://einarhjorleifsson.github.io/obus/).

For purists, one regrets to inform that the functionality of {obus} has
quite some number of dependencies (56, see also
[DESCRIPTION](https://raw.githubusercontent.com/einarhjorleifsson/obus/refs/heads/master/DESCRIPTION)).
Some of them may possibly be trimmed, but never all.

Access to the parquet datafiles is though independent of {obus} and for
that matter **any software platform** used. The current **temporary**
path to the exchange files (with the new header lingo) used in {obus}
is:

    https://heima.hafro.is/~einarhj/datras/HH.parquet
    https://heima.hafro.is/~einarhj/datras/HL.parquet
    https://heima.hafro.is/~einarhj/datras/CA.parquet

## Installation

You can install {obus} using one of:

``` r
remotes::install_github("einarhjorleifsson/obus")
pak::pak("einarhjorleifsson/obus")
```

``` r
library(obus)
library(dplyr)
```

## Importing

The fastest way to import the full DATRAS data into R memory:

``` r
system.time({
  hh <- dr_get("HH")
  hl <- dr_get("HL")
  ca <- dr_get("CA")
})
#>    user  system elapsed 
#>  11.032   1.943  29.990
```

| type |     rows | cols |
|:-----|---------:|-----:|
| HH   |   150256 |   70 |
| HL   | 14397130 |   30 |
| CA   |  5964646 |   35 |

Number of records and variables

All tables use standard column names and correct variable types. If your
downstream code depends on the old DATRAS column names, revert with:

``` r
hl |> dr_translate(from = "new", to = "old")
#> # A tibble: 14,397,130 × 30
#>    RecordType `-`    Quarter Country Ship  Gear  SweepLngt GearEx DoorType StNo 
#>    <chr>      <chr>    <int> <chr>   <chr> <chr>     <int> <chr>  <chr>    <chr>
#>  1 HL         SWC-I…       4 GB-SCT  749S  GOV          60 <NA>   P        550  
#>  2 HL         SWC-I…       4 GB-SCT  749S  GOV          60 <NA>   P        578  
#>  3 HL         SWC-I…       4 GB-SCT  749S  GOV          60 <NA>   P        548  
#>  4 HL         SWC-I…       4 GB-SCT  749S  GOV          60 <NA>   P        571  
#>  5 HL         SWC-I…       4 GB-SCT  749S  GOV          60 <NA>   P        539  
#>  6 HL         SWC-I…       4 GB-SCT  749S  GOV          60 <NA>   P        543  
#>  7 HL         SWC-I…       4 GB-SCT  749S  GOV          60 <NA>   P        543  
#>  8 HL         SWC-I…       4 GB-SCT  749S  GOV          60 <NA>   P        543  
#>  9 HL         SWC-I…       4 GB-SCT  749S  GOV          60 <NA>   P        543  
#> 10 HL         SWC-I…       4 GB-SCT  749S  GOV          60 <NA>   P        537  
#> # ℹ 14,397,120 more rows
#> # ℹ 20 more variables: HaulNo <int>, SpecCodeType <chr>, SpecCode <chr>,
#> #   SpecVal <chr>, Sex <chr>, TotalNo <dbl>, CatIdentifier <int>, NoMeas <int>,
#> #   SubFactor <dbl>, SubWgt <int>, CatCatchWgt <int>, LngtCode <chr>,
#> #   LngtClass <int>, CANoAtLngt <dbl>, DevStage <chr>, LenMeasType <chr>,
#> #   DateofCalculation <int>, Valid_Aphia <int>, Year <dbl>, .id <chr>
```

The XML API (`icesDatras::getDATRAS`) is also available via
`source = "xml"` — useful for targeted queries by survey, year, and
quarter without downloading the full table.

## Connecting

Rather than importing, you can open a lazy DuckDB connection to the same
parquet files. Nothing is downloaded until you explicitly call
`collect()`:

``` r
system.time({
  hh <- dr_con("HH")
  hl <- dr_con("HL")
})
#>    user  system elapsed 
#>   0.155   0.024   1.204
```

The connection is nearly instant — DuckDB reads only the file index, not
the data. You then use ordinary `{dplyr}` verbs to filter, join, and
compute; DuckDB translates them to SQL and executes against the remote
file. Only the rows and columns you actually need travel over the wire:

``` r
system.time(
  cod <- hl |>
    left_join(hh |> select(.id, DataType, HaulDuration, HaulValidity,
                           lon = ShootLongitude, lat = ShootLatitude)) |>
    left_join(dr_con("species"), by = join_by(aphia)) |>
    dr_add_length_cm() |>
    dr_add_n_and_cpue() |>
    filter(HaulValidity == "V", latin == "Gadus morhua",
           Survey %in% c("NS-IBTS", "SCOWCGFS"), Quarter == 1) |>
    select(.id, Survey, Year, lon, lat, latin, length_cm, n_haul, n_hour) |>
    collect()
)
#>    user  system elapsed 
#>   0.543   0.051   0.946
glimpse(cod)
#> Rows: 152,918
#> Columns: 9
#> $ .id       <chr> "NS-IBTS:1990:1:NO:58EJ:GOV:0046:46", "NS-IBTS:1990:1:NO:58E…
#> $ Survey    <chr> "NS-IBTS", "NS-IBTS", "NS-IBTS", "NS-IBTS", "NS-IBTS", "NS-I…
#> $ Year      <dbl> 1990, 1990, 1990, 1990, 1990, 1990, 1990, 1990, 1990, 1990, …
#> $ lon       <dbl> 2.5000, 2.5000, 2.5000, 2.5000, 3.1333, 2.6333, 2.6333, 2.63…
#> $ lat       <dbl> 60.3333, 60.3333, 60.3333, 60.3333, 60.1167, 59.8667, 59.866…
#> $ latin     <chr> "Gadus morhua", "Gadus morhua", "Gadus morhua", "Gadus morhu…
#> $ length_cm <dbl> 36, 40, 42, 48, 54, 26, 29, 31, 34, 36, 37, 38, 41, 42, 49, …
#> $ n_haul    <dbl> 1.0, 1.0, 2.0, 1.0, 1.0, 1.0, 6.0, 1.0, 3.0, 1.0, 2.0, 2.0, …
#> $ n_hour    <dbl> 2, 2, 4, 2, 2, 2, 12, 2, 6, 2, 4, 4, 2, 2, 2, 2, 2, 4, 3, 3,…
```

**The same pipeline works unchanged whether `hh` and `hl` are DuckDB
connections or plain R data frames.** You can mix and match — switch to
`dr_get()` when you need the full table in memory, use `dr_con()` when
you want lazy filtering. The `dr_add_*()` functions handle both
transparently.

For local parquet files, skip `dr_con()` and use
`duckdbfs::open_dataset()` directly — the result is identical:

``` r
hl <- duckdbfs::open_dataset("~/datras/HL.parquet")
```

See the [Parquet and DuckDB](articles/parquet_and_duckdb.html) article
for a full explanation of how Parquet, DuckDB, and dbplyr fit together,
including why the file format matters and a step-by-step walkthrough of
lazy query building.

## Specs

    #> ─ Session info ───────────────────────────────────────────────────────────────
    #>  setting  value
    #>  version  R version 4.5.2 (2025-10-31)
    #>  os       macOS Tahoe 26.5.1
    #>  system   aarch64, darwin20
    #>  ui       X11
    #>  language (EN)
    #>  collate  en_US.UTF-8
    #>  ctype    en_US.UTF-8
    #>  tz       Atlantic/Reykjavik
    #>  date     2026-07-01
    #>  pandoc   3.9.0.2 @ /opt/homebrew/bin/ (via rmarkdown)
    #>  quarto   1.8.26 @ /usr/local/bin/quarto
    #> 
    #> ─ Packages ───────────────────────────────────────────────────────────────────
    #>  package     * version  date (UTC) lib source
    #>  blob          1.3.0    2026-01-14 [2] CRAN (R 4.5.2)
    #>  cachem        1.1.0    2024-05-16 [2] CRAN (R 4.5.0)
    #>  cli           3.6.6    2026-04-09 [2] CRAN (R 4.5.2)
    #>  curl          7.1.0    2026-04-22 [2] CRAN (R 4.5.2)
    #>  data.table    1.18.4   2026-05-06 [2] CRAN (R 4.5.2)
    #>  DBI           1.3.0    2026-02-25 [2] CRAN (R 4.5.2)
    #>  dbplyr        2.6.0    2026-06-17 [2] CRAN (R 4.5.2)
    #>  devtools      2.5.2    2026-04-30 [2] CRAN (R 4.5.2)
    #>  digest        0.6.39   2025-11-19 [2] CRAN (R 4.5.2)
    #>  dplyr       * 1.2.1    2026-04-03 [2] CRAN (R 4.5.2)
    #>  duckdb        1.5.4    2026-06-19 [2] CRAN (R 4.5.2)
    #>  duckdbfs      0.1.2.99 2026-04-28 [2] Github (cboettig/duckdbfs@0b48916)
    #>  ellipsis      0.3.3    2026-04-04 [2] CRAN (R 4.5.2)
    #>  evaluate      1.0.5    2025-08-27 [2] CRAN (R 4.5.0)
    #>  fastmap       1.2.0    2024-05-15 [2] CRAN (R 4.5.0)
    #>  fs            2.1.0    2026-04-18 [2] CRAN (R 4.5.2)
    #>  generics      0.1.4    2025-05-09 [2] CRAN (R 4.5.0)
    #>  glue          1.8.1    2026-04-17 [2] CRAN (R 4.5.2)
    #>  htmltools     0.5.9    2025-12-04 [2] CRAN (R 4.5.2)
    #>  httr2         1.2.3    2026-06-23 [2] CRAN (R 4.5.2)
    #>  icesDatras    1.5.1    2026-05-10 [2] Github (einarhjorleifsson/icesDatras@870daf6)
    #>  knitr         1.51     2025-12-20 [2] CRAN (R 4.5.2)
    #>  lifecycle     1.0.5    2026-01-08 [2] CRAN (R 4.5.2)
    #>  magrittr      2.0.5    2026-04-04 [2] CRAN (R 4.5.2)
    #>  memoise       2.0.1    2021-11-26 [2] CRAN (R 4.5.0)
    #>  obus        * 2026.07  2026-07-01 [1] local
    #>  otel          0.2.0    2025-08-29 [2] CRAN (R 4.5.0)
    #>  pillar        1.11.1   2025-09-17 [2] CRAN (R 4.5.0)
    #>  pkgbuild      1.4.8    2025-05-26 [2] CRAN (R 4.5.0)
    #>  pkgconfig     2.0.3    2019-09-22 [2] CRAN (R 4.5.0)
    #>  pkgload       1.5.3    2026-06-15 [2] CRAN (R 4.5.2)
    #>  purrr         1.2.2    2026-04-10 [2] CRAN (R 4.5.2)
    #>  R6            2.6.1    2025-02-15 [2] CRAN (R 4.5.0)
    #>  rappdirs      0.3.4    2026-01-17 [2] CRAN (R 4.5.2)
    #>  rlang         1.2.0    2026-04-06 [2] CRAN (R 4.5.2)
    #>  rmarkdown     2.31     2026-03-26 [2] CRAN (R 4.5.2)
    #>  rstudioapi    0.19.0   2026-06-11 [2] CRAN (R 4.5.2)
    #>  sessioninfo   1.2.4    2026-06-04 [2] CRAN (R 4.5.2)
    #>  tibble        3.3.1    2026-01-11 [2] CRAN (R 4.5.2)
    #>  tidyselect    1.2.1    2024-03-11 [2] CRAN (R 4.5.0)
    #>  usethis       3.2.1    2025-09-06 [2] CRAN (R 4.5.0)
    #>  utf8          1.2.6    2025-06-08 [2] CRAN (R 4.5.0)
    #>  vctrs         0.7.3    2026-04-11 [2] CRAN (R 4.5.2)
    #>  withr         3.0.3    2026-06-19 [2] CRAN (R 4.5.2)
    #>  xfun          0.59     2026-06-19 [2] CRAN (R 4.5.2)
    #>  yaml          2.3.12   2025-12-10 [2] CRAN (R 4.5.2)
    #> 
    #>  [1] /private/var/folders/14/1_h9q5hn2h93byhrkzp8jfj00000gp/T/RtmpjiEUCC/temp_libpatha79b47c5350c
    #>  [2] /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/library
    #>  * ── Packages attached to the search path.
    #> 
    #> ──────────────────────────────────────────────────────────────────────────────
