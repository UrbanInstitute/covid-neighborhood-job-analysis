# Download necessary files directly to the appopriate folder
# Small files go to data/raw-data/small/
# while larger files (>100M) go to data/raw-data/big/
library(tidyverse)
library(jsonlite)

# Census tract and county geographic files
# Tracts simplify to 1:500k, Counties to 1:5m
# Census tract (2010)
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

# County (2010)
download.file(url = "https://www2.census.gov/geo/tiger/GENZ2018/shp/cb_2018_us_county_5m.zip",
              destfile = "data/raw-data/big/county.zip")
unzip(zipfile = "data/raw-data/big/county.zip",
      exdir = "data/raw-data/big")
file.remove("data/raw-data/big/county.zip")

# LODES data from the Urban Institute Data Catalog
# All jobs, RAC
download.file(url = "https://ui-spark-data-public.s3.amazonaws.com/lodes/summarized-files/Tract_level/all_jobs_excluding_fed_jobs/rac_all_tract_level.csv",
              destfile = "data/raw-data/big/rac_all.csv")

# All jobs, RAC, >=$40,000 per year
# Waiting on Vivian