library(tidyverse)
library(sf)
library(mapview)

#Run up to line 156 of produce-geo-files.R 


tracts_out_of_cbsas = final_joined_cbsa %>%
  filter(is.na(cbsa_fips)) %>% 
  st_union() %>% 
  st_sf()

tracts_in_cbsas <- final_joined_cbsa %>% 
  filter(!is.na(cbsa_fips)) %>% 
  st_union() %>% 
  st_sf

mapview(tracts_out_of_cbsas, col.regions = "blue") +
  mapview(tracts_in_cbsas, col.regions = "yellow") +
  mapview(cbsas, col.regions = "red")