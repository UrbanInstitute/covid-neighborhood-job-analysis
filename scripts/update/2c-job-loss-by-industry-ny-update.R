# Calculate Job loss by LODES Industry Sector using NY state data
library(tidyverse)
library(jsonlite)
library(testit)
library(readxl)

generate_ny_percent_change_by_industry = function(start_quarter_lodes = 
    start_quarter_lodes, past_unemployment_weeks = past_unemployment_weeks,
    ny_manual_data_filapath =
    "data/raw-data/small/ny-manual-input-data.xlsx"){

        
    ##----Read in data------------------------------------------------------
    # Read in BLS CES data
    qcew_all <- read_csv("data/raw-data/big/ny_qcew.csv")

    # Read in crosswalk from NAICS supersector to LODES.
    lodes_crosswalk <- fromJSON("data/raw-data/small/naics-to-led.json")

    # Read in crosswalk from NAICS sector to LODES
    lodes_crosswalk_sector <- fromJSON("data/raw-data/small/naics-sector-to-led.json")

    # Read in industry to lodes xwalk, to put names to lodes industries
    lehd_types <- read_csv("data/raw-data/small/lehd_types.csv")


    # Above two crosswalks were constructed manually from pg 7 of
    # https://lehd.ces.census.gov/data/lodes/LODES7/LODESTechDoc7.4.pdf


    ##----Get total_employment by LODES industry code-------------------------
    # Subset to NAICS supersector and latest quarter
    qcew_sub <- qcew_all %>%
    filter(agglvl_code == 54,
            qtr == start_quarter_lodes)

    # Aggregate all employment, taking last month of the quarter,
    # By industry by supersector
    qcew_agg <- qcew_sub %>%
    group_by(industry_code) %>%
    summarize(total_employment = sum(month3_emplvl)) %>%
    filter(industry_code %in% names(lodes_crosswalk))

    # Attach LODES codes "CNS{number}" and write out
    add_lodes_code <- function(industry_code) {
    str_glue("CNS", lodes_crosswalk[industry_code][[1]])
    }
    qcew_led <- qcew_agg %>%
    mutate(lodes_var =
            qcew_agg$industry_code
            %>% map_chr(add_lodes_code))



    ## ----Get unemploygment claims by LODES industry code-----------------------
    
    # Read in weekly unemployment claims, allocate Construction/Utilities based on
    # WA split. We do this because NY doesn't report Construction/Utilities
    # Calculate WA ratio of job loss
    wa_data <- read_csv("data/processed-data/job_change_wa_most_recent.csv")
    utilities_wa <- wa_data %>%
    filter(industry_code == "22") %>%
    select(unemployment_totals) %>%
    pull()
    construction_wa <- wa_data %>%
    filter(industry_code == "23") %>%
    select(unemployment_totals) %>%
    pull()
    cu_ratio <- utilities_wa / (utilities_wa + construction_wa)

    # Add separate NY rows for constrution and utilities
    weekly_unemployment <- read_excel("data/raw-data/small/ny-manual-input-data.xlsx",
                                    sheet = "Sheet1")
    split_base <- weekly_unemployment %>%
    filter(`2 Digit NAICS` == "22, 23") %>%
    select_if(is.numeric) %>%
    unname()
    utilities_ny <- split_base %>%
    map_dbl(~ .x * cu_ratio)
    construction_ny <- split_base %>%
    map_dbl(~ .x * (1 - cu_ratio))
    weekly_unemployment <- weekly_unemployment %>%
    rbind(c(c("Utilities", "22"), utilities_ny)) %>%
    rbind(c(c("Construction", "23"), construction_ny)) %>%
    filter(`2 Digit NAICS` != "22, 23")

    add_naics_super_lodes <- function(naics) {
    str_glue("CNS", lodes_crosswalk_sector[naics][[1]])
    }
    weekly_unemployment_sub <- weekly_unemployment %>%
    mutate(lodes_var = weekly_unemployment$`2 Digit NAICS` %>%
            map_chr(add_naics_super_lodes)) %>%
    filter(lodes_var != "CNS00")
    cols <- length(colnames(weekly_unemployment_sub))
    weekly_unemployment_sub <- weekly_unemployment_sub %>%
    #only keep unemp claims from last n weeks
    select(c((cols - past_unemployment_weeks):cols)) %>%
    mutate_at(vars(-lodes_var), as.numeric)

    # Sum across rows to get total unemployment over past n weeks
    # Then summarize by LODES code
    weekly_unemployment_totals <- weekly_unemployment_sub %>%
    data.frame(unemployment = rowSums(weekly_unemployment_sub[1:past_unemployment_weeks])) %>%
    select(lodes_var, unemployment) %>%
    group_by(lodes_var) %>%
    summarize(unemployment_totals = sum(unemployment)) %>%
    left_join(lehd_types %>%
                transmute(lodes_var = toupper(lehd_var),
                            lehd_name),
                by = c("lodes_var"))


    ##----Get % change in employment by LODES industry code-----------------------
    # Note: assumes no hires, which is not true, but should generally show relative
    # job change in the short term until we get BLS CES data
    percent_change_industry <- qcew_led %>%
    left_join(weekly_unemployment_totals, by = "lodes_var") %>%
    select(lodes_var, everything()) %>%
    # merge(weekly_unemployment_totals, by = "lodes_var") %>%
    mutate(percent_change_employment = -unemployment_totals / total_employment) %>%
    arrange(lodes_var) %>%
    select(lehd_name, lodes_var, everything()) %>%
    write_csv(str_glue("data/processed-data/job_change_ny_last_{past_unemployment_weeks}_weeks.csv"))

    # Write out most recent NY job change data
    percent_change_industry %>%
    write_csv("data/processed-data/job_change_ny_most_recent.csv")

}

