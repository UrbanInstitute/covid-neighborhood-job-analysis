library(tidyverse)
library(sf)
library(testit)

# Set Params -------------------------------------------------

# Set static=TRUE if its your first time running the scripts, FALSE otherwise.
# This runs the scripts located in the sctips/static folder
static <- FALSE

# set dryrun = FALSE if you want to upload files to S3. Most users can safely
# set dryrun = TRUE
dryrun <- FALSE

# Are we using the BLS data for job loss calculation? Set to TRUE after
# 2020-05-08. If FALSE, use WA/NY weighted data for job loss calculations
is_bls <- TRUE

# Number of past weeks of unemployment data to use for WA, NY AND BLS
past_unemployment_weeks <- 6

# Set bin values for legend bins and histograms. The histogram needs to be
# manually reviewd and may need to change these values
tmax_bins <- c(100, 150, 200, 250, 800)
max_bins <- c(100, 250, 500, 750, 1000, 2000, 5000, 10000, 250000)


### Below params are only for NY/WA data
# Week number for downloading WA data. Latest week as of 2020-05-07 is 17
week_num_wa <- 16

# LODES quarter from which to start % change in employment
start_quarter_lodes <- 3


if (static) {
    source("scripts\\static\\1-download-data-static.R", encoding = "UTF-8")
    source("scripts\\static\\2-produce-geo-files-static.R", encoding = "UTF-8")
    source("scripts\\static\\3-produce-data-files-static.R", encoding = "UTF-8")
    if (!dryrun) {
        source("scripts\\static\\4-transfer-to-s3-static.R", encoding = "UTF-8")
    }
}

source("scripts\\update\\1-download-data-update.R", encoding = "UTF-8")
source("scripts\\update\\1b-generate-bls-state-claims-csv-update.R", encoding = "UTF-8")
source("scripts\\update\\2a-job-loss-by-industry-wa-update.R", encoding = "UTF-8")
source("scripts\\update\\2b-job-loss-by-industry-bls-update.R", encoding = "UTF-8")
source("scripts\\update\\2c-job-loss-by-industry-ny-update.R", encoding = "UTF-8")
source("scripts\\update\\2y-job-loss-by-industry-combine-states-update.R", encoding = "UTF-8")
source("scripts\\update\\2z-job-loss-by-industry-by-state-update.R", encoding = "UTF-8")
source("scripts\\update\\3-produce-data-files-update.R", encoding = "UTF-8")
source("scripts\\update\\4-produce-summary-stats-update.R", encoding = "UTF-8")

# stop because you need to review the histograms and confirm legend bounds
stop()
source("scripts\\update\\5-create-sum-files-update.R", encoding = "UTF-8")
if (!dryrun) {
    source("scripts\\update\\6-transfer-to-s3-update.R", encoding = "UTF-8")
}