#Creates the geographic Census tract-level files, 
#which contain the simplified geometries of Census tracts at the metro area and county level

library(tidyverse)
library(urbnmapr)
library(sf)
library(tigris)

options(use_tigris_cache = T, 
        tigris_class = "sf")

#assign path of xwalk data
path <- "data/raw-data/small/"

start_month <- 2
start_year <- 2020

#read in xwalk data
read_xwalk <- function(filename){
  read_csv(paste0(path, filename),
    #skip first line
    skip = 1
  ) 
}
#create clean tract id for xwalk data
clean_xwalk <- function(df){
 df %>% 
    mutate(tract = str_remove(Tract, "\\."),
           trct = paste0(`County code`, tract))
}


#read in tract to cbsa file. should have allocation factor of 1 as tracts should be nested in counties which are nested in cbsas
tract_to_cbsa <- read_xwalk("geocorr2018_tract10_cbsa15.csv")
tract_to_cbsa_c <- clean_xwalk(tract_to_cbsa)

#check if allocation factor of 1 
cbsa_check<-tract_to_cbsa_c %>% 
  pull(`tract to cbsa allocation factor`) %>% 
  unique()!=1 

if(any(cbsa_check )){
     stop("tracts are not showing as nested within cbsas")
   }

#read in tract to county file. should have allocation factor of 1 as tracts should be nested within counties
tract_to_county <- read_xwalk("geocorr2018_tract10_county14.csv")
tract_to_county_c <- clean_xwalk(tract_to_county)

#check if allocation factor of 1
county_check<-tract_to_county_c %>% 
  pull(`tract to county14 allocation factor`) %>% 
  unique()!=1 

if(any(county_check )){
  stop("tracts are not showing as nested within counties")
}


#select only variables we need from tract to county and tract to cbsa and merge. 
#Note, merge actually not needed as tract to cbsa has county on there. 
trct_cty_cbsa<-tract_to_county_c %>% 
  select(trct,
         county_fips = `County code (2014)`,
         county_name = `County name`) %>% 
  left_join(tract_to_cbsa_c %>% 
              select(trct, 
                     cbsa = `CBSA (current)`,
                     cbsa_name = `2015 CBSA name`), 
            by = "trct")

#write out tract/county/cbsa crosswalk 
write_csv(trct_cty_cbsa, 
          "data/processed-data/tract_county_cbsa_xwalk.csv")


# Get counties around south dakota
# Purpose is WAC is missing for 2017 for south dakota, 
# which means RAC will be undercounted in surrounding area

#get spatial counties
my_counties <- get_urbn_map(map = "counties", sf = T)

#get states in order to join on final data. 
my_states_sf <- get_urbn_map(map = "states", sf = T) 

#Remove geometries
my_states <- my_states_sf %>% 
  st_drop_geometry()

#keep just south dakota
south_dakota <- filter(my_counties, state_name == "South Dakota")

#keep every county except south dakota in order to join
not_south_dakota <- filter(my_counties, state_name != "South Dakota")

#do join to find counties around south dakota
around_sd<- st_join( not_south_dakota, 
                     south_dakota %>%
                       select(county_fips), 
                     suffix = c("_not_sd", "_sd")) %>% 
  #keep only those that succcessfully joined
  filter(!is.na(county_fips_sd)) %>% 
  #pull the fips that are around sd that joined
  pull(county_fips_not_sd) %>% 
  #get unique fips
  unique()

#remove geometry and create variable that is 1 if data is in south dakota or alaska, or around south dakota. 
#both south dakota and alaska are missing from wac 2017
around_sd_df = my_counties %>% 
  st_drop_geometry() %>% 
  mutate(should_be_2016 = ifelse(state_name %in% c("South Dakota", "Alaska") | county_fips %in% around_sd, 1, 0)) %>% 
  select(county_fips, should_be_2016) 

#add states to use in final dataset
around_sd_df_1 <- around_sd_df %>% 
  mutate(state_fips = substr(county_fips, 1, 2)) %>% 
  left_join(my_states, by = "state_fips")

#write out data to choose which tracts we need to use 2016 for
write_csv(around_sd_df_1, "data/processed-data/counties_to_get_2016.csv")

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

#read in tract files

#get filenames in directory
shp_files<- list.files("data/raw-data/big", pattern = ".shp$")

#ensure these are tract files
tract_files <- shp_files [str_detect(shp_files, "tract")]


#read in tract files and append together
my_tracts<-tract_files %>% 
  map(~st_read(paste0("data/raw-data/big/", .))) %>% 
  reduce(rbind)

#write out to geojson
st_write(my_tracts, "data/processed-data/tracts.geojson")



#get cbsa spatial file for use on s3

my_cbsas<-core_based_statistical_areas(cb = T)


#write out geographies for use on s3 
st_write(my_cbsas, "data/processed-data/s3_final/cbsas.geojson")
st_write(my_counties, "data/processed-data/s3_final/counties.geojson")
st_write(my_states_sf, "data/processed-data/s3_final/states.geojson")

