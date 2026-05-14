#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(corrr)
  library(dplyr)
  library(forcats)
  library(ggplot2)
  library(ggridges)
  library(irr)
  library(irrCAC)
  library(mirt)
  library(purrr)
  library(readr)
  library(scales)
  library(stringr)
  library(tibble)
  library(tidyr)
})

public_dir <- file.path("data-derived", "public")
figure_dir <- file.path("results", "public", "figures")
table_dir <- file.path("results", "public", "tables")

dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

read_public_csv <- function(stem) {
  path <- file.path(public_dir, paste0(stem, ".csv"))
  if (!file.exists(path)) {
    stop("Missing public data file: ", path, call. = FALSE)
  }
  readr::read_csv(path, show_col_types = FALSE)
}

save_plot <- function(plot, filename, width, height) {
  ggplot2::ggsave(
    filename = file.path(figure_dir, filename),
    plot = plot,
    width = width,
    height = height,
    dpi = 300
  )
}

write_table <- function(data, filename) {
  readr::write_csv(data, file.path(table_dir, filename), na = "")
}

format_score_column <- function(x) {
  if (all(x == floor(x), na.rm = TRUE)) {
    sprintf("%.0f", x)
  } else {
    sprintf("%.3f", x)
  }
}

topic_effect_plot <- function(data) {
  ggplot(data, aes(x = year, y = mean)) +
    geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.2) +
    geom_line(linewidth = 0.7) +
    labs(
      x = "Year",
      y = "Estimated topic proportion",
      title = paste0("Conflict and Violence Topic (Topic ", unique(data$topic), ")")
    ) +
    theme_bw()
}

cutpoints <- function(model, type = "score") {
  stopifnot(class(model) == "SingleGroupClass")

  type <- match.arg(type, c("score", "discrimination"))

  coefs <- as.data.frame(mirt::coef(model, as.data.frame = TRUE))
  coefs <- coefs |>
    mutate(
      variable = rownames(coefs),
      coef_type = stringr::str_extract(variable, "a([0-9]+)?$|d([0-9]+)?$"),
      variable = stringr::str_replace(variable, "\\.a([0-9]+)?$|\\.d([0-9]+)?$", "")
    ) |>
    group_by(variable) |>
    mutate(
      estimate = par / -par[1],
      pct975 = CI_2.5 / -CI_2.5[1],
      pct025 = CI_97.5 / -CI_97.5[1],
      se = abs(pct975 - estimate) / 1.96
    ) |>
    filter(!is.na(coef_type))

  num_obs <- model@Data$data |>
    as_tibble() |>
    summarise(across(everything(), ~ sum(!is.na(.x)))) |>
    pivot_longer(everything(), names_to = "variable", values_to = "num_obs")

  coefs <- coefs |>
    left_join(num_obs, by = "variable")

  if (type == "score") {
    coefs |>
      filter(!grepl("^a", coef_type)) |>
      select(variable, estimate, pct025, pct975, se, num_obs) |>
      ungroup()
  } else {
    coefs |>
      filter(grepl("^a", coef_type)) |>
      mutate(
        estimate = par,
        pct025 = CI_2.5,
        pct975 = CI_97.5
      ) |>
      select(variable, estimate, pct025, pct975, num_obs) |>
      ungroup()
  }
}

song_features_public <- read_public_csv("song_features_public") |>
  mutate(
    has_lyrics = as.logical(has_lyrics),
    across(starts_with("keyword_"), as.logical)
  )
llm_politics_simple_public <- read_public_csv("llm_politics_simple_public") |>
  mutate(
    about_politics = as.logical(about_politics),
    confidence_score = as.numeric(confidence_score)
  )
llm_politics_themes_public <- read_public_csv("llm_politics_themes_public")
politics_categories_public <- read_public_csv("politics_categories_public")
politics_categories_human_public <- read_public_csv("politics_categories_human_public")
human_coding_public <- read_public_csv("human_coding_public") |>
  mutate(is_political = as.logical(is_political))
stm_topic_terms <- read_public_csv("stm_topic_terms")
stm_violence_effect_public <- read_public_csv("stm_violence_effect_public")
empath_scores_public <- read_public_csv("empath_scores_public")
empath_top_songs <- read_public_csv("empath_top_songs")
empath_known_songs <- read_public_csv("empath_known_songs")
appendix_known_politics_classifications <- read_public_csv("appendix_known_politics_classifications") |>
  mutate(across(starts_with("about_politics_"), as.logical))
