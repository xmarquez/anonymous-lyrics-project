# Overview

This anonymous review repository contains replication materials for *"'We Didn't Start the Fire'... But Can We Detect It? Measuring Political Content in Song Lyrics with LLMs"*, a study of political content in Billboard Hot 100 song lyrics (1958-2025). The analysis relies on a `{targets}` pipeline that scrapes song lyrics from Genius, classifies them for political content with nine LLMs, compares the LLMs with keyword search, a structural topic model (STM), Empath, and human coders, and produces the tables and figures reported in the manuscript.

This repository contains the full pipeline code plus sanitized derived data; full lyrics and credentials are not included (see Statement about Rights). There are three ways to run the analysis:

| Mode | Command | Requires | Runtime | Reproduces |
|:---|:---|:---|:---|:---|
| **Public replay (default for reviewers)** | `Rscript run_public.R` | Only this repository | under one minute | Manuscript figures and tables from `data-derived/public/` |
| Frozen run | `Rscript run_frozen.R` | Frozen scraped lyrics and LLM outputs (`data-frozen/`), shared privately with the editors because the lyrics are copyrighted. No API keys | 30-45 minutes | Everything downstream of scraping and LLM calls, including STM, Empath, and the full reports |
| Full live run | `./run.sh` | User-supplied API keys | about one week | Everything, including scraping and LLM calls |

# Data Availability and Provenance Statements

## Summary

- Source data include the Billboard Hot 100 list from 1958-08-06 to 2025-10-22 (`data-raw/hot100.csv`) and lyrics scraped using the Genius API.
- Access to Genius data requires a `GENIUS_API_TOKEN` and compliance with Genius terms.
- A variable codebook is provided as `codebook.qmd` (source) and `codebook.md` (rendered for GitHub).
- The public replication package includes sanitized derived data in `data-derived/public/` in both CSV and RDS form.

## Statement about Rights

- The full lyrics used in the analysis are copyrighted and are not redistributed here. This anonymous bundle omits full lyrics, full lyric-bearing prompt bodies, raw API request and response archives, and API keys; it includes sanitized derived data, model classifications, and LLM free-text justifications (which may contain incidental lyric quotations).
- The scraped lyrics and raw LLM outputs used in the manuscript are shared privately with the journal's editors and replication team as frozen intermediate objects, which allow the full analysis to be rerun without scraping or API calls (`run_frozen.R`). They are not part of this public repository.
- Users who rerun the full live pipeline must supply their own credentials and are responsible for complying with the applicable terms for the underlying data sources and API providers. Since public APIs change and models get deprecated, there is no guarantee that a full scrape and classification can be replicated exactly using this pipeline.

## Summary of Availability

- [ ] All data are publicly available.
- [x] Some data cannot be made publicly available.
- [ ] No data can be made publicly available.

The public source list and sanitizable derived objects can be shared. Full lyrics and credential-bearing materials cannot be shared in this repository.

## Details on each Data Source

The basic source list consists of Billboard Hot 100 songs. The list was obtained from a Kaggle dataset that tracks the Billboard Hot 100 and is included here as `data-raw/hot100.csv`.

The lyrics of most songs are scraped via the Genius API. The scraping code is primarily in `R/genius_api.R` and runs as part of the larger `{targets}` pipeline in `R/scraping_pipeline.R`. A fuller description of the lyric-processing workflow is in `llm_classification.qmd`.

Intermediate and final analytical objects are produced by the `{targets}` pipeline. For the anonymous public package, the reproducible path distributes sanitized derived objects in `data-derived/public/`.

# Dataset list

Inputs and source data:

| data_file | source | notes | provided |
|:---|:---|:---|:---|
| `data-raw/hot100.csv` | Billboard Hot 100 source list | Input list of songs | Yes |
| `data-raw/known_politics_songs.csv` | Curated validation list | Known political songs used for validation | Yes |
| `empath/input/politics_keywords.csv` | Authors | Seed words for the custom Empath politics categories | Yes |
| `human-coding/exports/political_coding_export_20260304_221106.csv` | Human coders | Classifications, confidence, and justifications for 600 songs by two coders (anonymized as Coder A and Coder B); no lyrics | Yes |
| `human-coding/coding_instructions.md` | Authors | Instructions given to the human coders | Yes |
| N/A - produced during a full run | Genius API | Lyrics scraped by the pipeline | Code provided to rerun; lyrics not redistributed |

