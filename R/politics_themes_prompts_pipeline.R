politics_themes_prompts_pipeline <- list(
  # ---- Prompt templates
  tar_file(
    name = politics_themes_prompts_file,
    command = here::here("prompts", "politics-themes-prompt.md"),
    description = "Prompts: file for the politics themes prompt"
  ),
  tar_file(
    name = politics_categories_extraction_prompt_file,
    command = here::here("prompts", "extract-politics-categories-prompt.md"),
    description = "Prompts: file for prompt extracting categories from the justifications"
  ),
  # ---- Category extraction prompt
  tar_target(
    name = politics_categories_extraction_prompt,
    command = ellmer::interpolate_file(
        politics_categories_extraction_prompt_file,
        justifications = clear_politics_songs |> 
          left_join(
            combined_responses_politics_simple, 
            by = join_by(prompt_digest)
          ) |> 
          filter(about_politics) |>
          mutate(justification = paste(seq_along(justification), justification, sep = ". ")) |>
          pull(justification) |>
          paste(collapse = "\n")
      ),
    description = "Prompts: long prompt for extraction of political categories"
  ), 
  # ---- Sample prompt data
  tar_target(
    name = politics_themes_prompts_sample_raw,
    command = {
      categories_md <- politics_categories |>
        dplyr::select(category, description) |>
        dplyr::mutate(
          dplyr::across(
            dplyr::everything(),
            \(x) stringr::str_replace_all(
              stringr::str_replace_all(as.character(x), "\\r?\\n", " "),
              "\\|",
              "\\\\|"
            )
          )
        )

      categories_table <- c(
        "| Category | Description |",
        "| --- | --- |",
        paste0("| ", categories_md$category, " | ", categories_md$description, " |")
      ) |>
        paste(collapse = "\n")

      sample_songs <- clear_politics_songs |>
        dplyr::slice_head(n = 10)

      tibble(
        prompt = ellmer::interpolate_file(
          politics_themes_prompts_file,
          genius_artist = sample_songs$genius_artist,
          genius_title = sample_songs$genius_title,
          year = sample_songs$year,
          lyrics = sample_songs$lyrics,
          categories = categories_table
        )
      ) |>
        mutate(prompt_digest = vapply(
          prompt,
          function(single_prompt) digest::digest(single_prompt),
          character(1)
        )
      ) |>
        bind_cols(sample_songs |>
          dplyr::select(-dplyr::any_of("prompt_digest")))
    },
    description = "Prompts: ungrouped DF of themes prompts from sample of clear politics songs"
  ),
  # ---- Grouped sample prompts by model and batch
  tar_group_by(
    name = politics_themes_prompts_sample,
    command = politics_themes_prompts_sample_raw |>
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
    description = "Prompts: grouped DF of themes prompts from sample of clear politics songs, sized per model"
  ),
  # ---- Full prompt data
  tar_target(
    name = politics_themes_prompts_full_raw,
    command = {
      categories_md <- politics_categories |>
        dplyr::select(category, description) |>
        dplyr::mutate(
          dplyr::across(
            dplyr::everything(),
            \(x) stringr::str_replace_all(
              stringr::str_replace_all(as.character(x), "\\r?\\n", " "),
              "\\|",
              "\\\\|"
            )
          )
        )

      categories_table <- c(
        "| Category | Description |",
        "| --- | --- |",
        paste0("| ", categories_md$category, " | ", categories_md$description, " |")
      ) |>
        paste(collapse = "\n")

      tibble(
        prompt = ellmer::interpolate_file(
          politics_themes_prompts_file,
          genius_artist = clear_politics_songs$genius_artist,
          genius_title = clear_politics_songs$genius_title,
          year = clear_politics_songs$year,
          lyrics = clear_politics_songs$lyrics,
          categories = categories_table
        )
      ) |>
        mutate(prompt_digest = vapply(
          prompt,
          function(single_prompt) digest::digest(single_prompt),
          character(1)
        )
      ) |>
        bind_cols(clear_politics_songs |>
          dplyr::select(-dplyr::any_of("prompt_digest")))
    },
    description = "Prompts: ungrouped DF of themes prompts for clear politics songs"
  ),
  # ---- Grouped full prompts by model and batch
  tar_group_by(
    name = politics_themes_prompts_full,
    command = politics_themes_prompts_full_raw |>
      dplyr::select(-dplyr::any_of(c("batch", "tar_group"))) |>
      tidyr::crossing(models_df) |>
      dplyr::group_by(model) |>
      dplyr::mutate(
        prompt_batch_size = as.integer(prompt_batch_size),
        prompt_batch = ((dplyr::row_number() - 1) %/% prompt_batch_size) + 1L
      ) |>
      dplyr::ungroup() |>
      filter(
        model != "gemma3:4b"
      ),
    model,
    prompt_batch,
    description = "Prompts: grouped DF of themes prompts for clear politics songs, sized per model"
  )
)
