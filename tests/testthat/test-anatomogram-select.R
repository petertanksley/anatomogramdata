test_that("browse mode returns a tissue/system lookup covering all systems", {
  browse <- anatomogram_select("male")

  expect_setequal(names(browse), c("tissue_id", "tissue_name", "system"))
  expect_true(!"outline" %in% browse$tissue_id)
  expect_setequal(
    unique(browse$system),
    c("Cardiovascular", "Digestive", "Endocrine", "Integumentary",
      "Lymphatic/Immune", "Muscular", "Nervous", "Reproductive",
      "Respiratory", "Skeletal", "Urinary")
  )
})

test_that("system mode selects a single system and includes the outline", {
  bones <- anatomogram_select("male", system = "Skeletal")

  expect_true(all(bones$system == "Skeletal"))
  expect_true("outline" %in% bones$tissue_id)
  expect_true(all(bones$tissue_id[bones$tissue_id != "outline"] %in%
    organ_systems$tissue_id[organ_systems$system == "Skeletal"]))
})

test_that("system mode with outline = FALSE omits the outline", {
  bones <- anatomogram_select("male", system = "Skeletal", outline = FALSE)
  expect_false("outline" %in% bones$tissue_id)
})

test_that("system mode tags a multi-system organ once per requested system", {
  both <- anatomogram_select("male", system = c("Digestive", "Endocrine"))
  pancreas_systems <- both$system[both$tissue_id == "UBERON_0001264"]

  expect_setequal(unique(pancreas_systems), c("Digestive", "Endocrine"))
  expect_true(all(table(pancreas_systems) > 0))
})

test_that("unknown system name errors and lists valid names", {
  expect_error(
    anatomogram_select("male", system = "Nonexistent"),
    "Unknown system"
  )
})

test_that("organ mode resolves a literal tissue_id", {
  d <- anatomogram_select("male", organs = "UBERON_0000948", outline = FALSE)
  expect_setequal(unique(d$tissue_id), "UBERON_0000948")
})

test_that("organ mode resolves a fuzzy, case-insensitive name match", {
  d <- anatomogram_select("male", organs = "KIDNEY", outline = FALSE)
  expect_setequal(unique(d$tissue_id), "UBERON_0002113")
})

test_that("organ mode: unnamed elements are pure selection, named attach a value", {
  d <- anatomogram_select("male", organs = c("kidney", heart = "High"), outline = FALSE)

  kidney_val <- unique(d$value[d$tissue_name == "kidney"])
  heart_val <- unique(d$value[d$tissue_name == "heart"])

  expect_true(is.na(kidney_val))
  expect_identical(heart_val, "High")
})

test_that("organ mode: unmatched organ name warns and is dropped, not fatal", {
  expect_warning(
    result <- anatomogram_select("male", organs = c(kidney = "x", nonexistent_organ_xyz = "y"),
                                  outline = FALSE),
    "No tissue matched"
  )
  expect_true(all(result$tissue_id == "UBERON_0002113"))
})

test_that("organ mode: ambiguous fuzzy match errors listing candidates", {
  expect_error(
    anatomogram_select("male", organs = "hippocampus"),
    "matches more than one tissue"
  )
})

test_that("organ mode join preserves vertex order for multi-blob organs (match, not merge)", {
  lung <- anatomogram_select("male", organs = "lung", outline = FALSE)
  raw <- hgMale[hgMale$tissue_id == "UBERON_0002048", ]

  expect_identical(lung$x, raw$x)
  expect_identical(lung$y, raw$y)
  expect_identical(lung$group, raw$group)
  expect_true(length(unique(lung$group)) >= 2) # both lungs present as separate blobs
})

test_that("specifying both organs and system errors", {
  expect_error(
    anatomogram_select("male", organs = "kidney", system = "Skeletal"),
    "not both"
  )
})