Public derived-data bundle (`data-derived/public/`). Every object is provided as both `.csv` and `.rds`; `manifest.csv` is the machine-readable inventory.

| stem | contents | used for |
|:---|:---|:---|
| `human_coding_public` | Anonymized human classifications and justifications | Human-validation tables and appendix figures |
| `llm_politics_simple_public` | Song-model political-content classifications, justifications, and per-response token usage and cost, without full lyrics | Main Figures 2-6, appendix LLM/human-validation figures, and Table E1 |
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

- R 4.5.x (the lockfile records R 4.5.1; the Docker image uses `rocker/verse:4.5.2`)
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

GPU inference is not required for the public derived-data run, but it speeds local inference for Ollama-based models in a full live run.

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

## Runtime

- Public replay (`run_public.R`): under one minute.
- Frozen run (`run_frozen.R`): 30-45 minutes on the machine above, mostly fitting the STM (`stm_fit`, about 25 minutes) and rendering the reports; about 16 minutes in the Docker image on the same machine.
- Full live run: about one week. Recorded runtimes for the most expensive targets in the original run (branch times summed) were:

| target | duration |
|:---|---:|
| `hot100_genius_full` | about 1.5 days |
| `combined_responses_politics_simple` | about 5.5 days |
| `combined_responses_politics_themes` | about 1.8 hours |
| `stm_search_k` | about 3.4 hours |
| `stm_fit` | about 27 minutes |
| `stm_effects`, `empath_analysis`, GPT-5.2 category extraction | about 1 minute each or less |

Summed branch times overstate active computation for the LLM targets (batch jobs can wait up to 24 hours) and understate elapsed time across restarts. Actual runtime varies with batch processing, parallel workers, provider limits, and restarts.

# Description of programs/code

- `_targets.R`: main pipeline definition.
- `R/`: pipeline functions and helpers, including scraping, prompt construction, LLM calls, human-coding validation, and analysis sub-pipelines.
- `_targets.yaml`: defines two `{targets}` projects, `main` (live run, store `_targets/`) and `frozen` (store `_targets_frozen/`).
- `R/frozen_targets.R`: in the `frozen` project, replaces each scraping, LLM, and `stm::searchK()` target, and the STM text preprocessing, with a target that reads the corresponding file in `data-frozen/`; all other targets are identical in both modes.
- `run.sh`: master non-interactive script for the full live run.
- `run.R`: interactive runner.
- `run_frozen.R`: runs the pipeline from frozen inputs (requires the privately shared `data-frozen/`).
- `run_public.R`: short public reproduction entry point using only `data-derived/public/`.
- `scripts/export_frozen_inputs.R`: writes `data-frozen/` from a completed live run.
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

This writes figure files to `results/public/figures/` and table files to `results/public/tables/`, including Appendix Tables D1-D2. It takes under a minute after packages are installed.

## Frozen Run (editors and replication team)

With the privately shared `data-frozen/` folder placed in the repository root, and Python set up for Empath (`requirements-empath.txt`, in `.venv/empath` or via `RETICULATE_PYTHON`), run:

```bash
Rscript run_frozen.R
```

This rebuilds every target downstream of scraping and LLM calls into `_targets_frozen/` and renders the three reports. No API keys are needed.

**Numerical note on the STM.** The structural topic model is sensitive to floating-point differences between platforms and linear-algebra libraries. On the authors' platform (Windows, R's bundled reference BLAS) the frozen run reproduces the published topics exactly; on Linux, including the Docker image, it converges to a very similar but not identical solution (matched topics have a median correlation of 0.96-0.98, but a few topics differ), so the STM topic table and the violence-topic figure can differ slightly. All other results reproduce exactly across platforms.

