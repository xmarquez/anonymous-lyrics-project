#!/usr/bin/env Rscript

# run_frozen.R - Run the full analysis pipeline from frozen inputs
#
# Rebuilds every downstream target (prompt construction, response processing, STM fit and effects,
# Empath, human-coding validation, cost summaries, and the three Quarto reports) from the outputs of
# the authors' original scraping and LLM runs stored in data-frozen/. No API keys are needed and no
# external services are called. Results go to a separate store, _targets_frozen/.
#
# Usage:
#   Rscript run_frozen.R
#   Rscript run_frozen.R target1 target2   # build specific targets (and their dependencies)
#
# Requirements: R packages from renv.lock; Python with the Empath package for the Empath targets
# (see requirements-empath.txt; set RETICULATE_PYTHON or create .venv/empath); Quarto for reports.

Sys.setenv(TAR_PROJECT = "frozen")
source(file.path("R", "frozen_targets.R"))

missing <- FROZEN_TARGETS[!file.exists(frozen_path(FROZEN_TARGETS))]
if (length(missing) > 0) {
  stop(
    "Missing frozen inputs in ", FROZEN_DIR, "/: ", paste(missing, collapse = ", "),
    ". These are distributed privately; see README."
  )
}

names <- commandArgs(trailingOnly = TRUE)
start <- Sys.time()
if (length(names) > 0) {
  targets::tar_make(names = tidyselect::any_of(names))
} else {
  targets::tar_make()
}
message("Frozen pipeline finished in ", format(round(difftime(Sys.time(), start, units = "mins"), 1)))
