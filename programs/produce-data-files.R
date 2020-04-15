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



# Function to get max value of the total job loss in any industry for the data 
# aggregated by the geography
# INPUT:
#   data: a dataframe of tracts
#   group: a geography to group by (ie cbsa or county_fips)
# OUTPUT:
#   data: input data with a max column appended. This max column
#         contains the binned max job loss in any industry for the data 
#         aggregated by the geography. The bins are set now at
#         100, 250, 500, 750, 1000, 2000, 5000, and max value.
# These binned maximum values are used to decide scale in bar charts for data viz
add_sum_bins <- function(data, group){
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

# Function to get max value of any one tracts jobs loss in any
# industry for the data aggregated by the geography
# INPUT:
#   data: a dataframe of tracts
#   group: a geography to group by (ie cbsa or county_fips)
# OUTPUT:
#   data: a 2 column dataframe with the geography (cbsa or county_fips)
#         and tmax, or the tract maximum. Tmax is a binned variable with
#         with bins right now at 100, 150, 200, 250, and 600
# These max binned values are used to decide scale for bar charts in data viz
add_bins <- function(data, group){
  data %>% 
    pivot_longer(cols = X01:X20, 
                 names_to= "job_type", 
                 values_to = "job_loss") %>% 
    group_by({{group}}) %>% 
    summarise(max_temp = max(job_loss)) %>% 
    mutate(tmax = case_when(
      max_temp <=100 ~ 100,
      max_temp > 100 & max_temp <= 150 ~ 150,
      max_temp > 150 & max_temp <=200 ~ 200,
      max_temp > 200 & max_temp <=250 ~ 250,
      max_temp > 250 ~ 600,
    )) %>% 
    select(-max_temp) }


# Get max value of any 1 tracts jobs loss in any industry for 
# each county
county_bins <-job_loss_wide_sf %>% 
  # drop spatial features
  st_drop_geometry() %>% 
  # ensure no missing county fips
  filter(!is.na(county_fips)) %>%
  # create tract max column for each county
  add_bins(county_fips)

# Sum data to the county level & add max industry job loss 
# and max industry-tract job loss
county_sums <- job_loss_wide_sf %>%
  # drop spatial features
  st_drop_geometry() %>%
  # ensure no missing counties
  filter(!is.na(county_fips)) %>%
  # cast county as character to avoid warnings
  mutate(county_fips = as.character(county_fips)) %>% 
  # group by the county
  group_by(county_fips) %>% 
  # aggregate industry job loss values to county
  summarise_at(.vars = vars(starts_with("X")), ~sum(.)) %>% 
  # ungroup data
  ungroup() %>%
  # add max industry job loss for whole county
  add_sum_bins(county_fips) %>% 
  # add max tract-industry job loss for whole county
  left_join(county_bins, by = "county_fips") %>%
  # join to county geographies
  left_join(my_counties %>% 
              mutate(county_fips = as.character(county_fips)), 
            by = "county_fips" ) %>% 
  # cast back to sf object
  st_sf() %>% 
  # reorder columns
  select(county_fips, county_name, state_name, everything()) 
 

# Get max value of any 1 tracts jobs loss in any industry for 
# each cbsa
cbsa_bins <-job_loss_wide_sf %>%
  # drop spatial features
  st_drop_geometry() %>%
  # ensure no missing cbsas
  filter(!is.na(cbsa)) %>%
  # cast cbsa as character to avoid warning
  mutate(cbsa = as.character(cbsa)) %>%
  # add tract maximum for bins
  add_bins(cbsa)

# Sum data to the cbsa level & add max industry job loss 
# and max industry-tract job loss 
cbsa_sums <- job_loss_wide_sf %>% 
  # drop spatial features
  st_drop_geometry() %>%
  # ensure no missing cbsas
  filter(!is.na(cbsa)) %>%
  # cast cbsa as character to avoid warning
  mutate(cbsa= as.character(cbsa)) %>% 
  # group by the cbsa
  group_by(cbsa) %>% 
  # aggregate industry job loss values to cbsa
  summarise_at(.vars = vars(starts_with("X")), ~sum(.)) %>% 
  # add max industry job loss for whole cbsa
  add_sum_bins(cbsa) %>%
  # add max max tract-industry job loss for whole cbsa
  left_join(cbsa_bins, by = "cbsa") %>% 
  # join to cbsa geographies
  left_join(my_cbsas, by = "cbsa") %>%
  st_sf() %>% 
  # reorder columns
  select(cbsa, cbsa_name, everything())


#----Write out job loss estimates for counties/cbsa's------------------------------

st_write(county_sums, "data/processed-data/s3_final/sum_job_loss_county.geojson", delete_dsn = TRUE)
st_write(cbsa_sums, "data/processed-data/s3_final/sum_job_loss_cbsa.geojson", delete_dsn = TRUE)

# write to csv
county_sums %>% 
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



