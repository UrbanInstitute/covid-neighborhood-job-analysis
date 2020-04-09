library(aws.s3)
library(tidyverse)


# read in secret keys
secret_keys <- read_csv("data/raw-data/small/secret_keys.csv")

#set keys
key <- secret_keys$`Access key ID` 
secret_key <- secret_keys$`Secret access key`

#set bucket name
my_bucket_name <- "ui-lodes-job-change-public" 


Sys.setenv("AWS_ACCESS_KEY_ID" = key,
           "AWS_SECRET_ACCESS_KEY" = secret_key,
           "AWS_DEFAULT_REGION" = "us-east-1")


s3_filepath <- "data/processed-data/s3_final/"

#put geojson file in bucket directory
put_object(file = paste0(s3_filepath, "job_loss_by_tract.geojson"), 
           object = "job_loss_by_tract.geojson",
           bucket = my_bucket_name,
           multipart = T)

#put cbsa csv in bucket directory
put_object( paste0(s3_filepath, "cbsa_job_loss.csv"), 
           "cbsa_job_loss.csv",
           my_bucket_name)

#put county csv in bucket directory
put_object(paste0(s3_filepath, "county_job_loss.csv"), 
           "county_job_loss.csv",
           my_bucket_name)

#put state geojson in bucket directory
put_object(paste0(s3_filepath, "states.geojson"), 
           "states.geojson",
           my_bucket_name)

#put cbsa geojson in bucket directory
put_object(paste0(s3_filepath, "cbsas.geojson"), 
           "cbsas.geojson",
           my_bucket_name)

#put county geojson in bucket directory
put_object(paste0(s3_filepath, "counties.geojson"), 
           "counties.geojson",
           my_bucket_name, 
           multipart = T)

#put median county summaries csv in bucket directory
put_object(paste0(s3_filepath, "median_job_loss_county.csv"),
           "median_job_loss_county.csv",
           my_bucket_name)

#put median cbsa summaries csv in bucket directory
put_object(paste0(s3_filepath, "median_job_loss_cbsa.csv"),
           "median_job_loss_cbsa.csv",
           my_bucket_name)


#list files in county directory 
county_files <- list.files(paste0(s3_filepath, "county"))

#put all files in county directory on s3
county_files %>% 
  walk(~put_object(file = paste0(s3_filepath, "county/", .), 
                   object = paste0("county/", .), 
                   bucket = my_bucket_name))

#list files in county directory 
cbsa_files <- list.files(paste0(s3_filepath, "cbsa"))


#put all files in county directory on s3
cbsa_files %>% 
  walk(~put_object(file = paste0(s3_filepath, "cbsa/", .), 
                   object = paste0("cbsa/", .), 
                   bucket = my_bucket_name))





