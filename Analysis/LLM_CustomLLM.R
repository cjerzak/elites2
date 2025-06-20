# Script: LLM_CustomLLM.R
{
# Run the agent, if initialized 
if(INITIALIZED_CUSTOM_ENV_TAG){
    # rebuild agent - make sure tor is running (see tor browser to confirm)
    # brew services start tor
    rotate_tor_circuit() 
    
    # experimental 
    if(T == F){ 
    WhereSearch <- grep(unlist(lapply(theTools, function(l_){ l_$description})),pattern="DuckDuckGo")
    theTools[[WhereSearch]]$client$headers <- list("User-Agent" = paste0("Mozilla/5.0 (Windows NT 10.0; rv:124.0) Gecko/", 
                                                                 sample(20100101:20231231,1), " Firefox/", 
                                                                 sample(100:124,1), ".0"))
    
    test <- ratelimitr::limit_rate(theAgent$invoke(
        list(messages = list(list(role = "user", 
                                  content = thePrompt))),
        config = list(configurable = list(thread_id = "session-001"))),
        rate(n = 1, period = 1))
    }

    # recreate agent 
    theAgent <- agents$create_react_agent(
      model        = theLLM,
      tools        = theTools,
      checkpointer = MemorySaver(),
    )
    
    # thePrompt <- "What is the politicalparty of Scott Walker?"
    # (theLLM$bind_tools(theTools))$invoke(input = thePrompt)
    raw_response <- try(theAgent$invoke(
        list(messages = list(list(role = "user", 
                                  content = thePrompt))),
             config = list(configurable = list(thread_id = "session-001"))),
        TRUE)
    if(grepl(raw_response,pattern = "202 Ratelimit")){Sys.sleep(30L); warning("202 Ratelimit triggered")} # triggered on task 44 
    if(grepl(raw_response,pattern = "TimeoutException")){Sys.sleep(30L); warning("TimeoutException triggered")}

    # save full traceback
    text_blob <- paste(unlist(raw_response), collapse = "\n")
    writeBin(charToRaw(text_blob), file.path(sprintf("%s/traces/CID%s_PID%s_YID%s_R%s.txt",
                                           output_directory,
                                           data$country_id[i],
                                           data$person_id[i],
                                           data$election_year[i],
                                           data$round2[i]
                                           )))
    
    # extract final response 
    theResponseText <- try(raw_response$messages[[length(raw_response$messages)]]$text(), TRUE)
    
    # clean text
    theResponseText <- gsub("<[^>]+>.*?</[^>]+>\\n?", "", theResponseText)
    if(CustomLLMBackend == "exo"){
      theResponseText <- sub(
        "(?s).*<\\|python_tag\\|>(\\{.*?\\})<\\|eom_id\\|>.*",
        "\\1", theResponseText, perl = TRUE)
    }

    if(class(theResponseText) %in% "try-error"){
      response <- try(list("message" = NA, "status_code" = 100), TRUE)
    }
    if(!class(theResponseText) %in% "try-error"){
      response <- try(list("message" = theResponseText, "status_code" = 200), TRUE)
    }
}
  
# Initialize the agent 
if(!INITIALIZED_CUSTOM_ENV_TAG){
      INITIALIZED_CUSTOM_ENV_TAG <- TRUE
      library(reticulate)
  
      # conda create -n CustomLLMSearch python=3.13
      # conda activate CustomLLMSearch
      # pip install uv 
      # uv pip install --upgrade streamlit langchain_groq langchain_community langgraph python-dotenv langchain_openai arxiv wikipedia duckduckgo-search socksio

      # activate env 
      use_condaenv("CustomLLMSearch", required = TRUE)
      
      # load packages 
      community_utils <- import("langchain_community.utilities")
      community_tools <- import("langchain_community.tools")
      agents <- import("langgraph.prebuilt")
      MemorySaver <- import("langgraph.checkpoint.memory")$MemorySaver
      dotenv <- import("dotenv"); dotenv$load_dotenv()
      
      # define toolkit using tor 
      # brew services start tor 
      # from terminal
      Sys.setenv(http_proxy  = "socks5h://127.0.0.1:9050",
                 https_proxy = "socks5h://127.0.0.1:9050")
      rotate_tor_circuit <- function() {
        system("kill -HUP $(pgrep -x tor)")  # Send SIGHUP to Tor process
        Sys.sleep(1)  # Allow circuit rebuild
      }
      # Then in execution: rotate_tor_circuit()
      wiki <- community_tools$WikipediaQueryRun(api_wrapper = community_utils$WikipediaAPIWrapper(
                                                        top_k_results = 3L,
                                                        doc_content_chars_max = 500),
                                                verbose = FALSE,
                                                timeout = 90L,
                                                max_concurrency = 1L,
                                                proxies = list(
                                                  "http" = "socks5h://127.0.0.1:9050",
                                                  "https" = "socks5h://127.0.0.1:9050"
                                                ))
      search <- community_tools$DuckDuckGoSearchRun(name = "Search",
                                                    api_wrapper = community_utils$DuckDuckGoSearchAPIWrapper(
                                                      max_results = 3L,
                                                      safesearch = "moderate",
                                                      time = "none"
                                                    ),
                                                    doc_content_chars_max = 300L, # likely ignored 
                                                    timeout = 90L,
                                                    verbose = FALSE,
                                                    max_concurrency = 1L,
                                                    proxies = list(
                                                      "http" = "socks5h://127.0.0.1:9050",
                                                      "https" = "socks5h://127.0.0.1:9050"
                                                    )
                                                    )
      Sys.setenv(
        ALL_PROXY   = "socks5h://127.0.0.1:9050",
        HTTP_PROXY  = "socks5h://127.0.0.1:9050",
        HTTPS_PROXY = "socks5h://127.0.0.1:9050"
      )
      

      # sanity checks 
      # search$invoke("Capital of Egypt")
      
    # save tools 
    theTools <- list(wiki, search)
    #theTools <- list(search)
    #theTools <- list(wiki)
    
    if(CustomLLMBackend == "groq"){
      chat_models <- import("langchain_groq")
      theLLM <- chat_models$ChatGroq(
        groq_api_key = Sys.getenv("GROQ_API_KEY"),
        model = modelName,
        temperature = 0.01,
        streaming = TRUE
      )
    }
    if(CustomLLMBackend == "exo"){
      base_url <- system("ifconfig | grep 'inet ' | awk '{print $2}'", intern = TRUE)
      base_url <- sprintf("%s:52415", base_url[length(base_url)])
      
      exo_url <- sprintf("http://%s/v1",base_url)

      # import the ChatOpenAI class
      # https://python.langchain.com/docs/integrations/chat/
      # https://chatgpt.com/share/684ce13e-20b8-800f-b7a6-d3909cd9da02
      chat_models <- import("langchain_openai")
      source(sprintf('%s/Analysis/LLM_ExoLLMWrapper.R',LocalGitHubLoc), local = TRUE)
      
      # instantiate it against your Exo endpoint
      #theLLM <- chat_models$ChatOpenAI(
      #  model_name            = modelName,
      #  openai_api_base       = exo_url,
      #  temperature           = 0.01,
      #  streaming             = TRUE
      #)
    
      # little sanity test for the exo model 
      if(T == F){
        # extract the first generation’s text
        schema  <- import("langchain.schema",  convert = FALSE)
        sys_msg <- schema$SystemMessage(content = "You are a helpful assistant.")
        usr_msg <- schema$HumanMessage(content = "What model are you?") 
        theLLM$invoke(input = "What is the capital of Egypt?")
        (theLLM$bind_tools(theTools))$invoke(input = "What is the capital of Egypt?")
        theLLM$generate( list( list(sys_msg, usr_msg) ) )
      }
    }
    if (CustomLLMBackend == "openai") {
        # import the OpenAI chat wrapper
        chat_models <- import("langchain_openai")
        theLLM <- chat_models$ChatOpenAI(
          model_name      = modelName,
          openai_api_key  = Sys.getenv("OPENAI_API_KEY"),
          # if you have a custom API base, otherwise will default to OpenAI’s API
          openai_api_base = Sys.getenv("OPENAI_API_BASE", unset = "https://api.openai.com/v1"),
          temperature     = 0.01,
          streaming       = TRUE
        )
    }
      
    # define search 
    theAgent <- agents$create_react_agent(
                      model        = theLLM,
                      tools        = theTools,
                      checkpointer = MemorySaver(),
                  )
    
    # sanity checks
    if(T == F){
      search$description
      
      from_schema <- import("langchain_core.messages")
      thePrompt <- "What is the political party of Scott Walker?"
      thePrompt2 <- list(from_schema$HumanMessage(content = thePrompt))
   
      # probe base output with tools       
      (theLLM$bind_tools(theTools))$invoke(input = thePrompt)
      (theLLM$bind_tools(theTools))$invoke(input = thePrompt2)

      # probe interactive agent use 
      theAgent <- agents$create_react_agent(model = theLLM, tools = theTools,checkpointer = MemorySaver())
      
      theAgent$invoke(
        list(messages = list(list(role = "user", 
                                  content = thePrompt))),
        config = list(configurable = list(thread_id = "session-001"))
      )
      theAgent$invoke(
        list(messages = thePrompt2),
        config = list(configurable = list(thread_id = "session-001"))
      )
    }

    #To start tor now and restart at login:
    #  brew services start tor
    #Or, if you don't want/need a background service you can just run:
    # /opt/homebrew/opt/tor/bin/tor

    # try catches 
    if("search" %in% ls()){ 
      tryCatch({
        result <- search$invoke("scott walker age")
        print("Search working!")
        print(result)
      }, error = function(e) {
        print(paste("Search tool failing:", e$message))
      })
    }
    
    message("Done setting up Custom LLM...")
}
}
