# Row-Wise Value Classifier

This function classifies the values in a set of input vectors row-wise
based on specific rules. It supports numeric, logical, and categorical
(non-numeric) vectors, applying type-specific classifications and
producing a combined classification for each row as a delimited string.

## Usage

``` r
.dr_row_classifier(...)
```

## Arguments

- ...:

  A series of numeric, logical, or categorical vectors to classify. All
  vectors must be of the same length.

## Value

A character vector, with one element per row of input, containing the
concatenated classifications for each row.

## Details

### Classification Rules:

- **Numeric or Logical Variables**:

  - `NA`: Missing values are classified as `"NA"`.

  - `0`: Values equal to `0` (or `FALSE` for logicals) are classified as
    `"0"`.

  - `>0`: Positive values (or `TRUE` for logicals) are classified as
    `">0"`.

  - `<=0`: Negative values are classified as `"<=0"`.

- **Categorical (Non-Numeric) Variables**:

  - `"a"`: Non-missing values are classified generically as `"a"`.

  - `"NA"`: Missing values are classified as `"NA"`.

### Output:

The function outputs a combined classification for each row,
concatenated using `"_"` to separate the classifications for all input
vectors.

## Examples

``` r
var1 <- c(NA, 0, 1, 2)           # Numeric
var2 <- c(0, 1, NA, 3)           # Numeric
var3 <- c(NA, NA, 2, 0)          # Numeric
var4 <- c("a", "b", NA, "c")     # Categorical
var5 <- c(TRUE, FALSE, NA, TRUE) # Logical

classifications <- .dr_row_classifier(var1, var2, var3, var4, var5)
print(classifications)
#> [1] "NA_0_NA_a_>0"   "0_>0_NA_a_0"    ">0_NA_>0_NA_NA" ">0_>0_0_a_>0"  

## Output:
# [1] "NA_0_NA_a_>0" "0_>0_NA_a_0" ">0_NA_>0_NA_NA" ">0_>0_0_a_>0"
```
