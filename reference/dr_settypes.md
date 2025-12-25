# Set variable types

Used when downloading raw data to ensures consistency in column types

## Usage

``` r
dr_settypes(d)
```

## Arguments

- d:

  A DATRAS exchange table

## Value

A table of same dimention as input

## Details

The column type setting is according to
[DATRAS_Field_descriptions_and_example_file_May2022.xlsx](https://einarhjorleifsson.github.io/obus/reference/%22www.ices.dk%5C/data/Documents%5C/DATRAS%5C/DATRAS_Field_descriptions_and_example_file_May2022.xlsx%22)
with some additional guesswork for flexfile variables
