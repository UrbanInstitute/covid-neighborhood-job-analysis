# Transfer necesssary files from local computer to S3
library(aws.s3)
library(tidyverse)

#----AWS Setup--------------------------------------

# read in AWS secret keys
secret_keys <- read_csv("data/raw-data/small/secret_keys.csv")

# set keys
key <- secret_keys$`Access key ID` 
secret_key <- secret_keys$`Secret access key`

# set bucket name
my_bucket_name <- "ui-lodes-job-change-public" 


Sys.setenv("AWS_ACCESS_KEY_ID" = key,
           "AWS_SECRET_ACCESS_KEY" = secret_key,
           "AWS_DEFAULT_REGION" = "us-east-1")


s3_filepath <- "data/processed-data/s3_final/"

#----Transfer Files----------------------------------

# put tract job loss file in root directory
put_object(file = paste0(s3_filepath, "job_loss_by_tract.geojson"), 
           object = "job_loss_by_tract.geojson",
           bucket = my_bucket_name,
           multipart = F)

# put sum county summaries geojson in root directory
put_object(paste0(s3_filepath, "sum_job_loss_county.geojson"),
           "sum_job_loss_county.geojson",
           my_bucket_name)

# put sum cbsa summaries geojson in root directory
put_object(paste0(s3_filepath, "sum_job_loss_cbsa.geojson"),
           "sum_job_loss_cbsa.geojson",
           my_bucket_name)


# put sum county summaries csv in root directory
put_object(paste0(s3_filepath, "sum_job_loss_county.csv"),
           "sum_job_loss_county.csv",
           my_bucket_name)

# put sum cbsa summaries csv in root directory
put_object(paste0(s3_filepath, "sum_job_loss_cbsa.csv"),
           "sum_job_loss_cbsa.csv",
           my_bucket_name)

# put sum USA summaries csv in root directory
put_object(file = paste0(s3_filepath, "sum_job_loss_us.csv"),
           "sum_job_loss_us.csv",
           my_bucket_name)

