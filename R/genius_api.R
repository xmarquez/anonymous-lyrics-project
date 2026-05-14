#' Call the Genius API
#'
#' Performs a GET request against the Genius API and returns parsed JSON.
#'
#' @param path Character scalar. API path starting with "/".
#' @param token Character scalar. Genius API token. Defaults to
#'   `Sys.getenv("GENIUS_API_TOKEN")`.
#' @param ... Named query parameters passed to the request.
#' @param max_retries Integer. Number of retry attempts for the request.
#'   Each request uses a 30-second timeout.
#'
#' @return A list parsed from JSON with `simplifyVector = FALSE`.
#' @seealso https://docs.genius.com
#' @examples
#' \dontrun{
#'   genius_api_get("/search", q = "John Lennon #9 Dream")
#' }
genius_api_get <- function(path,
                           token = Sys.getenv("GENIUS_API_TOKEN"),
                           ...,
                           max_retries = 5) {
  if (!nzchar(token)) {
    stop("GENIUS_API_TOKEN is not set.")
  }

  config <- httr::add_headers(Authorization = paste("Bearer", token))
  if (is.null(config$options)) {
    config$options <- list()
  }
  config$options$timeout <- 30

  response <- httr::RETRY(
    verb = "GET",
    url = paste0("https://api.genius.com", path),
    config = config,
    query = list(...),
    times = max_retries,
    pause_base = 1,
    pause_cap = 60,
    quiet = FALSE
  )

  httr::stop_for_status(response)
  jsonlite::fromJSON(
    httr::content(response, as = "text", encoding = "UTF-8"),
    simplifyVector = FALSE
  )
}

#' Search Genius for songs
#'
#' Queries the Genius search endpoint and returns a tibble of hits.
#'
#' @param query Character scalar. Search query string.
#' @param token Character scalar. Genius API token. Defaults to
#'   `Sys.getenv("GENIUS_API_TOKEN")`.
#' @param per_page Integer. Number of results per page (1 to 50).
#' @param page Integer. Page number for pagination.
#' @param max_retries Integer. Number of retry attempts for the request.
#'
#' @return A tibble with columns: `genius_id`, `title`, `full_title`, `artist`,
#'   `url`, and `api_path`. Returns an empty tibble if no hits are found.
#' @examples
#' \dontrun{
#'   hits <- genius_search("John Lennon #9 Dream")
#' }
genius_search <- function(query,
                          token = Sys.getenv("GENIUS_API_TOKEN"),
                          per_page = 10,
                          page = 1,
                          max_retries = 5) {
  if (!is.character(query) || length(query) != 1 || !nzchar(trimws(query))) {
    stop("query must be a non-empty character scalar")
  }
  if (!is.numeric(per_page) || length(per_page) != 1 || is.na(per_page) ||
      per_page < 1 || per_page > 50) {
    stop("per_page must be between 1 and 50")
  }
  if (!is.numeric(page) || length(page) != 1 || is.na(page) || page < 1) {
    stop("page must be a positive number")
  }

  res <- genius_api_get(
    path = "/search",
    token = token,
    q = query,
    per_page = per_page,
    page = page,
    max_retries = max_retries
  )

  hits <- res$response$hits
  if (length(hits) == 0) {
    return(tibble::tibble())
  }

  rows <- lapply(hits, function(hit) {
    result <- hit$result
    artist <- if (is.null(result$primary_artist$name)) {
      NA_character_
    } else {
      result$primary_artist$name
    }

    tibble::tibble(
      genius_id = if (is.null(result$id)) NA_integer_ else result$id,
      title = if (is.null(result$title)) NA_character_ else result$title,
      full_title = if (is.null(result$full_title)) NA_character_ else result$full_title,
      artist = artist,
      url = if (is.null(result$url)) NA_character_ else result$url,
      api_path = if (is.null(result$api_path)) NA_character_ else result$api_path
    )
  })

  dplyr::bind_rows(rows)
}

