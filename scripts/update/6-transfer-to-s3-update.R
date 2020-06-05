# Transfer necesssary files from local computer to S3
library(aws.s3)
library(tidyverse)

transfer_all_files_to_s3 <- function(
                                     my_bucket_name = "ui-lodes-job-change-public") {
    #----AWS Setup--------------------------------------

    # Read in AWS secret keys
    secret_keys <- read_csv("data/raw-data/small/secret_keys.csv")

    # Set keys
    key <- secret_keys$`Access key ID`
    secret_key <- secret_keys$`Secret access key`

    Sys.setenv(
        "AWS_ACCESS_KEY_ID" = key,
        "AWS_SECRET_ACCESS_KEY" = secret_key,
        "AWS_DEFAULT_REGION" = "us-east-1"
    )

    s3_filepath <- "data/processed-data/s3_final/"

    #----Transfer Files----------------------------------

    # put tract job loss geojson in root directory
    put_object(
        file = paste0(s3_filepath, "job_loss_by_tract.geojson"),
        object = "job_loss_by_tract.geojson",
        bucket = my_bucket_name,
        multipart = F
    )

    # put sum county summaries geojson in root directory
    put_object(
        paste0(s3_filepath, "sum_job_loss_county.geojson"),
        "sum_job_loss_county.geojson",
        my_bucket_name
    )

    # put sum cbsa summaries geojson in root directory
    put_object(
        paste0(s3_filepath, "sum_job_loss_cbsa.geojson"),
        "sum_job_loss_cbsa.geojson",
        my_bucket_name
    )

    # put tract job loss csv in root directory
    put_object(
        file = paste0(s3_filepath, "job_loss_by_tract.csv"),
        object = "job_loss_by_tract.csv",
        bucket = my_bucket_name,
        multipart = F
    )


    # put sum county summaries csv in root directory
    put_object(
        paste0(s3_filepath, "sum_job_loss_county.csv"),
        "sum_job_loss_county.csv",
        my_bucket_name
    )

    # put sum cbsa summaries csv in root directory
    put_object(
        paste0(s3_filepath, "sum_job_loss_cbsa.csv"),
        "sum_job_loss_cbsa.csv",
        my_bucket_name
    )

    # put sum USA summaries csv in root directory
    put_object(
        file = paste0(s3_filepath, "sum_job_loss_us.csv"),
        "sum_job_loss_us.csv",
        my_bucket_name
    )

    # put reshaped jsons in root directory
    put_object(
        file = paste0(s3_filepath, "sum_job_loss_county_reshaped.json"),
        "reshaped/sum_job_loss_county_reshaped.json",
        my_bucket_name
    )

    put_object(
        file = paste0(s3_filepath, "sum_job_loss_cbsa_reshaped.json"),
        "reshaped/sum_job_loss_cbsa_reshaped.json",
        my_bucket_name
    )

    put_object(
        file = paste0(s3_filepath, "sum_job_loss_us.json"),
        "reshaped/sum_job_loss_us.json",
        my_bucket_name
    )
    
    # put IPUMS disemployment file in root directory
    put_object(
        file = paste0("data/processed-data/ipums/ipums_2014_18_disemployment_most_recent.csv"),
        "ipums_2014_18_disemployment_most_recent.csv",
        my_bucket_name
    )
    
    
}

transfer_all_files_to_s3()
