#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(readr)
  library(stm)
  library(stringr)
  library(targets)
  library(tibble)
  library(tidyr)
})

output_dir <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(output_dir) > 0) {
  output_dir[[1]]
} else {
  file.path("data-derived", "public")
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

write_public_pair <- function(data, stem) {
  csv_path <- file.path(output_dir, paste0(stem, ".csv"))
  rds_path <- file.path(output_dir, paste0(stem, ".rds"))

  readr::write_csv(data, csv_path, na = "")
  saveRDS(data, rds_path, version = 3)

  tibble(
    csv_file = file.path("data-derived", "public", basename(csv_path)),
    rds_file = file.path("data-derived", "public", basename(rds_path))
  )
}

assert_absent_columns <- function(data, columns, object_name) {
  present <- intersect(names(data), columns)
  if (length(present) > 0) {
    stop(
      object_name,
      " still contains excluded columns: ",
      paste(present, collapse = ", "),
      call. = FALSE
    )
  }
}

normalize_join_key <- function(x) {
  x |>
    stringr::str_to_lower() |>
    stringr::str_replace_all("[^[:alnum:]]+", " ") |>
    stringr::str_squish()
}

summarise_empath_scores <- function(data, empath_score_cols) {
  data |>
    select(any_of(c("artist", "title", empath_score_cols))) |>
    group_by(artist, title) |>
    summarise(
      across(
        all_of(empath_score_cols),
        \(x) if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE)
      ),
      .groups = "drop"
    )
}

build_empath_unique <- function(empath_results) {
  empath_results |>
    select(
      artist,
      title,
      politics,
      politics_nytimes,
      politics_reddit,
      politics_fiction,
      government,
      independence,
      violence,
      military,
      terrorism,
      law
    ) |>
    group_by(artist, title) |>
    summarise(across(where(is.numeric), ~ max(.x, na.rm = TRUE)), .groups = "drop")
}

top_empath <- function(data, column, panel) {
  data |>
    filter(.data[[column]] > 0) |>
    arrange(desc(.data[[column]])) |>
    slice_head(n = 6) |>
    transmute(
      panel,
      artist,
      title,
      score = round(.data[[column]], 3)
    )
}

message("Reading source targets...")
hot100_genius_full <- targets::tar_read(hot100_genius_full)
human_coding_raw <- targets::tar_read(human_coding_raw)
combined_responses_politics_simple <- targets::tar_read(combined_responses_politics_simple)
combined_responses_politics_simple_enriched <- targets::tar_read(combined_responses_politics_simple_enriched)
combined_responses_politics_themes_enriched <- targets::tar_read(combined_responses_politics_themes_enriched)
politics_simple_prompts_full_raw <- targets::tar_read(politics_simple_prompts_full_raw)
politics_categories <- targets::tar_read(politics_categories)
politics_categories_human <- targets::tar_read(politics_categories_human)
stm_topic_labels <- targets::tar_read(stm_topic_labels)
stm_effects <- targets::tar_read(stm_effects)
empath_results <- targets::tar_read(empath_results)

message("Building public microdata...")
coder_lookup <- tibble(coder_name = sort(unique(human_coding_raw$coder_name))) |>
  mutate(coder = paste("Coder", LETTERS[row_number()]))

human_coding_public <- human_coding_raw |>
  left_join(coder_lookup, by = "coder_name") |>
  transmute(
    prompt_digest,
    song,
    artist,
    year,
    weeks,
    top,
    coder,
    is_political = as.logical(is_political),
    confidence,
    justification
  ) |>
  arrange(prompt_digest, coder)

llm_politics_simple_public <- combined_responses_politics_simple_enriched |>
  transmute(
    prompt_digest,
    song,
    artist,
    weeks,
    top,
    year,
    genius_title,
    genius_artist,
    match_score,
    status,
    model,
    about_politics,
    confidence_score,
    justification,
    processing,
    input_tokens,
    cached_input_tokens,
    output_tokens,
    cost
  ) |>
  arrange(prompt_digest, model)

llm_politics_themes_public <- combined_responses_politics_themes_enriched |>
  transmute(
    prompt_digest,
    song,
    artist,
    year,
    model,
    themes,
    politics,
    confidence_score,
    num_models,
    processing,
    input_tokens,
    cached_input_tokens,
    output_tokens,
    cost
  ) |>
  tidyr::unnest_longer(themes, values_to = "theme", keep_empty = TRUE) |>
  mutate(theme = as.character(theme)) |>
  arrange(prompt_digest, model, theme)

politics_categories_public <- politics_categories |>
  arrange(category)

politics_categories_human_public <- politics_categories_human |>
  arrange(category)

