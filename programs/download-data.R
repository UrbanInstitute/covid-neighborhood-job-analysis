# Download necessary files directly to the appopriate folder
# Small files go to data/raw-data/small/
# while larger files (>100M) go to data/raw-data/big/
library(tidyverse)
library(jsonlite)

# Census tract and county geographic files
# Tracts simplify to 1:500k, Counties to 1:5m
# Census tract (2010)

#Create output direcotry to place big raw-data in.
dir.create("data/raw-data/big", showWarnings = FALSE)

download_by_state <- function(state) {
  download.file(url = str_glue("https://www2.census.gov/geo/tiger/GENZ2018/shp/cb_2018_{state}_tract_500k.zip"),
                destfile = str_glue("data/raw-data/big/{state}.zip"))
  unzip(zipfile = str_glue("data/raw-data/big/{state}.zip"),
        exdir = "data/raw-data/big")
  file.remove(str_glue("data/raw-data/big/{state}.zip"))
}
state_fips <- fromJSON("https://api.census.gov/data/2010/dec/sf1?get=NAME&for=state:*")
state_fips <- state_fips[, 2][c(2:length(state_fips[, 2]))]
dl <- state_fips %>% map(download_by_state)

# LODES data from the Urban Institute Data Catalog
# All jobs, RAC
download.file(url = "https://ui-spark-data-public.s3.amazonaws.com/lodes/summarized-files/Tract_level/all_jobs_excluding_fed_jobs/rac_all_tract_level.csv",
              destfile = "data/raw-data/big/rac_all.csv")

# All jobs, RAC, >=$40,000 per year
download.file(url = "https://urban-data-catalog.s3.amazonaws.com/drupal-root-live/2020/03/30/rac_se03_tract.csv",
              destfile = "data/raw-data/big/rac_se03.csv")

# BLS CES Data
download.file(url = "https://download.bls.gov/pub/time.series/ce/ce.data.0.AllCESSeries",
              destfile = "data/raw-data/big/ces_all.txt")

# BLS QCEW Data for Washington (SAE does not have all industries for WA)
download.file(url = "https://data.bls.gov/cew/data/files/2019/csv/2019_qtrly_by_area.zip",
              destfile = "data/raw-data/big/wa_qcew.zip")
unzip("data/raw-data/big/wa_qcew.zip",
      files = c("2019.q1-q3.by_area/2019.q1-q3 53000 Washington -- Statewide.csv"),
      exdir = "data/raw-data/big")
file.remove("data/raw-data/big/wa_qcew.zip")

file.rename(from = "data/raw-data/big/2019.q1-q3.by_area/2019.q1-q3 53000 Washington -- Statewide.csv",
            to = "data/raw-data/big/wa_qcew.csv")
unlink("data/raw-data/big/2019.q1-q3.by_area", recursive = TRUE)

# WA state unemployment estimates, most recent
# NOTE this file gets corrupted when automatically downloaded, so I manually
# downloaded this to the small folder given its size
# download.file(url = "https://esdorchardstorage.blob.core.windows.net/esdwa/Default/ESDWAGOV/labor-market-info/Libraries/Regional-reports/UI-Claims-Karen/2020 claims/UI claims week 13_2020.xlsx",
#              destfile = "data/raw-data/big/UI claims week 13_2020.xlsx")
