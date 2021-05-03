


#----Read in Data---------------------------------------------
# assign path to folder for Lodes data (ie rac_all.csv)
path <- "data/raw-data/big/"

# Read in full Lodes Data
lodes_all_raw <- read_csv(paste0(path, "rac_all.csv")) 

# Read in Lodes data for income over 40k
lodes_over_40_raw <- read_csv(paste0(path, "rac_se03.csv")) 

# Read in data that we will use 2016 data for given data issues in 2018
counties_to_get_2016 <- read_csv("data/processed-data/counties_to_get_2016.csv")


#----Cleanup LODES Data---------------------------------------------

# function to clean Lodes before join
clean_lodes <- function(df){
  
  dat_temp<- df %>%  
    # join data to choose 2016 data
    left_join(counties_to_get_2016, by = c("cty"="county_fips")) 
  
  # keep 2016 data for counties in alaska
  dat_2016<- dat_temp %>%
    filter(year == 2016 & should_be_2016 == 1) 
  
  # keep 2018 data for counties not in alaska
  dat_2018<- dat_temp %>% 
    filter(year == 2018 & (should_be_2016 !=1 | is.na(should_be_2016)))
  
  # append rows together
  my_df <- bind_rows(dat_2018, dat_2016)
  
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
  select(-c(value_all, value_40)) %>% 
  # write to csv
  write_csv("data/processed-data/lodes_joined.csv")

# check how many values are na
lodes_joined %>% 
  pull(value) %>% 
  is.na() %>% 
  sum()

