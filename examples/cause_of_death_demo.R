# Demo: human male anatogram highlighting organs associated with several
# CDC-style leading-cause-of-death categories, using ggplot2::geom_map()
# directly (see NOTES.md, Milestone 8/9 -- no custom plotting function
# ships in this package; geom_map() already provides everything needed).
#
# IMPORTANT: the category NAMES below are real, well-established public
# health categories (CDC's leading-causes-of-death list). The organ
# assignments are illustrative anatomical associations, not sourced
# mortality statistics -- there are no death counts, rates, or rankings
# here. Substitute real data (e.g. CDC WONDER underlying cause of death
# files) for actual analysis; this only demonstrates the plotting
# mechanics.
#
# A few CDC categories (unintentional injury, suicide) are deliberately
# omitted -- they aren't localized to one distinct internal organ, and
# forcing an organ assignment for them would be misleading rather than
# illustrative.

devtools::load_all(".", quiet = TRUE)
library(ggplot2)

# hgMale's `id` column defaults to tissue_id (UBERON/CL codes), since that's
# the exact, unambiguous key. To key by plain-English name instead (nobody
# should have to memorize ontology codes -- see anatogram_select("male")
# to browse what's available), just re-point `id` at `tissue_name`:
organs_map <- hgMale[hgMale$tissue_id != "outline", ]
organs_map$id <- organs_map$tissue_name
outline_map <- hgMale[hgMale$tissue_id == "outline", ]

# Plain-English tissue_name, not UBERON codes. ("hippocampus" alone matches
# both of the two hippocampus polygons in the source -- geom_map() handles
# one map_id spanning multiple map rows/ids just fine, same as a country
# made of several polygons on a real choropleth map.)
cause_of_death <- data.frame(
  map_id = c("heart", "coronary artery", "left ventricle",
             "colon", "prostate gland",
             "lung", "bronchus", "trachea",
             "brain", "hippocampus", "cerebral cortex",
             "pancreas",
             "kidney", "renal cortex",
             "liver"),
  cause = c("Heart disease", "Heart disease", "Heart disease",
            "Cancer (selected sites)", "Cancer (selected sites)",
            "Chronic respiratory disease", "Chronic respiratory disease", "Chronic respiratory disease",
            "Stroke", "Alzheimer's disease", "Alzheimer's disease",
            "Diabetes",
            "Kidney disease", "Kidney disease",
            "Chronic liver disease")
)

p <- ggplot(cause_of_death, aes(map_id = map_id)) +
  geom_map(data = data.frame(map_id = "outline"), map = outline_map,
           fill = "grey90", colour = "black", linewidth = 0.2) +
  geom_map(aes(fill = cause), map = organs_map, colour = "black", linewidth = 0.2) +
  scale_fill_brewer(palette = "Set2", na.value = "grey92", name = "Leading cause\nof death (illustrative)") +
  expand_limits(x = outline_map$x, y = outline_map$y) +
  coord_fixed() + theme_void() +
  labs(title = "Organs associated with leading causes of death (illustrative)",
       caption = "Category names are real (CDC-style); organ assignments are illustrative, not sourced mortality data.")

ggsave("examples/cause_of_death_demo.png", p, width = 6, height = 8, dpi = 150)
cat("Wrote examples/cause_of_death_demo.png\n")
