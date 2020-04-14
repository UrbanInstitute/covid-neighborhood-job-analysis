#Creates the data files at the Census tract level using 2017 LODES data, 
#subtracting jobs over 40k from all jobs. BLS or Washington unemployment data is available.  

#load libraries
library(tidyverse)
library(sf)

#choose which dataset to use ; should be either `bls` or `wa`
dataset <- "wa"

#assign path of Lodes data
path <- "data/raw-data/big/"

#Read in full Lodes Data
lodes_all_raw <- read_csv(paste0(path, "rac_all.csv")) 

#Read in Lodes data for income over 40k
lodes_over_40_raw <- read_csv(paste0(path, "rac_se03.csv")) 


#Read in data that we will use 2016 data for given data issues in 2017
counties_to_get_2016 <- read_csv("data/processed-data/counties_to_get_2016.csv")

#function to clean data before join
clean_lodes <- function(df){
  
  dat_temp<- df %>%  
  # join data to choose 2016 data
  left_join(counties_to_get_2016, by = c("cty"="county_fips")) 
  
  # keep 2016 data for counties around and inside south dakota and alaska
  dat_2016<- dat_temp %>%
  filter(year == 2016 & should_be_2016 == 1) 
  
  # keep 2017 data for counties not around and inside south dakota and alaska
  dat_2017<- dat_temp %>% 
  filter(year == 2017 & (should_be_2016 !=1 | is.na(should_be_2016)))
  
  # append rows together
  my_df <- bind_rows(dat_2017, dat_2016)
  
  my_df %>%
  # delete unneded vars
    select(-c(cty, 
              ctyname, 
              st,
              stname,
              trctname,
              should_be_2016)) %>%  
  #make data long in order to join
    pivot_longer(starts_with("c"),  
                 names_to = "variable",
                 values_to = "value") %>% 
  #keep only desired variables
      filter(startsWith(variable, "cns")| #industry vars
             startsWith(variable, "cr") | #race vars
             startsWith(variable, "ct") | #ethnicity vars
             variable == "c000") #total jobs
}


lodes_all <- lodes_all_raw %>%
  clean_lodes()

lodes_over_40 <- lodes_over_40_raw %>% 
  clean_lodes()





#join data and create final value
lodes_joined <- left_join(lodes_all, 
                          lodes_over_40, 
                          by = c("year",
                                 "trct",
                                 "variable"), 
                          suffix = c("_all", "_40")) %>% 
  #subtract income>40k jobs from all jobs 
  mutate(value = value_all - value_40) %>%
  #remove total and 40k variables
  select(-c(value_all, value_40)) 

#check how many values are na
lodes_joined %>% 
  pull(value) %>% 
  is.na() %>% 
  sum()


prep_employment_join <- function(df){
  df %>% 
    mutate(lodes_var = tolower(lodes_var)) %>% 
    select(lodes_var, percent_change_employment)
}

if(dataset == "wa"){
  
 job_loss_estimates <- read_csv("data/processed-data/job_change_wa_most_recent.csv") %>% 
   prep_employment_join()
  
} else if(dataset == "bls"){
  #get most recent ces file to join to lodes data - deprecated, now just read in most recent file
  
  # #get files in processed data directory
  # processed_files<-list.files("data/processed-data") 
  # 
  # #get just ces files, and create variable that has the last month as designated in the file 
  # ces_files<-processed_files[processed_files %>% 
  #                              startsWith("job_change_bls")] %>% 
  #   data.frame(files = .) %>% 
  #   mutate(last_month = substr(files, str_length(files) - 5, str_length(files) - 3) %>% 
  #            str_remove("_") %>% 
  #            as.numeric())
  # 
  # #keep just the last file, and set file name of most recent file
  # most_recent_file <- ces_files %>% 
  #   filter(last_month == max(last_month)) %>% 
  #   pull(files) %>% 
  #   as.character()
  
  #read in most recent file and prepare for join
  job_loss_estimates <- read_csv("data/processed-data/job_change_bls_most_recent.csv") %>% 
    prep_employment_join()
    
  
} else {
  #if incorrect dataset value
  stop("incorrect value for `dataset`: should be `wa` or `bls`")
}


#read in industry to lodes xwalk, to put names to lodes industries
lehd_types <- read_csv("data/raw-data/small/lehd_types.csv")

