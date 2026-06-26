# obus

## Preamble

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

``` R
https://heima.hafro.is/~einarhj/datras/HH.parquet
https://heima.hafro.is/~einarhj/datras/HL.parquet
https://heima.hafro.is/~einarhj/datras/CA.parquet
```

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
#>  10.232   2.473  29.821
```

| type |     rows | cols |
|:-----|---------:|-----:|
| HH   |   150261 |   70 |
| HL   | 14397334 |   30 |
| CA   |  5964714 |   35 |

Number of records and variables

All tables use standard column names and correct variable types. If your
downstream code depends on the old DATRAS column names, revert with:

``` r

hl |> dr_translate(from = "new", to = "old")
#> # A tibble: 14,397,334 × 30
#>    RecordType `-`    Quarter Country Ship  Gear  SweepLngt GearEx DoorType StNo 
#>    <chr>      <chr>    <int> <chr>   <chr> <chr>     <int> <chr>  <chr>    <chr>
#>  1 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     1    
#>  2 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     2    
#>  3 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     2    
#>  4 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     2    
#>  5 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     2    
#>  6 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     2    
#>  7 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     2    
#>  8 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     2    
#>  9 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     2    
#> 10 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     2    
#> # ℹ 14,397,324 more rows
#> # ℹ 20 more variables: HaulNo <int>, SpecCodeType <chr>, SpecCode <chr>,
#> #   SpecVal <chr>, Sex <chr>, TotalNo <dbl>, CatIdentifier <int>, NoMeas <int>,
#> #   SubFactor <dbl>, SubWgt <int>, CatCatchWgt <int>, LngtCode <chr>,
#> #   LngtClass <int>, CANoAtLngt <dbl>, DevStage <chr>, LenMeasType <chr>,
#> #   DateofCalculation <int>, Valid_Aphia <int>, Year <dbl>, .id <chr>
```

The XML API
([`icesDatras::getDATRAS`](https://rdrr.io/pkg/icesDatras/man/getDATRAS.html))
is also available via `source = "xml"` — useful for targeted queries by
survey, year, and quarter without downloading the full table.

## Connecting

Rather than importing, you can open a lazy DuckDB connection to the same
parquet files. Nothing is downloaded until you explicitly call
[`collect()`](https://dplyr.tidyverse.org/reference/compute.html):

``` r

system.time({
  hh <- dr_con("HH")
  hl <- dr_con("HL")
})
#>    user  system elapsed 
#>   0.083   0.009   0.317
```

The connection is nearly instant — DuckDB reads only the file index, not
the data. You then use ordinary [dplyr](https://dplyr.tidyverse.org)
verbs to filter, join, and compute; DuckDB translates them to SQL and
executes against the remote file. Only the rows and columns you actually
need travel over the wire:

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
#>   0.416   0.055   0.542
glimpse(cod)
#> Rows: 152,918
#> Columns: 9
#> $ .id       <chr> "NS-IBTS:1978:1:DK:26SA:HT:5:5", "NS-IBTS:1978:1:DK:26SA:HT:…
#> $ Survey    <chr> "NS-IBTS", "NS-IBTS", "NS-IBTS", "NS-IBTS", "NS-IBTS", "NS-I…
#> $ Year      <dbl> 1978, 1978, 1978, 1978, 1978, 1978, 1978, 1978, 1978, 1978, …
#> $ lon       <dbl> 6.5167, 6.5167, 6.5167, 4.9500, 5.3167, 5.9500, 5.9500, 5.95…
#> $ lat       <dbl> 55.5167, 55.5167, 55.5167, 55.6500, 56.3333, 55.7000, 55.700…
#> $ latin     <chr> "Gadus morhua", "Gadus morhua", "Gadus morhua", "Gadus morhu…
#> $ length_cm <dbl> 15, 18, 32, 14, 20, 18, 19, 20, 48, 12, 13, 15, 16, 17, 18, …
#> $ n_haul    <dbl> 1, 2, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1, 2, 1, 1, …
#> $ n_hour    <dbl> 2, 4, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2, 4, 2, 2, …
```

