empath_pipeline <- list(
  # ---- Inputs
  tar_file(
    name = empath_keywords_file,
    command = here::here("empath", "input", "politics_keywords.csv"),
    description = "Empath: seed keyword file for custom politics categories"
  ),
  tar_target(
    name = empath_keywords,
    command = readr::read_csv(empath_keywords_file, show_col_types = FALSE),
    description = "Empath: seed keyword list"
  ),
  tar_target(
    name = empath_input,
    command = hot100_genius_full |>
      dplyr::filter(
        !is.na(match_score),
        match_score < 0.3,
        !is.na(lyrics),
        lyrics != ""
      ) |>
      dplyr::transmute(
        title = song,
        artist = artist,
        year = as.numeric(year),
        weeks = weeks,
        top = top,
        lyrics = lyrics,
        genius_id = genius_id,
        genius_title = genius_title,
        genius_artist = genius_artist
    ),
    description = "Empath: filtered lyrics and metadata"
  ),
  # ---- Analysis
  tar_target(
    name = empath_analysis,
    command = {
      empath_python <- Sys.getenv("RETICULATE_PYTHON", unset = "")
      if (nzchar(empath_python)) {
        reticulate::use_python(empath_python, required = TRUE)
      } else {
        venv_path <- here::here(".venv", "empath")
        if (dir.exists(venv_path)) {
          reticulate::use_virtualenv(venv_path, required = TRUE)
        }
      }

      if (!reticulate::py_module_available("empath")) {
        stop("Python module 'empath' not available. Set RETICULATE_PYTHON or install in .venv/empath.")
      }

      empath <- reticulate::import("empath")
      lexicon <- empath$Empath()

      keywords <- empath_keywords$keyword |>
        stats::na.omit() |>
        unique() |>
        as.character()

      lexicon$create_category("politics_reddit", keywords, model = "reddit")
      lexicon$create_category("politics_nytimes", keywords, model = "nytimes")
      lexicon$create_category("politics_fiction", keywords, model = "fiction")

      lyrics <- enc2utf8(empath_input$lyrics)
      analysis <- lapply(lyrics, function(text) lexicon$analyze(text, normalize = TRUE))
      analysis_df <- dplyr::bind_rows(lapply(analysis, as.list))

      results <- dplyr::bind_cols(empath_input, analysis_df)
      topics <- tibble::tibble(topic = names(analysis_df))
      politics_subset <- results |>
        dplyr::filter(
          politics > 0 |
            politics_reddit > 0 |
            politics_fiction > 0 |
            politics_nytimes > 0
        )

      list(
        results = results,
        topics = topics,
        politics_subset = politics_subset
      )
    },
    description = "Empath: analyze lyrics using base and seed categories"
  ),
  # ---- Outputs
  tar_target(
    name = empath_topics,
    command = empath_analysis$topics,
    description = "Empath: topic names"
  ),
  tar_target(
    name = empath_results,
    command = empath_analysis$results,
    description = "Empath: per-song category scores"
  ),
  tar_target(
    name = empath_politics_subset,
    command = empath_analysis$politics_subset,
    description = "Empath: subset with any politics signal"
  )
)
