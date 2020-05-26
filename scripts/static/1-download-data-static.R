# Download necessary files directly to the appopriate folder
# Small files go to data/raw-data/small/
# while larger files (>100M) go to data/raw-data/big/
library(tidyverse)
library(jsonlite)
library(tigris)
library(sf)

options(
  use_tigris_cache = T,
  tigris_class = "sf"
)

# Create output directory to place big raw-data in.
dir.create("data/raw-data/big", showWarnings = FALSE)

#----Download Census tracts from Census FTP site ------------------------------

# Census tract  geographic files
# Tracts simplify to 1:500k,
# Census tract (2010)

download_by_state <- function(state) {
  # Note we use GENZ2018, or the Cartographic boundary files
  download.file(
    url = str_glue("https://www2.census.gov/geo/tiger/GENZ2018/shp/cb_2018_{state}_tract_500k.zip"),
    destfile = str_glue("data/raw-data/big/{state}.zip")
  )
  unzip(
    zipfile = str_glue("data/raw-data/big/{state}.zip"),
    exdir = "data/raw-data/big"
  )
  file.remove(str_glue("data/raw-data/big/{state}.zip"))
}
state_fips <- fromJSON("https://api.census.gov/data/2010/dec/sf1?get=NAME&for=state:*")
state_fips <- state_fips[, 2][c(2:length(state_fips[, 2]))]
dl <- state_fips %>% map(download_by_state)


#----Download LODES data-----------------------------------
# Downloaded from the Urban Institute Data Catalog

# All jobs, RAC
download.file(
  url = "https://ui-spark-data-public.s3.amazonaws.com/lodes/summarized-files/Tract_level/all_jobs_excluding_fed_jobs/rac_all_tract_level.csv",
  destfile = "data/raw-data/big/rac_all.csv"
)

# All jobs, RAC, >=$40,000 per year
download.file(
  url = "https://urban-data-catalog.s3.amazonaws.com/drupal-root-live/2020/03/30/rac_se03_tract.csv",
  destfile = "data/raw-data/big/rac_se03.csv"
)


#----Download cbsas, counties,PUMA's and states from tigris------------

# FIPS codes
download.file(
  url = "https://www2.census.gov/programs-surveys/popest/geographies/2017/all-geocodes-v2017.xlsx",
  destfile = "data/raw-data/big/fips.xlsx",
  mode = "wb"
)

my_states <- states(cb = T)
my_cbsas <- core_based_statistical_areas(cb = T)

my_counties <- counties(cb = T, year = 2018)
my_counties_no_cb <- counties(cb = F, year = 2018)

my_pumas <- reduce(
  map(state_fips, function(x) {
    pumas(
      state = x,
      year = 2018
    )
  }),
  rbind
)


# The CB (cartographic boundary files used for smoother mapping boundaries)
# version of the tracts file doesn't have the full county name. So we pull the
# non-cb version of the counteis file and left join the full county name.

my_counties <- my_counties %>%
  left_join(my_counties_no_cb %>%
    select(GEOID, NAMELSAD) %>%
    st_drop_geometry(), by = "GEOID") %>%
  select(-NAME) %>%
  rename(NAME = NAMELSAD)


clean_and_write_sf <- function(name, filepath) {
  name %>%
    st_transform(4326) %>%
    st_write(., filepath, delete_dsn = TRUE)
}

dir.create("data/processed-data/s3_final", showWarnings = FALSE)

clean_and_write_sf(my_cbsas, "data/raw-data/big/cbsas.geojson")
clean_and_write_sf(my_counties, "data/raw-data/big/counties.geojson")
clean_and_write_sf(my_states, "data/raw-data/big/states.geojson")
clean_and_write_sf(pumas, "data/raw-data/big/pumas.geojson")

# NOTE ON IPUMS: Must be manually downloaded to data/raw-data/big/ --------