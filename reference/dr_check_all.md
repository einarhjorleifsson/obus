# Run all applicable QC checks and return a combined report

A convenience wrapper that runs
[`dr_check_sentinels()`](dr_check_sentinels.md),
[`dr_check_subfactor()`](dr_check_subfactor.md), and
[`dr_check_totalno()`](dr_check_totalno.md) on the supplied tables and
binds the results into a single report tibble.

## Usage

``` r
dr_check_all(hh = NULL, hl = NULL, ca = NULL, ...)
```

## Arguments

- hh:

  HH exchange table (with `.id` added), or `NULL`.

- hl:

  HL exchange table (with `.id` and `DataType` joined in), or `NULL`.

- ca:

  CA exchange table, or `NULL`.

- ...:

  Additional arguments passed to individual check functions (e.g., `tol`
  for [`dr_check_totalno()`](dr_check_totalno.md), or old-style column
  name overrides).

## Value

A tibble with one row per check, columns `check`, `table`, `n_fail`,
`n_total`, `pct_fail`, `detail`.

## Details

Supply whichever tables you have. Checks that require a table you have
not supplied are silently skipped.

Both `hh` and `hl` must have a `.id` column (call
[`dr_add_id()`](dr_add_id.md) first if needed). `DataType` must also be
present in `hl` for the HL arithmetic checks. If your HL table does not
yet contain `DataType`, join it from HH:

**New-style tables** (from [`dr_get()`](dr_get.md) or
[`dr_con()`](dr_con.md)):

    hh <- hh |> dr_add_id()
    hl <- hl |> dr_add_id() |>
      dplyr::left_join(dplyr::select(hh, .id, DataType), by = ".id")
    dr_check_all(hh = hh, hl = hl)

**Old-style tables** (from [`dr_con_raw()`](dr_con_raw.md) or
`dr_get(from = "old")`):

    hh <- hh |> dr_add_id()
    hl <- hl |> dr_add_id() |>
      dplyr::left_join(dplyr::select(hh, .id, DataType), by = ".id")
    dr_check_all(hh = hh, hl = hl,
                 SubsamplingFactor = SubFactor,
                 TotalNumber = TotalNo, NumberAtLength = HLNoAtLngt,
                 Species = Valid_Aphia, Sex = Sex,
                 SpeciesCategory = CatIdentifier)
