#Creates the geographic Census tract-level files, 
#which contain the simplified geometries of Census
#tracts at the metro area and county level

library(tidyverse)
library(sf)
library(jsonlite)
library(testit)

options(scipen = 999)


#----Get counties around South Dakota --------------------------
# We do this bc WAC is missing in 2017 for south dakota, 
# which means RAC will be undercounted in surrounding area

my_counties <- st_read("data/raw-data/big/counties.geojson")


# keep just south dakota
south_dakota <- filter(my_counties %>% select(GEOID, STATEFP), STATEFP == "46")

# keep every county except south dakota in order to join
not_south_dakota <- filter(my_counties %>% select(GEOID, STATEFP), STATEFP!= "46")

# do join to find counties around south dakota
around_sd<- st_join( not_south_dakota, 
                     south_dakota,
                     #We want counties outside SD that touch SD,
                     # so we use st_touches
                     join = st_touches,
                     left = FALSE,
                     suffix = c("_not_sd", "_sd")) %>% 
  # Pull unique geoids of counties bordering South Dakota
  pull(GEOID_not_sd) %>% 
  unique()


# remove geometry and create variable that is 1 if data is in south dakota 
# or alaska, or around south dakota. 
# both south dakota and alaska are missing from wac 2017
around_sd_df = my_counties %>% 
  st_drop_geometry() %>% 
  mutate(should_be_2016 = ifelse(STATEFP %in% c("46", "02") | GEOID %in% around_sd, 1, 0)) %>% 
  select(county_fips = GEOID, should_be_2016) 

# write out data to choose which tracts we need to use 2016 for
write_csv(around_sd_df, "data/processed-data/counties_to_get_2016.csv")


#---------
## potential code to use when we want to use place
# tract_to_place <- read_xwalk("geocorr2018_tract10_place14.csv")
# tract_to_place_c <- clean_xwalk(tract_to_place) 
# 
# tract_to_place_c_1 <- tract_to_place_c %>%
#   group_by(trct) %>% 
#   summarise(pop10_trct = sum(`Population (2010)`, na.rm=T)) %>% 
#   right_join(tract_to_place_c, by = "trct") %>% 
#   ungroup() %>% 
#   mutate(afact = `Population (2010)` / pop10_trct,
#          fullplacefp = paste0(`State code`, `Place (2014)`)) %>% 
#   filter(afact >= .01, !is.na(`Place name 2014`)) %>% 
#   select(trct, 
#          fullplacefp, 
#          place_name = `Place name 2014`,
#          afact) %>% 
#   distinct()


#----------

#----Generate all tracts in US file --------------------------

# get filenames in directory
shp_files <- list.files("data/raw-data/big", pattern = ".shp$")

# ensure these are tract files
tract_files <- shp_files[str_detect(shp_files, "tract")]

# read in tract files and append to 1 big tracts file
my_tracts<-tract_files %>% 
  map(~st_read(paste0("data/raw-data/big/", .))) %>% 
  reduce(rbind) %>% 
  st_transform(4326)

# write out to geojson
st_write(my_tracts, "data/processed-data/tracts.geojson", 
         delete_dsn = TRUE)



#----Create tract<>CBSA croswalk --------------------------

# Crosswalk creatd by spatially joining tracts to CBSA's and using
# using 99.5% area cutoff (ie 99.5% of tracts area needs to be 
# inside CBSA). CBSA's are made up of tracts, so all tracts should 
# be in 1 CBSA max.

# We initially used Mable Geocorr's tract to CBSA crosswalk file,
# (http://mcdc.missouri.edu/applications/geocorr2014.html) 
# but found a few errors/left out tracts. So we decided 
# to create the crosswalk ourselves. Geocorr file can
# be found at data/raw-data/geocorr2018_tract10_place14.csv


# read in CBSA geographies
my_cbsas<- st_read("data/raw-data/big/cbsas.geojson") %>% 
  select(cbsa_fips = GEOID, cbsa_name = NAME)

# get intersections of tracts and cbsas
my_intersections <- st_intersection(my_tracts %>% 
                                      select(GEOID) %>% 
                                      #change projection to Albers equal area as 
                                      # you want a projected crs when doing area
                                      # calculations. Note using crs 4326 doesn't
                                      # change results.
                                      st_transform("ESRI:102008"), 
                                    my_cbsas %>% 
                                      st_transform("ESRI:102008")) %>% 
                    st_transform(4326)


# add area of intersections
my_intersections <- my_intersections %>% 
  mutate(int_area = st_area(my_intersections)) 

# add area of tract
my_tracts_area <- my_tracts %>% 
  transmute(GEOID, tract_area = st_area(my_tracts)) %>% 
  st_drop_geometry() %>% 
  as_tibble()

