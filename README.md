# elites2

Scripts and prompts for a global leadership AI agent.  The project queries
large language models to infer the ethnicity or political party of political
elites and then evaluates the results.

## Repository layout

- `Analysis/LLM_GetPredictions.R` – fetches predictions from a selected LLM
  (OpenAI, DeepSeek or a custom agent using Groq or Exo backends).
- `Analysis/LLM_AnalyzePredictions.R` – combines per‑country results and
  computes accuracy statistics.
- `Analysis/LLM_DataLocs.R` – small helper file that points to the expected
  location of the `.dta` input files.
- `Analysis/LLM_CustomLLM.R` – bridges to a Python search agent via
  `reticulate`.
- `Analysis/Prompts/` – prompt templates used for the different tasks.

Input data should live in a local `Data/` directory and output files are written
to `SavedResults/` (created automatically).  These directories are not tracked
in git.

## Setup

1. Install R (4.0 or newer) and the packages listed at the top of
   `Analysis/LLM_GetPredictions.R` (`dplyr`, `haven`, `future`, `reticulate`,
   etc.).
2. The Python environment `CustomLLMSearch` is expected when using the custom
   search agent.  Required libraries can be installed with `pip` as noted inside
 `LLM_CustomLLM.R`.
3. Create a `.env` file in the repository root with any API keys you plan to
   use.  For example:

   ```
   GROQ_API_KEY=...
   OPENAI_API_KEY=...
   DEEPSEEK_API_KEY=...
   ```
4. When using the custom agent, set `CustomLLMBackend` in
   `LLM_GetPredictions.R` to either `"groq"` or `"exo"`.

## Running the pipeline

1. Place your input `.dta` files (see `LLM_DataLocs.R` for the filenames) in the
   `Data/` directory or adjust the paths accordingly.
2. From R, run `source("Analysis/LLM_GetPredictions.R")` to generate prediction
   files under `SavedResults/`.
3. Run `source("Analysis/LLM_AnalyzePredictions.R")` to evaluate those
   predictions and produce summary metrics.

The scripts are designed for experimentation; feel free to modify the model and
prompt selections within `LLM_GetPredictions.R`.