## Optional Full Live Pipeline

1. Copy `.Renviron.example` to `.Renviron`.
2. Fill in local credentials for the required services.
3. Run `./run.sh` for a local `renv`-based run.
4. Alternatively, run `USE_DOCKER=1 ./run.sh` to execute inside Docker.

The full live pipeline reruns scraping and model calls and therefore requires user-supplied API keys plus access to the underlying services. See `DOCKER_SETUP.md` for Docker-specific setup and troubleshooting.

# List of tables and programs

Manuscript tables and figures, with the report chunk that produces each one and the corresponding file written by the public replay (`results/public/`):

| Manuscript item | Report (label) | Public replay output |
|:---|:---|:---|
| Table 1 (performance expectations) | none (conceptual table) | |
| Figure 1 (political keyword search) | `analysis_replication.qmd` (`fig-keyword-politics`) | `figures/figure_1_keyword_politics.png` |
| Table 2 (STM topic words) | `analysis_replication.qmd` (`tbl-stm-topics`) | `tables/table_2_stm_topic_terms.csv` |
| Table 3 (Empath top songs) | `analysis_replication.qmd` (`tbl-empath-top-songs`) | `tables/table_3_empath_top_songs.csv` |
| Table 4 (Empath known political songs) | `analysis_replication.qmd` (`tbl-empath-known-songs`) | `tables/table_4_empath_known_songs.csv` |
| Table 5 (songs about politics) | `llm_classification.qmd` (`tbl-simple-results`) | `tables/table_5_songs_about_politics.csv` |
| Figure 2 (political songs per model and year) | `llm_classification.qmd` (`fig-yearly`) | `figures/figure_2_yearly_politics_by_model.png` |
| Figure 3 (correlations between models) | `llm_classification.qmd` (`fig-corr`) | `figures/figure_3_model_correlations.png` |
| Figure 4 (average confidence by model) | `llm_classification.qmd` (`fig-confidence-by-model`) | `figures/figure_4_average_confidence_by_model.png` |
| Figure 5 (confidence by model agreement) | `llm_classification.qmd` (`fig-confidence-political`) | `figures/figure_5_confidence_by_agreement.png` |
| Figure 6 (confidence-weighted political content) | `llm_classification.qmd` (`fig-confidence-weighted`) | `figures/figure_6_confidence_weighted_politics.png` |
| Table 6 (theme categories) | `llm_classification.qmd` (`tbl-theme-categories`) | `tables/table_6_theme_categories.csv` |
| Table 7 (inter-model theme agreement) | `llm_classification.qmd` (`tbl-correlations`) | `tables/table_7_theme_agreement.csv` |
| Table 8 (LLM vs human agreement) | `human_classification.qmd` (`tbl-per-model-kappa`) | `tables/table_8_human_model_agreement.csv` |
| Table E1 (token usage and estimated costs, supplementary material) | `llm_classification.qmd` (`tbl-politics-simple-costs`) | `tables/appendix_table_e1_llm_costs.csv` |
| Supplementary figures and tables | remaining `fig-` and `tbl-` labels in the three reports | `figures/appendix_*.png`, `tables/appendix_*.csv` |

Other programs and outputs:

| Item | Program | Output |
|:---|:---|:---|
| Pipeline objects | `_targets.R` | `_targets/` (live run) or `_targets_frozen/` (frozen run) |
| Variable codebook | `codebook.qmd` | `codebook.md` (re-render with `quarto render codebook.qmd --to gfm`) |

# AI assistance

The authors made use of OpenAI's GPT-5.2-Codex, GPT 5.5, and Anthropic's Claude Sonnet 4.5, Opus 4.6, and Opus 5.5 to assist with writing and reviewing the code for lyric scraping, analysis, human-coding validation, and the replication materials. These tools were accessed through OpenAI's Codex and Anthropic's Claude Code between December 2025 and October 2026. The large language models used to measure political content are described in the Methods and in Appendix E.

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
