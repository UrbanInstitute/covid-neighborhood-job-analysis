#This file compares 2009 bls data with 2009 Washington unemployment data 
#to benchmark our current method with job loss across the country. 


#----Load Libraries------------
library(tidyverse)
library(jsonlite)
library(testit)
library(readxl)


#----Download BLS QCEW Data for 2008------------

# BLS QCEW Data for Washington (SAE does not have all industries for WA)
download.file(url = "https://data.bls.gov/cew/data/files/2008/csv/2008_qtrly_by_area.zip",
              destfile = "data/raw-data/big/wa_qcew_2008.zip")
unzip("data/raw-data/big/wa_qcew_2008.zip",
      files = c("2008.q1-q4.by_area/2008.q1-q4 53000 Washington -- Statewide.csv"),
      exdir = "data/raw-data/big")
file.remove("data/raw-data/big/wa_qcew_2008.zip")

file.rename(from = "data/raw-data/big/2008.q1-q4.by_area/2008.q1-q4 53000 Washington -- Statewide.csv",
            to = "data/raw-data/big/wa_qcew_2008.csv")
unlink("data/raw-data/big/2008.q1-q4.by_area", recursive = TRUE)


#-----Calculate Job loss by LODES Industry Sector using BLS data------


# Parameters for start month and year from which to compare job change
start_month <- 2
start_year <- 2009

# Read in data
# Read in crosswalk from CES NAICS to LODES
lodes_crosswalk <- fromJSON("data/raw-data/small/ces-to-naics.json")

# Read in all CES data
ces_all <- read_tsv("data/raw-data/big/ces_all.txt")

# Specify only the series we are interested in:
# CES (seasonally adjusted) + {industry code from crosswalk} + 
# 01 (All employees, thousands)
construct_ces_list <- function(industry_code){
  str_glue("CES{industry_code}01")
}
series_list <- names(lodes_crosswalk) %>% 
  map_chr(construct_ces_list)

# Subset CES data to only series we are interested in, and ensure all
# of the values appear in the dataset
ces_series_subset <- ces_all %>% 
  filter(series_id %in% series_list)
assert(length(unique(ces_series_subset$series_id)) == 
         length(names(lodes_crosswalk)))

# Add month variable
ces_series_subset_m <- ces_series_subset %>%
  mutate(month = as.numeric(gsub("M", "", period)))

# Filter data to latest month as one dataset, and initial comparison
# month as another.
# Latest month
latest_month <- start_month + 1
latest_year <- start_year

ces_series_latest <- ces_series_subset_m %>%
  filter(year == latest_year) %>%
  filter(month == latest_month)

# Reference month
ces_series_reference <- ces_series_subset_m %>%
  filter(year == start_year) %>%
  filter(month == start_month) 

# Function to remove and rename columns to prep for join
#Chris note - altered slightly as this function was giving me error: "All arguments must be named"
join_prep <- function(df, col_name){
  df %>% 
    select(series_id, value) %>%
    rename(!!sym(col_name) := value)
}

# Remove and rename columns
ces_series_latest <- join_prep(ces_series_latest, "latest")
ces_series_reference <- join_prep(ces_series_reference, "reference")

# Join data together and calculate change
job_change <- ces_series_reference %>%
  left_join(ces_series_latest, by = "series_id") %>%
  mutate(percent_change_employment = latest / reference - 1)


# Add LED supersector codes
map_supersector <- function(series_id){
  str_glue("CNS", lodes_crosswalk[substr(series_id, 4, 11)][[1]])
}

job_change_led <- job_change %>%
  mutate(lodes_var = series_id %>%
           map_chr(map_supersector)) %>%
  arrange(lodes_var)




#----Calculate Job loss by LODES Industry Sector using BLS/WA state data--------



##----Set Parameters----------------------------------------------------
# start_quarter: quarter from which to compare job change and
# past_unemp_weeks: # of past weeks of unemployment data to use
# filename: filename of WA unemployment data (downloaded from 
#           download-data.R)
start_quarter <- 3
past_unemployment_weeks <- 4
filename <- "UI claims week 13_2020.xlsx"


##----Read in data------------------------------------------------------
# Read in BLS CES data
qcew_all <- read_csv("data/raw-data/big/wa_qcew_2008.csv")

