politics_simple_prompts_pipeline <- list(
  # ---- Filtered inputs
  tar_target(
    name = hot100_genius_sample_cleaned,
    command = hot100_genius_sample |>
      filter(
        !is.na(genius_id),
        !is.na(lyrics),
        !is.na(genius_artist),
        !is.na(genius_title)
      ),
    description = "Prompts: sample of Hot 100 lyrics successfully scraped, for testing"
  ),
  tar_target(
    name = hot100_genius_full_cleaned,
    command = hot100_genius_full |>
      filter(
        !is.na(genius_id),
        !is.na(lyrics),
        !is.na(genius_artist),
        !is.na(genius_title),
        lyrics != ""
      ),
    description = "Prompts: Hot 100 lyrics successfully scraped, full"
  ), 
  # ---- Prompt template
  tar_file(
    name = politics_simple_prompts_file,
    command = here::here("prompts", "politics-simple-prompt.md"),
    description = "Prompts: file for the simple politics prompt"
  ), 
  # ---- Raw prompt data
  tar_target(
    name = politics_simple_prompts_sample_raw,
    command = tibble(
      prompt = ellmer::interpolate_file(
        politics_simple_prompts_file,
        genius_artist = hot100_genius_sample_cleaned$genius_artist,
        genius_title = hot100_genius_sample_cleaned$genius_title,
        year = hot100_genius_sample_cleaned$year,
        lyrics = hot100_genius_sample_cleaned$lyrics
      )
    ) |>
      mutate(prompt_digest = vapply(
        prompt,
        function(single_prompt) digest::digest(single_prompt),
        character(1)
      )
    ) |>
      bind_cols(hot100_genius_sample_cleaned),
    description = "Prompts: ungrouped DF of prompts from sample of Hot 100 lyrics successfully scraped, for testing"
  ),
  tar_target(
    name = politics_simple_prompts_full_raw,
    command = tibble(
      prompt = ellmer::interpolate_file(
        politics_simple_prompts_file,
        genius_artist = hot100_genius_full_cleaned$genius_artist,
        genius_title = hot100_genius_full_cleaned$genius_title,
        year = hot100_genius_full_cleaned$year,
        lyrics = hot100_genius_full_cleaned$lyrics
      )
    ) |>
      mutate(prompt_digest = vapply(
        prompt,
        function(single_prompt) digest::digest(single_prompt),
        character(1)
      )
    ) |>
      bind_cols(hot100_genius_full_cleaned),
    description = "Prompts: ungrouped DF of prompts from full Hot 100 lyrics successfully scraped"
  ),
  # ---- Grouped prompts by model and batch
  tar_group_by(
    name = politics_simple_prompts_sample,
    command = politics_simple_prompts_sample_raw |>
      dplyr::select(-dplyr::any_of(c("batch", "tar_group"))) |>
      tidyr::crossing(models_df) |>
      dplyr::group_by(model) |>
      dplyr::mutate(
        prompt_batch_size = as.integer(prompt_batch_size),
        prompt_batch = ((dplyr::row_number() - 1) %/% prompt_batch_size) + 1L
      ) |>
      dplyr::ungroup(),
    model,
    prompt_batch,
    description = "Prompts: grouped DF of prompts from sample of Hot 100 lyrics successfully scraped, sized per model"
  ),
  tar_group_by(
    name = politics_simple_prompts_full,
    command = politics_simple_prompts_full_raw |>
      dplyr::select(-dplyr::any_of(c("batch", "tar_group"))) |>
      tidyr::crossing(models_df) |>
      dplyr::group_by(model) |>
      dplyr::mutate(
        prompt_batch_size = as.integer(prompt_batch_size),
        prompt_batch = ((dplyr::row_number() - 1) %/% prompt_batch_size) + 1L
      ) |>
      dplyr::ungroup(),
    model,
    prompt_batch,
    description = "Prompts: grouped DF of prompts from full set of Hot 100 lyrics successfully scraped, sized per model"
  )
)