**The same pipeline works unchanged whether `hh` and `hl` are DuckDB
connections or plain R data frames.** You can mix and match — switch to
[`dr_get()`](https://einarhjorleifsson.github.io/obus/reference/dr_get.md)
when you need the full table in memory, use
[`dr_con()`](https://einarhjorleifsson.github.io/obus/reference/dr_con.md)
when you want lazy filtering. The `dr_add_*()` functions handle both
transparently.

For local parquet files, skip
[`dr_con()`](https://einarhjorleifsson.github.io/obus/reference/dr_con.md)
and use
[`duckdbfs::open_dataset()`](https://cboettig.github.io/duckdbfs/reference/open_dataset.html)
directly — the result is identical:

``` r

hl <- duckdbfs::open_dataset("~/datras/HL.parquet")
```

See the [Parquet and
DuckDB](https://einarhjorleifsson.github.io/obus/articles/parquet_and_duckdb.md)
article for a full explanation of how Parquet, DuckDB, and dbplyr fit
together, including why the file format matters and a step-by-step
walkthrough of lazy query building.

## Specs

``` R
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
#>  date     2026-06-26
#>  pandoc   3.9.0.2 @ /opt/homebrew/bin/ (via rmarkdown)
#>  quarto   1.8.26 @ /usr/local/bin/quarto
#> 
#> ─ Packages ───────────────────────────────────────────────────────────────────
#>  package     * version    date (UTC) lib source
#>  blob          1.3.0      2026-01-14 [2] CRAN (R 4.5.2)
#>  cachem        1.1.0      2024-05-16 [2] CRAN (R 4.5.0)
#>  cli           3.6.6      2026-04-09 [2] CRAN (R 4.5.2)
#>  curl          7.1.0      2026-04-22 [2] CRAN (R 4.5.2)
#>  data.table    1.18.4     2026-05-06 [2] CRAN (R 4.5.2)
#>  DBI           1.3.0      2026-02-25 [2] CRAN (R 4.5.2)
#>  dbplyr        2.6.0      2026-06-17 [2] CRAN (R 4.5.2)
#>  devtools      2.5.2      2026-04-30 [2] CRAN (R 4.5.2)
#>  digest        0.6.39     2025-11-19 [2] CRAN (R 4.5.2)
#>  dplyr       * 1.2.1      2026-04-03 [2] CRAN (R 4.5.2)
#>  duckdb        1.5.4      2026-06-19 [2] CRAN (R 4.5.2)
#>  duckdbfs      0.1.2.99   2026-04-28 [2] Github (cboettig/duckdbfs@0b48916)
#>  ellipsis      0.3.3      2026-04-04 [2] CRAN (R 4.5.2)
#>  evaluate      1.0.5      2025-08-27 [2] CRAN (R 4.5.0)
#>  fastmap       1.2.0      2024-05-15 [2] CRAN (R 4.5.0)
#>  fs            2.1.0      2026-04-18 [2] CRAN (R 4.5.2)
#>  generics      0.1.4      2025-05-09 [2] CRAN (R 4.5.0)
#>  glue          1.8.1      2026-04-17 [2] CRAN (R 4.5.2)
#>  htmltools     0.5.9      2025-12-04 [2] CRAN (R 4.5.2)
#>  httr2         1.2.3      2026-06-23 [2] CRAN (R 4.5.2)
#>  icesDatras    1.5.1      2026-05-10 [2] Github (einarhjorleifsson/icesDatras@870daf6)
#>  knitr         1.51       2025-12-20 [2] CRAN (R 4.5.2)
#>  lifecycle     1.0.5      2026-01-08 [2] CRAN (R 4.5.2)
#>  magrittr      2.0.5      2026-04-04 [2] CRAN (R 4.5.2)
#>  memoise       2.0.1      2021-11-26 [2] CRAN (R 4.5.0)
#>  obus        * 2026.06.23 2026-06-26 [1] local
#>  otel          0.2.0      2025-08-29 [2] CRAN (R 4.5.0)
#>  pillar        1.11.1     2025-09-17 [2] CRAN (R 4.5.0)
#>  pkgbuild      1.4.8      2025-05-26 [2] CRAN (R 4.5.0)
#>  pkgconfig     2.0.3      2019-09-22 [2] CRAN (R 4.5.0)
#>  pkgload       1.5.3      2026-06-15 [2] CRAN (R 4.5.2)
#>  purrr         1.2.2      2026-04-10 [2] CRAN (R 4.5.2)
#>  R6            2.6.1      2025-02-15 [2] CRAN (R 4.5.0)
#>  rappdirs      0.3.4      2026-01-17 [2] CRAN (R 4.5.2)
#>  rlang         1.2.0      2026-04-06 [2] CRAN (R 4.5.2)
#>  rmarkdown     2.31       2026-03-26 [2] CRAN (R 4.5.2)
#>  rstudioapi    0.19.0     2026-06-11 [2] CRAN (R 4.5.2)
#>  sessioninfo   1.2.4      2026-06-04 [2] CRAN (R 4.5.2)
#>  tibble        3.3.1      2026-01-11 [2] CRAN (R 4.5.2)
#>  tidyselect    1.2.1      2024-03-11 [2] CRAN (R 4.5.0)
#>  usethis       3.2.1      2025-09-06 [2] CRAN (R 4.5.0)
#>  utf8          1.2.6      2025-06-08 [2] CRAN (R 4.5.0)
#>  vctrs         0.7.3      2026-04-11 [2] CRAN (R 4.5.2)
#>  withr         3.0.3      2026-06-19 [2] CRAN (R 4.5.2)
#>  xfun          0.59       2026-06-19 [2] CRAN (R 4.5.2)
#>  yaml          2.3.12     2025-12-10 [2] CRAN (R 4.5.2)
#> 
#>  [1] /private/var/folders/14/1_h9q5hn2h93byhrkzp8jfj00000gp/T/RtmpmwZd22/temp_libpatha84d46e88914
#>  [2] /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/library
#>  * ── Packages attached to the search path.
#> 
#> ──────────────────────────────────────────────────────────────────────────────
```
