# Connect to the Species WoRMS Dataset

This function provides a connection to the 'species_worms' dataset
stored in a Parquet file. The dataset was created based on the ICES
vocabulary code list 'SpecWoRMS'.

## Usage

``` r
dr_con_latin()
```

## Value

A `duckdbfs` dataset object pointing to the Parquet file.

## Details

The parquet file was generated from the ICES vocabulary code list
"SpecWoRMS" with the following steps:

- The code list is obtained using `icesVocab::getCodeList("SpecWoRMS")`.

- It is processed to contain two columns: `Valid_Aphia` (integer) and
  `latin` (scientific name).

- The resulting data is written as a Parquet file

Path to the Parquet file:
<https://heima.hafro.is/~einarhj/datras/species_worms.parquet>

## Examples

``` r
# Example of connecting to the species dataset
latin <- dr_con_latin()
dplyr::glimpse(latin)  # Peek at the dataset
#> Rows: ??
#> Columns: 3
#> Database: DuckDB 1.4.3 [unknown@Linux 6.11.0-1018-azure:R 4.5.2/:memory:]
#> $ Valid_Aphia <int> 141443, 107232, 134121, 100695, 124043, 106984, 267197, 12…
#> $ latin       <chr> "Sepia elegans", "Pagurus bernhardus", "Cliona celata", "A…
#> $ species     <chr> "elegant cuttlefish", "Bernhard's hermit crab", "boring sp…
```
