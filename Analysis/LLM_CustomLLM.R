# Script: LLM_CustomLLM.R
{
# Run the agent, if initialized 
if(INITIALIZED_CUSTOM_ENV_TAG){
    # thePrompt <- "What is the politicalparty of Scott Walker?"
    # (theLLM$bind_tools(theTools))$invoke(input = thePrompt)
    browser()
    raw_response <- try(theAgent$invoke(
        list(messages = list(list(role = "user", 
                                  content = thePrompt))),
             config = list(configurable = list(thread_id = "session-001"))),
        TRUE)
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
      # uv pip install --upgrade streamlit langchain_groq langchain_community langgraph python-dotenv langchain_openai arxiv wikipedia duckduckgo-search

      # activate env 
      use_condaenv("CustomLLMSearch", required = TRUE)
      
      # load packages 
      community_utils <- import("langchain_community.utilities")
      community_tools <- import("langchain_community.tools")
      agents <- import("langgraph.prebuilt")
      MemorySaver <- import("langgraph.checkpoint.memory")$MemorySaver
      dotenv <- import("dotenv"); dotenv$load_dotenv()

      arxiv <- community_tools$ArxivQueryRun(api_wrapper = community_utils$ArxivAPIWrapper(
                                                              top_k_results = 3L,
                                                              doc_content_char_max = 500L ))
      wiki <- community_tools$WikipediaQueryRun(api_wrapper = community_utils$WikipediaAPIWrapper(
                                                        top_k_results = 3L,
                                                        doc_content_char_max = 500L))
      search <- community_tools$DuckDuckGoSearchRun(name = "Search")
      
      # llm XX
      # wiki XX
      # search ? -> VPN      
      

      theTools <- list(wiki, 
                       search)

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
      #system("ifconfig | grep 'inet ' | grep -v '127.0.0.1'", intern = TRUE)
      #system("ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}'", intern = TRUE)
      
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
    message("Done setting up Custom LLM...")
}
}
