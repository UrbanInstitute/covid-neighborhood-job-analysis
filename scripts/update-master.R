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

# Set bin values for legend bins and histograms. The histogram needs to be
# manually reviewed and may need to change these values
tmax_bins <- c(100, 150, 200, 250, 675)
max_bins <- c(100, 250, 500, 750, 1000, 2000, 5000, 10000, 200000)



if (static) {
    source("scripts\\static\\1-download-data-static.R", encoding = "UTF-8")
    source("scripts\\static\\2-produce-geo-files-static.R", encoding = "UTF-8")
    source("scripts\\static\\3-produce-data-files-static.R", encoding = "UTF-8")
    if (!dryrun) {
        source("scripts\\static\\4-transfer-to-s3-static.R", encoding = "UTF-8")
    }
}
source("scripts\\update\\5-create-sum-files-update.R", encoding = "UTF-8")
if (!dryrun) {
    source("scripts\\update\\6-transfer-to-s3-update.R", encoding = "UTF-8")
}


