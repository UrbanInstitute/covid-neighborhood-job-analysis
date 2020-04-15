# Creates the data files at the Census tract level using 2017 LODES data, 
# subtracting jobs over 40k from all jobs. BLS or Washington unemployment data is available.  

# load libraries
library(tidyverse)
library(sf)

#----Set Parameters----------------------------------------------------
# choose which dataset to use ; should be either `bls` or `wa`
dataset <- "wa"

# assign path to folder for Lodes data (ie rac_all.csv)
path <- "data/raw-data/big/"

#----Read in Data---------------------------------------------
# Read in full Lodes Data
lodes_all_raw <- read_csv(paste0(path, "rac_all.csv")) 

# Read in Lodes data for income over 40k
lodes_over_40_raw <- read_csv(paste0(path, "rac_se03.csv")) 

# Read in data that we will use 2016 data for given data issues in 2017
counties_to_get_2016 <- read_csv("data/processed-data/counties_to_get_2016.csv")

# read in industry to lodes xwalk, to put names to lodes industries
lehd_types <- read_csv("data/raw-data/small/lehd_types.csv")

# read in geography crosswalk from trct to county to cbsa
trct_cty_cbsa_xwalk <- read_csv("data/processed-data/tract_county_cbsa_xwalk.csv")


# Read in % change employement estimates from WA or BLS
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


#----Cleanup LODES Data---------------------------------------------

# function to clean Lodes before join
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


#generate lodes data for <40k jobs
lodes_all <- lodes_all_raw %>%
  clean_lodes()

lodes_over_40 <- lodes_over_40_raw %>% 
  clean_lodes()

lodes_joined <- left_join(lodes_all, 
                          lodes_over_40, 
                          by = c("year",
                                 "trct",
                                 "variable"), 
                          suffix = c("_all", "_40")) %>% 
  # subtract income>40k jobs from all jobs 
  mutate(value = value_all - value_40) %>%
  # remove total and 40k variables
  select(-c(value_all, value_40)) 

# check how many values are na
lodes_joined %>% 
  pull(value) %>% 
  is.na() %>% 
  sum()



#----Generate job loss estimates for all tracts-----------------------------------

# Generate job loss estimates for each industry across all tracts. 

job_loss_wide = lodes_joined %>% 
  # join lodes total employment data to % change in 
  # employment estimates from WA or BLS
  left_join( job_loss_estimates, 
          by = c("variable" = "lodes_var"))  %>% 
  # keep only industry variables
  filter(startsWith(variable, "cns")) %>% 
  # multiply number of jobs in industry by the % change unemployment for that industry
  mutate(job_loss_in_industry = value * -1 * percent_change_employment,
         ind_var = paste0("X", str_remove(variable, "cns"))) %>% 
  select(-value, -year, -percent_change_employment, -variable) %>%
  # pvit wide to go from row=tract-industry  to row=tract
  pivot_wider(names_from = ind_var, values_from = job_loss_in_industry, id_cols = trct) %>% 
  # sum all jobs lost across all industries for total job loss per tract
  mutate(X000 =(.)%>% select(starts_with("X")) %>% rowSums(na.rm=TRUE)) %>% 
  # append county/cbsa info for each tract
  left_join(trct_cty_cbsa_xwalk, by = c("trct" = "GEOID")) %>% 
  select(trct, county_fips, county_name, cbsa, cbsa_name, everything()) %>% 
  # round jobs by industry to 0.1 (to decrease output file size)
  mutate_at(.vars = vars(X01:X20), ~round(., digits = 1)) %>% 
  # round total jobs lost to integer for reader
  # for reader understandability (What is 1.3 jobs?)
  mutate(X000 = round(X000)) 

# Note: every row of job_loss_wide is a tract

# The LODES data has one tract not found in the master 2018 Census tract file.
# This is tract 12057980100, which is in Florida and seems to be mostly water.
# For now we exlcude this tract from the analysis

