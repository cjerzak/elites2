# Task Variants

## V1
- Use names only to complete task (only use name context)
- A good baseline
- Complete this task
- Focus performing task on Africa (Kenya as starting point)

## V1.1
- Use names + marginal (i.e., baseline) probabilities to calibrate

## V2
- Use names + Google search (in an AI agent–like manner) to complete task (use name + Internet information)
- More similar to what actual RA would do
- Most costly, but more informative

### Possibilities
1. Ask the model to figure out a lot of things at once (cheaper)
2. Ask the model to figure out one thing at a time

- Compare when V1 and V2 give different answers
- First get names, then get characteristics?

## Note: LLM Providers
- **OpenAI**  → allows for search  
- **DeepSeek**  → cheap  
- **Grok**  → enables Twitter/X  

---

# Additional Context

## elites2

Scripts and prompts for a global leadership AI agent. The project queries AI agents to infer the ethnicity or political party of political elites and then evaluates the results.

### Repository Layout

- `Analysis/LLM_GetPredictions.R`  
  Fetches predictions from a selected LLM (OpenAI, DeepSeek, or a custom Groq agent).

- `Analysis/LLM_AnalyzePredictions.R`  
  Combines per-country results and computes accuracy statistics.

- `Analysis/LLM_DataLocs.R`  
  Small helper file that points to the expected location of the `.dta` input files.

- `Analysis/LLM_CustomLLM.R`  
  Bridges to a Python search agent via `reticulate`.

- `Analysis/Prompts/`  
  Prompt templates used for the different tasks.

> **Input data** should live in a local `Data/` directory and **output files** are written to `SavedResults/` (created automatically). These directories are not tracked in git.

---

## Setup

1. Install R (4.0 or newer) and the packages listed at the top of `Analysis/LLM_GetPredictions.R`  
   (e.g., `dplyr`, `haven`, `future`, `reticulate`, etc.).

2. The Python environment `CustomLLMSearch` is expected when using the custom search agent.  
   Required libraries can be installed with `pip` as noted inside `LLM_CustomLLM.R`.

3. Create a `.env` file in the repository root with any API keys you plan to use. For example:
   ```bash
   GROQ_API_KEY=...
   OPENAI_API_KEY=...
   DEEPSEEK_API_KEY=...
