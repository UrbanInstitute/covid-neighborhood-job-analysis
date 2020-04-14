library(tidyverse)
library(sf)
library(urbnthemes)
set_urbn_defaults()

job_loss <-  st_read("data/processed-data/s3_final/job_loss_by_tract.geojson")

job_loss_long <- job_loss %>%
  janitor::clean_names() %>% 
  st_drop_geometry() %>%
  pivot_longer(cols = x01:x20, 
               names_to= "job_type", 
               job_losss_to = "job_loss")

job_loss_long %>% 
  select(job_type, 
         job_loss) %>% 
  group_by(job_type) %>% 
  summarize(min = min(job_loss, na.rm =T),
            quartile_0.25 = quantile(job_loss,0.25, na.rm =T),
            mean = mean (job_loss, na.rm =T), 
            median = median(job_loss, na.rm =T),
            quantile_0.75 = quantile(job_loss, 0.75, na.rm =T),
            max = max(job_loss, na.rm =T)
            )


summary(job_loss$X000)
hist(job_loss$X000)


job_loss_long %>% 
  group_by(job_type) %>%
  mutate(job_loss_cat = case_when(
    job_loss >= 0 & job_loss < 50 ~ "0-49",
    job_loss >= 50 & job_loss < 100 ~ "50-99",
    job_loss >= 100 & job_loss < 150 ~ "100-149",
    job_loss >= 150 & job_loss < 200 ~ "150-199",
    job_loss >=200 & job_loss < 250 ~ "200-249",
    job_loss >=250 ~ "250+") %>% 
    factor(levels = c("0-49", 
                      "50-99", 
                      "100-149", 
                      "150-199", 
                      "200-249", 
                      "250+"))) %>%
  count(job_loss_cat)  %>% 
  write_csv("data/processed-data/summary_by_industry.csv")


job_loss_long %>%
  filter(job_loss >= 100) %>% 
  write_csv("data/processed-data/over_100_by_industry.csv") %>% 
  ggplot() + 
  geom_histogram(mapping = aes(job_loss), bins = 1000)

  ggsave(filename = "data/processed-data/job_loss.png")
  
  
  
  
  
  #summary stats
  #run up to `county_sums` and `cbsa_sums` line in produce-data-files
  
  county_sums_long<-county_sums %>%
    janitor::clean_names() %>% 
    select(-geometry) %>% 
    pivot_longer(cols = x01:x20, 
                 names_to= "job_type", 
                 values_to = "job_loss")
  
  county_sums_long %>% 
    select(job_type, 
           job_loss) %>% 
    group_by(job_type) %>% 
    summarize(min = min(job_loss, na.rm =T),
              quartile_0.25 = quantile(job_loss,0.25, na.rm =T),
              mean = mean (job_loss, na.rm =T), 
              median = median(job_loss, na.rm =T),
              quantile_0.75 = quantile(job_loss, 0.75, na.rm =T),
              max = max(job_loss, na.rm =T)
    ) %>% 
    write_csv("data/processed-data/county_stats_of_sums.csv")
  
  #summary stats
  cbsa_sums_long<-cbsa_sums %>%
    janitor::clean_names() %>% 
    select(-geometry) %>% 
    pivot_longer(cols = x01:x20, 
                 names_to= "job_type", 
                 values_to = "job_loss")
  
  cbsa_sums_long %>% 
    select(job_type, 
           job_loss) %>% 
    group_by(job_type) %>% 
    summarize(min = min(job_loss, na.rm =T),
              quartile_0.25 = quantile(job_loss,0.25, na.rm =T),
              mean = mean (job_loss, na.rm =T), 
              median = median(job_loss, na.rm =T),
              quantile_0.75 = quantile(job_loss, 0.75, na.rm =T),
              max = max(job_loss, na.rm =T)
    ) %>% 
    write_csv("data/processed-data/cbsa_stats_of_sums.csv")
  
  
  county_sums %>% 
    add_bins(county_fips) %>%
    count(max) %>% 
    write_csv("data/processed-data/count_county_by_sum_size.csv")
  
  cbsa_sums %>% 
    add_bins(cbsa) %>% 
    count(max) %>% 
    write_csv("data/processed-data/count_cbsa_by_sum_size.csv")
  
  
  county_sums_long %>% 
    filter(job_loss > 3000) %>%
    ggplot() + 
    geom_histogram(mapping = aes(job_loss), bins = 1000) + 
    scale_x_continuous(breaks = seq(0, 120000, 10000), limits = c(0, 120000))
  
  ggsave("data/processed-data/county_sums.png")
  
  cbsa_sums_long %>% 
    filter(job_loss > 3000) %>% 
    ggplot() + 
    geom_histogram(mapping = aes(job_loss), bins = 1000) + 
    scale_x_continuous(breaks = seq(0, 160000, 10000), limits = c(0, 160000))
  
  ggsave("data/processed-data/cbsa_sums.png")  