#read in geography crosswalk from trct to county to cbsa
trct_cty_cbsa_xwalk <- read_csv("data/processed-data/tract_county_cbsa_xwalk.csv")

#join lodes data with most recent job loss data,
#with industry names dataframe, and with the geographic xwalk
full_data <- left_join(lodes_joined, 
                       job_loss_estimates, 
                       by = c("variable" = "lodes_var")) %>% 
             left_join(lehd_types, by = c("variable" = "lehd_var")) %>%
             left_join(trct_cty_cbsa_xwalk, by = c("trct" = "GEOID")) 

#trct_cty_cbsa_xwalk is missing some county_fips - 
#note actually much less than this, as data long by variable
# AN: Looks like this just one tract: 12057980100 in Florida
sum(is.na(full_data$county_fips))

# AN: I actually don't know if want to overwrite the county
# fips after we've done the left join with the tract_cnty_cbsa crosswalk.
# If there are any missing fips, then they aren't in our master census tract
# and that's a problem. In this case it seems to be just this one tract in 
# Florida that's in teh lodes data but not in our master 2018 tract file from the Census FTP site
#add correct county_fips 
full_data_1 <- full_data %>% 
  mutate(county_fips = substr(trct, 1, 5))

#create job loss by industry data 
job_loss_by_industry <- full_data_1 %>% 
  #keep only industry variables
  filter(startsWith(variable, "cns")) %>% 
  #multiply number of jobs in industry by the percent change unemployment for that industry
  mutate(job_loss_in_industry = value * -1 * percent_change_employment ) 

#create index
job_loss_index <- job_loss_by_industry %>% 
  #group by the tract
  group_by(trct) %>% 
  #sum job losses by industry together
  summarise(job_loss_index = sum(job_loss_in_industry)) %>% 
  #ungroup data
  ungroup()



#create job loss by industry wide file

job_loss_wide <- job_loss_by_industry %>% 
  transmute(trct,
         county_fips,
         county_name, 
         cbsa,
         cbsa_name,
         ind_var = paste0("X", str_remove(variable, "cns")),
         job_loss_in_industry) %>% 
  pivot_wider(names_from = ind_var, values_from = job_loss_in_industry) %>% 
  left_join(job_loss_index, by = "trct") %>% 
  rename(X000 = job_loss_index)

#AN: Looks like LODES is missing some tracts (and has one exta tract)
trct_cty_cbsa_xwalk %>% nrow() #Manually created xwalk has 73,745 tracts
my_tracts %>% nrow()        #Data from Census FTP site has 73,745 tracts
job_loss_wide %>% nrow()   #Lodes data has 72,738 tracts

#CD: correct. Ajjit and i discussed, he will look into if this is a problem 
# Below i flagged 100 tracts in my_tracts that are not in job_loss_wide: 99 are water tracts that are formatted with "XXXXX99XXXX" 
# see https://www2.census.gov/geo/pdfs/maps-data/data/tiger/tgrshp2017/TGRSHP2017_TechDoc_Ch3.pdf
# the only other one is 12086981000, which has a population of 62 people, estimated. I propose we just filter it out

#CD: below (ajjit's code to download my_tracts from tigris) creates same thing as my_tracts except with some extra territories

# us = fips_codes %>%
#   filter(!state_code%in% c(74)) %>%
#   pull(state_code) %>%
#   unique()
# 
# options(use_tigris_cache = FALSE)
# all_tracts <- reduce(
#   map(us, function(x) {
#     tigris::tracts(
#             class = "sf",
#             state = x,
#             cb = TRUE,
#             year = 2018,
#             refresh = TRUE)
#   }),
#   rbind
# )


#read in tract geography
my_tracts <- st_read("data/processed-data/tracts.geojson")

#join data to tract spatial information
job_loss_wide_sf <- left_join(my_tracts %>% select(GEOID), 
                              job_loss_wide, 
                              by = c("GEOID" = "trct")) 

#filter out puerto rico 
job_loss_wide_sf_1 <- job_loss_wide_sf %>%
  filter(!startsWith(GEOID, "72"))


#check how many tracts are in spatial data but not our data
sum(is.na(job_loss_wide_sf_1$X000))

#filter out water tracts 
job_loss_wide_sf_2<- filter(job_loss_wide_sf_1, substr(GEOID, 6, 7) != "99")

