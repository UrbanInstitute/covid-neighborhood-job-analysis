library(tidyverse)
library(sf)


x = st_read("C:/Users/anarayanan/Downloads/job_loss_by_tract.geojson")

y= x %>% janitor::clean_names() %>% 
  pivot_longer(cols = agriculture_forestry_fishing_and_hunting:public_administration, 
               names_to= "job_type", 
               values_to = "job_loss")

job_type_y %>% select(cbsa_name, job_loss_index, job_type, job_loss) %>% 
  group_by(job_type) %>% 
  summarize(min = min(job_loss, na.rm =T),
            quartile_0.25 = quantile(job_loss,0.25, na.rm =T),
            mean = mean (job_loss, na.rm =T), 
            median = median(job_loss, na.rm =T),
            quantile_0.75 = quantile(job_loss, 0.75, na.rm =T),
            max = max(job_loss, na.rm =T)
            )


summary(x$job_loss_index)
hist(x$job_loss_index)