appendix_interpretation_examples <- read_public_csv("appendix_interpretation_examples")

theme_display_labels <- tibble::tribble(
  ~theme, ~category_display,
  "Category 1", "Environmental degradation & climate change",
  "Category 2", "War, militarism & foreign policy",
  "Category 3", "Racism, civil rights & racial justice",
  "Category 4", "Economic inequality & class struggle",
  "Category 5", "Government corruption",
  "Category 6", "Authoritarianism & repression",
  "Category 7", "National identity & nationalism",
  "Category 8", "Political polarization",
  "Category 9", "Media manipulation",
  "Category 10", "Immigration & displacement",
  "Category 11", "Social welfare & public services",
  "Category 12", "Gender & sexuality rights"
)

model_display_labels <- tibble::tribble(
  ~model, ~model_display,
  "gemini_3_flash_preview", "Gemini 3 Flash Preview",
  "gemma3_4b", "Gemma 3 (4B)",
  "moonshotai_kimi_k2_instruct_0905", "MoonshotAI Kimi K2 Instruct (0905)",
  "gpt_5_mini", "GPT-5 Mini",
  "gpt_5_nano", "GPT-5 Nano",
  "claude_haiku_4_5_20251001", "Claude Haiku 4.5 (2025-10-01)",
  "meta_llama_llama_4_scout_17b_16e_instruct", "LLaMA 4 Scout (17B, 16e Instruct)",
  "openai_gpt_oss_120b", "OpenAI GPT OSS (120B)",
  "openai_gpt_oss_20b", "OpenAI GPT OSS (20B)"
)

table_5_model_order <- c(
  "claude-haiku-4-5-20251001",
  "gemini-3-flash-preview",
  "gemma3:4b",
  "gpt-5-mini",
  "gpt-5-nano",
  "meta-llama/llama-4-scout-17b-16e-instruct",
  "moonshotai/kimi-k2-instruct-0905",
  "openai/gpt-oss-120b",
  "openai/gpt-oss-20b"
)

matched_song_features <- song_features_public |>
  filter(has_lyrics, !is.na(match_score), match_score < 0.3)

keyword_labels <- c(
  keyword_politics = "Politics / Political",
  keyword_war = "War",
  keyword_democracy = "Democra*",
  keyword_vote = "Vote / Voting"
)

country_keyword_labels <- c(
  keyword_korea = "Korea",
  keyword_vietnam = "Vietnam",
  keyword_iraq = "Iraq",
  keyword_afghanistan = "Afghanistan"
)

main_keyword_series <- matched_song_features |>
  select(year, all_of(names(keyword_labels))) |>
  pivot_longer(
    cols = -year,
    names_to = "keyword",
    values_to = "present"
  ) |>
  mutate(label = recode(keyword, !!!keyword_labels)) |>
  group_by(label, year) |>
  summarise(prop = mean(present, na.rm = TRUE), .groups = "drop")

figure_1 <- main_keyword_series |>
  ggplot(aes(x = year, y = prop)) +
  geom_line() +
  facet_wrap(~label, ncol = 2, scales = "free_y") +
  scale_y_continuous(labels = scales::percent) +
  labs(x = "Year", y = "Proportion of songs") +
  theme_bw()

save_plot(figure_1, "figure_1_keyword_politics.png", 8, 6)

appendix_missing_lyrics <- song_features_public |>
  group_by(year) |>
  summarise(missing = mean(!has_lyrics), .groups = "drop") |>
  ggplot(aes(x = year, y = missing)) +
  geom_line() +
  scale_y_continuous(labels = scales::percent) +
  labs(x = "Year", y = "Proportion missing")

save_plot(appendix_missing_lyrics, "appendix_missing_lyrics_by_year.png", 8, 5)

