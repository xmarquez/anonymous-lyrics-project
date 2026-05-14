# Overview

This anonymous review repository contains replication materials for a study of political content in Billboard Hot 100 song lyrics. The analysis relies on a `{targets}` pipeline that scrapes and cleans song lyrics data, runs LLM classification for political content and related analyses, validates classifications against human coding, and produces the tables and figures reported in the manuscript.

This repository contains sanitized derived data plus the full pipeline code; full lyrics and credentials are not included (see Statement about Rights). The default public reproduction path (`run_public.R`) replays manuscript outputs from `data-derived/public/` in minutes; the optional full pipeline (`run.sh`, optionally containerized via `DOCKER_SETUP.md`) regenerates everything from upstream sources.

# Data Availability and Provenance Statements

## Summary

- Source data include the Billboard Hot 100 list (`data-raw/hot100.csv`) and lyrics scraped using the Genius API.
- Access to Genius data requires a `GENIUS_API_TOKEN` and compliance with Genius terms.
- A variable codebook is provided as `codebook.qmd` (source) and `codebook.md` (rendered for GitHub).
- The public replication package includes sanitized derived data in `data-derived/public/` in both CSV and RDS form.

## Statement about Rights

- The full lyrics used in the analysis are copyrighted and are not redistributed here. This anonymous bundle omits full lyrics, full lyric-bearing prompt bodies, raw API request and response archives, and API keys; it includes sanitized derived data, model classifications, and LLM free-text justifications (which may contain incidental lyric quotations).
- Users who rerun the full private pipeline must supply their own credentials and are responsible for complying with the applicable terms for the underlying data sources and API providers.

## Summary of Availability

- [ ] All data are publicly available.
- [x] Some data cannot be made publicly available.
- [ ] No data can be made publicly available.

The public source list and sanitizable derived objects can be shared. Full lyrics and credential-bearing materials cannot be shared in this repository.

## Details on each Data Source

The basic source list consists of Billboard Hot 100 songs. The list was obtained from a Kaggle dataset that tracks the Billboard Hot 100 and is included here as `data-raw/hot100.csv`.

The lyrics of most songs are scraped via the Genius API. The scraping code is primarily in `R/genius_api.R` and runs as part of the larger `{targets}` pipeline in `R/scraping_pipeline.R`. A fuller description of the lyric-processing workflow is in `llm_classification.qmd`.

Intermediate and final analytical objects are produced by the `{targets}` pipeline. For the anonymous public package, the intended reproducible path distributes sanitized derived objects in `data-derived/public/` rather than full copyrighted lyrics or raw provider archives.

# Dataset list

Inputs and source data:

| data_file | source | notes | provided |
|:---|:---|:---|:---|
| `data-raw/hot100.csv` | Billboard Hot 100 source list | Input list of songs | Yes |
| `data-raw/known_politics_songs.csv` | Curated validation list | Known political songs used for validation | Yes |
| N/A - produced during a full run | Genius API | Lyrics scraped by the pipeline | Code provided to rerun; lyrics not redistributed |

Public derived-data bundle (`data-derived/public/`). Every object is provided as both `.csv` and `.rds`; `manifest.csv` is the machine-readable inventory.

| stem | contents | used for |
|:---|:---|:---|
| `human_coding_public` | Anonymized human classifications and justifications | Human-validation tables and appendix figures |
| `llm_politics_simple_public` | Song-model political-content classifications and justifications, without full lyrics | Main Figures 2-6 and appendix LLM/human-validation figures |
| `llm_politics_themes_public` | Song-model political-theme classifications in long form | Theme tables and appendix theme figures |
| `politics_categories_public` | Theme-category lookup table | Theme tables |
| `politics_categories_human_public` | Human-justification category lookup table | Human-validation appendix outputs |
| `song_features_public` | Song-level match metadata plus lyric-availability and keyword indicators, without lyrics | Main Figure 1 and appendix lyric-match/keyword figures |
| `stm_topic_terms` | Highest-probability words for STM topics | Main Table 2 |
| `stm_violence_effect_public` | Estimated STM violence-topic trajectory with confidence intervals | Appendix STM figure |
| `empath_scores_public` | Row-level Empath scores for measures used in the manuscript and appendix | Empath appendix figure and Empath tables |
| `empath_top_songs` | Top-song summary for Empath political measures | Main Table 3 |
| `empath_known_songs` | Empath scores for the curated known-political-song list | Main Table 4 |
| `appendix_known_politics_classifications` | Known-political-song classifications from the report's all-matches validation path | Appendix Table D1 |
| `appendix_interpretation_examples` | Manually condensed interpretation examples | Appendix Table D2 |

# Computational requirements

## Software Requirements

The full pipeline runs with the following software requirements:

