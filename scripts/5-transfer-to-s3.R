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
           multipart = T)

# put geojson file in root directory
put_object(file = paste0(s3_filepath, "no_cbsa_tracts.geojson"), 
           object = "no_cbsa_tracts.geojson",
           bucket = my_bucket_name,
           multipart = F)

# # put cbsa csv in bucket directory
# put_object( paste0(s3_filepath, "cbsa_job_loss.csv"), 
#            "cbsa_job_loss.csv",
#            my_bucket_name)
# 
# # put county csv in bucket directory
# put_object(paste0(s3_filepath, "county_job_loss.csv"), 
#            "county_job_loss.csv",
#            my_bucket_name)

# put state geojson in bucket directory
put_object(paste0(s3_filepath, "states.geojson"), 
           "states.geojson",
           my_bucket_name)
# 
# # put cbsa geojson in root directory
# put_object(paste0(s3_filepath, "cbsas.geojson"), 
#            "cbsas.geojson",
#            my_bucket_name)
# 
# # put county geojson in bucket directory
# put_object(paste0(s3_filepath, "counties.geojson"), 
#            "counties.geojson",
#            my_bucket_name, 
#            multipart = T)

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


# list files in county directory 
county_files <- list.files(paste0(s3_filepath, "county"))

# put all files in county directory on s3
county_files %>% 
  walk(~put_object(file = paste0(s3_filepath, "county/", .), 
                   object = paste0("county/", .), 
                   bucket = my_bucket_name))

# list files in cbsa directory 
cbsa_files <- list.files(paste0(s3_filepath, "cbsa"))


# put all files in cbsa directory on s3
cbsa_files %>% 
  walk(~put_object(file = paste0(s3_filepath, "cbsa/", .), 
                   object = paste0("cbsa/", .), 
                   bucket = my_bucket_name))

# put lehd_types.csv on s3. This is transalation list beween
# geojson industry codes and human readable industry names
put_object("data/raw-data/small/lehd_types_s3.csv",
           "lehd_types_s3.csv",
           my_bucket_name)

put_object(file = paste0(s3_filepath, "sum_job_loss_us.csv"),
           "sum_job_loss_us.csv",
           my_bucket_name)


