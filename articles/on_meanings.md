# On meanings

One of the peculiarities, or should one say messiness of the DATRAS
exchange data is that the Data Type in HH record defines the aggregation
level of data fields reported in HL-record. Why this is so …

``` r
library(obus)
library(duckdbfs)
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union
hh <- dr_con("HH")
hl <- dr_con("HL")
```

## DataType

``` r
hh |> 
  count(DataType) |> 
  mutate(p = round(n / sum(n, na.rm = TRUE) * 100, 1)) |> 
  arrange(DataType)
#> # Source:     SQL [?? x 3]
#> # Database:   DuckDB 1.4.3 [unknown@Linux 6.11.0-1018-azure:R 4.5.2/:memory:]
#> # Ordered by: DataType
#>   DataType     n     p
#>   <chr>    <dbl> <dbl>
#> 1 C        49173  33.4
#> 2 P         1683   1.1
#> 3 R        95144  64.7
#> 4 S          969   0.7
#> 5 NA          40   0
```

The variable DataType resides in the HH-table is any of the following:

- **R**: R (Recorded by haul): the catch is sorted and some species
  might be subsampled, so subfactors have to be \>= 1
- **S**: S (subsampled data): the catch is subsampled before sorting, so
  all sub factors have to be \> 1
- **C**: C (Data by CPUE): the catch is calculated to CPUE level, so all
  sub factors have to be 1
- **P**:
- NA:

Questions:

- Does it stay the same across a single survey, across years

- DataType **R**:

- DataType **S**:

- DataType **C**:

- DataType **P**:

### TotalNo

- DataType **R**: The total number of fish of one species, sex, and
  category in the given haul.
- DataType **S**: The total number of fish of one species, sex, and
  category in the given haul.
- DataType **C**: The total number of fish of one species and sex in the
  given haul, raised to 1 hour hauling.
- DataType **P**:

### CatIdentifier - subsample identifier???

- DataType **R**: Category within species and sex. The field can be used
  to categorize fish with different size or weight categories. Different
  categories within one haul, species, sex, can have different
  sub-factors. The field cannot be reported as 0, use 1 if only one
  category is present.
- DataType **S**: As above
- DataType **C**: Only 1
- DataType **P**:

### NoMeas

- DataType **R**: Number of fish measured for the given haul or
  sub-sample, species, and sex
- DataType **S**: Same as above
- DataType **C**: Same as above
- DataType **P**:

### SubFactor

- DataType **R**: Sub-sampling factor by haul, species, sex, length.
  **Value = or \> 1**. Make sure that TotalNo = NoMeas x SubFactor.
- DataType **S**: Sub-sampling factor by haul, species, sex, length.
  **Value is always \> 1**. Make sure that TotalNo = NoMeas x SubFactor.
- DataType **C**: Only 1.
- DataType **P**:

### SubWgt

- DataType **R**: The total weight of sub-sampled fish reported in
  NoMeas.
- DataType **S**: Same as above.
- DataType **C**: The total weight of sub-sampled fish reported in
  NoMeas or report -9.
- DataType **P**:

### CatCatchWgt

- DataType **R**: Catch weight of fish per species, sex, and category in
  the given haul (as in TotalNo).
- DataType **S**: Same as above
- DataType **C**: Catch weight per species per haul, raised to one hour
  of hauling.
- DataType **P**:

### HLNoAtLngt

- DataType **R**: The number of fish for this sex of this species, in
  this category in the haul. Make sure that TotalNo = Sum (HLNoAtLngt) x
  SubFactor or NoMeas = Sum (HLNoAtLngt)
- DataType **S**: Same as above.
- DataType **C**: The number of fish for this sex of this species in the
  haul adjusted to one hour of catching. Make sure that TotalNo = Sum
  (HLNoAtLngt).
- DataType **P**:
