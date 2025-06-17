# Script: LLM_AnalyzePredictions.R
{
  #  - Reads each country's predictions from ./Prediction/*
  #  - Merges them
  #  - Computes metrics overall, by country, and by pred type
  #  - Visualizes confusion matrices
  
  # Clean workspace 
  rm(list=ls())
  setwd("~/Dropbox/APIs/Elites2") ; options(error = NULL)
  LocalGitHubLoc <- "~/Documents/elites2"
  library(httr);library(jsonlite)
  
  # load in input data 
  source(sprintf('%s/Analysis/LLM_LoadInputData.R',LocalGitHubLoc))

  #prediction_dir <- "./SavedResults/Pred-OpenAI-gpt-4o-mini-search-preview-SearchTestParty"
  #prediction_dir <- "./SavedResults/Pred-SearchTestParty-OpenAI-gpt-4o-mini-search-preview"
  #prediction_dir <- "./SavedResults/Pred-SearchTestParty-CustomLLM-llama-3.1-8b-instant"
  #prediction_dir <- "./SavedResults/Pred-SearchTestParty-CustomLLM-qwen-qwq-32b"
  #prediction_dir <- "./SavedResults/Pred-SearchTestParty-CustomLLM-meta-llama_SL_llama-4-scout-17b-16e-instruct"
  prediction_dir <- "./SavedResults/Pred-SearchTestParty-CustomLLM-llama-3.1-8b-instant"

  analysis_var <- "pol_party"            # column name of target covariate
  pred_name_   <- paste0("predicted_", analysis_var)
  truth_name_ <- analysis_var
  pred_sym  <- rlang::sym(pred_name_)
  truth_sym <- rlang::sym(truth_name_)
  
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
      needed_cols <- c("glp_country", analysis_var, pred_name_)
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
  eval_data <- all_data[!is.na(all_data[[truth_name_]]),]
  
  cbind(all_data[[pred_name_]],all_data[[truth_name_]])
  plot(1*is.na(all_data$predicted_pol_party))
    
  # drop predictions not in pool of options
  # sum(!eval_data[[pred_name_]] %in% eval_data[[truth_name_]])
  eval_data <- eval_data[eval_data[[pred_name_]] %in% eval_data[[truth_name_]], ]
  
  # Quick check
  cat("Total rows in 'eval_data': ", nrow(eval_data), "\n")
  cat("Countries found: ", paste(unique(eval_data$glp_country), collapse = ", "), "\n")

  #View(cbind(eval_data$glp_country, eval_data$ethnic, eval_data$predicted_ethnicity))
  
  # obtain results
  # 4. Overall Metrics
  # (a) Overall accuracy
  overall_accuracy <- mean(eval_data[[pred_name_]] == eval_data[[truth_name_]])
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
  metrics_overall <- eval_data %>%
    mutate(
      truth    = factor(.data[[truth_name_]], levels = all_levels),
      estimate = factor(.data[[pred_name_]],  levels = all_levels)
    ) %>%
    yardstick::metrics(truth = truth, estimate = estimate)

  cat("\nYardstick Overall Metrics (Accuracy, Kappa, etc.):\n")
  print(metrics_overall)
  
  acc_by_country <- tapply(eval_data[[truth_name_]] == eval_data[[pred_name_]],
                           eval_data$glp_country,
                           mean)
  sort( acc_by_country )
  
  # For F2 specifically:
  f2_overall <- eval_data %>%
    mutate(
      truth    = factor(.data[[truth_name_]], levels = all_levels),
      estimate = factor(.data[[pred_name_]],  levels = all_levels)
    ) %>%
    f_meas(truth = truth, estimate = estimate, beta = 2)
  cat("\nOverall F2 (macro-averaged): ", f2_overall$.estimate, "\n")
  
  # -------------------------------------------------------------------
  # 5. Metrics by Country
  # -------------------------------------------------------------------
  acc_by_country <- tapply(1:nrow(eval_data),
                           eval_data$glp_country,
                           function(i_){
                             mean(eval_data[i_,][[truth_name_]] ==
                                    eval_data[i_,][[pred_name_]])
                           })
  baseline_acc_by_country <- tapply(1:nrow(eval_data),
                                eval_data$glp_country,
                                function(i_){
                                  mean(eval_data[i_,][[truth_name_]] ==
                                         names(table(eval_data[i_,][[truth_name_]]))[
                                           which.max(table(eval_data[i_,][[truth_name_]]))
                                      ])
                                })
  nGroups_by_country <- tapply(1:nrow(eval_data),
                               eval_data$glp_country,
                               function(i_){
                                 length(unique(eval_data[i_,][[truth_name_]]))
                               })
  dispersion_by_country <- tapply(1:nrow(eval_data),
                                  eval_data$glp_country,
                                  function(i_){
                                    sum(prop.table(table(
                                      eval_data[i_,][[truth_name_]]
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
  

  # Using yardstick grouped approach for multi-class metrics by country
  by_country_metrics <- eval_data %>%
    mutate(
      truth    = factor(.data[[truth_name_]], levels = all_levels),
      estimate = factor(.data[[pred_name_]],  levels = all_levels)
    ) %>%
    group_by(glp_country) %>%
    metrics(truth = truth, estimate = estimate)

  by_country_f2 <- eval_data %>%
    mutate(
      truth    = factor(.data[[truth_name_]], levels = all_levels),
      estimate = factor(.data[[pred_name_]],  levels = all_levels)
    ) %>%
    group_by(glp_country) %>%
    f_meas(truth = truth, estimate = estimate, beta = 2)
  
  cat("\nMulti-class Metrics by Country (yardstick):\n")
  print(by_country_metrics)
  cat("F2 by Country (yardstick):")
  print(by_country_f2)

  by_country_ethnicity <- eval_data %>%
    group_by(glp_country, .data[[truth_name_]]) %>%
    summarise(
      n         = n(),
      n_correct = sum(.data[[pred_name_]] == .data[[truth_name_]]),
      accuracy  = mean(.data[[pred_name_]] == .data[[truth_name_]]),
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
    count(!!truth_sym, !!pred_sym) %>%
    group_by(glp_country, !!truth_sym) %>%
    mutate(prop = n / sum(n)) %>%
    ungroup() %>%
    arrange(glp_country, !!truth_sym, desc(n))
  
  cat("\nCross-tab (Head):\n")
  print(head(crosstab_by_country, 30))  # Print first few rows
}