# Display problematic tract
job_loss_wide %>% 
  group_by(trct) %>% 
  summarize(any_na = any(is.na(county_fips))) %>% 
  filter(any_na)

# Discard problematic tract 
job_loss_wide = job_loss_wide %>%
                filter(trct != "12057980100")




#----Append tract geographies to job loss estimates-----------------------------------

# read in tract geography
my_tracts <- st_read("data/processed-data/tracts.geojson") %>% 
  mutate_if(is.factor, as.character) %>% 
  # filter out tracts in Puerto Rico
  filter(!startsWith(GEOID, "72")) %>% 
  # filter out tracts that are only water
  filter(substr(GEOID, 6, 7) != "99")

# join data to tract spatial information
job_loss_wide_sf <- left_join(my_tracts %>% select(GEOID), 
                              job_loss_wide, 
                              by = c("GEOID" = "trct")) 

# The 2018 Census tract file has one tract not found in the LODES data
# This is tract 12086981000 near Miami Beach in Florida & has a population 
# of 62. For now we exlcude this tract from the analysis
job_loss_wide_sf <- job_loss_wide_sf %>% 
                    filter(GEOID != "12086981000")

# Check that the tracts contianed in job_loss_wide are the same after
# adding spatial info
assert("job_loss_wide_sf has a different number of rows that job_loss_wide",
       nrow(job_loss_wide_sf) == nrow(job_loss_wide))
assert("job_loss_wide_sf has differnt GEOIDS compared to job_loss_wide",
       all.equal(job_loss_wide %>% 
         arrange(trct) %>% 
         pull(trct),
       job_loss_wide_sf %>% 
         arrange(GEOID) %>% 
         pull(GEOID)))


#----Write out job loss estimates for tracts-----------------------------------

# remove extreaneous variables and write out
# job_loss_by_tract.geojson which is list of all tracts,
# thier cbsa (can be NA) and job loss estimates by sector

geo_file_name <- "data/processed-data/s3_final/job_loss_by_tract.geojson"

job_loss_wide_sf %>%
  select(-c(county_fips, 
            county_name,
            cbsa_name)) %>% 
  st_write(geo_file_name, delete_dsn = TRUE)


#create directories for smaller geojson writeouts by county and cbsa
if(!dir.exists("data/processed-data/s3_final/county")){
  dir.create("data/processed-data/s3_final/county")
}

if(!dir.exists("data/processed-data/s3_final/cbsa")){
  dir.create("data/processed-data/s3_final/cbsa")
}


# fxn to write out geojsons for smaller geographies. Takes 3 args: 
#   geo - either "county" or "cbsa"
#   code - the fips code of the geography 
#   var_name - the name of the variable storing the fips code 
#             (either county_fips or cbsa)
write_smaller_geojson <- function(geo, code, var_name){

  # get file name of file to write out    
  file_name <- paste0("data/processed-data/s3_final/", 
           geo, 
           "/", 
           code, 
           ".geojson")
  
  # filter to just the geography we want and write out the file to geojson
  job_loss_wide_sf %>%
      filter({{var_name}} == code) %>%
      select(-c(county_fips, 
                county_name,
                cbsa_name))%>%
      st_write(file_name, delete_dsn = TRUE)

}

# write out individual county job loss geojsons
job_loss_wide_sf %>% 
  filter(!is.na(county_fips)) %>%
  pull(county_fips) %>% 
  unique() %>% 
  walk(~write_smaller_geojson(geo = "county", 
                              code = ., 
                              var_name = county_fips))

# write out indiviudal cbsa job loss geojsons
job_loss_wide_sf %>% 
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


#----Generate job loss estimates for all counties/cbsa's------------------------------


# Read in state, county, cbsa info for appending more detailed names
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