- R 4.5.x
- Python 3.10+ for Empath targets
- Optional: Docker and Docker Compose
- Optional: Ollama for local models such as `gemma3:4b`

A Docker image can be built from the included `Dockerfile`. `docker-compose.yml` is also provided for local containerized execution; see `DOCKER_SETUP.md`.

## R Packages

R package dependencies are managed via `renv.lock`. The lockfile is included so the R package environment can be restored. One R dependency (`groqDeveloper`) is installed from GitHub. 

## Python Packages

Empath dependencies are managed via `requirements-empath.txt`.

## Hardware Requirements

The full pipeline was run on a machine with the following specifications:

- OS: Windows 11 Enterprise (64-bit)
- CPU: Intel Core Ultra 7 265H (16 cores / 16 logical)
- RAM: 32 GB
- Disk: approximately 819 GB in the working partition, with approximately 119 GB free at testing time
- GPU: NVIDIA RTX PRO 500 Blackwell Generation Laptop GPU and Intel Arc Pro 140T

GPU inference is not required for the public derived-data run, but it speeds local inference for Ollama-based models in a full private run.

## Storage Requirements

The full `{targets}` pipeline reported the following storage use:

| type | size |
|:---|---:|
| branch | 36 MB |
| function | 0 B |
| object | 0 B |
| pattern | 5 MB |
| stem | 683 MB |
| total | 724 MB |

## Runtime (from targets metadata)

The full pipeline is computationally expensive because it includes scraping, LLM calls, and topic-model fitting. Representative recorded runtimes include:

| target_or_pattern | duration |
|:---|---:|
| `hot100_genius_sample` | 374.859s (about 6.25 minutes) |
| `hot100_genius_full` | 11932.751s (about 3.31 hours) |
| `combined_responses_politics_simple` | 12384.145s (about 3.44 hours) |
| `politics_simple_responses_sample` | 2.703s |
| `politics_themes_responses_sample` | 1701.454s (about 28.36 minutes) |
| `stm_search_k` | 12322.203s (about 3.42 hours) |
| `stm_fit` | 1644.437s (about 27.41 minutes) |

Recorded aggregate runtime metadata:

| type | duration |
|:---|---:|
| branch | 586875.282s (about 6.79 days) |
| function | 0s |
| object | 0s |
| pattern | 26395.912s (about 7.33 hours) |
| stem | 14371.433s (about 3.99 hours) |
| total | 627642.627s (about 1.04 weeks) |

Pattern durations are not the same as elapsed wall-clock time for a fresh run, and totals may be inflated where pattern timings already include branch work. Actual runtime varies with batch processing, parallel workers, provider limits, and restarts. Overall, a full run should take about a week.

# Description of programs/code

- `_targets.R`: main pipeline definition.
- `R/`: pipeline functions and helpers, including scraping, prompt construction, LLM calls, human-coding validation, and analysis sub-pipelines.
- `run.sh`: master non-interactive replication script.
- `run.R`: interactive runner.
- `run_public.R`: short public reproduction entry point using only `data-derived/public/`.
- `scripts/export_public_replication_data.R`: converts a completed full-pipeline targets cache into the sanitized public bundle in `data-derived/public/`.
- `scripts/render_public_manuscript_outputs.R`: recreates the current manuscript and appendix outputs from public derived data.
- `config/models.yml`: model configuration, including providers, processing modes, batch sizes, and explicit model parameters.
- `prompts/`: prompt templates (mustache-style `{{lyrics}}`, `{{genius_title}}`, etc. placeholders). The rendered prompt bodies — templates with actual lyrics filled in — are not redistributed.
- `llm_classification.qmd`, `analysis_replication.qmd`, `human_classification.qmd`: analysis reports and manuscript-output sources.
- `codebook.qmd`, `codebook.md`: variable codebook (source and rendered GitHub-flavored markdown; `.md` is browsable directly on GitHub).
- `.Renviron.example`: placeholder environment-variable file for optional full-pipeline runs.
- `Dockerfile`, `Dockerfile.rstudio`, `docker-compose.yml`, `.dockerignore`, `DOCKER_SETUP.md`: containerized execution support.
- `.Rprofile`, `renv/activate.R`, `renv/settings.json`: `renv` bootstrap files used by local and Docker execution.

# Instructions to Replicators

## Default Public Reproduction Mode

The intended public reproduction mode is a short derived-data run that rebuilds the manuscript figures, appendix figures, and associated public tables from sanitized objects in `data-derived/public/`, without API keys or full lyrics.

Run:

```bash
Rscript -e "renv::restore()"
Rscript run_public.R
```

This writes figure files to `results/public/figures/` and table files to `results/public/tables/`, including Appendix Tables D1-D2.

## Optional Full Private Pipeline

