# Script: LLM_DataLocs.R
{
  groups_dat_loc <- 'ethnic_groups_041225.dta'
  person_dat_loc <- "ethnic_party_master_041225.dta"
  
  # load hf dtat
  message("Loading main input data (via HFace)...")
  resp <- try(httr::GET(sprintf("https://huggingface.co/datasets/JerzakLabs/GLP/resolve/main/%s",
                                person_dat_loc), 
                        add_headers(Authorization = paste("Bearer",Sys.getenv("HF_API_KEY")))),T)
  httr::stop_for_status(resp) 
  
  # Write to a temporary .dta file and read it into R
  tmp <- try(tempfile(fileext = ".dta"),T)
  try(writeBin(content(resp, "raw"), tmp),T)
  
  # load in data 
  data <- try(haven::read_dta(tmp, encoding = "UTF-8"),T) 
  if("try-error" %in% class(data)){
    message("HF failed. Now trying Dropbox load of main input data...")
    data <- haven::read_dta(sprintf("./Data/%s", person_dat_loc), 
                            encoding = "UTF-8")
  }
}