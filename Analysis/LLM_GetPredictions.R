# Script: LLM_GetPredictions.R
{
  # -- Clean workspace and set directories --
  rm(list = ls())
  setwd("~/Dropbox/APIs/Elites2") ; options(error = NULL) 
  set.seed(999L)
  runTest <- TRUE
  
  LocalGitHubLoc <- "~/Documents/elites2"
  runName <- "SearchTestParty"
  analysis_var <- "pol_party"            # column name of target covariate
  #analysis_var <- "birth_place"            # column name of target covariate
  promptType   <- "BaseSearch"

  LLMProvider <- "CustomLLM"; CustomLLMBackend <- "groq"; modelName <- "llama-3.1-8b-instant"; INITIALIZED_CUSTOM_ENV_TAG <- FALSE
  #LLMProvider <- "CustomLLM"; modelName <- "qwen-qwq-32b"; INITIALIZED_CUSTOM_ENV_TAG <- FALSE
  #LLMProvider <- "CustomLLM"; modelName <- "meta-llama/llama-4-scout-17b-16e-instruct"; INITIALIZED_CUSTOM_ENV_TAG <- FALSE
  #LLMProvider <- "CustomLLM"; modelName <- "gemma2-9b-it"; INITIALIZED_CUSTOM_ENV_TAG <- FALSE
  
  #LLMProvider <- "OpenAI"; modelName <- "gpt-4o-mini-search-preview"
  #LLMProvider <- "OpenAI"; modelName <- "gpt-4o-search-preview"
  #LLMProvider <- "OpenAI"; modelName <- "gpt-4.1-mini" 
  #LLMProvider <- "OpenAI"; modelName <- "gpt-4.1-nano"
  #LLMProvider <- "OpenAI"; modelName <- "gpt-4o-mini-2024-07-18" 
  #LLMProvider <- "OpenAI"; modelName <- "gpt-4o-2024-11-20" 
  
  # LLMProvider <- "DeepSeek";modelName <- "deepseek-chat"
  # LLMProvider <- "DeepSeek";modelName <- "deepseek-reasoner"
  
  searchEnabled <- grepl(tolower(promptType),pattern="search")
  
  # -- Load required packages --
  suppressPackageStartupMessages({
    library(httr);library(jsonlite)
    library(rio);library(MLmetrics);library(tibble)
    library(haven);library(tidyr);library(dplyr)
    library(readxl);library(writexl);library(stringr)
    library(future); library(future.apply); library(progress)
  })
  
  # -- Set up multicore (adjust workers if needed) --
  plan(multisession(workers = parallel::detectCores() - 0L))
  
  # 1. READ & PREPARE DATA
  # Load data
  source(sprintf('%s/Analysis/LLM_LoadInputData.R',LocalGitHubLoc))

  # drop NAs
  data[[analysis_var]][data[[analysis_var]] == " "] <- NA
  data <- data[!is.na(data[[analysis_var]]), ]
  
  # clean some data 
  if (analysis_var == "pol_party") {
    data$pol_party <- trimws(gsub("\\s+", " ", data$pol_party))
  }
  
  #data <- data[1:6,] # sample for quick execution
  if(runTest){
    KeepCountriesForTest <- c(
      "Nigeria", 
      "South Africa",
      "India",
      "Dominican Republic",
      "Egypt",
      #"Indonesia",
      #"Jamaica",
      #"Kenya",
      "Turkey",
      #"Taiwan",
      #"Russian Federation",
      #"Israel",
      "Thailand",
      #"United Kingdom (Great Britain)",
      "Brazil", "Japan", 
      #"Egypt",
      "United States of America"
    )
    unique(data$glp_country)
    #grep(data$glp_country,pattern="Russia",value=T)
    setdiff(KeepCountriesForTest, data$glp_country)
    data <- data[which(data$glp_country %in% KeepCountriesForTest),]
  }
  
  # Build map of options per country for the target variable
  data[[analysis_var]][data[[analysis_var]]==""] <- NA
  options_map <- data %>%
    group_by(glp_country) %>%
    summarise(options = list(unique(c(na.omit(.data[[analysis_var]]))))) %>%
    deframe()
  
  # subset data 
  filtered_data <- data[data$glp_country %in% names(options_map), ]
  filtered_data <- filtered_data %>%
                      group_by(glp_country) %>% 
                        slice_sample(n = 10) %>% 
                          ungroup()
  print("Data dimensions:")
  print(dim(filtered_data))
  

  
  # Split by country
  list_by_country <- split(filtered_data, filtered_data$glp_country)
  
  # ----------------------------------------------------------------------------
  # 2. ENCODING FIX
  # ----------------------------------------------------------------------------
  
  # Function to detect encoding and attempt to fix "person_name" if needed
  fix_encoding <- function(df) { 
    if ("person_name" %in% colnames(df) && is.character(df$person_name)) {
      # Extract sample text
      sample_text <- df$person_name[1:min(nrow(df), 10)] 
      sample_text <- sample_text[!is.na(sample_text) & sample_text != ""]
      if (length(sample_text) > 0) { 
        # Guess encoding
        temp_file <- tempfile() 
        writeLines(sample_text, temp_file, useBytes = TRUE) 
        encoding_guess <- readr::guess_encoding(temp_file)$encoding[1] 
        unlink(temp_file)
        if (!is.na(encoding_guess) && encoding_guess != "UTF-8") { 
          df$person_name <- iconv(df$person_name, from = "UTF-8", 
                                 to = encoding_guess, 
                                 sub = "byte")
        }
      }
    }
    return( df ) 
  }
  
  list_by_country <- lapply(list_by_country, fix_encoding)
  
  # ----------------------------------------------------------------------------
  # 3. API PARAMETERS (OpenAI, DeepSeek, etc.)
  # ----------------------------------------------------------------------------
  # Switch between model providers here
  if (LLMProvider == "OpenAI") {
    baseURL  <- "https://api.openai.com/v1/chat/completions"; api_key  <- Sys.getenv("OPENAI_API_KEY")  
  }
  if (LLMProvider == "DeepSeek"){
    baseURL  <- "https://api.deepseek.com/chat/completions"; api_key  <- Sys.getenv("DEEPSEEK_API_KEY")
  }
  if (LLMProvider == "CustomLLM"){
    source(sprintf('%s/Analysis/LLM_CustomLLM.R',LocalGitHubLoc),local = TRUE)# first run initializes env 
  }

  # create output directory 
  dir.create(output_directory <- sprintf("./SavedResults/Pred-%s-%s-%s",
                                         runName,
                                         LLMProvider, 
                                         gsub(modelName, pattern = "\\/", replace= "_SL_")
                                         ), 
                                 showWarnings = FALSE, recursive = TRUE)
  
  # ----------------------------------------------------------------------------
  # CORE PREDICTION FUNCTION
  # ----------------------------------------------------------------------------
  
  # Single-call function that queries ChatGPT (or other LLM) for a single name
  predict_value <- function(person_name, glp_country) {

    # Safety: if name is missing or blank
    if (is.na(person_name) || trimws(person_name) == "") {
      return(NA_character_)
    }
    
    # Build prompt from country-specific list
    options_of_country <- options_map[[glp_country]]
    
    # call in the prompt (this is called in as the {thePrompt} object)
    if(promptType == "BaseNameOnly"){ 
        source(sprintf('%s/Analysis/Prompt_%s_ModeName.R',
                       LocalGitHubLoc, analysis_var),local = TRUE)
    }
    if(promptType == "BaseSearch"){ 
        source(sprintf("%s/Analysis/Prompts/Prompt_%s_ModeSearch.R", 
                       LocalGitHubLoc, analysis_var),local = TRUE) 
    }
    
    # Prepare the request body
    body <- list(
      model = modelName,
      messages = list(
        list(
              role = "user", 
             content = thePrompt
            )
        ),
      max_tokens = 600
    )
    if (!searchEnabled) {
      body$temperature <- 0.1
    }
    if (searchEnabled) {
      #body$tools              <- list(list(type = "web_search"))
      #body$tools              <- list(list(type = "web_search_preview"))
      #body$tool_choice        <- "auto"      # let model decide when to call search
      #body$tool_choice        <- "required"    
      body$web_search_options <- list(search_context_size = "low")
    }
    
    # Backoff for reliability (up to 5 attempts)
    wait_time   <- 1
    
    for (attempt in seq_len(max_attempts <- 2)) {
      if(LLMProvider %in% c("OpenAI", "DeepSeek")){ 
        response <- try(
          POST(
            url = baseURL,
            add_headers(Authorization = paste("Bearer", api_key)),
            body = body,
            encode = "json",
            timeout(30)
          ), silent = TRUE)
        response <- try(content(response, as = "text", encoding = "UTF-8"), T)
        content_parsed <- try(fromJSON( response ),T) 
      }

      # mandatory sleep 
      Sys.sleep( wait_time )
      if(LLMProvider %in% c("CustomLLM")){ 
        source(sprintf("%s/Analysis/LLM_CustomLLM.R", LocalGitHubLoc),local = TRUE)
      }

      # If request fails or times out
      if (inherits(response, "try-error")) {
        Sys.sleep(wait_time); next
      }
      
      if (response$status_code != 200) { # Non-200, wait and retry
        Sys.sleep(wait_time)
      }
      if (response$status_code == 200) { # Successfully obtain answer 
        # if( length(content_parsed$choices$message$annotations[[1]]) > 0){ browser() }
        # print(content_parsed$choices$message)
        if(LLMProvider %in% c("OpenAI","DeepSeek") ){ raw_output <- try(content_parsed$choices$message$content,T) }
        if(LLMProvider %in% c("CustomLLM") ){ raw_output <- try(response$message,T) }
        
        # extract from the JSON
        json_txt <- str_extract(raw_output,"(?<=```json\\n)[\\s\\S]*?(?=\\n```)")
        json_txt <- ifelse(is.na(json_txt), yes= raw_output, no = json_txt)
        parsed_json <- try(fromJSON(json_txt),T)
        if("try-error" %in% class(parsed_json)){
          parsed_json <- try(fromJSON( str_extract(raw_output, 
                                                   "(?<=json\\n)[\\s\\S]*?(?=\\n```)") ), T) 
        }
        if("try-error" %in% class(parsed_json)){
          parsed_json <- try(fromJSON( raw_output ), T) 
        }
        if("try-error" %in% class(parsed_json)){
          browser()
          message("ERROR IN PARSED OUTPUT")
          next 
        }
        justification <- parsed_json$justification
        the_message <- list("predicted_value" = 
                              eval(parse(text = sprintf("the_prediction <- parsed_json$%s",analysis_var))),
                            "predicted_value_explanation" = parsed_json$justification, 
                            "predicted_value_confidence" = parsed_json$confidence, 
                            "prompt" = thePrompt)
        if(!the_prediction %in% options_of_country){ 
          browser()
          print("Got an answer from LLM, but output format bad. Retrying...") 
          Sys.sleep(0.1)
        }
        if(the_prediction %in% options_of_country){ return(the_message) } 
      }
    }
    browser()
    
    # If all attempts fail
    return( list("predicted_value" = NA,
                 "predicted_value_explanation" = NA, 
                 "predicted_value_confidence" = NA, 
                 "prompt" = NA) )
  }
  
  # ----------------------------------------------------------------------------
  # 6. PREDICTION WORKFLOW (country-level)
  # ----------------------------------------------------------------------------
  
  # This function:
  #   - Checks for existing partial results
  #   - Predicts missing rows
  #   - Caches predictions incrementally
  predict_and_save <- function(df, glp_country, output_directory) {
    # Construct file paths
    csv_path  <- file.path(output_directory, paste0("LLMPrediction_", 
                                                    glp_country, ".csv"))
    rds_path  <- file.path(output_directory, paste0("LLMPrediction_", 
                                                    glp_country, ".rds"))
    
    # If partial or completed results exist, load them
    if (file.exists(rds_path)) {
      message(">>> Resuming from partial results: ", glp_country)
      existing_results <- readRDS(rds_path)
      # Merge existing predictions back into df
      eval(parse(text = sprintf('
      df <- df %%>%%
        left_join(existing_results %%>%% select(row_id, 
                                              predicted_%s,
                                              predicted_%s_explanation, 
                                              predicted_%s_confidence, 
                                              prompt),
                                              by = "row_id")
      ', analysis_var,analysis_var,analysis_var) ))
    } else if (file.exists(csv_path)) {
      # or load from CSV if no RDS
      message(">>> Resuming from CSV: ", glp_country)
      existing_results <- read.csv(csv_path, stringsAsFactors = FALSE)
      eval(parse(text = sprintf('
          df <- df %%>%%
            left_join(existing_results %%>%% select(row_id, 
                                                  predicted_%s,
                                                  predicted_%s_explanation, 
                                                  predicted_%s_confidence, 
                                                  prompt),
                                                  by = "row_id")
      ', analysis_var,analysis_var,analysis_var) ))
    } else {
      # If no existing file, create a row_id to track progress
      df$row_id <- seq_len(nrow(df))
      eval(parse(text = sprintf('
      df$predicted_%s <- df$predicted_%s_explanation <- df$predicted_%s_confidence <- NA_character_
        ', analysis_var, analysis_var, analysis_var)))
      df$prompt             <- NA_character_
    }
    
    # Identify which rows need predictions
    eval(parse(text = sprintf('
            todo_idx <- which(is.na(df$predicted_%s) | df$predicted_%s == "")
    ', analysis_var, analysis_var)))
    if (length(todo_idx) == 0) {
      message(">>> All predictions are already available for ", glp_country)
    } else {
      message(">>> Need to get predictions for ", length(todo_idx), " rows in ", glp_country)
      
      # Set up a progress bar
      pb <- progress_bar$new(
        format = "  Predicting :current/:total (:percent) - ETA: :eta",
        total = length(todo_idx), clear = FALSE, width = 60
      )
      
      # FUTURE_LAPPLY with concurrency limit to avoid rate-limit issues
      # Adjust `future.seed = TRUE` to ensure reproducible seeds if needed
      # You may also set `future.scheduling = 1` or `chunk.size` to control tasks
      #predicted_responses <- future.apply::future_lapply(future.seed = TRUE,
      print("Running in non-parallel mode for testing..."); predicted_responses <- lapply(
        X = todo_idx,
        FUN = function(i) {
          # Predict
          res <- predict_value(df$person_name[i], df$glp_country[i])
          pb$tick()
          Sys.sleep(0.1)  # small pause to mitigate rapid-fire requests
          return(res)
        }
      )
      predicted_responses <- as.data.frame(do.call(rbind,predicted_responses))
      
      # Store results
      eval(parse(text = sprintf('
      df[todo_idx,"predicted_%s"] <- unlist(predicted_responses$predicted_value)
      df[todo_idx,"predicted_%s_explanation"] <- unlist(predicted_responses$predicted_value_explanation)
      df[todo_idx,"predicted_%s_confidence"] <- unlist(predicted_responses$predicted_value_confidence)
      ', analysis_var,analysis_var,analysis_var)))
      df[todo_idx,"prompt"] <- unlist(predicted_responses$prompt)
      
      # View(df[,c("predicted_ethnicity","predicted_ethnicity_explanation","predicted_ethnicity_confidence")])
      # View(df[,c("pol_party", "predicted_party","predicted_party_explanation","predicted_party_confidence")])
      
      # Save partial results immediately
      eval(parse(text = sprintf('
      saveRDS(df %%>%% select(row_id, 
                            predicted_%s, 
                            predicted_%s_explanation,
                            predicted_%s_confidence,
                            prompt),
              file = rds_path)
              ',analysis_var,analysis_var,analysis_var)))
    }

    # Write final results to disk
    df$LLMProvider <- LLMProvider
    df$CustomLLMBackend <- ifelse(LLMProvider == "CustomLLM", CustomLLMBackend, NA)
    df$modelName <- modelName
    df$promptType <- promptType
    df$runTest <- runTest
    df$AnalysisDate <- Sys.Date()
    write.csv(df, file = csv_path, row.names = FALSE)
    saveRDS(df, file = rds_path)
    
    return(df)
  }
  
  # ----------------------------------------------------------------------------
  # 7. MAIN EXECUTION
  # ----------------------------------------------------------------------------
  
  # Ensure each data frame has a row_id to track partial progress
  list_by_country <- lapply(list_by_country, function(df) {
    if (!"row_id" %in% colnames(df)) {
      df$row_id <- seq_len(nrow(df))
    }
    df
  })
  
  all_results <- list(); for (ctry in names(list_by_country)) {
    message("Processing country: ", ctry)
    
    df_ctry <- list_by_country[[ctry]]
    out_ctry <- predict_and_save(df_ctry, ctry, output_directory)
    all_results[[ctry]] <- out_ctry
  }
  
  # all_results[[1]][,c("ethnic","predicted_ethnicity")]
  
  message("Done with LLM_GetPredictions.R call!")
  if(T == F){ 
    source("~/Documents/elites2/Analysis/LLM_AnalyzePredictions.R")
  }
}
