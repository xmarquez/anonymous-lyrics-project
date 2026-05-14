#!/usr/bin/env bash
set -euo pipefail

# run.sh - Master script for Political Analysis replication package
#
# Usage:
#   ./run.sh                 # run locally with renv
#   USE_DOCKER=1 ./run.sh     # run inside Docker using docker compose
#   TARGETS=target1,target2 ./run.sh   # run specific targets (comma-separated)
#
# Notes:
# - API keys must be set in .Renviron (see .Renviron.example).
# - Empath targets require Python dependencies; see requirements-empath.txt and DOCKER_SETUP.md.
#   On Windows, you can set up the venv with scripts/setup_empath_venv.ps1 and set RETICULATE_PYTHON.

TARGETS="${TARGETS:-}"
RUN_EXPR="targets::tar_make()"
if [[ -n "$TARGETS" ]]; then
  RUN_EXPR="targets::tar_make(names = strsplit(Sys.getenv('TARGETS'), ',', fixed = TRUE)[[1]])"
fi

if [[ ! -f .Renviron ]]; then
  echo "Missing .Renviron. Copy .Renviron.example to .Renviron and add API keys."
  exit 1
fi

if [[ "${USE_DOCKER:-}" == "1" ]]; then
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker not found. Install Docker Desktop or run locally without USE_DOCKER."
    exit 1
  fi
  echo "Running in Docker via docker compose..."
  docker compose build lyrics-pipeline
  docker compose run --rm lyrics-pipeline Rscript -e "$RUN_EXPR"
  exit 0
fi

echo "Running locally with renv..."
Rscript -e "if (!requireNamespace('renv', quietly = TRUE)) install.packages('renv', repos = c(CRAN = 'https://cloud.r-project.org'))"
Rscript -e "renv::restore()"
Rscript -e "$RUN_EXPR"
