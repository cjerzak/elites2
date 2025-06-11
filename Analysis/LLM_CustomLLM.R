# Script: LLM_CustomLLM.R
{
# Run the agent, if initialized 
if(INITIALIZED_CUSTOM_ENV_TAG){
  if(CustomLLMBackend == "groq"){
    result <- try(search_agent$invoke(
        list(messages = list(list(role = "user", content = thePrompt))),
        config = list(configurable = list(thread_id = "session-001")), TRUE))
    theResponseText <- try(result$messages[[length(result$messages)]]$text(), TRUE)

    theResponseText <- gsub("<[^>]+>.*?</[^>]+>\\n?", "", theResponseText)

    if(class(theResponseText) %in% "try-error"){
      response <- try(list("message" = NA, "status_code" = 100), TRUE)
    }
    if(!class(theResponseText) %in% "try-error"){
      response <- try(list("message" = theResponseText, "status_code" = 200), TRUE)
    }
  }
  if(CustomLLMBackend == "exo"){
    payload <- list(
      model = modelName,
      messages = list(
        list(role = "system", content = "You are Exo."),
        list(role = "user",   content = thePrompt)
      ),
      temperature = 0.7
    )
    resp <- requests$post(exo_url, json = payload, headers = exo_headers)
    resp$raise_for_status()
    result <- resp$json()
    theResponseText <- result$choices[[1]]$message$content

    if(is.null(theResponseText)){
      response <- try(list("message" = NA, "status_code" = 100), TRUE)
    } else {
      response <- try(list("message" = theResponseText, "status_code" = 200), TRUE)
    }
  }
}
  
# Initialize the agent 
if(!INITIALIZED_CUSTOM_ENV_TAG){
    INITIALIZED_CUSTOM_ENV_TAG <- TRUE
    library(reticulate)

    # conda create -n CustomLLMSearch python=3.9
    # conda activate CustomLLMSearch
    # uv pip install streamlit langchain_groq langchain_community python-dotenv arxiv wikipedia duckduckgo-search

    use_condaenv("CustomLLMSearch", required = TRUE)

    if(CustomLLMBackend == "groq"){
      chatg <- import("langchain_groq")
      community_utils <- import("langchain_community.utilities")
      community_tools <- import("langchain_community.tools")
      agents <- import("langgraph.prebuilt")
      MemorySaver <- import("langgraph.checkpoint.memory")$MemorySaver
      callbacks <- import("langchain.callbacks")
      dotenv <- import("dotenv")
      os <- import("os")
      dotenv$load_dotenv()

      arxiv <- community_tools$ArxivQueryRun(api_wrapper = community_utils$ArxivAPIWrapper(
                                                              top_k_results = 3L,
                                                              doc_content_char_max = 500L
                                                            ))
      wiki <- community_tools$WikipediaQueryRun(api_wrapper = community_utils$WikipediaAPIWrapper(
                                                        top_k_results = 3L,
                                                        doc_content_char_max = 500L
                                                      ))
      search <- community_tools$DuckDuckGoSearchRun(name = "Search")

      theTools <- list(arxiv, wiki, search)

      theLLM <- chatg$ChatGroq(
        groq_api_key = os$getenv("GROQ_API_KEY"),
        model = modelName,
        temperature = 0.1,
        streaming = TRUE
      )

      search_agent <- agents$create_react_agent(
        model       = theLLM,
        tools       = theTools,
        checkpointer = MemorySaver()
      )
    }

    if(CustomLLMBackend == "exo"){
      requests <- import("requests")
      exo_url <- "http://localhost:52415/v1/chat/completions"
      exo_headers <- dict("Content-Type" = "application/json")
    }
  }
}
