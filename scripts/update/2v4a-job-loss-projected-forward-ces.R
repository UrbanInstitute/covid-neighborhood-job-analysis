# Calculate Job loss by LODES Industry Sector using BLS data
# Start running after May 8th instead of scripts 2a and 2c


library(tidyverse)
library(testit)


generate_bls_percent_change_by_industry = function(start_month_bls = 2,
    start_year_bls = 2020, ces_filepath = "data/raw-data/big/ces_all.txt",
    acs_xwalk_filepath = "data/raw-data/small/2017-ind-ces-crosswalk.csv",
    sae_xwalk_filepath = "data/raw-data/small/ces-sae-crosswalk.csv"){

  # Function to generate bls percent change job loss by industry for detailed
  # industries, projecting forward those a month old to the current month
  # INPUT:
  #   start_month_bls: BLS month to use as baseline to measure job loss % change
  #   start_year_bls: BLS year to use as baseline to measure job loss % change
  #   ces_filepath: Filepath to ces_all.txt file downloaded in by
  #     1-download-data-update.R
  #   acs_xwalk_filepath: Filepath to crosswalk of ces industry codes to ACS 
  #   IND codes
  # OUTPUT:
  # ces_projected: a dataframe will all detailed industries by projected job
  #   loss from start month and start year to most recent month


  # Read in CES and crosswalk data
  acs_crosswalk <- read_csv(acs_xwalk_filepath)
  ces_all <- read_tsv(ces_filepath)
  
  if(!"series_id" %in% names(ces_all)){
    ces_all <- read_tsv(ces_filepath,
                        # sometimes headers are stripped by BLS perhaps on
                        # accident. So we specify ourselves
                        col_names = c("series_id", "year", "period", 
                                      "value", "footnote_codes") )
    
    
  }
  sae_xwalk <- read_csv(sae_xwalk_filepath,
                        col_types = list(col_character(),
                                         col_character(),
                                         col_character()))
  
  # Make sure there are no NA's in the CES series ids
  assert(ces_all %>% filter(is.na(series_id)) %>% nrow == 0)


  ##----Generate % Change in employment-----------------------------------

  # Add SAE series we'll need later
  sae_xwalk_series <- sae_xwalk %>%
    filter(!is.na(ces_code_2_digit)) %>%
    mutate(series_id = str_glue("CES{ces_code_2_digit}01"))
  
  # Specify only the series we are interested in:
  all_series <- unique(c(unique(acs_crosswalk$series_id),
                  unique(acs_crosswalk$parent_series_id),
                  unique(sae_xwalk_series$series_id)))

  # Subset CES data to only series we are interested in, and ensure all
  # of the values appear in the dataset
  ces_series_subset <- ces_all %>% 
                        filter(series_id %in% all_series)
  

  assert(length(unique(ces_series_subset$series_id)) == 
          length(all_series) - 1)

  # Add month variable
  ces_series_subset_m <- ces_series_subset %>%
                          mutate(month = as.numeric(gsub("M", "", period)))

  # Filter data to latest month as one dataset, month before the latest month
  # as another, and initial comparison month as another.
  # Latest month
  ces_series_latest <- ces_series_subset_m %>%
    filter(year == max(year)) %>%
    filter(month == max(month))
  latest_month <- max(ces_series_latest$month)
  latest_year <- max(ces_series_latest$year)
  # Month before
  ces_series_previous <- ces_series_subset_m %>%
    filter(year == max(year)) %>%
    filter(month == max(month) - 1)
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
  ces_series_previous <- join_prep(ces_series_previous, "previous")
  ces_series_reference <- join_prep(ces_series_reference, "reference")

  # Join data together and calculate % change
  job_change <- ces_series_reference %>%
    left_join(ces_series_latest, by = "series_id") %>%
    left_join(ces_series_previous, by = "series_id") %>%
    mutate(percent_change_employment_latest = latest / reference - 1,
           percent_change_employment_previous = previous / reference - 1)
  
  # Separate into needing parent and not needing one
  parent_list <- acs_crosswalk %>%
    filter(recency == 1) %>%
    distinct(series_id)
  no_parent_list <- acs_crosswalk %>%
    filter(recency == 0) %>%
    distinct(series_id)
  need_parent <- parent_list %>%
    left_join(job_change, by = "series_id")
  no_parent <- no_parent_list %>%
    left_join(job_change, by = "series_id") %>%
    mutate(percent_change_imputed = percent_change_employment_latest)

  # Add parent series and correct
  # AN: Left join below is hard to read, why not:
  # parents <- acs_crosswalk %>% 
  #   filter(series_id %in% (parent_list %>% pull(series_id))) %>% 
  #   distinct(series_id, parent_series_id)
  
  parents <- need_parent %>%
    left_join(acs_crosswalk %>%
                filter(recency == 1) %>%
                distinct(series_id, parent_series_id), by = "series_id") %>%
    select(series_id, parent_series_id)
  latest_parent_change <- job_change %>%
    filter(series_id %in% unique(acs_crosswalk$parent_series_id)) %>%
    select(series_id, percent_change_employment_latest, percent_change_employment_previous) %>%
    rename(parent_series_id = series_id, 
           parent_change_latest = percent_change_employment_latest,
           parent_change_previous = percent_change_employment_previous)
  assert("All parents should have change data, if not need to check ACS crosswalk",
         latest_parent_change %>% filter(is.na(parent_change_latest)) %>% nrow() == 0)
  job_change_corrected <- need_parent %>%
    left_join(parents, by = "series_id") %>%
    left_join(latest_parent_change, by = "parent_series_id") %>%
    mutate(percent_change_imputed = percent_change_employment_previous + parent_change_latest - parent_change_previous)

  # Bind together
  job_change_all_corrected <- job_change_corrected %>%
    bind_rows(no_parent) %>%
    select(series_id, reference, percent_change_employment_previous, percent_change_imputed)
  
  # Calculate all super industries to prep for next step for SAE crosswalk
  job_change_for_sae <- job_change %>%
    rename(percent_change_imputed = percent_change_employment_latest) %>%
    select(series_id, reference, percent_change_employment_previous, percent_change_imputed) %>%
    filter(series_id %in% sae_xwalk_series$series_id)
  
  ##----Write out data------------------------------------------------

  # Write out job chage csv specific to latest month and year
  job_change_all_corrected %>%
    write_csv(
      str_glue("data/processed-data/job_change_ces_imputed_{start_year_bls}_{start_month_bls}_to_{latest_year}_{latest_month}.csv")
    )

  # Replace most recent bls job change csv
  job_change_all_corrected %>%
    write_csv("data/processed-data/job_change_ces_imputed_most_recent.csv")

  # Write out job change for SAE, for specific month year and most recent
  
  job_change_for_sae %>%
    write_csv("data/processed-data/job_change_ces_for_sae_most_recent.csv")
  job_change_for_sae %>%
    write_csv(
      str_glue("data/processed-data/job_change_ces_for_sae_{start_year_bls}_{start_month_bls}_to_{latest_year}_{latest_month}.csv")
    )
  
  return(job_change_all_corrected)
}


job_change_all_corrected = generate_bls_percent_change_by_industry(
  ces_filepath = "data/raw-data/big/ces_all_modified.txt"
  )
