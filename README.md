# Estimating Low Income Job loss due to COVID-19

This repository contains the code and data needed to estimate the number of
low-income jobs lost to COVID-19 in every tract in the US. The scripts read in
data from Census LODES, the BLS, WA state unemployment figures, and other data
sources to estimate the number of jobs lost in every industry for each Census
tract in the US. The output data files of this repo power Urban's interactive
[web app](https://www.urban.org/features/where-low-income-jobs-are-being-lost-covid-19) visualizing the estimated low income jobs that will be lost to
COVID-19. You can view the code for creating the web application at [this](https://github.com/UrbanInstitute/covid-jobloss-feature)
Github repo.

We hope government support programs, and non-profit service providers use the
web app and this data to more effectively dedicate resources - such as food,
child care support, or cash assistance - to those who need it most.

## Required libraries

- `tidyverse`
- `sf`
- `jsonlite`
- `tigris`
- `testit`
- `readxl`
- `aws.s3`


## Directory Structure

- `scripts/` stores the relevant scripts
- `data/` stores the data
  - `raw-data/` stores raw data.
    - `small/` stores data that can be pushed to Github. All manually compiled
      data needed to run the scripts are here
    - `big/` stores data that can't be pushed to Github, but will be downloaded in
      through `1-download-data.R`
  - `processed-data/` stores processed data, none of which will be written to Github


## Description of Scripts

- **`1-download-data.R`**: Downloads the relevant Census geographies, BLS data,
  LODES data,and WA state unemployment data to the `data/raw-data/big/` folder.
- **`2a-job-loss-by-industry-wa.R`**: Uses data from the Washington State
  Employment Security Department - which provides estimates on a weekly basis of
  unemployment claims by industry supersector - to estimate the percent change
  in employment for every industry.  We apply the relative estimates to the
  country by comparing job loss relative to NAICS sector from BLS QCEW data,
  until the May BLS CES update, which should provide a better estimate of job
  loss by industry nationally. Note that WA state data does not capture % change
  in employment, as it only includes unemployment claims, not new hires, but
  should be a decent proxy for relative job loss among industries in the short
  term. Both this script and the next script produce a similar data files, so 
  that the BLS data, when they are released in May, can be substituted for WA 
  state data
- **`2b-job-loss-by-industry-bls.R`**: Uses the national Bureau of Labor
  Statistics (BLS) Current Employment Statistics (CES) dataset to generate the
  estimated percent changes in employment per industry.  Because stay at home
  and other orders happened in a staggered fashion, and the CES reports for the
  pay period includes the 12th of the previous month, we will not be using
  this data until the May BLS release.
- **`2c-job-loss-by-industry-ny.R`**: Uses data from the New York State Department
  of Labor, manually transcribed from PDF to `data/raw-data/small/ny-manual-input-data.xlsx`.
  Provides estimates on a weekly baseis of unemployment claims by industry
  supersector, just like WA state, and estimates the percent change in employment
  for every industry. Same caveats and process as the WA state data. For how we 
  apply it, see `2z-job-loss-by-industry-combine-states.R`.
- **`2y-job-loss-by-industry-combine-states.R`**: Combines all states 
  unemployment claims change data (currently WA and NY) into a single, weighted 
  average file. We apply this weighted average to the LODES data to produce
  better estimates. Same caveats and process as WA data.
- **`2z-job-loss-by-industry-by-state.R`**: Uses the job loss by industry file
  to calculate job losses by industry by state. State level totals and job loss 
  calculations come from the BLS advance weekly claims for the previous weeks, 
  divided by the BLS QCEW data, to ensure we are using similar data as comparisons 
  across files. A ratio of job loss in the state compared to job loss as a whole
  in the industry file is applied for each state to the industry estimates to
  produce a job loss by industry by state file.
- **`3-produce-geo-files.R`**: Generates a few intermediary geographic files for use
  in analysis, including:
    - single geojson of all tracts in the US
    - a tract to cbsa crosswalk
    - a geojson of all tracts not in any cbsas
- **`4-produce-data-files.R`**: Generates estimates of job loss by tract using 2017
  LODES data from the [Urban Institute Data
  Catalog](https://datacatalog.urban.org/dataset/longitudinal-employer-household-dynamics-origin-destination-employment-statistics-lodes),
  and unemployment rates by industry generated in script `2a` (initial run), `2z` 
  (subsequent updates in April) or `2b` (subsequent updates in May and beyond). 
  This file produces the main outputs used in the interactive data viz, including:
    -  `job_loss_by_tract.geojson`: Estimated job losses by industry for every
       tract in the US
    - `sum_job_loss_county.geojson`: Estimated job losses by industry for every
      county in the US
    - `sum_job_loss_cbsa.geojson`: Estimated job losses by industry for every
      CBSA in the US
    - `sum_job_loss_us.geojson`: Estimated job losses by industry for the entire
      United States

- **`5-transfer-to-s3.R`**: After files are written out and quality checked,
  this script transfers them to S3 in a publicly available bucket. Running this
  is completely optional and in most cases not needed.
  

## Caveats

For a complete list of caveats, see the technical appendix available from our
[web application](https://www.urban.org/features/where-low-income-jobs-are-being-lost-covid-19).

## Contact

Contact Graham MacDonald at gmacdonald@urban.org