# Builds data/organ_systems.rda from the hand-curated data-raw/organ_systems.csv
# (see dev/NOTES.md, Milestone 11 -- there's no organ-system hierarchy in the EBI
# source to derive this from, so it's a manual mapping). Sourced from
# data-raw/build_data.R, which must run first: this script validates its
# coverage against the just-built hgMale/hgFemale, so both must already
# exist in the calling environment.

organ_systems <- read.csv("data-raw/organ_systems.csv", stringsAsFactors = FALSE)

data_ids <- unique(c(hgMale$tissue_id, hgFemale$tissue_id))
data_ids <- setdiff(data_ids, "outline")

missing_from_csv <- setdiff(data_ids, organ_systems$tissue_id)
if (length(missing_from_csv) > 0) {
  stop("organ_systems.csv is missing tissue_id(s) present in hgMale/hgFemale: ",
       paste(missing_from_csv, collapse = ", "),
       ". Add a system assignment for each before rebuilding.", call. = FALSE)
}

extra_in_csv <- setdiff(organ_systems$tissue_id, data_ids)
if (length(extra_in_csv) > 0) {
  stop("organ_systems.csv has tissue_id(s) not present in hgMale/hgFemale: ",
       paste(extra_in_csv, collapse = ", "),
       ". Remove or correct these rows.", call. = FALSE)
}

usethis::use_data(organ_systems, overwrite = TRUE)

cat("Wrote data/organ_systems.rda (", nrow(organ_systems), "rows,",
    length(unique(organ_systems$tissue_id)), "distinct tissues,",
    length(unique(organ_systems$system)), "systems )\n")
