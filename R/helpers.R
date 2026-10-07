#' Pricing for models whose provider responses do not report costs
#'
#' Per-1M-token list prices (USD) at the time of the classification runs (December 2025 - January 2026), with
#' batch discount rules. Used by [estimate_model_costs()] in both the pipeline and the public replay.
#'
#' @return A tibble with columns `model`, `input_per_m`, `output_per_m`, `cached_input_per_m`,
#'   `batch_discount_factor`, and `cache_discounts_with_batch`.
model_pricing_table <- function() {
  tibble::tribble(
    ~model, ~input_per_m, ~output_per_m, ~cached_input_per_m, ~batch_discount_factor, ~cache_discounts_with_batch,
    "openai/gpt-oss-20b", 0.075, 0.30, 0.037, 0.5, FALSE,
    "openai/gpt-oss-120b", 0.15, 0.60, 0.075, 0.5, FALSE,
    "moonshotai/kimi-k2-instruct-0905", 1.00, 3.00, 0.50, 0.5, FALSE,
    "meta-llama/llama-4-scout-17b-16e-instruct", 0.11, 0.34, NA_real_, 0.5, FALSE,
    "gemini-3-flash-preview", 0.50, 3.00, 0.05, 0.5, NA
  )
}

#' Estimate model costs from token summaries
#'
#' Aggregates token usage by model/processing and fills in missing or zero costs
#' using external pricing data. Applies batch discount rules and cached-token
#' handling for providers that do not stack batch and cache discounts.
#'
#' @param responses A data frame with `model`, `processing`, token columns, and
#'   (optionally) `cost`.
#' @param model_pricing A data frame with columns `model`, `input_per_m`,
#'   `output_per_m`, `cached_input_per_m`, `batch_discount_factor`, and
#'   `cache_discounts_with_batch`.
#'
#' @return A tibble with summed tokens and estimated costs by model/processing.
estimate_model_costs <- function(responses, model_pricing) {
  responses |>
    dplyr::group_by(model, processing) |>
    dplyr::summarise(
      dplyr::across(dplyr::matches("tokens|cost"), \(x) sum(x, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    dplyr::left_join(model_pricing, by = "model") |>
    dplyr::mutate(
      batch_discount_factor = dplyr::coalesce(batch_discount_factor, 1),
      cache_discounts_with_batch = dplyr::coalesce(cache_discounts_with_batch, TRUE),
      cached_input_per_m = dplyr::coalesce(cached_input_per_m, input_per_m),
      input_tokens = dplyr::coalesce(input_tokens, 0),
      output_tokens = dplyr::coalesce(output_tokens, 0),
      cached_input_tokens = dplyr::coalesce(cached_input_tokens, 0),
      effective_input_tokens = pmax(input_tokens - cached_input_tokens, 0),
      base_cost = (
        effective_input_tokens * input_per_m +
          cached_input_tokens * cached_input_per_m +
          output_tokens * output_per_m
      ) / 1e6,
      batch_cost = dplyr::if_else(
        cache_discounts_with_batch,
        base_cost,
        (input_tokens * input_per_m + output_tokens * output_per_m) / 1e6
      ),
      cost_estimate = dplyr::if_else(
        processing == "batch",
        batch_cost * batch_discount_factor,
        base_cost
      ),
      cost_from_estimate = (is.na(cost) | cost == 0) & !is.na(input_per_m),
      cost = dplyr::if_else(cost_from_estimate, cost_estimate, cost),
      cost = dplyr::if_else(
        processing == "batch" & !cost_from_estimate & !is.na(cost),
        cost / 2,
        cost
      )
    ) |>
    dplyr::select(
      model,
      processing,
      input_tokens,
      cached_input_tokens,
      output_tokens,
      cost
    )
}
