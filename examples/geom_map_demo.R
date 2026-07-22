# Demo: using ggplot2::geom_map() directly with hgMale -- this is THE way
# to plot this package's data (see NOTES.md, Milestones 8-9: an earlier
# gganatogram2() convenience wrapper was tried and then dropped, since
# geom_map() already covers everything it did and more, with no custom
# ggproto Geom needed). geom_map() already extends GeomPolygon and does an
# id-based join exactly like a bespoke geom_anatogram() would, inheriting
# every GeomPolygon aesthetic (fill, alpha, colour, linewidth, linetype)
# automatically.
#
# This demonstrates mapping `linewidth` per tissue from real data, alongside
# `fill` -- both just ordinary ggplot2 aesthetics, no package-specific code
# needed for either.
#
# Two requirements that are NOT optional, both already baked into
# hgMale/hgFemale by data-raw/build_data.R -- see R/data.R:
#   1. `map` must have a literal `group` column (not just `id`/`tissue_id`).
#      Without it, geom_map() defaults grouping to `id` and merges
#      multi-blob organs (e.g. the two lungs, drawn here) into one broken
#      connect-the-dots shape.
#   2. Do NOT add scale_y_reverse() -- geom_map()'s polygon coordinates
#      never pass through ggplot2's normal scale-training pipeline, so
#      scale_y_reverse() trains on no real data and collapses the plot to
#      a tiny sliver. hgMale/hgFemale ship with `y` already flipped for
#      exactly this reason.

devtools::load_all(".", quiet = TRUE)
library(ggplot2)

outline <- hgMale[hgMale$tissue_id == "outline", ]
organs_map <- hgMale[hgMale$tissue_id != "outline", ]

cause_of_death <- data.frame(
  map_id = c("UBERON_0000948", "UBERON_0002048", "UBERON_0002107"),
  cause  = c("Heart disease", "Chronic respiratory disease", "Chronic liver disease"),
  # Illustrative confidence weighting -- NOT real data -- just to show a
  # second aesthetic (linewidth) varying per tissue, independent of fill.
  confidence = c("High", "High", "Medium")
)

p <- ggplot(cause_of_death, aes(map_id = map_id)) +
  geom_map(data = data.frame(map_id = "outline"), map = outline,
           fill = "grey90", colour = "black", linewidth = 0.2) +
  geom_map(aes(fill = cause, linewidth = confidence), map = organs_map, colour = "black") +
  scale_linewidth_manual(values = c(High = 1, Medium = 0.3)) +
  expand_limits(x = outline$x, y = outline$y) +
  coord_fixed() +
  theme_void() +
  labs(title = "geom_map() power-user demo: fill + linewidth, both from real data columns",
       caption = "Illustrative only -- not real mortality data.")

ggsave("examples/geom_map_demo.png", p, width = 6, height = 8, dpi = 150)
cat("Wrote examples/geom_map_demo.png\n")
