human_coding_pipeline <- list(
  # ---- Input: track the export CSV as a file target
  tar_file(
    name = human_coding_export_file,
    command = here::here("human-coding", "exports", "political_coding_export_20260304_221106.csv"),
    description = "Human coding: raw export CSV file"
  ),

  # ---- Load and clean human coding data (filter to main coders only)
  tar_target(
    name = human_coding_raw,
    command = readr::read_csv(human_coding_export_file, show_col_types = FALSE) |>
      dplyr::filter(coder_name %in% c("coder_b", "coder_a")),
    description = "Human coding: loaded and filtered to the two main anonymized coders"
  ),

  # ---- Wide format: one row per song, columns per coder
  tar_target(
    name = human_coding_wide,
    command = human_coding_raw |>
      dplyr::select(prompt_digest, song, artist, year, weeks, top, coder_name, is_political, confidence) |>
      tidyr::pivot_wider(
        id_cols = c(prompt_digest, song, artist, year, weeks, top),
        names_from = coder_name,
        values_from = c(is_political, confidence)
      ) |>
      janitor::clean_names(),
    deployment = "main",
    description = "Human coding: wide format with is_political and confidence per coder"
  ),

  # ---- Combined wide: human coders + LLM classifications on the 600-song subset
  tar_target(
    name = human_llm_wide,
    command = human_coding_wide |>
      dplyr::inner_join(
        combined_responses_wide_politics_simple |>
          dplyr::select(-dplyr::any_of(c(
            "prompt", "song", "artist", "weeks", "top", "year",
            "genius_url", "genius_id", "genius_title", "genius_artist",
            "match_score", "lyrics"
          ))),
        by = "prompt_digest"
      ),
    deployment = "main",
    description = "Human coding: combined wide dataset (human + LLM) on 600-song intersection"
  ),

  # ---- Combined long format for analyses that need it
  tar_target(
    name = human_llm_long,
    command = {
      human_long <- human_coding_raw |>
        dplyr::transmute(
          prompt_digest,
          song, artist, year,
          model = coder_name,
          about_politics = as.logical(is_political),
          confidence_score = confidence,
          justification
        )
      llm_long <- combined_responses_politics_simple_enriched |>
        dplyr::filter(prompt_digest %in% human_coding_wide$prompt_digest) |>
        dplyr::distinct(prompt_digest, model, .keep_all = TRUE) |>
        dplyr::select(prompt_digest, song, artist, year, model, about_politics, confidence_score, justification)
      dplyr::bind_rows(human_long, llm_long)
    },
    deployment = "main",
    description = "Human coding: long format combining human coders and LLM responses"
  )
)
