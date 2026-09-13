VAL_2026_RESULT_INDEX_URL <- "https://resultat.val.se/resultatfiler/val2026/index.md5"

val_2026_district_sources <- function() {
  source_page <- "https://www.val.se/valresultat-och-statistik/statistik-och-data/radata-val-2026"

  data.frame(
    key = c(
      "district_maps_geojson_zip",
      "districts_xlsx",
      "district_comparability_xlsx",
      "eligible_voters_rd_xlsx",
      "result_files_index_md5"
    ),
    url = c(
      "https://www.val.se/download/18.332cf48819bd61ac1513889/1785491689960/valdistrikt-riket-2026.zip",
      "https://www.val.se/download/18.332cf48819bd61ac151499d/1779801380664/valdistrikt-hela-landet-2026.xlsx",
      "https://www.val.se/download/18.1a2972da19f159e73fd3a47/1787064655347/valdistrikt-jamforelser-mellan-2022-och-2026.xlsx",
      "https://www.val.se/download/18.1a2972da19f159e73fd3b4a/1787064446298/antal-rostberattigade-per-valdistrikt-uppdelat-pa-kon-och-alder-kvalifikationsdagen-14-augusti-2026-val-till-riksdagen.xlsx",
      VAL_2026_RESULT_INDEX_URL
    ),
    filename = c(
      "valdistrikt_riket_2026.zip",
      "valdistrikt_hela_landet_2026.xlsx",
      "valdistrikt_jamforelser_2022_2026.xlsx",
      "rostberattigade_rd_kvalifikationsdagen_2026.xlsx",
      "resultatfiler_index.md5"
    ),
    source_page = c(rep(source_page, 4), "https://www.val.se/valresultat-och-statistik/statistik-och-data/teknisk-beskrivning-av-resultatfiler"),
    description = c(
      "National 2026 district map GeoJSON in ZIP, SWEREF99 TM.",
      "All Swedish 2026 election districts without coordinates.",
      "Valmyndigheten comparability assessment between 2022 and 2026 districts.",
      "Eligible voters for the 2026 Riksdag election by district, age, and sex on 2026-08-14.",
      "Index for downloadable 2026 result ZIP files. This may be empty before results are published."
    ),
    stringsAsFactors = FALSE
  )
}

download_val_2026_district_data <- function(data_dir = "data/val_2026",
                                            force = FALSE,
                                            unzip_maps = TRUE,
                                            quiet = FALSE) {
  sources <- val_2026_district_sources()
  raw_dir <- file.path(data_dir, "raw")
  metadata_dir <- file.path(data_dir, "metadata")
  geojson_dir <- file.path(data_dir, "geojson")

  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(metadata_dir, recursive = TRUE, showWarnings = FALSE)
  if (isTRUE(unzip_maps)) {
    dir.create(geojson_dir, recursive = TRUE, showWarnings = FALSE)
  }

  manifest <- sources
  manifest$path <- file.path(raw_dir, manifest$filename)
  manifest$downloaded <- FALSE
  manifest$exists <- FALSE
  manifest$bytes <- NA_real_
  manifest$md5 <- NA_character_
  manifest$fetched_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")

  for (i in seq_len(nrow(manifest))) {
    dest <- manifest$path[i]
    if (!file.exists(dest) || isTRUE(force)) {
      if (!quiet) {
        message("Downloading ", manifest$key[i], " -> ", dest)
      }
      utils::download.file(
        url = manifest$url[i],
        destfile = dest,
        mode = "wb",
        quiet = quiet
      )
      manifest$downloaded[i] <- TRUE
    }

    manifest$exists[i] <- file.exists(dest)
    if (manifest$exists[i]) {
      manifest$bytes[i] <- file.info(dest)$size
      manifest$md5[i] <- unname(tools::md5sum(dest))
    }
  }

  if (isTRUE(unzip_maps)) {
    zip_path <- file.path(raw_dir, "valdistrikt_riket_2026.zip")
    if (file.exists(zip_path)) {
      files <- utils::unzip(zip_path, list = TRUE)
      geojson_files <- files$Name[grepl("\\.geojson$", files$Name, ignore.case = TRUE)]
      if (length(geojson_files) != 1L) {
        stop("Expected exactly one GeoJSON file in ", zip_path, call. = FALSE)
      }
      utils::unzip(zip_path, files = geojson_files, exdir = geojson_dir, overwrite = TRUE)
    }
  }

  manifest_path <- file.path(metadata_dir, "source_manifest.csv")
  utils::write.csv(manifest, manifest_path, row.names = FALSE, fileEncoding = "UTF-8")

  result_index_path <- file.path(raw_dir, "resultatfiler_index.md5")
  if (file.exists(result_index_path)) {
    result_index <- readLines(result_index_path, warn = FALSE, encoding = "UTF-8")
    result_index <- trimws(result_index[nzchar(trimws(result_index))])
    result_index <- result_index[result_index != "d41d8cd98f00b204e9800998ecf8427e  -"]
    writeLines(result_index, file.path(metadata_dir, "resultatfiler_index_entries.txt"), useBytes = TRUE)
  }

  invisible(manifest)
}

