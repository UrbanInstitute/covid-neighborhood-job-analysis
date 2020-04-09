library(tidyverse)
library(sf)
library(tigris)
library(mapview)
options(tigris_use_cache = TRUE)

cbsa = st_read("https://ui-lodes-job-change-public.s3.amazonaws.com/cbsas.geojson") %>% 
  st_transform(2163)

x = st_read("https://ui-lodes-job-change-public.s3.amazonaws.com/job_loss_by_tract.geojson")
fips_in_job_change_index = x %>% pull(state_fips) %>% unique() %>% as.character()


us_states = tigris::states(class = "sf")
us = us_states %>% 
  filter(STATEFP %in% fips_in_job_change_index) %>% 
  st_union() %>% 
  st_as_sf()

us = us %>% st_transform(2163)

#These are the tiny bits of the border of USA that aren't 
# in the cbsa file, proably due to different resolution sizes
diff = st_difference(cbsa, us)

# So we clip those tiny boundaries off of the US shapefile
us1 = st_difference(us, diff)

# And then find the parts of the US that are not covered by our CBSA map
diff_us = st_difference(us_int, cbsa)
non_overlapping_us = diff_us %>% st_union()

# us_int = st_intersection(us %>% st_set_precision(1e5), diff %>% st_set_precision(1e5))
# 
# 
# diff2 = st_difference(us %>% st_set_precision(1e5), cbsa %>% st_set_precision(1e5))
# 
# diff_us = st_difference(us_int, cbsa)
# diff_us2 = st_difference(us, cbsa)

diff_us = st_difference(us_int, cbsa)