1. Copy `.Renviron.example` to `.Renviron`.
2. Fill in local credentials for the required services.
3. Run `./run.sh` for a local `renv`-based run.
4. Alternatively, run `USE_DOCKER=1 ./run.sh` to execute inside Docker.

The full private pipeline reruns scraping and model calls and therefore requires user-supplied API keys plus access to the underlying services. See `DOCKER_SETUP.md` for Docker-specific setup and troubleshooting.

## Sanitized Bundle vs. Full Regeneration

`run_public.R` is a replay path. It does not regenerate tables and figures from scratch, but treats the files in `data-derived/public/` as fixed inputs and reproduces the manuscript-facing outputs from those sanitized inputs. In particular, it does not scrape lyrics, reconstruct omitted lyric text, rebuild full prompt bodies, call API providers, or run computationally intensive models (like the Structural Topic model or Empath analysis reported in the paper).

The sanitized bundle was produced from a completed full targets run using:

```bash
Rscript scripts/export_public_replication_data.R
```

Recreating that bundle from upstream sources would therefore require the optional full private pipeline first: obtaining lyrics through the Genius API, rerunning the LLM classifications and related analyses (including the STM model and Empath analysis), creating the full private targets cache, and then exporting the shareable subset with `scripts/export_public_replication_data.R`.

# List of tables and programs

| manuscript_item | program_or_file | output_or_label | notes |
|:---|:---|:---|:---|
| Figures and tables in `llm_classification.qmd` | `llm_classification.qmd` | `fig-match-by-match-score`, `fig-match-proportions-by-match-score`, `tbl-example-of-match-discrepancies`, `tbl-models`, `tbl-politics-simple-costs`, `tbl-politics-categories`, `tbl-simple-results`, `fig-yearly`, `fig-corr`, `fig-disc`, `tbl-known-politics`, `tbl-imagine`, `tbl-johnny-cash`, `tbl-politics-only-one-model`, `fig-confidence-by-model`, `fig-confidence-political`, `fig-confidence-weighted`, `tbl-confidence-scores`, `fig-density-politics-per-year`, `fig-popularity`, `tbl-theme-categories`, `fig-theme-distribution-per-model`, `fig-theme-distribution`, `fig-theme-distribution-per-model-ridges`, `tbl-correlations` | See labels in source file |
| Figures and tables in `analysis_replication.qmd` | `analysis_replication.qmd` | `fig-missing-lyrics`, `fig-keyword-politics`, `fig-keyword-war-countries`, `tbl-stm-topics`, `fig-stm-violence`, `fig-empath-over-time`, `tbl-empath-top-songs`, `tbl-empath-top-songs-expanded`, `tbl-empath-known-songs` | See labels in source file |
| Human-coding validation outputs | `human_classification.qmd` | Human-coder comparison tables and figures | See labels in source file |
| Public derived-data reproduction | `run_public.R`, `scripts/render_public_manuscript_outputs.R` | `results/public/figures/`, `results/public/tables/` | Uses only sanitized public data; reproduces current manuscript and appendix outputs, including Appendix Tables D1-D2 |
| Pipeline outputs | `_targets.R` | Targets cache in `_targets/` | Generated at runtime |
| Variable codebook | `codebook.qmd` | `codebook.md` | Pre-rendered GitHub-flavored markdown; re-render with `quarto render codebook.qmd --to gfm` |

# References

## Data sources

- Billboard Hot 100 weekly chart, accessed via the Kaggle "Billboard" dataset: <https://www.kaggle.com/datasets/ludmin/billboard>.
- Genius lyrics, accessed via the Genius API: <https://docs.genius.com/>.

## Software

- Landau, W. M., (2021). The targets R package: a dynamic
  Make-like function-oriented pipeline toolkit for
  reproducibility and high-performance computing. Journal
  of Open Source Software, 6(57), 2959,
  <https://doi.org/10.21105/joss.02959>
- Wickham H, Cheng J, Jacobs A, Aden-Buie G, Schloerke B
  (2025). _ellmer: Chat with Large Language Models_.
  doi:10.32614/CRAN.package.ellmer
  <https://doi.org/10.32614/CRAN.package.ellmer>, R package
  version 0.4.0,
  <https://CRAN.R-project.org/package=ellmer>.
- Roberts ME, Stewart BM, Tingley D (2019). “stm: An R
  Package for Structural Topic Models.” _Journal of
  Statistical Software_, *91*(2), 1-40.
  doi:10.18637/jss.v091.i02
  <https://doi.org/10.18637/jss.v091.i02>.
- Fast, E., Chen, B., & Bernstein, M. S. (2016). Empath: Understanding Topic Signals in Large-Scale Text. In *Proceedings of the 2016 CHI Conference on Human Factors in Computing Systems* (pp. 4647-4657).

## Models

LLM model identifiers, providers, and configuration parameters are listed in `config/models.yml`.
