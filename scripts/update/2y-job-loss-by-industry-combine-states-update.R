# For pre-BLS releases with state data, combine multiple states into
# a single file

library(tidyverse)


combine_wa_ny_percent_change_by_industry <- function(
                                                     states = c("ny", "wa")) {

    # Function that combines NY and WA unemployment data, weighted by number
    # of jobs in the industries of each state
    # INPUT:
    #   states: vector of states whose data this fxn will combine

    # path where these files are stored
    path <- "data/processed-data/job_change_{.x}_most_recent.csv"

    ## ----Calculate weighted average-------------------------------------------------
    # Read in all files and calculate the weighted average job loss
    states_paths <- map_chr(states, ~ str_glue(path))
    all_files <- states_paths %>%
        map_df(~ read_csv(.))
    all_files %>%
        group_by(lehd_name, lodes_var, industry_code) %>%
        summarise(
            total_employment = sum(total_employment),
            unemployment_totals = sum(unemployment_totals)
        ) %>%
        mutate(
            percent_change_employment =
                -unemployment_totals / total_employment
        ) %>%
        arrange(lodes_var) %>%
        # Write out weighted file
        write_csv("data/processed-data/job_change_all_states_most_recent.csv")
}

combine_wa_ny_percent_change_by_industry()

