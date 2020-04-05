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

### download-data.R

Downloads the relevant files to the Raw data directly, if they can be automatically downloaded. Some, such as those accessed from Geocorr, cannot be automatically gathered and therefore are manually accessed.

### produce-data-files.R

`produce_data_files.R` creates a national data file at the Census tract level using 2017 LODES data from the [Urban Institute Data Catalog](https://datacatalog.urban.org/dataset/longitudinal-employer-household-dynamics-origin-destination-employment-statistics-lodes). The file uses the all jobs category, and subtracts out jobs paying more than $40,000 per year to focus only on low- and moderate-income jobs. The file keeps only the tract ID, total number of jobs, number of jobs by industry, and jobs by race variables. 

Using the `job-loss-by-industry.R` file, the code multiplies the percent job loss by supersector by the number of jobs in each supersector fo0r each Census tract, and uses this to estimate the total number of jobs estimated to be lost by Census tract so far, which we call the `job_loss_index`. A geospatial, national tract level file is written out with the `job_loss_index` field as a variable. (Question: Do we normalize by total number of jobs? Shows two different things.)

This program also produces a national-level summary file by nation, CBSA and county, that calculates the `job_loss_index` per normalized by the number of low income workers.

### transfer-to-s3.R

After files are written out and quality checked, they are stored in S3 in a publicly available bucket.
  
### job-loss-by-industry.R

Data sourced from national Bureau of Labor Statistics (BLS) Current Employment Statistics (CES) national data. Because stay at home and other orders happened in a staggered fashion, and the CES reports for the pay period that includes the 12th of the previous month, the initial cut will use national statistics to show the likely impacts across the country on a relative scale. 

This file also sources data from the Washington State Employment Security Department, which provides estimates on a weekly basis of initial unemployment claims by industry supersector. We will use these data and apply the relative estimates to the country, until the May BLS CES update, which should provide a better estimate of job loss by industry.

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

Once selected, the map zooms to that location. The map is likely produced in Mapbox and shows census tracts in the chosen geography by the job loss index.
  
## Contact

Contact Graham MacDonald at gmacdonald@urban.org