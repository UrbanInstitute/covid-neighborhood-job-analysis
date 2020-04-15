# For investigating the two problematic Florida tracts
library(tidyverse)
library(tigris)
library(sf)
library(mapview)

fl_tracts_18 = tigris::tracts(state = "Fl", class = "sf", year = 2018, cb = TRUE)
fl_tracts_10 = tigris::tracts(state = "FL", class = "sf", year = 2010, cb = TRUE)

fl_tracts_18_cb = tigris::tracts(state = "FL", class = "sf", year = 2018, cb = FALSE)
fl_tracts_10_cb = tigris::tracts(state = "FL", class = "sf", year = 2010, cb = FALSE)

# 12057980100 is in LODES data and 2010 CB file but not in 2018 CB file 
# 12086981000 is in 2018 CB file but not 2010 CB file or LODES data
fl_tracts_10 %>% filter(str_detect(GEO_ID, c("12057980100", "12086981000")))
fl_tracts_18 %>% filter(GEOID == 12086981000 | GEOID == 12057980100)

# Both problematic tracts are in the Non CB Census tract files for 2010 and 2018
fl_tracts_10_cb %>% filter(str_detect(GEO_ID, c("12057980100", "12086981000")))
fl_tracts_18_cb %>% filter(GEOID == 12086981000 | GEOID == 12057980100)


fl_weird_trats = rbind(f1 , f2)
fl_weird_trats %>% mapview()