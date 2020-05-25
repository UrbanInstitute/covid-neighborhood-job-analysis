# Using the State by IND job loss estimates from 2v4c, merge with 
# 2014-18 ACS and disemploy people based on job loss estimates and
# random number generator. Produce a file with disemployment flag
# for public release. Summarize job loss by 2-digit NAICS by PUMA and
# write out for next step.


library(tidyverse)
library(testit)
library(ipumsr)


generate_acs_percent_change_by_industry = function(start_month_bls = 2,
  start_year_bls = 2020, acs_ipums_path = "data/raw-data/big/usa_00043.xml",
  acs_estimates_path = "data/processed-data/job_change_acs_estimates_most_recent.csv",
  latest_year = 2020, latest_month = 4, ipums_vintage = "2014_18"){
  
  # Function to generate ACS job change by industry
  # INPUT:
  #   start_month_bls: BLS month to use as baseline to measure job loss % change
  #   start_year_bls: BLS year to use as baseline to measrue job loss % change
  #   acs_ipums_path: path to DDI file from IPUMS (data file should be in same directory)
  #   acs_estimates_path: path to state by IND estimates from 2v4c
  #   latest_year: latest year from 2v4b
  #   latest_month: latest month from 2v4b
  #   ipums_vintage: The IPUMS vintage years used for the analysis
  # OUTPUT:
  # job_change_led: a dataframe, where every row is a unique PUMA and 2-digit
  #   NAICS industry. This dataframe is the measure % change in net employment 
  #   for each PUMA-NAICS in relation to the start month and year for people earning
  #   less than $40,000 per year in wages, in 2018 inflation adjusted dollars
  
  
  # Read in estimates and crosswalk data
  ddi <- read_ipums_ddi(acs_ipums_path)
  ipums_data <- read_ipums_micro(ddi)
  acs_estimates <- read_csv(acs_estimates_path)
  
  ## Merge and disemploy -----------------------------------------------------

  # Set seed
  set.seed(20200525)
  
  # Merge and generate disemployment flag, only if person is currently employed
  ipums_data_merge <- ipums_data %>%
    mutate(IND = str_pad(as.character(IND), 4, side = "left", pad = "0"),
           state = str_pad(as.character(STATEFIP), 2, side = "left", pad = "0"),
           puma = str_pad(as.character(PUMA), 5, side = "left", pad = "0")) %>%
    left_join(acs_estimates, by = c("IND", "state")) %>%
    mutate(percent_change_state_imputed = replace_na(percent_change_state_imputed, 0),
           random_number = runif(n()),
           disemploy = ifelse((random_number < (1 + percent_change_state_imputed)) | EMPSTAT != 1,
                              0, 1),
           wage_level = ifelse(INCWAGE < 40000, 1, 0),
           total_employment = PERWT * ifelse(EMPSTAT == 1, 1, 0),
           total_disemployment = PERWT * disemploy)
  
  # Prep for public writeout
  disemploy_file_public <- ipums_data_merge %>%
    select(YEAR, MULTYEAR, SERIAL, PERNUM, percent_change_state_imputed,
           random_number, disemploy)
  
  # Checks against national data here
  net_employment <- sum(ipums_data_merge$total_employment)
  print(str_glue("Net employment is {net_employment}"))
  net_disemployment <- sum(ipums_data_merge$total_disemployment)
  print(str_glue("Net disemployment is {net_disemployment}"))
  net_li_employment <- ipums_data_merge %>% 
    filter(wage_level == 1) %>% 
    summarise(sum(total_employment)) %>% 
    pull()
  print(str_glue("Net <$40k employment is {net_li_employment}"))
  net_li_disemployment <- ipums_data_merge %>% 
    filter(wage_level == 1) %>% 
    summarise(sum(total_disemployment)) %>% 
    pull()
  print(str_glue("Net <$40k disemployment is {net_li_disemployment}"))
  
  # Get IPUMS estimates by 2-digit NAICS by PUMA for wages < $40k
  ipums_estimates <- ipums_data_merge %>%
    filter(wage_level == 1) %>%
    group_by(state, puma, led_code) %>%
    summarise(total_employed_pre = sum(total_employment),
              total_unemployed_post = sum(total_disemployment)) %>%
    ungroup() %>%
    mutate(percent_change_imputed = -total_unemployed_post / total_employed_pre)
  
  # Potential opportunity to calculate MOE with file on next release
  
  ##----Write out data------------------------------------------------
  
  # Write out disemployment file for public use with latest month and year
  disemploy_file_public %>%
    write_csv(
      str_glue("data/processed-data/ipums/ipums_{ipums_vintage}_disemployment_{start_year_bls}_{start_month_bls}_to_{latest_year}_{latest_month}.csv")
    )

  # Write out disemployment file for public use most recent
  disemploy_file_public %>%
    write_csv(
      str_glue("data/processed-data/ipums/ipums_{ipums_vintage}_disemployment_most_recent.csv")
    )
  
  # Write out job chage csv specific to latest month and year
  ipums_estimates %>%
    write_csv(
      str_glue("data/processed-data/job_change_ipums_estimates_{start_year_bls}_{start_month_bls}_to_{latest_year}_{latest_month}.csv")
    )
  
  # Replace most recent bls job change csv
  ipums_estimates %>%
    write_csv("data/processed-data/job_change_ipums_estimates_most_recent.csv")
  
  return(ipums_estimates)
}


ipums_estimates = generate_acs_percent_change_by_industry()
