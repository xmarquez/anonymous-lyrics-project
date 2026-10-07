#!/usr/bin/env Rscript

# Export frozen inputs from the authors' completed live targets store (_targets/).
#
# Writes one xz-compressed RDS per target in FROZEN_TARGETS to data-frozen/, plus a snapshot of
# the original run's metadata (original_run_meta.rds) and a manifest. The frozen pipeline
# (TAR_PROJECT=frozen) reads these files instead of scraping Genius, calling LLM APIs, or running
# stm::searchK().
#
# data-frozen/ contains full copyrighted lyrics: share it only privately with editors and the
# replication team, never in the public or anonymous repository.

suppressPackageStartupMessages({
  library(targets)
  library(dplyr)
})

source(here::here("R", "frozen_targets.R"))

Sys.setenv(TAR_PROJECT = "main")
if (!dir.exists(here::here("_targets"))) {
  stop("No live targets store at _targets/. Run the full pipeline first.")
}
dir.create(here::here(FROZEN_DIR), showWarnings = FALSE)

manifest <- purrr::map(FROZEN_TARGETS, \(name) {
  message("Exporting ", name)
  object <- tar_read_raw(name)
  path <- frozen_path(name)
  saveRDS(object, path, compress = "xz")
  tibble::tibble(
    target = name,
    file = file.path(FROZEN_DIR, basename(path)),
    class = class(object)[1],
    rows = if (is.data.frame(object)) nrow(object) else NA_integer_,
    bytes = file.size(path),
    md5 = unname(tools::md5sum(path)),
    contains_full_lyrics = name %in% c("hot100_genius_sample", "hot100_genius_full", "stm_processed")
  )
}) |>
  purrr::list_rbind()

meta <- tar_meta()
saveRDS(meta, here::here(FROZEN_DIR, "original_run_meta.rds"), compress = "xz")

readr::write_csv(manifest, here::here(FROZEN_DIR, "manifest.csv"))
message("Wrote ", nrow(manifest), " frozen inputs (", round(sum(manifest$bytes) / 1e6, 1), " MB) to ", FROZEN_DIR, "/")
