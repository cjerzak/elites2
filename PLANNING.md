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
- **Grok**  → enables Twitter/X  search

## Project requirements summary

- The codebase should take a simple input string representing a covariate name
  (for example, `"covar_name"`).
- Given that string, generate the prompt and predictions describing the meaning
  of the covariate.
- Use the generated prompt to impute values for all leaders in the dataset.
- Automatically evaluate the resulting predictions.
- In a later step we will add an outer loop that iterates over key columns so
  the imputation covers a single, unified dataset with evaluation metrics.
- High‑ and all‑confidence imputed data will be made publicly available on
  Hugging Face for downstream research.

