# Calculate Job loss by LODES Industry Sector using BLS/WA state data

library(tidyverse)
library(jsonlite)
library(testit)
library(readxl)


generate_wa_percent_change_by_industry = function(
	past_unemployment_weeks = past_unemployment_weeks,  
	start_quarter_lodes = start_quarter_lodes, 
	wa_unemp_filepath = "data/raw-data/big/UI claims week wa_most_recent.xlsx",
    qcew_all_filpeath = "data/raw-data/big/wa_qcew.csv",
    naics_led_filepath = "data/raw-data/small/naics-to-led.json",
    naics_sector_led_filepath = "data/raw-data/small/naics-sector-to-led.json",
    lehd_types_filepath = "data/raw-data/small/lehd_types.csv"){

    # Function that genrates job loss % change by industry based on WA
    # unemployment data.
    # INPUT
    # 	past_unemployment_weeks: # of past unemployment weeks to use for job loss
    # 		% calculation
    #   start_quarter_lodes: baseline odes quarter from which to start job loss
    #     comparison
    #   wa_unemp_filepath: Filepath to most recent WA unemployment data
    #   qcew_all_filpeath: Filepath to most recent qcew_all data
    #   naics_setor_filepath: filepath to naics<>lodes indsutry code xwalk
    #   naics_sector_led_filepath: filepath to naics sector<>lodes indsutry code xwalk
    #   lehd_types_filepath: filepath to lodes industry<>human readable industry


    ##----Read in data------------------------------------------------------
    # Read in BLS CES data
    qcew_all <- read_csv(qcew_all_filpeath)

    # Read in crosswalk from NAICS supersector to LODES.
    lodes_crosswalk <- fromJSON(naics_led_filepath)

    # Read in crosswalk from NAICS sector to LODES
    lodes_crosswalk_sector <- fromJSON(naics_sector_led_filepath)

    # Read in industry to lodes xwalk, to put names to lodes industries
    lehd_types <- read_csv(lehd_types_filepath)


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
    add_lodes_code <- function(industry_code){
      str_glue("CNS",lodes_crosswalk[industry_code][[1]])
    }
    qcew_led <- qcew_agg %>%
                  mutate(lodes_var = qcew_agg$industry_code %>% map_chr(add_lodes_code))



    ##----Get unemploygment claims by LODES industry code-----------------------

    # Read in weekly unemployment claims, drop all columns except the first 2
    # and the last `n` that are not null
    not_all_na <- function(var){
      any(!is.na(var))
    }
    add_naics_super_lodes <- function(naics){
      str_glue("CNS",lodes_crosswalk_sector[naics][[1]])
    }
    weekly_unemployment <- read_excel(wa_unemp_filepath,
                                      sheet = "2DigitNAICS_ICs ",
                                      skip = 3)
    weekly_unemployment_sub <- weekly_unemployment %>%
                            mutate(lodes_var = weekly_unemployment$`2 Digit NAICS` %>% map_chr(add_naics_super_lodes)) %>%
                            filter(lodes_var != "CNS00") %>%
                            select_if(not_all_na)
    cols <- length(colnames(weekly_unemployment_sub))
    weekly_unemployment_sub <- weekly_unemployment_sub %>%
                            #only keep unemp claims from last n weeks
                            select(c((cols-past_unemployment_weeks):cols))

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
                                write_csv(str_glue("data/processed-data/job_change_wa_last_{past_unemployment_weeks}_weeks.csv"))
    
    ##-----Write out WA % job change data-------
    percent_change_industry %>% 
      write_csv("data/processed-data/job_change_wa_most_recent.csv")
}

generate_wa_percent_change_by_industry(
    past_unemployment_weeks = past_unemployment_weeks,
	start_quarter_lodes = start_quarter_lodes
)



