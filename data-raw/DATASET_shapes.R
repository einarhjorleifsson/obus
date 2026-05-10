library(tidyverse)
library(sf)

bb <-
  duckdbfs::open_dataset("https://heima.hafro.is/~einarhj/datras/HH.parquet") |>
  filter(ShootLongitude > -20) |>
  summarise(xmin = min(ShootLongitude),
            ymin = min(ShootLatitude),
            xmax = max(HaulLongitude),
            ymax = max(HaulLatitude)) |>
  collect()
bb <- st_bbox(c(xmin = bb$xmin, ymin = bb$ymin, xmax = bb$xmax, ymax = bb$ymax), crs = st_crs(4326))
dr_coastline <-
  rnaturalearth::ne_coastline(scale = 50) |>
  st_crop(bb) |>
  select(geometry)
usethis::use_data(dr_coastline, overwrite = TRUE)
