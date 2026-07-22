#' Human male tissue polygon data
#'
#' A tidy tibble of body-outline and organ polygons for the human male
#' anatogram, parsed directly from the EBI Expression Atlas anatomogram SVG
#' source (see `data-raw/build_data.R` and `dev/NOTES.md`).
#'
#' @format A tibble with one row per polygon vertex:
#' \describe{
#'   \item{tissue_id}{Ontology ID (e.g. `"UBERON_0000948"`), or `"outline"`
#'     for the body silhouette.}
#'   \item{tissue_name}{Human-readable tissue name from the SVG's `<title>`
#'     element, where present (`NA` for a handful of cell-type-marker
#'     tissues -- see `dev/NOTES.md`).}
#'   \item{ontology}{Ontology prefix (`"UBERON"` or `"CL"`), or `NA` for the
#'     outline.}
#'   \item{element_index, subpath}{Internal grouping keys -- use
#'     `polygon_id` instead unless debugging the parser.}
#'   \item{polygon_id, group}{Identical, duplicated under two names: unique
#'     ID per disjoint polygon ring. Use directly as `group` when passing
#'     this data as `ggplot2::geom_map()`'s `map` argument (see
#'     `examples/geom_map_demo.R`) -- `geom_map()` requires a literal
#'     `group` column, and without it, multi-blob organs (e.g. the two
#'     lungs) would incorrectly merge into one connect-the-dots shape.}
#'   \item{id}{Duplicate of `tissue_id`, present because `ggplot2::geom_map()`
#'     requires a literal `id` column on its `map` argument.}
#'   \item{x, y}{Vertex coordinates, already oriented right-side-up for
#'     direct plotting -- do **not** add `ggplot2::scale_y_reverse()`.
#'     (The raw SVG source has y growing downward; `y` here has already
#'     been flipped once, at package-data build time, rather than asking
#'     every plot to reverse it itself -- `scale_y_reverse()` actively
#'     breaks `ggplot2::geom_map()`, since `geom_map()`'s polygon
#'     coordinates never pass through the normal scale-training pipeline.
#'     See `dev/NOTES.md`, Milestone 8.)}
#'   \item{outline_role}{For `tissue_id == "outline"` rows only (`NA`
#'     otherwise): `"silhouette"` (the plain outer body shape),
#'     `"contour_detail"` (the same full-body shape but with interior
#'     cut-lines for fingers/toes/ears/joints), or `"feature"` (small
#'     facial marks -- eyes, nostril, mouth). Classified from geometry at
#'     build time (bounding-box area, then point count), not from any tag
#'     in the SVG source -- see `dev/NOTES.md`, Milestone 11.}
#' }
#' @source \url{https://github.com/ebi-gene-expression-group/anatomogram}
#'   (images CC-BY-4.0, code Apache-2.0). See `dev/NOTES.md` for attribution
#'   and parsing details.
"hgMale"

#' Human female tissue polygon data
#'
#' Same structure as [hgMale], for the human female anatomogram.
#'
#' @format See [hgMale].
#' @source \url{https://github.com/ebi-gene-expression-group/anatomogram}
#'   (images CC-BY-4.0, code Apache-2.0). See `dev/NOTES.md` for attribution
#'   and parsing details.
"hgFemale"

#' Organ system membership for anatomogram tissues
#'
#' A hand-curated lookup table mapping each `tissue_id` in [hgMale]/[hgFemale]
#' to one or more organ systems (Skeletal, Muscular, Integumentary, Nervous,
#' Endocrine, Cardiovascular, Lymphatic/Immune, Respiratory, Digestive,
#' Urinary, Reproductive). Nothing in the EBI SVG source encodes this --
#' see `data-raw/organ_systems.csv` and `dev/NOTES.md`, Milestone 11, for the
#' curation approach. Use [anatomogram_select()] rather than joining against
#' this table directly for the common case.
#'
#' @format A data frame, long format (one row per `tissue_id` x `system`
#'   pair -- a tissue belonging to more than one system, e.g. the pancreas
#'   in both Digestive and Endocrine, has more than one row):
#' \describe{
#'   \item{tissue_id}{Ontology ID, matches [hgMale]/[hgFemale]'s `tissue_id`.}
#'   \item{tissue_name}{Human-readable name, for readability only -- not
#'     used for matching (tissue_name strings are inconsistent across sexes
#'     for the same tissue_id; join on tissue_id instead).}
#'   \item{system}{One of the 11 systems listed above.}
#' }
"organ_systems"
