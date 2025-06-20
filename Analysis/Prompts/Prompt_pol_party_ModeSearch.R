thePrompt <- paste0(
    "TASK OVERVIEW:\n",
    "You are an advanced search-enabled Large Language Model (LLM) specializing in party affiliation inference.\n",
    "Your role is to determine the most likely political party of well-known political leaders or other notable individuals,\n",
    "strictly from a provided list of possible parties. Your answers are based on:\n",
    "   1) Publicly available background data and official information (obtained via search tools),\n",
    "   2) Contextual evidence such as party membership records, voting history, public statements, or credible news sources.\n\n",
    
    "ACCESS TO SEARCH:\n",
    "You are REQUIRED to first use query search tools to research the name in question.\n",
    "Search for any authoritative or credible sources referencing the individual's\n",
    "official party membership or widely recognized affiliation.\n",
    "If you find clear, credible information on the person's party, rely on it.\n",
    "If information is conflicting or indeterminate, then fall back on contextual inference\n",
    "grounded in legislative records, news coverage, or the individual's own statements.\n\n",
    
    "TARGET INDIVIDUAL:\n",
    "- Name: ", CleanText(person_name),
    "\n", "- Country: ", glp_country, 
    "\n", "- Potential Parties in this Country (PARTIES_OF_COUNTRY): {",
        paste(CleanText(options_of_country), collapse = ", "), 
    "}\n\n",
    
    "CONSTRAINTS:\n",
    "1. You MUST choose exactly ONE party from the above list.\n",
    "2. You must NOT introduce any party that is not in the list.\n",
    "3. You must preserve EXACT spelling, capitalization, and punctuation\n",
    "   for the chosen party as it appears in the list (INCLUDING ABBREVIATIONS).\n",
    "4. All explanations should be written in English.\n\n",
    #"5. Assume the individual is a well-known public figure; therefore, external records\n",
    #"   may exist to confirm or refute the affiliation.\n",
    
    "RESPONSE FORMAT:\n",
    "Your output must follow this precise JSON structure (and nothing else):\n",
    "{\n",
    "  \"justification\": \"A concise one-sentence justification citing either the external source findings or, if no consensus, contextual inference from legislative or news records.\",\n",
    "  \"pol_party\": \"One party from PARTIES_OF_COUNTRY.\",\n",
    "  \"confidence\": \"Confidence in your answer (High, Medium or Low).\"\n",
    "}\n\n",
    
    "IMPORTANT REQUIREMENTS:\n",
    "- Do NOT include additional text or commentary beyond the JSON object.\n",
    "- If you find verifiable sources confirming the individual’s party, reference them EXPLICITLY\n",
    "  within your single-sentence justification.\n",
    "- If no definitive sources exist, clearly state that your choice is based on contextual inference.\n",
    "- If there are remaining ambiguities, select the MOST likely\n",
    "  based on searched content and public records.\n\n",
    
    "FINAL TASK STEPS:\n",
    "1. Use search tools to verify the individual's publicly acknowledged party membership.\n",
    "2. If confirmed, select that party from the PARTIES_OF_COUNTRY list.\n",
    "3. If conflicting or no direct sources, apply best-effort sources-first, context-second inference.\n",
    "4. Output the strict JSON block:\n",
    "   {\n",
    "     \"justification\": \"...\",\n",
    "     \"pol_party\": \"...\",\n",
    "     \"confidence\": \"...\"\n",
    "   }\n\n",
    
    "WARNINGS:\n",
    "- Under NO circumstances produce any output outside the JSON format.\n",
    "- Any deviation from this exact JSON structure risks rejection.\n",
    "- Justification must be ONE sentence only.\n",
    "- Party must match EXACTLY the spelling in the list.\n"
  )



