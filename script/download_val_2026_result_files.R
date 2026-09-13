#!/usr/bin/env Rscript

source("R/download_val_2026_district_data.R")

download_val_2026_result_files(
  data_dir = "data/val_2026",
  force = "--force" %in% commandArgs(trailingOnly = TRUE)
)
