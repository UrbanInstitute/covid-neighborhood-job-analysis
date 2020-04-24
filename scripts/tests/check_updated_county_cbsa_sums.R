library(tidyverse)
library(tigris)
library(sf)
library(daff)


clean_df <- function(df) {
    df %>%
        mutate_if(is.factor, as.character)
}

old_county_sums <- read_csv("https://ui-lodes-job-change-public.s3.amazonaws.com/sum_job_loss_county.csv")
old_cbsa_sums <- read_csv("https://ui-lodes-job-change-public.s3.amazonaws.com/sum_job_loss_cbsa.csv")
old_us_sums <- read_csv("https://ui-lodes-job-change-public.s3.amazonaws.com/sum_job_loss_us.csv")

new_county_sums <- read_csv("data/processed-data/s3_final/sum_job_loss_county.csv")
new_cbsa_sums <- read_csv("data/processed-data/s3_final/sum_job_loss_cbsa.csv")
new_us_sums <- read_csv("data/processed-data/s3_final/sum_job_loss_us.csv")

diff_county <- daff::diff_data(old_county_sums, new_county_sums)
diff_cbsa <- daff::diff_data(old_cbsa_sums, new_cbsa_sums)
diff_us <- daff::diff_data(old_us_sums, new_us_sums)

dir.create("data/processed-data/tests", showWarnings = FALSE)

write_diff(diff_county, "data/processed-data/tests/diff_county.csv")
write_diff(diff_cbsa, "data/processed-data/tests/diff_cbsa.csv")
write_diff(diff_us, "data/processed-data/tests/diff_us.csv")

render_diff(diff_cbsa)