# ##----Set Parameters----------------------------------------------------
# # start_quarter_lodes: quarter from which to compare job change and
# # past_unemp_weeks: # of past weeks of unemployment data to use
# # filename: filename of WA unemployment data (downloaded from 
# #           download-data.R)
# start_quarter_lodes <- 3
# # Need to increment by 1 after each week
# past_unemployment_weeks <- 6

# #should update every week
# filename <- "UI claims week wa_most_recent.xlsx"


# ##----Read in data------------------------------------------------------
# # Read in BLS CES data
# qcew_all <- read_csv("data/raw-data/big/wa_qcew.csv")

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
#               filter(agglvl_code == 54, 
#                     qtr == start_quarter_lodes)

# # Aggregate all employment, taking last month of the quarter,
# # By industry by supersector
# qcew_agg <- qcew_sub %>% 
#               group_by(industry_code) %>%
#               summarize(total_employment = sum(month3_emplvl)) %>%
#               filter(industry_code %in% names(lodes_crosswalk))
                  
# # Attach LODES codes "CNS{number}" and write out
# add_lodes_code <- function(industry_code){
#   str_glue("CNS",lodes_crosswalk[industry_code][[1]])
# }
# qcew_led <- qcew_agg %>%
#               mutate(lodes_var = qcew_agg$industry_code %>% map_chr(add_lodes_code))



# ##----Get unemploygment claims by LODES industry code-----------------------

# # Read in weekly unemployment claims, drop all columns except the first 2
# # and the last `n` that are not null
# not_all_na <- function(var){
#   any(!is.na(var))
# }
# add_naics_super_lodes <- function(naics){
#   str_glue("CNS",lodes_crosswalk_sector[naics][[1]])
# }
# weekly_unemployment <- read_excel(str_glue("data/raw-data/big/{filename}"),
#                                   sheet = "2DigitNAICS_ICs ",
#                                   skip = 3)
# weekly_unemployment_sub <- weekly_unemployment %>%
#                         mutate(lodes_var = weekly_unemployment$`2 Digit NAICS` %>% map_chr(add_naics_super_lodes)) %>%
#                         filter(lodes_var != "CNS00") %>%
#                         select_if(not_all_na)
# cols <- length(colnames(weekly_unemployment_sub))
# weekly_unemployment_sub <- weekly_unemployment_sub %>%
#                         #only keep unemp claims from last n weeks
#                         select(c((cols-past_unemployment_weeks):cols))

# # Sum across rows to get total unemployment over past n weeks
# # Then summarize by LODES code
# weekly_unemployment_totals <- weekly_unemployment_sub %>%
#                                 data.frame(unemployment = rowSums(weekly_unemployment_sub[1:past_unemployment_weeks])) %>%
#                                 select(lodes_var, unemployment) %>%
#                                 # AN: Any reasom you're selecting by index rather than by 
#                                 # select(c((past_unemployment_weeks+1):(past_unemployment_weeks+2))) %>%
#                                 group_by(lodes_var) %>%
#                                 summarize(unemployment_totals = sum(unemployment)) %>% 
#                                 left_join(lehd_types %>%
#                                             transmute(lodes_var = toupper(lehd_var),
#                                                       lehd_name), 
#                                           by = c("lodes_var"))


# ##----Get % change in employment by LODES industry code-----------------------
# # Note: assumes no hires, which is not true, but should generally show relative
# # job change in the short term until we get BLS CES data
# percent_change_industry <- qcew_led %>%
#                             left_join(weekly_unemployment_totals, by = "lodes_var") %>%
#                             select(lodes_var, everything()) %>% 
#                           # merge(weekly_unemployment_totals, by = "lodes_var") %>%
#                             mutate(percent_change_employment = -unemployment_totals / total_employment) %>%
#                             arrange(lodes_var) %>%
#                             select(lehd_name, lodes_var, everything()) %>% 
#                             write_csv(str_glue("data/processed-data/job_change_wa_last_{past_unemployment_weeks}_weeks.csv"))
# percent_change_industry %>% 
#   write_csv("data/processed-data/job_change_wa_most_recent.csv")
