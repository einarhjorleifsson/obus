
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
# install.packages("pak")
#pak::pak("einarhjorleifsson/obus")
```

## Table connections

``` r
library(obus)
hh <- dr_con("HH")
hl <- dr_con("HL")
ca <- dr_con("CA")
```

## A little peek

``` r
library(tidyverse)
hl |> glimpse()
#> Rows: ??
#> Columns: 19
#> Database: DuckDB 1.4.3 [unknown@Linux 5.10.0-33-amd64:R 4.4.1/:memory:]
#> $ .id                  <chr> "BITS:2017:1:DE:06SL:TVS:24001:1", "BITS:2003:4:D…
#> $ SpecCodeType         <chr> "W", "W", "W", "W", "W", "W", "W", "W", "W", "W",…
#> $ SpecCode             <chr> "126417", "126417", "126417", "126417", "126417",…
#> $ SpecVal              <chr> "1", "1", "1", "1", "1", "1", "1", "1", "1", "1",…
#> $ Sex                  <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, N…
#> $ TotalNo              <dbl> 149.0, 158.0, 149.0, 158.0, 149.0, 221.0, 221.0, …
#> $ CatIdentifier        <int> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1…
#> $ NoMeas               <int> 149, 158, 149, 158, 149, 221, 221, 221, 221, 221,…
#> $ SubFactor            <dbl> 1.000, 1.000, 1.000, 1.000, 1.000, 1.000, 1.000, …
#> $ SubWgt               <int> NA, NA, NA, NA, NA, 43140, 43140, 43140, 43140, 4…
#> $ CatCatchWgt          <int> 4458, 4700, 4458, 4700, 4458, 43140, 43140, 43140…
#> $ LngtCode             <chr> "0", "0", "0", "0", "0", ".", ".", ".", ".", ".",…
#> $ LngtClass            <int> 145, 165, 150, 170, 155, 310, 320, 330, 220, 230,…
#> $ HLNoAtLngt           <dbl> 5, 4, 12, 13, 9, 1, 2, 5, 24, 24, 17, 18, 14, 10,…
#> $ DevStage             <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, N…
#> $ LenMeasType          <chr> "1", NA, "1", NA, "1", "1", "1", "1", "1", "1", "…
#> $ ValidAphiaID         <chr> "126417", "126417", "126417", "126417", "126417",…
#> $ ScientificName_WoRMS <chr> "Clupea harengus", "Clupea harengus", "Clupea har…
#> $ DateofCalculation    <chr> "20240814", "20250401", "20240814", "20250401", "…
```

## A little exploration

``` r
library(santoku)
# Grid resolution
dx <- 1
dy <- dx / 2
# Limit analysis to certain time and space
hh |> 
  filter(Year %in% 2001:2010,
         between(ShootLong, -20, 25),
         between(ShootLat, -Inf, 65)) |> 
  # assign coordinates to grid
  mutate(lon = ShootLong%/%dx * dx + dx/2,
         lat = ShootLat%/%dy * dy + dy/2) |> 
  left_join(hl |> 
              select(.id, ScientificName_WoRMS),
           by = join_by(.id)) |>
  # analyse by grid
  group_by(lon, lat) |> 
  summarise(n_taxa = n_distinct(ScientificName_WoRMS),
            .groups = "drop") |> 
  # load data into R memory because santoku::chop not in duckdb lingo
  #  chop is also nicer than cut - keeps things more orderly
  collect() |> 
  mutate(n_taxa = chop(n_taxa, breaks = c(0, 25, 50, 75, 100, 125, 150, 200))) |> 
  ggplot(aes(lon, lat, fill = n_taxa)) +
  geom_tile() +
  scale_fill_viridis_d(option = "inferno", direction = -1) +
  coord_quickmap() +
  labs(x = NULL, y = NULL, fill = "Number of\ndistinct taxa",
       caption = "DATRAS 2001-2010, core area: Number of distinct taxa reported per rectangle")
```

<img src="man/figures/README-demo-1.png" width="100%" />
