# Download necessary files directly to the appopriate folder
# Small files go to data/raw-data/small/
# while larger files (>100M) go to data/raw-data/big/

#----Download Unemployment data from BLS and WA------------


# BLS CES Data
# No manual update needed
download.file(url = "https://download.bls.gov/pub/time.series/ce/ce.data.0.AllCESSeries",
              destfile = "data/raw-data/big/ces_all.txt")

# BLS QCEW Data for Washington and New York
# (SAE does not have all industries for WA and NY)
# may need update to change q1-q3 to q1-q4, but not essential
download.file(url = "https://data.bls.gov/cew/data/files/2019/csv/2019_qtrly_by_area.zip",
              destfile = "data/raw-data/big/wa_qcew.zip")
unzip("data/raw-data/big/wa_qcew.zip",
      files = c("2019.q1-q3.by_area/2019.q1-q3 53000 Washington -- Statewide.csv"),
      exdir = "data/raw-data/big")

unzip("data/raw-data/big/wa_qcew.zip",
      files = c("2019.q1-q3.by_area/2019.q1-q3 36000 New York -- Statewide.csv"),
      exdir = "data/raw-data/big")
file.remove("data/raw-data/big/wa_qcew.zip")

file.rename(from = "data/raw-data/big/2019.q1-q3.by_area/2019.q1-q3 53000 Washington -- Statewide.csv",
            to = "data/raw-data/big/wa_qcew.csv")
file.rename(from = "data/raw-data/big/2019.q1-q3.by_area/2019.q1-q3 36000 New York -- Statewide.csv",
            to = "data/raw-data/big/ny_qcew.csv")

unlink("data/raw-data/big/2019.q1-q3.by_area", recursive = TRUE)

# BLS QCEW data by state

download.file(url = "https://data.bls.gov/cew/data/files/2019/xls/2019_all_county_high_level.zip",
              destfile = "data/raw-data/big/us_qcew.zip")
unzip("data/raw-data/big/us_qcew.zip",
      files = c("allhlcn193.xlsx"),
      exdir = "data/raw-data/big")
file.remove("data/raw-data/big/us_qcew.zip")
file.rename(from = "data/raw-data/big/allhlcn193.xlsx",
            to = "data/raw-data/big/us_qcew.xlsx")

# WA state unemployment estimates, most recent
# Needs manual update (increase week # by 1)
download.file(url = "https://esdorchardstorage.blob.core.windows.net/esdwa/Default/ESDWAGOV/labor-market-info/Libraries/Regional-reports/UI-Claims-Karen/2020 claims/UI claims week 14_2020.xlsx", 
              destfile = "data/raw-data/big/UI claims week 14_2020.xlsx",
              #download file in binary mode, if you don't, xlsx file is corrupted
              mode="wb")