#' Normalize text for matching
#'
#' Lowercases text, removes featured markers and bracketed text, and
#' normalizes whitespace and punctuation.
#'
#' @param x Character vector to normalize.
#'
#' @return A character vector of normalized strings.
#' @examples
#' genius_normalize_text("Artist feat. Someone (Remix)")
genius_normalize_text <- function(x) {
  x <- tolower(x)
  x <- gsub("&", "and", x)
  x <- gsub("\\bfeat\\.?\\b|\\bfeaturing\\b|\\bft\\.?\\b", "", x)
  x <- gsub("\\(.*?\\)|\\[.*?\\]", " ", x)
  x <- gsub("[^a-z0-9]+", " ", x)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

#' Score search hits against artist and title
#'
#' Computes a normalized edit distance between the target artist and title and
#' each hit. Adds `match_score` and optional `match_ok` columns.
#'
#' @param artist Character scalar. Target artist name.
#' @param title Character scalar. Target song title.
#' @param hits Tibble of search hits from `genius_search()`.
#' @param max_distance Numeric scalar or NULL. Maximum normalized distance to
#'   consider a hit as acceptable.
#'
#' @return A tibble of hits sorted by `match_score`.
genius_match_hits <- function(artist,
                              title,
                              hits,
                              max_distance = 0.35) {
  if (nrow(hits) == 0) {
    return(hits)
  }

  target <- genius_normalize_text(paste(artist, title))
  candidates <- genius_normalize_text(paste(hits$artist, hits$title))
  distances <- as.numeric(utils::adist(target, candidates))
  denom <- pmax(nchar(target), nchar(candidates), 1)
  hits$match_score <- distances / denom
  hits <- hits[order(hits$match_score), ]

  if (!is.null(max_distance)) {
    hits$match_ok <- hits$match_score <= max_distance
  }

  hits
}

#' Find the best Genius match for a song
#'
#' Runs a search and returns the best matching hit, or an empty tibble if no
#' acceptable match is found.
#'
#' @param artist Character scalar. Target artist name.
#' @param title Character scalar. Target song title.
#' @param token Character scalar. Genius API token. Defaults to
#'   `Sys.getenv("GENIUS_API_TOKEN")`.
#' @param per_page Integer. Number of results per page (1 to 50).
#' @param page Integer. Page number for pagination.
#' @param max_distance Numeric scalar or NULL. Maximum normalized distance to
#'   consider a hit as acceptable.
#' @param max_retries Integer. Number of retry attempts for the request.
#'
#' @return A single-row tibble for the best match, or an empty tibble.
#' @examples
#' \dontrun{
#'   best <- genius_best_match("John Lennon", "#9 Dream")
#' }
genius_best_match <- function(artist,
                              title,
                              token = Sys.getenv("GENIUS_API_TOKEN"),
                              per_page = 10,
                              page = 1,
                              max_distance = 0.35,
                              max_retries = 5) {
  if (!is.character(artist) || length(artist) != 1 || !nzchar(trimws(artist))) {
    stop("artist must be a non-empty character scalar")
  }
  if (!is.character(title) || length(title) != 1 || !nzchar(trimws(title))) {
    stop("title must be a non-empty character scalar")
  }

  hits <- genius_search(
    query = paste(artist, title),
    token = token,
    per_page = per_page,
    page = page,
    max_retries = max_retries
  )
  hits <- genius_match_hits(
    artist = artist,
    title = title,
    hits = hits,
    max_distance = max_distance
  )

  if (nrow(hits) == 0) {
    return(tibble::tibble())
  }

  best <- hits[1, ]
  if (!is.null(max_distance) && isFALSE(best$match_ok)) {
    return(tibble::tibble())
  }

  best
}

#' Scrape lyrics from a Genius song page
#'
#' Downloads the song page, extracts lyric containers, and reconstructs line
#' breaks into a single lyrics string.
#'
#' @param song_url Character scalar. Genius song URL.
#' @param user_agent Character scalar. User agent string for the request.
#'   The request uses a 30-second timeout.
#'
#' @return A character scalar with lyrics, or `NA_character_` if not found.
#' @examples
#' \dontrun{
#'   lyrics <- genius_scrape_lyrics(
#'     "https://genius.com/John-lennon-9-dream-lyrics"
#'   )
#' }
genius_scrape_lyrics <- function(song_url,
                                 user_agent = "R (Genius lyrics scraper)") {
  if (is.na(song_url) || !nzchar(song_url)) {
    return(NA_character_)
  }

  config <- httr::user_agent(user_agent)
  if (is.null(config$options)) {
    config$options <- list()
  }
  config$options$timeout <- 30

  response <- httr::RETRY(
    verb = "GET",
    url = song_url,
    config = config,
    times = 3,
    pause_base = 1,
    pause_cap = 30,
    quiet = FALSE
  )
  httr::stop_for_status(response)

  html <- httr::content(response, as = "text", encoding = "UTF-8")
  page <- xml2::read_html(html)

  containers <- rvest::html_elements(page, "div[data-lyrics-container='true']")
  if (length(containers) == 0) {
    containers <- rvest::html_elements(
      page,
      "div.lyrics, div[class^='Lyrics__Container']"
    )
  }
  if (length(containers) == 0) {
    return(NA_character_)
  }

  header_blocks <- rvest::html_elements(
    containers,
    "[data-exclude-from-selection='true'], div[class^='LyricsHeader__']"
  )
  if (length(header_blocks) > 0) {
    xml2::xml_remove(header_blocks)
  }

  genius_node_text <- function(node) {
    node_type <- xml2::xml_type(node)
    if (identical(node_type, "text")) {
      return(xml2::xml_text(node))
    }
    if (!identical(node_type, "element")) {
      return("")
    }

    node_name <- xml2::xml_name(node)
    if (identical(node_name, "br")) {
      return("\n")
    }
    if (node_name %in% c("script", "style")) {
      return("")
    }

    children <- xml2::xml_contents(node)
    if (length(children) == 0) {
      return("")
    }

    paste(
      vapply(children, genius_node_text, character(1), USE.NAMES = FALSE),
      collapse = ""
    )
  }

  lyrics <- vapply(containers, genius_node_text, character(1), USE.NAMES = FALSE)
  lyrics <- gsub("\r\n", "\n", lyrics, fixed = TRUE)
  lyrics <- gsub("[ \t]+\n", "\n", lyrics)
  lyrics <- gsub("\n[ \t]+", "\n", lyrics)
  lyrics <- lyrics[nzchar(trimws(lyrics))]
  lyrics <- paste(lyrics, collapse = "\n")
  lyrics <- gsub("\n{2,}", "\n\n", lyrics)
  lyrics <- trimws(lyrics)

  if (!nzchar(lyrics)) NA_character_ else lyrics
}

#' Get lyrics for a song by artist and title
#'
#' Finds the best Genius match for the artist and title, then scrapes the
#' lyrics page. Returns a tibble with match metadata and status.
#'
#' @param artist Character scalar. Target artist name.
#' @param title Character scalar. Target song title.
#' @param token Character scalar. Genius API token. Defaults to
#'   `Sys.getenv("GENIUS_API_TOKEN")`.
#' @param per_page Integer. Number of search results per page (1 to 50).
#' @param page Integer. Page number for pagination.
#' @param max_distance Numeric scalar or NULL. Maximum normalized distance to
#'   consider a hit as acceptable.
#' @param max_retries Integer. Number of retry attempts for the request.
#' @param rate_limit Numeric. Seconds to sleep before scraping lyrics.
#' @param user_agent Character scalar. User agent string for the request.
#'
#' @return A tibble with columns: `artist`, `title`, `genius_id`,
#'   `genius_title`, `genius_artist`, `genius_url`, `match_score`, `lyrics`,
#'   and `status`.
#' @examples
#' \dontrun{
#'   result <- genius_get_lyrics("John Lennon", "#9 Dream")
#'   result$lyrics
#' }
genius_get_lyrics <- function(artist,
                              title,
                              token = Sys.getenv("GENIUS_API_TOKEN"),
                              per_page = 10,
                              page = 1,
                              max_distance = 0.35,
                              max_retries = 5,
                              rate_limit = 0,
                              user_agent = "R (Genius lyrics scraper)") {
  if (!is.character(artist) || length(artist) != 1 || !nzchar(trimws(artist))) {
    stop("artist must be a non-empty character scalar")
  }
  if (!is.character(title) || length(title) != 1 || !nzchar(trimws(title))) {
    stop("title must be a non-empty character scalar")
  }
  if (!is.numeric(per_page) || length(per_page) != 1 || is.na(per_page) ||
      per_page < 1 || per_page > 50) {
    stop("per_page must be between 1 and 50")
  }
  if (!is.numeric(page) || length(page) != 1 || is.na(page) || page < 1) {
    stop("page must be a positive number")
  }
  if (!is.numeric(rate_limit) || length(rate_limit) != 1 || is.na(rate_limit) ||
      rate_limit < 0) {
    stop("rate_limit must be a non-negative number")
  }

  best <- genius_best_match(
    artist = artist,
    title = title,
    token = token,
    per_page = per_page,
    page = page,
    max_distance = max_distance,
    max_retries = max_retries
  )
 
  if (nrow(best) == 0) {
    return(tibble::tibble(
      artist = artist,
      title = title,
      genius_id = NA_integer_,
      genius_title = NA_character_,
      genius_artist = NA_character_,
      genius_url = NA_character_,
      match_score = NA_real_,
      lyrics = NA_character_,
      status = "no_match"
    ))
  }

  if (rate_limit > 0) {
    Sys.sleep(rate_limit)
  }

  lyrics <- genius_scrape_lyrics(best$url, user_agent = user_agent)
  status <- if (is.na(lyrics)) "lyrics_not_found" else "ok"

  tibble::tibble(
    artist = artist,
    title = title,
    genius_id = best$genius_id,
    genius_title = best$title,
    genius_artist = best$artist,
    genius_url = best$url,
    match_score = best$match_score,
    lyrics = lyrics,
    status = status
  )
}
