
# obus

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/imbus)](https://CRAN.R-project.org/package=imbus)
<!-- badges: end -->

The aim of {obus} to provide users with tidy DATRAS tables with
non-ambiguous variables.

That said, {obus} is a temporary experimental package used to explore
various DATRAS data connections and wrapper functions to make life a
little easier for everyday user. Some of that may be taken up in a more
official package. Or possibly not.

For purist, one regrets to inform that this package has quite some
number of dependencies (see
[DESCRIPTION](https://raw.githubusercontent.com/einarhjorleifsson/obus/refs/heads/master/DESCRIPTION)).
It should however be possible to trim down that fat.

## Installation

You can install the development version of {obus} from
[GitHub](https://github.com/einarhjorleifsson/obus) running:

``` r
remotes::install_github("einarhjorleifsson/obus")
```

In some cases {obus} uses wrapper functions depending on {icesDatras}
features that have, as of yet, not been taken up in the official ICES
version (issues pending) install that package via:

``` r
remotes::install_github("einarhjorleifsson/icesDatras")
```

There are two ways to connect to the DATRAS data, either by importing
the whole datasets into R or by making an in-process DuckDB database
connection.

``` r
library(obus)
```

## Importing

The fastest way to **import** the full DATRAS data into R is:

``` r
system.time({
  hh <- dr_get("HH", from = "parquet")
  hl <- dr_get("HL", from = "parquet")
  ca <- dr_get("CA", from = "parquet")
})
#>    user  system elapsed 
#>  21.921   3.608   4.097
```

So we are talking about less than 5 seconds if you sitting on the optic
fiber. If you are connected via wifi this may take closer to 60 seconds.
Whatever the case one can assume that nobody will complain given that
the dimension just imported are as follows:

| type |     rows | cols |
|:-----|---------:|-----:|
| HL   |   146944 |   74 |
| HH   | 14092724 |   36 |
| CA   |  5800702 |   38 |

Number of records and variables

The above fast access is achieved by importing from parquet files that
are hosted on a conventional http-server. The parquet data source is as
of now **not** a mirror of the data residing at ICES, but a recent copy.
ICES datacenter is currently exploring ways to serve a mirror of the
DATRAS data via parquet files hosted on a cloud service.

If one wants an up-to-date mirror one could use a slower route using a
new API from the ICES datacenter. In R one can use the
icesDatras::get_datras_unaggregated_data function. That function has
been wrapped into dr_get so one can get data from many surveys with one
command. E.g. all surveys from 2025 can be obtained by:

``` r
hh <- obus::dr_get("HH", years = 2025, from = "new")
```

## Connecting

Although the DATRAS data can not be considered big data, one can pretend
that it is and use techniques developed for such datasets. So instead of
importing the full dataset into R one can generate a connection to the
parquet files (remember, these are not fully up-to-date) using
in-process DuckDB database.

### HH data

``` r
hh <- dr_con("HH")
hh |> glimpse()
#> Rows: ??
#> Columns: 74
#> Database: DuckDB 1.4.3 [unknown@Linux 5.10.0-33-amd64:R 4.4.1/:memory:]
#> $ RecordHeader            <chr> "﻿HH", "HH", "HH", "HH", "HH", "HH", "HH", "HH…
#> $ Survey                  <chr> "BITS", "BITS", "BITS", "BITS", "BITS", "BITS"…
#> $ Quarter                 <int> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1…
#> $ Country                 <chr> "DK", "DK", "DK", "DK", "DK", "DK", "DK", "DK"…
#> $ Platform                <chr> "26D4", "26D4", "26D4", "26D4", "26D4", "26D4"…
#> $ Gear                    <chr> "CAM", "CAM", "CAM", "EXP", "EXP", "GRT", "GRT…
#> $ SweepLength             <int> NA, NA, NA, 110, 110, NA, NA, NA, NA, NA, NA, …
#> $ GearExceptions          <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ DoorType                <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ StationName             <chr> "150", "151", "152", "149", "147", "10", "101"…
#> $ HaulNumber              <int> 67, 68, 69, 66, 65, 8, 54, 2, 55, 56, 57, 59, …
#> $ Year                    <int> 1991, 1991, 1991, 1991, 1991, 1991, 1991, 1991…
#> $ Month                   <int> 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3…
#> $ Day                     <int> 20, 20, 20, 19, 19, 6, 17, 5, 17, 17, 17, 17, …
#> $ StartTime               <chr> "0514", "0644", "0923", "2128", "1829", "1417"…
#> $ DepthStratum            <chr> "11", "11", "12", "12", "12", "10", "11", "9",…
#> $ HaulDuration            <int> 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60…
#> $ DayNight                <chr> "D", "D", "D", "N", "N", "D", "D", "D", "D", "…
#> $ ShootLatitude           <dbl> 55.6000, 55.6667, 55.5167, 55.4500, 55.5500, 5…
#> $ ShootLongitude          <dbl> 16.2500, 16.2667, 16.1667, 15.1167, 15.1833, 1…
#> $ HaulLatitude            <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ HaulLongitude           <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ StatisticalRectangle    <chr> "40G6", "40G6", "40G6", "39G5", "40G5", "38G4"…
#> $ BottomDepth             <int> 76, 71, 80, 83, 80, 47, 79, 34, 60, 80, 80, 73…
#> $ HaulValidity            <chr> "V", "V", "V", "V", "V", "V", "V", "V", "V", "…
#> $ HydrographicStationID   <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, "104+5", N…
#> $ StandardSpeciesCode     <chr> "1", "1", "1", "1", "1", "1", "1", "1", "1", "…
#> $ BycatchSpeciesCode      <chr> "1", "1", "1", "1", "1", "1", "1", "1", "1", "…
#> $ DataType                <chr> "C", "C", "C", "C", "C", "C", "C", "C", "C", "…
#> $ NetOpening              <dbl> NA, 5, 5, 7, 16, 3, 3, 4, 3, 3, 3, 3, 3, 3, 3,…
#> $ Rigging                 <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ Tickler                 <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ Distance                <dbl> 6111, 6482, 6482, 6667, 8519, 6667, 6482, 6296…
#> $ WarpLength              <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ WarpDiameter            <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ WarpDensity             <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ DoorSurface             <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ DoorWeight              <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ DoorSpread              <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ WingSpread              <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ Buoyancy                <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ KiteArea                <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ GroundRopeWeight        <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ TowDirection            <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ SpeedGround             <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ SpeedWater              <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ SurfaceCurrentDirection <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ SurfaceCurrentSpeed     <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ BottomCurrentDirection  <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ BottomCurrentSpeed      <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ WindDirection           <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ WindSpeed               <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ SwellDirection          <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ SwellHeight             <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ SurfaceTemperature      <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ BottomTemperature       <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ SurfaceSalinity         <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ BottomSalinity          <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ ThermoCline             <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ ThermoClineDepth        <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ CodendMesh              <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ SecchiDepth             <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ Turbidity               <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ TidePhase               <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ TideSpeed               <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ PelagicSamplingType     <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ MinTrawlDepth           <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ MaxTrawlDepth           <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ SurveyIndexArea         <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ EDOM                    <int> 20250401, 20250401, 20250401, 20250401, 202504…
#> $ ReasonHaulDisruption    <lgl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ DateofCalculation       <chr> "", "", "", "", "", "", "", "", "", "", "", ""…
#> $ .id                     <chr> "BITS:1991:1:DK:26D4:CAM:150:67", "BITS:1991:1…
#> $ time                    <dttm> 1991-03-20 05:14:00, 1991-03-20 06:44:00, 199…
```

### HL data

``` r
hl <- dr_con("HL")
hl |> glimpse()
#> Rows: ??
#> Columns: 7
#> Database: DuckDB 1.4.3 [unknown@Linux 5.10.0-33-amd64:R 4.4.1/:memory:]
#> $ .id              <chr> "BITS:1991:1:DE:06S1:H20:48:43", "BITS:1991:1:DE:06S1…
#> $ latin            <chr> "Pleuronectes platessa", "Pleuronectes platessa", "Po…
#> $ length_cm        <dbl> 24.0, 25.0, 24.0, 15.0, 15.5, 16.0, 16.5, 17.0, 17.5,…
#> $ SpeciesSex       <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, N…
#> $ DevelopmentStage <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, N…
#> $ n                <dbl> 1.0, 2.0, 1.0, 4.5, 4.5, 14.0, 28.5, 9.5, 9.5, 23.5, …
#> $ cpue             <dbl> 2, 4, 2, 9, 9, 28, 57, 19, 19, 47, 38, 9, 9, 376, 376…
```

### CA data

``` r
ca <- dr_con("CA")
ca |> glimpse()
#> Rows: ??
#> Columns: 5
#> Database: DuckDB 1.4.3 [unknown@Linux 5.10.0-33-amd64:R 4.4.1/:memory:]
#> $ .id           <chr> "BITS:1991:1:SE:77AR:GOV:71:6", "BITS:1991:1:SE:77AR:GOV…
#> $ latin         <chr> "Gadus morhua", "Gadus morhua", "Gadus morhua", "Gadus m…
#> $ length_cm     <dbl> 34, 36, 39, 40, 43, 45, 30, 31, 34, 35, 38, 43, 44, 45, …
#> $ IndividualSex <chr> "M", "F", "F", "F", "F", "F", "M", "M", "M", "M", "M", "…
#> $ LiverWeight   <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
```

### Data processing using a connection

For those familiar with using dplyr-verbs to process data most of those
function as well as many base-R functions can be used to process the
data. E.g. one can get all survey stations for the third quarter in 2025
and add to that the number of cod observed using the following script:

``` r
data <-
  # Process the data in DuckDB
  hh |> 
  filter(Year == 2025,
         Quarter == 3) |> 
  left_join(hl |> 
              filter(latin == "Gadus morhua") |> 
              group_by(.id) |> 
              summarise(n = sum(n, na.rm = TRUE)),
            by = join_by(.id)) |> 
  # Import the data into R
  collect() |> 
  mutate(n = replace_na(n, 0))
```

Here all the code steps prior to the collect command are automatically
translated to SQL and passed to the in-process DuckDB. It is only at
collect step that the data is actually imported into R.

## Small print

This stuff is in development, thus bugs, snags and errors are expected.
{obus} still has some experimental hangover functions that need to be
pruned or removed.

## How did I get here?

    #> ─ Session info ───────────────────────────────────────────────────────────────
    #>  setting  value
    #>  version  R version 4.4.1 (2024-06-14)
    #>  os       Debian GNU/Linux 11 (bullseye)
    #>  system   x86_64, linux-gnu
    #>  ui       X11
    #>  language (EN)
    #>  collate  is_IS.UTF-8
    #>  ctype    is_IS.UTF-8
    #>  tz       Atlantic/Reykjavik
    #>  date     2026-01-26
    #>  pandoc   3.2 @ /usr/lib/rstudio-server/bin/quarto/bin/tools/x86_64/ (via rmarkdown)
    #>  quarto   1.5.57 @ /usr/local/bin/quarto
    #> 
    #> ─ Packages ───────────────────────────────────────────────────────────────────
    #>  package      * version    date (UTC) lib source
    #>  arrow          22.0.0.1   2025-12-23 [2] CRAN (R 4.4.1)
    #>  assertthat     0.2.1      2019-03-21 [2] CRAN (R 4.4.1)
    #>  bit            4.6.0      2025-03-06 [2] CRAN (R 4.4.1)
    #>  bit64          4.6.0-1    2025-01-16 [2] CRAN (R 4.4.1)
    #>  blob           1.3.0      2026-01-14 [2] CRAN (R 4.4.1)
    #>  cachem         1.1.0      2024-05-16 [2] CRAN (R 4.4.1)
    #>  cli            3.6.5      2025-04-23 [2] CRAN (R 4.4.1)
    #>  curl           7.0.0      2025-08-19 [2] CRAN (R 4.4.1)
    #>  data.table     1.18.0     2025-12-24 [2] CRAN (R 4.4.1)
    #>  DBI            1.2.3      2024-06-02 [2] CRAN (R 4.4.1)
    #>  dbplyr         2.5.1      2025-09-10 [2] CRAN (R 4.4.1)
    #>  devtools       2.4.6      2025-10-03 [2] CRAN (R 4.4.1)
    #>  dichromat      2.0-0.1    2022-05-02 [2] CRAN (R 4.4.1)
    #>  digest         0.6.39     2025-11-19 [2] CRAN (R 4.4.1)
    #>  dplyr        * 1.1.4      2023-11-17 [2] CRAN (R 4.4.1)
    #>  duckdb         1.4.3      2025-12-10 [2] CRAN (R 4.4.1)
    #>  duckdbfs       0.1.2      2025-10-12 [2] CRAN (R 4.4.1)
    #>  ellipsis       0.3.2      2021-04-29 [2] CRAN (R 4.4.1)
    #>  evaluate       1.0.5      2025-08-27 [2] CRAN (R 4.4.1)
    #>  farver         2.1.2      2024-05-13 [2] CRAN (R 4.4.1)
    #>  fastmap        1.2.0      2024-05-15 [2] CRAN (R 4.4.1)
    #>  forcats      * 1.0.1      2025-09-25 [2] CRAN (R 4.4.1)
    #>  fs             1.6.6      2025-04-12 [2] CRAN (R 4.4.1)
    #>  generics       0.1.4      2025-05-09 [2] CRAN (R 4.4.1)
    #>  ggplot2      * 4.0.1      2025-11-14 [2] CRAN (R 4.4.1)
    #>  glue           1.8.0      2024-09-30 [2] CRAN (R 4.4.1)
    #>  gtable         0.3.6      2024-10-25 [2] CRAN (R 4.4.1)
    #>  hms            1.1.4      2025-10-17 [2] CRAN (R 4.4.1)
    #>  htmltools      0.5.9      2025-12-04 [2] CRAN (R 4.4.1)
    #>  httr           1.4.7      2023-08-15 [2] CRAN (R 4.4.1)
    #>  icesDatras     1.5.1      2026-01-23 [2] Github (einarhjorleifsson/icesDatras@221fcc9)
    #>  knitr          1.51       2025-12-20 [2] CRAN (R 4.4.1)
    #>  lifecycle      1.0.5      2026-01-08 [2] CRAN (R 4.4.1)
    #>  lubridate    * 1.9.4      2024-12-08 [2] CRAN (R 4.4.1)
    #>  magrittr       2.0.4      2025-09-12 [2] CRAN (R 4.4.1)
    #>  memoise        2.0.1      2021-11-26 [2] CRAN (R 4.4.1)
    #>  obus         * 2026.01.22 2026-01-26 [1] local
    #>  otel           0.2.0      2025-08-29 [2] CRAN (R 4.4.1)
    #>  pillar         1.11.1     2025-09-17 [2] CRAN (R 4.4.1)
    #>  pkgbuild       1.4.8      2025-05-26 [2] CRAN (R 4.4.1)
    #>  pkgconfig      2.0.3      2019-09-22 [2] CRAN (R 4.4.1)
    #>  pkgload        1.4.1      2025-09-23 [2] CRAN (R 4.4.1)
    #>  purrr        * 1.2.1      2026-01-09 [2] CRAN (R 4.4.1)
    #>  R6             2.6.1      2025-02-15 [2] CRAN (R 4.4.1)
    #>  RColorBrewer   1.1-3      2022-04-03 [2] CRAN (R 4.4.1)
    #>  readr        * 2.1.6      2025-11-14 [2] CRAN (R 4.4.1)
    #>  remotes        2.5.0      2024-03-17 [2] CRAN (R 4.4.1)
    #>  rlang          1.1.7      2026-01-09 [2] CRAN (R 4.4.1)
    #>  rmarkdown      2.30       2025-09-28 [2] CRAN (R 4.4.1)
    #>  rstudioapi     0.18.0     2026-01-16 [2] CRAN (R 4.4.1)
    #>  S7             0.2.1      2025-11-14 [2] CRAN (R 4.4.1)
    #>  scales         1.4.0      2025-04-24 [2] CRAN (R 4.4.1)
    #>  sessioninfo    1.2.3      2025-02-05 [2] CRAN (R 4.4.1)
    #>  stringi        1.8.7      2025-03-27 [2] CRAN (R 4.4.1)
    #>  stringr      * 1.6.0      2025-11-04 [2] CRAN (R 4.4.1)
    #>  tibble       * 3.3.1      2026-01-11 [2] CRAN (R 4.4.1)
    #>  tidyr        * 1.3.2      2025-12-19 [2] CRAN (R 4.4.1)
    #>  tidyselect     1.2.1      2024-03-11 [2] CRAN (R 4.4.1)
    #>  tidyverse    * 2.0.0      2023-02-22 [2] CRAN (R 4.4.1)
    #>  timechange     0.3.0      2024-01-18 [2] CRAN (R 4.4.1)
    #>  tzdb           0.5.0      2025-03-15 [2] CRAN (R 4.4.1)
    #>  usethis        3.2.1      2025-09-06 [2] CRAN (R 4.4.1)
    #>  vctrs          0.7.1      2026-01-23 [2] CRAN (R 4.4.1)
    #>  withr          3.0.2      2024-10-28 [2] CRAN (R 4.4.1)
    #>  xfun           0.56       2026-01-18 [2] CRAN (R 4.4.1)
    #>  yaml           2.3.12     2025-12-10 [2] CRAN (R 4.4.1)
    #> 
    #>  [1] /tmp/RtmpM6Zp2g/temp_libpath22b395679a3710
    #>  [2] /heima/einarhj/R/x86_64-pc-linux-gnu-library/4.4
    #>  [3] /usr/local/lib/R/site-library
    #>  [4] /usr/lib/R/site-library
    #>  [5] /usr/lib/R/library
    #>  * ── Packages attached to the search path.
    #> 
    #> ──────────────────────────────────────────────────────────────────────────────
