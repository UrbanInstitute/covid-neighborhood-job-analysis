# Script run just on Aug 7th as BLS ces_all.txt files was missig a few major
# Series. We append the mining/Logging and Construction Series to the full file
# after downloaing in the respective subseries file
library(tidyverse)
library(tidylog)


# Download mining/logging subseries (10a)
download.file(
  url = "https://download.bls.gov/pub/time.series/ce/ce.data.10a.MiningAndLogging.Employment",
  destfile = "data/raw-data/big/ces_01_subseries.txt"
)

# Download construction subseries (20a)
download.file(
  url = "https://download.bls.gov/pub/time.series/ce/ce.data.20a.Construction.Employment",
  destfile = "data/raw-data/big/ces_02_subseries.txt"
)


subseries_01 = read_tsv("data/raw-data/big/ces_01_subseries.txt")
subseries_02 = read_tsv("data/raw-data/big/ces_02_subseries.txt")

ces_filepath = "data/raw-data/big/ces_all.txt"

ces_all <- read_tsv(ces_filepath,
                    # sometimes headers are stripped by BLS perhaps on
                    # accident. So we specify ourselves
                    col_names = c("series_id", "year", "period", 
                                  "value", "footnote_codes"))

# There should only be one row withh an NA value for series_id (the first row
# that seemed to be cutoff). COnfirm that and drop it.
assert(ces_all %>% 
  # sOmetimes series id is NA or blank (depending on how R parses it)
  filter(is.na(series_id) | series_id == "") %>%
  nrow() == 1)

ces_all = ces_all %>% 
  filter(!is.na(series_id) & series_id != "")


ces_all_modified = ces_all %>%
  # filter out any series that start with 1 or 2
  filter(!(str_starts(series_id, "CES2") |
           str_starts(series_id, "CES2"))) %>% 
  bind_rows(subseries_01) %>% 
  bind_rows(subseries_02)

# Ensure there are no NAs in the data
assert(ces_all_modified %>% 
         filter(is.na(series_id) | series_id == "") %>%
         nrow() == 0)

# Write out
ces_all_modified %>% write_tsv("data/raw-data/big/ces_all_modified.txt")
