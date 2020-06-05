# Calculate Job loss by ACS IND Sector using BLS data
# Uses new methodology combining CES, SAE, and IPUMS data
# to create a PUMA-level estimate of job loss by 2-digit NAICS
# Start running after June 5th instead of other "2" scripts


library(tidyverse)
library(testit)


generate_acs_percent_change_by_industry = function(start_month_bls = 2,
  start_year_bls = 2020, sae_estimates_path = "data/processed-data/job_change_sae_estimates_most_recent.csv",
  acs_xwalk_path = "data/raw-data/small/2017-ind-ces-crosswalk.csv",
  latest_year = 2020, latest_month = 4){
  
  # Function to generate ACS job change by industry
  # INPUT:
  #   start_month_bls: BLS month to use as baseline to measure job loss % change
  #   start_year_bls: BLS year to use as baseline to measrue job loss % change
  #   sae_estimates_path: path to file producing state and industry level job loss estimates
  #   acs_xwalk_path: path to crosswalk from CES industry to ACS industry
  #   latest_year: latest year from 2v4b
  #   latest_month: latest month from 2v4b
  # OUTPUT:
  # job_change_led: a dataframe, where every row is a unique state and ACS
  #   industry. This dataframe is the measure % change in net employment 
  #   for each state-industry in relation to the start month and year
  
  
  # Read in estimates and crosswalk data
  sae_estimates <- read_csv(sae_estimates_path)
  acs_xwalk <- read_csv(acs_xwalk_path)
  

  ##----Crosswalk to ACS codes--------------------------------------------------

  # Format datasets
  acs_xwalk_sub <- acs_xwalk %>%
    select(IND, ces_code, led_code, formula_type, operator) %>%
    rename(industry = ces_code)
  acs_xwalk_single <- acs_xwalk_sub %>%
    filter(formula_type == "single" & !is.na(industry))
  acs_xwalk_na <- acs_xwalk_sub %>%
    filter(is.na(industry))
  acs_xwalk_formula <- acs_xwalk_sub %>%
    filter(formula_type == "formula") %>%
    mutate()
  
  # Join and calculate formulas
  # Join function
  join_states <- function(st){
    # Function to join the sae_estimates with the sae crosswalk, by state
    # Input:
    #   st: State, 2-digit FIPS
    # Output:
    #   Full data frame for that state where each record is unique on IND
    
    # Filter by state
    sae_filter <- sae_estimates %>%
      filter(state == st)
    
    # For single operators, join and we're done, dropping duplicates
    sae_acs_single <- acs_xwalk_single %>%
      left_join(sae_filter, by = "industry") %>%
      select(IND, state, led_code, percent_change_state_imputed) %>%
      distinct(IND, .keep_all = TRUE)
    
    # For N/A operators, add state
    sae_acs_na <- acs_xwalk_na %>%
      mutate(state = st,
             reference = NA,
             percent_change_state_imputed = NA) %>%
      select(IND, state, led_code, percent_change_state_imputed)
    
    # For formula operators, do weighted math
    sae_acs_formula <- acs_xwalk_formula %>%
      left_join(sae_filter, by = "industry") %>%
      mutate(product = ifelse(operator == "+",
                              reference * percent_change_state_imputed,
                              -reference * percent_change_state_imputed),
             reference_sum = ifelse(operator == "+",
                                    reference,
                                    -reference)) %>%
      group_by(IND) %>%
      summarize(sum_product = sum(product),
                sum_reference = sum(reference_sum)) %>%
      mutate(percent_change_state_imputed = sum_product / sum_reference,
             percent_change_state_imputed = ifelse(sum_reference <= 5,
                    NA,
                    percent_change_state_imputed)) %>%
      ungroup()
    
      # For formula operators with no residual, use + categories only
      sae_acs_formula_no_residual <- sae_acs_formula %>%
        filter(is.na(percent_change_state_imputed)) %>%
        select(IND) %>%
        left_join(acs_xwalk_sub, by = "IND") %>%
        filter(operator == "+") %>%
        left_join(sae_filter, by = "industry") %>%
        mutate(product = reference * percent_change_state_imputed) %>%
        group_by(IND) %>%
        summarize(sum_product = sum(product),
                  sum_reference = sum(reference)) %>%
        mutate(percent_change_state_imputed = sum_product / sum_reference)
      
      # Filter out no residuals from formulas and bind together
      get_led_codes <- acs_xwalk %>%
        distinct(IND, led_code)
      sae_acs_formula_bind <- sae_acs_formula %>%
        filter(!is.na(percent_change_state_imputed)) %>%
        bind_rows(sae_acs_formula_no_residual) %>%
        mutate(state = st) %>%
        select(IND, state, percent_change_state_imputed) %>%
        left_join(get_led_codes, by = "IND")
      
      # Bind all together and return
      sae_acs_data <- sae_acs_single %>%
        bind_rows(sae_acs_na, sae_acs_formula_bind)
      assert("Length is the same as unique IND from crosswalk",
             length(unique(sae_acs_data$IND)) == acs_xwalk %>%
               distinct(IND) %>% count())
      
      sae_acs_data
  }
  
  # Iterate through all states
  acs_estimates <- unique(sae_estimates$state) %>%
    map(join_states) %>%
    bind_rows()
  
  
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