assert_absent_columns(
  human_coding_public,
  c("coder_name", "lyrics", "prompt", "genius_url"),
  "human_coding_public"
)
assert_absent_columns(
  llm_politics_simple_public,
  c("lyrics", "prompt", "ellmer_params", ".error", "genius_url"),
  "llm_politics_simple_public"
)
assert_absent_columns(
  llm_politics_themes_public,
  c("lyrics", "prompt", "ellmer_params", "genius_url"),
  "llm_politics_themes_public"
)

message("Building lyric-derived public summaries...")
song_features_public <- hot100_genius_full |>
  mutate(
    has_lyrics = !is.na(lyrics) & lyrics != "",
    lyrics_clean = stringr::str_to_lower(coalesce(lyrics, "")),
    lyrics_clean = stringr::str_replace_all(lyrics_clean, "[^[:alnum:]]", " "),
    keyword_politics = stringr::str_detect(lyrics_clean, "\\bpolitic(s|al)\\b"),
    keyword_war = stringr::str_detect(lyrics_clean, "\\bwar(s)?\\b"),
    keyword_democracy = stringr::str_detect(lyrics_clean, "democra"),
    keyword_vote = stringr::str_detect(lyrics_clean, "\\bvote\\b|\\bvoting\\b"),
    keyword_korea = stringr::str_detect(lyrics_clean, "\\bkorea\\b"),
    keyword_vietnam = stringr::str_detect(lyrics_clean, "\\bvietnam\\b"),
    keyword_iraq = stringr::str_detect(lyrics_clean, "\\biraq\\b"),
    keyword_afghanistan = stringr::str_detect(lyrics_clean, "\\bafghan\\w*\\b")
  ) |>
  transmute(
    song,
    artist,
    weeks,
    top,
    year,
    genius_id,
    genius_title,
    genius_artist,
    match_score,
    status,
    has_lyrics,
    keyword_politics,
    keyword_war,
    keyword_democracy,
    keyword_vote,
    keyword_korea,
    keyword_vietnam,
    keyword_iraq,
    keyword_afghanistan
  ) |>
  arrange(year, artist, song)

stm_prob <- stm_topic_labels$prob
colnames(stm_prob) <- paste0("word_", seq_len(ncol(stm_prob)))
stm_topic_terms <- as_tibble(stm_prob) |>
  mutate(topic = row_number(), .before = 1)

violence_terms <- c("die", "fight", "kill", "dead", "gun", "blood", "war", "violence")
topic_scores <- apply(
  stm_topic_labels$prob,
  1,
  \(words) sum(tolower(words) %in% violence_terms)
)
violence_topic <- which.max(topic_scores)
if (length(violence_topic) == 0 || max(topic_scores) == 0) {
  violence_topic <- 70
}

# plot.estimateEffect() simulates the confidence band; fix the seed so repeated exports are identical
set.seed(14850)
stm_violence_plot_data <- plot(
  stm_effects,
  "Year",
  method = "continuous",
  topics = violence_topic,
  omit.plot = TRUE
)

stm_violence_effect_public <- tibble(
  year = stm_violence_plot_data$x,
  topic = stm_violence_plot_data$topics,
  mean = unname(stm_violence_plot_data$means[[1]]),
  lower = unname(stm_violence_plot_data$ci[[1]][1, ]),
  upper = unname(stm_violence_plot_data$ci[[1]][2, ])
)

empath_score_cols <- c(
  "politics",
  "politics_nytimes",
  "politics_reddit",
  "politics_fiction",
  "government",
  "independence",
  "violence",
  "military",
  "terrorism",
  "law"
)

empath_scores_public <- empath_results |>
  select(
    title,
    artist,
    year,
    weeks,
    top,
    all_of(empath_score_cols)
  ) |>
  arrange(year, artist, title)

empath_unique <- build_empath_unique(empath_results)

empath_top_songs <- bind_rows(
  top_empath(empath_unique, "politics", "Panel A: Politics"),
  top_empath(empath_unique, "politics_nytimes", "Panel B: Politics (NY Times)"),
  top_empath(empath_unique, "politics_reddit", "Panel C: Politics (Reddit)"),
  top_empath(empath_unique, "politics_fiction", "Panel D: Politics (Fiction)")
)

known_politics <- readr::read_csv(
  file.path("data-raw", "known_politics_songs.csv"),
  show_col_types = FALSE
)

empath_scored_filtered <- summarise_empath_scores(empath_results, empath_score_cols) |>
  mutate(
    artist_key = normalize_join_key(artist),
    title_key = normalize_join_key(title),
    source_priority = 1L
  )

