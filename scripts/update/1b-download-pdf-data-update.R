library(tidyverse)
library(readxl)
library(pdftools)
library(janitor)
library(lubridate)
library(magick)

generate_advance_claims_data <- function(bls_raw_filepath = "data/raw-data/big/r539cy.xls",
                                         bls_raw_skip = 4,
                                         bls_raw_startdate = "2020-03-20",
                                         bls_pdf_url = "https://www.dol.gov/ui/data.pdf",
                                         bls_pdf_page = 5,
                                         use_textract = TRUE,
                                         textract_misspellings = c(
                                             "Mississipp" = "Mississippi",
                                             "lowa" = "Iowa",
                                             "Alabama\\'" = "Alabama"
                                         ),
                                         textract_pypath = "scripts/update/1b-extract-csv.py",
                                         output_file = "data/raw-data/small/initial-claims-bls-state.csv") {
    # Function that combines UI Weekly claims data which are behind by a week
    # with DOL's latest week unemployment numbers. The latest week unemployment numbers
    # are only available as a table in a pdf, which this function can try to parse using
    # Amazon's Textract service. If that option is set to FALSE, Users can also manually
    # add a column to the output CSV and manually add the unemployment numbers from the new
    # week's PDF to the appropriate state. One file needs to be manually downloaded from
    # https://oui.doleta.gov/unemploy/claims.asp before this function is run.
    # INPUT:
    #   - bls_raw_filepath (str): The filepath to the manually downloaded CSV from the above URL
    #   - bls_raw_skip (int): How many lines in the blw_raw csv to skip (usually due to bad headers/subheaders)
    #   - bls_raw_startdate (str): The startdat from which to left censor the BLS raw data from. We've set this
    #       to the week of 2020-03-21 as that's when the rest of our WA/NY data also begins
    #   - bls_pdf_url (str): URL to pull the new weekly unemployment PDF from. This seems to be a fixer URL, so
    #       content chagnes automatically each Thursday morning
    #   - bls_pdf_page (int): The page of the above pdf containing the Table titled "Advance
    #       State Claims -Not Seasonally Adjusted". We pull out just this page for easier OCRing with TEXTRACT
    #   - use_textract (lgl): Flag to specify whether to use AWS Textract to try to automatically generate
    #       a CSV from the PDF table. We've tested it on the 4/23/20 PDF and it seems to perform well
    #       without any mistakes. If you set this to FALSE, the bls_raw data will be written out and you
    #       are expected to manually add a column to that CSV and populate with the values from the PDF
    #   - textract_misppellings (named vector): A list of state misspellings that Textract seems to make
    #       with the pdf. This list may need to be updated in the future, for now it is simply the two
    #       two mistakes
    #   - textract_ptpath: Filepath to python file that uses textract to generate a CSV
    #   - output_file: Filepath (and name) for output CSV

    # Read in and clean raw bls data
    bls_raw <- read_excel(bls_raw_filepath,
        skip = bls_raw_skip
    ) %>%
        janitor::clean_names() %>%
        select(state, filed_week_ended, initial_claims)

    bls_raw <- bls_raw %>%
        filter(filed_week_ended >= bls_raw_startdate) %>%
        pivot_wider(names_from = filed_week_ended, values_from = initial_claims)

    # Get next week of BLS data (ie current week) to use as colname
    last_raw_week <- bls_raw %>%
        select(ncol(.)) %>%
        colnames()
    next_week <- (lubridate::ymd(last_raw_week) + days(7)) %>% as.character()


    # Read in page 5 of BLS pdf, where advanced state claims are
    # May need to manually check pdf to make sure this is still right page
    pdf_img <- image_read_pdf(bls_pdf_url, pages = 5)

    # Crop to just columns for state, advance claims, and prior weeks claims
    advance_claims_img <- image_crop(pdf_img, "1100x2370+50+330")

    # Write out cropped image to png
    advance_claims_img %>% image_write(
        path = "data/processed-data/bls-advance-claims-table.png",
        format = "png"
    )


    if (use_textract) {

        # Setup and run python script that uses textract to extract CSV from image
        shell_command <- paste0("python ", textract_pypath, " data/processed-data/bls-advance-claims-table.png")
        # This only works on Windows, you may need to change shell argument
        shell(shell_command, shell = "cmd.exe")

        # Read in output of Textract
        bls_advance_claims <- read_csv("data/processed-data/textract_bls_output.csv")

        # Rename columns and cleanup for joining
        bls_advance_claims <- bls_advance_claims %>%
            select(
                !!last_raw_week := `Prior Wk`,
                !!next_week := Advance,
                state = STATE
            ) %>%
            mutate(
                state = str_replace_all(state, "[[:punct:]]", ""),
                state = stringr::str_trim(state)
            )

        # Join to raw bls data
        all_bls_claims <- bls_raw %>%
            left_join(bls_advance_claims, by = c("2020-04-25", "state"))

        return(all_bls_claims)
    } else {
        print("initial-claims-bls-state.csv needs to be manually updated with image located at data/processed-data/bls-advance-claims-table.png ")
        return(bls_raw)
    }
}

bls_advance_claims <- generate_advance_claims_data()
bls_advance_claims %>% write_csv("data/raw-data/small/initial-claims-bls-state.csv")