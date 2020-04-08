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

#set keys for the bucket
get_bucket(
  bucket = my_bucket_name,
  key = key,
  secret = secret_key
)


#upload all files in s3_final directory while maintaining folders
s3sync(files = dir("data/processed-data/s3_final", recursive = T), 
       bucket = my_bucket_name,
       direction = "upload")



