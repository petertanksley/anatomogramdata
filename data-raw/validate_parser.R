# Validation: parse each source SVG and sanity-check against gganatogram's own
# rendering of the same tissues. See dev/NOTES.md (Milestones 2-3) for context.

source("data-raw/svg_parser.R")
library(ggplot2)

# No limb-segment tissue exists in this dataset (Expression Atlas's 82
# profiled tissues are internal organs, not limb regions -- confirmed by
# listing distinct tissue_name values, see dev/NOTES.md). Outline/heart/lung
# instead: lung is a paired organ, good test of disjoint-blob
# (subpath/element_index) grouping.
compare_ids <- c("outline", "UBERON_0000948", "UBERON_0002048")

runs <- list(
  list(label = "male",
       svg = "data-raw/ebi-source/homo_sapiens.male.svg",
       old_rda = "upstream/gganatogram/data/hgMale_list.rda",
       old_list_name = "hgMale_list",
       old_names = c("human_male_outline", "heart", "lung")),
  list(label = "female",
       svg = "data-raw/ebi-source/homo_sapiens.female.svg",
       old_rda = "upstream/gganatogram/data/hgFemale_list.rda",
       old_list_name = "hgFemale_list",
       old_names = c("outline", "heart", "lung"))
)

for (run in runs) {
  parsed <- extract_tissue_paths(run$svg)
  cat("[", run$label, "] Parsed", nrow(parsed), "vertices across",
      dplyr::n_distinct(parsed$tissue_id), "tissue ids and",
      dplyr::n_distinct(parsed$polygon_id), "distinct polygons\n")

  p_new <- parsed %>%
    filter(tissue_id %in% compare_ids) %>%
    ggplot(aes(x, y, group = polygon_id, fill = tissue_id)) +
    geom_polygon(colour = "black", linewidth = 0.2) +
    coord_fixed() +
    scale_y_reverse() +  # SVG y grows downward; flip so the figure reads upright
    labs(title = paste0("parse_svg.R output (", run$label, ": outline / heart / lung)")) +
    theme_minimal()
  ggsave(paste0("data-raw/validation_new_parser_", run$label, ".png"),
         p_new, width = 5, height = 7, dpi = 150)

  # gganatogram's own bundled rendering of the same tissues, for comparison.
  env <- new.env()
  load(run$old_rda, envir = env)
  old_list <- env[[run$old_list_name]]
  old_names <- intersect(run$old_names, names(old_list))
  old_df <- bind_rows(lapply(old_list[old_names], function(d) {
    d$group <- as.character(d$group)  # `group` type varies (numeric/character) across tissues
    d
  }))
  p_old <- old_df %>%
    ggplot(aes(x, y, group = group, fill = id)) +
    geom_polygon(colour = "black", linewidth = 0.2) +
    coord_fixed() +
    labs(title = paste0("gganatogram's own rendering (", run$label, ")")) +
    theme_minimal()
  ggsave(paste0("data-raw/validation_old_gganatogram_", run$label, ".png"),
         p_old, width = 5, height = 7, dpi = 150)
}

cat("\nWrote per-sex validation_new_parser_<sex>.png / validation_old_gganatogram_<sex>.png in data-raw/\n")
cat("Compare them side by side to sanity-check shape/proportions.\n")
