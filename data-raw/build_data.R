# Builds the package's bundled data objects (data/hgMale.rda, data/hgFemale.rda)
# from the EBI anatomogram SVG source. Re-run this whenever the source SVGs
# change; it's the only place hgMale/hgFemale get regenerated. See NOTES.md.

source("data-raw/svg_parser.R")

# Prep for direct plotting/geom_map() use -- flips SVG's y-down convention
# to standard Cartesian (removes the need for scale_y_reverse() everywhere
# downstream, which is not just a convenience: scale_y_reverse() actively
# breaks ggplot2::geom_map(), since geom_map()'s polygon coordinates never
# pass through the normal scale-training pipeline -- see NOTES.md,
# Milestone 8), and adds the `id`/`group` columns geom_map() requires.
# `group` in particular is not optional: without it, geom_map() defaults
# grouping to `id` and merges multi-blob organs (e.g. the two lungs) into
# one broken connect-the-dots shape.
prep_for_package <- function(df) {
  df$y <- -df$y
  df$id <- df$tissue_id
  df$group <- df$polygon_id
  df
}

hgMale   <- prep_for_package(extract_tissue_paths("data-raw/ebi-source/homo_sapiens.male.svg"))
hgFemale <- prep_for_package(extract_tissue_paths("data-raw/ebi-source/homo_sapiens.female.svg"))

# Classifies each `tissue_id == "outline"` subpath (grouped by `group`) into
# one of three roles, purely from geometry. There's no SVG-level tag to use
# instead: the outline comes from a single compound path in the male SVG
# and a differently-nested group of paths in the female SVG (confirmed by
# reading both source files directly), so subpath *numbers* don't
# correspond between sexes at all -- but in both, the two
# largest-bounding-box subpaths are always the two full-body variants, and
# between those two, the one with more vertices is consistently the
# version with interior contour/joint lines cut into it (fingers, toes,
# ears), while the one with fewer is the plain silhouette. Everything else
# is a small facial/decorative mark. See NOTES.md, Milestone 11.
classify_outline_role <- function(df) {
  df$outline_role <- NA_character_
  out_idx <- which(df$tissue_id == "outline")
  if (length(out_idx) == 0) return(df)

  out <- df[out_idx, ]
  areas <- tapply(seq_len(nrow(out)), out$group, function(idx) {
    diff(range(out$x[idx])) * diff(range(out$y[idx]))
  })
  counts <- table(out$group)[names(areas)]

  top2 <- names(sort(areas, decreasing = TRUE))[1:2]
  role <- setNames(rep("feature", length(areas)), names(areas))
  role[top2[which.max(counts[top2])]] <- "contour_detail"
  role[top2[which.min(counts[top2])]] <- "silhouette"

  df$outline_role[out_idx] <- role[out$group]
  df
}

hgMale   <- classify_outline_role(hgMale)
hgFemale <- classify_outline_role(hgFemale)

usethis::use_data(hgMale, overwrite = TRUE)
usethis::use_data(hgFemale, overwrite = TRUE)

cat("Wrote data/hgMale.rda (", nrow(hgMale), "rows ) and data/hgFemale.rda (",
    nrow(hgFemale), "rows )\n")

source("data-raw/build_organ_systems.R")
