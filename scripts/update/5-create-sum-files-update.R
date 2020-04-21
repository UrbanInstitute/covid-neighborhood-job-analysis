library(tidyverse)
library(sf)


#----Set parameters-------------------------------------------
# Set max bin values after evaluating histograms in S3
tmax_bins = c(100, 150, 200, 250, 700)
max_bins = c(100, 250, 500, 750, 1000, 2000, 5000, 7000, 200000)


#----Generate job loss estimates for all counties/cbsa's------------------------------


# Read in state, county, cbsa info for appending more detailed names
my_states <- st_read("data/raw-data/big/states.geojson") %>% 
  st_drop_geometry() %>% 
  transmute(state_fips = GEOID,
            state_name = NAME)

my_counties <- st_read("data/raw-data/big/counties.geojson") %>% 
  transmute(county_fips = as.character(GEOID),
            state_fips = STATEFP,
            county_name = NAME) %>% 
  left_join(my_states, "state_fips") %>% 
  select(-state_fips)
 
my_cbsas <- st_read("data/raw-data/big/cbsas.geojson") %>% 
  transmute(cbsa =  as.character(GEOID),
            cbsa_name = NAME)



job_loss_wide_sf <- st_read("data/processed-data/s3_final/job_loss_by_tract.geojson")

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
      max_temp <= max_bins[1] ~ max_bins[1],
      max_temp > max_bins[1] & max_temp <= max_bins[2] ~ max_bins[2],
      max_temp > max_bins[2] & max_temp <=max_bins[3] ~ max_bins[3],
      max_temp > max_bins[3] & max_temp <=max_bins[4] ~ max_bins[4],
      max_temp > max_bins[4] & max_temp <= max_bins[5] ~ max_bins[5],
      max_temp > max_bins[5] & max_temp <= max_bins[6] ~ max_bins[6],
      max_temp > max_bins[6] & max_temp <= max_bins[7] ~ max_bins[7],
      max_temp > max_bins[7] & max_temp <= max_bins[8] ~ max_bins[8],
      max_temp > max_bins[8] ~ max_bins[9] 
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
      max_temp <= tmax_bins[1] ~ tmax_bins[1],
      max_temp > tmax_bins[1] & max_temp <= tmax_bins[2] ~ tmax_bins[2],
      max_temp > tmax_bins[2] & max_temp <= tmax_bins[3] ~ tmax_bins[3],
      max_temp > tmax_bins[3] & max_temp <= tmax_bins[4] ~ tmax_bins[4],
      max_temp > tmax_bins[4] ~ tmax_bins[5],
    )) %>% 
    select(-max_temp) }


# Get max value of any 1 tracts jobs loss in any industry for 
# each county
county_bins <-job_loss_wide_sf %>% 
  # drop spatial features
  st_drop_geometry() %>% 
  #add county fips
  mutate(county_fips = substr(GEOID, 1, 5)) %>%
  # ensure no missing county fips
  filter(!is.na(county_fips)) %>%
  # create tract max column for each county
  add_bins(county_fips)

# Sum data to the county level & add max industry job loss 
# and max industry-tract job loss
county_sums <- read_csv("data/processed-data/county_sums.csv") %>% 
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
  select(county_fips, county_name, state_name, everything()) %>% 
  # round jobs by industry to 0.1 (to decrease output file size)
  mutate_at(.vars = vars(X01:X20), ~round(., digits = 1)) %>% 
  # round total jobs lost to integer for reader understandability 
  mutate(X000 = round(X000)) 


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
cbsa_sums <- read_csv("data/processed-data/cbsa_sums.csv") %>%
  #convert numeric cbsa into character
  mutate(cbsa = sprintf("%05d", cbsa)) %>%
  # add max industry job loss for whole cbsa
  add_sum_bins(cbsa) %>%
  # add max max tract-industry job loss for whole cbsa
  left_join(cbsa_bins, by = "cbsa") %>% 
  # join to cbsa geographies
  left_join(my_cbsas, by = "cbsa") %>%
  st_sf() %>% 
  # reorder columns
  select(cbsa, cbsa_name, everything()) %>% 
  # round jobs by industry to 0.1 (to decrease output file size)
  mutate_at(.vars = vars(X01:X20), ~round(., digits = 1)) %>% 
  # round total jobs lost to integer for reader understandability
  mutate(X000 = round(X000))


#----Write out job loss estimates for counties/cbsa's------------------------------

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
            cbsa)) %>%
  summarise_all(~sum(.)) %>% 
  mutate(GEOID = "99") %>%
  select(GEOID, everything()) %>% 
  write_csv("data/processed-data/s3_final/sum_job_loss_us.csv")
