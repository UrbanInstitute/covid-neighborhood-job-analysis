# Calculate Job loss by LODES Industry Sector using BLS data

library(tidyverse)
library(jsonlite)
library(testit)

# Parameters for start month and year from which to compare job change
start_month = 2
start_year = 2020

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
series_list <- names(lodes_crosswalk) %>% map_chr(construct_ces_list)

# Subset CES data to only series we are interested in, and ensure all
# of the values appear in the dataset
ces_series_subset <- ces_all %>% filter(series_id %in% series_list)
assert(length(unique(ces_series_subset$series_id)) == 
        length(names(lodes_crosswalk)))


       
       