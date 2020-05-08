# Calculate Job loss by LODES Industry Sector using BLS data
# Start running after May 8th instead of scripts 2a and 2c


library(tidyverse)
library(jsonlite)
library(testit)


generate_bls_percent_change_by_industry = function(start_month_bls = 2,
    start_year_bls = 2020, ces_filepath = "data/raw-data/big/ces_all.txt",
    naics_lodes_xwalk_filepath = "data/raw-data/small/ces-to-naics.json"){

  # Function to generate bls percent change job loss by industry
  # INPUT:
  #   start_month_bls: BLS month to use as baseline to measure job loss % change
  #   start_year_bls: BLS year to use as baseline to measrue job loss % change
  #   ces_filepath: Filepath to ces_all.txt file downloaded in by
  #     1-download-data-update.R
  #   naics_lodes_xwalk_filepath: Filepath to manually compiled crosswalk of
  #     ces industry codes to naices industry codes
  # OUTPUT:
  # job_change_led: a 20 row dataframe, where every row is a national is a CES
  #   industry. This dataframe is the measure % change in net employment for 
  #   each of these 20 industries in relation to the start month and yet


  # Read in CES and crosswalk data
  lodes_crosswalk <- fromJSON(naics_lodes_xwalk_filepath)
  ces_all <- read_tsv(ces_filepath)

  ##----Generate % Change in employment-----------------------------------

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
  ces_series_latest <- ces_series_subset_m %>%
                        filter(year == max(year)) %>%
                        filter(month == max(month))
  latest_month <- max(ces_series_latest$month)
  latest_year <- max(ces_series_latest$year)
  # Reference month
  ces_series_reference <- ces_series_subset_m %>%
                            filter(year == start_year_bls) %>%
                            filter(month == start_month_bls) 

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
