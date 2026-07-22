expected_cols <- c("tissue_id", "tissue_name", "ontology", "element_index",
                    "subpath", "polygon_id", "x", "y", "id", "group", "outline_role")

test_that("hgMale and hgFemale have the expected columns", {
  expect_setequal(names(hgMale), expected_cols)
  expect_setequal(names(hgFemale), expected_cols)
})

test_that("outline_role takes only the 3 expected values, NA elsewhere", {
  for (base in list(hgMale, hgFemale)) {
    outline_rows <- base[base$tissue_id == "outline", ]
    non_outline_rows <- base[base$tissue_id != "outline", ]

    expect_setequal(unique(outline_rows$outline_role),
                     c("silhouette", "contour_detail", "feature"))
    expect_true(all(is.na(non_outline_rows$outline_role)))
  }
})

test_that("organ_systems covers every non-outline tissue_id in hgMale/hgFemale, both ways", {
  data_ids <- unique(c(hgMale$tissue_id, hgFemale$tissue_id))
  data_ids <- setdiff(data_ids, "outline")

  expect_true(all(data_ids %in% organ_systems$tissue_id))
  expect_true(all(organ_systems$tissue_id %in% data_ids))
})

test_that("organ_systems has the 11 expected systems and long-format dual membership", {
  expect_setequal(
    unique(organ_systems$system),
    c("Cardiovascular", "Digestive", "Endocrine", "Integumentary",
      "Lymphatic/Immune", "Muscular", "Nervous", "Reproductive",
      "Respiratory", "Skeletal", "Urinary")
  )
  # pancreas is the known dual-membership case (Digestive + Endocrine)
  pancreas_systems <- organ_systems$system[organ_systems$tissue_id == "UBERON_0001264"]
  expect_setequal(pancreas_systems, c("Digestive", "Endocrine"))
})
