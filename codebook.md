# Codebook for Key Targets


This codebook documents the variables in three key targets from the
pipeline: `hot100data`, `hot100_genius_full`, and
`combined_responses_politics_simple`.

## hot100data

Weekly Billboard Hot 100 chart records from Kaggle (one row per
song-week). Column names are cleaned with `janitor::clean_names()`.

Rows: 350,787. Columns: 8.

| Variable | Type | Description |
|----|----|----|
| date | Date | Chart week date. |
| song | character | Song title as listed in the Hot 100 chart. |
| artist | character | Artist name as listed in the Hot 100 chart. |
| rank | numeric | Chart position for that week (1 is top). |
| last_week | numeric | Prior week rank for the same song (may be NA for new entries). |
| peak_position | numeric | Best (lowest) rank achieved by the song up to that week. |
| weeks_in_charts | character | Number of weeks on the chart as recorded in the source; stored as character because it can include “-” for new entries. |
| image_url | character | URL to the chart image; “\#” indicates missing. |

## hot100_genius_full

One row per unique song-artist combination from the Hot 100, matched to
Genius and scraped for lyrics. Derived from a song-level summary of
`hot100data` and a Genius API/HTML scrape.

Rows: 32,118. Columns: 14.

| Variable | Type | Description |
|----|----|----|
| song | character | Song title from the Hot 100 dataset. |
| artist | character | Artist name from the Hot 100 dataset. |
| weeks | integer | Total number of weeks the song appears on the Hot 100. |
| top | numeric | Best (lowest) chart rank across all weeks. |
| year | numeric | Year when the song reached its best rank (max year where `rank == top`). |
| batch | numeric | Scraping batch id (from GENIUS_BATCH_SIZE grouping). |
| tar_group | integer | Targets internal grouping index for batch processing. |
| genius_id | integer | Genius song ID for the best match (NA if no match). |
| genius_title | character | Song title from the Genius hit. |
| genius_artist | character | Artist name from the Genius hit. |
| genius_url | character | Genius song URL. |
| match_score | numeric | Normalized edit distance between (artist + title) and the Genius hit; lower is better, NA if no match, and capped at 0.5 by the scraper. |
| lyrics | character | Scraped lyrics from Genius (NA if not found). |
| status | character | Scrape status: “ok”, “no_match”, or “lyrics_not_found”. |

## combined_responses_politics_simple

Structured LLM outputs for the simple politics prompt. Each row is a
single model response for a prompt (one prompt per song and model).

Rows: 245,547. Columns: 16.

| Variable | Type | Description |
|----|----|----|
| about_politics | logical | Model classification of whether the lyrics are about politics. |
| justification | character | Model-provided rationale for the classification. |
| confidence_score | numeric | Model-reported confidence (0 to 1). |
| input_tokens | numeric | Input tokens for the structured response call. |
| output_tokens | numeric | Output tokens for the structured response call. |
| cached_input_tokens | numeric | Cached input tokens reported by the provider (may be NA). |
| cost | numeric | Cost reported for the call (may be NA depending on provider). |
| prompt_digest | character | Digest of the prompt text for joining back to prompt metadata. |
| model | character | Model identifier used for the response. |
| api | character | API/provider group from `config/models.yml`. |
| ellmer_function | character | Ellmer chat function used to send the prompt. |
| ellmer_params | list | Parameters passed to the model (temperature, etc.). |
| processing | character | Processing mode: sequential, parallel, or batch. |
| prompt_batch_size | integer | Batch size used for this model’s prompts. |
| tar_group | integer | Targets internal grouping index for this batch. |
| .error | list | Targets error object for failed calls (NULL/NA if none). |

## combined_responses_politics_themes

Structured LLM outputs for the politics themes prompt, run on songs
classified as political in the simple prompt. Each row is a single model
response for a prompt.

Rows: 5,136. Columns: 13.

| Variable | Type | Description |
|----|----|----|
| themes | list | List-column of 1-4 theme labels selected by the model from the extracted categories. |
| input_tokens | numeric | Input tokens for the structured response call. |
| output_tokens | numeric | Output tokens for the structured response call. |
| cached_input_tokens | numeric | Cached input tokens reported by the provider (may be NA). |
| cost | numeric | Cost reported for the call (may be NA depending on provider). |
| prompt_digest | character | Digest of the prompt text for joining back to prompt metadata. |
| model | character | Model identifier used for the response. |
| api | character | API/provider group from `config/models.yml`. |
| ellmer_function | character | Ellmer chat function used to send the prompt. |
| ellmer_params | list | Parameters passed to the model (temperature, etc.). |
| processing | character | Processing mode: sequential, parallel, or batch. |
| prompt_batch_size | integer | Batch size used for this model’s prompts. |
| tar_group | integer | Targets internal grouping index for this batch. |
