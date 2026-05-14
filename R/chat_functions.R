#' Send prompts with an ellmer chat model
#'
#' Builds an ellmer chat object using the supplied provider function and
#' dispatches prompts via batch, parallel, or sequential structured chat calls.
#'
#' @param prompt A character vector, an `ellmer_prompt`, or a list of prompts.
#'   Each prompt should be a user message (or prompt object) compatible with
#'   ellmer.
#' @param model Model identifier for the provider.
#' @param ellmer_function Name of an ellmer chat function, e.g. `chat_openai`.
#' @param ellmer_params Named list of parameters passed to the chat function's
#'   `params` argument.
#' @param type A type specification created with `ellmer::type_*()` functions.
#'   Required for structured output.
#' @param processing One of "sequential" (default), "parallel", or "batch".
#'   "batch" is supported for OpenAI/Anthropic (ellmer) and Groq (custom helper).
#' @return A data frame that includes a `prompt_digest` column
#'   (via `digest::digest()`), `input_tokens`, `output_tokens`,
#'   `cached_input_tokens`, `cost`, and the structured output columns. If
#'   structured output is not tabular, it is returned in a `response` list
#'   column.
#' @examples
#' \dontrun{
#' prompts <- ellmer::interpolate("Hello {{name}}", name = c("Ada", "Linus"))
#' run_ellmer_chat(
#'   prompt = prompts,
#'   model = "gpt-4.1-nano",
#'   ellmer_function = "chat_openai",
#'   ellmer_params = list(temperature = 0.2),
#'   type = ellmer::type_array(ellmer::type_object(answer = ellmer::type_string())),
#'   batch = FALSE,
#'   parallel = TRUE
#' )
#' }
run_ellmer_chat <- function(prompt,
                            model,
                            ellmer_function,
                            ellmer_params = list(),
                            type = NULL,
                            processing = c("sequential", "parallel", "batch")) {
  processing <- match.arg(processing)
  if (!is.character(model) || length(model) != 1 || !nzchar(model)) {
    stop("model must be a non-empty character scalar")
  }
  if (!is.character(ellmer_function) || length(ellmer_function) != 1 ||
      !nzchar(ellmer_function)) {
    stop("ellmer_function must be a non-empty character scalar")
  }
  if (!is.list(ellmer_params)) {
    stop("ellmer_params must be a list")
  }
  if (is.null(type)) {
    stop("type must be supplied for structured output")
  }
  if (identical(processing, "batch") &&
      !ellmer_function %in% c("chat_anthropic", "chat_openai", "chat_claude", "chat_groq_developer")) {
    stop("processing = 'batch' is supported only for chat_claude, chat_anthropic, chat_openai, or chat_groq_developer")
  }
  # Locate the chat function either in ellmer or in groqDeveloper (if installed)
  if (exists(ellmer_function, envir = asNamespace("ellmer"), inherits = FALSE)) {
    chat_fun <- get(ellmer_function, asNamespace("ellmer"), inherits = FALSE)
  } else if (requireNamespace("groqDeveloper", quietly = TRUE) &&
             exists(ellmer_function, envir = asNamespace("groqDeveloper"), inherits = FALSE)) {
    chat_fun <- get(ellmer_function, asNamespace("groqDeveloper"), inherits = FALSE)
  } else {
    stop(sprintf("ellmer_function '%s' not found in ellmer or groqDeveloper namespaces", ellmer_function))
  }
  chat_args <- list(model = model)
  if (length(ellmer_params) > 0) {
    chat_args$params <- ellmer_params
  }
  chat <- do.call(chat_fun, chat_args)

  if (inherits(prompt, "ellmer_prompt") || is.character(prompt)) {
    prompts <- as.list(prompt)
  } else if (is.list(prompt)) {
    prompts <- prompt
  } else {
    stop("prompt must be a character vector, ellmer_prompt, or list")
  }

  prompt_digests <- vapply(
    prompts,
    function(single_prompt) digest::digest(single_prompt),
    character(1)
  )
  na_token_stats <- list(
    input_tokens = NA_real_,
    output_tokens = NA_real_,
    cached_input_tokens = NA_real_,
    cost = NA_real_
  )

  extract_token_stats <- function(chat_obj) {
    tokens <- chat_obj$get_tokens()
    if (is.data.frame(tokens) && nrow(tokens) > 0) {
      last_row <- tokens[nrow(tokens), , drop = FALSE]
      input_tokens <- if ("input" %in% names(last_row)) last_row$input[[1]] else NA_real_
      output_tokens <- if ("output" %in% names(last_row)) last_row$output[[1]] else NA_real_
      cached_input_tokens <- if ("cached_input" %in% names(last_row)) {
        last_row$cached_input[[1]]
      } else {
        NA_real_
      }
      cost <- if ("cost" %in% names(last_row)) {
        as.numeric(last_row$cost[[1]])
      } else {
        as.numeric(chat_obj$get_cost(include = "last"))
      }
      return(list(
        input_tokens = input_tokens,
        output_tokens = output_tokens,
        cached_input_tokens = cached_input_tokens,
        cost = cost
      ))
    }
    list(
      input_tokens = NA_real_,
      output_tokens = NA_real_,
      cached_input_tokens = NA_real_,
      cost = as.numeric(chat_obj$get_cost(include = "last"))
    )
  }

  append_prompt_metadata <- function(result, digest, model, token_stats) {
    input_tokens <- token_stats$input_tokens
    output_tokens <- token_stats$output_tokens
    cached_input_tokens <- token_stats$cached_input_tokens
    cost <- token_stats$cost
    if (is.list(result) && !is.data.frame(result)) {
      is_scalar <- vapply(
        result,
        function(el) is.null(el) || (length(el) == 1 && is.atomic(el)),
        logical(1)
      )
      if (length(result) > 0 && !is.null(names(result)) && all(is_scalar)) {
        result <- tibble::as_tibble(result)
      }
    }
    if (is.data.frame(result)) {
      result$prompt_digest <- rep_len(digest, nrow(result))
      result$model <- model
      result$input_tokens <- rep_len(input_tokens, nrow(result))
      result$output_tokens <- rep_len(output_tokens, nrow(result))
      result$cached_input_tokens <- rep_len(cached_input_tokens, nrow(result))
      result$cost <- rep_len(cost, nrow(result))
      return(result)
    }
    tibble::tibble(
      prompt_digest = digest,
      model = model,
      input_tokens = input_tokens,
      output_tokens = output_tokens,
      cached_input_tokens = cached_input_tokens,
      cost = cost,
      response = list(result)
    )
  }

  ensure_token_columns <- function(result) {
    if (!"input_tokens" %in% names(result)) result$input_tokens <- NA_real_
    if (!"output_tokens" %in% names(result)) result$output_tokens <- NA_real_
    if (!"cached_input_tokens" %in% names(result)) {
      result$cached_input_tokens <- NA_real_
    }
    if (!"cost" %in% names(result)) result$cost <- NA_real_
    result
  }

  normalize_token_columns <- function(result) {
    to_numeric <- function(x) {
      if (is.list(x)) {
        return(vapply(
          x,
          function(val) {
            if (length(val) == 0 || is.null(val)) {
              return(NA_real_)
            }
            as.numeric(val[[1]])
          },
          numeric(1)
        ))
      }
      as.numeric(x)
    }
    if ("input_tokens" %in% names(result)) {
      result$input_tokens <- to_numeric(result$input_tokens)
    }
    if ("output_tokens" %in% names(result)) {
      result$output_tokens <- to_numeric(result$output_tokens)
    }
    if ("cached_input_tokens" %in% names(result)) {
      result$cached_input_tokens <- to_numeric(result$cached_input_tokens)
    }
    if ("cost" %in% names(result)) {
      result$cost <- to_numeric(result$cost)
    }
    result
  }

  simplify_scalar_list_columns <- function(result, exclude = "response") {
    for (col_name in names(result)) {
      if (col_name %in% exclude) {
        next
      }
      column <- result[[col_name]]
      if (!is.list(column)) {
        next
      }
      is_scalar <- vapply(
        column,
        function(el) is.null(el) || (length(el) == 1 && is.atomic(el)),
        logical(1)
      )
      if (!all(is_scalar)) {
        next
      }
      is_logical <- vapply(column, function(el) is.null(el) || is.logical(el), logical(1))
      is_numeric <- vapply(column, function(el) is.null(el) || is.numeric(el), logical(1))
      is_character <- vapply(column, function(el) is.null(el) || is.character(el), logical(1))
      if (all(is_logical)) {
        result[[col_name]] <- vapply(
          column,
          function(el) if (is.null(el)) NA else as.logical(el),
          logical(1)
        )
      } else if (all(is_numeric)) {
        result[[col_name]] <- vapply(
          column,
          function(el) if (is.null(el)) NA_real_ else as.numeric(el),
          numeric(1)
        )
      } else if (all(is_character)) {
        result[[col_name]] <- vapply(
          column,
          function(el) if (is.null(el)) NA_character_ else as.character(el),
          character(1)
        )
      } else {
        result[[col_name]] <- vapply(
          column,
          function(el) if (is.null(el)) NA_character_ else as.character(el),
          character(1)
        )
      }
    }
    result
  }

  has_token_columns <- function(result) {
    all(c("input_tokens", "output_tokens", "cost") %in% names(result))
  }

  format_structured_results <- function(result, digests, model, token_stats) {
    if (is.data.frame(result) && length(digests) == 1) {
      result$prompt_digest <- digests[[1]]
      result$model <- model
      if (!has_token_columns(result) && length(token_stats) >= 1) {
        result$input_tokens <- token_stats[[1]]$input_tokens
        result$output_tokens <- token_stats[[1]]$output_tokens
        result$cached_input_tokens <- token_stats[[1]]$cached_input_tokens
        result$cost <- token_stats[[1]]$cost
      }
      result <- ensure_token_columns(result)
      result <- normalize_token_columns(result)
      result <- simplify_scalar_list_columns(result)
      return(result)
    }
    if (is.data.frame(result) && nrow(result) == length(digests)) {
      result$prompt_digest <- digests
      result$model <- model
      if (!has_token_columns(result) && length(token_stats) == length(digests)) {
        result$input_tokens <- vapply(token_stats, \(x) x$input_tokens, numeric(1))
        result$output_tokens <- vapply(token_stats, \(x) x$output_tokens, numeric(1))
        result$cached_input_tokens <- vapply(token_stats, \(x) x$cached_input_tokens, numeric(1))
        result$cost <- vapply(token_stats, \(x) as.numeric(x$cost), numeric(1))
      }
      result <- ensure_token_columns(result)
      result <- normalize_token_columns(result)
      result <- simplify_scalar_list_columns(result)
      return(result)
    }
    if (is.list(result) && length(result) == length(digests)) {
      rows <- Map(append_prompt_metadata, result, digests, model, token_stats)
      result <- dplyr::bind_rows(rows)
      result <- normalize_token_columns(result)
      result <- simplify_scalar_list_columns(result)
      return(result)
    }
    rows <- Map(
      append_prompt_metadata,
      rep(list(result), length(digests)),
      digests,
      rep(model, length(digests)),
      token_stats
    )
    result <- dplyr::bind_rows(rows)
    result <- normalize_token_columns(result)
    result <- simplify_scalar_list_columns(result)
    result
  }

  run_batch <- function() {
    prompt_hash <- digest::digest(prompts)
    safe_model <- gsub("[^A-Za-z0-9_.-]", "-", model)
    safe_fun <- gsub("[^A-Za-z0-9_.-]", "-", ellmer_function)
    path <- here::here(
      "data-raw",
      sprintf("ellmer-batch-%s-%s-%s.json", prompt_hash, safe_model, safe_fun)
    )
    result <- ellmer::batch_chat_structured(
      chat = chat,
      prompts = prompts,
      path = path,
      type = type,
      include_tokens = TRUE,
      include_cost = TRUE
    )
    token_stats <- rep(list(na_token_stats), length(prompts))
    format_structured_results(result, prompt_digests, model, token_stats)
  }

  run_parallel <- function() {
    result <- ellmer::parallel_chat_structured(
      chat = chat,
      prompts = prompts,
      type = type,
      include_tokens = TRUE,
      include_cost = TRUE
    )
    token_stats <- rep(list(na_token_stats), length(prompts))
    format_structured_results(result, prompt_digests, model, token_stats)
  }

  run_sequential <- function() {
    if (length(prompts) == 1) {
      result <- chat$chat_structured(prompts[[1]], type = type, convert = TRUE)
      token_stats <- extract_token_stats(chat)
      result <- append_prompt_metadata(result, prompt_digests[[1]], model, token_stats)
      result <- ensure_token_columns(result)
      result <- normalize_token_columns(result)
      result <- simplify_scalar_list_columns(result)
      return(result)
    }

    responses <- vector("list", length(prompts))
    token_stats <- vector("list", length(prompts))
    for (idx in seq_along(prompts)) {
      chat_single <- chat$clone()
      responses[[idx]] <- chat_single$chat_structured(prompts[[idx]], type = type, convert = TRUE)
      token_stats[[idx]] <- extract_token_stats(chat_single)
    }
    if (!is.null(names(prompts))) {
      names(responses) <- names(prompts)
    }
    format_structured_results(responses, prompt_digests, model, token_stats)
  }

  if (identical(processing, "batch")) {
    return(run_batch())
  }
  if (identical(processing, "parallel")) {
    return(run_parallel())
  }
  run_sequential()
}
