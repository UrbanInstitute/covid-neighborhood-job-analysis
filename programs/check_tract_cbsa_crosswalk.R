library(tidyverse)
library(sf)
library(mapview)

job_loss_tracts = st_read("data/processed-data/s3_final/job_loss_by_tract.geojson")
cbsas = st_read("data/raw-data/big/cbsas.geojson")


tracts_out_of_cbsas = job_loss_tracts %>%
  filter(is.na(cbsa)) %>% 
  st_union() %>% 
  st_sf()

tracts_in_cbsas = job_loss_tracts %>% 
  filter(!is.na(cbsa)) %>% 
  st_union() %>% 

mapview(tracts_out_of_cbsas, col.regions = "blue") +
  mapview(tracts_in_cbsas, col.regions = "yellow") +
  mapview(cbsas, col.regions = "green")