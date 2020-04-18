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


# put geojson file in root directory
put_object(file = paste0(s3_filepath, "no_cbsa_tracts.geojson"), 
           object = "no_cbsa_tracts.geojson",
           bucket = my_bucket_name,
           multipart = F)

# put state geojson in root directory
put_object(paste0("data/raw-data/big/states.geojson"), 
           "states.geojson",
           my_bucket_name)

# put lehd_types.csv on s3. This is transalation list beween
# geojson industry codes and human readable industry names
put_object("data/raw-data/small/lehd_types_s3.csv",
           "lehd_types_s3.csv",
           my_bucket_name)




