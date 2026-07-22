# anatomogramdata

Tidy, ontology-tagged, ggplot2-ready human anatomogram polygon data
(`hgMale`/`hgFemale`), parsed directly from the [EBI Expression Atlas
anatomogram SVG source](https://github.com/ebi-gene-expression-group/anatomogram)
— not a frozen hardcoded snapshot.

This is a **data package, not a plotting package**. There is no custom
geom or plotting function — plot the bundled data with
`ggplot2::geom_map()` or `ggplot2::geom_polygon()` directly, which already
provide full aesthetic flexibility (fill, alpha, colour, linewidth, ...)
with no package-specific code needed.

Human only (male + female) — no mouse/other-organism data.

## Installation

```r
# install.packages("remotes")
remotes::install_github("<account>/anatomogramdata")
```

## Quick start

`anatomogram_select()` is the package's single entry point for browsing,
selecting, and filtering the bundled anatomy data.

```r
library(anatomogramdata)
library(ggplot2)

# browse: what tissues and organ systems are available
anatomogram_select("male")

# select specific organs and attach a value to each (e.g. for fill)
d <- anatomogram_select("male", organs = c(kidney = "High", heart = "Low"))

ggplot(d, aes(x, y, group = group)) +
  geom_polygon(data = subset(d, tissue_id == "outline"),
               fill = "grey90", colour = "black") +
  geom_polygon(data = subset(d, tissue_id != "outline"),
               aes(fill = value), colour = "black") +
  coord_fixed() +
  theme_void()

# or pull a whole organ system at once
bones <- anatomogram_select("male", system = "Skeletal")
```

See `examples/` for more worked patterns, including faceting by organ
system and the `ggplot2::geom_map()` power-user path for mapping more than
one aesthetic at once.

## Attribution

Built directly from the EBI Expression Atlas anatomogram source
(Apache-2.0 code / CC-BY-4.0 images), not a fork of the `gganatogram`
package's code or bundled data — though structurally indebted to
`gganatogram` (Jesper Grud Skat Madsen / jespermaag) as prior art. See
`NOTES.md` for the full build history and attribution/licensing details.

## License

MIT © Peter Tanksley