appendix_keyword_countries <- matched_song_features |>
  select(year, all_of(names(country_keyword_labels))) |>
  pivot_longer(
    cols = -year,
    names_to = "keyword",
    values_to = "present"
  ) |>
  mutate(label = recode(keyword, !!!country_keyword_labels)) |>
  group_by(label, year) |>
  summarise(prop = mean(present, na.rm = TRUE), .groups = "drop") |>
  ggplot(aes(x = year, y = prop)) +
  geom_line() +
  facet_wrap(~label, ncol = 2) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 0.01)) +
  labs(x = "Year", y = "Proportion of songs") +
  theme_bw()

save_plot(appendix_keyword_countries, "appendix_country_keyword_search.png", 8, 6)

appendix_match_counts <- song_features_public |>
  ggplot(aes(x = year, fill = as.factor(round(match_score, digits = 1)))) +
  geom_bar(width = 1) +
  labs(fill = "Match distance", y = "") +
  scale_fill_viridis_d(na.value = "grey50") +
  scale_y_continuous()

save_plot(appendix_match_counts, "appendix_match_counts_by_score.png", 8, 5)

appendix_match_proportions <- song_features_public |>
  ggplot(aes(x = year, fill = as.factor(round(match_score, digits = 1)))) +
  geom_bar(width = 1, position = "fill") +
  labs(fill = "Match distance", y = "") +
  scale_fill_viridis_d(na.value = "grey50") +
  scale_y_continuous(labels = scales::label_percent())

save_plot(appendix_match_proportions, "appendix_match_proportions_by_score.png", 8, 5)

appendix_stm_violence <- topic_effect_plot(stm_violence_effect_public)
save_plot(appendix_stm_violence, "appendix_stm_violence_over_time.png", 8, 5)

appendix_empath_over_time <- bind_rows(
  empath_scores_public |> filter(politics > 0) |> count(year) |> mutate(category = "Politics"),
  empath_scores_public |> filter(politics_nytimes > 0) |> count(year) |> mutate(category = "Politics (NYTimes)"),
  empath_scores_public |> filter(politics_reddit > 0) |> count(year) |> mutate(category = "Politics (Reddit)"),
  empath_scores_public |> filter(politics_fiction > 0) |> count(year) |> mutate(category = "Politics (Fiction)")
) |>
  ggplot(aes(x = year, y = n)) +
  geom_line() +
  facet_wrap(~category, ncol = 2, scales = "free_y") +
  labs(x = "Year", y = "Songs with non-zero score")

save_plot(appendix_empath_over_time, "appendix_empath_over_time.png", 8, 6)

analysis_simple <- llm_politics_simple_public |>
  filter(match_score < 0.3)

figure_2 <- analysis_simple |>
  group_by(year, model) |>
  summarise(avg = mean(about_politics, na.rm = TRUE), .groups = "drop") |>
  ggplot(aes(x = year, y = avg)) +
  geom_line(aes(color = model)) +
  stat_summary() +
  scale_y_continuous(labels = scales::percent) +
  labs(y = "Proportion of songs with political content") +
  scale_color_viridis_d()

save_plot(figure_2, "figure_2_yearly_politics_by_model.png", 8, 5)

simple_wide <- analysis_simple |>
  distinct(prompt_digest, model, .keep_all = TRUE) |>
  select(prompt_digest, model, about_politics) |>
  pivot_wider(names_from = model, values_from = about_politics) |>
  janitor::clean_names()

figure_3 <- simple_wide |>
  select(-prompt_digest) |>
  mutate(across(everything(), as.numeric)) |>
  corrr::correlate() |>
  corrr::rplot(print_cor = TRUE) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

save_plot(figure_3, "figure_3_model_correlations.png", 8, 6)

appendix_discrimination_model <- mirt::mirt(
  simple_wide |>
    select(-prompt_digest) |>
    mutate(across(everything(), as.numeric)),
  model = 1,
  itemtype = "2PL",
  SE = TRUE,
  verbose = FALSE
)

appendix_discrimination <- cutpoints(appendix_discrimination_model, type = "discrimination") |>
  mutate(variable = str_remove_all(variable, "about_politics_") |>
           str_replace_all("\\.", "-")) |>
  ggplot(aes(x = reorder(variable, estimate), y = estimate, ymin = pct025, ymax = pct975)) +
  labs(
    x = "",
    y = "Discrimination parameter for each model\n(higher value means fewer idiosyncratic\nerrors relative to latent score)"
  ) +
  geom_point() +
  geom_errorbar() +
  coord_flip()