# function takes in a grouped dataframe (by the geography) and finds the 
# max job loss in any industry,
# setting bins right now at 100, 250, 500, 750, 1000, 2000, 5000, and max value
# These maximum values are used to decide scale in bar charts for data viz

add_bins <- function(data, group){
  data %>% 
    pivot_longer(cols = X01:X20, 
                 names_to= "job_type", 
                 values_to = "job_loss") %>% 
  group_by({{group}}) %>% 
    mutate(max_temp = max(job_loss)) %>% 
    ungroup() %>% 
    mutate(max_max_temp = max(max_temp)) %>% 
    group_by({{group}}) %>% 
    mutate(max = case_when(
      max_temp <=100 ~ 100,
      max_temp > 100 & max_temp <= 250 ~ 250,
      max_temp > 250 & max_temp <=500 ~ 500,
      max_temp > 500 & max_temp <=750 ~ 750,
      max_temp > 750 & max_temp <= 1000 ~ 1000,
      max_temp > 1000 & max_temp <= 2000 ~ 2000,
      max_temp > 2000 & max_temp <= 5000 ~ 5000,
      max_temp > 5000 ~ max_max_temp 
    )) %>% 
    select(-c(max_temp, max_max_temp)) %>% 
    pivot_wider(names_from ="job_type", values_from = "job_loss") %>% 
    select(-max, everything()) %>% 
    ungroup()
  
}



# Get total industry job losses in each county
county_sums <- job_loss_wide_sf %>% 
  st_drop_geometry() %>% 
  filter(!is.na(county_fips)) %>%
  group_by(county_fips) %>% 
  select(-c(GEOID, 
            cbsa,
            cbsa_name,
            county_name)) %>%
  # sum job loss in each industry 
  summarise_all(~sum(.)) %>% 
  # add max job loss in any industry as a binned max variable
  add_bins(county_fips) %>% 
  # join to counties
  left_join(my_counties, by = "county_fips" ) %>% 
  # convert back to sf object
  st_sf() %>% 
  # reorder columns
  select(county_fips, county_name, state_name, everything()) %>% 




# Get total industry job losses in each cbsa
cbsa_sums <-job_loss_wide_sf %>% 
  st_drop_geometry() %>% 
  filter(!is.na(cbsa)) %>%
  mutate(cbsa = as.character(cbsa)) %>%
  group_by(cbsa) %>% 
  
  select(-c(GEOID, 
            county_fips,
            county_name, 
            cbsa_name)) %>%
  summarise_all(~sum(.))  %>% 
  # add max job loss in any industry as a binned max variable
  add_bins(cbsa) %>%
  # join to cbsas
  left_join(my_cbsas, by = "cbsa") %>%
  # convert back to sf object
  st_sf() %>% 
  # reorder columns
  select(cbsa, cbsa_name, everything()) 


#----Write out job loss estimates for all counties/cbsa's------------------------------


st_write(county_sums, "data/processed-data/s3_final/sum_job_loss_county.geojson", delete_dsn = TRUE)
st_write(cbsa_sums, "data/processed-data/s3_final/sum_job_loss_cbsa.geojson", delete_dsn = TRUE)

# write to csv
county_sums %>% 
  st_drop_geometry() %>%
write_csv("data/processed-data/s3_final/sum_job_loss_county.csv") 

# write to csv
cbsa_sums %>% 
  st_drop_geometry() %>%
  write_csv("data/processed-data/s3_final/sum_job_loss_cbsa.csv") 



#----Calculate and write out job loss estimates for whole US------------------------------

us_sums <- job_loss_wide_sf %>% 
  st_drop_geometry() %>% 
  select(-c(GEOID, 
            county_fips,
            county_name, 
            cbsa,
            cbsa_name)) %>%
  summarise_all(~sum(.)) %>% 
  mutate(GEOID = "99") %>%
  select(GEOID, everything()) %>% 
  write_csv("data/processed-data/s3_final/sum_job_loss_us.csv")



