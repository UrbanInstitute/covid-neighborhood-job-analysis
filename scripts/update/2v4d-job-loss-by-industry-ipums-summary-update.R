# Using the State by IND job loss estimates from 2v4c, merge with 
# 2014-18 ACS and disemploy people based on job loss estimates and
# random number generator. Produce a file with disemployment flag
# for public release. Summarize job loss by 2-digit NAICS by PUMA and
# write out for next step.


library(tidyverse)
library(testit)
library(ipumsr)


generate_acs_percent_change_by_industry = function(start_month_bls = 2,
  start_year_bls = 2020, acs_ipums_path = "data/raw-data/big/usa_00041.xml",
  acs_estimates_path = "data/processed-data/job_change_acs_estimates_most_recent.csv",
  latest_year = 2020, latest_month = 4){
  
  # Function to generate ACS job change by industry
  # INPUT:
  #   start_month_bls: BLS month to use as baseline to measure job loss % change
  #   start_year_bls: BLS year to use as baseline to measrue job loss % change
  #   acs_ipums_path: path to DDI file from IPUMS (data file should be in same directory)
  #   acs_estimates_path: path to state by IND estimates from 2v4c
  #   latest_year: latest year from 2v4b
  #   latest_month: latest month from 2v4b
  # OUTPUT:
  # job_change_led: a dataframe, where every row is a unique PUMA and 2-digit
  #   NAICS industry. This dataframe is the measure % change in net employment 
  #   for each PUMA-NAICS in relation to the start month and year
  
  
  # Read in estimates and crosswalk data
  ddi <- read_ipums_ddi(acs_ipums_path)
  ipums_data <- read_ipums_micro(ddi)
  acs_estimates <- read_csv(acs_estimates_path)
  
  ## Merge and disemploy -----------------------------------------------------



  
  
  ##----Write out data------------------------------------------------
  
  # Write out job chage csv specific to latest month and year
  acs_estimates %>%
    write_csv(
      str_glue("data/processed-data/job_change_acs_estimates_{start_year_bls}_{start_month_bls}_to_{latest_year}_{latest_month}.csv")
    )
  
  # Replace most recent bls job change csv
  acs_estimates %>%
    write_csv("data/processed-data/job_change_acs_estimates_most_recent.csv")
  
  
  return(acs_estimates)
}


acs_estimates = generate_acs_percent_change_by_industry()
