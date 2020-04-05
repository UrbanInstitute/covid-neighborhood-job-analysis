# Calculate Job loss by LODES Industry Sector using BLS data

library(tidyverse)
library(jsonlite)
library(testit)

# Parameters for start month and year from which to compare job change
start_month <- 2
start_year <- 2020

# Read in data
# Read in crosswalk from CES NAICS to LODES
lodes_crosswalk <- fromJSON("data/raw-data/small/ces-to-naics.json")

# Read in all CES data
ces_all <- read_tsv("data/raw-data/big/ces_all.txt")

# Specify only the series we are interested in:
# CES (seasonally adjusted) + {industry code from crosswalk} + 
# 01 (All employees, thousands)
series_template <- "CES{industry_code}01"
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
ces_series_latest <- ces_series_subset_m %>%
                      filter(year == max(year)) %>%
                      filter(month == max(month))
latest_month <- max(ces_series_latest$month)
latest_year <- max(ces_series_latest$year)
# Reference month
ces_series_reference <- ces_series_subset_m %>%
                          filter(year == start_year) %>%
                          filter(month == start_month) 
# Function to remove and rename columns to prep for join
join_prep <- function(df, col_name){
  df %>% 
    select(series_id, value) %>%
    rename(setNames("value", col_name))
}
# Remove and rename columns
ces_series_latest <- join_prep(ces_series_latest, "latest")
ces_series_reference <- join_prep(ces_series_reference, "reference")

# Join data together and calculate change
job_change <- ces_series_reference %>%
               merge(ces_series_latest, by = "series_id", all.x = TRUE) %>%
               mutate(job_change = latest / reference - 1)

# Add LED supersector codes
map_supersector <- function(series_id){
  lodes_crosswalk[substr(series_id, 4, 11)][[1]]
}
job_change_led <- job_change %>%
                    mutate(led_variable = series_id %>%
                                            map_chr(map_supersector)) %>%
                    arrange(led_variable)

# Write out
job_change_led %>% 
  write_csv(
    str_glue("data/processed-data/job_change_bls_{start_year}_{start_month}_to_{latest_year}_{latest_month}.csv")
  )
                  
