
# obus

## Preamble

*2026-05-28: Currently the steps below may not run / are not
reproducible. Possibly not even the installation process. Fix will be
made before 2026-06-01.*

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/imbus)](https://CRAN.R-project.org/package=imbus)
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
rudimentary [web-space](https://github.com/einarhjorleifsson/obus).

This README is definitively not a gentle introduction for the novice.
The current form is a dialogue instigator, aimed at members of the
IMBUS-project.

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
#>  10.555   1.761  38.878
```

So we are talking about around 5 seconds if you sitting on the optic
fiber. If you are connected via poor wifi this may take on the order of
a minute. Whatever the case one can assume that nobody will complain
about the time, given that the dimension just imported are as follows:

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
residing in ICES Datras Database. ICES Datacenter is currently
evaluating/exploring ways provide faster access to the data than
currently available.

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

The old faithful (icesDatras::getDATRAS) is wrapped within the above
function (specify source as “xml”, with the addition that variable type
is set, -9 are turned to NA and one can get more than one survey a time.
Here we only dare to call one year of HL-data:

``` r
system.time({
  hl_xml <- dr_get(recordtype = "HL", years = 2026, source = "xml")
})
#>    user  system elapsed 
#>   9.433   3.083  57.417
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
#>   0.984   0.260   8.397
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
- The user is genarally not interested in how the data is transfered
  over the wire, the function argument source (“xml”, “csv”, “parquet”)
  are here just placed as developmental demos.
- Hosting the full DATRAS dataset as parquet files on a https-server
  provides the fasted download time.
- For all practical purposes one could embed the parquet source in
  existing function icesDatras::getDatras - the only thing the user (or
  packages that uses the function) would notice is that he would get:
  - Faster response
  - Variable types are taken care of upstream

The link between https hosted parquet files and the DATRAS database is
something that computer engineers would need to sort out. That is if
this is going to be taken up by the ICES Datacenter.

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
#>   0.201   0.025   1.012
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
#> FROM uwronfvvqkjjuyt
```

So the object hl is actually some kind of an SQL-query. What happens
behind the scene when using dr_con is:

- A tiny database engine called DuckDB is started silently from R — no
  separate server or installation needed (The feature is installed
  initially on the compute when {obus} is installed).
- DuckDB opens an HTTP connection to the parquet file on the remote
  server and reads only its *index* (column names, types, and where each
  chunk of rows lives in the file). This is why the connection is nearly
  instantaneous — only limited number of records have travelled over the
  wire.

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
#> SELECT uwronfvvqkjjuyt.*
#> FROM uwronfvvqkjjuyt
#> WHERE (Survey = 'NS-IBTS') AND ("Year" = 2026.0) AND ("Quarter" = 1.0)
```

Ergo:

- We have added to the original SQL query a filter using dplyr-verbs
- We no longer have preset arguement within a function (like
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
#>     uwronfvvqkjjuyt.*,
#>     CASE
#> WHEN (LengthCode = '-9') THEN NULL
#> WHEN (LengthCode IN ('.', '0')) THEN (LengthClass / 10.0)
#> WHEN (LengthCode IN ('1', '2', '5')) THEN LengthClass
#> ELSE NULL
#> END AS length_cm
#>   FROM uwronfvvqkjjuyt
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

#### Out of place:

- Every `filter()`, `select()`, or `mutate()` you write in R is silently
  translated into an SQL query. That is what `show_query()` reveals.
  Nothing is computed yet; you are just building up instructions.
- When you finally call `collect()` — or any function that actually
  needs the numbers — DuckDB is clever about what it fetches. If you
  filtered to one survey, it skips the rest of the file entirely. If you
  only selected three columns, the other fifty are never downloaded.
  This is called *predicate and projection pushdown*.
- Only at that point do rows travel from the server to your R session,
  already filtered and shaped exactly as you asked.

We can take a peek via:

- First to observe is that the number rows is unknown
- What may scream at you are the few numbers of variables
- If you want them all just use argument `trim = FALSE` in the
  `dr_con`-function.
- What is trimmed is currently an overkill. What to trim needs
  discussion among the bus-people.
- You get the latin and the ingles name of the species upfront, gone is
  the not-so-useful downstream-analysis aphia numerical code
- Future dream could be to get the actual stock-name here, for those
  stocks that are fixed in space and/or seasonal time.

### Data processing using a connection

For those familiar with using dplyr-verbs to process R data.frames most
of those function as well as many base-R functions can be used to
process the “connected” data. E.g. one can get all survey stations in
2024 and add to that the number of cod observed using the following
script:

``` r
system.time({
  q <-
    # Process the data in DuckDB
    dr_con("HH") |> 
    filter(Year == 2024,
                  Quarter %in% 1:4) |> 
    select(.id, lon = ShootLongitude, lat = ShootLatitude) |> 
    filter(between(lon, 0, 11)) |> 
    left_join(dr_con("HL") |> 
                       filter(latin == "Gadus morhua") |> 
                       group_by(.id) |> 
                       summarise(n_haul = sum(n_haul, na.rm = TRUE)),
                     by = join_by(.id)) |> 
    mutate(n_haul = coalesce(n_haul, 0))
})
#> Error in `filter()`:
#> ℹ In argument: `latin == "Gadus morhua"`
#> Caused by error:
#> ! Object `latin` not found.
q |> glimpse()
#> Rows: ??
#> Columns: 31
#> Database: DuckDB 1.5.2 [root@Darwin 25.5.0:R 4.5.2/:memory:]
#> $ RecordHeader          <chr> "HL", "HL", "HL", "HL", "HL", "HL", "HL", "HL", …
#> $ Survey                <chr> "NS-IBTS", "NS-IBTS", "NS-IBTS", "NS-IBTS", "NS-…
#> $ Quarter               <int> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
#> $ Country               <chr> "GB-SCT", "GB-SCT", "GB-SCT", "GB-SCT", "GB-SCT"…
#> $ Platform              <chr> "74EX", "74EX", "74EX", "74EX", "74EX", "74EX", …
#> $ Gear                  <chr> "GOV", "GOV", "GOV", "GOV", "GOV", "GOV", "GOV",…
#> $ SweepLength           <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ GearExceptions        <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ DoorType              <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ StationName           <chr> "46", "46", "46", "46", "46", "35", "35", "35", …
#> $ HaulNumber            <int> 16, 16, 16, 16, 16, 5, 5, 5, 9, 9, 11, 11, 13, 1…
#> $ SpeciesCodeType       <chr> "T", "T", "T", "T", "T", "T", "T", "T", "T", "T"…
#> $ SpeciesCode           <chr> "164712", "164712", "164712", "164712", "164712"…
#> $ SpeciesValidity       <chr> "1", "1", "1", "1", "1", "1", "1", "1", "1", "1"…
#> $ IndividualSex         <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ TotalNumber           <dbl> 9, 9, 9, 9, 9, 3, 3, 3, 31, 31, 7, 7, 4, 4, 4, 4…
#> $ SpeciesCategory       <int> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
#> $ SubsampledNumber      <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ SubsamplingFactor     <dbl> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
#> $ SubsampleWeight       <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ SpeciesCategoryWeight <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ LengthCode            <chr> "1", "1", "1", "1", "1", "1", "1", "1", "1", "1"…
#> $ LengthClass           <int> 80, 89, 95, 97, 98, 80, 95, 98, 83, 89, 57, 59, …
#> $ NumberAtLength        <dbl> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
#> $ DevelopmentStage      <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ LengthType            <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ DateofCalculation     <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ Valid_Aphia           <int> 126436, 126436, 126436, 126436, 126436, 126436, …
#> $ Year                  <dbl> 1967, 1967, 1967, 1967, 1967, 1967, 1967, 1967, …
#> $ .id                   <chr> "NS-IBTS:1967:1:GB-SCT:74EX:GOV:46:16", "NS-IBTS…
#> $ length_cm             <dbl> 80, 89, 95, 97, 98, 80, 95, 98, 83, 89, 57, 59, …
```

Here all the code steps are automatically translated to SQL and passed
to the in-process DuckDB. We can view the sql via:

``` r
q |> show_query()
#> <SQL>
#> SELECT q01.*
#> FROM (
#>   SELECT
#>     uwronfvvqkjjuyt.*,
#>     CASE
#> WHEN (LengthCode = '-9') THEN NULL
#> WHEN (LengthCode IN ('.', '0')) THEN (LengthClass / 10.0)
#> WHEN (LengthCode IN ('1', '2', '5')) THEN LengthClass
#> ELSE NULL
#> END AS length_cm
#>   FROM uwronfvvqkjjuyt
#> ) q01
#> WHERE (Gear = 'GOV') AND (length_cm > 50.0)
```

The data is not yet in R, we only got a whiff of the data. Only at the
“collect”-step data are imported:

``` r
system.time({
  d <- q |> collect()
})
#>    user  system elapsed 
#>   0.610   0.044   0.325
d |> glimpse()
#> Rows: 388,120
#> Columns: 31
#> $ RecordHeader          <chr> "HL", "HL", "HL", "HL", "HL", "HL", "HL", "HL", …
#> $ Survey                <chr> "NS-IBTS", "NS-IBTS", "NS-IBTS", "NS-IBTS", "NS-…
#> $ Quarter               <int> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
#> $ Country               <chr> "GB-SCT", "GB-SCT", "GB-SCT", "GB-SCT", "GB-SCT"…
#> $ Platform              <chr> "74EX", "74EX", "74EX", "74EX", "74EX", "74EX", …
#> $ Gear                  <chr> "GOV", "GOV", "GOV", "GOV", "GOV", "GOV", "GOV",…
#> $ SweepLength           <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ GearExceptions        <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ DoorType              <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ StationName           <chr> "46", "46", "46", "46", "46", "35", "35", "35", …
#> $ HaulNumber            <int> 16, 16, 16, 16, 16, 5, 5, 5, 9, 9, 11, 11, 13, 1…
#> $ SpeciesCodeType       <chr> "T", "T", "T", "T", "T", "T", "T", "T", "T", "T"…
#> $ SpeciesCode           <chr> "164712", "164712", "164712", "164712", "164712"…
#> $ SpeciesValidity       <chr> "1", "1", "1", "1", "1", "1", "1", "1", "1", "1"…
#> $ IndividualSex         <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ TotalNumber           <dbl> 9, 9, 9, 9, 9, 3, 3, 3, 31, 31, 7, 7, 4, 4, 4, 4…
#> $ SpeciesCategory       <int> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
#> $ SubsampledNumber      <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ SubsamplingFactor     <dbl> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
#> $ SubsampleWeight       <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ SpeciesCategoryWeight <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ LengthCode            <chr> "1", "1", "1", "1", "1", "1", "1", "1", "1", "1"…
#> $ LengthClass           <int> 80, 89, 95, 97, 98, 80, 95, 98, 83, 89, 57, 59, …
#> $ NumberAtLength        <dbl> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
#> $ DevelopmentStage      <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ LengthType            <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ DateofCalculation     <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, …
#> $ Valid_Aphia           <int> 126436, 126436, 126436, 126436, 126436, 126436, …
#> $ Year                  <dbl> 1967, 1967, 1967, 1967, 1967, 1967, 1967, 1967, …
#> $ .id                   <chr> "NS-IBTS:1967:1:GB-SCT:74EX:GOV:46:16", "NS-IBTS…
#> $ length_cm             <dbl> 80, 89, 95, 97, 98, 80, 95, 98, 83, 89, 57, 59, …
```

Note that:

- The time this took is in the order of one second even though we
  started off with connecting to the full DATRAS HH and HL dataset
  **residing on the web**.
- We joined information from two separate tables
- We filtered by parameters that {icesDatras}-users are familiar with
  (Survey, Year, Quarter) but sneaked also in a longitudinal filter.

Why so fast? - the short story:

- Only the variables .id (unique station id), lon, lat, latin and n_haul
  are ever passed over the web.
- In addition, for those variables only certain chunks of the parquet
  files (read: rows).
- Those chunks that the above variables “fall within the range” of the
  filtered values are passed over the web.

### I only want to work on a local copy of the Datras data

If you use tidyverse you can use the same code flow as in the example
above. We first need to get some Datras HH and HL data to demonstrate
this. Here is the quickest way, the code actually removes also all the
extra frills added to the HH and HL data residing on the web:

``` r
if (!dir.exists("datras")) dir.create("datras")
dr_get("HH") |> 
  # strip the frills, nothing up my sleeve, pure HH data
  select(-c(.id, date, time)) |> 
  duckdbfs::write_dataset("datras/HH.parquet")
#> Error in `select()`:
#> ! Can't select columns that don't exist.
#> ✖ Column `date` doesn't exist.
dr_get("HL") |> 
  # strip again
  select(-c(.id:n_hour)) |> 
  duckdbfs::write_dataset("datras/HL.parquet")
#> Error in `select()`:
#> ! Can't select columns that don't exist.
#> ✖ Column `n_hour` doesn't exist.
```

Now for the code base on “pure” local HH and HL:

``` r
duckdbfs::open_dataset("datras/HH.parquet") |> 
  filter(Year == 2024,
                Quarter %in% 1:4) |> 
  dr_add_id() |> 
  select(.id, lon = ShootLongitude, lat = ShootLatitude,
                # needed to get the n_haul
                DataType, HaulDuration) |> 
  filter(between(lon, 0, 11)) |> 
  left_join(duckdbfs::open_dataset("datras/HL.parquet") |> 
                     left_join(dr_lookup_species |> duckdbfs::as_dataset(),
                               by = join_by(Valid_Aphia == aphia)) |> 
                     filter(latin == "Gadus morhua") |> 
                     dr_add_id()) |> 
  dr_add_n_and_cpue() |>
  group_by(.id, lon, lat) |> 
  summarise(n_haul = sum(n_haul, na.rm = TRUE),
                   .groups = "drop") |> 
  mutate(n_haul = coalesce(n_haul, 0)) |> 
  collect()
#> Error in `DBI::dbSendQuery()`:
#> ! IO Error: No files found that match the pattern "datras/HH.parquet/**"
#> 
#> LINE 1: ... OR REPLACE TEMPORARY VIEW ikkihtmhvbbdcmy AS SELECT * FROM parquet_scan('datras/HH.parquet/**', HIVE_PARTITIONING=TRUE...
#>                                                                        ^
#> ℹ Context: rapi_prepare
#> ℹ Error type: IO
```

If you are scared of using duckdb as your middle man, you can achieve
the same thing this way:

``` r
# If you have your in some other format on disk, replace the import code
hh <- arrow::read_parquet("datras/HH.parquet")
#> Error:
#> ! IOError: Failed to open local file 'datras/HH.parquet'. Detail: [errno 2] No such file or directory
hl <- arrow::read_parquet("datras/HL.parquet")
#> Error:
#> ! IOError: Failed to open local file 'datras/HL.parquet'. Detail: [errno 2] No such file or directory

hh |> 
  filter(Year == 2024,
                Quarter %in% 1:4) |> 
  dr_add_id() |> 
  select(.id, lon = ShootLongitude, lat = ShootLatitude,
                # needed to get the n_haul
                DataType, HaulDuration) |> 
  filter(between(lon, 0, 11)) |> 
  left_join(hl |> 
                     left_join(dr_lookup_species,
                               by = join_by(Valid_Aphia == aphia)) |> 
                     filter(latin == "Gadus morhua") |> 
                     dr_add_id()) |> 
  dr_add_n_and_cpue() |>
  group_by(.id, lon, lat) |> 
  summarise(n_haul = sum(n_haul, na.rm = TRUE),
                   .groups = "drop") |> 
  mutate(n_haul = coalesce(n_haul, 0))
#> Error in `auto_copy()`:
#> ! `x` and `y` must share the same src.
#> ℹ `x` is a <tbl_duckdb_connection/tbl_dbi/tbl_sql/tbl_lazy/tbl> object.
#> ℹ `y` is a <tbl_df/tbl/data.frame> object.
#> ℹ Set `copy = TRUE` if `y` can be copied to the same source as `x` (may be
#>   slow).
```

## Small print

The Devil is in the details. The code flow demonstrated here is not
pretending to give the absolute truth. It is for now, a
proof-of-concept. I am anticipating as well as welcoming issues, both on
the actual code as well as on the general philosophy. The ultimate aim
is to make both expert and novice users of the DATRAS data as painless
as possible.

Your best place for any communication regarding {obus} is [github
issue](https://github.com/einarhjorleifsson/obus/issues).

## Package dependencies

For purist, one regrets to inform that {obus} has quite some number of
dependencies (56, see also
[DESCRIPTION](https://raw.githubusercontent.com/einarhjorleifsson/obus/refs/heads/master/DESCRIPTION)).
Some of them may possibly be trimmed, but never all.

Access to the parquet datafiles is though independent of {obus} and for
that matter any platform used. Rhe current path to the exchange files
(with the new header lingo):

    https://heima.hafro.is/~einarhj/datras/HH.parquet
    https://heima.hafro.is/~einarhj/datras/HL.parquet
    https://heima.hafro.is/~einarhj/datras/CA.parquet

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
    #>  arrow         24.0.0     2026-04-29 [2] CRAN (R 4.5.2)
    #>  assertthat    0.2.1      2019-03-21 [2] CRAN (R 4.5.0)
    #>  bit           4.6.0      2025-03-06 [2] CRAN (R 4.5.0)
    #>  bit64         4.8.2      2026-05-19 [2] CRAN (R 4.5.2)
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
    #>  [1] /private/var/folders/14/1_h9q5hn2h93byhrkzp8jfj00000gp/T/Rtmp398Saa/temp_libpathcd83d9991c7
    #>  [2] /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/library
    #>  * ── Packages attached to the search path.
    #> 
    #> ──────────────────────────────────────────────────────────────────────────────

    #> Error:
    #> ! [ENOENT] Failed to remove 'datras/HH.parquet': no such file or directory
    #> Error:
    #> ! [ENOENT] Failed to remove 'datras/HL.parquet': no such file or directory
