stm_pipeline <- list(
  # ---- Input data
  tar_target(
    name = hot100_genius_full_stm_data,
    command = hot100_genius_full |>
      dplyr::filter(
        !is.na(match_score),
        match_score < 0.3,
        !is.na(lyrics),
        lyrics != ""
      ) |>
      dplyr::transmute(
        Lyrics = lyrics,
        Year = as.numeric(year),
        Weeks = weeks,
        Top = top,
        song = song,
        artist = artist,
        genius_id = genius_id,
        genius_title = genius_title,
        genius_artist = genius_artist
    ),
    description = "STM: filtered lyrics and metadata for topic modeling"
  ),
  # ---- Text processing
  tar_target(
    name = stm_processed,
    command = stm::textProcessor(
      hot100_genius_full_stm_data$Lyrics,
      metadata = hot100_genius_full_stm_data
    ),
    description = "STM: processed documents and metadata"
  ),
  tar_target(
    name = stm_prepped,
    command = stm::prepDocuments(
      stm_processed$documents,
      stm_processed$vocab,
      stm_processed$meta
    ),
    description = "STM: prepared documents, vocab, and metadata"
  ),
  # ---- Diagnostics
  tar_target(
    name = stm_search_k,
    command = stm::searchK(
      stm_prepped$documents,
      stm_prepped$vocab,
      K = c(10, 20, 30, 40, 50, 60, 70, 80),
      prevalence = ~ stm::s(as.numeric(Year)) + Weeks + Top,
      data = stm_prepped$meta,
      init.type = "Spectral",
      seed = 14850
    ),
    description = "STM: searchK diagnostics for choosing number of topics"
  ),
  # ---- Model fit and outputs
  tar_target(
    name = stm_fit,
    command = stm::stm(
      stm_prepped$documents,
      stm_prepped$vocab,
      K = 71,
      prevalence = ~ stm::s(as.numeric(Year)) + Weeks + Top,
      max.em.its = 400,
      data = stm_prepped$meta,
      init.type = "Spectral",
      seed = 14850
    ),
    description = "STM: fitted topic model"
  ),
  tar_target(
    name = stm_effects,
    command = stm::estimateEffect(
      1:71 ~ stm::s(Year) + Weeks + Top,
      stm_fit,
      meta = stm_prepped$meta,
      uncertainty = "Global"
    ),
    description = "STM: prevalence effects over time and chart performance"
  ),
  tar_target(
    name = stm_topic_labels,
    command = stm::labelTopics(
      stm_fit,
      topics = 1:length(summary(stm_fit)$topicnums),
      n = 7,
      frexweight = 0.5
    ),
    description = "STM: topic labels"
  )
)
