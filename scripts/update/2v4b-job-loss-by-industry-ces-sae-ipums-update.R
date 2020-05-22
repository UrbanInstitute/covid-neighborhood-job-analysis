# Calculate Job loss by CES detailed Industry Sector using BLS data
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
  #   sae_xwalk_filepath: Filepath to the CES-SAE crosswalk
  #   ces_estimates_filepath: Filpath to imputed CES data from previous step
  #   sae_parent_filepath: Filepath to imputed CES for SAE parents from previous step
  # OUTPUT:
  # job_change_led: a dataframe, where every row is a unique state and CES
  #   industry. This dataframe is the measure % change in net employment 
  #   for each state-industry in relation to the start month and year


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
    mutate(ces_to_sae_diff = ces_previous - percent_change_employment) %>%
    rename(parent_industry = industry)
  
  # Merge with CES detailed industries and calculate state by CES industry estimate
  # Function that replace the last non zero digit with 0s
  # Input: 
  #   - cstring, the string
  #   - nz, non zero digits at the end of the string to replace
  # Output: string with digits at the end replaced with 0s
  replace_zeroes <- function(cstring, nz){
    end <- substr(cstring, length(cstring) - 1, length(cstring))
    while (end == "0"){
      cstring <- substr(cstring, 1, length(cstring) - 1)
      end <- substr(cstring, length(cstring) - 1, length(cstring))
    }
    rep_str <- substr(cstring, 1, str_length(cstring) - nz)
    str_pad(rep_str, 8, "right", pad = "0")
  }
  
  # Function to take ces_code and replace last digit that's not a 0 with
  # a zero, look for code matchin SAE, repeat until parent is found, return id
  # Input: ces_code
  # Output: ces_code with matchin SAE data
  get_parent <- function(code_ces){
    found_parent <- FALSE
    num_zeroes <- 1
    while (found_parent == FALSE){
      test_ces <- replace_zeroes(code_ces, num_zeroes)
      test_filter <- sae_xwalk %>%
        filter(ces_code_2_digit == test_ces) %>%
        nrow()
      if (test_filter > 0){ found_parent = TRUE }
      num_zeroes <- num_zeroes + 1
    }
    test_ces
  }
  
  # Add SAE parent industry
  ces_prep <- ces_estimates %>%
    mutate(industry = substr(series_id, 4, 11)) %>%
    mutate(parent_industry = industry %>% map_chr(get_parent))
  ces_merge_sub <- ces_merge %>%
    select(state, parent_industry, ces_to_sae_diff)
  
  # Merge and calculate estimates
  ces_sae_estimates <- ces_merge_sub %>%
    left_join(ces_prep, by = "parent_industry") %>%
    mutate(percent_change_state_imputed = percent_change_imputed - ces_to_sae_diff) %>%
    filter(!is.na(series_id)) %>%
    select(state, industry, reference, percent_change_state_imputed)

  ##----Write out data------------------------------------------------

  # Write out job chage csv specific to latest month and year
  ces_sae_estimates %>%
    write_csv(
      str_glue("data/processed-data/job_change_sae_estimates_{start_year_bls}_{start_month_bls}_to_{latest_year}_{latest_month}.csv")
    )

  # Replace most recent bls job change csv
  ces_sae_estimates %>%
    write_csv("data/processed-data/job_change_sae_estimates_most_recent.csv")


  return(ces_sae_estimates)
}


ces_sae_estimates = generate_bls_percent_change_by_industry()
