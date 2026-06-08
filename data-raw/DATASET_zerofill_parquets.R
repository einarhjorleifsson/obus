# Build and upload pre-computed zero-filled DATRAS parquets
#
# Produces two parquet files:
#
#   HL_zerofill_species.parquet  — one row per .id × ValidAphiaID
#       Columns: Survey, Quarter, .id, ValidAphiaID, n_hour
#       59.5M rows, ~42 MB (Zstd). Suitable for haul-level CPUE analyses.
#
#   HL_zerofill_length.parquet   — one row per .id × ValidAphiaID × length_mm
#       Columns: Survey, Quarter, .id, ValidAphiaID, length_mm, n_hour
#       2.24B rows, ~2.9 GB (Zstd). For length-frequency indices.
#
# In both files, n_hour = 0 where the species was absent from the haul;
# non-zero rows carry the observed CPUE (numbers per hour of hauling).
# The species and length grids are constrained within each Survey × Quarter,
# so no cross-survey species leakage occurs.
#
# Run time: ~5 minutes end-to-end (dominated by the dr_cpue_by_haul() call).
# Re-run whenever the source HH/HL parquets are updated.
#
# Upload requires network access to the HAFRI server.
# Adjust DATRAS_PATH to match the server mount point on your machine.

devtools::load_all()
library(tidyverse)
library(arrow)
library(duckdb)

DATRAS_PATH <- "/net/hafri.hafro.is/export/home/hafri/einarhj/datras"

# -----------------------------------------------------------------------------
# 1.  Source parquets
# -----------------------------------------------------------------------------

hh <- dr_con("HH")
hl <- dr_con("HL") |> rename(ValidAphiaID = Valid_Aphia)

# -----------------------------------------------------------------------------
# 2.  Observed haul-level CPUE  (.id × ValidAphiaID, non-zero rows only)
# -----------------------------------------------------------------------------

message("Computing observed CPUE ...")
cpue_obs <- dr_cpue_by_haul(hh, hl) |>
  select(Survey, Quarter, .id, ValidAphiaID, n_hour)

# -----------------------------------------------------------------------------
# 3.  Zero-fill skeleton:  all .id × ValidAphiaID combos within Survey × Quarter
# -----------------------------------------------------------------------------

message("Building species-only grid ...")
hauls_sq <- hl |>
  distinct(Survey, Quarter, .id) |>
  collect()

species_sq <- hl |>
  distinct(Survey, Quarter, ValidAphiaID) |>
  collect()

full_grid <- inner_join(hauls_sq, species_sq,
                        by = c("Survey", "Quarter"),
                        relationship = "many-to-many")

# -----------------------------------------------------------------------------
# 4.  Species-only zero-filled parquet
# -----------------------------------------------------------------------------

message("Joining and writing HL_zerofill_species.parquet ...")

out_species <- left_join(full_grid, cpue_obs,
                         by = c("Survey", "Quarter", ".id", "ValidAphiaID")) |>
  mutate(n_hour = coalesce(n_hour, 0))

out_path_species <- file.path(DATRAS_PATH, "HL_zerofill_species.parquet")
write_parquet(out_species, out_path_species, compression = "zstd")

size_mb <- round(file.size(out_path_species) / 1e6)
message(sprintf("  Written: %s  (%d MB, %s rows)",
                out_path_species, size_mb,
                format(nrow(out_species), big.mark = ",")))

# -----------------------------------------------------------------------------
# 5.  Length-expanded zero-filled parquet  (DuckDB streaming write)
# -----------------------------------------------------------------------------

message("Building length sequences ...")
length_seqs <- hl |>
  distinct(Survey, Quarter, ValidAphiaID, LengthCode, LengthClass) |>
  collect() |>
  dr_add_length_mm() |>
  filter(length_mm > 0) |>
  group_by(Survey, Quarter, ValidAphiaID, LengthCode) |>
  reframe(
    length_mm = {
      lv   <- sort(unique(length_mm))
      step <- if (length(lv) > 1) min(diff(lv)) else lv
      seq(lv[1], lv[length(lv)], by = step)
    }
  ) |>
  distinct(Survey, Quarter, ValidAphiaID, length_mm)

# Observed CPUE at length level for the join
cpue_obs_len <- dr_cpue_by_length(hh, hl) |>
  select(Survey, Quarter, .id, ValidAphiaID, length_mm, n_hour)

message("Writing HL_zerofill_length.parquet via DuckDB ...")
con <- dbConnect(duckdb())
duckdb_register(con, "full_grid",    full_grid)
duckdb_register(con, "length_seqs",  length_seqs)
duckdb_register(con, "cpue_obs_len", cpue_obs_len)

out_path_length <- file.path(DATRAS_PATH, "HL_zerofill_length.parquet")

dbExecute(con, sprintf(
  "COPY (
    SELECT
      fg.Survey, fg.Quarter, fg.\".id\", fg.ValidAphiaID,
      ls.length_mm,
      coalesce(cl.n_hour, 0.0) AS n_hour
    FROM full_grid   fg
    JOIN length_seqs ls
      ON  fg.Survey       = ls.Survey
      AND fg.Quarter      = ls.Quarter
      AND fg.ValidAphiaID = ls.ValidAphiaID
    LEFT JOIN cpue_obs_len cl
      ON  fg.\".id\"       = cl.\".id\"
      AND fg.ValidAphiaID = cl.ValidAphiaID
      AND ls.length_mm    = cl.length_mm
  ) TO '%s' (FORMAT PARQUET, COMPRESSION ZSTD)",
  out_path_length
))

dbDisconnect(con)

size_mb_len <- round(file.size(out_path_length) / 1e6)
message(sprintf("  Written: %s  (%d MB)", out_path_length, size_mb_len))

# -----------------------------------------------------------------------------
# 6.  Fix permissions
# -----------------------------------------------------------------------------

system(sprintf("chmod a+r %s", out_path_species))
system(sprintf("chmod a+r %s", out_path_length))

message("Done.")
