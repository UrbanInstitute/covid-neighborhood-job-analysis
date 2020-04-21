# For pre-BLS releases with state data, combine multiple states into
# a single file

library(tidyverse)

##----Set Parameters----------------------------------------------------
# states: filenames of state unemployment data from 2[letter here]
# programs to combine
# path: path where these files are stored
states <- c("ny", "wa")
path <- "data/processed-data/job_change_{.x}_most_recent.csv"

##----Calculate average-------------------------------------------------
# Read in all files and calculate the weighted average job loss
states_paths <- map_chr(states, ~ str_glue(path))
all_files <-  states_paths %>%
  map_df(~read_csv(.))
all_files %>%
  group_by(lehd_name, lodes_var, industry_code) %>%
  summarise(total_employment = sum(total_employment),
            unemployment_totals = sum(unemployment_totals)) %>%
  mutate(percent_change_employment =
           -unemployment_totals / total_employment) %>%
  arrange(lodes_var) %>%
  write_csv("data/processed-data/job_change_all_states_most_recent.csv")
