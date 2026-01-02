# obus

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
#> Columns: 8
#> Database: DuckDB 1.4.3 [unknown@Linux 5.10.0-33-amd64:R 4.4.1/:memory:]
#> $ .id      <chr> "BITS:2013:4:DE:06SL:TVS:24252:36", "BITS:2013:4:DE:06SL:TVS:…
#> $ latin    <chr> "Gadus morhua", "Gadus morhua", "Gadus morhua", "Gadus morhua…
#> $ length   <dbl> 39.0, 40.0, 41.0, 42.0, 44.0, 49.0, 51.0, 52.0, 9.0, 10.0, 13…
#> $ Sex      <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, N…
#> $ DevStage <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, N…
#> $ n        <dbl> 19.2619, 8.2551, 2.7517, 13.7585, 2.7517, 2.7517, 2.7517, 2.7…
#> $ cpue     <dbl> 38.5238, 16.5102, 5.5034, 27.5170, 5.5034, 5.5034, 5.5034, 5.…
#> $ species  <chr> "Atlantic cod", "Atlantic cod", "Atlantic cod", "Atlantic cod…
```

## A little exploration

``` r
library(santoku)
#> 
#> Attaching package: 'santoku'
#> The following object is masked from 'package:tidyr':
#> 
#>     chop
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
              select(.id, latin),
           by = join_by(.id)) |>
  # analyse by grid
  group_by(lon, lat) |> 
  summarise(n_taxa = n_distinct(latin),
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

![](reference/figures/README-demo-1.png)
