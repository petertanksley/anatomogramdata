# Demo: the quick-start path via anatogram_select(organs = ...) -- skips
# geom_map()'s map/data join entirely for the common case of "I have one
# value per organ, plot it." See examples/geom_map_demo.R and
# examples/cause_of_death_demo.R for the geom_map() power-user path (needed
# when mapping more than one aesthetic to real data, e.g. fill + linewidth
# together).
#
# anatogram_select() resolves organ names (fuzzy, case-insensitive partial
# match against tissue_name -- see anatogram_select("male") for the browse
# table) or literal tissue_id values to a single flat data frame, ready
# for plain ggplot2::geom_polygon() -- no map_id, no separate map= argument.

devtools::load_all(".", quiet = TRUE)
library(ggplot2)

d <- anatogram_select(
  "male",
  organs = c(kidney = "High", heart = "High", lung = "Medium", liver = "Low")
)

p <- ggplot(d, aes(x, y, group = group)) +
  geom_polygon(data = subset(d, tissue_id == "outline"),
               fill = "grey90", colour = "black", linewidth = 0.2) +
  geom_polygon(data = subset(d, tissue_id != "outline"),
               aes(fill = value), colour = "black") +
  expand_limits(x = d$x, y = d$y) +
  coord_fixed() +
  theme_void() +
  labs(title = "anatogram_select(organs = ...) quick-start: one value per organ, geom_polygon() only",
       fill = "Value")

ggsave("examples/anatogram_values_demo.png", p, width = 6, height = 8, dpi = 150)
cat("Wrote examples/anatogram_values_demo.png\n")
