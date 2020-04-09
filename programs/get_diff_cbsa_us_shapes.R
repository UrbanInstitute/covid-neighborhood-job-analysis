library(tidyverse)
library(sf)
library(tigris)


cbsa = st_read("https://ui-lodes-job-change-public.s3.amazonaws.com/cbsas.geojson") %>% 
  st_transform(2163)

x = st_read("https://ui-lodes-job-change-public.s3.amazonaws.com/job_loss_by_tract.geojson")
fips_in_job_change_index = x %>% pull(state_fips) %>% unique() %>% as.character()


us_states = tigris::states()
us = us_states %>% 
  filter(STATEFP %in% fips_in_job_change_index) %>% 
  st_union() %>% 
  st_as_sf()

us = us %>% st_transform(2163)

#These are the tiny bits of the border of USA that aren't 
# in the cbsa file, proably due to different resolution sizes
diff = st_difference(cbsa, us)

# So we clip those tiny boundaries off of the US shapefile
us = st_intersection(us, diff)


diff2 = st_difference(us, cbsa)

us = st_intersection(us, diff)
mapview(diff)