#check how many tracts are in spatial data but not our data
sum(is.na(job_loss_wide_sf_2$X000))

#not sure what's going on in this tract, but has a population of only 62. 


#round jobs by industry at the .1 level, full index at the integer level
job_loss_wide_sf_3 <- job_loss_wide_sf_2 %>% 
  mutate_at(.vars = vars(X01:X20), ~round(., digits = 1)) %>% 
  mutate(X000 = round(X000)) %>% 
  filter(!is.na(X000))


#remove geojson file and write out
remove_and_write <- function(sf_data, geo_file_name){
  
  if(file.exists(geo_file_name)){
    file.remove(geo_file_name)
  }
  
  #write out data
  sf_data %>%
    st_write(geo_file_name)
  
}

#remove extreaneous variables and write out
#job_loss_by_tract.geojson which is list of all tracts,
#thier cbsa (can be NA) and job loss estimates

geo_file_name <- "data/processed-data/s3_final/job_loss_by_tract.geojson"

job_loss_wide_sf_3 %>%
  select(-c(county_fips, 
            county_name,
            cbsa_name)) %>% 
  remove_and_write(geo_file_name)


#create directories for smaller geojson writeouts
if(!dir.exists("data/processed-data/s3_final/county")){
  dir.create("data/processed-data/s3_final/county")
}

if(!dir.exists("data/processed-data/s3_final/cbsa")){
  dir.create("data/processed-data/s3_final/cbsa")
}


#write out geojson in smaller files. takes in three arguments: 
#geo - either "county" or "cbsa"
#code - the fips code of the geography
#var_name - the name of the variable storing the fips code
write_smaller_geojson <- function(geo, code, var_name){

#get file name of file to write out    
file_name <- paste0("data/processed-data/s3_final/", 
         geo, 
         "/", 
         code, 
         ".geojson")

#filter to just the geography we want and write out the file to geojson
  job_loss_wide_sf_3 %>%
    filter({{var_name}} == code) %>%
    select(-c(county_fips, 
              county_name,
              cbsa_name))%>%
    remove_and_write(file_name)

}

#write out file to county geographies
job_loss_wide_sf_3 %>% 
  filter(!is.na(county_fips)) %>%
  pull(county_fips) %>% 
  unique() %>% 
  walk(~write_smaller_geojson(geo = "county", 
                              code = ., 
                              var_name = county_fips))

#write out file to cbsa geographies
job_loss_wide_sf_3 %>% 
  filter(!is.na(cbsa)) %>%
  pull(cbsa) %>% 
  unique() %>% 
  walk(~write_smaller_geojson(geo = "cbsa", 
                              code = ., 
                              var_name = cbsa))


