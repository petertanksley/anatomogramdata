# Source Assessment — Milestone 1 (2026-07-20)

Findings from forking `gganatogram` locally and inspecting the actual EBI
anatomogram source it derives from. Everything below is *candidate scope* —
none of it is committed work. See `bob.md` for what's actually active.

## What's in this directory

- `upstream/gganatogram/` — local clone of
  [jespermaag/gganatogram](https://github.com/jespermaag/gganatogram)
  (HEAD as of 2026-07-20: `eac6df5`, Aug 2025). Reference only — not our
  package source, not pushed anywhere.
- `data-raw/ebi-source/` — a small sample pulled directly from
  [ebi-gene-expression-group/anatomogram](https://github.com/ebi-gene-expression-group/anatomogram)
  (`homo_sapiens.male.svg`, `homo_sapiens.female.svg`, `svgsMetadata.json`),
  used to confirm the source format below. Not a full data pull.

## License (corrected 2026-07-20)

`gganatogram`'s `DESCRIPTION` file declares **`License: GPL-2`**. GitHub's
API reported `license: null` only because there's no standalone `LICENSE`
file at the repo root — that check doesn't read `DESCRIPTION`. This is a
real, valid license, not an absence of one. Practical implication: any
derivative work built from `gganatogram`'s own code/data must itself be
GPL-2-compatible if published. Not a blocker to working locally; a
constraint to keep in mind before any public release.

The EBI anatomogram source is separately licensed and unambiguous: **code
Apache 2.0, SVG images CC-BY 4.0**. Since Milestone 2's parser works
directly from the EBI SVGs (not from gganatogram's bundled data), the
parser itself sits under the cleaner Apache/CC-BY terms — the GPL-2
constraint only bites if we reuse gganatogram's own code or hardcoded data
directly.

## gganatogram's current approach

- Tissue outlines are **hardcoded R data frames** — a one-time snapshot of
  the EBI SVGs, with plain-text tissue name strings (no ontology IDs).
- Rendering uses `geom_polygon()` + the `ggpolypath` package as a
  workaround for shapes with holes — `ggpolypath` exists specifically
  because base `geom_polygon` mishandles self-intersecting/hole paths. Not
  a purpose-built ggplot2 geom.
- Coverage: human (male 68 tissues / female 70), mouse (45, + a 12-region
  brain variant), 24 other organisms.

## What the actual EBI source looks like

Pulled `homo_sapiens.male.svg` (952 KB) and `svgsMetadata.json` (14.9 KB)
directly to check feasibility:

- **82 tissue IDs** listed in `svgsMetadata.json` for `homo_sapiens.male.svg`,
  tagged against real ontologies — mostly **UBERON** (anatomical entity),
  with some **CL** (Cell Ontology) IDs mixed in (e.g. `CL_0000738`).
  gganatogram's hardcoded frames don't carry any of this — just tissue
  name strings.
- SVG structure is genuinely layered: elements are grouped under
  `id="LAYER_OUTLINE"` (the body outline) and `id="LAYER_EFO"` (the
  EFO/UBERON-tagged tissue shapes), with individual tissue groups/paths
  keyed by their ontology ID (`id="UBERON_0000956"`, etc.) — 76+ distinct
  UBERON-tagged top-level ids found directly in the male SVG.
- **Important technical detail:** these are real SVG `<path>` elements
  (343 of them in the male SVG) using bezier-curve `d` attributes — **not**
  `<polygon>` point lists (0 found). Any pipeline that regenerates polygon
  data from these SVGs needs to flatten curves into vertices (e.g. via
  `grImport2`/`rsvg` in R, or `svgpathtools` in Python at prep time), not
  just parse point coordinates directly. This likely explains why
  gganatogram baked in static coordinates originally — flattening was a
  one-time cost — but it means our data is now permanently decoupled from
  upstream SVG updates and carries no ontology metadata.

## Candidate roadmap (not committed — revisit as time allows)

1. **Parsing pipeline**: `data-raw/` script that downloads the EBI SVGs +
   `svgsMetadata.json`, flattens `<path>` curves to polygon vertices, and
   emits tidy tibbles tagged with UBERON/CL/EFO IDs (regenerable whenever
   EBI updates their SVGs, unlike gganatogram's frozen snapshot).
2. **Proper geom**: a dedicated `GeomAnatogram` ggproto (built on `sf`
   polygons, which handle holes correctly via winding rules) instead of
   the `ggpolypath` workaround.
3. Everything past that (additional species, palettes, Shiny/interactive,
   facet support) — undecided, per `bob.md`.

Given the 0.5h/week budget on this project, step 1 (the parsing pipeline)
is the next real milestone whenever picked back up — it's the piece that
unlocks everything else, and gganatogram's own repo history suggests no
one has done it since the original 2018 snapshot.

## Milestone 2 (2026-07-20) — parsing pipeline built and validated

`data-raw/parse_svg.R` parses `homo_sapiens.male.svg` directly into a tidy
tibble (`tissue_id`, `tissue_name`, `ontology`, `polygon_id`, `x`, `y`) and
was validated against gganatogram's own bundled rendering of the same
tissues — see `data-raw/validation_new_parser.png` vs
`data-raw/validation_old_gganatogram.png`. Shapes are recognizable, correctly
proportioned, and the paired-lung/single-heart grouping renders correctly,
confirming the multi-blob (`subpath`/`polygon_id`) logic works.

**What it does, beyond gganatogram's original approach:**
- Actually flattens `C` (cubic Bezier) and `A` (elliptical arc) commands
  into vertices via parametric sampling, rather than treating Bezier
  control points as if they were polygon vertices (what the original
  `createAnatograms.R`/`getCoord.py` do — see the "gganatogram's current
  approach" section above).
- Handles `<ellipse>`, `<circle>`, and `<rect>` shape elements alongside
  `<path>`, and resolves `<use>` references — none of which the original
  extraction script supported (it only handled `<path>`, and needed manual
  `DrawEllipse()` hacks bolted on afterward for the shapes it couldn't
  parse).
- Recurses genuinely through arbitrary `<g>` nesting, composing
  `matrix()`/`translate()`/`scale()` transforms correctly at each level,
  rather than the original's several overlapping special-case loops for
  different observed nesting patterns.
- Tags every tissue with its real ontology ID and prefix (UBERON/CL), not
  just a name string.

**Two structural findings worth remembering:**
- 10 of the 82 `homo_sapiens.male.svg` tissue entries are `<use>` elements
  that stamp a shared "leukocyte" icon (`id="CL_0000738"`) onto
  blood-related tissues, rather than drawing a real anatomical outline.
  These are cell-type markers, not tissue polygons — worth treating as a
  separate data layer if/when the geom rework happens, not folded into
  the same polygon set as organ shapes.
- The source SVG embeds the CC-license badge itself as an `<a
  href="https://www.ebi.ac.uk/gxa/licence.html">`-wrapped icon nested
  inside `LAYER_OUTLINE`. The parser now explicitly excludes `<a>`
  elements as decorative (confirmed by inspection, not guessed) — if this
  pattern repeats in other species' SVGs, the same exclusion should hold.
- Also notable: the live SVG already has a real elliptical `<ellipse>` for
  at least one structure (breast) that gganatogram's 2018 snapshot had to
  hand-add via `DescTools::DrawEllipse()` with eyeballed coordinates —
  concrete confirmation the live source has improved since the snapshot
  was taken, not just theoretically.

## Milestone 3 (2026-07-20) — female SVG run, two real parser bugs found and fixed

Extended `parse_svg.R` to also run `homo_sapiens.female.svg`. This
surfaced two genuine bugs the male-only run hadn't exercised — both fixed,
both worth remembering since they're about the general parser, not
female-specific:

1. **Exponent notation broke the "unsupported command" check.** The check
   originally flagged any stray letter left in a path's `d` string after
   removing the command letter — but scientific notation (`1.4e-6`, which
   female's SVG uses and male's happens not to) legitimately contains a
   letter. Fixed by removing all matched numbers first and checking what's
   left over, instead of flagging any bare letter.
2. **A lookahead-based tokenizer (`str_split(d, "(?=[MLCAZ])")`) hit a PCRE
   "node stack overflow"** on female's longer path strings. Replaced with a
   direct `str_extract_all(d, "[MLCAZ][^MLCAZ]*")` — no lookahead, and
   faster besides.
3. **A genuine self-referential `<use>` cycle in the source data:**
   `homo_sapiens.female.svg` has `<use id="UBERON_0001954"
   href="#UBERON_0002421">` nested *inside* `<g id="UBERON_0002421">` —
   the hippocampus group references itself. The recursive resolver now
   tracks a stack of in-progress `<use>` targets and skips (with a
   warning) instead of recursing forever. Only one such cycle found in
   this file; worth checking for when other species/sex files are run.

**A concrete data-quality point in gganatogram's own bundled data**, found
while building the validation comparison plot: `hgFemale_list[["outline"]]`
is correctly named at the list level, but its internal `id` column value
is `"path3584"`, not `"outline"` — a mislabeling left over from their
extraction script. The list also carries 19 duplicate entries all
literally named `"path3584"` (plus one `"path9"`) — stray per-path
fragments that never got folded into the main `"outline"` entry, sitting
alongside it as list-name duplicates (R's `[[` silently returns only the
first match, so most of them are unreachable by name at all). This isn't
a new-parser bug — it's a bug/inconsistency in gganatogram's *existing*
package data — but it's a good concrete example of exactly the kind of
mess a real recursive walker (which merges everything under a tissue
group by structure, regardless of internal path-id naming) avoids by
construction. `parse_svg.R`'s output has no such duplication: `tissue_id`
is set once, deliberately, to `"outline"` for the whole layer.

Both male and female now parse cleanly and validate visually against
gganatogram's own renderings (`data-raw/validation_new_parser_<sex>.png`
vs `data-raw/validation_old_gganatogram_<sex>.png`).

**Not yet done:** only human male + female have been run through the
pipeline. Other species files, and the `GeomAnatogram` ggproto that will
consume this tibble, are future milestones.

## Milestone 4 (2026-07-20) — formalized as a loadable package + plotting function

Now usable for real plots, not just prototyping. Per your call: humans only
(no mouse/other-organism data), a real minimal R package (not a
`source()`-a-script workflow), and a thin `geom_polygon()` wrapper rather
than the originally-floated custom `GeomAnatogram` ggproto (revisit only if
real rendering problems show up — none have yet).

**Package structure added:**
- `DESCRIPTION` / `LICENSE(.md)` — `License: MIT + file LICENSE` for the
  package *code*. This is deliberately different from gganatogram's own
  GPL-2: our parser and data build directly from the EBI source (which is
  Apache-2.0 code / CC-BY-4.0 images — see Milestone 1), not from
  gganatogram's code or bundled data, so we aren't bound by its GPL-2.
  The CC-BY-4.0 attribution requirement for the bundled `hgMale`/`hgFemale`
  data itself is noted in `LICENSE.md` and in each dataset's roxygen
  `@source`.
- `data-raw/parse_svg.R` split into `data-raw/svg_parser.R` (pure function
  definitions, no side effects — reusable from multiple entry points) and
  `data-raw/validate_parser.R` (the existing validation script). New
  `data-raw/build_data.R` generates `data/hgMale.rda` and
  `data/hgFemale.rda` via `usethis::use_data()`.
- `R/data.R` — roxygen documentation for `hgMale`/`hgFemale`.
- `R/gganatogram2.R` — the `gganatogram2()` plotting function.
- `.Rbuildignore` — excludes `upstream/`, raw SVGs, and the project's own
  admin files (`bob.md`, `CLAUDE.md`, etc.) from any future build/check.

**`gganatogram2(data, sex, fill)`:** draws the body outline (fixed fill,
for context) plus an **inner join** of the organ tissues against `data` by
`tissue_id` — deliberately inner, not left. `hgMale`/`hgFemale` carry all
82 profiled tissues; drawing all of them regardless of whether the user
supplied a value produces a cluttered muscle/vessel-map effect (every
unmapped organ still gets a visible black border with `NA` fill — looks
like an anatomy textbook, not a highlight plot). Only tissues the caller
actually passes in `data` get drawn on top of the outline. Confirmed by
building `examples/cause_of_death_demo.R`: an illustrative (not real
mortality data — see the script's own header) mapping of CDC-style
leading-cause-of-death category names onto organs, rendered on `hgMale`.
First render (before the inner-join fix) showed exactly the muscle-map
clutter described above; after the fix, output is a clean silhouette with
only the mapped organs highlighted — see
`examples/cause_of_death_demo.png`.

**Usable now via:**
```r
devtools::load_all(".")   # or install and library(gganatogram2) later
my_data <- data.frame(tissue_name = c("heart", "lung"), value = c(...))
gganatogram2(my_data, sex = "male", fill = "value")
```
`tissue_id` values are the UBERON/CL ontology IDs in `hgMale`/`hgFemale`; but
nobody should have to memorize those to make a plot, so `gganatogram2()`
also accepts a `tissue_name` column instead (matched case-insensitively;
`tissue_id` wins if both are present, since `tissue_name` has a couple of
harmless duplicates -- two distinct hippocampus polygons are both just
named `"hippocampus"`). Use `anatogram_tissues("male")`/`anatogram_tissues("female")`
to browse or search (`grepl(..., ignore.case = TRUE)`) what plain-English
names are available -- 73 of 83 tissues have one; the 10 without are
`<use>`-referenced cell-type markers (see the leukocyte-icon finding
above), not real organs.

## Milestone 6 (2026-07-20) — per-tissue and outline alpha

`gganatogram2()` gained an `alpha` argument mirroring `fill`: pass a single
number (e.g. `alpha = 0.6`) for uniform organ transparency, or the name of
a column in `data` (e.g. `alpha = "severity"`) to give different tissues
different transparency, mapped the same way `fill` is. `outline_alpha`
does the same for the fixed body-silhouette layer (a single number only --
the outline is one layer, not per-tissue). Both tested and confirmed
working (uniform fade, and a `severity` column producing visibly different
opacity per organ plus its own auto-generated ggplot legend).

## Milestone 7 (2026-07-20) — tested (and ruled out) curve resolution as the "boxy" cause

Peter described the plots as "a bit boxy" and asked how much of a lift a
custom `GeomAnatogram` ggproto would be. Before touching the geom
architecture, tested the cheap hypothesis first: bumped
`flatten_cubic_bezier`/`flatten_arc`'s segment count from 12 to 30 and
added `linejoin = "round"` to `gganatogram2()`'s polygon layers.

**Result: the segment count was not the cause.** A zoomed side-by-side
render of the kidney (a good curved test case) at n=12 vs n=30 was
visually identical — 12 segments per Bezier/arc was already smooth enough
at any reasonable zoom. Reverted the segment count back to 12 (n=30 had
roughly doubled `hgMale`/`hgFemale`'s row count -- 521,776 vs 212,212 rows
-- for zero visible benefit, not worth the bloat). Kept `linejoin =
"round"` in `gganatogram2()` since it's a free, harmless change to the
polygon layers' joint style.

**Still open:** what "boxy" actually refers to is unconfirmed -- candidates
include the legend's rectangular color swatches, the uniform black
outlines between adjacent organs, or the inherent style of the source SVG
illustration itself (which we don't control). Needs Peter's input before
guessing further / before deciding whether a custom geom is actually the
right lift.

## Milestone 8 (2026-07-20) — real ggplot2 geom flexibility, no custom Geom needed

Peter clarified "boxy": not visual smoothness, but that `gganatogram2()`
only exposes `fill`/`alpha` as bespoke named parameters, unlike a real
ggplot2 geom which inherits the full aesthetic system (colour, linewidth,
linetype, ...) for free. Asked how much of a lift a custom `GeomAnatogram`
ggproto would be.

**Finding: no custom ggproto needed.** `ggplot2::geom_map()` — the geom
behind choropleth maps — already extends `GeomPolygon` and does an
id-based join exactly like a bespoke `geom_anatogram()` would, inheriting
every `GeomPolygon` aesthetic (fill, alpha, colour, linewidth, linetype)
automatically. Tested directly against ggplot2's own source
(`ggplot2:::GeomMap$draw_panel`) rather than assuming:

- A `map` data frame just needs `x`, `y`, `id` columns (per `geom_map()`'s
  own validation) — but **also needs an explicit `group` column**, which
  is not documented as required but is: without it, `geom_map()` defaults
  `group <- id`, and multi-blob organs (confirmed with the two lungs) merge
  into one broken connect-the-dots shape instead of staying separate.
  Confirmed the fix (`group = polygon_id`) renders both lung lobes
  correctly.
- **Found and fixed a real bug:** `scale_y_reverse()` breaks `geom_map()`.
  `geom_map()`'s polygon coordinates never pass through ggplot2's normal
  scale-training pipeline (confirmed via `ggplot_build()` — the built
  layer data has exactly 1 row per `map_id`, not one per vertex, since the
  real coordinates live only inside the `map` argument, invisible to
  automatic scale training). Adding `scale_y_reverse()` on top of that
  means the y-scale trains on no real data and collapses to a tiny
  degenerate range — the plot renders as a small cropped sliver (just the
  top of the head) instead of the full figure. **Fix:** don't reverse the
  scale at plot time at all — flip `y` once when the package data is
  built, so it ships already right-side-up.
- Confirmed a full outline + organs plot with a **per-tissue `linewidth`
  mapped from real data** (`aes(fill = cause, linewidth = confidence)`)
  renders correctly with two independent, automatically-generated legends
  — see `examples/geom_map_demo.R`/`.png`. This is something
  `gganatogram2()` cannot do without adding another bespoke parameter for
  every new aesthetic; `geom_map()` gets it for free.

**What changed:**
- `data-raw/build_data.R`: `hgMale`/`hgFemale` now carry pre-flipped `y`
  (Cartesian-oriented, not SVG y-down) plus `id` (= `tissue_id`) and
  `group` (= `polygon_id`) columns, so they're immediately usable as
  `geom_map()`'s `map` argument. See `R/data.R` for the documented
  rationale on each column.
- `R/gganatogram2.R`: dropped `scale_y_reverse()` (redundant now, and
  actively wrong to re-add per the bug above). Confirmed the demo plot
  renders identically to before the refactor — purely internal change, no
  interface change.
- `examples/geom_map_demo.R`: the power-user pattern, using
  `ggplot2::geom_map()` directly instead of `gganatogram2()`.

**Division of labor going forward:** `gganatogram2()` stays the
convenience path (fuzzy `tissue_name` matching, automatic outline layer,
one function call) for quick plots. `ggplot2::geom_map()` directly against
`hgMale`/`hgFemale` is the power-user path when full aesthetic control,
faceting, or anything beyond `fill`/`alpha` is needed — no package code
required for that flexibility, it already exists in ggplot2.

## Milestone 9 (2026-07-20) — renamed to `anatomogramdata`; dropped `gganatogram2()`

Peter's read on the project, prompted by Milestone 8's finding: "is this
basically just a data compilation/processing package now?" Yes — the real
engineering was always the SVG parser and the resulting clean, tidy,
ontology-tagged data; the plotting layer turned out to be a thin,
increasingly redundant convenience on top of stock `ggplot2::geom_map()`.

**Renamed** `gganatogram2` → `anatomogramdata` (directory
`PROJ_gganatogram2` → `PROJ_anatomogramdata`, `gganatogram2.Rproj` →
`anatomogramdata.Rproj`, `bob.md`/registry-local.md updated) — invokes the
EBI source ("anatomogram") plus signals what the package actually is
("data"), rather than the `gg`-prefix convention that implies a ggplot2
geom extension.

**Dropped `gganatogram2()` entirely** (Peter's call, after questioning why
it was still needed): `R/gganatogram2.R` and `man/gganatogram2.Rd` removed.
It bought three things — an automatic outline layer, fuzzy
case-insensitive `tissue_name` matching, and a one-line call — all of which
`geom_map()` either already covers or barely costs to replicate manually
(exact-match `tissue_name` values, browseable via `anatogram_tissues()`,
aren't a real burden to type correctly). `examples/cause_of_death_demo.R`
rewritten to use `geom_map()` directly (re-pointing `hgMale`'s `id` column
at `tissue_name` for name-based keying); confirmed it renders the same
figure as before.

**`DESCRIPTION`'s `Imports` dropped to nothing** — with `gganatogram2()`
gone, `R/` is just data documentation (`data.R`) and `anatogram_tissues()`
(base R only, no dependencies). An honest reflection of what the package
now is.

Net effect: `anatomogramdata` ships two clean datasets
(`hgMale`/`hgFemale`) ready to hand straight to `ggplot2::geom_map()`, plus
one small lookup helper (`anatogram_tissues()`) — no bespoke plotting code
at all. `examples/geom_map_demo.R` and `examples/cause_of_death_demo.R` are
the two worked reference patterns for how to actually plot with it.

## Milestone 10 (2026-07-22) — added `anatogram_values()`, a data-prep helper

Peter's ask: make the common case ("I have a value per organ, plot it")
feel as close to ordinary `ggplot2` usage as possible, without reopening
Milestone 9's decision to not have a plotting wrapper. The distinction that
kept this in scope: Milestone 9 removed `gganatogram2()` because
`geom_map()` already covers plotting flexibility with no bespoke code
needed. The actual remaining friction was never about plotting flexibility
— it was translating plain-English organ names to ontology `tissue_id`s
and assembling a plottable frame. That's a data-shaping problem, so the
fix is a data-shaping function.

**Added** `R/anatogram_values.R`, exported as `anatogram_values(sex,
values, value_name = "value", outline = TRUE)`. `values` is a named vector
where each name is either a literal `tissue_id` or a fuzzy, case-insensitive
partial match against `tissue_name` (same matching style
`anatogram_tissues()`'s own example already demonstrated). Resolution
rules, decided with Peter before implementation:
- Name matches zero tissues → `warning()`, dropped, not fatal.
- Name matches exactly one distinct `tissue_id` → resolved normally
  (this includes multi-blob organs like kidney and lung, which share one
  `tissue_id` across blobs — confirmed by checking
  `anatogram_tissues("male")` directly rather than assuming).
- Name matches more than one distinct `tissue_id` → `stop()`, listing
  every candidate. The one real case of this in the male dataset:
  "hippocampus" resolves to two separate IDs (`UBERON_0002421`,
  `UBERON_0001954`) sharing the identical `tissue_name`.

**Correctness detail worth remembering:** the value-to-polygon join uses
`match()`, not `merge()`. `merge()` doesn't preserve row order, and
`geom_polygon()` (unlike `geom_map()`) connects vertices strictly in row
order within each `group` — a naive `merge()`-based join would silently
scramble multi-blob organs into self-crossing shapes. Verified directly:
`anatogram_values()`'s output for `"lung"` is `identical()` to the raw
`hgMale` subset's `x`/`y`/`group` columns, and the rendered demo shows both
lungs and both kidneys as intact, separate blobs, not connect-the-dots
messes.

**Added** `examples/anatogram_values_demo.R` as the new quick-start
reference pattern: `anatogram_values()` output straight into two
`geom_polygon()` layers (outline, then organs with `aes(fill = value)`) —
no `map_id`, no `aes(map_id = ...)`, no separate `map =` argument.
`examples/geom_map_demo.R` and `examples/cause_of_death_demo.R` remain the
documented path for anything needing more than one aesthetic mapped to
real data (e.g. `fill` + `linewidth` together), since `geom_map()` still
has no equivalent in the new helper.

## Milestone 11 (2026-07-22) — outline-role classification + organ systems + `anatogram_system()`

Two follow-up questions from using `anatogram_values()`: (1) the rendered
outline turned out to be more than one shape — could the outer silhouette
be separated from the interior contour lines? (2) does the data support
filtering/faceting by organ system ("all bones," "all digestive organs")?
Both required checking the actual source rather than assuming an answer.

**Outline.** `hgMale`'s `tissue_id == "outline"` is 15 subpaths, all from a
single compound `<path id="human_male_outline">` — confirmed by reading
the raw SVG XML (`LAYER_OUTLINE` has exactly one real child for male,
`<a>` aside, which is the CC-license badge already excluded by the
parser). Faceting the subpaths out: the two largest by bounding-box area
are both full-body shapes — one plain (1,608 points), one with the same
shape plus interior cut-lines for fingers/toes/ears/joints (2,860 points).
The other 13 are small facial marks (eyes, nostril, mouth, a
belly-button dot).

Checked female too, since a male-only finding wasn't safe to generalize:
female's `LAYER_OUTLINE` is a nested `<g>` of multiple `<path>`s, not one
compound path — the parser's subpath-index scheme comes out completely
different (`outline_1_1`/`outline_1_2` for male vs.
`outline_1_18001`/`outline_1_18002` for female), so a hardcoded
subpath-number rule would have silently classified the wrong shapes on
the female dataset. The **geometric pattern** holds for both sexes though:
top-2-by-bounding-box-area subpaths are always the full-body variants, and
between those two, more points = the contour/detail version. That's the
rule implemented in `data-raw/build_data.R`'s new `classify_outline_role()`,
producing the new `outline_role` column (`"silhouette"` /
`"contour_detail"` / `"feature"`, `NA` for non-outline rows) — verified
directly against both `hgMale` and `hgFemale` before shipping.

**Organ systems.** Nothing in the source encodes this.
`data-raw/ebi-source/svgsMetadata.json` — the only metadata file — maps
filename → species/view → a flat list of ontology IDs, no hierarchy.
UBERON does have a real is_a/part_of system hierarchy, but per Peter's
choice this became a hand-curated lookup table rather than a live query
against the ontology, to avoid an external dependency for a low-priority
side project.

Pulled the full distinct tissue list via `anatogram_tissues()` across
both sexes: **91 distinct `tissue_id`s** (organs plus `CL_`-prefixed cell
markers — B cell, T cell, monocyte, natural killer cell, leukocyte,
platelet). One of those, `UBERON_0001981`, has no `<title>` in either sex
— traced it in the raw SVG to a `<use href="#CL_0000738">` (the leukocyte
icon reused as a marker); it resolves to "blood vessel" and is classified
under Cardiovascular. Two source quirks worth remembering: "bone" appears
under two distinct tissue_ids (`UBERON_0002481` and an 8-digit
`UBERON_00024818`, both mapped to Skeletal), and "hippocampus" under two
distinct ids (`UBERON_0002421`, `UBERON_0001954`, both mapped to Nervous —
the same pair `anatogram_values()` already errors on for ambiguous
fuzzy-name matching, though irrelevant here since this table is keyed by
ID).

Curated into `data-raw/organ_systems.csv`: 96 rows (91 distinct tissues,
5 with genuine dual-system membership — pancreas in Digestive + Endocrine,
appendix in Digestive + Lymphatic/Immune, bone marrow in Skeletal +
Lymphatic/Immune, diaphragm in Muscular + Respiratory, throat in
Respiratory + Digestive) across 11 standard systems (Skeletal, Muscular,
Integumentary, Nervous, Endocrine, Cardiovascular, Lymphatic/Immune,
Respiratory, Digestive, Urinary, Reproductive). `data-raw/build_organ_systems.R`
validates full two-way coverage against `hgMale`/`hgFemale` at build time
(every tissue_id in the data must appear in the CSV and vice versa) —
confirmed this check actually fires by deliberately dropping a row and
re-running before shipping the real table. Produces `data/organ_systems.rda`.

**Added** `anatogram_system(sex, system = NULL)`: `system = NULL` browses
(returns the valid system names, same idea as `anatogram_tissues()`'s
unfiltered browse mode); one or more system names filters `hgMale`/`hgFemale`
to matching tissues, tagging each block with a `system` column so a
tissue in more than one requested system (e.g. pancreas under
`c("Digestive", "Endocrine")`) correctly appears once per system — exactly
what `facet_wrap(~system)` needs. Unknown system name errors with the
valid list, matching `anatogram_values()`'s error style.

**Added** `examples/anatogram_system_demo.R`: silhouette-vs-contour
styling, a single-system ("all bones") plot, and a faceted multi-system
plot confirming pancreas renders correctly in both its Digestive and
Endocrine panels.

## Milestone 12 (2026-07-22) — consolidated to one exported function, `anatogram_select()`

Peter's ask: ship fewer functions. The package had grown to three small
exported functions (`anatogram_tissues()`, `anatogram_values()`,
`anatogram_system()` — Milestones 9-11), each covering one kind of organ
selection/browsing. This was a pure consolidation of already-verified
logic into one function with three mutually exclusive modes, not new
resolution behavior:

- **Browse** (`organs = NULL`, `system = NULL`): returns a
  `tissue_id`/`tissue_name`/`system` lookup table — replaces both
  `anatogram_tissues()`'s and `anatogram_system(sex)`'s (no-arg) browse
  behavior in one call.
- **System** (`system` given): identical resolution to the old
  `anatogram_system()` — unknown names error listing valid ones, each
  requested system tagged and `rbind`'d so multi-system tissues (pancreas)
  appear once per system.
- **Organ** (`organs` given): identical resolution to the old
  `anatogram_values()` — exact `tissue_id` match first, then fuzzy
  case-insensitive partial match against `tissue_name`; zero matches warn
  and drop; ambiguous matches (hippocampus) error listing candidates.
  Unnamed elements are pure selection; named elements attach a value.
  Still joined via `match()`, never `merge()` (Milestone 10's
  vertex-order-corruption fix, unchanged).

Passing both `organs` and `system` errors rather than defining new
combined-selection semantics — keeps the mental model simple; call twice
and `rbind()` if both are genuinely needed.

**Real improvement, not just a rename:** `anatogram_system()` previously
had no `outline` handling at all — the outline had to be assembled by
hand in every system-mode demo. Unifying the two code paths means
`outline = TRUE` (the default) now applies to system mode too, appending
an outline copy to each requested system's block — removing exactly the
kind of manual-assembly friction this consolidation exists to fix.

**Bug caught during verification, not after shipping:** the initial
`organs` resolution logic mishandled a *mixed* named/unnamed vector (e.g.
`c("kidney", heart = "High")`) — for the unnamed `"kidney"` element,
`names()` returns `""` rather than `NA`, and the fix that falls back to
the element's own string as the search term also needs `vals[empty] <- NA`
explicitly, or the unnamed element's own name gets misread as its
attached value (`kidney`'s value came back as `"kidney"` instead of
`NA` on the first pass). Caught by testing exactly this mixed case before
calling it done, not assumed correct because the named-only and
unnamed-only cases both worked.

**Deleted** `R/anatogram_tissues.R`, `R/anatogram_values.R`,
`R/anatogram_system.R`; **added** `R/anatogram_select.R` (the exported
function plus a small non-exported `resolve_organs()` helper for the
organ-matching loop). `devtools::document()` cleaned up the three stale
`.Rd` files automatically on re-running after the source change — verified
rather than assumed, since NAMESPACE briefly warned about the
now-missing old exports until the second `document()` pass. `NAMESPACE`
now has exactly one `export()` line.

**Updated** `examples/anatogram_values_demo.R` and
`examples/anatogram_system_demo.R` to call `anatogram_select(organs = ...)`
/ `anatogram_select(system = ...)`; re-rendered both and confirmed the
output plots match Milestones 10/11 exactly (the bones/facets renders now
additionally show the full outline detail per panel for free, per the
improvement above). `examples/cause_of_death_demo.R`'s one comment
reference updated too.