empath_raw_path <- file.path("empath", "output", "empath_using_seeds.csv")
if (file.exists(empath_raw_path)) {
  empath_scored_raw <- readr::read_csv(empath_raw_path, show_col_types = FALSE) |>
    select(-1) |>
    summarise_empath_scores(empath_score_cols = empath_score_cols) |>
    mutate(
      artist_key = normalize_join_key(artist),
      title_key = normalize_join_key(title),
      source_priority = 2L
    )

  empath_scored <- bind_rows(empath_scored_filtered, empath_scored_raw)
} else {
  empath_scored <- empath_scored_filtered
}

empath_known_songs <- known_politics |>
  mutate(
    artist_key = normalize_join_key(artist),
    title_key = normalize_join_key(title)
  ) |>
  left_join(
    empath_scored |>
      arrange(artist_key, title_key, source_priority) |>
      group_by(artist_key, title_key) |>
      slice_head(n = 1) |>
      ungroup() |>
      select(-source_priority, -artist, -title),
    by = c("artist_key", "title_key")
  ) |>
  mutate(across(all_of(empath_score_cols), ~ tidyr::replace_na(.x, 0))) |>
  arrange(year, artist, title) |>
  select(
    artist,
    title,
    year,
    all_of(empath_score_cols)
  ) |>
  mutate(across(where(is.numeric), ~ round(.x, 3)))

appendix_interpretation_examples <- tribble(
  ~artist, ~title, ~year, ~model, ~political_interpretation, ~non_political_interpretation,
  "Twenty One Pilots", "Jumpsuit", 2018, "gemma3:4b", "Societal pressure interpreted as political systems", "Personal struggle; no political actors",
  "Jay-Z ft. R. Kelly", "Guilty Until Proven Innocent", 2001, "gemma3:4b", "Critique of media bias and justice system", "Personal legal issues, not politics",
  "Pearl Jam", "Given to Fly", 1998, "gemma3:4b", "Metaphors of oppression and control", "Personal resilience and symbolism",
  "Bob Dylan", "I Want You", 1966, "gemma3:4b", "References to political/social figures", "Romantic longing dominates",
  "P!nk", "Stupid Girls", 2006, "gemma3:4b", "Critique of societal values", "Cultural critique, not politics",
  "Bob Dylan", "Tangled Up in Blue", 1975, "gemma3:4b", "References to revolution and slavery", "Personal narrative",
  "James Gang", "Funk #49", 1970, "gemma3:4b", "Implied surveillance and control", "Personal behaviour",
  "Ice Cube ft. Das EFX", "Check Yo Self", 1993, "gemma3:4b", "References to policing tensions", "Street life focus",
  "Sammy Hagar", "I Can’t Drive 55", 1984, "kimi-k2", "Protest against speed limit law", "Personal frustration",
  "Imagine Dragons", "Natural", 2018, "gemma3:4b", "Themes of corrupt systems", "Individual resilience"
)

politics_simple_prompt_lookup_all <- politics_simple_prompts_full_raw |>
  distinct(prompt_digest, .keep_all = TRUE)

combined_responses_politics_simple_all_matches <- combined_responses_politics_simple |>
  distinct(prompt_digest, model, .keep_all = TRUE) |>
  left_join(politics_simple_prompt_lookup_all, by = "prompt_digest") |>
  filter(!is.na(song))

summarised_responses_politics_simple_all_matches <- combined_responses_politics_simple_all_matches |>
  group_by(prompt_digest, song, artist, year, genius_title, genius_artist, match_score) |>
  summarise(
    politics = mean(about_politics, na.rm = TRUE),
    num_models = sum(about_politics, na.rm = TRUE),
    .groups = "drop"
  )

combined_responses_wide_politics_simple_all_matches <- combined_responses_politics_simple_all_matches |>
  select(prompt_digest, model, about_politics) |>
  pivot_wider(
    id_cols = prompt_digest,
    names_from = model,
    values_from = about_politics,
    names_prefix = "about_politics_"
  ) |>
  janitor::clean_names()

politics_only_all_matches <- summarised_responses_politics_simple_all_matches |>
  left_join(combined_responses_wide_politics_simple_all_matches, by = "prompt_digest")

appendix_known_politics_classifications <- known_politics |>
  mutate(
    artist_key = normalize_join_key(artist),
    title_key = normalize_join_key(title)
  ) |>
  left_join(
    politics_only_all_matches |>
      mutate(
        artist_key = normalize_join_key(artist),
        title_key = normalize_join_key(song)
      ) |>
      arrange(artist_key, title_key, match_score) |>
      group_by(artist_key, title_key) |>
      slice_head(n = 1) |>
      ungroup() |>
      select(
        artist_key,
        title_key,
        politics,
        num_models,
        starts_with("about_politics_")
      ),
    by = c("artist_key", "title_key")
  ) |>
  select(
    artist,
    title,
    year,
    starts_with("about_politics_"),
    politics,
    num_models
  )

