# Recreate CES and SAE numbers from a given month.by filtering out more recent
# numbers. Note this won't be exactly the same as the data release from that
# point in time as BLS makes updates
library(tidyverse)

all_ces <- read_tsv("data/raw-data/big/ces_all.txt")
all_sae <- read_tsv("data/raw-data/big/sae_all.txt")



# Select month to simulate. Must be integer where 1 = Jan, 2 = Feb, etc
simulated_month <- 9

# In Month X, CES releases data up until Month X-1
data_until_month <- simulated_month -1

# Get most recent month in data, and prepend "M" to match CES periods
most_recent_month <- data_until_month %>%
    str_pad(width = 2, side = "left", pad = "0") %>%
    paste0("M", .)

# Generate vector of CES periods to filter out of data
months_to_filter_out <- data_until_month:13 %>%
    str_pad(width = 2, side = "left", pad = "0") %>%
    paste0("M", .)

# Select the IDs that appear in the current month. This should only be a small
# portion of all the IDs
ids_in_cur_month <- all_ces %>%
    # Filter out M13 data as those are annualized averages
    filter(period != "M13") %>%
    filter(year == 2020) %>%
    # pull latest month's series
    mutate(month = as.numeric(gsub("M", "", period))) %>%
    filter(month == max(month)) %>% 
    pull(series_id)


all_ces_filtered_month <- all_ces %>%
    filter(year == 2020, period == most_recent_month) %>%
    # To simulate dataset from this period, we only keep the series that would
    # have appeared in that month's release
    filter(series_id %in% ids_in_cur_month)

all_ces_modified <- all_ces %>%
    filter(year == 2020) %>%
    filter(!period %in% months_to_filter_out) %>%
    bind_rows(all_ces_filtered_month)



# Recreate the SAE from (simulated_month)

# Note: When SAE released data in month X, they actually only release data until 
# Month X-2 as there is a two month lag.  So SAE numbers published in M12 will 
# only have up until M110. Whereas for the CES, numbers published in M12 will 
# have all series up until M10 and a few series for M11. 


all_sae_modified <- all_sae %>%
    filter(year == 2020) %>%
    # M13 indicates annula averages, m12 = Dec, m11 = Nov, etc
    filter(!period %in% months_to_filter_out) 





# Overwrite ces and sae files with filtered data
all_ces_modified %>% write_delim("data/raw-data/big/ces_all.txt", delim = "\t")
all_sae_modified %>% write_delim("data/raw-data/big/sae_all.txt", delim = "\t")


# SAE should have data up until simulated_month - 1
all_sae_modified %>%
    filter(year == 2020) %>%
    count(period)

# CES should have data up until simulated_month - 1 and a few series from
# simulated_month  
all_ces_modified %>%
    filter(year == 2020) %>%
    count(period)


