#!/usr/bin/env Rscript

# run.R - Entry point for running the targets pipeline
# This script is designed to be run both locally and in Docker containers

# Print startup message
message("==============================================")
message("Starting Lyrics Analysis Pipeline")
message("==============================================")
message("")

# Load required libraries
suppressPackageStartupMessages({
  library(targets)
})

# Check if .Renviron exists and API keys are set
if (!file.exists(".Renviron")) {
  warning("No .Renviron file found. Please copy .Renviron.example to .Renviron and add your API keys.")
}

# Verify critical API keys are set
required_keys <- c("OPENAI_API_KEY", "GROQ_API_KEY", "GENIUS_API_TOKEN",
                   "ANTHROPIC_API_KEY", "GEMINI_API_KEY", "MISTRAL_API_KEY")
missing_keys <- required_keys[!nchar(Sys.getenv(required_keys)) > 0]

if (length(missing_keys) > 0) {
  warning("The following API keys are not set: ", paste(missing_keys, collapse = ", "))
  message("Some targets may fail without these keys.")
  message("")
}

# Print session info for reproducibility
message("R Session Information:")
message("R version: ", R.version.string)
message("Working directory: ", getwd())
message("")

# Check if targets store exists
if (dir.exists("_targets")) {
  message("Found existing _targets store")
  message("")
}

# Run the targets pipeline
message("Running targets pipeline...")
message("Use tar_make() to run the pipeline")
message("")

# You can customize the behavior here:
# - Run all targets: tar_make()
# - Run specific targets: tar_make(names = c("target1", "target2"))
# - Run with specific workers: modify _targets.R
# - Visualize the pipeline: tar_visnetwork()

# Uncomment the line below to run the entire pipeline automatically
# tar_make()

# Or for interactive use in Docker, you might want:
# tar_make()

message("==============================================")
message("To run the pipeline, execute: targets::tar_make()")
message("To visualize the pipeline: targets::tar_visnetwork()")
message("To see outdated targets: targets::tar_outdated()")
message("==============================================")
