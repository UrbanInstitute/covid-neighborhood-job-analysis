library(aws.s3)
library(tidyverse)


# read in secret keys
secret_keys <- read_csv("data/raw-data/small/secret_keys.csv")

#set keys
key <- secret_keys$`Access key ID` 
secret_key <- secret_keys$`Secret access key`

#set bucket name
my_bucket_name <- "ui-lodes-job-change-public" 


#set keys for the bucket
get_bucket(
  bucket = my_bucket_name,
  key = key,
  secret = secret_key
)

#put geojson file in bucket directory
put_object(file = "data/processed-data/job_loss_by_tract.geojson", 
           object = "job_loss_by_tract.geojson",
           bucket = my_bucket_name,
           multipart = T)

#put cbsa csv in bucket directory
put_object("data/processed-data/cbsa_job_loss.csv", 
           "cbsa_job_loss.csv",
           my_bucket)

#put county csv in bucket directory
put_object("data/processed-data/county_job_loss.csv", 
           "county_job_loss.csv",
           my_bucket)
