# Calculate Job loss by LODES Industry Sector using BLS data

library(tidyverse)
library(jsonlite)
library(testit)

# Parameters for start quarter from which to compare job change
start_quarter <- 3

# Read in all CES data
qcew_all <- read_csv("data/raw-data/big/wa_qcew.csv")

# Read in crosswalk from NAICS to LODES
lodes_crosswalk <- fromJSON("data/raw-data/small/naics-to-led.json")

# Subset to NAICS supersector and latest quarter
qcew_sub <- qcew_all %>%
              filter(agglvl_code == 54, 
                    qtr == 3)

# Aggregate all employment, taking last month of the quarter,
# By industry by supersector
qcew_agg <- qcew_sub %>% 
              group_by(industry_code) %>%
              summarize(total_employment = sum(month3_emplvl)) %>%
              filter(industry_code %in% names(lodes_crosswalk))
                  
# Attach LODES codes "CNS{number}" and write out
add_lodes_code <- function(industry_code){
  str_glue("CNS",lodes_crosswalk[industry_code][[1]])
}
qcew_led <- qcew_agg %>%
              mutate(lodes_var = qcew_agg$industry_code %>% map_chr(add_lodes_code))



