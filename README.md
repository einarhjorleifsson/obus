
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
[package website](https://einarhjorleifsson.github.io/obus).

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

You can install {obus} from
[GitHub](https://github.com/einarhjorleifsson/obus) using one of:

``` r
remotes::install_github("einarhjorleifsson/obus")
pak::pak("einarhjorleifsson/obus")
```

There are two ways to access the DATRAS data, either by importing the
whole datasets into R or by making an in-process DuckDB database
connection.

``` r
library(obus)
library(dplyr)
```

## Importing

The fastest way to **import** the full DATRAS data into R is:

``` r
system.time({
  hh <- dr_get("HH", source = "parquet")
  hl <- dr_get("HL", source = "parquet")
  ca <- dr_get("CA", source = "parquet")
})
#>    user  system elapsed 
#>  10.269   1.872  29.035
```

So we are talking about around 5 seconds if you’re sitting on the optic
fiber. If you are connected via poor wifi this may take on the order of
a minute. The dr_get is just a thin wrapper around the path stated
above. User can thus access the data without the {obus} as middle man
via e.g.:

    arrow::read_parquet("https://heima.hafro.is/~einarhj/datras/HH.parquet")

And if Python is your preferred platform:

    import pandas as pd
    pd.read_parquet("https://heima.hafro.is/~einarhj/datras/HH.parquet")

Whatever the case one can assume that nobody will complain about the
speed of access, given that the dimensions just imported are as follows:

| type |     rows | cols |
|:-----|---------:|-----:|
| HH   |   150287 |   70 |
| HL   | 14397344 |   30 |
| CA   |  5964650 |   35 |

Number of records and variables

The above fast importing is achieved by importing from parquet files
that are hosted on a conventional https-server. At this stage it is
unclear how much simultaneous traffic it can handle. The way things have
been setup so far is just a proof of concept. By the same nature, do not
expect that the datasets accessed are the latest mirror of the data
residing in ICES Datras Database.

Those familiar with DATRAS data will notice when viewing the data that
the variable names are based on the new lingo. If your downstream
code-flow depends on the old lingo one can easily revert back via:

``` r
hl |> dr_translate(from = "new", to = "old")
#> # A tibble: 14,397,344 × 30
#>    RecordType Survey Quarter Country Ship  Gear  SweepLngt GearEx DoorType StNo 
#>    <chr>      <chr>    <int> <chr>   <chr> <chr>     <int> <chr>  <chr>    <chr>
#>  1 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     1    
#>  2 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     1    
#>  3 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     1    
#>  4 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     1    
#>  5 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     1    
#>  6 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     1    
#>  7 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     1    
#>  8 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     1    
#>  9 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     1    
#> 10 HL         NS-IB…       1 NL      64WB  DHT          45 <NA>   <NA>     1    
#> # ℹ 14,397,334 more rows
#> # ℹ 20 more variables: HaulNo <int>, SpecCodeType <chr>, SpecCode <chr>,
#> #   SpecVal <chr>, Sex <chr>, TotalNo <dbl>, CatIdentifier <int>, NoMeas <int>,
#> #   SubFactor <dbl>, SubWgt <int>, CatCatchWgt <int>, LngtCode <chr>,
#> #   LngtClass <int>, CANoAtLngt <dbl>, DevStage <chr>, LenMeasType <chr>,
#> #   DateofCalculation <int>, Valid_Aphia <int>, Year <dbl>, .id <chr>
```

The old faithful (`icesDatras::getDATRAS`) is wrapped within `dr_get()`
(specify `source = "xml"`), with the addition that variable types are
set, -9 values are turned to NA, and one can retrieve more than one
survey at a time. Here we only dare to call one year of HL-data:

``` r
system.time({
  hl_xml <- dr_get(recordtype = "HL", years = 2026, source = "xml")
})
#>    user  system elapsed 
#>   9.265   2.947  50.610
```

In store we now have:

``` r
hl_xml |> count(Survey)
#>     Survey     n
#> 1     BITS 25115
#> 2  NS-IBTS 48070
#> 3 SCOWCGFS 12307
```

A little faster approach is also in experimental phase
(icesDatras::get_datras_unaggregated_data) but it is not yet a mirror of
the most up to date data (hence here year 2025 is used)

``` r
system.time({
  hl_csv <- dr_get("HL", years = 2025, source = "csv")
})
#>    user  system elapsed 
#>   0.947   0.282   8.805
```

In store we now have:

``` r
hl_csv |> count(Survey)
#>     Survey     n
#> 1     BITS 27084
#> 2      BTS 49393
#> 3     DYFS  4967
#> 4  NL-BSAS  1359
#> 5  NS-IBTS 85341
#> 6   SCOROC  5175
#> 7 SCOWCGFS 10223
#> 8      SNS  2597
```

The above demonstrates the following:

- All approaches return to the user R-dataframes
- The user is generally not interested in how the data is transferred
  over the wire, the function argument source (“xml”, “csv”, “parquet”)
  are here just placed as developmental demos.
- Hosting the full DATRAS dataset as parquet files on a https-server
  provides the fastest download and import time.
- For all practical purposes one could embed the parquet source in
  existing function icesDatras::getDatras - the only thing the user (or
  packages that uses the function) would notice is that he would get:
  - Faster response
  - Variable types are taken care of upstream

The link between https hosted parquet files and the DATRAS database is
something that computer engineers would need to sort out. That is if
parquet distribution is going to be taken up as a default.

## Connecting

Although the DATRAS data can not be considered big data, one can use
techniques developed for such datasets. So instead of importing the full
dataset into R one can generate a connection to the **same** web-hosted
parquet files as above using in-process DuckDB database.

``` r
system.time({
  hh <- dr_con("HH")
  hl <- dr_con("HL")
  ca <- dr_con("CA")
})
#>    user  system elapsed 
#>   0.189   0.030   0.923
class(hl) ; nrow(hl)
#> [1] "tbl_duckdb_connection" "tbl_dbi"               "tbl_sql"              
#> [4] "tbl_lazy"              "tbl"
#> [1] NA
hl |> glimpse()
#> Rows: ??
#> Columns: 30
#> Database: DuckDB 1.5.2 [root@Darwin 25.5.0:R 4.5.2/:memory:]
#> $ RecordHeader          <chr> "HL", "HL", "HL", "HL", "HL", "HL", "HL", "HL", …
#> $ Survey                <chr> "NS-IBTS", "NS-IBTS", "NS-IBTS", "NS-IBTS", "NS-…
#> $ Quarter               <int> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
#> $ Country               <chr> "NL", "NL", "NL", "NL", "NL", "NL", "NL", "NL", …
#> $ Platform              <chr> "64WB", "64WB", "64WB", "64WB", "64WB", "64WB", …
#> $ Gear                  <chr> "DHT", "DHT", "DHT", "DHT", "DHT", "DHT", "DHT",…
#> $ SweepLength           <int> 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, …
#> $ GearExceptions        <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ DoorType              <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ StationName           <chr> "1", "1", "1", "1", "1", "1", "1", "1", "1", "1"…
#> $ HaulNumber            <int> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
#> $ SpeciesCodeType       <chr> "T", "T", "T", "T", "T", "T", "T", "T", "T", "T"…
#> $ SpeciesCode           <chr> "164758", "161722", "161722", "161722", "161722"…
#> $ SpeciesValidity       <chr> "4", "1", "1", "1", "1", "1", "1", "1", "1", "1"…
#> $ IndividualSex         <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ TotalNumber           <dbl> 1800, 117, 117, 117, 117, 117, 117, 117, 117, 11…
#> $ SpeciesCategory       <int> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
#> $ SubsampledNumber      <int> NA, 117, 117, 117, 117, 117, 117, 117, 117, 117,…
#> $ SubsamplingFactor     <dbl> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
#> $ SubsampleWeight       <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ SpeciesCategoryWeight <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ LengthCode            <chr> NA, "0", "0", "0", "0", "0", "0", "0", "0", "0",…
#> $ LengthClass           <int> NA, 15, 95, 100, 105, 110, 115, 120, 125, 130, 1…
#> $ NumberAtLength        <dbl> NA, 1, 1, 2, 6, 10, 9, 12, 18, 16, 16, 12, 7, 5,…
#> $ DevelopmentStage      <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ LengthType            <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ DateofCalculation     <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ Valid_Aphia           <int> 126438, 126417, 126417, 126417, 126417, 126417, …
#> $ Year                  <dbl> 1965, 1965, 1965, 1965, 1965, 1965, 1965, 1965, …
#> $ .id                   <chr> "NS-IBTS:1965:1:NL:64WB:DHT:1:1", "NS-IBTS:1965:…
```

Note here that beside the above function accessing the **same parquet
files** as when using `dr_get`:

- the time is almost instantaneous
- the objects are some kind of a tibble of variant type sql, more
  specifically a duckdb_connection
- the nrow returned is NA (one can get that number via `hl |> count()`
- the data feel like R-dataframe(s)

Let’s look at the hl object from another angle:

``` r
hl |> show_query()
#> <SQL>
#> SELECT *
#> FROM adrgfsvdmqeiamm
```

So the object hl is actually some kind of an SQL-query. What happens
behind the scene when using dr_con is:

- A tiny database engine called DuckDB is started silently from R — no
  separate server or installation needed (The feature is installed
  initially on the computer when {obus} is installed).
- DuckDB opens an HTTP connection to the parquet file on the remote
  server and reads only its *index* (column names, types, and where each
  chunk of rows lives in the file). This is why the connection is nearly
  instantaneous — only limited number of records have travelled over the
  wire, just to give the user a whiff of the data.

Now we can do the usual:

``` r
q <- 
  hl |> 
  filter(Survey == "NS-IBTS", Year == 2026, Quarter == 1)
```

What we now have in store is:

``` r
q |> show_query()
#> <SQL>
#> SELECT adrgfsvdmqeiamm.*
#> FROM adrgfsvdmqeiamm
#> WHERE (Survey = 'NS-IBTS') AND ("Year" = 2026.0) AND ("Quarter" = 1.0)
```

Ergo:

- We have added to the original SQL query a filter using dplyr-verbs
- We no longer have preset argument within a function (like
  icesDatras::getDATRAS) but supply that via the dplyr-filter function

The magic is that we now have a system were we can supply any filter to
any of the variables. And any other magic one may spin up using the
{dplyr} verbs. E.g.:

``` r
q <- 
  hl |> 
  mutate(length_cm = dplyr::case_when(
          LengthCode == "-9" ~ NA_real_,          # Invalid length codes marked as NA
          LengthCode %in% c(".", "0") ~ LengthClass / 10,  # Divide by 10
          LengthCode %in% c("1", "2", "5") ~ LengthClass,  # Direct mapping
          TRUE ~ NA_real_                                  # Any other case is NA
        )) |> 
  filter(Gear == "GOV", length_cm > 50)
```

``` r
q |> show_query()
#> <SQL>
#> SELECT q01.*
#> FROM (
#>   SELECT
#>     adrgfsvdmqeiamm.*,
#>     CASE
#> WHEN (LengthCode = '-9') THEN NULL
#> WHEN (LengthCode IN ('.', '0')) THEN (LengthClass / 10.0)
#> WHEN (LengthCode IN ('1', '2', '5')) THEN LengthClass
#> ELSE NULL
#> END AS length_cm
#>   FROM adrgfsvdmqeiamm
#> ) q01
#> WHERE (Gear = 'GOV') AND (length_cm > 50.0)
```

We now have to decide how much code to hide from the average user. E.g.
instead of the mutate above to convert all length classes to centimeters
we could use an experimental function:

``` r
q <- 
  hl |> 
  dr_add_length_cm() |> 
  filter(Gear == "GOV", length_cm > 50)
```

We can also join two or more tables:

``` r
species <- duckdbfs::open_dataset("https://heima.hafro.is/~einarhj/datras/species.parquet")
q <- 
  hl |> 
  left_join(hh |> select(.id, DataType, HaulDuration, HaulValidity,
                         lon = ShootLongitude, lat = ShootLatitude),
            by = join_by(.id)) |> 
  left_join(species,
            by = join_by(Valid_Aphia == aphia)) |>  # Note: Valid_Aphia is the name returned from the parquet; alignment with the new-style standard name (ValidAphiaID) is pending clarification with the ICES Datacenter
  dr_add_length_cm() |> 
  dr_add_n_and_cpue() |> 
  filter(HaulValidity == "V",
         !is.na(LengthCode),
         latin == "Gadus morhua",
         Survey %in% c("NS-IBTS", "SCOWCGFS"),
         Quarter == 1) |> 
  select(.id, Survey, Year, lon, lat, species, length_cm, n_haul, n_hour)
```

We have now built quite a substantive SQL query (without knowing any
SQL):

``` r
q |> show_query()
#> <SQL>
#> SELECT
#>   ".id",
#>   Survey,
#>   "Year",
#>   lon,
#>   lat,
#>   species,
#>   length_cm,
#>   n_haul,
#>   (n_haul / HaulDuration) * 60.0 AS n_hour
#> FROM (
#>   SELECT
#>     q01.*,
#>     CASE
#> WHEN (DataType = 'C') THEN (((NumberAtLength * SubsamplingFactor) * HaulDuration) / 60.0)
#> WHEN (DataType = 'R') THEN (NumberAtLength * SubsamplingFactor)
#> WHEN (DataType = 'P') THEN (NumberAtLength * SubsamplingFactor)
#> WHEN (DataType = 'S') THEN (NumberAtLength * SubsamplingFactor)
#> WHEN (DataType = '-9') THEN NULL
#> WHEN ((DataType IS NULL)) THEN NULL
#> ELSE NULL
#> END AS n_haul
#>   FROM (
#>     SELECT
#>       q01.*,
#>       CASE
#> WHEN (LengthCode = '-9') THEN NULL
#> WHEN (LengthCode IN ('.', '0')) THEN (LengthClass / 10.0)
#> WHEN (LengthCode IN ('1', '2', '5')) THEN LengthClass
#> ELSE NULL
#> END AS length_cm
#>     FROM (
#>       SELECT
#>         adrgfsvdmqeiamm.*,
#>         DataType,
#>         HaulDuration,
#>         HaulValidity,
#>         ShootLongitude AS lon,
#>         ShootLatitude AS lat,
#>         latin,
#>         species
#>       FROM adrgfsvdmqeiamm
#>       LEFT JOIN ysegjshareclpkb
#>         ON (adrgfsvdmqeiamm.".id" = ysegjshareclpkb.".id")
#>       LEFT JOIN fwwxahawbjpsqjs
#>         ON (adrgfsvdmqeiamm.Valid_Aphia = fwwxahawbjpsqjs.aphia)
#>     ) q01
#>   ) q01
#> ) q01
#> WHERE
#>   (HaulValidity = 'V') AND
#>   (NOT((LengthCode IS NULL))) AND
#>   (latin = 'Gadus morhua') AND
#>   (Survey IN ('NS-IBTS', 'SCOWCGFS')) AND
#>   ("Quarter" = 1.0)
```

Let’s now import the data:

``` r
system.time(
  data <- q |> collect()
)
#>    user  system elapsed 
#>   0.425   0.044   0.469
```

So we basically have obtained some ~150 thousand cod measurements from
two surveys (1965 onwards) where we have:

- standardized the length
- obtained the number of cod in the haul
- standardized the number to an hour

And this less than 1 second!

It needs to be mentioned that the same code can be used if the original
source (hh and hl objects) were just dataframes already imported into R,
either from the parquet files or via icesDatras::getDATRAS, the latter
with only some minor additional twist.

It also should be highlighted than any local bookkeeping of Datras data
files is kind of obsolete, unless one expects to be off-line. In these
days and ages even vessels on the high seas are rarely without decent
internet connection.

## Specs

    #> ─ Session info ───────────────────────────────────────────────────────────────
    #>  setting  value
    #>  version  R version 4.5.2 (2025-10-31)
    #>  os       macOS Tahoe 26.5
    #>  system   aarch64, darwin20
    #>  ui       X11
    #>  language (EN)
    #>  collate  en_US.UTF-8
    #>  ctype    en_US.UTF-8
    #>  tz       Atlantic/Reykjavik
    #>  date     2026-05-29
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
    #>  dbplyr        2.5.2      2026-02-13 [2] CRAN (R 4.5.2)
    #>  devtools      2.5.2      2026-04-30 [2] CRAN (R 4.5.2)
    #>  digest        0.6.39     2025-11-19 [2] CRAN (R 4.5.2)
    #>  dplyr       * 1.2.1      2026-04-03 [2] CRAN (R 4.5.2)
    #>  duckdb        1.5.2      2026-04-13 [2] CRAN (R 4.5.2)
    #>  duckdbfs      0.1.2.99   2026-04-28 [2] Github (cboettig/duckdbfs@0b48916)
    #>  ellipsis      0.3.3      2026-04-04 [2] CRAN (R 4.5.2)
    #>  evaluate      1.0.5      2025-08-27 [2] CRAN (R 4.5.0)
    #>  fastmap       1.2.0      2024-05-15 [2] CRAN (R 4.5.0)
    #>  fs            2.1.0      2026-04-18 [2] CRAN (R 4.5.2)
    #>  generics      0.1.4      2025-05-09 [2] CRAN (R 4.5.0)
    #>  glue          1.8.1      2026-04-17 [2] CRAN (R 4.5.2)
    #>  htmltools     0.5.9      2025-12-04 [2] CRAN (R 4.5.2)
    #>  httr2         1.2.2      2025-12-08 [2] CRAN (R 4.5.2)
    #>  icesDatras    1.5.1      2026-05-10 [2] Github (einarhjorleifsson/icesDatras@870daf6)
    #>  knitr         1.51       2025-12-20 [2] CRAN (R 4.5.2)
    #>  lifecycle     1.0.5      2026-01-08 [2] CRAN (R 4.5.2)
    #>  magrittr      2.0.5      2026-04-04 [2] CRAN (R 4.5.2)
    #>  memoise       2.0.1      2021-11-26 [2] CRAN (R 4.5.0)
    #>  obus        * 2026.01.30 2026-05-29 [1] local
    #>  otel          0.2.0      2025-08-29 [2] CRAN (R 4.5.0)
    #>  pillar        1.11.1     2025-09-17 [2] CRAN (R 4.5.0)
    #>  pkgbuild      1.4.8      2025-05-26 [2] CRAN (R 4.5.0)
    #>  pkgconfig     2.0.3      2019-09-22 [2] CRAN (R 4.5.0)
    #>  pkgload       1.5.2      2026-04-22 [2] CRAN (R 4.5.2)
    #>  purrr         1.2.2      2026-04-10 [2] CRAN (R 4.5.2)
    #>  R6            2.6.1      2025-02-15 [2] CRAN (R 4.5.0)
    #>  rappdirs      0.3.4      2026-01-17 [2] CRAN (R 4.5.2)
    #>  rlang         1.2.0      2026-04-06 [2] CRAN (R 4.5.2)
    #>  rmarkdown     2.31       2026-03-26 [2] CRAN (R 4.5.2)
    #>  rstudioapi    0.18.0     2026-01-16 [2] CRAN (R 4.5.2)
    #>  sessioninfo   1.2.3      2025-02-05 [2] CRAN (R 4.5.0)
    #>  tibble        3.3.1      2026-01-11 [2] CRAN (R 4.5.2)
    #>  tidyr         1.3.2      2025-12-19 [2] CRAN (R 4.5.2)
    #>  tidyselect    1.2.1      2024-03-11 [2] CRAN (R 4.5.0)
    #>  usethis       3.2.1      2025-09-06 [2] CRAN (R 4.5.0)
    #>  utf8          1.2.6      2025-06-08 [2] CRAN (R 4.5.0)
    #>  vctrs         0.7.3      2026-04-11 [2] CRAN (R 4.5.2)
    #>  withr         3.0.2      2024-10-28 [2] CRAN (R 4.5.0)
    #>  xfun          0.57       2026-03-20 [2] CRAN (R 4.5.2)
    #>  yaml          2.3.12     2025-12-10 [2] CRAN (R 4.5.2)
    #> 
    #>  [1] /private/var/folders/14/1_h9q5hn2h93byhrkzp8jfj00000gp/T/Rtmp6MNse1/temp_libpathed5f71ab9389
    #>  [2] /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/library
    #>  * ── Packages attached to the search path.
    #> 
    #> ──────────────────────────────────────────────────────────────────────────────
