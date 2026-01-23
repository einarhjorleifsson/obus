
# obus

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/imbus)](https://CRAN.R-project.org/package=imbus)
<!-- badges: end -->

{obus} is a temporary experimental package used to explore various
DATRAS data connections and wrapper functions to make life a little
easier for everyday user. Some of this may be taken up in a more offical
package.

## Installation

You can install the development version of imbus from
[GitHub](https://github.com/einarhjorleifsson/obus) with:

``` r
devtools::install_github("einarhjorleifsson/obus")
```

## Table connections

You can generate a connection to the main DATRAS tables by:

``` r
library(obus)
hh <- dr_con("HH", quiet = FALSE)
hl <- dr_con("HL")
ca <- dr_con("CA")
```

## A little peek

``` r
hh
#> # Source:   table<xkyucrqrkywiooh> [?? x 74]
#> # Database: DuckDB 1.4.3 [unknown@Linux 5.10.0-33-amd64:R 4.4.1/:memory:]
#>    RecordHeader Survey Quarter Country Platform Gear  SweepLength GearExceptions
#>    <chr>        <chr>    <int> <chr>   <chr>    <chr>       <int> <chr>         
#>  1 ﻿HH           BITS         1 DK      26D4     CAM            NA <NA>          
#>  2 HH           BITS         1 DK      26D4     CAM            NA <NA>          
#>  3 HH           BITS         1 DK      26D4     CAM            NA <NA>          
#>  4 HH           BITS         1 DK      26D4     EXP           110 <NA>          
#>  5 HH           BITS         1 DK      26D4     EXP           110 <NA>          
#>  6 HH           BITS         1 DK      26D4     GRT            NA <NA>          
#>  7 HH           BITS         1 DK      26D4     GRT            NA <NA>          
#>  8 HH           BITS         1 DK      26D4     GRT            NA <NA>          
#>  9 HH           BITS         1 DK      26D4     GRT            NA <NA>          
#> 10 HH           BITS         1 DK      26D4     GRT            NA <NA>          
#> # ℹ more rows
#> # ℹ 66 more variables: DoorType <chr>, StationName <chr>, HaulNumber <int>,
#> #   Year <int>, Month <int>, Day <int>, StartTime <chr>, DepthStratum <chr>,
#> #   HaulDuration <int>, DayNight <chr>, ShootLatitude <dbl>,
#> #   ShootLongitude <dbl>, HaulLatitude <dbl>, HaulLongitude <dbl>,
#> #   StatisticalRectangle <chr>, BottomDepth <int>, HaulValidity <chr>,
#> #   HydrographicStationID <chr>, StandardSpeciesCode <chr>, …
hl
#> # Source:   SQL [?? x 7]
#> # Database: DuckDB 1.4.3 [unknown@Linux 5.10.0-33-amd64:R 4.4.1/:memory:]
#>    .id                   latin length_cm SpeciesSex DevelopmentStage     n  cpue
#>    <chr>                 <chr>     <dbl> <chr>      <chr>            <dbl> <dbl>
#>  1 BITS:1991:1:DE:06S1:… Pleu…      24   <NA>       <NA>               1       2
#>  2 BITS:1991:1:DE:06S1:… Pleu…      25   <NA>       <NA>               2       4
#>  3 BITS:1991:1:DE:06S1:… Poll…      24   <NA>       <NA>               1       2
#>  4 BITS:1991:1:DE:06S1:… Clup…      15   <NA>       <NA>               4.5     9
#>  5 BITS:1991:1:DE:06S1:… Clup…      15.5 <NA>       <NA>               4.5     9
#>  6 BITS:1991:1:DE:06S1:… Clup…      16   <NA>       <NA>              14      28
#>  7 BITS:1991:1:DE:06S1:… Clup…      16.5 <NA>       <NA>              28.5    57
#>  8 BITS:1991:1:DE:06S1:… Clup…      17   <NA>       <NA>               9.5    19
#>  9 BITS:1991:1:DE:06S1:… Clup…      17.5 <NA>       <NA>               9.5    19
#> 10 BITS:1991:1:DE:06S1:… Clup…      21   <NA>       <NA>              23.5    47
#> # ℹ more rows
ca
#> # Source:   SQL [?? x 5]
#> # Database: DuckDB 1.4.3 [unknown@Linux 5.10.0-33-amd64:R 4.4.1/:memory:]
#>    .id                          latin        length_cm IndividualSex LiverWeight
#>    <chr>                        <chr>            <dbl> <chr>               <dbl>
#>  1 BITS:1991:1:SE:77AR:GOV:71:6 Gadus morhua        34 M                      NA
#>  2 BITS:1991:1:SE:77AR:GOV:71:6 Gadus morhua        36 F                      NA
#>  3 BITS:1991:1:SE:77AR:GOV:71:6 Gadus morhua        39 F                      NA
#>  4 BITS:1991:1:SE:77AR:GOV:71:6 Gadus morhua        40 F                      NA
#>  5 BITS:1991:1:SE:77AR:GOV:71:6 Gadus morhua        43 F                      NA
#>  6 BITS:1991:1:SE:77AR:GOV:71:6 Gadus morhua        45 F                      NA
#>  7 BITS:1991:1:SE:77AR:GOV:70:5 Gadus morhua        30 M                      NA
#>  8 BITS:1991:1:SE:77AR:GOV:70:5 Gadus morhua        31 M                      NA
#>  9 BITS:1991:1:SE:77AR:GOV:70:5 Gadus morhua        34 M                      NA
#> 10 BITS:1991:1:SE:77AR:GOV:70:5 Gadus morhua        35 M                      NA
#> # ℹ more rows
```
