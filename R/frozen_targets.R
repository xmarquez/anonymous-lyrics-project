# Frozen-input mode
#
# Targets that scrape Genius, call paid LLM APIs, or run the multi-hour STM search
# can be replaced by "frozen" copies of their outputs from the authors' original run.
# Frozen mode is active when the targets project is "frozen" (see _targets.yaml), e.g.
#   Sys.setenv(TAR_PROJECT = "frozen"); targets::tar_make()
# The frozen run uses its own store (_targets_frozen/) and reads inputs from data-frozen/,
# which is written from the original store by scripts/export_frozen_inputs.R.

FROZEN_DIR <- "data-frozen"

# Targets whose outputs are frozen. Everything downstream is recomputed.
FROZEN_TARGETS <- c(
  "hot100_genius_sample",
  "hot100_genius_full",
  "politics_simple_responses_sample",
  "combined_responses_politics_simple",
  "politics_categories",
  "politics_categories_human",
  "politics_themes_responses_sample",
  "combined_responses_politics_themes",
  "stm_search_k"
)

use_frozen <- function() {
  identical(Sys.getenv("TAR_PROJECT"), "frozen")
}

frozen_path <- function(name) {
  here::here(FROZEN_DIR, paste0(name, ".rds"))
}

#' Swap a live target for a frozen one when frozen mode is active
#'
#' In live mode, returns `target` unchanged. In frozen mode, returns a file target tracking
#' `data-frozen/<name>.rds` plus a target with the original name that reads it, so downstream
#' targets need no changes.
#'
#' @param target A target object created with [targets::tar_target()].
#' @returns A target object or a list of two target objects.
tar_frozen <- function(target) {
  if (!use_frozen()) {
    return(target)
  }
  name <- target$settings$name
  stopifnot(name %in% FROZEN_TARGETS)
  file_name <- paste0(name, "_frozen_file")
  list(
    targets::tar_target_raw(
      name = file_name,
      command = call("frozen_path", name),
      format = "file",
      deployment = "main",
      description = paste("Frozen input file for", name)
    ),
    targets::tar_target_raw(
      name = name,
      command = call("readRDS", as.symbol(file_name)),
      deployment = "main",
      description = paste("Frozen:", target$settings$description)
    )
  )
}

#' Pipeline metadata for reports
#'
#' In frozen mode, returns the metadata snapshot of the authors' original run so that reported
#' runtimes refer to the original scraping and API calls rather than to reading frozen files.
#'
#' @returns A data frame as returned by [targets::tar_meta()].
pipeline_meta <- function() {
  snapshot <- here::here(FROZEN_DIR, "original_run_meta.rds")
  if (use_frozen() && file.exists(snapshot)) {
    return(readRDS(snapshot))
  }
  targets::tar_meta()
}