save_plot(appendix_discrimination, "appendix_llm_discrimination.png", 8, 5)

figure_4 <- analysis_simple |>
  filter(!is.na(about_politics)) |>
  group_by(model, about_politics) |>
  summarise(avg = mean(confidence_score, na.rm = TRUE), .groups = "drop") |>
  mutate(classification = if_else(about_politics, "Political", "Non-political")) |>
  ggplot(aes(x = avg, y = forcats::fct_reorder(model, avg), color = classification)) +
  geom_line(aes(group = model), color = "grey70", linewidth = 0.4) +
  geom_point(size = 2.5) +
  scale_x_continuous(labels = scales::percent) +
  labs(x = "Average confidence", y = "", color = "") +
  coord_cartesian(xlim = c(0.5, 1))

save_plot(figure_4, "figure_4_average_confidence_by_model.png", 8, 5)

figure_5 <- analysis_simple |>
  distinct(prompt_digest, model, .keep_all = TRUE) |>
  group_by(prompt_digest) |>
  mutate(num_models = sum(about_politics, na.rm = TRUE)) |>
  ungroup() |>
  filter(num_models > 0, about_politics) |>
  ggplot(aes(y = num_models, x = confidence_score)) +
  geom_count(aes(color = model), position = "jitter", alpha = 0.2) +
  stat_summary() +
  geom_smooth() +
  labs(
    y = "Number of models classifying a song as political",
    x = "Confidence level",
    size = "Number of songs"
  ) +
  scale_color_viridis_d()

save_plot(figure_5, "figure_5_confidence_by_agreement.png", 8, 5)

figure_6 <- analysis_simple |>
  group_by(year, model) |>
  summarise(avg = weighted.mean(about_politics, confidence_score, na.rm = TRUE), .groups = "drop") |>
  ggplot(aes(x = year, y = avg)) +
  geom_line(aes(color = model, linetype = model)) +
  stat_summary() +
  scale_y_continuous(labels = scales::percent) +
  labs(y = "Proportion of songs about politics,\nweighted by confidence") +
  scale_color_viridis_d()

save_plot(figure_6, "figure_6_confidence_weighted_politics.png", 8, 5)

appendix_density_politics <- analysis_simple |>
  group_by(prompt_digest, year, song, artist) |>
  summarise(politics = weighted.mean(about_politics, confidence_score, na.rm = TRUE), .groups = "drop") |>
  filter(politics > 0.8) |>
  ggplot(aes(x = year)) +
  geom_density() +
  labs(y = "Distribution of most clearly political songs")

save_plot(appendix_density_politics, "appendix_density_politics_per_year.png", 8, 5)

appendix_popularity <- analysis_simple |>
  filter(!is.na(about_politics)) |>
  ggplot(aes(x = year, y = weeks, color = as.factor(about_politics))) +
  geom_count(position = "jitter", alpha = 0.2) +
  geom_smooth() +
  scale_color_viridis_d() +
  scale_y_log10() +
  labs(y = "Weeks on the Billboard chart", color = "About politics?")

save_plot(appendix_popularity, "appendix_popularity.png", 8, 5)

theme_data <- llm_politics_themes_public |>
  filter(!is.na(theme)) |>
  left_join(
    politics_categories_public |>
      rename(theme = category),
    by = "theme"
  ) |>
  mutate(category = paste(theme, description, sep = ": "))

appendix_theme_distribution_per_model <- theme_data |>
  mutate(theme = fct_infreq(theme)) |>
  ggplot(aes(fill = theme, x = model)) +
  geom_bar(position = "fill") +
  scale_fill_viridis_d() +
  scale_y_continuous(labels = scales::percent_format()) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(y = "", c = "")

save_plot(appendix_theme_distribution_per_model, "appendix_theme_distribution_per_model.png", 8, 5)

appendix_theme_distribution <- theme_data |>
  distinct(prompt_digest, model, theme, .keep_all = TRUE) |>
  filter(!is.na(song)) |>
  ggplot(aes(x = year, y = fct_reorder(category, year))) +
  stat_density_ridges() +
  labs(y = "")

save_plot(appendix_theme_distribution, "appendix_theme_distribution.png", 8, 9)

