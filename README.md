# election collection 2026

Utilities for collecting Swedish 2026 election district inputs from Valmyndigheten.

Valmyndigheten currently publishes the 2026 district geography as GeoJSON inside ZIP files, plus XLSX files for the district list, 2022-2026 comparability, and eligible voters. The result-file feed is documented through `index.md5` and can be refreshed as results become available.

## Download

Run from the repository root:

```sh
Rscript script/download_val_2026_district_data.R
```

Force a fresh download:

```sh
Rscript script/download_val_2026_district_data.R --force
```

The reusable function is `download_val_2026_district_data()` in `R/download_val_2026_district_data.R`.

## Result Files

Valmyndigheten documents result-file downloads through:

```text
https://resultat.val.se/resultatfiler/val2026/index.md5
```

When the index starts listing result ZIP files, download or refresh them with:

```sh
Rscript script/download_val_2026_result_files.R
```

The reusable function is `download_val_2026_result_files()`. It preserves the relative paths from `index.md5`, writes files under `data/val_2026/results/`, appends the download minute to each result ZIP name, and checks MD5 checksums.

For example, a result file published by Valmyndigheten as:

```text
./p/rd/Val_2026_preliminar_00_RD.zip
```

is saved locally as:

```text
data/val_2026/results/p/rd/Val_2026_preliminar_00_RD_HH.MM.zip
```

If Valmyndigheten updates the same result ZIP later in the evening, rerunning the script keeps the earlier snapshot and writes a new minute-stamped file.

## Layout

- `R/` contains reusable functions.
- `script/` contains runnable scripts.
- `data/val_2026/raw/` contains downloaded source files.
- `data/val_2026/geojson/` contains the extracted national district GeoJSON.
- `data/val_2026/results/` contains downloaded result ZIP files when available.
- `data/val_2026/metadata/` contains download manifests and result-index status files.
