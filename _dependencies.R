# Packages used indirectly that renv's dependency scan cannot see, declared here so renv::snapshot() keeps them in
# renv.lock. This file is never sourced.

# stm::textProcessor() (stm_processed target) requires tm and, for stemming, SnowballC; stm only suggests them.
library(tm)
library(SnowballC)
