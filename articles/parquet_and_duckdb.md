# Parquet Files and DuckDB

This article explains two technologies that power
[obus](https://einarhjorleifsson.github.io/obus/) under the hood —
**Parquet** and **DuckDB** — and why they matter even if you never think
about them directly.

The short version: the full DATRAS exchange tables (HH, HL, CA) live on
a web server as Parquet files. When you call
[`dr_con()`](https://einarhjorleifsson.github.io/obus/reference/dr_con.md),
a tiny in-process database called DuckDB connects to those files and
lets you filter, join, and compute on them using ordinary
[dplyr](https://dplyr.tidyverse.org) code — without ever downloading the
parts you don’t need. You can switch to a regular R data frame at any
point and **the same [dplyr](https://dplyr.tidyverse.org) code keeps
working unchanged**.

------------------------------------------------------------------------

## 1 Why not just CSV?

The traditional way to share tabular data is a CSV file. CSV is readable
by nearly any tool, which is why it has outlasted every format that
tried to replace it. But CSV has three weaknesses that become painful at
DATRAS scale:

**No type information.** A CSV file is plain text. When you read it, the
parser has to guess whether `"2026"` is a year (integer) or an ID
(character). DATRAS has had persistent problems with fields like `StNo`
arriving as integer in some national submissions and character in
others, causing
[`bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html) to
fail. Every time you read a CSV you re-run the guessing game.

**Reads the whole file.** If you want only the `Survey`, `Year`, and
`HaulNumber` columns from a 14-million-row HL file, a CSV reader still
reads all 40+ columns, then discards the ones you did not ask for.

**No compression awareness.** A plain CSV of the full HL table is
multiple gigabytes. The same data in Parquet fits in a fraction of that
— the exact numbers are measured in the [Compression](#compression)
section below.

Parquet fixes all three.

------------------------------------------------------------------------

## 2 Parquet: the columnar file format

### 2.1 Columns, not rows

A CSV stores one row at a time:

    Survey,Year,Quarter,Country,Platform,...
    NS-IBTS,2026,1,Scotland,Scotia,...
    NS-IBTS,2026,1,Scotland,Scotia,...

Parquet stores one **column** at a time: all `Survey` values together,
then all `Year` values together, and so on. This sounds like a minor
implementation detail, but the consequence is important: if you ask for
only `Survey` and `Year`, Parquet reads only those two columns from
disk. The other 38 columns are never touched.

### 2.2 Metadata stored in the file

Every Parquet file carries a **footer** — a compact block of binary
metadata at the end of the file. The footer contains:

- column names
- column types (`INT32`, `UTF8`, `DOUBLE`, …)
- number of rows
- row-group boundaries (the file is split into chunks; the footer says
  where each starts)
- min/max statistics per chunk, per column

When DuckDB first connects to a Parquet file it reads only the footer —
a few kilobytes even for a file with millions of rows. From that it
knows the schema, the row count, and which chunks it can skip entirely
when a filter is applied.

### 2.3 Strict types

Types are recorded in the file and enforced on read. An `INT32` column
comes back as integer, a `UTF8` column comes back as character — no
guessing, no surprises. When reading from the XML source
(`dr_get(source = "xml")`), the parquet file is not involved at all;
types are applied separately by
[`dr_settypes()`](https://einarhjorleifsson.github.io/obus/reference/dr_settypes.md)
using the `dr_lookup_fields` table as its reference. Either way the
result is a correctly typed data frame, but the two paths are
independent.

### 2.4 Compression

Within each column chunk, values are compressed. Parquet supports
several algorithms; the obus server files use **Snappy**, a fast
algorithm optimised for decompression speed. Similar values compress
extremely well: a column that is the string `"NS-IBTS"` repeated 500 000
times compresses to almost nothing. Numeric columns with many repeated
values (like `Quarter`, which is only 1–4) shrink similarly.

The result, measured directly from the server file and a freshly written
CSV of the same data: the full HL table (14,397,334 rows, 30 columns)
occupies **97 MB** as Parquet. Writing the identical data as a plain CSV
produces a **2.1 GB** file — 22 × larger.

------------------------------------------------------------------------

## 3 DuckDB: a database that lives inside R

### 3.1 What it is

[DuckDB](https://duckdb.org) is a relational database engine designed
for analytical queries on large tables. Unlike PostgreSQL or MySQL,
DuckDB runs **in-process** — it starts up as a library inside your R
session, with no separate server to install, configure, or connect to.
When you install [obus](https://einarhjorleifsson.github.io/obus/),
DuckDB comes along as an R package dependency and is ready to use
immediately.

### 3.2 Three ways to get an `hl` object — and why it doesn’t matter

Before going further, here are the three ways you might start a DATRAS
analysis, and what you end up with:

``` r

# 1. Connect to the obus server (lazy — nothing downloaded yet)
hl <- dr_con("HL")

# 2. Connect to a local copy (lazy — identical object to dr_con())
hl <- duckdbfs::open_dataset("~/datras/HL.parquet")

# 3. Import the full table into R memory
hl <- dr_get("HL")
```

**Options 1 and 2 return a lazy DuckDB connection. Option 3 returns a
plain R data frame.** These are different objects internally, but from
your perspective as a user they behave identically: every
[dplyr](https://dplyr.tidyverse.org) verb (`filter`, `mutate`,
`group_by`, `summarise`, `left_join`, …) and every `dr_add_*()` function
in [obus](https://einarhjorleifsson.github.io/obus/) works the same way
on all three. You do not need to know or care which one you have.

The rest of this article uses `hl` from
[`dr_con()`](https://einarhjorleifsson.github.io/obus/reference/dr_con.md),
but every single line of code shown would work unchanged if `hl` had
come from
[`duckdbfs::open_dataset()`](https://cboettig.github.io/duckdbfs/reference/open_dataset.html)
or
[`dr_get()`](https://einarhjorleifsson.github.io/obus/reference/dr_get.md)
instead.

### 3.3 Connecting is nearly instant; importing is not

``` r

system.time({
  hl <- dr_con("HL")   # lazy connection — reads only the file footer
})
```

       user  system elapsed
      1.506   0.063   7.021 

``` r

system.time({
  hl_imported <- dr_get("HL")   # full import — all rows into R memory
})
```

       user  system elapsed
      9.651   1.382  27.673 

The difference is what has actually happened.
[`dr_con()`](https://einarhjorleifsson.github.io/obus/reference/dr_con.md)
sends an HTTP HEAD request, then tells DuckDB to note the file location
and read its footer — a few kilobytes. The 14-million-row table has not
moved.
[`dr_get()`](https://einarhjorleifsson.github.io/obus/reference/dr_get.md)
downloads the entire file.

``` r

class(hl)
```

    [1] "tbl_duckdb_connection" "tbl_dbi"               "tbl_sql"
    [4] "tbl_lazy"              "tbl"                  

``` r

nrow(hl)   # NA — DuckDB has not counted rows yet
```

    [1] NA

The `NA` row count signals that `hl` is a **promise** of data, not data
itself. A query will be needed to make anything happen.

------------------------------------------------------------------------

## 4 dbplyr: writing dplyr, getting SQL

### 4.1 The translation layer

[dbplyr](https://dbplyr.tidyverse.org/) is the package that makes the
magic happen. It intercepts ordinary
[dplyr](https://dplyr.tidyverse.org) verbs —
[`filter()`](https://dplyr.tidyverse.org/reference/filter.html),
[`select()`](https://dplyr.tidyverse.org/reference/select.html),
[`mutate()`](https://dplyr.tidyverse.org/reference/mutate.html),
[`group_by()`](https://dplyr.tidyverse.org/reference/group_by.html),
[`summarise()`](https://dplyr.tidyverse.org/reference/summarise.html),
[`left_join()`](https://dplyr.tidyverse.org/reference/mutate-joins.html)
— and translates them into SQL, which DuckDB can then execute against
the Parquet file.

You never have to write a line of SQL. You write
[dplyr](https://dplyr.tidyverse.org):

``` r

q <- hl |>
  filter(Survey == "NS-IBTS", Year == 2026, Quarter == 1)
```

What does `q` contain? Still a lazy query. To see the SQL that was
built:

``` r

q |> show_query()
```

    <SQL>
    SELECT *
    FROM jkgefhcrjvvvonx
    WHERE (Survey = 'NS-IBTS') AND ("Year" = 2026.0) AND ("Quarter" = 1.0)

Nothing has been downloaded yet. The filter is encoded as a `WHERE`
clause that DuckDB will push down to the Parquet row-group level: any
chunk whose min/max statistics show it contains no NS-IBTS 2026 Q1 rows
is skipped entirely.

### 4.2 Building up a query step by step

You can chain verbs freely. Each one adds to the SQL plan:

``` r

q <- hl |>
  dr_add_length_cm() |>
  filter(
    Survey  == "NS-IBTS",
    Quarter == 1,
    !is.na(LengthCode)
  ) |>
  select(.id, Survey, Year, aphia, length_cm, NumberAtLength, SubsamplingFactor)

q |> show_query()
```

    <SQL>
    SELECT
      ".id",
      Survey,
      "Year",
      aphia,
      length_cm,
      NumberAtLength,
      SubsamplingFactor
    FROM (
      SELECT
        *,
        CASE
    WHEN (LengthCode = '-9') THEN NULL
    WHEN (LengthCode IN ('.', '0')) THEN (LengthClass / 10.0)
    WHEN (LengthCode IN ('1', '2', '5')) THEN LengthClass
    ELSE NULL
    END AS length_cm
      FROM jkgefhcrjvvvonx
    ) AS q01
    WHERE (Survey = 'NS-IBTS') AND ("Quarter" = 1.0) AND (NOT((LengthCode IS NULL)))

The `CASE WHEN` block that
[`dr_add_length_cm()`](https://einarhjorleifsson.github.io/obus/reference/dr_add_length_cm.md)
adds internally is translated to SQL and included in the same query. No
intermediate data frame is created.

### 4.3 `collect()` — the moment data moves

Only when you call
[`collect()`](https://dplyr.tidyverse.org/reference/compute.html) does
DuckDB actually read data from the Parquet file and return it as a plain
R data frame:

``` r

system.time(
  data <- q |> collect()
)
```

       user  system elapsed
      0.837   0.031   5.406 

``` r

nrow(data)
```

    [1] 2301995

DuckDB reads only the columns used in the query, skips row-groups that
can’t match the filter, decompresses what remains, and returns the
result. A query that touches a few percent of the 14-million-row file
completes in under a second even over an HTTP connection.

### 4.4 Joins stay lazy too

You can join multiple connections before collecting. The entire join is
pushed down to DuckDB:

``` r

hh <- dr_con("HH")
sp <- dr_con("species")

q <- hl |>
  inner_join(
    hh |> select(.id, HaulValidity, DataType, HaulDuration),
    by = ".id"
  ) |>
  inner_join(sp, by = "aphia") |>
  dr_add_length_cm() |>
  dr_add_n_and_cpue() |>
  filter(
    HaulValidity == "V",
    latin        == "Gadus morhua",
    Survey       %in% c("NS-IBTS", "SCOWCGFS"),
    Quarter      == 1
  ) |>
  select(.id, Survey, Year, latin, length_cm, n_haul, n_hour)

q |> show_query()
```

    <SQL>
    SELECT
      ".id",
      Survey,
      "Year",
      latin,
      length_cm,
      n_haul,
      (n_haul / HaulDuration) * 60.0 AS n_hour
    FROM (
      SELECT
        *,
        CASE
    WHEN (DataType = 'C') THEN (((NumberAtLength * SubsamplingFactor) * HaulDuration) / 60.0)
    WHEN (DataType = 'R') THEN (NumberAtLength * COALESCE(SubsamplingFactor, 1.0))
    WHEN (DataType = 'P') THEN (NumberAtLength * SubsamplingFactor)
    WHEN (DataType = 'S') THEN (NumberAtLength * SubsamplingFactor)
    WHEN (DataType = '-9') THEN NULL
    WHEN ((DataType IS NULL)) THEN NULL
    ELSE NULL
    END AS n_haul
      FROM (
        SELECT
          *,
          CASE
    WHEN (LengthCode = '.') THEN 0.1
    WHEN (LengthCode = '0') THEN 0.5
    WHEN (LengthCode = '1') THEN 1.0
    WHEN (LengthCode = '2') THEN 2.0
    WHEN (LengthCode = '5') THEN 5.0
    WHEN ((LengthCode IS NULL)) THEN NULL
    END AS accuracy
        FROM (
          SELECT
            *,
            CASE
    WHEN (LengthCode = '-9') THEN NULL
    WHEN (LengthCode IN ('.', '0')) THEN (LengthClass / 10.0)
    WHEN (LengthCode IN ('1', '2', '5')) THEN LengthClass
    ELSE NULL
    END AS length_cm
          FROM (
            SELECT
              jkgefhcrjvvvonx.*,
              HaulValidity,
              DataType,
              HaulDuration,
              latin,
              species
            FROM jkgefhcrjvvvonx
            INNER JOIN xfhjhpzaqmnbmym
              ON (jkgefhcrjvvvonx.".id" = xfhjhpzaqmnbmym.".id")
            INNER JOIN hnberquhpwdidab
              ON (jkgefhcrjvvvonx.aphia = hnberquhpwdidab.aphia)
          ) AS q01
        ) AS q01
      ) AS q01
    ) AS q01
    WHERE
      (HaulValidity = 'V') AND
      (latin = 'Gadus morhua') AND
      (Survey IN ('NS-IBTS', 'SCOWCGFS')) AND
      ("Quarter" = 1.0)

``` r

system.time(
  cod <- q |> collect()
)
```

       user  system elapsed
      5.117   0.049  13.328 

``` r

glimpse(cod)
```

    Rows: 152,918
    Columns: 7
    $ .id       <chr> "NS-IBTS:1974:1:SE:77TH:FOT:16", "NS-IBTS:1974:1:SE:77TH:FOT…
    $ Survey    <chr> "NS-IBTS", "NS-IBTS", "NS-IBTS", "NS-IBTS", "NS-IBTS", "NS-I…
    $ Year      <dbl> 1974, 1974, 1974, 1974, 1974, 1974, 1974, 1974, 1974, 1974, …
    $ latin     <chr> "Gadus morhua", "Gadus morhua", "Gadus morhua", "Gadus morhu…
    $ length_cm <dbl> 44, 53, 56, 45, 46, 49, 55, 66, 72, 73, 11, 37, 48, 10, 12, …
    $ n_haul    <dbl> 1.00, 1.00, 1.00, 1.25, 2.50, 2.50, 1.25, 1.25, 2.50, 1.25, …
    $ n_hour    <dbl> 1, 1, 1, 1, 2, 2, 1, 1, 2, 1, 1, 1, 1, 2, 2, 6, 2, 2, 2, 6, …

Three Parquet files joined, filtered, and computed — all in DuckDB,
before a single row enters R memory.

------------------------------------------------------------------------

## 5 Same code, three backends

The point stated earlier bears a concrete demonstration. Here is a
function that computes total cod catch by survey, year, and quarter:

``` r

summarise_cod <- function(hl_input, hh_input) {
  hl_input |>
    inner_join(hh_input |> select(.id, HaulValidity, DataType, HaulDuration),
               by = ".id") |>
    dr_add_length_cm() |>
    dr_add_n_and_cpue() |>
    filter(HaulValidity == "V", aphia == 126436L) |>
    group_by(Survey, Year, Quarter) |>
    summarise(n_haul_total = sum(n_haul, na.rm = TRUE), .groups = "drop")
}
```

Call it with **remote DuckDB connections** — only the matching rows ever
leave the server:

``` r

summarise_cod(dr_con("HL"), dr_con("HH")) |> collect()
```

Call it with **local DuckDB connections** — same laziness, files on your
own disk:

``` r

summarise_cod(
  duckdbfs::open_dataset("~/datras/HL.parquet"),
  duckdbfs::open_dataset("~/datras/HH.parquet")
) |> collect()
```

Call it with **in-memory data frames** — everything already in R:

``` r

hh_local <- dr_get("HH", surveys = "NS-IBTS", years = 2024, quarters = 1)
hl_local <- dr_get("HL", surveys = "NS-IBTS", years = 2024, quarters = 1)
summarise_cod(hl_local, hh_local)
```

The function is identical in all three cases. No `if` statements, no
special cases, no adapter layer. The `dr_add_*()` functions in
[obus](https://einarhjorleifsson.github.io/obus/) are written to handle
both `tbl_duckdb_connection` and ordinary `data.frame` inputs;
[dplyr](https://dplyr.tidyverse.org) dispatches to the right method
automatically.

### 5.1 When to prefer each approach

| Situation | Recommended approach |
|----|----|
| Exploring the full dataset, filtering by survey / year / species | [`dr_con()`](https://einarhjorleifsson.github.io/obus/reference/dr_con.md) — lazy; only your subset downloads |
| Running the same filtered subset repeatedly in one session | [`dr_get()`](https://einarhjorleifsson.github.io/obus/reference/dr_get.md) once, then work on the data frame |
| Joining across HH + HL + species without caring about the full tables | [`dr_con()`](https://einarhjorleifsson.github.io/obus/reference/dr_con.md) — DuckDB handles the join before collect |
| Working offline or on a slow connection | [`dr_get()`](https://einarhjorleifsson.github.io/obus/reference/dr_get.md) up front, save locally |
| Building a function that others will call either way | Write against [dplyr](https://dplyr.tidyverse.org) — it works on both |

------------------------------------------------------------------------

## 6 What you never have to do

A few things that used to be standard practice with DATRAS data are now
unnecessary:

**Maintain local copies.** There is no need to periodically download and
version a local `HL.csv`. The Parquet files on the server are the
authoritative copy. Connect, filter, collect — and you always get the
current version.

**Manage file formats.** You do not need to know whether the underlying
storage is Snappy-compressed Parquet, zstd-compressed Parquet, or
anything else. DuckDB handles the format; you handle the dplyr.

**Write SQL.** [dbplyr](https://dbplyr.tidyverse.org/) writes it for
you.
[`show_query()`](https://dplyr.tidyverse.org/reference/explain.html) is
there if you are curious, not because you need to worry about it.

------------------------------------------------------------------------

## 7 Summary

    Parquet file on server
            │
            │  (dr_con reads only the footer — nearly instant)
            ▼
    DuckDB connection in R
            │
            │  (dplyr verbs build an SQL plan — no data moves yet)
            ▼
    Lazy query (tbl_duckdb_connection)
            │
            │  (collect() executes the query — only matching rows and columns travel)
            ▼
    Plain R data frame

The three technologies — Parquet, DuckDB, dbplyr — are independently
useful, but together they give you interactive performance on a
14-million-row dataset, with no local storage, no SQL, and code that
works identically on an in-memory data frame the moment you need to
switch.
