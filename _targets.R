# Created by use_targets().
# Follow the comments below to fill in this target script.
# Then follow the manual to check and run the pipeline:
#   https://books.ropensci.org/targets/walkthrough.html#inspect-the-pipeline # nolint

# Load packages required to define the pipeline: -----
library(targets)
library(tarchetypes) 
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(groqDeveloper)

# Set target options: ------
tar_option_set(
  packages = c(
    "dplyr", "tidyr", "readr", "stringr", "httr", "janitor", "lubridate",
    "purrr", "tibble", "jsonlite", "rvest", "xml2", "yaml", "groqDeveloper"
  ), # packages that your targets need to run
  format = "rds", # default storage format
  controller = crew::crew_controller_local(
    options_local = crew::crew_options_local(here::here("logs")),
    # options_metrics = crew::crew_options_metrics(path = "/dev/stdout"),
    workers = 15,
    seconds_idle = 60
    )
  # Set other options as needed.
)

# Run the R scripts in the R/ folder with your custom functions: -----
tar_source()
# source("other_functions.R") # Source other scripts as needed. # nolint

# Target list -----
list(
  # ---- Pipeline fragments
  scraping,
  politics_simple_prompts_pipeline,
  politics_themes_prompts_pipeline,
  structured_response_objects,
  stm_pipeline,
  empath_pipeline,
  human_coding_pipeline,

  # ---- Configuration and reference data
  tar_file(
    name = models_config_file,
    command = here::here("config", "models.yml"),
    description = "Config: model definitions YAML"
  ),
  tar_group_size(
    name = models_df,
    command = build_models_df(models_config_file),
    size = 1,
    description = "Config: parsed model definitions for prompts and metadata"
  ),
  tar_target(
    name = model_pricing,
    command = tibble::tribble(
      ~model, ~input_per_m, ~output_per_m, ~cached_input_per_m, ~batch_discount_factor, ~cache_discounts_with_batch,
      "openai/gpt-oss-20b", 0.075, 0.30, 0.037, 0.5, FALSE,
      "openai/gpt-oss-120b", 0.15, 0.60, 0.075, 0.5, FALSE,
      "moonshotai/kimi-k2-instruct-0905", 1.00, 3.00, 0.50, 0.5, FALSE,
      "meta-llama/llama-4-scout-17b-16e-instruct", 0.11, 0.34, NA_real_, 0.5, FALSE,
      "gemini-3-flash-preview", 0.50, 3.00, 0.05, 0.5, NA
    ),
    description = "Pricing: per-1M token rates and discount rules for models missing cost data"
  ),
  tar_file_read(
    name = known_politics,
    command = here::here("data-raw/known_politics_songs.csv"),
    read = readr::read_csv(file = !!.x),
    description = "Reference: known political songs list"
  ),

  # ---- Sample runs and exports
  tar_frozen(tar_target(
    name = politics_simple_responses_sample,
    command = run_ellmer_chat(
      politics_simple_prompts_sample$prompt, 
      politics_simple_prompts_sample$model[[1]], 
      politics_simple_prompts_sample$ellmer_function[[1]], 
      type = structured_response_format_politics_simple, 
      processing = politics_simple_prompts_sample$processing[[1]]
    ) |> 
      left_join(models_df, by = join_by(model)),
    pattern = map(politics_simple_prompts_sample),
    description = "Sample: LLM responses for simple politics prompt"
  )),
  tar_frozen(tar_target(
    name = politics_themes_responses_sample,
    command = run_ellmer_chat(
      politics_themes_prompts_sample$prompt,
      politics_themes_prompts_sample$model[[1]],
      politics_themes_prompts_sample$ellmer_function[[1]],
      type = structured_response_format_politics_themes,
      processing = politics_themes_prompts_sample$processing[[1]]
    ) |> 
      left_join(models_df, by = join_by(model)),
    pattern = map(politics_themes_prompts_sample),
    description = "Sample: LLM responses for politics themes prompt"
  )),
  tar_target(
    name = export_politics_simple_responses_sample,
    command = write_csv(politics_simple_responses_sample, here::here("politics_simple_responses_sample.csv")),
    description = "Export: sample politics_simple responses to CSV"
  ),

  # ---- Simple politics classification
  tar_frozen(tar_target(
    name = combined_responses_politics_simple,
    command = run_ellmer_chat(
      politics_simple_prompts_full$prompt, 
      politics_simple_prompts_full$model[[1]], 
      politics_simple_prompts_full$ellmer_function[[1]], 
      type = structured_response_format_politics_simple, 
      processing = politics_simple_prompts_full$processing[[1]]
    ) |> 
      left_join(models_df, by = join_by(model)),
    pattern = map(politics_simple_prompts_full),
    error = "null",
    description = "LLM responses: full simple politics classifications"
  )),
  tar_target(
    name = combined_responses_politics_simple_enriched,
    command = left_join(
      combined_responses_politics_simple,
      politics_simple_prompts_full_raw |>
        group_by(prompt_digest) |>
        filter(match_score == min(match_score)) |>
        ungroup() |>
        filter(match_score < 0.3) |>
        distinct(prompt_digest, .keep_all = TRUE),
      by = join_by(prompt_digest)
    ),
    description = "Metadata-enriched politics_simple responses for downstream summaries"
  ),
  tar_target(
    name = combined_responses_wide_politics_simple,
    command = combined_responses_politics_simple_enriched |>
      distinct(prompt_digest, model, .keep_all = TRUE) |>
      filter(!is.na(song))  |>
      select(
        prompt_digest, prompt:year, 
        starts_with("genius_"), 
        match_score, lyrics, 
        model, about_politics, 
        justification, confidence_score
      ) |>
      pivot_wider(id_cols = prompt_digest:lyrics, names_from = "model", 
                  values_from = c(
                    about_politics, 
                    justification, 
                    confidence_score)) |>
      janitor::clean_names(),
    deployment = "main",
    description = "Wide: per-song simple politics outputs across models"
  ),
  tar_target(
    name = summarised_responses_politics_simple,
    command = combined_responses_politics_simple_enriched |>
      distinct(prompt_digest, model, .keep_all = TRUE) |>
      filter(!is.na(song)) |> 
      group_by(
        across(c(prompt_digest, song:year, 
        starts_with("genius"), lyrics))) |>
      summarise(politics = mean(about_politics, na.rm = TRUE),
                confidence_score = mean(confidence_score, na.rm = TRUE),
                num_models = sum(about_politics, na.rm = TRUE),
              .groups = "drop"),
    deployment = "main",
    description = "Summary: aggregated simple politics classifications per song"
  ),
  tar_target(
    name = clear_politics_songs,
    command = summarised_responses_politics_simple |>
      filter(num_models > (nrow(models_df) / 2)),
    deployment = "main",
    description = "Subset: songs classified as political by a model majority"
  ),

  # ---- Human coding sample
  tar_target(
    name = human_coding_sample,
    command = {
      n_models <- nrow(models_df)
      not_political <- summarised_responses_politics_simple |>
        filter(num_models == 0)
      likely_political <- summarised_responses_politics_simple |>
        filter(num_models >= n_models / 2)
      bind_rows(
        slice_sample(not_political, n = min(300, nrow(not_political))) |>
          mutate(sample_group = "not_political"),
        slice_sample(likely_political, n = min(300, nrow(likely_political))) |>
          mutate(sample_group = "likely_political")
      )
    },
    deployment = "main",
    description = "Sample: 300 non-political + 300 likely-political songs for human coding"
  ),
  tar_target(
    name = export_human_coding_sample,
    command = {
      dir.create(here::here("human-coding"), showWarnings = FALSE)
      human_coding_sample |>
        slice_sample(n = nrow(human_coding_sample)) |>
        select(prompt_digest, song, artist, year, weeks, top, genius_url, lyrics) |>
        write_csv(here::here("human-coding", "human_coding_sample.csv"))
      here::here("human-coding", "human_coding_sample.csv")
    },
    format = "file",
    description = "Export: human coding sample to CSV in human-coding/"
  ),

  # ---- Category extraction
  tar_frozen(tar_target(
    name = politics_categories,
    command = {
      chat <- ellmer::chat_openai(model = "gpt-5.2", params = ellmer::params(reasoning_effort = "high"))
      output_schema <- ellmer::type_array(ellmer::type_string())
      res <- chat$chat_structured(politics_categories_extraction_prompt, type = output_schema)
      tibble(category = paste("Category", seq_along(res)), description = res)
    },
    description = "Categories: extracted themes from model justifications"
  )),
  tar_frozen(tar_target(
    name = politics_categories_human,
    command = {
      justifications_text <- human_coding_raw |>
        filter(is_political == 1, nchar(justification) > 0) |>
        mutate(justification = paste(seq_along(justification), justification, sep = ". ")) |>
        pull(justification) |>
        paste(collapse = "\n")
      prompt <- ellmer::interpolate_file(
        politics_categories_extraction_prompt_file,
        justifications = justifications_text
      )
      chat <- ellmer::chat_openai(model = "gpt-5.2", params = ellmer::params(reasoning_effort = "high"))
      output_schema <- ellmer::type_array(ellmer::type_string())
      res <- chat$chat_structured(prompt, type = output_schema)
      tibble(category = paste("Category", seq_along(res)), description = res)
    },
    description = "Categories: extracted themes from human coder justifications"
  )),

  # ---- Politics themes classification
  tar_frozen(tar_target(
    name = combined_responses_politics_themes,
    command = run_ellmer_chat(
      politics_themes_prompts_full$prompt, 
      politics_themes_prompts_full$model[[1]], 
      politics_themes_prompts_full$ellmer_function[[1]], 
      type = structured_response_format_politics_themes, 
      processing = politics_themes_prompts_full$processing[[1]]
    ) |> 
      left_join(models_df, by = join_by(model)),
    pattern = map(politics_themes_prompts_full),
    error = "null",
    description = "LLM responses: themes extracted for political songs"
  )),
  tar_target(
    name = combined_responses_politics_themes_enriched,
    command = left_join(
      combined_responses_politics_themes,
      politics_themes_prompts_full_raw |>
        distinct(prompt_digest, .keep_all = TRUE),
      by = join_by(prompt_digest)
    ),
    description = "Metadata-enriched politics_themes responses for downstream summaries"
  ),
  tar_target(
    name = combined_responses_wide_politics_themes,
    command = combined_responses_politics_themes_enriched |>
      distinct(prompt_digest, model, .keep_all = TRUE) |>
      filter(!is.na(song))  |>
      select(
        prompt_digest, prompt:year,
        starts_with("genius_"), 
        lyrics, 
        model, themes
      ) |>
      pivot_wider(id_cols = prompt_digest:lyrics, names_from = "model", 
                  values_from = c(themes)) |>
      janitor::clean_names(),
    deployment = "main",
    description = "Wide: per-song themes across models with metadata"
  ),

  # ---- Cost summaries
  tar_target(
    name = politics_simple_costs,
    command = estimate_model_costs(
      combined_responses_politics_simple,
      model_pricing
    ),
    description = "Costs: summed tokens and costs for politics_simple responses"
  ),
  tar_target(
    name = politics_themes_cost,
    command = estimate_model_costs(
      combined_responses_politics_themes,
      model_pricing
    ),
    description = "Costs: summed tokens and costs for politics_themes responses"
  ),

  # ---- Reports
  tar_quarto(
    name = llm_classification_report,
    path = "llm_classification.qmd",
    description = "Quarto report: LLM classification analysis"
  ),
  tar_quarto(
    name = analysis_replication_report,
    path = "analysis_replication.qmd",
    description = "Quarto report: Replication of keyword/STM/Empath figures and tables"
  ),
  tar_quarto(
    name = human_classification_report,
    path = "human_classification.qmd",
    description = "Quarto report: human vs LLM classification validation"
  )
)
