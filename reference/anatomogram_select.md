# Browse, select, or filter anatomogram tissues – by organ, by organ system

A single entry point for the three things you'd otherwise need separate
functions for: browsing what tissues/systems exist, pulling one or more
whole organ systems, or selecting specific organs (optionally attaching
a value to each, e.g. for `fill`). Output is always shaped for
[`ggplot2::geom_polygon()`](https://ggplot2.tidyverse.org/reference/geom_polygon.html)
directly (see `examples/anatomogram_values_demo.R`,
`examples/anatomogram_system_demo.R`) – no
[`geom_map()`](https://ggplot2.tidyverse.org/reference/geom_map.html)
join needed.

## Usage

``` r
anatomogram_select(
  sex = c("male", "female"),
  organs = NULL,
  system = NULL,
  value_name = "value",
  outline = TRUE
)
```

## Arguments

- sex:

  `"male"` or `"female"`.

- organs:

  `NULL` (default), or a character vector selecting specific organs.
  Each element is either a literal `tissue_id` (e.g. `"UBERON_0000948"`)
  or matched fuzzily (case-insensitive, partial) against `tissue_name`.
  An element matching zero tissues emits a
  [`warning()`](https://rdrr.io/r/base/warning.html) and is dropped; one
  matching more than one distinct `tissue_id` (e.g. `"hippocampus"`,
  which has a left and a right entry under separate IDs) is an error
  listing the candidates – use a more specific term or the literal
  `tissue_id`. Naming an element (e.g. `c(kidney = "high")`) attaches
  that value under `value_name`; unnamed elements are pure selection.
  Mutually exclusive with `system`.

- system:

  `NULL` (default), or a character vector of one or more organ systems
  (see
  [organ_systems](https://petertanksley.github.io/anatomogramdata/reference/organ_systems.md)
  for the full list, or call `anatomogram_select(sex)` with
  `organs`/`system` both `NULL` to browse). Unknown names error listing
  the valid ones. Mutually exclusive with `organs`.

- value_name:

  Name of the column holding attached values in organ mode (default
  `"value"`). Ignored in browse/system mode.

- outline:

  If `TRUE` (default), include the body outline rows too (in system
  mode, once per requested system block), so the result can drive both
  an outline layer and a filled-organs layer.

## Value

If both `organs` and `system` are `NULL` (browse mode): a lookup data
frame of `tissue_id`, `tissue_name`, `system` (a tissue in more than one
system appears as more than one row). Otherwise: the usual
`hgMale`/`hgFemale` polygon columns filtered to the selection, plus a
`system` column (system mode) or a `value_name` column (organ mode).

## Examples

``` r
anatomogram_select("male")                              # browse
#>          tissue_id               tissue_name           system
#> 1       CL_0000084                      <NA> Lymphatic/Immune
#> 2       CL_0000233                      <NA>   Cardiovascular
#> 3       CL_0000236                      <NA> Lymphatic/Immune
#> 4       CL_0000576                      <NA> Lymphatic/Immune
#> 5       CL_0000623                      <NA> Lymphatic/Immune
#> 6       CL_0000738                 leukocyte Lymphatic/Immune
#> 7   UBERON_0000004                      nose      Respiratory
#> 8   UBERON_0000007           pituitary gland        Endocrine
#> 9   UBERON_0000014                      skin    Integumentary
#> 10  UBERON_0000029                lymph node Lymphatic/Immune
#> 11  UBERON_0000167               oral cavity        Digestive
#> 12  UBERON_0000178                      <NA>   Cardiovascular
#> 13  UBERON_0000310                    breast     Reproductive
#> 14  UBERON_0000341                    throat      Respiratory
#> 15  UBERON_0000341                    throat        Digestive
#> 16  UBERON_0000451         prefrontal cortex          Nervous
#> 17  UBERON_0000473                    testis     Reproductive
#> 18  UBERON_0000945                   stomach        Digestive
#> 19  UBERON_0000947                     aorta   Cardiovascular
#> 20  UBERON_0000948                     heart   Cardiovascular
#> 21  UBERON_0000955                     brain          Nervous
#> 22  UBERON_0000956           cerebral cortex          Nervous
#> 23  UBERON_0000966                      <NA>          Nervous
#> 24  UBERON_0000970                       eye          Nervous
#> 25  UBERON_0000977                    pleura      Respiratory
#> 26  UBERON_0000989                     penis     Reproductive
#> 27  UBERON_0000998           seminal vesicle     Reproductive
#> 28  UBERON_0001000              vas deferens     Reproductive
#> 29  UBERON_0001013            adipose tissue    Integumentary
#> 30  UBERON_0001021                     nerve          Nervous
#> 31  UBERON_0001043                 esophagus        Digestive
#> 32  UBERON_0001044            salivary gland        Digestive
#> 33  UBERON_0001052                    rectum        Digestive
#> 34  UBERON_0001103                 diaphragm      Respiratory
#> 35  UBERON_0001103                 diaphragm         Muscular
#> 36  UBERON_0001134           skeletal muscle         Muscular
#> 37  UBERON_0001135             smooth muscle         Muscular
#> 38  UBERON_0001153                    caecum        Digestive
#> 39  UBERON_0001154                  appendix        Digestive
#> 40  UBERON_0001154                  appendix Lymphatic/Immune
#> 41  UBERON_0001155                     colon        Digestive
#> 42  UBERON_0001225              renal cortex          Urinary
#> 43  UBERON_0001255           urinary bladder          Urinary
#> 44  UBERON_0001264                  pancreas        Digestive
#> 45  UBERON_0001264                  pancreas        Endocrine
#> 46  UBERON_0001301                epididymis     Reproductive
#> 47  UBERON_0001621           coronary artery   Cardiovascular
#> 48  UBERON_0001637                      <NA>   Cardiovascular
#> 49  UBERON_0001706              nasal septum      Respiratory
#> 50  UBERON_0001723                    tongue        Digestive
#> 51  UBERON_0001728             nasal pharynx      Respiratory
#> 52  UBERON_0001736       submandibular gland        Digestive
#> 53  UBERON_0001831             parotid gland        Digestive
#> 54  UBERON_0001870            frontal cortex          Nervous
#> 55  UBERON_0001871             temporal lobe          Nervous
#> 56  UBERON_0001876                  amygdala          Nervous
#> 57  UBERON_0001954               hippocampus          Nervous
#> 58  UBERON_0001981                      <NA>   Cardiovascular
#> 59  UBERON_0002037                cerebellum          Nervous
#> 60  UBERON_0002046             thyroid gland        Endocrine
#> 61  UBERON_0002048                      lung      Respiratory
#> 62  UBERON_0002079               left atrium   Cardiovascular
#> 63  UBERON_0002084            left ventricle   Cardiovascular
#> 64  UBERON_0002106                    spleen Lymphatic/Immune
#> 65  UBERON_0002107                     liver        Digestive
#> 66  UBERON_0002108           small intestine        Digestive
#> 67  UBERON_0002110              gall bladder        Digestive
#> 68  UBERON_0002113                    kidney          Urinary
#> 69  UBERON_0002114                  duodenum        Digestive
#> 70  UBERON_0002116                     ileum        Digestive
#> 71  UBERON_0002134           tricuspid valve   Cardiovascular
#> 72  UBERON_0002135              mitral valve   Cardiovascular
#> 73  UBERON_0002146           pulmonary valve   Cardiovascular
#> 74  UBERON_0002185                  bronchus      Respiratory
#> 75  UBERON_0002240               spinal cord          Nervous
#> 76  UBERON_0002245     cerebellar hemisphere          Nervous
#> 77  UBERON_0002367            prostate gland     Reproductive
#> 78  UBERON_0002369             adrenal gland        Endocrine
#> 79  UBERON_0002371               bone marrow Lymphatic/Immune
#> 80  UBERON_0002371               bone marrow         Skeletal
#> 81  UBERON_0002372                    tonsil Lymphatic/Immune
#> 82  UBERON_0002421               hippocampus          Nervous
#> 83 UBERON_00024818                      bone         Skeletal
#> 84  UBERON_0003126                   trachea      Respiratory
#> 85  UBERON_0006618          atrial appendage   Cardiovascular
#> 86  UBERON_0007650 gastroesophageal junction        Digestive
#> 87  UBERON_0007844                 cartilage         Skeletal
anatomogram_select("male", system = "Skeletal")          # all bones
#> # A tibble: 6,464 × 12
#>    tissue_id   tissue_name ontology element_index subpath polygon_id     x     y
#>    <chr>       <chr>       <chr>            <int>   <dbl> <chr>      <dbl> <dbl>
#>  1 UBERON_000… bone marrow UBERON               9       1 UBERON_00…  59.6 -141.
#>  2 UBERON_000… bone marrow UBERON               9       1 UBERON_00…  59.5 -141.
#>  3 UBERON_000… bone marrow UBERON               9       1 UBERON_00…  59.5 -141.
#>  4 UBERON_000… bone marrow UBERON               9       1 UBERON_00…  59.5 -141.
#>  5 UBERON_000… bone marrow UBERON               9       1 UBERON_00…  59.4 -141.
#>  6 UBERON_000… bone marrow UBERON               9       1 UBERON_00…  59.4 -141.
#>  7 UBERON_000… bone marrow UBERON               9       1 UBERON_00…  59.4 -141.
#>  8 UBERON_000… bone marrow UBERON               9       1 UBERON_00…  59.3 -141.
#>  9 UBERON_000… bone marrow UBERON               9       1 UBERON_00…  59.3 -141.
#> 10 UBERON_000… bone marrow UBERON               9       1 UBERON_00…  59.3 -141.
#> # ℹ 6,454 more rows
#> # ℹ 4 more variables: id <chr>, group <chr>, outline_role <chr>, system <chr>
anatomogram_select("male", organs = c(kidney = "high"))  # one organ, valued
#> # A tibble: 5,722 × 12
#>    tissue_id   tissue_name ontology element_index subpath polygon_id     x     y
#>    <chr>       <chr>       <chr>            <int>   <dbl> <chr>      <dbl> <dbl>
#>  1 UBERON_000… kidney      UBERON              74       1 UBERON_00…  60.2 -54.6
#>  2 UBERON_000… kidney      UBERON              74       1 UBERON_00…  59.9 -54.7
#>  3 UBERON_000… kidney      UBERON              74       1 UBERON_00…  59.6 -54.9
#>  4 UBERON_000… kidney      UBERON              74       1 UBERON_00…  59.4 -55.0
#>  5 UBERON_000… kidney      UBERON              74       1 UBERON_00…  59.1 -55.1
#>  6 UBERON_000… kidney      UBERON              74       1 UBERON_00…  58.9 -55.3
#>  7 UBERON_000… kidney      UBERON              74       1 UBERON_00…  58.7 -55.4
#>  8 UBERON_000… kidney      UBERON              74       1 UBERON_00…  58.6 -55.6
#>  9 UBERON_000… kidney      UBERON              74       1 UBERON_00…  58.4 -55.8
#> 10 UBERON_000… kidney      UBERON              74       1 UBERON_00…  58.3 -56.1
#> # ℹ 5,712 more rows
#> # ℹ 4 more variables: id <chr>, group <chr>, outline_role <chr>, value <chr>
```
