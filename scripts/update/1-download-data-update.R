# Download necessary files directly to the appopriate folder
# Small files go to data/raw-data/small/
# while larger files (>100M) go to data/raw-data/big/

#----Download Unemployment data from BLS and WA------------


update_bls_ces_data <- function(url =
                                   "https://download.bls.gov/pub/time.series/ce/ce.data.0.AllCESSeries") {
   # BLS CES Data
   # No manual update needed
   download.file(
      url = url,
      destfile = "data/raw-data/big/ces_all.txt"
   )
}

update_bls_sae_data <- function(url =
                                   "https://download.bls.gov/pub/time.series/sm/sm.data.1.AllData") {
   # BLS SAE Data
   # No manual update needed
   download.file(
      url = url,
      destfile = "data/raw-data/big/sae_all.txt"
   )
}

update_wa_ny_qcew_data <- function(zip_url =
                                      "https://data.bls.gov/cew/data/files/2019/csv/2019_qtrly_by_area.zip") {
   # (SAE does not have all industries for WA and NY)
   # Download zip file of all states
   download.file(
      url = zip_url,
      destfile = "data/raw-data/big/wa_qcew.zip"
   )
   
   # Extract NY and WA data
   unzip("data/raw-data/big/wa_qcew.zip",
         files = c("2019.q1-q3.by_area/2019.q1-q3 53000 Washington -- Statewide.csv"),
         exdir = "data/raw-data/big"
   )
   
   unzip("data/raw-data/big/wa_qcew.zip",
         files = c("2019.q1-q3.by_area/2019.q1-q3 36000 New York -- Statewide.csv"),
         exdir = "data/raw-data/big"
   )
   file.remove("data/raw-data/big/wa_qcew.zip")
   
   # Rename to more readable names
   file.rename(
      from = "data/raw-data/big/2019.q1-q3.by_area/2019.q1-q3 53000 Washington -- Statewide.csv",
      to = "data/raw-data/big/wa_qcew.csv"
   )
   file.rename(
      from = "data/raw-data/big/2019.q1-q3.by_area/2019.q1-q3 36000 New York -- Statewide.csv",
      to = "data/raw-data/big/ny_qcew.csv"
   )
   
   unlink("data/raw-data/big/2019.q1-q3.by_area", recursive = TRUE)
}

update_all_us_qcew_data <- function(url =
                                       "https://data.bls.gov/cew/data/files/2019/xls/2019_all_county_high_level.zip") {
   # Download all states data
   download.file(
      url = url,
      destfile = "data/raw-data/big/us_qcew.zip"
   )
   
   # Extract and rename all us xlsx
   unzip("data/raw-data/big/us_qcew.zip",
         files = c("allhlcn193.xlsx"),
         exdir = "data/raw-data/big"
   )
   file.remove("data/raw-data/big/us_qcew.zip")
   file.rename(
      from = "data/raw-data/big/allhlcn193.xlsx",
      to = "data/raw-data/big/us_qcew.xlsx"
   )
}
update_wa_unemp_data <- function(week_num) {
   # week_num: The week number to get unemployment data. This needs to be
   # manually increased by 1 every week. As of 06/07/20, latest week_num = 17
   
   # Download WA state unemployment estimates, most recent = week 17
   download.file(
      url = str_glue("https://esdorchardstorage.blob.core.windows.net/esdwa/Default/ESDWAGOV/labor-market-info/Libraries/Regional-reports/UI-Claims-Karen/2020 claims/UI claims week {week_num}_2020.xlsx"),
      destfile = "data/raw-data/big/UI claims week wa_most_recent.xlsx",
      # download file in binary mode, if you don't, xlsx file is corrupted
      mode = "wb"
   )
}

#----- Download all BLS data-----------
update_bls_ces_data("https://download.bls.gov/pub/time.series/ce/ce.data.0.AllCESSeries")
update_bls_sae_data("https://download.bls.gov/pub/time.series/sm/sm.data.1.AllData")
# update_wa_ny_qcew_data("https://data.bls.gov/cew/data/files/2019/csv/2019_qtrly_by_area.zip")
# update_all_us_qcew_data("https://data.bls.gov/cew/data/files/2019/xls/2019_all_county_high_level.zip")

#----- Download updated WA data-----------
# Note week_num should be set in master file and this env should have access to it
# update_wa_unemp_data(week_num_wa)