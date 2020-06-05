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

Note: Starting from 6/5/2020, we are using a new methodology to calculate job loss based on national BLS CES and SAE data, instead of QCEW data and individual state data. To see the scripts and data used in the old methodology, you van view the previous commits on the master branch

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
- **`1-download-data.R`**: Downloads Census tract, states, PUMA, and CBSA data for the analysis and Census [LODES](https://lehd.ces.census.gov/data/) data aggregated to the Census tract and available on the [Urban Data
  Catalog](https://datacatalog.urban.org/dataset/longitudinal-employer-household-dynamics-origin-destination-employment-statistics-lodes)

- **`2-produce-geo-files.R`**: Produces some intermediary geographic files including geojsons of all
CBSA's tract, and counties in the US, a tract<>CBSA crosswalk, and a tract<>PUMA crosswalk

- **`3-produce-data-files-static.R`**: Produces `lodes_joined.csv` from the Census LODES data which is listing of the number of low income workers in every tract-industry combination in the US

- **`4-transfer-to-s3-static.R`**: Transfers a few static files to S3, mostly used in the data viz

### `update/`
- **`1-download-data-update.R`**: Downloads current BLS CES and SAE data.

- **`2v4a-job-loss-projected-forward-ces.R`**: Uses BLS CES data from the latest month,
  and for subsectors that are one month lagged, projects them forward using the change
  from their parent sectors.

- **`2v4b-job-loss-by-industry-ces-sae-ipums-update.R`**: Uses BLS SAE data and CES data
  to project lagged state employment data forward one month, and uses the relationship
  between previous month SAE to CES supersector data to project national level industry
  job loss estimates down to the state level.

- **`2v4c-job-loss-by-industry-ipums-update.R`**: Uses the CES to ACS crosswalk generated
  manually here at Urban to summarize state by detailed CES industry calculations to state
  by detailed ACS industry calculations. Crosswalk documentation and code may be found
  here: https://github.com/UrbanInstitute/ipums-acs-naics-standardization. 

- **`2v4d-job-loss-by-industry-ipums-summary-update.R`**: Uses the state by detailed ACS
  industry job loss estimates and merges with the most recent 5 year ACS (2014-18) microdata
  from IPUMS USA to produce a microdata file that allows people to join with the ACS IPUMS
  file and produce their own estimates. Also produces PUMA by 2-digit NAICS job loss estimates
  for use in step 3.

- **`3-produce-data-files.R`**: Generates estimates of job loss by tract using 2017
  LODES data from the [Urban Institute Data
  Catalog](https://datacatalog.urban.org/dataset/longitudinal-employer-household-dynamics-origin-destination-employment-statistics-lodes),
  and job loss per PUMA files generated with the scripts in step 2. This file produces
  the main output used in the interactive data viz - 
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
  
## Caveats

For a complete list of caveats, see the technical appendix available from our
[web application](https://www.urban.org/features/where-low-income-jobs-are-being-lost-covid-19).

See [changelog.md](https://github.com/UrbanInstitute/covid-neighborhood-job-analysis/blob/master/changelog.md) for recent changes and updates.

## IPUMS USA Citation

```
Steven Ruggles, Sarah Flood, Ronald Goeken, Josiah Grover, Erin Meyer, Jose Pacas and Matthew Sobek. IPUMS USA: Version 10.0 [dataset]. Minneapolis, MN: IPUMS, 2020. https://doi.org/10.18128/D010.V10.0
```

## Contact

Contact Graham MacDonald at gmacdonald@urban.org