# calculate intersection area/tract area and filter to
# only areas where intersection is over 99.5% of the tract's
# area. This is done to exclude intersections that only overlap 
# with the border of a CBSA. 
tract_cbsa_ints <- my_intersections %>% 
  st_drop_geometry() %>% 
  right_join(my_tracts_area, "GEOID") %>% 
  as_tibble() %>% 
  mutate(perc = int_area / tract_area,
         perc = as.numeric(perc)) %>% 
  filter(perc >= .7)

# Check tracts are not in multiple CBSAs
assert("tracts are in multiple CBSAs", 
       tract_cbsa_ints %>% 
        pull(GEOID) %>% 
        unique() %>%
        length() == nrow(tract_cbsa_ints))


# join data back onto tract data
tract_cbsa_ints <- my_tracts %>% 
  select(GEOID) %>% 
  left_join(tract_cbsa_ints, "GEOID")


# create tract to CBSA crosswalk
trct_cty_cbsa <- tract_cbsa_ints %>% 
  st_drop_geometry() %>% 
  # get county fips from tract GEOID
  mutate(county_fips = substr(GEOID, 1, 5)) %>% 
  # join with county for county names
  left_join(my_counties, by = c("county_fips" = "GEOID")) %>%
  # select/order wanted variables
  select(GEOID, county_fips, county_name = NAME, cbsa = cbsa_fips, cbsa_name)

write_csv(trct_cty_cbsa, "data/processed-data/tract_county_cbsa_xwalk.csv")


#----Write out tracts not in any CBSA's --------------------------
# This is used as a masking polygon for the data viz
tracts_out_of_cbsas = tract_cbsa_ints %>%
  filter(is.na(cbsa_fips)) %>% 
  st_union() %>% 
  st_sf()

st_write(tracts_out_of_cbsas, "data/processed-data/s3_final/no_cbsa_tracts.geojson",
         delete_dsn = TRUE)


#----Write out CbsaToCounty and CountyToCbsa JSONS---------------

# This is used for toggling between County and CBSA in data viz
county_to_cbsa = trct_cty_cbsa %>% 
  filter(!is.na(cbsa)) %>% 
  group_by(county_fips) %>% 
  summarize(cbsas = list(unique(cbsa)))  %>% 
  pivot_wider(names_from = county_fips, values_from = cbsas)

cbsa_to_county = trct_cty_cbsa %>% 
  group_by(cbsa) %>% 
  summarize(counties = list(unique(county_fips))) %>% 
  pivot_wider(names_from = cbsa, values_from = counties)


jsonlite::write_json(cbsa_to_county, 'data/processed-data/CbsaToCounty2.json')
jsonlite::write_json(county_to_cbsa, 'data/processed-data/CountyToCbsa2.json')


#----Create tract<>PUMA croswalk --------------------------


# Read in pumas
my_pumas <- st_read("data/raw-data/big/pumas.geojson")

# Generate tract population centroids
x = my_tracts %>%
    left_join(pop_centers_2010 %>%
        mutate(GEOID = paste0(STATEFP, COUNTYFP, TRACTCE)) %>% 
        select(GEOID, POPULATION, LATITUDE, LONGITUDE),
        by = "GEOID"
    )

# Use population weighted centroids to set center of tracts. 25 tracts,
#  don't exist in the 2010 Census provided population centroids, so we just
#  calculate the areal centroids and append. Note, for 1 tract in TX, the
#  population centroid is just  outside of the US, so we use areal centroid
#  instead. For one tract in AL, both the population and areal centroid are outside
#  the US (in the middle of the Pacific Ocean), so we hardcode lat/lon based on manual
#  survey of Google Maps
tract_centroids = x %>%
    st_drop_geometry() %>%
    as_tibble() %>%
    # For one tract in Alaska, both the population weighted cenroid and the areal
    # end up being in the Pacific Ocean. So just for that one tract, we
    # hardcode a lat/lon centroid based on a manual survey of Google Maps.
    mutate(
        LATITUDE = if_else(GEOID == "02016000100", 52.318869, LATITUDE),
        LONGITUDE = if_else(GEOID == "02016000100", -172.452039, LONGITUDE)
    ) %>% 
    filter(!is.na(LATITUDE)) %>%
    # One tract in TX that has population centroid outside of US, so we filter
    # out and use areal centroid instead.
    filter(!GEOID %in% c("48479001717")) %>% 
    st_as_sf(coords = c("LONGITUDE", "LATITUDE")) %>% 
    st_set_crs(4326)
