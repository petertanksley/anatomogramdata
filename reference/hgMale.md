# Human male tissue polygon data

A tidy tibble of body-outline and organ polygons for the human male
anatogram, parsed directly from the EBI Expression Atlas anatomogram SVG
source (see `data-raw/build_data.R` and `dev/NOTES.md`).

## Usage

``` r
hgMale
```

## Format

A tibble with one row per polygon vertex:

- tissue_id:

  Ontology ID (e.g. `"UBERON_0000948"`), or `"outline"` for the body
  silhouette.

- tissue_name:

  Human-readable tissue name from the SVG's `<title>` element, where
  present (`NA` for a handful of cell-type-marker tissues – see
  `dev/NOTES.md`).

- ontology:

  Ontology prefix (`"UBERON"` or `"CL"`), or `NA` for the outline.

- element_index, subpath:

  Internal grouping keys – use `polygon_id` instead unless debugging the
  parser.

- polygon_id, group:

  Identical, duplicated under two names: unique ID per disjoint polygon
  ring. Use directly as `group` when passing this data as
  [`ggplot2::geom_map()`](https://ggplot2.tidyverse.org/reference/geom_map.html)'s
  `map` argument (see `examples/geom_map_demo.R`) –
  [`geom_map()`](https://ggplot2.tidyverse.org/reference/geom_map.html)
  requires a literal `group` column, and without it, multi-blob organs
  (e.g. the two lungs) would incorrectly merge into one connect-the-dots
  shape.

- id:

  Duplicate of `tissue_id`, present because
  [`ggplot2::geom_map()`](https://ggplot2.tidyverse.org/reference/geom_map.html)
  requires a literal `id` column on its `map` argument.

- x, y:

  Vertex coordinates, already oriented right-side-up for direct plotting
  – do **not** add
  [`ggplot2::scale_y_reverse()`](https://ggplot2.tidyverse.org/reference/scale_continuous.html).
  (The raw SVG source has y growing downward; `y` here has already been
  flipped once, at package-data build time, rather than asking every
  plot to reverse it itself –
  [`scale_y_reverse()`](https://ggplot2.tidyverse.org/reference/scale_continuous.html)
  actively breaks
  [`ggplot2::geom_map()`](https://ggplot2.tidyverse.org/reference/geom_map.html),
  since
  [`geom_map()`](https://ggplot2.tidyverse.org/reference/geom_map.html)'s
  polygon coordinates never pass through the normal scale-training
  pipeline. See `dev/NOTES.md`, Milestone 8.)

- outline_role:

  For `tissue_id == "outline"` rows only (`NA` otherwise):
  `"silhouette"` (the plain outer body shape), `"contour_detail"` (the
  same full-body shape but with interior cut-lines for
  fingers/toes/ears/joints), or `"feature"` (small facial marks – eyes,
  nostril, mouth). Classified from geometry at build time (bounding-box
  area, then point count), not from any tag in the SVG source – see
  `dev/NOTES.md`, Milestone 11.

## Source

<https://github.com/ebi-gene-expression-group/anatomogram> (images
CC-BY-4.0, code Apache-2.0). See `dev/NOTES.md` for attribution and
parsing details.
