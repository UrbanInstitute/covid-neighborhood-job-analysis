#Creates the data files at the Census tract level using 2017 LODES data, 
#subtracting jobs over 40k from all jobs 

#load libraries
library(tidyverse)

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
  
  mutate(
    #subtract income>40k jobs from all jobs 
    value = value_all - value_40,
    #create variable for industry crosswalk with ced
    ced_xwalk = ifelse(startsWith(variable, "cns"), 
                       substr(variable, 4, 5), 
                       NA_character_)) %>% 
  #remove total and 40k variables
  select(-c(value_all, value_40)) 

#check how many values are na
lodes_joined %>% 
  pull(value) %>% 
  is.na() %>% 
  sum()


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

#read in most recent file
ces <- read_csv(paste0("data/processed-data/", most_recent_file))

#read in industry to lodes xwalk, to put names to lodes industries
lehd_types <- read_csv("data/raw-data/small/lehd_types.csv")

#read in geography crosswalk from trct to county to cbsa
trct_cty_cbsa_xwalk <- read_csv("data/processed-data/tract_county_cbsa_xwalk.csv")

#join lodes data with most recent ces data,
#with industry names dataframe, and with the geographic xwalk
full_data <- left_join(lodes_joined, 
                       ces, 
                       by = c("ced_xwalk" = "led_variable")) %>% 
             left_join(lehd_types, by = c("variable" = "lehd_var")) %>%
             left_join(trct_cty_cbsa_xwalk, by = "trct") 


#add sums of variables by county
full_data_1 <- full_data %>% 
  group_by(county_fips, variable) %>% 
  summarise(county_total = sum(value, na.rm=T)) %>% 
  right_join(full_data, by = c("county_fips", "variable")) %>% 
  ungroup()

#add sums of variables by cbsa
full_data_2 <- full_data_1 %>%
  group_by(cbsa, variable) %>% 
  summarise(cbsa_total = sum(value, na.rm=T)) %>% 
  right_join(full_data_1, by = c("cbsa", "variable")) %>% 
  #select variables we want
           select(trct, 
                  year,
                  state_fips,
                  state_name,
                  cbsa, 
                  cbsa_name,  
                  county_fips, 
                  county_name,
                  variable,
                  lehd_name,
                  num_jobs = value,
                  job_change,
                  cbsa_total,
                  county_total)


#read in tract geography
my_tracts <- st_read("data/processed-data/tracts.geojson")



#write out data - hear back from Graham

