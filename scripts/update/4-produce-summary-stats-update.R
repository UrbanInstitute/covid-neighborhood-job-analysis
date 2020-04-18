# For producing summary stats/figures. We used this info
# to make deicisons about data viz legends and breakpoints
library(tidyverse)
library(sf)
library(urbnthemes)
set_urbn_defaults()

job_loss_dat <-  st_read("data/processed-data/s3_final/job_loss_by_tract.geojson")


job_loss_long <- job_loss_dat %>%
  st_drop_geometry() %>%
  pivot_longer(cols = X01:X20, 
               names_to= "job_type", 
               values_to = "job_loss")


create_tmax_histogram <- function(data, group, title) {
data_maxes<-data %>%
  group_by({{group}}) %>% 
  summarise(max_temp = max(job_loss)) %>% 
  filter(max_temp >= 100) %>% 
  ungroup()

data_max <- ceiling(max(data_maxes$max_temp)/50)*50 

  data_maxes %>% 
  ggplot() + 
  geom_histogram(mapping = aes(max_temp), bins = 400) + 
  scale_x_continuous(limits = c(100, data_max),
                     breaks = seq(100, data_max, 50)) + 
    labs(title = paste0(title, " with ", round(max(data_maxes$max_temp)), " max"))
}



job_loss_long %>% 
mutate(county_fips = substr(GEOID, 1, 5)) %>% 
create_tmax_histogram(group = county_fips, title = "Max of tract-level job loss at county level")

ggsave(filename = "data/processed-data/tmax_county_hist.png")

job_loss_long %>% 
create_tmax_histogram(group = cbsa, title = "Max of tract-level job loss at cbsa level")

ggsave(filename = "data/processed-data/tmax_cbsa_hist.png")


county_sums <- read_csv("data/processed-data/county_sums.csv") %>% 
  pivot_longer(cols = X01:X20, 
               names_to= "job_type", 
               values_to = "job_loss")

cbsa_sums <- read_csv("data/processed-data/cbsa_sums.csv") %>% 
  pivot_longer(cols = X01:X20, 
               names_to= "job_type", 
               values_to = "job_loss")

create_max_histogram <- function(data, title){
  max_val <- ceiling(max(data$job_loss)/10000) * 10000
  
  data %>% 
    filter(job_loss >= 3000) %>% 
    ggplot() + 
    geom_histogram(mapping= aes(job_loss), bins = 1000) + 
    scale_x_continuous(limits = c(3000, max_val),
                       breaks = seq(3000, max_val, 12000)) + 
    labs(title = paste0(title, " with ", round(max(data$job_loss)), " max"))
  
}
  
  
  county_sums %>% 
   create_max_histogram("Max of county sum level job loss")
  
   ggsave("data/processed-data/county_sums.png")
  
  
  cbsa_sums %>% 
    create_max_histogram("Max of cbsa sum level job loss")
  
   ggsave("data/processed-data/cbsas_sums.png")
  
  

