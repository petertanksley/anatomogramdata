# Organ system membership for anatomogram tissues

A hand-curated lookup table mapping each `tissue_id` in
[hgMale](https://petertanksley.github.io/anatomogramdata/reference/hgMale.md)/[hgFemale](https://petertanksley.github.io/anatomogramdata/reference/hgFemale.md)
to one or more organ systems (Skeletal, Muscular, Integumentary,
Nervous, Endocrine, Cardiovascular, Lymphatic/Immune, Respiratory,
Digestive, Urinary, Reproductive). Nothing in the EBI SVG source encodes
this – see `data-raw/organ_systems.csv` and `dev/NOTES.md`, Milestone
11, for the curation approach. Use
[`anatomogram_select()`](https://petertanksley.github.io/anatomogramdata/reference/anatomogram_select.md)
rather than joining against this table directly for the common case.

## Usage

``` r
organ_systems
```

## Format

A data frame, long format (one row per `tissue_id` x `system` pair – a
tissue belonging to more than one system, e.g. the pancreas in both
Digestive and Endocrine, has more than one row):

- tissue_id:

  Ontology ID, matches
  [hgMale](https://petertanksley.github.io/anatomogramdata/reference/hgMale.md)/[hgFemale](https://petertanksley.github.io/anatomogramdata/reference/hgFemale.md)'s
  `tissue_id`.

- tissue_name:

  Human-readable name, for readability only – not used for matching
  (tissue_name strings are inconsistent across sexes for the same
  tissue_id; join on tissue_id instead).

- system:

  One of the 11 systems listed above.