generate_ny_percent_change_by_industry(
    past_unemployment_weeks = past_unemployment_weeks,
    start_quarter_lodes = start_quarter_lodes
)


# ##----Read in data------------------------------------------------------
# # Read in BLS CES data
# qcew_all <- read_csv("data/raw-data/big/ny_qcew.csv")

# # Read in crosswalk from NAICS supersector to LODES.
# lodes_crosswalk <- fromJSON("data/raw-data/small/naics-to-led.json")

# # Read in crosswalk from NAICS sector to LODES
# lodes_crosswalk_sector <- fromJSON("data/raw-data/small/naics-sector-to-led.json")

# # Read in industry to lodes xwalk, to put names to lodes industries
# lehd_types <- read_csv("data/raw-data/small/lehd_types.csv")


# # Above two crosswalks were constructed manually from pg 7 of
# # https://lehd.ces.census.gov/data/lodes/LODES7/LODESTechDoc7.4.pdf


# ##----Get total_employment by LODES industry code-------------------------
# # Subset to NAICS supersector and latest quarter
# qcew_sub <- qcew_all %>%
#   filter(agglvl_code == 54,
#          qtr == start_quarter_lodes)

# # Aggregate all employment, taking last month of the quarter,
# # By industry by supersector
# qcew_agg <- qcew_sub %>%
#   group_by(industry_code) %>%
#   summarize(total_employment = sum(month3_emplvl)) %>%
#   filter(industry_code %in% names(lodes_crosswalk))

# # Attach LODES codes "CNS{number}" and write out
# add_lodes_code <- function(industry_code) {
#   str_glue("CNS", lodes_crosswalk[industry_code][[1]])
# }
# qcew_led <- qcew_agg %>%
#   mutate(lodes_var =
#            qcew_agg$industry_code
#          %>% map_chr(add_lodes_code))



# ##----Get unemploygment claims by LODES industry code-----------------------

# # Read in weekly unemployment claims, allocate Construction/Utilities based on
# # WA split
# # Calculate WA ratio of job loss
# wa_data <- read_csv("data/processed-data/job_change_wa_most_recent.csv")
# utilities_wa <- wa_data %>%
#   filter(industry_code == "22") %>%
#   select(unemployment_totals) %>%
#   pull()
# construction_wa <- wa_data %>%
#   filter(industry_code == "23") %>%
#   select(unemployment_totals) %>%
#   pull()
# cu_ratio <- utilities_wa / (utilities_wa + construction_wa)

# # Add separate NY rows for constrution and utilities
# weekly_unemployment <- read_excel("data/raw-data/small/ny-manual-input-data.xlsx",
#                                   sheet = "Sheet1")
# split_base <- weekly_unemployment %>%
#   filter(`2 Digit NAICS` == "22, 23") %>%
#   select_if(is.numeric) %>%
#   unname()
# utilities_ny <- split_base %>%
#   map_dbl(~ .x * cu_ratio)
# construction_ny <- split_base %>%
#   map_dbl(~ .x * (1 - cu_ratio))
# weekly_unemployment <- weekly_unemployment %>%
#   rbind(c(c("Utilities", "22"), utilities_ny)) %>%
#   rbind(c(c("Construction", "23"), construction_ny)) %>%
#   filter(`2 Digit NAICS` != "22, 23")

# add_naics_super_lodes <- function(naics) {
#   str_glue("CNS", lodes_crosswalk_sector[naics][[1]])
# }
# weekly_unemployment_sub <- weekly_unemployment %>%
#   mutate(lodes_var = weekly_unemployment$`2 Digit NAICS` %>%
#            map_chr(add_naics_super_lodes)) %>%
#   filter(lodes_var != "CNS00")
# cols <- length(colnames(weekly_unemployment_sub))
# weekly_unemployment_sub <- weekly_unemployment_sub %>%
#   #only keep unemp claims from last n weeks
#   select(c((cols - past_unemployment_weeks):cols)) %>%
#   mutate_at(vars(-lodes_var), as.numeric)

# # Sum across rows to get total unemployment over past n weeks
# # Then summarize by LODES code
# weekly_unemployment_totals <- weekly_unemployment_sub %>%
#   data.frame(unemployment = rowSums(weekly_unemployment_sub[1:past_unemployment_weeks])) %>%
#   select(lodes_var, unemployment) %>%
#   group_by(lodes_var) %>%
#   summarize(unemployment_totals = sum(unemployment)) %>%
#   left_join(lehd_types %>%
#               transmute(lodes_var = toupper(lehd_var),
#                         lehd_name),
#             by = c("lodes_var"))


# ##----Get % change in employment by LODES industry code-----------------------
# # Note: assumes no hires, which is not true, but should generally show relative
# # job change in the short term until we get BLS CES data
# percent_change_industry <- qcew_led %>%
#   left_join(weekly_unemployment_totals, by = "lodes_var") %>%
#   select(lodes_var, everything()) %>%
#   # merge(weekly_unemployment_totals, by = "lodes_var") %>%
#   mutate(percent_change_employment = -unemployment_totals / total_employment) %>%
#   arrange(lodes_var) %>%
#   select(lehd_name, lodes_var, everything()) %>%
#   write_csv(str_glue("data/processed-data/job_change_ny_last_{past_unemployment_weeks}_weeks.csv"))
# percent_change_industry %>%
#   write_csv("data/processed-data/job_change_ny_most_recent.csv")
