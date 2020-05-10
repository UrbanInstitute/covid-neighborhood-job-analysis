# Calculate Job loss by LODES Industry Sector using BLS data
# Uses new methodology combining CES, SAE, and IPUMS data
# to create a PUMA-level estimate of job loss by 2-digit NAICS
# Start running after June 5th instead of other "2" scripts


library(tidyverse)
library(jsonlite)
library(testit)


generate_bls_percent_change_by_industry = function(
  start_month_bls = 2,
  start_year_bls = 2020, 
  ces_filepath = "data/raw-data/big/ces_all.txt",
  sae_filepath = "data/raw-data/big/sae_all.txt"){

  # Function to generate bls percent change job loss by industry
  # INPUT:
  #   start_month_bls: BLS month to use as baseline to measure job loss % change
  #   start_year_bls: BLS year to use as baseline to measrue job loss % change
  #   ces_filepath: Filepath to ces_all.txt file downloaded in by
  #     1-download-data-update.R
  #   sae_filepath: Filepath to sae_all.txt file downloaded in by
  #     1-download-data-update.R
  # OUTPUT:
  # job_change_led: a dataframe, where every row is a unique PUMA and 2-digit
  #   NAICS industry. This dataframe is the measure % change in net employment 
  #   for each PUMA-industry in relation to the start month and year


  # Read in CES, SAE, and crosswalk data
  ces_all <- read_tsv(ces_filepath)
  sae_all <- read_tsv(sae_filepath)

  ##----Generate % Change in employment-----------------------------------

  get_bls_time <- function(df, yr, mo){
    # Function to get latest month and year of BLS data from flat files
    # INPUT:
    #   df: Dataframe of BLS flat file, tidy format
    #   yr: Year to filter, 0 for max
    #   mo: Month to filter, 0 for max
    # OUTPUT:
    # df: A Dataframe filtered to just the requested month and year
    df_mo <- df %>%
      mutate(month = as.numeric(gsub("M", "", period)))
    if (yr == 0){ yr <- max(df_mo$year) }
    if (mo == 0){ 
      df_mo_yr <- df_mo %>% filter(year == yr)
      mo <- max(df_mo_yr$month)
    }
    df_mo %>%
      filter(year == yr) %>%
      filter(month == mo)
  }
  
  # CES
  # Filter data to latest month as one dataset, and initial comparison
  # month as another.
  # Latest month
  ces_series_latest <- get_bls_time(ces_all, 0, 0)
  latest_month <- max(ces_series_latest$month)
  latest_year <- max(ces_series_latest$year)
  # Reference month
  ces_series_reference <- get_bls_time(ces_all, start_year_bls, start_month_bls)

  # Function to remove and rename columns to prep for join
  join_prep <- function(df, col_name){
    df %>% 
      select(series_id, value) %>%
      rename(!!sym(col_name) := value)
  }

  # Remove and rename columns
  ces_series_latest <- join_prep(ces_series_latest, "latest")
  ces_series_reference <- join_prep(ces_series_reference, "reference")

  # Join data together and calculate % change
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

  ##----Write out data------------------------------------------------

  # Write out job chage csv specific to latest month and year
  job_change_led %>%
    write_csv(
      str_glue("data/processed-data/job_change_bls_{start_year_bls}_{start_month_bls}_to_{latest_year}_{latest_month}.csv")
    )

  # Replace most recent bls job change csv
  job_change_led %>%
    write_csv("data/processed-data/job_change_bls_most_recent.csv")


  return(job_change_led)
}


job_change_led = generate_bls_percent_change_by_industry()
