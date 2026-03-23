# Establish a DuckDB Connection to DATRAS Datasets

This function creates a DuckDB connection to a specified DATRAS dataset
type, facilitating access to trawl survey data stored in Parquet format.
The dataset type determines which data is loaded from the remote source.

## Usage

``` r
dr_con(
  type = NULL,
  trim = TRUE,
  url = "https://heima.hafro.is/~einarhj/datras",
  quiet = TRUE
)
```

## Arguments

- type:

  A character string specifying the dataset type. Available values
  (tables):

  - `"HH"`: Haul-level data.

  - `"HL"`: Catch-at-length data (filterable via the `trim` option).

  - `"CA"`: Catch-at-age data (filterable via the `trim` option).

  - `"species"`: Species dataset derived from ICES SpecWoRMS.

- trim:

  Logical. For `"HL"` or `"CA"`, if `TRUE` (default), non-essential
  fields are excluded. Ignored for other datasets.

- url:

  URL to the Parquet file directory, currently defaulting to
  `"https://heima.hafro.is/~einarhj/datras"`.

- quiet:

  Logical. If `TRUE` (default), suppresses connection warnings and
  messages.

## Value

A DuckDB dataset table.

## Dataset Types

This function operates on the following dataset types:

- **"HH" (Haul-Level Data)**: Contains information related to individual
  haul events.

- **"HL" (Catch-at-Length Data)**: Records catches categorized by length
  class.

- **"CA" (Catch-at-Age Data)**: Includes age-based biological data
  (e.g., liver weight, length).

- **"species" (Species List)**: Derived from the ICES vocabulary
  'SpecWoRMS' and includes species names and related metadata.

## Dataset Paths

The dataset is accessed via HTTP/HTTPS paths at a user-defined or
default URL location. The file names are inferred from the provided
`type` parameter (e.g., a Parquet file named `"HH.parquet"` for `"HH"`
type data).

## Unique Identifier (.id)

For dataset types `"HH"`, `"HL"`, and `"CA"`, a unique identifier column
(`.id`) represent catenation of fields Survey, Year, Quarter, Country,
Platform, Gear, StationName and HaulNumber seperated by ":" (see
[`dr_add_id`](dr_add_id.md)).

## Examples

``` r
if (FALSE) { # \dontrun{
  # Establish connections
  dr_con("HH")                   # Connect to haul-level data.
  dr_con("HL", trim = FALSE)     # Include all fields for catch-at-length data.
  species_data <- dr_con("species")

  # Inspect species data
  dplyr::glimpse(species_data)
} # }
```