read_val_2026_result_index <- function(index_path) {
  if (!file.exists(index_path)) {
    stop("Result index does not exist: ", index_path, call. = FALSE)
  }

  lines <- readLines(index_path, warn = FALSE, encoding = "UTF-8")
  lines <- trimws(lines[nzchar(trimws(lines))])
  lines <- lines[lines != "d41d8cd98f00b204e9800998ecf8427e  -"]

  if (length(lines) == 0L) {
    return(data.frame(md5 = character(), relative_path = character()))
  }

  parts <- strsplit(lines, "[[:space:]]+", perl = TRUE)
  bad <- vapply(parts, length, integer(1)) < 2L
  if (any(bad)) {
    stop("Could not parse result index line(s): ", paste(lines[bad], collapse = "; "), call. = FALSE)
  }

  data.frame(
    md5 = vapply(parts, `[[`, character(1), 1L),
    relative_path = vapply(parts, function(x) paste(x[-1L], collapse = " "), character(1)),
    stringsAsFactors = FALSE
  )
}

val_2026_timestamped_path <- function(path, time = Sys.time()) {
  suffix <- format(time, "%H.%M")
  extension <- tools::file_ext(path)

  if (!nzchar(extension)) {
    return(paste0(path, "_", suffix))
  }

  stem <- substr(path, 1L, nchar(path) - nchar(extension) - 1L)
  paste0(stem, "_", suffix, ".", extension)
}

escape_regex <- function(x) {
  gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", x, perl = TRUE)
}

val_2026_result_candidates <- function(path) {
  directory <- dirname(path)
  filename <- basename(path)
  extension <- tools::file_ext(filename)
  stem <- if (nzchar(extension)) {
    substr(filename, 1L, nchar(filename) - nchar(extension) - 1L)
  } else {
    filename
  }

  pattern <- paste0(
    "^",
    escape_regex(stem),
    "_[0-9]{2}\\.[0-9]{2}",
    if (nzchar(extension)) paste0("\\.", escape_regex(extension)) else "",
    "$"
  )

  timestamped <- if (dir.exists(directory)) {
    file.path(directory, list.files(directory, pattern = pattern))
  } else {
    character()
  }

  unique(c(path, timestamped))
}

val_2026_find_result_by_md5 <- function(path, expected_md5) {
  candidates <- val_2026_result_candidates(path)
  candidates <- candidates[file.exists(candidates)]
  if (length(candidates) == 0L) {
    return(NA_character_)
  }

  md5 <- unname(tools::md5sum(candidates))
  matches <- candidates[identical_character(md5, expected_md5)]
  if (length(matches) == 0L) {
    return(NA_character_)
  }

  matches[which.max(file.info(matches)$mtime)]
}

identical_character <- function(x, value) {
  !is.na(x) & x == value
}

download_val_2026_result_files <- function(data_dir = "data/val_2026",
                                           force = FALSE,
                                           quiet = FALSE,
                                           base_url = "https://resultat.val.se/resultatfiler/val2026") {
  raw_dir <- file.path(data_dir, "raw")
  results_dir <- file.path(data_dir, "results")
  metadata_dir <- file.path(data_dir, "metadata")
  index_path <- file.path(raw_dir, "resultatfiler_index.md5")

  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(metadata_dir, recursive = TRUE, showWarnings = FALSE)

  utils::download.file(
    url = VAL_2026_RESULT_INDEX_URL,
    destfile = index_path,
    mode = "wb",
    quiet = quiet
  )

  index <- read_val_2026_result_index(index_path)
  if (nrow(index) == 0L) {
    manifest <- data.frame(
      md5 = character(),
      relative_path = character(),
      url = character(),
      path = character(),
      downloaded = logical(),
      md5_ok = logical(),
      stringsAsFactors = FALSE
    )
    utils::write.csv(
      manifest,
      file.path(metadata_dir, "result_files_manifest.csv"),
      row.names = FALSE,
      fileEncoding = "UTF-8"
    )
    if (!quiet) {
      message("No result files are currently listed in ", VAL_2026_RESULT_INDEX_URL)
    }
    return(invisible(manifest))
  }

  manifest <- index
  manifest$url <- paste0(
    sub("/$", "", base_url),
    "/",
    sub("^\\./", "", manifest$relative_path)
  )
  manifest$path <- file.path(results_dir, sub("^\\./", "", manifest$relative_path))
  manifest$downloaded <- FALSE
  manifest$downloaded_minute <- NA_character_
  manifest$md5_actual <- NA_character_
  manifest$md5_ok <- FALSE

  for (i in seq_len(nrow(manifest))) {
    unstamped_dest <- manifest$path[i]
    dir.create(dirname(unstamped_dest), recursive = TRUE, showWarnings = FALSE)

    existing <- val_2026_find_result_by_md5(unstamped_dest, manifest$md5[i])
    needs_download <- isTRUE(force) || is.na(existing)

    if (needs_download) {
      download_time <- Sys.time()
      dest <- val_2026_timestamped_path(unstamped_dest, download_time)
      if (!quiet) {
        message("Downloading result file ", manifest$relative_path[i], " -> ", dest)
      }
      utils::download.file(
        url = manifest$url[i],
        destfile = dest,
        mode = "wb",
        quiet = quiet
      )
      manifest$downloaded[i] <- TRUE
      manifest$downloaded_minute[i] <- format(download_time, "%H.%M")
    } else {
      dest <- existing
    }

    manifest$path[i] <- dest
    if (file.exists(dest)) {
      manifest$md5_actual[i] <- unname(tools::md5sum(dest))
      manifest$md5_ok[i] <- identical(manifest$md5_actual[i], manifest$md5[i])
    }
  }

  if (any(!manifest$md5_ok)) {
    failed <- manifest$relative_path[!manifest$md5_ok]
    stop("Checksum mismatch for result file(s): ", paste(failed, collapse = ", "), call. = FALSE)
  }

  utils::write.csv(
    manifest,
    file.path(metadata_dir, "result_files_manifest.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )

  invisible(manifest)
}