# Ben says he no longer needs the bbox file as mapbox creates them
# #Total data (not just under 40k)
# #join lodes data with most recent job loss data,
# #with industry names dataframe, and with the geographic xwalk
# full_data_all <- left_join(lodes_all, 
#                        job_loss_estimates, 
#                        by = c("variable" = "lodes_var")) %>% 
#   left_join(lehd_types, by = c("variable" = "lehd_var")) %>%
#   left_join(trct_cty_cbsa_xwalk, by = c("trct" = "GEOID")) 
# 
# #trct_cty_cbsa_xwalk is missing some county_fips - 
# #note actually much less than this, as data long by variable
# sum(is.na(full_data_all$county_fips))
# 
# #add correct county_fips 
# full_data_1_all <- full_data_all %>% 
#   mutate(county_fips = substr(trct, 1, 5))
# 
# #create job loss by industry data 
# job_loss_by_industry_all <- full_data_1_all %>% 
#   #keep only industry variables
#   filter(startsWith(variable, "cns")) %>% 
#   #multiply number of jobs in industry by the percent change unemployment for that industry
#   mutate(job_loss_in_industry = value * -1 * percent_change_employment ) 
# 
# #create index
# job_loss_index_all <- job_loss_by_industry_all %>% 
#   #group by the tract
#   group_by(trct) %>% 
#   #sum job losses by industry together
#   summarise(job_loss_index = sum(job_loss_in_industry)) %>% 
#   #ungroup data
#   ungroup()
# 
# 
# 
# #select total jobs for under 40k
# total_jobs <-filter(full_data_1, 
#                     variable == "c000") %>% 
#   select(trct, 
#          county_fips,
#          county_name,
#          cbsa,
#          cbsa_name,
#          total_jobs_under_40 = value) %>% 
#   #join to get index for jobs under 40k
#   left_join(job_loss_index, by = "trct")
# 
# 
# #select totals job, all jobs
# total_jobs_all <- filter(lodes_all, 
#                      variable == "c000") %>% 
#   select(trct, total_jobs_all = value) %>% 
#   #join to get index for all jobs
#   left_join(job_loss_index_all, by = "trct")
# 
# #combine all data together
# combined_all <- left_join(total_jobs, 
#                           total_jobs_all,
#                           by = "trct", 
#                           suffix = c("_under_40",
#                                      "_all")) 
# 
# #summarise jobs at a group level, cbsa or county, 
# #and compute percentages of job loss for lodes under 40k and total lodes
# summarise_job_loss <- function(df, grouped_var){
#   df %>% 
#     group_by({{grouped_var}}) %>% 
#     select( {{grouped_var}},
#              total_jobs_under_40,
#              total_jobs_all,
#              job_loss_index_under_40,
#              job_loss_index_all) %>%
#     summarise_all(
#                  ~sum(., na.rm=T)) %>% 
#     ungroup() %>% 
#     mutate(under_40_index_perc = job_loss_index_under_40 / total_jobs_under_40,
#            total_index_perc = job_loss_index_all / total_jobs_all) %>% 
#     select(-c(total_jobs_under_40,
#               total_jobs_all,
#               job_loss_index_under_40,
#               job_loss_index_all))
# }
# 
# 
# #summarise by county and merge on county names
# county_job_loss<- summarise_job_loss(combined_all, county_fips) %>% 
#   left_join(combined_all %>% 
#               select(county_fips, county_name) %>% 
#               distinct() %>% 
#               filter(!is.na(county_fips) & !is.na(county_name)), by = "county_fips") 
# 
# #summarise by cbsa and merge on cbsa names
# cbsa_job_loss <- summarise_job_loss(combined_all, cbsa) %>% 
#   filter(!is.na(cbsa)) %>% 
#   left_join(combined_all %>% 
#               select(cbsa, cbsa_name) %>% 
#               distinct() %>% 
#               filter(!is.na(cbsa) & !is.na(cbsa_name)), by = "cbsa") 
#   
# 
# 
# #convert bbox object to dataframe
# bbox_as_df <- function(my_bbox) {
#   my_bbox %>%
#     tibble() %>%
#     mutate(names = c("xmin",
#                      "ymin",
#                      "xmax",
#                      "ymax")) %>%
#     rename(values = ".") %>% 
#     mutate(values = as.numeric(values)) %>%
#     pivot_wider(names_from = names, 
#                 values_from = values)
# }
# 
# #create bounding box given a fips code and geography - geo is either "cbsa" or "county_fips"
# create_bbox <- function(my_fips, geo){
#   filter(job_loss_wide_sf_1, 
#          {{geo}} == my_fips) %>% 
#     st_bbox() %>% 
#     bbox_as_df()
# }
# 
# #get unique counties
# my_county_fips <- job_loss_wide_sf_1 %>% 
#   filter(!is.na(county_fips)) %>%
#   pull(county_fips) %>% 
#   unique()
# 
# #get unique cbsas
# my_cbsas <- job_loss_wide_sf_1 %>% 
#   filter(!is.na(cbsa)) %>%
#   pull(cbsa) %>% 
#   unique()
# 
# 
# #get all county bboxes
# #note: these take some time. any thoughts on how to make faster?
# county_bbox<-my_county_fips %>%
#   map_df(~create_bbox(., county_fips)) %>% 
#   cbind(my_county_fips, .)
# 
# #get all cbsa bboxes
# #note: these take some time. any thoughts on how to make faster? 
# cbsa_bbox <- my_cbsas %>% 
#   map_df(~create_bbox(., cbsa)) %>% 
#   cbind(my_cbsas,  .)
# 
# #join together bbox data and county job loss data, and reorder
# county_final <- left_join(county_bbox %>% rename(county_fips = my_county_fips), 
#                           county_job_loss,
#                           by = "county_fips") %>% 
#   select(county_fips, county_name, everything())
# 
# #join together bbox data and cbsa job loss data, and reorder
# cbsa_final <- left_join(cbsa_bbox %>% rename(cbsa = my_cbsas), cbsa_job_loss, by= "cbsa")%>% 
#   select(cbsa, cbsa_name, everything())
# 
# #write out final data with bounding boxes
# write_csv(county_final, "data/processed-data/s3_final/county_job_loss.csv")
# write_csv(cbsa_final, "data/processed-data/s3_final/cbsa_job_loss.csv")

