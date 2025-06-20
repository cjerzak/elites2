# Script: LLM_Helpers.R
{
  CleanText <- function(name){
    name <- textutils::HTMLdecode(name)
    return(name)
  }
}
