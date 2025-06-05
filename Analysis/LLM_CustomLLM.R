# Script: LLM_CustomLLM.R
{
# Run the agent, if initialized 
if(INITIALIZED_CUSTOM_ENV_TAG){
  # thePrompt <- "What was the *party* of the Governor of Wisconsin in 1854?"
  
  # for fast test 
  #response <- list("message" = "hi",
                   #"status_code" = 200)
    
  # Run the agent and get a response
  result <- try(search_agent$invoke(
      # the normal input dict
      list( messages = list( list(role = "user", 
                              content = thePrompt)) ),
      # the config dict expected by MemorySaver
      config = list(
        configurable = list(thread_id = "session-001")  # any string we like as ID
  ) ), TRUE)
  theResponseText <- try(result$messages[[length(result$messages)]]$text(),TRUE)
  
  # remove XML tags 
  theResponseText <- gsub("<[^>]+>.*?</[^>]+>\\n?", "", theResponseText)
  
  if(class(theResponseText) %in% "try-error"){ 
    response <- try(list("message"=NA, # NA upon failure 
                         "status_code"=100), TRUE) 
  }
  if(!class(theResponseText) %in% "try-error"){ 
    response <- try(list("message"=theResponseText, # Last AI Message,
                         "status_code"=200), TRUE) 
  }
}
  
# Initialize the agent 
if(!INITIALIZED_CUSTOM_ENV_TAG){ 
    INITIALIZED_CUSTOM_ENV_TAG <- TRUE
    library(reticulate)
    
    # conda create -n CustomLLMSearch python=3.9
    # conda activate CustomLLMSearch
    # uv pip install streamlit langchain_groq langchain_community python-dotenv arxiv wikipedia duckduckgo-search
    
    # Point to your Python environment
    use_condaenv("CustomLLMSearch", required = TRUE)
    
    # Import Python libraries
    chatg <- import("langchain_groq")
    community_utils <- import("langchain_community.utilities")
    community_tools <- import("langchain_community.tools")
    agents <- import("langgraph.prebuilt")   
    MemorySaver <- import("langgraph.checkpoint.memory")$MemorySaver  
    callbacks <- import("langchain.callbacks")
    dotenv <- import("dotenv")
    os <- import("os")
    
    # 3. Load .env variables
    dotenv$load_dotenv()
    
    # 4. Create the wrappers/tools
    arxiv <- community_tools$ArxivQueryRun(api_wrapper = community_utils$ArxivAPIWrapper(
                                                            top_k_results = 3L,
                                                            doc_content_char_max = 500L
                                                          ))
    wiki <- community_tools$WikipediaQueryRun(api_wrapper = community_utils$WikipediaAPIWrapper(
                                                      top_k_results = 3L,
                                                      doc_content_char_max = 500L
                                                    ))
    search <- community_tools$DuckDuckGoSearchRun(name = "Search")
    
    # define tools for agent 
    theTools <- list(arxiv, 
                     wiki, 
                     search)
  
    # Create the LLM
    theLLM <- chatg$ChatGroq(
      groq_api_key = os$getenv("GROQ_API_KEY"),
      model = modelName,
      temperature = 0.1,
      streaming = TRUE
    )
    
    # Initialize the agent
    search_agent <- agents$create_react_agent(  
      model       = theLLM,
      tools       = theTools,
      checkpointer = MemorySaver() # keeps dialogue state
    )
  }
}