my_states <- st_read("data/raw-data/big/states.geojson") %>% 
  st_drop_geometry() %>% 
  transmute(state_fips = GEOID,
            state_name = NAME)

my_counties <- st_read("data/raw-data/big/counties.geojson") %>% 
  transmute(county_fips = GEOID,
            county_name = NAME,
            state_fips = STATEFP) %>% 
  left_join(my_states, "state_fips") %>% 
  select(-state_fips)

my_cbsas <- st_read("data/raw-data/big/cbsas.geojson") %>% 
  transmute(cbsa =  as.character(GEOID),
            cbsa_name = NAME)



# create a binned category for the max to use in the county and cbsa zoom-in bar charts. 
# should be the max value of any industry in the tract inside of the geo, but relatively standardized
# function takes in a grouped dataframe (by the geography) and finds the max job loss in any industry,
# setting bins right now at 100, 150, 200, 250, and 600
add_bins <- function(grouped){
  grouped %>% 
    pivot_longer(cols = X01:X20) %>%
    mutate(max_temp = max(value),
           max = case_when(
            max_temp <=100 ~ 100,
            max_temp >100 & max_temp <= 150 ~ 150,
            max_temp > 150 & max_temp <= 200 ~ 200,
            max_temp > 200 & max_temp <= 250 ~ 250,
            max_temp > 250 & max_temp <= 600 ~ 600
           )) %>% 
    select(-max_temp) %>% 
    pivot_wider(names_from ="name", values_from = "value") %>% 
    select(-max, everything())
  
}

#get medians (of tract level information) for all variables at the cbsa and county levels

#county
county_medians <-job_loss_wide_sf_3 %>% 
  st_drop_geometry() %>% 
  filter(!is.na(county_fips)) %>%
  group_by(county_fips) %>% 
  add_bins() %>%
  select(-c(GEOID, 
            cbsa,
            cbsa_name,
            county_name)) %>%
  #note: this calculates the median of `max`` as well, but `max` should all be one unique value anyway
  summarise_all(~median(.)) %>% 
  #join to counties
  right_join(my_counties, by = "county_fips" ) %>% 
  #reorder
  select(county_fips, county_name, state_name, everything()) %>% 
  #keep only rows with data
  filter(!is.na(X000)) 




#cbsa
cbsa_medians <-job_loss_wide_sf_3 %>% 
  st_drop_geometry() %>% 
  filter(!is.na(cbsa)) %>%
  mutate(cbsa = as.character(cbsa)) %>%
  group_by(cbsa) %>% 
  add_bins() %>%
  select(-c(GEOID, 
            county_fips,
            county_name, 
            cbsa_name)) %>%
  summarise_all(~median(.))  %>% 
  #join to cbsas
  right_join(my_cbsas, by = "cbsa") %>%
  #reorder
  select(cbsa, cbsa_name, everything()) %>%
  #keep only rows with data
  filter(!is.na(X000)) 


remove_and_write(county_medians, "data/processed-data/s3_final/median_job_loss_county.geojson")
remove_and_write(cbsa_medians, "data/processed-data/s3_final/median_job_loss_cbsa.geojson")

#write to csv
county_medians %>% 
  select(-geometry) %>%
write_csv("data/processed-data/s3_final/median_job_loss_county.csv") 

#write to csv
cbsa_medians %>% 
  select(-geometry) %>%
  write_csv("data/processed-data/s3_final/median_job_loss_cbsa.csv") 

#get us medians and write out
us_medians <- job_loss_wide_sf_3 %>% 
  st_drop_geometry() %>% 
  select(-c(GEOID, 
            county_fips,
            county_name, 
            cbsa,
            cbsa_name)) %>%
  summarise_all(~median(.)) %>% 
  mutate(GEOID = "99") %>%
  select(GEOID, everything()) %>% 
  write_csv("data/processed-data/s3_final/median_job_loss_us.csv")
  

