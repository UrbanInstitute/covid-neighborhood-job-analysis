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

## Required R libraries

- `tidyverse`
- `sf`
- `jsonlite`
- `tigris`
- `testit`
- `readxl`
- `aws.s3`
- `ipumsr`


## Directory Structure

- `scripts/` stores the relevant scripts
  - `static/`: scripts that need to be run once when the repo is cloned
  - `dynamic/`: scripts that need to be run every time the underlying employment
    data from BLS or individual states are updated. We will update the data once
    a week on Thursdays until the May BLS release, after which we will update
    the data monthly in line with BLS data updates.
  - `update-master.R`: The master R script which sets paramters, and sources all
    other scripts as needed. If you want to recreate our results, this is the
    only file you'll need to run.
- `data/` stores the data
  - `raw-data/` stores raw data.
    - `small/` stores data that can be pushed to Github. All manually compiled
      data needed to run the scripts are here
    - `big/` stores data that can't be pushed to Github, but will be downloaded in
      through the `1-download-data-*` scripts
  - `processed-data/` stores processed data which are outputted from the
    scripts, some of which will be written to Github
    - `s3_final/`: The final versions of the data that will be written to S3 and be made publicly available on
    the Urban [Data Catalog](https://datacatalog.urban.org/dataset/estimated-low-income-jobs-lost-covid-19).


## Description of Scripts

### `static/`
- **`1-download-data.R`**: Downloads Census tract, state, and CBSA data for the analysis and Census [LODES](https://lehd.ces.census.gov/data/) data aggregated to the Census tract and available on the [Urban Data
  Catalog](https://datacatalog.urban.org/dataset/longitudinal-employer-household-dynamics-origin-destination-employment-statistics-lodes)

- **`2-produce-geo-files.R`**: Produces some intermediary geographic files including geojsons of all
CBSA's tract, and counties in the US, and a tract<>CBSA crosswalk

- **`3-produce-data-files-static.R`**: Produces `lodes_joined.csv` from the Census LODES data which is listing of the number of low income workers in every tract-industry combination in the US

- **`4-transfer-to-s3-static.R`**: Transfers a few static files to S3, mostly used in the data viz

### `update/`
- **`1-download-data-update.R`**: Downloads BLS QCEW data for US, and WA state weekly unemployment data
- 
- **`1b-generate-bls-state-claims-csv-update.R`**: Generates BLS state claims
  data using manually downloaded Advanced state claims data from
  https://oui.doleta.gov/unemploy/claims.asp and the latest weeks numbers
  reported in this BLS pdf thast updated weekly. This script uses AWS Textract
  to perform OCR on the PDF tables so these output files should definitely be manually
  checked. You can skip running this script if you manually update the
  initial-claims-bls-state.csv by following  instructions in the
  Manual Update section below. 

- **`2a-job-loss-by-industry-wa-update.R`**: Uses data from the Washington State
  Employment Security Department - which provides estimates on a weekly basis of
  unemployment claims by industry supersector - to estimate the percent change
  in employment for every industry. Note that WA state data does not capture % change
  in employment, as it only includes unemployment claims, not new hires, but
  should be a decent proxy for relative job loss among industries in the short
  term. Key output of this script is `job_change_wa_most_recent.csv`. Not necessary
  for estimates using BLS CES data.
  
- **`2b-job-loss-by-industry-bls-update.R`**: Uses the national Bureau of Labor
  Statistics (BLS) Current Employment Statistics (CES) dataset to generate the
  estimated percent changes in employment per industry.  Because stay at home
  and other orders happened in a staggered fashion, and the CES reports for the
  pay period includes the 12th of the previous month, we will not be using
  this data until the May 8th BLS release.
  
- **`2c-job-loss-by-industry-ny.R`**: Uses data from the New York State Department
  of Labor, manually transcribed from PDF to `data/raw-data/small/ny-manual-input-data.xlsx`.
  Provides estimates on a weekly basis of unemployment claims by industry
  supersector, just like WA state, and estimates the percent change in employment
  for every industry. Same caveats and process as the WA state data. For how we 
  apply it, see `2z-job-loss-by-industry-combine-states.R`. Not necessary for 
  estimates using BLS CES data.
  
- **`2y-job-loss-by-industry-combine-states.R`**: Combines all states 
  unemployment claims change data (currently WA and NY) into a single, weighted 
  average industry job loss file. Not necessary for estimates using BLS CES data.
  
- **`2z-job-loss-by-industry-by-state.R`**: Generates a job loss by industry by state file using 
  the weighted average industry job loss file (BLS beginning May 8) and BLS advance weekly 
  claims data. State-industry job loss figures are based on the weighted average file, but are 
  up/downweighted by the BLS advance weekly claims data for higher accuracy within states. State 
  level totals and job loss calculations come from the BLS advance weekly claims for the previous 
  weeks, divided by the BLS QCEW data, to ensure we are using similar data as comparisons 
  across files. A ratio of job loss in the state compared to job loss as a whole
  in the industry file is applied for each state to the industry estimates to
  produce a job loss by industry by state file. States with actual job loss by
  industry data are applied as is (currently WA and NY) for updates before May 8. 
  The key output file is `state_job_change_all_states_most_recent.csv`.

- **`3-produce-data-files.R`**: Generates estimates of job loss by tract using 2017
  LODES data from the [Urban Institute Data
  Catalog](https://datacatalog.urban.org/dataset/longitudinal-employer-household-dynamics-origin-destination-employment-statistics-lodes),
  and unemployment rates by industry generated in script `2a` (initial run), `2z` 
  (subsequent updates in April) or `2b` (subsequent updates in May and beyond). 
  This file produces the main output used in the interactive data viz - 
  `job_loss_by_tract.geojson` which contains estimated job losses by industry for every
  tract in the US
       
- **`4-produce-summary-stats-update.R`**: Generates some summary stats and histograms about
  the distribution of the estimated job loss numbers by county/cbsa. These histograms are used
  to set breakpoints for the legends in our dataviz. Running this
  is completely optional and in most cases not needed - unless you plan on recreating our data viz
  
- **`5-create-sum-files-update.R`**: Summarizes `job_loss_by_tract.gejson` by CBSA, county, and whole USA. 
  The main output files are     
    - `sum_job_loss_county.geojson (& csv)`: Estimated job losses by industry for every
      county in the US
    - `sum_job_loss_cbsa.geojson (& csv)`: Estimated job losses by industry for every
      CBSA in the US
    - `sum_job_loss_us.geojson (& csv)`: Estimated job losses by industry for the entire
      United States
  There are two fields in these files called max, and tmax that are based on the breakpoints determined
  after script 4. Unless you are planning on recreating our data viz, you can safely
  ignore these columns
  
- **`6-transfer-to-s3.R`**: After files are written out and quality checked,
  this script transfers them to S3 in a publicly available bucket. Running this
  is completely optional and in most cases not needed.
  

## Manual Data Updates
Because the New York State data and BLS state-level advanced claims are released
in PDF format, we use a manual process to update those files, as follows:

  1) Download the most recent NY state data from
     https://labor.ny.gov/stats/weekly-ui-claims-report.shtm and add the 
     current week of data as a new column to the sheet in 
     `data/raw-data/small/ny-manual-input-data.xlsx.`

  If you don't run script 1b and/or don't have an AWS account to use Textract,
  you need to perform these additional manual updates:
  
  2) Download the most recent BLS state-level advance claims data from
     https://oui.doleta.gov/unemploy/claims.asp. On the page, select State >
     2020-2021 > Spreadsheet > Submit. Once the Excel sheet downloads, open it,
     and filter to the latest week in the `Filed week ended` column. The values in
     the `Initial Claims` column are going to be a little different form the
     values in `data/raw-data/small/initial-claims-bls-state.csv` as the BLS
     updates the previous weeks numbers. You need to replace the old values in
     `initial-claims-bls-state.csv` with the updated values from the 
     `Initial Claims`  column of the downloaded excel sheet.

  3) Add a column to `data/raw-data/small/initial-claims-bls-state.csv` for the
     next week and manually fill in the new weeks numbers reported in this
     pdf: [https://www.dol.gov/ui/data.pdf/](https://www.dol.gov/ui/data.pdf/) 
     Be sure that states line up - they may be in different orders in the PDF
     and the claims data spreadsheet.

  4) IPUMS data must be manually downloaded from the [IPUMS USA website](https://usa.ipums.org/usa/).
     Data should be put in the `data/raw-data/big/` directory. We use 5-year 
     2014-18 ACS for this analysis.

## Caveats

For a complete list of caveats, see the technical appendix available from our
[web application](https://www.urban.org/features/where-low-income-jobs-are-being-lost-covid-19).

See [changelog.md](https://github.com/UrbanInstitute/covid-neighborhood-job-analysis/blob/master/changelog.md) for recent changes and updates.

## Contact

Contact Graham MacDonald at gmacdonald@urban.org