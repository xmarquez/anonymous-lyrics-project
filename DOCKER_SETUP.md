# Docker Setup for Reproducible Lyrics Analysis

This document describes Docker-based execution for the replication package. Docker is most useful for the optional full live pipeline, which requires API credentials and reruns scraping and LLM calls. The public replay (`run_public.R`) and the frozen run (`run_frozen.R`) can also be run inside the container.

## Included Files

- `Dockerfile`: main pipeline container.
- `Dockerfile.rstudio`: optional RStudio Server container.
- `docker-compose.yml`: container orchestration.
- `.dockerignore`: files excluded from Docker build contexts.
- `renv.lock`, `.Rprofile`, `renv/activate.R`, `renv/settings.json`: R dependency bootstrap files.
- `requirements-empath.txt`: Python dependencies for Empath targets.

## Prerequisites

- Docker Desktop or another recent Docker installation with Docker Compose.
- Local API credentials for services used by the full live pipeline.

## Environment Setup

Copy the template file and fill in local credentials:

```bash
cp .Renviron.example .Renviron
```

The repository excludes `.Renviron`; do not commit API keys.

Leave `RETICULATE_PYTHON` commented out when using Docker. The Docker image sets the container path automatically; that variable is only needed for local non-Docker runs.

## Build the Main Image

```bash
docker build -t lyrics-analysis:latest .
```

or:

```bash
docker compose build lyrics-pipeline
```

The image restores R packages from `renv.lock`, installs Quarto, and installs the Empath Python environment listed in `requirements-empath.txt`.

## Run the Full Live Pipeline

Using the project wrapper:

```bash
USE_DOCKER=1 ./run.sh
```

Using Docker Compose directly:

```bash
docker compose up -d lyrics-pipeline
docker compose exec lyrics-pipeline bash
Rscript -e "targets::tar_make()"
```

To run selected targets:

```bash
TARGETS=politics_simple_responses_sample USE_DOCKER=1 ./run.sh
```

or, inside the container:

```bash
Rscript -e "targets::tar_make(names = c('politics_simple_responses_sample'))"
```

## Optional RStudio Server

For interactive work:

```bash
docker compose --profile rstudio up -d rstudio
```

Then open `http://localhost:8787`. The development compose file disables authentication for local use only.

## Volumes and Persistence

`docker-compose.yml` bind-mounts the project directory and mounts a named Docker volume at `renv/library`. That keeps installed R packages available between runs and avoids the bind mount shadowing the restored package library.

Targets outputs are written under `_targets/` at runtime and persist in the mounted project directory.

## Empath Requirements

The Dockerfile installs Python, creates `/opt/empath_venv`, installs `requirements-empath.txt`, and sets `RETICULATE_PYTHON` to that virtual environment. Preserve those steps if the image is customized.

## Troubleshooting

If `renv::restore()` fails during a build, first verify that the lockfile restores outside Docker:

```bash
Rscript -e "renv::restore(prompt = FALSE)"
```

If API calls fail, check that variables from `.Renviron` are visible inside the container:

```bash
docker compose exec lyrics-pipeline Rscript -e "nzchar(Sys.getenv('OPENAI_API_KEY'))"  # TRUE if set; does not print the key
```

To inspect Docker disk use:

```bash
docker system df
```

## Runs Without API Keys

The public replay and the frozen run need no credentials, and `.Renviron` is optional in `docker-compose.yml`
(Docker Compose 2.24 or later):

```bash
docker compose run --rm lyrics-pipeline Rscript run_public.R
docker compose run --rm lyrics-pipeline Rscript run_frozen.R   # requires data-frozen/ (private package)
```

The frozen run writes to `_targets_frozen/`, which persists in the mounted project directory.
