# Analysis of Potential Neighborhood Effects of COVID-19 and Response

Government support programs, non-profits, such as food banks, and volunteers who are working to mitigate the economic impacts of the novel Coronavirus lack evidence about which areas are hardest hit economically, in real time. If they knew which people and neighborhoods are being hit the hardest economically, they could more effectively dedicate resources - such as food, child care support, or cash assistance - to those who need it most and mitigate some of the worst economic impacts of the coronavirus.

*What*: Create an interactive map and publish data of neighborhood-level measures of workers with the potential to be hardest hit, economically, by the cancelling of events, work from home policies, and social distancing required by the Coronavirus.

## Process

This repository contains code to produce the area-level geographic and data files that will make a web application efficient and fast to respond. Data are organized at potential levels where changemakers would be interested:

- metro areas
- counties
- cities and towns (Census places).

### Required libraries

- tidyverse
- sf
- testit

### download-data.R

Downloads the relevant files to the Raw data directly, if they can be automatically downloaded. Some, such as those accessed from Geocorr, cannot be automatically gathered and therefore are manually accessed.

### produce-geo-files.R

`produce_geo_files.R` creates the geographic Census tract-level files, which contain the simplified geometries of Census tracts at the metro area, county, and city and town level. [Geocorr2018](http://mcdc.missouri.edu/applications/geocorr2018.html) is used as the baseline crosswalk to generate the list of tracts in each of these areas, where a tract is considered in the area if at least 1% of the tract, weighted by 2010 census block population, is within the larger geography's boundary.

The file also produces a metro area, county, and city and town name to Census code crosswalk, so that the web application can easily allow users to search by name but still pull files by unique code IDs, which is the naming convention by which they are stored.

### produce-data-files.R

`produce_data_files.R` creates the data files at the Census tract level using 2017 LODES data from the [Urban Institute Data Catalog](https://datacatalog.urban.org/dataset/longitudinal-employer-household-dynamics-origin-destination-employment-statistics-lodes). The file uses the all jobs category, and subtracts out jobs paying more than $40,000 per year to focus only on low- and moderate-income jobs. The file keeps only the tract ID, total number of jobs, number of jobs by industry, and jobs by race variables. The files are then stored in a similar way to the geographic files at the metro area, county, and city and town level, measured by tracts that have at least 1% of their population in the larger geographic boundary.

### transfer-to-s3.R

After files are written out and quality checked, they are stored in S3 in a publicly available bucket in the following heirarchy:

- `geo/`
  - `./cbsa/`
  - `./county/`
  - `./place/`
- `data/`
  - `./cbsa/`
  - `./county/`
  - `./place/`
  
### job-loss-by-industry.R

Data sourced from national Bureau of Labor Statistics (BLS) Current Employment Statistics (CES) national data. Because stay at home and other orders happened in a staggered fashion, and the CES reports for the pay period that includes the 12th of the previous month, the initial cut will use national statistics to show the likely impacts across the country on a relative scale. Users can start from these defaults to choose their own scenarios based on their thoughts or better data. Ideally, we update this as better data become available over time.

## Data Structure

All data can be accessed programmatically or manually, using Geocorr 2018. Data on Geocorr uses the population weighted 2010 Census block to go from Census Tract to the most recent definitions for CBSA, County, and Census Place.

- `programs/` stores the relevant programs
- `data/` stores the data
  - `./raw-data/` stores raw data.
    - `./small/` stores data that can be pushed to Github. The goal is for all manually downloaded data to be committed here, if possible.
    - `./big/` stores data that can't be pushed to Github
  - `./processed-data/` stores processed data, none of which will be written to Github

## App functionality

*Initial Thoughts*: The app will show the user two dropdowns, the second of which allows text search and select. Below that is a link that says "Hide job loss assumptions by industry" that hides a group of 20 small sliders and input text boxes on click. Below that is a map. The map displays a county-level summary of the total estimated job loss by county, based on the slider defaults. When the sliders or input boxes change, the map changes in response.

The first dropdown asks the user to choose by metro area, county, or city and town. Once selected, the following dropdown is highlighted, which allows them to search and/or select from a list the metro area, county, or city and town they want to focus on.

Once selected, a map appears. The map pans to the geography and colors all census tracts in the chosen geography by the % of job loss, based on the slider assumptions. When the sliders or input boxes change, the map changes in response.

## Caveats

* Residence Area Characteristics (RAC) data from LODES reflect the most recent year of data, which is 2017 for most tracts. 2016 data are used, however, for tracts within Alaska and South Dakota and for tracts inside counties that are bordering South Dakota. Worker Area Characteristics (WAC) data, which is an input for RAC, are not available for South Dakota and Alaska in 2017. Therefore, the  tracts inside and around these two states will have undercounts - for inside South Dakota and Alaska, the undercounted reflect people that both work and live in the state, and for outside South Dakota, the undercounted reflect people that live outside of South Dakota and work within South Dakota. 
* The CES data used can tell us something about the relative decrease in jobs by industry, but is is only recent up to the 12th of each month. Therefore, we cannot interpet CES numbers as current absolute job loss. Additionally, the relative decrease in jobs by industry may differ over time, meaning more recent data may show different results. 

  
## Contact

Contact Graham MacDonald at gmacdonald@urban.org