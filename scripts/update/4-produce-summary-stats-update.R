# For producing summary stats/figures. We used this info
# to make deicisons about data viz legends and breakpoints
library(tidyverse)
library(sf)
library(urbnthemes)
library(aws.s3)
set_urbn_defaults()

generate_all_histograms = function(tmax_bins, max_bins){

    # Create output directory for summary stats
    dir.create("data/processed-data/s3_final/summary_stats", showWarnings = FALSE)

    ## Create histograms ----------------------------
    geo_file_name_raw <- "data/processed-data/s3_final/job_loss_by_tract_raw.geojson"
    job_loss_dat <- st_read(geo_file_name_raw)


    job_loss_long <- job_loss_dat %>%
    st_drop_geometry() %>%
    pivot_longer(
        cols = X01:X20,
        names_to = "job_type",
        values_to = "job_loss"
    ) %>%
    mutate(county_fips = substr(GEOID, 1, 5))


    create_tmax_histogram <- function(data, group, title) {
        lines <- tmax_bins
        lines_df <- data_frame(
            lines = lines,
            lines_chr = as.character(lines)
        )

        data_maxes <- data %>%
            group_by({{ group }}) %>%
            summarise(max_temp = max(job_loss)) %>%
            ungroup()

        # Get nice round max tick value for x axis scale
        max_tick_value <- ceiling(max(data_maxes$max_temp) / 50) * 50
        max_tick_value <- max(max_tick_value, tail(tmax_bins, n = 1))

        data_maxes %>%
            ggplot() +
            geom_histogram(mapping = aes(max_temp), bins = 200) +
            scale_x_continuous(
            limits = c(0, max_tick_value),
            breaks = seq(0, max_tick_value, 50)
            ) +
            geom_vline(
            xintercept = tmax_bins,
            linetype = "dashed",
            color = palette_urbn_magenta[5]
            ) +
            geom_text(
            mapping = aes(
                x = lines,
                y = 0,
                label = lines_chr,
                hjust = 1,
                vjust = 1,
                angle = 90,
            ),
            color = palette_urbn_magenta[5],
            data = lines_df
            ) +
            labs(title = paste0(title, " (max: ", round(max(data_maxes$max_temp)), ")"))
    }


    job_loss_long %>%
    create_tmax_histogram(group = county_fips, title = "Max job loss in any tract-industry across Counties")
    ggsave(filename = "data/processed-data/s3_final/summary_stats/tmax_county_hist.png")

    job_loss_long %>%
    create_tmax_histogram(group = cbsa, title = "Max job loss in any tract-industry across CBSAs")
    ggsave(filename = "data/processed-data/s3_final/summary_stats/tmax_cbsa_hist.png")


    county_sums <- read_csv("data/processed-data/county_sums.csv") %>%
    pivot_longer(
        cols = X01:X20,
        names_to = "job_type",
        values_to = "job_loss"
    )

    cbsa_sums <- read_csv("data/processed-data/cbsa_sums.csv") %>%
    pivot_longer(
        cols = X01:X20,
        names_to = "job_type",
        values_to = "job_loss"
    )

    create_max_histogram <- function(data, group, title, zoomed = F) {
        data_maxes <- data %>%
            group_by({{ group }}) %>%
            summarise(max_temp = max(job_loss)) %>%
            ungroup()


        if (zoomed) {
            quantile_95 <- quantile(data_maxes$max_temp, 0.95)
            lines <- max_bins[max_bins < quantile_95]
            lines_df <- data_frame(
            lines = lines,
            lines_chr = as.character(lines)
            )

            plot <- data_maxes %>%
            filter(max_temp < quantile_95) %>%
            ggplot() +
            geom_histogram(mapping = aes(max_temp), bins = 300) +
            # scale_x_continuous(limits = c(0, max_tick_value),
            #                    breaks = seq(0, max_tick_value, 10000)) +
            geom_vline(
                xintercept = lines,
                linetype = "dashed",
                color = palette_urbn_magenta[5]
            ) +
            geom_text(
                mapping = aes(
                x = lines,
                y = 0,
                label = lines_chr,
                hjust = 1,
                vjust = 1,
                angle = 90,
                ),
                color = palette_urbn_magenta[5],
                data = lines_df,
                size = 2
            ) +
            labs(title = paste0(title, " (max: ", round(max(data_maxes$max_temp)), ")"))
        }
        else {
            max_tick_value <- ceiling(max(data$job_loss) / 10000) * 10000
            max_tick_value <- max(max_tick_value, tail(max_bins, n = 1))
            lines <- tail(max_bins, n = 3)
            lines_df <- data_frame(
            lines = lines,
            lines_chr = as.character(lines)
            )


            plot <- data_maxes %>%
            ggplot() +
            geom_histogram(mapping = aes(max_temp), bins = 1000) +
            scale_x_continuous(
                limits = c(0, max_tick_value),
                breaks = seq(0, max_tick_value, 40000)
            ) +
            geom_vline(
                xintercept = max_bins,
                linetype = "dashed",
                color = palette_urbn_magenta[5],
                alpha = 0.5
            ) +
            geom_text(
                mapping = aes(
                x = lines,
                y = 0,
                label = lines_chr,
                hjust = 1,
                vjust = 1,
                angle = 90,
                ),
                color = palette_urbn_magenta[5],
                size = 2,
                data = lines_df
            ) +
            labs(title = paste0(title, " (max: ", round(max(data_maxes$max_temp)), ")"))
        }
        return(plot)
    }


    county_sums %>%
    create_max_histogram(county_fips, "Max County-Industry job loss", zoomed = F)
    ggsave("data/processed-data/s3_final/summary_stats/max_county_industry_hist.png",
    width = 9, height = 7, units = "in"
    )


    cbsa_sums %>%
    create_max_histogram(cbsa, "Max CBSA-Industry job loss", zoomed = F)
    ggsave("data/processed-data/s3_final/summary_stats/max_cbsa_industry_hist.png",
    width = 9, height = 7, units = "in"
    )


    county_sums %>%
    create_max_histogram(county_fips, "Max County-Industry job loss", zoomed = T)
    ggsave("data/processed-data/s3_final/summary_stats/max_county_industry_hist_zoomed.png",
    width = 9, height = 7, units = "in"
    )


    cbsa_sums %>%
    create_max_histogram(cbsa, "Max CBSA-Industry job loss", zoomed = T)
    ggsave("data/processed-data/s3_final/summary_stats/max_cbsa_industry_hist_zoomed.png",
    width = 9, height = 7, units = "in"
    )

}

