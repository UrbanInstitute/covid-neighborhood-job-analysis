library(tidyverse)
library(readxl)
library(pdftools)
library(janitor)
library(lubridate)



generate_advance_claims_data = function(bls_raw_filepath="data/raw-data/big/r539cy.xls",
                                        bls_raw_skip=4,
                                        bls_raw_startdate="2020-03-20",
                                        bls_pdf_url="https://www.dol.gov/ui/data.pdf",
                                        bls_pdf_page=5,
                                        use_textract=TRUE,
                                        textract_misspellings = c("Mississipp" = "Mississippi", 
                                                                  "lowa" = "Iowa",
                                                                  "Alabama\\'" = "Alabama"),
                                        textract_pypath = "scripts/update/1b-extract-csv.py",
                                        output_file = "data/raw-data/small/initial-claims-bls-state.csv"
){
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
  bls_raw = read_excel(bls_raw_filepath,
                       skip = bls_raw_skip) %>% 
    janitor::clean_names() %>% 
    select(state, filed_week_ended, initial_claims)
  
  bls_raw = bls_raw %>% 
    filter(filed_week_ended >= bls_raw_startdate) %>% 
    pivot_wider(names_from = filed_week_ended, values_from = initial_claims)
  
  # Get next week of BLS data (ie current week) to use as colname
  last_raw_week = bls_raw %>% select(ncol(.)) %>% colnames()
  next_week = (lubridate::ymd(last_raw_week) + days(7)) %>% as.character()
  
  # Download PDF of most recent BLS data
  download.file(url = bls_pdf_url,
                destfile = "data/raw-data/small/bls-advance-claims.pdf",
                mode = "wb")
  # Read in and split page 5, where advanced state claims are
  # May need to manuall check pdf to make sure that is still right page
  pdf_subset("data/raw-data/small/bls-advance-claims.pdf", 
             pages = bls_pdf_page,
             output = "data/processed-data/bls-advance-claims-table.pdf")
  
  if (use_textract){
    # Convert pdf to png for use with Textract 
    pdf_convert("data/processed-data/bls-advance-claims-table.pdf",
                format = "png", 
                dpi  = 500,
                filenames = "data/processed-data/bls-advance-claims-table.png")
    
    # Setup an run python script that uses textract to extract CSV from image
    shell_command = paste0("python ", textract_pypath, " data/processed-data/bls-advance-claims-table.png")
    # This only works on Windows, you may need to change shell argument
    shell(shell_command, shell = "cmd.exe")
    
    bls_latest_week = read_csv("data/processed-data/textract_bls_output.csv")
  }
  
}
                                        



if (textract){
  ## Define helper functions 
  append_textract_data = function(bls_data, filepath){
    
    last_raw_week = bls_data %>% select(ncol(.)) %>% colnames()
    next_week = (lubridate::ymd(last_raw_week) + days(7)) %>% as.character()
    
    bls_advance = read_csv(filepath,
                           # Table title was showing up as column names, so skip first row
                           skip = 1)
    
    bls_advance = bls_advance %>% janitor::clean_names() %>% 
      transmute(state, !!next_week := advance) %>% 
      # Somtimes states have * to denote that BLS performed estimates
      # Take those asterisks out for left join
      mutate(state = str_replace_all(state, "[[:punct:]]", ""),
             state = str_trim(state),
             state = case_when(
               # Some states were misspelled in OCR process. This might change
               # from week to week so need to check! `tidylog` is helpful here
               state == "Mississipp" ~ "Mississippi",
               state == "lowa" ~ "Iowa",
               TRUE ~ state
             ))
    
    bls_advance_claims = bls_data %>% 
      left_join(bls_advance, by = "state") 
    
    return(bls_advance_claims)
    
  }
  
  
  # convert to png for Textract (pdf not accepted file format)
  pdf_convert("data/raw-data/small/data-bls-advance-claims-page.pdf",
              format = "png",
              dpi = 500,
              filenames = "data/raw-data/small/data-bls-advance-claims-page.png")
  
  # Run python script that uses AWS textract to extract CSV table from png using OCR
  shell('python scripts/update/1b-extract-csv.py data/raw-data/small/data-bls-advance-claims-page.png', 
        shell ="cmd.exe", intern = T)
  
  # Append new weeks advance claims data to raw bls data
  bls_advance_claims = bls_raw %>% 
    append_textract_data("data/processed-data/textract_bls_output.csv") %>% 
    arrange(desc(state))
  
  # Write out bls_advance_claims, we HIGHLY suggest manually spot checking this with
  # data\\raw-data\\small\\data-bls-advance-claims_output.pdf to make sure the OCR 
  # process worked sucesfully
  bls_advance_claims %>% write_csv("data/proessed-data/initial-claims-bls-state.csv")
} else {
  # NOTE: A column now needs to be manuakll
  bls_raw %>% write_csv("data/proessed-data/initial-claims-bls-state.csv")
}




# We downloaded raw data from https://oui.doleta.gov/unemploy/claims.asp, by selecting:
# - State, 2020-2021, and Spreadsheet in the form. We downloaded the resulting spreadsheet
# to data/raw-data/big.
# Note you may need to resave this xls worksheet as an xls worksheet 
# to fix data corruption errors and get R to readin correctly
bls_raw = read_excel("data/raw-data/big/r539cy.xls",
                     skip = 4) %>% 
  janitor::clean_names() %>% 
  select(state, filed_week_ended, initial_claims)


bls_raw = bls_raw %>% 
  filter(filed_week_ended >= "2020-03-20") %>% 
  pivot_wider(names_from = filed_week_ended, values_from = initial_claims)

last_raw_week = bls_raw %>% select(ncol(.)) %>% colnames()
next_week = (lubridate::ymd(last_raw_week) + days(7)) %>% as.character()

# Download PDF of most recent BLS data
download.file(url = "https://www.dol.gov/ui/data.pdf",
              destfile = "data/raw-data/small/data-bls-advance-claims.pdf",
              mode = "wb")

# Read in and split page 5, where advanced state claims are
# May need to manuall check pdf to make sure that is still right page
pdf_subset("data/raw-data/small/data-bls-advance-claims.pdf", 5)

# Resulting pdf is called data\\raw-data\\small\\data-bls-advance-claims_output.pdf
# We then upload to Amazon Textract to extract the table as text using OCR and perform
# manual checks to make sure everythign is right. We then download the table as a zip file.
# We then extract the resulting table-1.csv into raw-data/processed-data/
bls_advance = read_csv("data/processed-data/table-1.csv",
                       # Table title was showing up as column names, so skip first row
                       skip = 1)


bls_advance = bls_advance %>% janitor::clean_names() %>% 
  transmute(state, !!next_week := advance) %>% 
  # Somtimes states have * to denote that BLS performed estimates
  # Take those asterisks out for left join
  mutate(state = str_replace_all(state, "[[:punct:]]", ""),
         state = str_trim(state),
         state = case_when(
           # Some states were misspelled in OCR process. This might change
           # from week to week so need to check! `tidylog` is helpful here
           state == "Mississipp" ~ "Mississippi",
           state == "lowa" ~ "Iowa",
           TRUE ~ state
         ))

bls_advance_claims = bls_raw %>% 
  left_join(bls_advance, by = "state") 