unjoined_tract_centroids = x %>%
    filter(GEOID %in% c("48479001717") | is.na(LATITUDE)) %>% 
    select(-LATITUDE, -LONGITUDE) %>% 
    st_centroid()

tract_centroids = rbind(tract_centroids, unjoined_tract_centroids)


# Spatially join tract centroids with PUMA's. This generates a 1:1 list of
# tracts to PUMA's
p_t_ints = st_join(
    tract_centroids %>%
        select(GEOID, POPULATION) %>% 
        st_transform("ESRI:102008"), 
    my_pumas %>%
        select(
        puma_geoid = GEOID10,
        puma_name = NAMELSAD10
        ) %>% 
        st_transform("ESRI:102008")) %>% 
    st_transform(4326)

# Make sure that all tracts are joined to a PUMA
assert(nrow(p_t_ints %>% filter(is.na(puma_geoid))) == 0)

puma_tract_xwalk = p_t_ints %>% 
st_drop_geometry() %>% 
# Filter out tracts in Puerto Rico as we're not using for this project
filter(!startsWith(puma_geoid, "72"))

puma_tract_xwalk %>% write_csv("data/processed-data/puma_tract_xwalk.csv")

# Old 1:many spatial join code. This turned out to be pretty hairy because there
# were lots of LINESTRINGS/POINTS that were intersecting and there wasn't a good
# # area cutoff to get clean intersections areas. Code takes 15 minutes to run.
# my_puma_tract_intersections <- st_intersection(my_tracts %>%
#                                       select(GEOID, state_fips = STATEFP, 
#                                       county_fips = COUNTYFP) %>% 
#                                       #change projection to Albers equal area as 
#                                       # you want a projected crs when doing area
#                                       # calculations. Note using crs 4326 doesn't
#                                       # change results.
#                                       st_transform("ESRI:102008"), 
#                                     my_pumas %>%
#                                       select(
#                                         puma_geoid = GEOID10,
#                                         puma_name = NAMELSAD10
#                                       ) %>% 
#                                       st_transform("ESRI:102008")) %>% 
#                     st_transform(4326)


# # add area of intersections
# my_puma_tract_intersections <- my_puma_tract_intersections %>% 
#   mutate(int_area = st_area(my_puma_tract_intersections)) 


#   my_puma_tract_intersections %>% select(int_area) %>% summary()



# # calculate intersection area/tract area and filter to
# # only areas where intersection is over 2% of the tract's
# # area. This is done to exclude intersections that only overlap 
# # with the border of a CBSA. 
# puma_tract_ints <- my_puma_tract_intersections %>% 
#   right_join(my_tracts_area, "GEOID") %>% 
#   mutate(perc = int_area / tract_area,
#          perc = as.numeric(perc)) %>% 
#     filter(perc > 0.05)
  
#   puma_tract_ints %>% st_write("data/raw-data/puma_tracts_ints.geojson")




# tracts_in_multiple_pumas = x %>%
#     count(GEOID) %>%
#     filter(n > 1) %>%
#     arrange(n) %>% 
#     pull(GEOID)

# ints_tracts = puma_tract_ints %>% 
#     filter(GEOID %in% tracts_in_multiple_pumas)

# ints_tracts %>%
#     filter(puma_geoid == "0400120") %>%
#     select(geometry) %>% 
#     plot(
#         col = alpha("green", 0.4),
#         add = T
#     )

# p_t_ints %>% filter(puma_geoid == "0400120")
# my_pumas %>% 
#     filter(GEOID10 == "0400120") %>% 
#     select(geometry) %>% 
#     plot(col = alpha("red", 0.4))

# p_geoids <- x %>%
#     filter(GEOID %in% tracts_in_multiple_pumas) %>% 
#     pull(puma_geoid) %>%
#     unique()

# int_pumas = my_pumas %>%
#     filter(GEOID10 %in% p_geoids)
    
# mapview(int_pumas)
        
# mapview(small_int_tracts %>% slice(1), col.regions = "blue")
# mapview(my_pumas %>% filter())

# leaflet(ints_tracts %>% slice(2)) %>%
#     addProviderTiles('CartoDB.Positron') %>% 
#     leafem::addFeatures()

# ints_tracts %>% slice(2) %>% plot()
# plot(ints_tracts %>% slice(3:4) %>% select(geometry), col = "green")
# plot(int_pumas %>% filter(GEOID10 %in% (ints_tracts %>% slice(3) %>% pull(puma_geoid))) %>% select(geometry), col = "red")
# mapview(int_pumas %>% filter(puma_geoid == ints_tracts %>% slice(1) %>% pull(puma_geoid)), col.regions = "green")


# summary()
# my_puma_tract_intersections %>% as_tibble()
# my_tracts_area %>% as_tibble()