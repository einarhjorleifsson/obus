# Get Survey Indices for All Years

Get age-based indices of abundance by species and survey.

## Usage

``` r
getIndicesAllYears(survey, quarter, species, quiet = FALSE)
```

## Arguments

- survey:

  the survey acronym, e.g. NS-IBTS.

- quarter:

  the quarter of the year the survey took place, i.e. 1, 2, 3 or 4.

- species:

  the Aphia species code for the species of interest.

- quiet:

  Boolean (default FALSE)

## Examples

``` r
if (FALSE) { # \dontrun{
haddock_aphia <- icesVocab::findAphia("haddock")
index <- getIndicesAllYears(survey = "NS-IBTS", quarter = 3, species = haddock_aphia)
str(index)
} # }
```
