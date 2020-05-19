# Calculate Job loss by LODES Industry Sector using BLS data
# Uses new methodology combining CES, SAE, and IPUMS data
# to create a PUMA-level estimate of job loss by 2-digit NAICS
# Start running after June 5th instead of other "2" scripts


library(tidyverse)
library(testit)


generate_bls_percent_change_by_industry = function(start_month_bls = 2,
  start_year_bls = 2020, ces_filepath = "data/raw-data/big/ces_all.txt",
  sae_filepath = "data/raw-data/big/sae_all.txt",
  sae_xwalk_filepath = "data/raw-data/small/ces-sae-crosswalk.csv",
  ces_estimates_filepath = "data/processed-data/job_change_ces_imputed_most_recent.csv",
  sae_parent_filepath = "data/processed-data/job_change_ces_for_sae_most_recent.csv"){

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
  sae_all <- read_tsv(sae_filepath)
  sae_xwalk <- read_csv(sae_xwalk_filepath,
                        col_types = list(col_character(),
                                         col_character(),
                                         col_character()))
  ces_estimates <- read_csv(ces_estimates_filepath)
  sae_parents <- read_csv(sae_parent_filepath)

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
  
  # SAE
  # Add relevant variables and filter
  sae_data <- sae_all %>%
    mutate(state = substr(series_id, 4, 5),
           area = substr(series_id, 6, 10),
           industry = substr(series_id, 11, 18),
           datatype = substr(series_id, 19, 20),
           seasonality = substr(series_id, 3, 3)) %>%
    filter(area == "00000",
           datatype == "01",
           state != "72" & state != "78",
           seasonality == "S")
  
  # Filter data to latest month as one dataset, and initial comparison
  # month as another.
  # Latest month
  sae_series_latest <- get_bls_time(sae_data, 0, 0)
  latest_month <- max(sae_series_latest$month)
  latest_year <- max(sae_series_latest$year)
  # Reference month
  sae_series_reference <- get_bls_time(sae_data, start_year_bls, start_month_bls)

  # Function to remove and rename columns to prep for join
  join_prep <- function(df, col_name){
    df %>% 
      select(series_id, value) %>%
      rename(!!sym(col_name) := value)
  }

  # Remove and rename columns
  sae_series_latest <- join_prep(sae_series_latest, "latest")
  sae_series_reference <- join_prep(sae_series_reference, "reference")

  # Join data together and calculate % change
  job_change <- sae_series_reference %>%
                left_join(sae_series_latest, by = "series_id") %>%
                mutate(percent_change_employment = latest / reference - 1,
                       state = substr(series_id, 4, 5),
                       industry = substr(series_id, 11, 18))

  # For missing industry-state combinations, assign the parent from the crosswalk
  industries <- job_change %>%
    distinct(industry)
  states <- job_change %>%
    distinct(state)
  missing_industries <- function(st){
    # Function to take a state and return missing industries for that state
    # Input: st, 2 digit FIPS
    # Output: Dataframe with missing industries
    job_change %>%
      filter(state == st) %>%
      full_join(industries, by = "industry") %>%
      filter(is.na(series_id)) %>%
      mutate(state = st)
  }
  missing_state_industries <- unique(states$state) %>%
    map(missing_industries) %>%
    bind_rows() %>%
    select(state, industry) %>%
    rename(sae_code_2_digit = industry) %>%
    left_join(sae_xwalk, by = "sae_code_2_digit") %>%
    rename(industry = sae_code_2_digit_backup) %>%
    left_join(job_change, by = c("state", "industry")) %>%
    select(state, sae_code_2_digit, reference, latest, percent_change_employment) %>%
    rename(industry = sae_code_2_digit) %>%
    mutate(series_id = str_glue("SMS{state}00000{industry}01"))
  job_change_all <- job_change %>%
    bind_rows(missing_state_industries) %>%
    arrange(series_id)
  
  # Merge with CES data, calculate ratio to parents
  sae_parent_data <- sae_parents %>%
    mutate(industry = substr(series_id, 4, 11)) %>%
    rename(ces_reference = reference,
           ces_previous = percent_change_employment_previous,
           ces_latest = percent_change_imputed) %>%
    select(-series_id)
  ces_merge <- job_change_all %>%
    left_join(sae_parent_data, by = "industry") %>%
    filter(!is.na(ces_reference)) %>%
    mutate(ces_to_sae_diff = ces_previous - percent_change_employment)
  
  # Merge with CES detailed industries and calculate state by CES industry estimate
  

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
