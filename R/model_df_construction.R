#' Build the models configuration data frame
#'
#' Read the models configuration YAML and return a tibble used by the
#' pipeline. Validates the processing mode for each model: must be one of
#' "sequential", "parallel", or "batch" (with "batch" allowed only for
#' `chat_anthropic` and `chat_openai`). Validates `prompt_batch_size` as a
#' positive integer, defaulting to 5 when omitted.
#'
#' @param models_config_file Path to the models YAML file. Must exist and be a
#'   non-empty character scalar.
#' @return A tibble with columns `api`, `model`, `ellmer_function`,
#'   `ellmer_params`, `processing`, and `prompt_batch_size`.
#' @examples
#' \dontrun{
#' build_models_df(here::here("config", "models.yml"))
#' }
build_models_df <- function(models_config_file) {
  if (!is.character(models_config_file) || length(models_config_file) != 1 ||
      !nzchar(models_config_file)) {
    stop("models_config_file must be a non-empty character scalar")
  }
  if (!file.exists(models_config_file)) {
    stop(sprintf("models_config_file not found: %s", models_config_file))
  }

  models_config <- yaml::read_yaml(models_config_file)
  if (!is.list(models_config) || length(models_config) == 0) {
    stop("models.yml: expected a top-level mapping of APIs")
  }

  models_df <- purrr::imap_dfr(models_config, function(cfg, api) {
    ellmer_function <- cfg$ellmer_function
    if (is.null(ellmer_function)) {
      ellmer_function <- NA_character_
    }

    api_params <- cfg$params
    if (is.null(api_params)) {
      api_params <- list()
    }

    api_processing <- cfg$processing
    api_prompt_batch_size <- cfg$prompt_batch_size

    models <- cfg$models
    if (is.null(models) || length(models) == 0) {
      return(tibble::tibble())
    }

    model_rows <- lapply(models, function(model_entry) {
      if (is.character(model_entry)) {
        model_name <- model_entry
        model_params <- list()
        model_processing <- api_processing
        enabled <- TRUE
      } else {
        model_name <- model_entry$name
        if (is.null(model_name)) {
          model_name <- model_entry$model
        }
        model_params <- model_entry$params
        if (is.null(model_params)) {
          model_params <- list()
        }
        model_processing <- model_entry$processing
        enabled <- model_entry$enabled
        model_prompt_batch_size <- model_entry$prompt_batch_size
        if (is.null(enabled)) {
          enabled <- TRUE
        }
      }

      if (is.null(model_processing)) {
        model_processing <- api_processing
      }
      if (is.null(model_processing)) {
        model_processing <- "sequential"
      }
      allowed_processing <- c("sequential", "parallel", "batch")
      if (!is.character(model_processing) || length(model_processing) != 1 ||
          is.na(model_processing) || !model_processing %in% allowed_processing) {
        stop(sprintf(
          "models.yml: api '%s' model '%s' processing must be one of %s",
          api,
          model_name,
          paste(allowed_processing, collapse = ", ")
        ))
      }
      if (identical(model_processing, "batch") &&
          !ellmer_function %in% c("chat_anthropic", "chat_openai", "chat_claude", "chat_groq_developer")) {
        stop(sprintf(
          "models.yml: api '%s' model '%s' processing 'batch' is only supported for chat_anthropic, chat_claude, chat_openai, or chat_groq_developer",
          api,
          model_name
        ))
      }
      if (is.null(model_prompt_batch_size)) {
        model_prompt_batch_size <- api_prompt_batch_size
      }
      if (is.null(model_prompt_batch_size)) {
        model_prompt_batch_size <- 5L
      }
      if (!is.numeric(model_prompt_batch_size) || length(model_prompt_batch_size) != 1 ||
          is.na(model_prompt_batch_size) || model_prompt_batch_size < 1) {
        stop(sprintf(
          "models.yml: api '%s' model '%s' prompt_batch_size must be a positive number",
          api,
          model_name
        ))
      }
      model_prompt_batch_size <- as.integer(model_prompt_batch_size)

      combined_params <- api_params
      if (length(model_params) > 0) {
        combined_params <- utils::modifyList(combined_params, model_params)
      }

      tibble::tibble(
        api = api,
        model = model_name,
        ellmer_function = ellmer_function,
        ellmer_params = list(combined_params),
        processing = model_processing,
        prompt_batch_size = model_prompt_batch_size,
        enabled = enabled
      )
    })

    dplyr::bind_rows(model_rows)
  }) |>
    dplyr::filter(enabled, !is.na(model), nzchar(model)) |>
    dplyr::select(-enabled)

  models_df
}
