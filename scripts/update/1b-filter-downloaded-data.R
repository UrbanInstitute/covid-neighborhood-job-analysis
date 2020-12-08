library(tidyverse)

all_ces <- read_tsv("data/raw-data/big/ces_all.txt")

all_sae <- read_tsv("data/raw-data/big/sae_all.txt")




# Recreate November numbers

ids_in_cur_month <- all_ces %>%
    filter(year == 2020) %>%
    filter(period == "M11") %>%
    pull(series_id)


all_ces_m10 <- all_ces %>%
    filter(year == 2020, period == "M08") %>%
    filter(series_id %in% ids_in_cur_month)

all_ces_modified <- all_ces %>%
    filter(year == 2020) %>%
    filter(!period %in% c("M11", "M10", "M09", "M08")) %>%
    bind_rows(all_ces_m10)



all_sae_m10 <- all_sae %>%
    filter(year == 2020, period == "M08") %>%
    filter(series_id %in% ids_in_cur_month)

all_sae_modified <- all_sae %>%
    filter(year == 2020) %>%
    filter(!period %in% c("M11", "M10", "M09", "M08")) %>%
    bind_rows(all_ces_m10)





# Overwrite ces and sae files with filtered data
all_ces_modified %>% write_delim("data/raw-data/big/ces_all.txt", delim = "\t")
all_sae_modified %>% write_delim("data/raw-data/big/sae_all.txt", delim = "\t")


all_ces %>%
    filter(year == 2020) %>%
    count(period)