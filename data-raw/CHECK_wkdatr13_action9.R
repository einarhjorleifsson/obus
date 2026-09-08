# Did WKDATR 2013 action 9 ever happen?
#
# This is the reproducible form of the evidence cited in PLAN-qc-checks.md
# (sections 0.6 and 6, "walk Annex 6's 27 actions against the archive").
#
# THE QUESTION. WKDATR met in January 2013, reviewed all 370 of DATRAS's
# field-range checks, and marked 124 of them for change. Action 9 in its Annex 6
# is the follow-through:
#
#   "Review proposal for new field ranges/changes in checks and send final
#    proposal to ICES Data Centre"   -- Chairs WGBIFS, IBTSWG, WGBEAM,
#                                       due "At 2013 meetings"
#
# Its Status cell is blank. So are the other 26. The report records no follow-up
# of any kind, and asking whether that means "not done" or "done, not recorded"
# is exactly the question no one has been able to answer since.
#
# WHY THIS SUBSET SETTLES IT. Of the 124 flagged checks, 26 are marked "change
# from warning to error" AND carry numeric bounds. That combination is
# falsifiable in a way nothing else in the annex is: a DATSU error BLOCKS
# upload, so if the change landed, the violation rate afterwards must be
# exactly zero. One violating row disproves it. A warning does not block --
# the submitter may accept it and upload anyway -- so violations before the
# change are expected and are what give the test its power.
#
# The verdicts come from the cell BACKGROUND COLOUR of Annex 5's tables, which
# pdftotext discards; see imbus/data-raw/extract_wkdatr13_colours.py for how
# they were recovered, and README_WKDATR13.md for the two conflicting legends.
#
# WHAT IT CANNOT SETTLE. 18 of the 26 were never violated on either side of
# 2014. For those the archive is silent -- making an unviolated check blocking
# changes nothing observable -- and they must be reported as unfalsifiable, not
# scored as passes. That vacuity is the method's ceiling, and it is why the
# output below carries four verdicts and not two.
#
# Run: Rscript data-raw/CHECK_wkdatr13_action9.R

options(width = 200)
suppressMessages({library(dplyr); library(obus)})

RANGES <- "~/R/Pakkar/imbus/DATRAS/external/WKDATR13_field_ranges.csv"

# WKDATR13 uses ICES's 2013 on-the-wire names; the archive uses opus's curated
# ones. Mapped explicitly rather than fuzzily -- every pair checked against
# opus::op_field_spec() (see PLAN-qc-checks.md 3.2 on the +1 field_no offset).
MAP <- c(Quarter = "Quarter", Year = "Year", Month = "Month", Day = "Day",
         TimeShot = "StartTime", ShootLat = "ShootLatitude",
         ShootLong = "ShootLongitude", HaulLat = "HaulLatitude",
         HaulLong = "HaulLongitude", SurCurDir = "SurfaceCurrentDirection",
         BotCurDir = "BottomCurrentDirection", WindDir = "WindDirection",
         SwellDir = "SwellDirection", WindSpeed = "WindSpeed",
         SwellHeight = "SwellHeight")

# NB comment.char = "#" is required to skip the provenance header, and is safe
# only because no data cell in these files contains a "#": R truncates a line at
# the first comment character EVEN INSIDE A QUOTED FIELD. An earlier version of
# the CSV carried "#e06808" colour values and silently lost 124 of 370 verdicts.
rng <- read.csv(path.expand(RANGES), comment.char = "#", stringsAsFactors = FALSE)

w <- rng |>
  filter(verdict == "changefromwarningtoerror", !is.na(min)) |>
  mutate(col = MAP[ifelse(field_current == "", field, field_current)]) |>
  filter(!is.na(col)) |>
  select(survey, col, min, max) |>
  distinct()

stopifnot(nrow(w) == 26)

hh <- dr_con_raw("HH") |>
  filter(Survey %in% c("BITS", "BTS", "NS-IBTS")) |>
  select(Survey, Year, all_of(unique(w$col))) |>
  collect()

res <- bind_rows(lapply(seq_len(nrow(w)), function(i) {
  d <- hh[hh$Survey == w$survey[i], ]
  v <- suppressWarnings(as.numeric(d[[w$col[i]]]))
  keep <- !is.na(v)                 # NULL and sentinel are absence, not a
  if (!any(keep)) return(NULL)      # range violation -- excluded, not counted
  data.frame(survey = w$survey[i], field = w$col[i], Year = d$Year[keep],
             bad = v[keep] < w$min[i] | v[keep] > w$max[i])
}))

# 2014 is left out on both sides: the actions were due "at 2013 meetings", so
# it is the year a change would have been landing rather than in force.
agg <- function(d) d |> group_by(survey, field) |>
  summarise(n = n(), bad = sum(bad), .groups = "drop") |> mutate(pct = 100 * bad / n)

era <- full_join(
  agg(filter(res, Year <= 2013)) |> rename(n_pre = n, bad_pre = bad, pct_pre = pct),
  agg(filter(res, Year >= 2015)) |> rename(n_post = n, bad_post = bad, pct_post = pct),
  by = c("survey", "field")) |>
  mutate(across(where(is.numeric), ~ tidyr::replace_na(.x, 0)),
         verdict = case_when(
           n_post == 0                   ~ "no data after 2014",
           bad_post == 0 & bad_pre  > 0  ~ "consistent with implementation",
           bad_post == 0 & bad_pre == 0  ~ "unfalsifiable (never violated)",
           TRUE                          ~ "still violated"))

cat("\n=== WKDATR 2013 action 9: did the 26 warning->error checks become errors? ===\n")
cat("A blocking error cannot be violated. One post-2014 violation disproves it.\n\n")
print(as.data.frame(arrange(era, verdict, desc(bad_post))), digits = 3, row.names = FALSE)

cat("\n--- summary ---\n"); print(table(era$verdict))

cat("\n--- every post-2014 violation, by year ---\n")
res |>
  semi_join(filter(era, verdict == "still violated"), by = c("survey", "field")) |>
  filter(Year >= 2015, bad) |> count(survey, field, Year) |>
  arrange(survey, field, Year) |> as.data.frame() |> print(row.names = FALSE)

# RESULT, archive of 2026-09-08: 3 consistent with implementation, 5 still
# violated, 18 unfalsifiable. BTS WindDirection is violated 9 times in 2023
# alone; BITS HaulLatitude and HaulLongitude are clean before 2014 and each
# violated once in 2025. BTS SwellHeight falls 8.13% -> 0.12%, which is a real
# improvement but not a gate -- the honest verdict there is "practice improved,
# the check did not become an error", and a binary pass/fail would report it
# wrongly in either direction.