appendix_theme_distribution_per_model_ridges <- theme_data |>
  distinct(prompt_digest, model, theme, .keep_all = TRUE) |>
  filter(!is.na(song)) |>
  ggplot(aes(x = year, y = fct_reorder(category, year))) +
  stat_density_ridges() +
  facet_wrap(~model) +
  labs(y = "")

save_plot(
  appendix_theme_distribution_per_model_ridges,
  "appendix_theme_distribution_per_model_ridges.png",
  10,
  10
)

empath_unique <- empath_scores_public |>
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

top_empath <- function(column, panel) {
  empath_unique |>
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

appendix_empath_top_songs_expanded <- bind_rows(
  top_empath("government", "Panel A: Government"),
  top_empath("independence", "Panel B: Independence"),
  top_empath("violence", "Panel C: Violence"),
  top_empath("military", "Panel D: Military"),
  top_empath("terrorism", "Panel E: Terrorism"),
  top_empath("law", "Panel F: Law")
)

table_2 <- stm_topic_terms |>
  mutate(
    word_2 = if_else(
      topic %in% c(
        1:18,
        20:28,
        32,
        50,
        52:54,
        58,
        60,
        62,
        65,
        67:71
      ),
      str_to_title(word_2),
      word_2
    ),
    across(
      starts_with("word_"),
      \(x) if_else(x == "nigga", "n****", x)
    )
  )

write_table(table_2, "table_2_stm_topic_terms.csv")
table_3 <- empath_top_songs |>
  mutate(
    panel = recode(
      panel,
      "Panel B: Politics (NY Times)" = "Panel B: Politics NYT",
      "Panel C: Politics (Reddit)" = "Panel C: Politics Reddit",
      "Panel D: Politics (Fiction)" = "Panel D: Politics Fiction"
    ),
    title = str_replace_all(title, "We're", "We’re"),
    score = sprintf("%.3f", score)
  )

write_table(table_3, "table_3_empath_top_songs.csv")

table_4 <- empath_known_songs |>
  mutate(
    title = str_replace_all(
      title,
      c(
        "Don't" = "Don’t",
        "What's" = "What’s"
      )
    ),
    across(
      c(
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
      ),
      format_score_column
    )
  )

write_table(table_4, "table_4_empath_known_songs.csv")
write_table(appendix_empath_top_songs_expanded, "appendix_empath_top_songs_expanded.csv")

appendix_d1 <- appendix_known_politics_classifications |>
  transmute(
    Artist = artist,
    title = str_replace_all(
      title,
      c(
        "Don't" = "Don’t",
        "What's" = "What’s",
        "Mr\\. Wendal" = "Mr.\u00a0Wendal"
      )
    ),
    `Claude H4.5` = about_politics_claude_haiku_4_5_20251001,
    `Gemini 3F` = about_politics_gemini_3_flash_preview,
    `Gemma3 4B` = about_politics_gemma3_4b,
    `GPT-5 Mini` = about_politics_gpt_5_mini,
    `GPT-5 Nano` = about_politics_gpt_5_nano,
    `Llama4 Scout` = about_politics_meta_llama_llama_4_scout_17b_16e_instruct,
    `Kimi K2` = about_politics_moonshotai_kimi_k2_instruct_0905,
    `GPT-OSS120B` = about_politics_openai_gpt_oss_120b,
    `GPT-OSS20B` = about_politics_openai_gpt_oss_20b,
    politics = sprintf("%.7f", politics),
    num_models
  )

write_table(
  appendix_d1,
  "appendix_table_d1_known_politics_classifications.csv"
)

appendix_d2 <- appendix_interpretation_examples |>
  transmute(
    Artist = artist,
    Title = title,
    Year = as.integer(year),
    Model = model,
    `Political Interpretation` = political_interpretation,
    `Non-Political Interpretation` = non_political_interpretation
  )

write_table(
  appendix_d2,
  "appendix_table_d2_interpretation_examples.csv"
)

table_5 <- analysis_simple |>
  group_by(model) |>
  summarise(
    total_songs_identified = sum(about_politics, na.rm = TRUE),
    percent = round(100 * mean(about_politics, na.rm = TRUE), 2),
    .groups = "drop"
  ) |>
  mutate(model = factor(model, levels = table_5_model_order)) |>
  arrange(model) |>
  mutate(model = as.character(model))

write_table(table_5, "table_5_songs_about_politics.csv")

table_6 <- llm_politics_themes_public |>
  filter(!is.na(theme)) |>
  mutate(theme = forcats::fct_lump(theme, n = 10)) |>
  left_join(
    politics_categories_public |>
      rename(theme = category),
    by = "theme"
  ) |>
  mutate(
    category = if_else(
      theme == "Other",
      "Other / NA",
      description
    )
  ) |>
  count(category, name = "n") |>
  mutate(percent = round(100 * n / sum(n), 1)) |>
  arrange(desc(n))

write_table(table_6, "table_6_theme_categories.csv")

base_ids <- llm_politics_themes_public |>
  distinct(prompt_digest, model)

theme_presence <- llm_politics_themes_public |>
  filter(!is.na(theme)) |>
  distinct(prompt_digest, model, theme) |>
  mutate(present = 1L)

table_7 <- sort(unique(theme_presence$theme)) |>
  map_dfr(\(th) {
    theme_matrix <- base_ids |>
      left_join(
        theme_presence |>
          filter(theme == th) |>
          select(prompt_digest, model, present),
        by = c("prompt_digest", "model")
      ) |>
      mutate(present = tidyr::replace_na(present, 0L)) |>
      pivot_wider(
        names_from = model,
        values_from = present,
        values_fill = 0L
      ) |>
      select(-prompt_digest)

    kappa_est <- irrCAC::fleiss.kappa.raw(theme_matrix)$est

    tibble(
      theme = th,
      kappa_value = kappa_est$coeff.val,
      conf_int = stringr::str_replace_all(kappa_est$conf.int, ",", ", ")
    )
  }) |>
  left_join(theme_display_labels, by = "theme") |>
  arrange(desc(kappa_value)) |>
  transmute(
    category = category_display,
    kappa = sprintf("%.2f", kappa_value),
    conf_int
  )

write_table(table_7, "table_7_theme_agreement.csv")

human_wide <- human_coding_public |>
  select(prompt_digest, song, artist, year, weeks, top, coder, is_political) |>
  pivot_wider(
    names_from = coder,
    values_from = is_political,
    names_prefix = "is_political_"
  ) |>
  janitor::clean_names()

human_cols <- names(human_wide) |>
  stringr::str_subset("^is_political_")

llm_validation_wide <- analysis_simple |>
  filter(prompt_digest %in% human_wide$prompt_digest) |>
  distinct(prompt_digest, model, .keep_all = TRUE) |>
  select(prompt_digest, model, about_politics) |>
  pivot_wider(names_from = model, values_from = about_politics, names_prefix = "about_politics_") |>
  janitor::clean_names()

human_llm_wide_public <- human_wide |>
  left_join(llm_validation_wide, by = "prompt_digest")

agreement_matrix <- human_llm_wide_public |>
  select(all_of(human_cols), starts_with("about_politics_")) |>
  mutate(across(everything(), as.numeric))

appendix_human_llm_corr <- agreement_matrix |>
  rename_with(\(x) str_remove_all(x, "about_politics_|is_political_")) |>
  corrr::correlate() |>
  corrr::rplot(print_cor = TRUE) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

save_plot(appendix_human_llm_corr, "appendix_human_llm_correlations.png", 8, 6)

appendix_human_irt_model <- mirt::mirt(
  agreement_matrix,
  model = 1,
  itemtype = "Rasch",
  SE = TRUE,
  verbose = FALSE
)

appendix_human_irt <- as.data.frame(mirt::coef(appendix_human_irt_model, as.data.frame = TRUE)) |>
  rownames_to_column("variable") |>
  filter(str_detect(variable, "\\.d$")) |>
  mutate(
    rater = str_remove(variable, "\\.d$") |>
      str_remove_all("about_politics_|is_political_") |>
      str_replace_all("\\.", "-"),
    estimate = par,
    pct025 = CI_2.5,
    pct975 = CI_97.5
  ) |>
  ggplot(aes(x = reorder(rater, estimate), y = estimate, ymin = pct025, ymax = pct975)) +
  labs(x = "", y = "Difficulty parameter\n(higher = more liberal political classification threshold)") +
  geom_point() +
  geom_errorbar(width = 0.3) +
  coord_flip()

save_plot(appendix_human_irt, "appendix_human_irt.png", 8, 6)

appendix_human_confidence <- human_coding_public |>
  ggplot(aes(x = confidence, fill = as.factor(is_political))) +
  geom_histogram(binwidth = 0.1, position = "dodge") +
  facet_wrap(~coder) +
  scale_fill_viridis_d() +
  labs(x = "Confidence", y = "Count", fill = "Political")

save_plot(appendix_human_confidence, "appendix_human_confidence.png", 8, 5)

human_with_llm_counts <- human_llm_wide_public |>
  mutate(llm_political_count = rowSums(across(starts_with("about_politics_")), na.rm = TRUE)) |>
  select(prompt_digest, llm_political_count)

appendix_human_confidence_vs_llm <- human_coding_public |>
  inner_join(human_with_llm_counts, by = "prompt_digest") |>
  ggplot(aes(x = llm_political_count, y = confidence, color = as.factor(is_political))) +
  geom_jitter(alpha = 0.3, width = 0.2) +
  geom_smooth(method = "loess") +
  facet_wrap(~coder) +
  scale_color_viridis_d() +
  labs(
    x = "Number of LLMs classifying song as political",
    y = "Human confidence",
    color = "Human: political"
  )

save_plot(
  appendix_human_confidence_vs_llm,
  "appendix_human_confidence_vs_llm_agreement.png",
  8,
  5
)

human_long <- human_coding_public |>
  transmute(
    prompt_digest,
    song,
    artist,
    year,
    model = coder,
    about_politics = is_political,
    confidence_score = confidence,
    justification
  )

llm_validation_long <- analysis_simple |>
  filter(prompt_digest %in% human_wide$prompt_digest) |>
  transmute(
    prompt_digest,
    song,
    artist,
    year,
    model,
    about_politics,
    confidence_score,
    justification
  )

human_llm_long_public <- bind_rows(human_long, llm_validation_long)

appendix_yearly_human_llm <- human_llm_long_public |>
  mutate(source = if_else(str_detect(model, "^Coder "), "Human", "LLM")) |>
  group_by(year, model, source) |>
  summarise(avg = mean(about_politics, na.rm = TRUE), .groups = "drop") |>
  ggplot(aes(x = year, y = avg, color = model, linetype = source)) +
  geom_line() +
  stat_summary(
    aes(group = source),
    fun = mean,
    geom = "line",
    linewidth = 1.2,
    linetype = "solid",
    alpha = 0.5
  ) +
  scale_y_continuous(labels = scales::percent) +
  scale_color_viridis_d() +
  labs(y = "Proportion classified as political", x = "Year")

save_plot(appendix_yearly_human_llm, "appendix_yearly_human_llm.png", 8, 5)

consensus_songs <- human_llm_wide_public |>
  mutate(
    human_consensus = case_when(
      if_all(all_of(human_cols), ~ .x == 1) ~ "Both political",
      if_all(all_of(human_cols), ~ .x == 0) ~ "Both not political",
      TRUE ~ "Disagree"
    ),
    human_political = as.integer(human_consensus == "Both political")
  ) |>
  filter(human_consensus != "Disagree")

model_cols <- names(consensus_songs) |>
  stringr::str_subset("^about_politics_")

table_8 <- map_dfr(model_cols, \(col) {
  kappa_result <- irr::kappa2(cbind(consensus_songs$human_political, consensus_songs[[col]]))
  tibble(
    model = stringr::str_remove(col, "^about_politics_"),
    kappa = round(kappa_result$value, 3),
    p_value = if_else(kappa_result$p.value < 0.001, "< .001", format(round(kappa_result$p.value, 3), nsmall = 3)),
    agreement = round(100 * mean(consensus_songs$human_political == consensus_songs[[col]], na.rm = TRUE), 1)
  )
}) |>
  left_join(model_display_labels, by = "model") |>
  transmute(
    model = model_display,
    kappa,
    p_value,
    agreement
  ) |>
  arrange(desc(kappa))

write_table(table_8, "table_8_human_model_agreement.csv")
write_table(politics_categories_human_public, "appendix_human_categories.csv")

message("Public manuscript and appendix outputs written to: ", normalizePath(file.path("results", "public")))
