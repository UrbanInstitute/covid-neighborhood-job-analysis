library(tidyverse)
library(sf)
library(testit)


static <- FALSE
# set dryrun = FALSE if you want to upload files to S3. Most users can safely
# set dryrun = TRUE
dryrun <- FALSE


if (static) {
    source("scripts\\static\\1-download-data-static.R", encoding = "UTF-8")
    source("scripts\\static\\2-produce-geo-files-static.R", encoding = "UTF-8")
    source("scripts\\static\\3-produce-data-files-static.R", encoding = "UTF-8")
    if (!dryrun) {
        source("scripts\\static\\4-transfer-to-s3-static.R", encoding = "UTF-8")
    }
}

source("scripts\\update\\1-download-data-update.R", encoding = "UTF-8")
source("scripts\\update\\2a-job-loss-by-industry-wa-update.R", encoding = "UTF-8")
source("scripts\\update\\2b-job-loss-by-industry-bls-update.R", encoding = "UTF-8")
source("scripts\\update\\2c-job-loss-by-industry-ny-update.R", encoding = "UTF-8")
source("scripts\\update\\2y-job-loss-by-industry-combine-states-update.R", encoding = "UTF-8")
source("scripts\\update\\2z-job-loss-by-industry-by-state-update.R", encoding = "UTF-8")
source("scripts\\update\\3-produce-data-files-update.R", encoding = "UTF-8")
source("scripts\\update\\4-produce-summary-stats-update.R", encoding = "UTF-8")
# stop because you need to review the histograms and make sure the breaks make sense
stop()
source("scripts\\update\\5-create-sum-files-update.R", encoding = "UTF-8")
if (!dryrun) {
    source("scripts\\update\\6-transfer-to-s3-update.R", encoding = "UTF-8")
}