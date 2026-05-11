# Get DATRAS Field Specifications

This function fetches XML data from the DATRAS web service, parses the
content, and returns the field specifications as a data frame.

## Usage

``` r
dr_get_fields(
  url = "https://datras.ices.dk/WebServices/DATRASWebService.asmx/getDatrasFieldList"
)
```

## Arguments

- url:

  A character string specifying the URL of the DATRAS web service.
  Defaults to
  `"https://datras.ices.dk/WebServices/DATRASWebService.asmx/getDatrasFieldList"`.

## Value

A tibble (data frame) containing the field specifications with the
following columns:

- `RecordHeader`: A character string indicating the record header type.

- `FieldName`: A character string specifying the field name.

- `FieldNameOld`: A character string specifying the old field name.

- `DataFormat`: A character string representing the format of the data.

- `Description`: A character string describing the field.

## Examples

``` r
# Fetch the default DATRAS field specifications:
specs <- dr_get_fields()

# View the first few rows:
head(specs)
#> # A tibble: 6 × 5
#>   RecordHeader FieldName    FieldNameOld DataFormat Description                 
#>   <chr>        <chr>        <chr>        <chr>      <chr>                       
#> 1 CA           RecordHeader RecordType   char       Definition of the data type…
#> 2 CA           Quarter      Quarter      int        Cruise quarter. Hauls outsi…
#> 3 CA           Country      Country      char       ISO 3166 country codes and …
#> 4 CA           Platform     Ship         char       SeaDataNet Ship and Platfor…
#> 5 CA           Gear         Gear         char       Gear type code              
#> 6 CA           SweepLength  SweepLngt    int        Length of sweep in metres. …
```
