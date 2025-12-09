library(tidyverse)
library(sf)

bb <-
  duckdbfs::open_dataset("https://heima.hafro.is/~einarhj/datras_latin/HH.parquet") |>
  filter(ShootLong > -20) |>
  summarise(xmin = min(ShootLong),
            ymin = min(ShootLat),
            xmax = max(HaulLong),
            ymax = max(HaulLat)) |>
  collect()
bb <- st_bbox(c(xmin = bb$xmin, ymin = bb$ymin, xmax = bb$xmax, ymax = bb$ymax), crs = st_crs(4326))
dr_coastline <-
  rnaturalearth::ne_coastline(scale = 50) |>
  st_crop(bb) |>
  select(geometry)
usethis::use_data(dr_coastline)
