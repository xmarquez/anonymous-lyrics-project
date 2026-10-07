GENIUS_SAMPLE_SIZE <- 100
GENIUS_BATCH_SIZE <- 100
GENIUS_RATE_LIMIT <- 1
GENIUS_MAX_DISTANCE <- 0.5

# The Hot 100 Billboard chart is hosted on Kaggle:
# https://www.kaggle.com/datasets/ludmin/billboard?resource=download&select=hot100.csv
# This is autoscraped weekly, so it's current
# I downloaded it on 22/12/2025

scraping <- list(
  # ---- Source data
  tar_file(
    name = hot100kaggle,
    command = here::here("data-raw", "hot100.csv"),
    description = "Scraping: Hot 100 Billboard chart from Kaggle autoscraper 2025-12-22"
  ), 
  tar_target(
    name = hot100data,
    command = read_csv(hot100kaggle) |>
      janitor::clean_names(),
    description = "Scraping: Hot 100 Billboard chart from Kaggle autoscraper, names cleaned"
  ), 
  tar_target(
    name = allSongs,
    command = hot100data |> 
      group_by(song, artist) |> 
      summarise(weeks = n(), 
                top = min(rank), 
                year = max(lubridate::year(date[rank == top]))) |> 
      ungroup(),
    description = "Scraping: Hot 100 Billboard chart from Kaggle autoscraper, summarised"
  ),
  # ---- Sample scrape (testing)
  tar_group_by(
    name = hot100_sample,
    command = allSongs |>
      slice_sample(n = GENIUS_SAMPLE_SIZE) |>
      mutate(batch = ((seq_along(song) - 1) %/% GENIUS_BATCH_SIZE) + 1),
    batch,
    deployment = "main",
    description = "Scraping: batched sample of Hot 100 Billboard chart for testing"
  ),
  tar_frozen(tar_target(
    name = hot100_genius_sample,
    command = hot100_sample |>
      mutate(genius = purrr::map2(artist, song, \(artist, song) {
        genius_get_lyrics(
          artist = artist,
          title = song,
          rate_limit = GENIUS_RATE_LIMIT,
          max_distance = GENIUS_MAX_DISTANCE
        ) |>
          dplyr::select(-artist, -title)
      })) |>
      tidyr::unnest(cols = genius),
    pattern = map(hot100_sample),
    deployment = "main",
    description = "Scraping: scrape lyrics from batched sample of Hot 100 Billboard chart for testing"
  )),
  # ---- Full scrape
  tar_group_by(
    name = hot100_full,
    command = allSongs |>
      mutate(batch = ((seq_along(song) - 1) %/% GENIUS_BATCH_SIZE) + 1),
    batch,
    deployment = "main",
    description = "Scraping: batched Hot 100 Billboard chart for scraping"
  ),
  tar_frozen(tar_target(
    name = hot100_genius_full,
    command = hot100_full |>
      mutate(genius = purrr::map2(artist, song, \(artist, song) {
        genius_get_lyrics(
          artist = artist,
          title = song,
          rate_limit = GENIUS_RATE_LIMIT,
          max_distance = GENIUS_MAX_DISTANCE
        ) |>
          dplyr::select(-artist, -title)
      })) |>
      tidyr::unnest(cols = genius),
    pattern = map(hot100_full),
    deployment = "main",
    error = "null",
    description = "Scraping: scrape lyrics from batched Hot 100 Billboard chart"
  ))
)
