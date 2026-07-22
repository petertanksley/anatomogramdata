# anatomogramdata

An R **data package** (renamed from `gganatogram2` — see `NOTES.md`, Milestone 9). Low-priority side project — keep conventions here minimal and only expand as the project actually grows.

## What this is

- Provides tidy, ontology-tagged, ggplot2-ready human anatomogram polygon data (`hgMale`/`hgFemale`), parsed directly from the EBI Expression Atlas anatomogram SVG source (https://ebi-gene-expression-group.github.io/anatomogram/) — not a frozen hardcoded snapshot like the original `gganatogram` package's bundled data.
- This is a **data package, not a plotting package**. There is no custom geom or plotting function — plot the data with `ggplot2::geom_map()` directly (see `examples/geom_map_demo.R`), which already provides full aesthetic flexibility (fill, alpha, colour, linewidth, ...) with no package-specific code needed. A `gganatogram2()` convenience wrapper was built and then deliberately removed once this became clear (Milestone 9).
- `anatogram_select(sex, organs, system, value_name, outline)` (Milestone 12) is the package's single exported function, consolidating what were three separate functions (`anatogram_tissues()`, `anatogram_values()`, `anatogram_system()` — Milestones 9-11) into one data-shaping convenience, not a plotting function. Three mutually exclusive modes: no `organs`/`system` browses (tissue_id/tissue_name/system lookup table); `system` filters/facets by organ system (Skeletal, Digestive, etc., from the hand-curated `organ_systems` table, since nothing in the EBI source encodes organ systems); `organs` resolves organ names (fuzzy match) or literal `tissue_id`s, optionally attaching values, to a flat data frame ready for plain `geom_polygon()` — see `examples/anatogram_values_demo.R`, `examples/anatogram_system_demo.R`. None of this reopens Milestone 9's decision; it addresses organ-name/system lookup friction, not a plotting-flexibility gap.
- `hgMale`/`hgFemale` carry `id`/`group` columns and pre-flipped `y` specifically so they work as `geom_map()`'s `map` argument out of the box — see `R/data.R` for why each of those exists (both are load-bearing, not incidental: `group` prevents multi-blob organs from merging, and `y` must not be re-reversed with `scale_y_reverse()`, which breaks `geom_map()`).
- `hgMale`/`hgFemale`'s `outline_role` column (Milestone 11) splits `tissue_id == "outline"` into `"silhouette"` (plain outer body shape), `"contour_detail"` (same shape with interior joint/finger/toe lines), and `"feature"` (small facial marks) — computed from geometry at build time, not from any tag in the SVG source (there isn't one; the outline is a single compound path with no distinguishing per-subpath metadata).
- Human only (male + female) — no mouse/other-organism data, per explicit scope call.

## Attribution

The parser and data are built directly from the EBI Expression Atlas anatomogram source (Apache-2.0 code / CC-BY-4.0 images) — not a fork of `gganatogram`'s code or bundled data, so its GPL-2 license doesn't apply here. Still structurally indebted to `gganatogram` (Jesper Grud Skat Madsen / jespermaag) as prior art. See `NOTES.md` for full attribution/licensing history.

## Status tracking

Project status, priority, and scheduling live in `bob.md`, not here — see that file for current phase and effort budget. This file is for durable conventions only.