message("Writing public files...")
written_files <- bind_rows(
  write_public_pair(human_coding_public, "human_coding_public"),
  write_public_pair(llm_politics_simple_public, "llm_politics_simple_public"),
  write_public_pair(llm_politics_themes_public, "llm_politics_themes_public"),
  write_public_pair(politics_categories_public, "politics_categories_public"),
  write_public_pair(politics_categories_human_public, "politics_categories_human_public"),
  write_public_pair(song_features_public, "song_features_public"),
  write_public_pair(stm_topic_terms, "stm_topic_terms"),
  write_public_pair(stm_violence_effect_public, "stm_violence_effect_public"),
  write_public_pair(empath_scores_public, "empath_scores_public"),
  write_public_pair(empath_top_songs, "empath_top_songs"),
  write_public_pair(empath_known_songs, "empath_known_songs"),
  write_public_pair(appendix_known_politics_classifications, "appendix_known_politics_classifications"),
  write_public_pair(appendix_interpretation_examples, "appendix_interpretation_examples")
)

manifest <- tribble(
  ~stem, ~description, ~source_object, ~contains_full_lyrics, ~contains_lyric_quotes, ~used_for,
  "human_coding_public", "Anonymized human classifications and justifications.", "human_coding_raw", FALSE, TRUE, "Human-validation tables and appendix human-coding figures.",
  "llm_politics_simple_public", "Song-model political-content classifications, justifications, and per-response token usage and cost, without full lyrics.", "combined_responses_politics_simple_enriched", FALSE, TRUE, "Current manuscript Figures 2-6, appendix LLM and human-validation figures, and Table E1 (costs).",
  "llm_politics_themes_public", "Song-model political-theme classifications in long form; token and cost columns are per response and repeat across a response's theme rows.", "combined_responses_politics_themes_enriched", FALSE, FALSE, "Theme tables, appendix theme figures, and Table E1 (costs).",
  "politics_categories_public", "Theme-category lookup table.", "politics_categories", FALSE, FALSE, "Theme tables.",
  "politics_categories_human_public", "Human-justification category lookup table.", "politics_categories_human", FALSE, FALSE, "Human-validation appendix tables.",
  "song_features_public", "Song-level match metadata plus non-text lyric-availability and keyword indicators.", "hot100_genius_full", FALSE, FALSE, "Current manuscript Figure 1 and appendix lyric-match/keyword figures.",
  "stm_topic_terms", "Highest-probability words for STM topics.", "stm_topic_labels", FALSE, FALSE, "Current manuscript Table 2.",
  "stm_violence_effect_public", "Estimated STM violence-topic trajectory with confidence interval.", "stm_effects plus stm_topic_labels", FALSE, FALSE, "Appendix STM figure.",
  "empath_scores_public", "Row-level Empath scores for the measures used in the manuscript and appendix.", "empath_results", FALSE, FALSE, "Empath appendix figure and Empath tables.",
  "empath_top_songs", "Top-song summary for Empath political measures.", "empath_results", FALSE, FALSE, "Current manuscript Table 3.",
  "empath_known_songs", "Empath scores for the curated known-political-song list.", "empath_results plus data-raw/known_politics_songs.csv", FALSE, FALSE, "Current manuscript Table 4.",
  "appendix_known_politics_classifications", "Known-political-song classifications from the report's all-matches validation path.", "combined_responses_politics_simple plus politics_simple_prompts_full_raw", FALSE, FALSE, "Appendix Table D1.",
  "appendix_interpretation_examples", "Manually condensed interpretation examples used in Appendix Table D2.", "manual appendix curation", FALSE, FALSE, "Appendix Table D2."
) |>
  left_join(
    written_files |>
      mutate(stem = str_remove(basename(csv_file), "\\.csv$")),
    by = "stem"
  ) |>
  select(
    csv_file,
    rds_file,
    description,
    source_object,
    contains_full_lyrics,
    contains_lyric_quotes,
    used_for
  )

manifest <- bind_rows(
  tibble(
    csv_file = file.path("data-raw", "known_politics_songs.csv"),
    rds_file = NA_character_,
    description = "Curated list of known political songs.",
    source_object = "hand-curated input",
    contains_full_lyrics = FALSE,
    contains_lyric_quotes = FALSE,
    used_for = "Validation, current manuscript Table 4, and Appendix Table D1."
  ),
  manifest
)

readr::write_csv(manifest, file.path(output_dir, "manifest.csv"), na = "")

message("Public replication data written to: ", normalizePath(output_dir))
