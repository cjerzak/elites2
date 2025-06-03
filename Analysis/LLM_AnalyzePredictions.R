# Script: LLM_AnalyzePredictions.R
{
  # ------------------------------------------------------------------------------
  #  EVALUATION SCRIPT FOR ETHNICITY INFERENCE
  #  - Reads each country's predictions from ./Prediction/*
  #  - Merges them
  #  - Computes metrics overall, by country, and by pred type
  #  - Visualizes confusion matrices
  # ------------------------------------------------------------------------------
  
  # Clean workspace (optional)
  rm(list=ls())
  setwd("~/Dropbox/APIs/Elites2") ; options(error = NULL)
  source('./Analysis/LLM_DataLocs.R')
  
  #prediction_dir <- "./SavedResults/Pred-DeepSeek-deepseek-chat-FastTest"
  #prediction_dir <- "./SavedResults/Pred-DeepSeek-deepseek-chat-FastTest2"
  #prediction_dir <- "./SavedResults/Pred-OpenAI-gpt-4.1-nano-FastTest3"
  #prediction_dir <- "./SavedResults/Pred-OpenAI-gpt-4.1-nano-FastTest3"
  #prediction_dir <- "./SavedResults/Pred-OpenAI-gpt-4o-mini-search-preview-SearchTestParty"
  prediction_dir <- "./SavedResults/Pred-SearchTestParty-OpenAI-gpt-4o-mini-search-preview"
  
  imputeType <- "party"; 
  #imputeType <- "ethnicity"; 
  if(imputeType=="party"){  pred_name_ <- "predicted_party"; truth_name_ <- "pol_party" }
  if(imputeType=="ethnicity"){  pred_name_ <- "predicted_ethnicity"; truth_name_ <- "ethnic" }
  
  # load in persons level data 
  ethnicgroups <- haven::read_dta(groups_dat_loc)
  ethnicpersons <- haven::read_dta(person_dat_loc, encoding = "UTF-8")
  # View(ethnicgroups[ethnicgroups$glp_country=="Brazil",])
  # View(ethnicgroups[grepl(ethnicgroups$glp_country,pattern="United Kingdom"),])
  
  # --- Libraries ---
  suppressPackageStartupMessages({
    library(dplyr); library(tidyr);library(tibble);library(purrr)
    library(ggplot2); library(readr); library(stringr)
    library(forcats); library(caret); library(yardstick) # For metrics such as f_meas, accuracy, etc.
  })
  
  # Path to predictions
  
  # 1. Gather all saved RDS or CSV files from the prediction directory
  rds_files <- paste(prediction_dir,"/",
                     grep(list.files(prediction_dir),pattern="\\.rds",value=T),
                     sep = "")
  csv_files <- paste(prediction_dir,"/",
                     grep(list.files(prediction_dir),pattern="\\.csv",value=T),
                     sep = "")
  
  # If you prefer RDS (as your main script saves partial progress in RDS):
  files_to_read <- if (length(rds_files) > 0) rds_files else csv_files
  
  # 2. Read and combine all predictions
  all_data <- files_to_read %>%
    map_dfr(function(file_path) {
      message("Reading: ", file_path)
      if (grepl("\\.rds$", file_path, ignore.case = TRUE)) {
        df <- readRDS(file_path)
      } else {
        df <- read_csv(file_path, show_col_types = FALSE)
      }
      
      # Ensure standard columns exist
      # e.g., "glp_country", "ethnic", "predicted_ethnicity"
      # If your dataset uses different column names, adjust here:
      if(imputeType == "ethnicity"){ needed_cols <- c("glp_country", "ethnic", "predicted_ethnicity")} 
      if(imputeType == "party"){ needed_cols <- c("glp_country", "pol_party", "predicted_party")} 
      missing_cols <- setdiff(needed_cols, colnames(df))
      if (length(missing_cols) > 0) {
        warning("Missing columns in file ", file_path, ": ", paste(missing_cols, collapse=", "))
        # Create them as NA if needed
        for (mc in missing_cols) { df[[mc]] <- NA }
      }
      
      # Return only the relevant columns plus anything else you want
      df %>% select(any_of(needed_cols), everything())
    })
  
  # View(all_data[all_data$glp_country=="Argentina",c("person_name",pred_name_,truth_name_)])
  # View(all_data[all_data$glp_country=="Brazil",c("person_name",pred_name_,truth_name_)])
  # View(all_data[all_data$glp_country=="Kenya",c("person_name",pred_name_,truth_name_)])
  # View(all_data[grepl(all_data$glp_country,pattern="United King"),c("person_name",pred_name_,truth_name_)])

  # 3. Filter rows that actually have ground-truth for evaluation
  eval_data <- all_data %>%
    filter(
      !is.na(ethnic), 
      ethnic != "" ) %>%
    mutate(
      # Coerce to character (if they’re haven_labelled or other) 
      ethnic = as.character(ethnic),
      predicted_ethnicity  = as.character(predicted_ethnicity),
      # Sometimes the model might return NA or blank 
      predicted_ethnicity  = if_else(is.na(predicted_ethnicity), 
                                     "MissingPrediction", predicted_ethnicity)
    )
  
  # drop predictions not in pool  
  stop("XXX")
  # sum(!eval_data$predicted_ethnicity %in% eval_data$ethnic)
  eval_data <- eval_data[which(eval_data$predicted_ethnicity %in% eval_data$ethnic),]
  cbind(all_data$pol_party, all_data$predicted_party)
  table(all_data$glp_country)
  mean(all_data$predicted_party == all_data$pol_party, na.rm = T)
  mean((all_data$predicted_party == all_data$pol_party)[all_data$predicted_party_confidence=="Low"], na.rm = T)
  mean((all_data$predicted_party == all_data$pol_party)[all_data$predicted_party_confidence=="High"], na.rm = T)
  all_data[,c("person_name","pol_party", "predicted_party_confidence","predicted_party")][1,]
  all_data$person_name
  
  # View(all_data[all_data$glp_country=="Egypt",])
  
  tapply(all_data$predicted_party_confidence, 
         all_data$glp_country, 
         table)
  
  all_data$predicted_party_explanation[all_data$predicted_party_confidence == "Low"][1]
  all_data$predicted_party_explanation[all_data$predicted_party_confidence == "Low"][2]
  all_data$predicted_party_explanation[all_data$predicted_party_confidence == "Low"][3]
  all_data$predicted_party_explanation[all_data$predicted_party_confidence == "High"][1]
  all_data$predicted_party_explanation[all_data$predicted_party_confidence == "High"][2]
  all_data$predicted_party_explanation[all_data$predicted_party_confidence == "High"][3]
  
  
  # Quick check
  cat("Total rows in 'eval_data': ", nrow(eval_data), "\n")
  cat("Countries found: ", paste(unique(eval_data$glp_country), collapse = ", "), "\n")

# obtain results
{
  #View(cbind(eval_data$glp_country,
        #eval_data$ethnic,
        #eval_data$predicted_ethnicity))
  
  # -------------------------------------------------------------------
  # 4. Overall Metrics
  # -------------------------------------------------------------------
  # (a) Overall accuracy
  overall_accuracy <- mean(eval_data[[pred_name_]] == eval_data[[truth_name_]])
  cat("\nOverall Accuracy:", round(overall_accuracy, 4), "\n")
  
  # (b) Overall confusion matrix (caret)
  truth_levels <- sort(unique(eval_data[[truth_name_]]))
  pred_levels  <- sort(unique(eval_data[[pred_name_]]))
  all_levels   <- union(truth_levels, pred_levels)
  
  cm_overall <- confusionMatrix(
    data      = factor(eval_data[[pred_name_]], levels = all_levels),
    reference = factor(eval_data[[truth_name_]], levels = all_levels)
  )
  cat("\nOverall Confusion Matrix:\n")
  print(cm_overall)
  
  # (c) Additional metrics via yardstick
  stop("XXX")
  metrics_overall <- eval_data %>%
    mutate(
      truth    = factor(ethnic, levels = all_levels),
      estimate = factor(predicted_ethnicity,  levels = all_levels)
    ) %>%
    yardstick::metrics(truth = truth, estimate = estimate)
  
  
  metrics_overall <- eval_data %>%
    yardstick::metrics(
      truth    = !!truth_sym,
      estimate = !!pred_sym
    )
  
  
  cat("\nYardstick Overall Metrics (Accuracy, Kappa, etc.):\n")
  print(metrics_overall)
  
  acc_by_country <- tapply(eval_data$ethnic==eval_data$predicted_ethnicity,
                           eval_data$glp_country, 
                           mean)
  sort( acc_by_country )
  
  # For F2 specifically:
  f2_overall <- eval_data %>%
    mutate(
      truth    = factor(ethnic, levels = all_levels),
      estimate = factor(predicted_ethnicity,  levels = all_levels)
    ) %>%
    f_meas(truth = truth, estimate = estimate, beta = 2)
  cat("\nOverall F2 (macro-averaged): ", f2_overall$.estimate, "\n")
  
  # -------------------------------------------------------------------
  # 5. Metrics by Country
  # -------------------------------------------------------------------
  acc_by_country <- tapply(1:nrow(eval_data),
                           eval_data$glp_country,
                           function(i_){
                             mean(eval_data[i_,]$ethnic == 
                                    eval_data[i_,]$predicted_ethnicity)
                           })
  baseline_acc_by_country <- tapply(1:nrow(eval_data),
                                eval_data$glp_country,
                                function(i_){
                                  mean(eval_data[i_,]$ethnic == 
                                         names(table(eval_data[i_,]$ethnic))[
                                           which.max(table(eval_data[i_,]$ethnic))]
                                  )
                                })
  nGroups_by_country <- tapply(1:nrow(eval_data),
                               eval_data$glp_country,
                               function(i_){
                                 length(unique(eval_data[i_,]$ethnic))
                               })
  dispersion_by_country <- tapply(1:nrow(eval_data),
                                  eval_data$glp_country,
                                  function(i_){
                                    sum(prop.table(table(
                                      eval_data[i_,]$ethnic
                                    ))^2)
                                  })
  plot(acc_by_country)
  head(sort(acc_by_country))
  plot(nGroups_by_country, acc_by_country, log="")
  plot(dispersion_by_country, acc_by_country, log="")
  head(sort(acc_by_country),10)
  tail(sort(acc_by_country),100)
  plot(baseline_acc_by_country, acc_by_country);abline(a=0,b=1)
  head(sort(acc_by_country-baseline_acc_by_country),20)
  tail(sort(acc_by_country-baseline_acc_by_country),20)
  cbind(baseline_acc_by_country, acc_by_country)
  
  stop("XXX")

  # Using yardstick grouped approach for multi-class metrics by country
  by_country_metrics <- eval_data %>%
    mutate(
      truth    = factor(ethnic, levels = all_levels),
      estimate = factor(predicted_ethnicity,  levels = all_levels)
    ) %>%
    group_by(glp_country) %>%
    metrics(truth = truth, estimate = estimate)
  
  by_country_f2 <- eval_data %>%
    mutate(
      truth    = factor(ethnic, levels = all_levels),
      estimate = factor(predicted_ethnicity,  levels = all_levels)
    ) %>%
    group_by(glp_country) %>%
    f_meas(truth = truth, estimate = estimate, beta = 2)
  
  cat("\nMulti-class Metrics by Country (yardstick):\n")
  print(by_country_metrics)
  cat("\nF2 by Country (yardstick):\n")
  print(by_country_f2)
  
  # -------------------------------------------------------------------
  # 6. Metrics by type
  # -------------------------------------------------------------------
  by_ethnicity <- eval_data %>%
    group_by(ethnic) %>%
    summarize(
      n = n(),
      accuracy = mean(ethnic == predicted_ethnicity),
      f2_macro = f_meas_vec(
        truth    = as.factor(ethnic),
        estimate = as.factor(predicted_ethnicity),
        beta     = 2,
        estimator= "macro"
      ),
      .groups = "drop"
    ) %>%
    arrange(desc(n))
  
  cat("\nBy group Performance:\n")
  print(by_ethnicity)
  
  cat("\n--- Summarize by (Country, True values) ---\n")
  
  by_country_ethnicity <- eval_data %>%
    group_by(glp_country, ethnic) %>%
    summarise(
      n         = n(),
      n_correct = sum(predicted_ethnicity == ethnic),
      accuracy  = mean(predicted_ethnicity == ethnic),
      .groups   = "drop"
    ) %>%
    arrange(glp_country, desc(n))
  
  cat("\nBy-Country and By-Ethnicity Summary:\n")
  print(by_country_ethnicity)
  
  # -------------------------------------------------------------------
  # 8. ALTERNATIVE: Cross-tab for confusion breakdown by country
  # -------------------------------------------------------------------
  cat("\n--- ALTERNATIVE: Cross-tab by Country (truth vs. predicted) ---\n")
  
  crosstab_by_country <- eval_data %>%
    group_by(glp_country) %>%
    count(ethnic, predicted_ethnicity) %>%
    group_by(glp_country, ethnic) %>%
    mutate(prop = n / sum(n)) %>%
    ungroup() %>%
    arrange(glp_country, ethnic, desc(n))
  
  cat("\nCross-tab (Head):\n")
  print(head(crosstab_by_country, 30))  # Print first few rows
}
}
