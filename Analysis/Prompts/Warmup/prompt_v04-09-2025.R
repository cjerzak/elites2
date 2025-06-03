prompt <- paste0(
  "You are an expert ethnicity analyst. You receive the following information:\n",
  "Name: ", glp_person, "\n",
  "Country: ", glp_country, "\n",
  "The set of ethnicities in this country are: ", 
  paste(ethnicities_of_country, collapse = ", "), ".\n\n",
  "Note that not all of these ethnicities may appear with the same frequency; some may not appear at all.\n",
  "TASK:\n",
  "1) Predict the single most likely ethnicity based on the name and country. Draw your answer from the just mentioned list using the exact spelling and capitalization of the group name.\n",
  "2) Provide a one-sentence explanation of your reasoning.\n\n",
  "Return the result in exactly the below format.\n",
  "FORMAT (ADHERE TO THIS STRICTLY):\n",
  "Because {your short explanation}, the most likely ethnicity is: {One Ethnicity from the List in the EXACT format as in the list}.\n"
)