write_histograms_to_s3 = function(
    my_bucket_name = "ui-lodes-job-change-public"){



    s3_filepath <- "data/processed-data/s3_final/"

    #----Upload histograms to-------------------------------------
    # put county/cbsa max histograms in summary_stats subfolder on S3.
    # NOTE: This needs to be reviewed so we can set max_bins and tmax_bins
    # in 5-create-sum-files-update.R

    put_object(
    paste0(s3_filepath, "summary_stats/max_cbsa_industry_hist_zoomed.png"),
    "summary_stats/max_cbsa_industry_hist_zoomed.png",
    my_bucket_name
    )

    put_object(
    paste0(s3_filepath, "summary_stats/max_county_industry_hist_zoomed.png"),
    "summary_stats/max_county_industry_hist_zoomed.png",
    my_bucket_name
    )

    put_object(
    paste0(s3_filepath, "summary_stats/max_cbsa_industry_hist.png"),
    "summary_stats/max_cbsa_industry_hist.png",
    my_bucket_name
    )

    put_object(
    paste0(s3_filepath, "summary_stats/max_county_industry_hist.png"),
    "summary_stats/max_county_industry_hist.png",
    my_bucket_name
    )

    put_object(
    paste0(s3_filepath, "summary_stats/tmax_cbsa_hist.png"),
    "summary_stats/tmax_cbsa_hist.png",
    my_bucket_name
    )

    put_object(
        paste0(s3_filepath, "summary_stats/tmax_county_hist.png"),
        "summary_stats/tmax_county_hist.png",
        my_bucket_name
    )

}


generate_all_histograms(
    tmax_bins = tmax_bins, max_bins = max_bins
)

write_histograms_to_s3()
