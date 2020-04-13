#Creates the geographic Census tract-level files, 
#which contain the simplified geometries of Census tracts at the metro area and county level

library(tidyverse)
library(sf)
library(jsonlite)




# Get counties around south dakota
# Purpose is WAC is missing for 2017 for south dakota, 
# which means RAC will be undercounted in surrounding area


my_counties <- st_read("data/raw-data/big/counties.geojson")


#keep just south dakota
south_dakota <- filter(my_counties %>% select(GEOID, STATEFP), STATEFP == "46")

#keep every county except south dakota in order to join
not_south_dakota <- filter(my_counties %>% select(GEOID, STATEFP), STATEFP!= "46")

#do join to find counties around south dakota
around_sd<- st_join( not_south_dakota, 
                     south_dakota,
                     #We want counties outside SD that touch SD
                     join = st_touches,
                     left = FALSE,
                     suffix = c("_not_sd", "_sd")) %>% 
  #Pull unique geoids of counties bordering South Dakota
  pull(GEOID_not_sd) %>% 
  unique()


#remove geometry and create variable that is 1 if data is in south dakota or alaska, or around south dakota. 
#both south dakota and alaska are missing from wac 2017
around_sd_df = my_counties %>% 
  st_drop_geometry() %>% 
  mutate(should_be_2016 = ifelse(STATEFP %in% c("46", "02") | GEOID %in% around_sd, 1, 0)) %>% 
  select(county_fips = GEOID, should_be_2016) 

#write out data to choose which tracts we need to use 2016 for
write_csv(around_sd_df, "data/processed-data/counties_to_get_2016.csv")


#---------
#potential code to use when we want to use place
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
#read in tract files

#get filenames in directory
shp_files<- list.files("data/raw-data/big", pattern = ".shp$")

#ensure these are tract files
tract_files <- shp_files [str_detect(shp_files, "tract")]


#read in tract files and append together
my_tracts<-tract_files %>% 
  map(~st_read(paste0("data/raw-data/big/", .))) %>% 
  reduce(rbind) %>% 
  st_transform(4326)

#write out to geojson
st_write(my_tracts, "data/processed-data/tracts.geojson", delete_dsn = TRUE)


#---------
#create cbsa tract crosswalk using spatial methods

#read in cbsa shapefile
my_cbsas<- st_read("data/raw-data/big/cbsas.geojson") %>% 
  select(cbsa_fips = GEOID, cbsa_name = NAME)

#join tract shapefile with cbsa shapefile
joined_cbsa<- st_join(my_tracts %>% select(GEOID), my_cbsas, join = st_covered_by)

#tracts are not in multiple cbsas
joined_cbsa$GEOID %>% 
  unique() %>%
  length() == nrow(joined_cbsa)



#create crosswalk
trct_cty_cbsa <- joined_cbsa %>% 
  #drop geometry
  st_drop_geometry() %>% 
  #add county fips
  mutate(county_fips = substr(GEOID, 1, 5)) %>% 
  #join with county for county names
  left_join(my_counties, by = c("county_fips" = "GEOID")) %>%
  #select/order wanted variables
  select(GEOID, county_fips, county_name = NAME, cbsa = cbsa_fips, cbsa_name)

write_csv(trct_cty_cbsa, "data/processed-data/tract_county_cbsa_xwalk.csv")

#-----------  
#Write out CbsaToCounty and CountyToCbsa JSONS

county_to_cbsa = trct_cty_cbsa %>% 
  filter(!is.na(cbsa)) %>% 
  group_by(county_fips) %>% 
  summarize(cbsas = list(unique(cbsa)))  %>% 
  pivot_wider(names_from = county_fips, values_from = cbsas)

cbsa_to_county = trct_cty_cbsa %>% 
  group_by(cbsa) %>% 
  summarize(counties = list(unique(county_fips))) %>% 
  pivot_wider(names_from = cbsa, values_from = counties)


jsonlite::write_json(cbsa_to_county, 'data/processed-data/cbsaToCounty2.json')
jsonlite::write_json(county_to_cbsa, 'data/processed-data/CountyToCbsa2.json')

