# Analysis of Potential Neighborhood Effects of COVID-19 and Response

Government support programs, non-profits, such as food banks, and volunteers who are working to mitigate the economic impacts of the novel Coronavirus lack evidence about which areas are hardest hit economically, in real time. If they knew which people and neighborhoods are being hit the hardest economically, they could more effectively dedicate resources - such as food, child care support, or cash assistance - to those who need it most and mitigate some of the worst economic impacts of the coronavirus.

*What*: Create an interactive map and publish data of neighborhood-level measures of workers with the potential to be hardest hit, economically, by the cancelling of events, work from home policies, and social distancing required by the Coronavirus.

## Process

This repository contains code to produce the area-level geographic and data files that will make a web application efficient and fast to respond. Data are organized at potential levels where changemakers would be interested:

- metro areas
- counties

### Required libraries

- tidyverse
- sf
- testit
- urbnmapr
- aws.s3

### download-data.R

Downloads the relevant files to the Raw data directly, if they can be automatically downloaded. Some, such as those accessed from Geocorr, cannot be automatically gathered and therefore are manually accessed.

### job-loss-by-industry-{source}.R

`source = bls`: Data sourced from national Bureau of Labor Statistics (BLS) Current Employment Statistics (CES) national data. Because stay at home and other orders happened in a staggered fashion, and the CES reports for the pay period that includes the 12th of the previous month, the initial cut will use national statistics to show the likely impacts across the country on a relative scale. 

`source = wa`: This file also sources data from the Washington State Employment Security Department, which provides estimates on a weekly basis of initial unemployment claims by industry supersector. We will use these data and apply the relative estimates to the country by comparing job loss relative to NAICS sector from BLS QCEW data, until the May BLS CES update, which should provide a better estimate of job loss by industry.

The two programs have the same two columns, `percent_change_employment` and `lodes_var`, so that the BLS data, when they are released in May, can be substituted for WA state data. Note that WA state data does not capture % change in employment, as it only includes unemployment claims, not new hires, but should be a decent proxy for relative job loss among industries in the short term.

### produce-geo-files.R and produce-data-files.R (in that order)

`produce-geo-files.R` produces the tract/county/cbsa crosswalk, creates the intermediary data needed to choose the tracts that we use 2016 data for instead of 2017 data because of data issues, and reads in the spatial tract data and collapses those tracts into one file. 

`produce_data_files.R` creates estimates of job loss by tract using 2017 LODES data from the [Urban Institute Data Catalog](https://datacatalog.urban.org/dataset/longitudinal-employer-household-dynamics-origin-destination-employment-statistics-lodes). The program uses the all jobs category, and subtracts out jobs paying more than $40,000 per year to focus only on low- and moderate-income jobs. The code multiplies the percent job loss by supersector data from `job-loss-by-industry-{source}.R` by the number of jobs in each supersector for each Census tract, and uses this to estimate the total number of jobs estimated to be lost by Census tract so far, which we call the `job_loss_index`. A geospatial, national tract level file is written out with the `job_loss_index` field as a variable. (Question: Do we normalize by total number of jobs? Shows two different things. Answer: no - do you want to?) The file also contains the estimated low-income job loss for the tract in each industry.

This program also produces a national-level summary file by CBSA and county, that calculates the low-income `job_loss_index` as a percent of low income workers and the `job_loss_index` as a percent of all workers. Bounding boxes for CBSAs and counties are also included.

### transfer-to-s3.R

After files are written out and quality checked, they are stored in S3 in a publicly available bucket.

## Data Structure

All data can be accessed programmatically or manually, using Geocorr 2018. Data on Geocorr uses the population weighted 2010 Census block to go from Census Tract to the most recent definitions for CBSA, County, and Census Place.

- `programs/` stores the relevant programs
- `data/` stores the data
  - `./raw-data/` stores raw data.
    - `./small/` stores data that can be pushed to Github. The goal is for all manually downloaded data to be committed here, if possible.
    - `./big/` stores data that can't be pushed to Github
  - `./processed-data/` stores processed data, none of which will be written to Github

## App functionality

*Second Cut*: The app will show the user two dropdowns, the second of which allows text search and select. Below that is a sentence that talks about the job loss index for that area, then below that is a map. The map displays a tract-level summary of the total estimated job loss by county, based on estimates produced from the R scripts above. 

The first dropdown asks the user to choose by metro area or county. Once selected, the following dropdown is highlighted, which allows them to search and/or select from a list the metro area or county they want to focus on.

Once selected, the map zooms to that location. The map is likely produced in Mapbox and shows census tracts in the chosen geography by the job loss index. Above the map, the app will show the proportion of low-income jobs that were lost in the chosen geography over the total number of low-income jobs.

## Caveats

* Residence Area Characteristics (RAC) data from LODES reflect the most recent year of data, which is 2017 for most tracts. 2016 data are used, however, for tracts within Alaska and South Dakota and for tracts inside counties that are bordering South Dakota. Worker Area Characteristics (WAC) data, which is an input for RAC, are not available for South Dakota and Alaska in 2017. Therefore, the  tracts inside and around these two states will have undercounts - for inside South Dakota and Alaska, the undercounted reflect people that both work and live in the state, and for outside South Dakota, the undercounted reflect people that live outside of South Dakota and work within South Dakota. 

* Because data are not available related to the number of low-income job losses, we estimate low-income job loss based off of the rate of job loss in Washington State, or, when available, the rate of job loss at the national level. These are estimates and will be different insofar as the rate of job loss varies within industries among different income levels. 
  
## Contact

Contact Graham MacDonald at gmacdonald@urban.org