# Read in crosswalk from NAICS supersector to LODES.
lodes_crosswalk <- fromJSON("data/raw-data/small/naics-to-led.json")

# Read in crosswalk from NAICS sector to LODES
lodes_crosswalk_sector <- fromJSON("data/raw-data/small/naics-sector-to-led.json")

# Read in industry to lodes xwalk, to put names to lodes industries
lehd_types <- read_csv("data/raw-data/small/lehd_types.csv")


# Above two crosswalks were constructed manually from pg 7 of
# https://lehd.ces.census.gov/data/lodes/LODES7/LODESTechDoc7.4.pdf


##----Get total_employment by LODES industry code-------------------------
# Subset to NAICS supersector and first quarter
qcew_sub <- qcew_all %>%
  filter(agglvl_code == 54, 
         qtr == start_quarter)

# Aggregate all employment, taking last month of the quarter,
# By industry by supersector
qcew_agg <- qcew_sub %>% 
  group_by(industry_code) %>%
  summarize(total_employment = sum(month3_emplvl)) %>%
  filter(industry_code %in% names(lodes_crosswalk))

# Attach LODES codes "CNS{number}" and write out
add_lodes_code <- function(industry_code){
  str_glue("CNS",lodes_crosswalk[industry_code][[1]])
}
qcew_led <- qcew_agg %>%
  mutate(lodes_var = qcew_agg$industry_code %>% map_chr(add_lodes_code))



##----Get unemploygment claims by LODES industry code-----------------------

# Read in weekly unemployment claims, drop all columns except the first 2
# and the last `n` that are not null
not_all_na <- function(var){
  any(!is.na(var))
}
add_naics_super_lodes <- function(naics){
  str_glue("CNS",lodes_crosswalk_sector[naics][[1]])
}
weekly_unemployment <- read_excel(str_glue("data/raw-data/big/{filename}"),
                                  sheet = "2DigitNAICS_ICs ",
                                  skip = 3)
weekly_unemployment_sub <- weekly_unemployment %>%
  mutate(lodes_var = weekly_unemployment$`2 Digit NAICS` %>% map_chr(add_naics_super_lodes)) %>%
  filter(lodes_var != "CNS00") %>%
  select_if(not_all_na)


weekly_unemployment_sub <- weekly_unemployment_sub %>%
  #only keep unemp claims from last n weeks
  select(`WK 10...116`: `WK 14...120`, lodes_var)

# Sum across rows to get total unemployment over past n weeks
# Then summarize by LODES code
weekly_unemployment_totals <- weekly_unemployment_sub %>%
  data.frame(unemployment = rowSums(weekly_unemployment_sub[1:past_unemployment_weeks])) %>%
  select(lodes_var, unemployment) %>%
  # AN: Any reasom you're selecting by index rather than by 
  # select(c((past_unemployment_weeks+1):(past_unemployment_weeks+2))) %>%
  group_by(lodes_var) %>%
  summarize(unemployment_totals = sum(unemployment)) %>% 
  left_join(lehd_types %>%
              transmute(lodes_var = toupper(lehd_var),
                        lehd_name), 
            by = c("lodes_var"))


##----Get % change in employment by LODES industry code-----------------------
# Note: assumes no hires, which is not true, but should generally show relative
# job change in the short term until we get BLS CES data
percent_change_industry <- qcew_led %>%
  left_join(weekly_unemployment_totals, by = "lodes_var") %>%
  select(lodes_var, everything()) %>% 
  # merge(weekly_unemployment_totals, by = "lodes_var") %>%
  mutate(percent_change_employment = -unemployment_totals / total_employment) %>%
  arrange(lodes_var) %>%
  select(lehd_name, lodes_var, everything()) 



#join together
percent_change_both<-percent_change_industry %>% 
  select(lodes_var, 
         lehd_name, 
         percent_change_employment_wa = percent_change_employment) %>% 
  left_join(job_change_led %>% 
              select(lodes_var,
                     percent_change_employment_bls = percent_change_employment), by = "lodes_var") %>% 
  mutate(dif =  percent_change_employment_wa - percent_change_employment_bls,
         dif_perc = dif / percent_change_employment_wa * -1) %>% 
  write_csv("data/processed-data/benchmarks_2009.csv")


