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
                                 "state_fips",
                                 "state_abbv",
                                 "state_name",
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
  
 job_loss_estimates <- read_csv("data/processed-data/job_change_wa_last_3_weeks.csv") %>% 
   prep_employment_join()
  
} else if(dataset == "bls"){
  #get most recent ces file to join to lodes data
  
  #get files in processed data directory
  processed_files<-list.files("data/processed-data") 
  
  #get just ces files, and create variable that has the last month as designated in the file 
  ces_files<-processed_files[processed_files %>% 
                               startsWith("job_change_bls")] %>% 
    data.frame(files = .) %>% 
    mutate(last_month = substr(files, str_length(files) - 5, str_length(files) - 3) %>% 
             str_remove("_") %>% 
             as.numeric())
  
  #keep just the last file, and set file name of most recent file
  most_recent_file <- ces_files %>% 
    filter(last_month == max(last_month)) %>% 
    pull(files) %>% 
    as.character()
  
  #read in most recent file and prepare for join
  job_loss_estimates <- read_csv(paste0("data/processed-data/", most_recent_file)) %>% 
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
             left_join(trct_cty_cbsa_xwalk, by = "trct") 

#trct_cty_cbsa_xwalk is missing some county_fips - 
#note actually much less than this, as data long by variable
sum(is.na(full_data$county_fips))

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
  select(trct, 
         state_fips,
         state_name,
         county_fips,
         county_name, 
         cbsa,
         cbsa_name,
         lehd_name, 
         job_loss_in_industry) %>% 
  pivot_wider(names_from = lehd_name, values_from = job_loss_in_industry) %>% 
  left_join(job_loss_index, by = "trct")


#read in tract geography
my_tracts <- st_read("data/processed-data/tracts.geojson")

#join data to tract spatial information
job_loss_wide_sf <- left_join(my_tracts %>% select(GEOID), 
                              job_loss_wide, 
                              by = c("GEOID" = "trct")) 

#filter out puerto rico 
job_loss_wide_sf_1 <- job_loss_wide_sf %>%
  filter(!startsWith(GEOID, "72"))

#some tracts are in spatial file that are not in our data
sum(is.na(job_loss_wide_sf_1$job_loss_index))

#i don't have a solution for this, just flagging


geo_file_name <- "data/processed-data/job_loss_by_tract.geojson"


if(file.exists(geo_file_name)){
  file.remove(geo_file_name)
}

#write out data
st_write(job_loss_wide_sf_1, geo_file_name)



#Total data (not just under 40k)
#join lodes data with most recent job loss data,
#with industry names dataframe, and with the geographic xwalk
full_data_all <- left_join(lodes_all, 
                       job_loss_estimates, 
                       by = c("variable" = "lodes_var")) %>% 
  left_join(lehd_types, by = c("variable" = "lehd_var")) %>%
  left_join(trct_cty_cbsa_xwalk, by = "trct") 

#trct_cty_cbsa_xwalk is missing some county_fips - 
#note actually much less than this, as data long by variable
sum(is.na(full_data_all$county_fips))

#add correct county_fips 
full_data_1_all <- full_data_all %>% 
  mutate(county_fips = substr(trct, 1, 5))

#create job loss by industry data 
job_loss_by_industry_all <- full_data_1_all %>% 
  #keep only industry variables
  filter(startsWith(variable, "cns")) %>% 
  #multiply number of jobs in industry by the percent change unemployment for that industry
  mutate(job_loss_in_industry = value * -1 * percent_change_employment ) 

#create index
job_loss_index_all <- job_loss_by_industry_all %>% 
  #group by the tract
  group_by(trct) %>% 
  #sum job losses by industry together
  summarise(job_loss_index = sum(job_loss_in_industry)) %>% 
  #ungroup data
  ungroup()






#select total jobs for under 40k
total_jobs <-filter(full_data_1, 
                    variable == "c000") %>% 
  select(trct, 
         state_fips,
         state_name,
         county_fips,
         county_name,
         cbsa,
         cbsa_name,
         total_jobs_under_40 = value) %>% 
  #join to get index for jobs under 40k
  left_join(job_loss_index, by = "trct")


#select totals job, all jobs
total_jobs_all <- filter(lodes_all, 
                     variable == "c000") %>% 
  select(trct, total_jobs_all = value) %>% 
  #join to get index for all jobs
  left_join(job_loss_index_all, by = "trct")

#combine all data together
combined_all <- left_join(total_jobs, 
                          total_jobs_all,
                          by = "trct", 
                          suffix = c("_under_40",
                                     "_all")) 

#summarise jobs at a group level, cbsa or county, 
#and compute percentages of job loss for lodes under 40k and total lodes
summarise_job_loss <- function(df, grouped_var){
  df %>% 
    group_by({{grouped_var}}) %>% 
    select( {{grouped_var}},
             total_jobs_under_40,
             total_jobs_all,
             job_loss_index_under_40,
             job_loss_index_all) %>%
    summarise_all(
                 ~sum(., na.rm=T)) %>% 
    ungroup() %>% 
    mutate(under_40_index_perc = job_loss_index_under_40 / total_jobs_under_40,
           total_index_perc = job_loss_index_all / total_jobs_all) %>% 
    select(-c(total_jobs_under_40,
              total_jobs_all,
              job_loss_index_under_40,
              job_loss_index_all))
}


#summarise by county and merge on county names
county_job_loss<- summarise_job_loss(combined_all, county_fips) %>% 
  left_join(combined_all %>% 
              select(county_fips, county_name) %>% 
              distinct() %>% 
              filter(!is.na(county_fips) & !is.na(county_name)), by = "county_fips") 

#summarise by cbsa and merge on cbsa names
cbsa_job_loss <- summarise_job_loss(combined_all, cbsa) %>% 
  filter(!is.na(cbsa)) %>% 
  left_join(combined_all %>% 
              select(cbsa, cbsa_name) %>% 
              distinct() %>% 
              filter(!is.na(cbsa) & !is.na(cbsa_name)), by = "cbsa") 
  


#convert bbox object to dataframe
bbox_as_df <- function(my_bbox) {
  my_bbox %>%
    tibble() %>%
    mutate(names = c("xmin",
                     "ymin",
                     "xmax",
                     "ymax")) %>%
    rename(values = ".") %>% 
    mutate(values = as.numeric(values)) %>%
    pivot_wider(names_from = names, 
                values_from = values)
}

#create bounding box given a fips code and geography - geo is either "cbsa" or "county_fips"
create_bbox <- function(my_fips, geo){
  filter(job_loss_wide_sf_1, 
         {{geo}} == my_fips) %>% 
    st_bbox() %>% 
    bbox_as_df()
}

#get unique counties
my_county_fips <- job_loss_wide_sf_1 %>% 
  pull(county_fips) %>% 
  unique()

#get unique cbsas
my_cbsas <- job_loss_wide_sf_1 %>% 
  pull(cbsa) %>% 
  unique()

#remove na values in cbsas
my_cbsas_r <- my_cbsas[!is.na(my_cbsas)]

#get all county bboxes
#note: these take some time. any thoughts on how to make faster?
county_bbox<-my_county_fips %>%
  map_df(~create_bbox(., "county_fips")) %>% 
  cbind(my_county_fips, .)

#get all cbsa bboxes
#note: these take some time. any thoughts on how to make faster? 
cbsa_bbox <- my_cbsas_r %>% 
  map_df(~create_bbox(., "cbsa")) %>% 
  cbind(my_cbsas_r,  .)

#join together bbox data and county job loss data, and reorder
county_final <- left_join(county_bbox %>% rename(county_fips = my_county_fips), 
                          county_job_loss,
                          by = "county_fips") %>% 
  select(county_fips, county_name, everything())

#join together bbox data and cbsa job loss data, and reorder
cbsa_final <- left_join(cbsa_bbox %>% rename(cbsa = my_cbsas_r), cbsa_job_loss, by= "cbsa")%>% 
  select(cbsa, cbsa_name, everything())

#write out final data with bounding boxes
write_csv(county_final, "data/processed-data/county_job_loss.csv")
write_csv(cbsa_final, "data/processed-data/cbsa_job_loss.csv")
