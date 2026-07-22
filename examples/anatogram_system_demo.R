# Demo: filtering/faceting by organ system via anatogram_select(system = ...),
# and separating the outer body silhouette from its interior contour detail
# via the outline_role column. Neither of these is derived from any tag in
# the EBI SVG source -- both are computed (geometry for outline_role,
# hand-curated lookup for organ system) -- see NOTES.md, Milestones 11-12.

devtools::load_all(".", quiet = TRUE)
library(ggplot2)

outline <- hgMale[hgMale$tissue_id == "outline", ]
body    <- outline[outline$outline_role == "silhouette", ]
contour <- outline[outline$outline_role == "contour_detail", ]

# (a) silhouette vs. interior contour lines, styled differently -- this is
# the outline_role column directly on hgMale, unrelated to anatogram_select()
p1 <- ggplot(body, aes(x, y, group = group)) +
  geom_polygon(fill = "grey90", colour = "black", linewidth = 0.3) +
  geom_polygon(data = contour, fill = NA, colour = "grey40", linewidth = 0.15) +
  expand_limits(x = outline$x, y = outline$y) +
  coord_fixed() + theme_void() +
  labs(title = "outline_role: silhouette (solid) vs. contour_detail (thin overlay)")
ggsave("examples/anatogram_system_silhouette_vs_contour.png", p1, width = 6, height = 8, dpi = 150)

# (b) "all bones" -- one system, no values needed. anatogram_select()'s
# system mode includes the outline automatically (outline = TRUE, the
# default) -- no need to assemble a backdrop layer by hand.
bones <- anatogram_select("male", system = "Skeletal")
p2 <- ggplot(bones, aes(x, y, group = group)) +
  geom_polygon(data = subset(bones, tissue_id == "outline"),
               fill = "grey95", colour = "black", linewidth = 0.2) +
  geom_polygon(data = subset(bones, tissue_id != "outline"),
               fill = "grey40", colour = "black") +
  expand_limits(x = outline$x, y = outline$y) +
  coord_fixed() + theme_void() +
  labs(title = "anatogram_select(\"male\", system = \"Skeletal\")")
ggsave("examples/anatogram_system_bones.png", p2, width = 6, height = 8, dpi = 150)

# (c) facet by system -- pancreas will correctly appear in both Digestive
# and Endocrine panels, since it's a real dual-system membership, not a
# bug. Each requested system gets its own outline block (tagged with that
# system), so every facet panel gets its own backdrop for free.
several <- anatogram_select("male", system = c("Skeletal", "Digestive", "Respiratory", "Endocrine"))
p3 <- ggplot(several, aes(x, y, group = group)) +
  geom_polygon(data = subset(several, tissue_id == "outline"),
               fill = "grey95", colour = "black", linewidth = 0.15) +
  geom_polygon(data = subset(several, tissue_id != "outline"),
               fill = "steelblue", colour = "black") +
  expand_limits(x = outline$x, y = outline$y) +
  coord_fixed() + theme_void() +
  facet_wrap(~ system) +
  labs(title = "anatogram_select(\"male\", system = c(\"Skeletal\",\"Digestive\",\"Respiratory\",\"Endocrine\"))")
ggsave("examples/anatogram_system_facets.png", p3, width = 10, height = 10, dpi = 150)

cat("Wrote examples/anatogram_system_silhouette_vs_contour.png, _bones.png, _facets.png\n")
