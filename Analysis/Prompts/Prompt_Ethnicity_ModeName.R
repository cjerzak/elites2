thePrompt <- paste0(
  "You are an expert analyst specializing in ethnicity inference. You are provided with the following information:\n\n",
  "- Name: ", person_name, "\n",
  "- Country: ", glp_country, "\n",
  "- Possible ethnicities in this country (ETHNICITIES_OF_COUNTRY): {", 
                                  paste(ethnicities_of_country, collapse = ", "), "}.\n\n",
  "Important notes:\n",
  "- Ethnicities listed may vary significantly in frequency; some may be rare or nonexistent.\n",
  "- Your prediction must be strictly limited to the provided ethnicities list. Do NOT invent or use any ethnicity outside this list.\n",
  "- Adhere EXACTLY to the spelling, capitalization, and punctuation provided in the ethnicity list (ETHNICITIES_OF_COUNTRY).\n\n",
  "TASK:\n",
  "1. Predict the SINGLE most likely ethnicity for the given name and country.\n",
  "2. Provide a brief, one-sentence justification emphasizing linguistic, historical, or cultural reasoning related to the name and country.\n\n",
  "CRITICAL FORMAT REQUIREMENT (STRICT ADHERENCE MANDATORY):\n",
  "Respond ONLY in valid JSON format exactly as shown below:\n",
  "{\n",
  "  \"justification\": \"Your concise one-sentence justification emphasizing linguistic, historical, or cultural reasoning related to the name and country.\"\n",
  "  \"ethnicity\": \"Ethnicity EXACTLY as listed in ETHNICITIES_OF_COUNTRY\"\n",
  "  \"confidence\": \"Confidence in your answer here\"\n",
  "}\n\n",
  "WARNINGS:\n",
  "- Do NOT deviate from the required JSON format under any circumstances.\n",
  "- Responses not matching this exact JSON format will be rejected.\n",
  "- Ensure your justification clearly connects the name with linguistic, historical, or cultural factors specific to the country provided.\n"
)


# answer before justification
# This ordering is especially effective because it reinforces structured thinking
# —first pinpointing a decision, then explicitly rationalizing it, 
# rather than allowing extended reasoning that might bias or distract
# from a definitive prediction.

# most basic approach: just use name, country to predict X 

