# Resolves each element of `organs` to a tissue_id -- either a literal
# ontology ID or a fuzzy, case-insensitive partial match against
# tissue_name. Returns a data frame with tissue_id and value columns,
# already filtered down to the terms that resolved (unmatched terms warn
# and are dropped here). Not exported -- internal to anatogram_select()'s
# organ mode.
resolve_organs <- function(organs, lookup) {
  nm <- names(organs)
  if (is.null(nm)) {
    terms <- as.character(organs)
    vals <- rep(NA, length(organs))
  } else {
    terms <- nm
    empty <- terms == ""
    terms[empty] <- as.character(organs[empty])
    vals <- unname(organs)
    vals[empty] <- NA
  }

  resolved_id <- character(length(terms))
  keep <- logical(length(terms))

  for (i in seq_along(terms)) {
    term <- terms[i]

    if (term %in% lookup$tissue_id) {
      resolved_id[i] <- term
      keep[i] <- TRUE
      next
    }

    hits <- lookup[!is.na(lookup$tissue_name) &
                     grepl(term, lookup$tissue_name, ignore.case = TRUE), ]
    uniq_ids <- unique(hits$tissue_id)

    if (length(uniq_ids) == 0) {
      warning("No tissue matched '", term, "' -- dropped.", call. = FALSE)
      keep[i] <- FALSE
    } else if (length(uniq_ids) == 1) {
      resolved_id[i] <- uniq_ids
      keep[i] <- TRUE
    } else {
      candidates <- unique(hits[, c("tissue_id", "tissue_name")])
      candidate_str <- paste0(candidates$tissue_name, " (", candidates$tissue_id, ")",
                               collapse = ", ")
      stop("'", term, "' matches more than one tissue: ", candidate_str,
           ". Use a more specific term or pass the literal tissue_id.",
           call. = FALSE)
    }
  }

  data.frame(tissue_id = resolved_id[keep], value = vals[keep], stringsAsFactors = FALSE)
}

#' Browse, select, or filter anatogram tissues -- by organ, by organ system
#'
#' A single entry point for the three things you'd otherwise need separate
#' functions for: browsing what tissues/systems exist, pulling one or more
#' whole organ systems, or selecting specific organs (optionally attaching
#' a value to each, e.g. for `fill`). Output is always shaped for
#' `ggplot2::geom_polygon()` directly (see `examples/anatogram_values_demo.R`,
#' `examples/anatogram_system_demo.R`) -- no `geom_map()` join needed.
#'
#' @param sex `"male"` or `"female"`.
#' @param organs `NULL` (default), or a character vector selecting specific
#'   organs. Each element is either a literal `tissue_id` (e.g.
#'   `"UBERON_0000948"`) or matched fuzzily (case-insensitive, partial)
#'   against `tissue_name`. An element matching zero tissues emits a
#'   `warning()` and is dropped; one matching more than one distinct
#'   `tissue_id` (e.g. `"hippocampus"`, which has a left and a right entry
#'   under separate IDs) is an error listing the candidates -- use a more
#'   specific term or the literal `tissue_id`. Naming an element (e.g.
#'   `c(kidney = "high")`) attaches that value under `value_name`; unnamed
#'   elements are pure selection. Mutually exclusive with `system`.
#' @param system `NULL` (default), or a character vector of one or more
#'   organ systems (see [organ_systems] for the full list, or call
#'   `anatogram_select(sex)` with `organs`/`system` both `NULL` to browse).
#'   Unknown names error listing the valid ones. Mutually exclusive with
#'   `organs`.
#' @param value_name Name of the column holding attached values in organ
#'   mode (default `"value"`). Ignored in browse/system mode.
#' @param outline If `TRUE` (default), include the body outline rows too
#'   (in system mode, once per requested system block), so the result can
#'   drive both an outline layer and a filled-organs layer.
#' @return If both `organs` and `system` are `NULL` (browse mode): a
#'   lookup data frame of `tissue_id`, `tissue_name`, `system` (a tissue in
#'   more than one system appears as more than one row). Otherwise: the
#'   usual `hgMale`/`hgFemale` polygon columns filtered to the selection,
#'   plus a `system` column (system mode) or a `value_name` column (organ
#'   mode).
#'
#' @examples
#' anatogram_select("male")                              # browse
#' anatogram_select("male", system = "Skeletal")          # all bones
#' anatogram_select("male", organs = c(kidney = "high"))  # one organ, valued
#'
#' @export
anatogram_select <- function(sex = c("male", "female"), organs = NULL, system = NULL,
                              value_name = "value", outline = TRUE) {
  sex <- match.arg(sex)
  base <- switch(sex, male = hgMale, female = hgFemale)

  if (!is.null(organs) && !is.null(system)) {
    stop("Specify `organs` or `system`, not both -- call anatogram_select() ",
         "twice and rbind() the results if you need both.", call. = FALSE)
  }

  if (is.null(organs) && is.null(system)) {
    lookup <- unique(base[base$tissue_id != "outline", c("tissue_id", "tissue_name")])
    return(merge(lookup, organ_systems[, c("tissue_id", "system")], by = "tissue_id"))
  }

  if (!is.null(system)) {
    valid_systems <- sort(unique(organ_systems$system))
    unknown <- setdiff(system, valid_systems)
    if (length(unknown) > 0) {
      stop("Unknown system(s): ", paste(unknown, collapse = ", "),
           ". Call anatogram_select(sex) with `organs`/`system` both NULL to list valid names.",
           call. = FALSE)
    }

    outline_rows <- base[base$tissue_id == "outline", ]

    blocks <- lapply(system, function(s) {
      ids <- organ_systems$tissue_id[organ_systems$system == s]
      rows <- base[base$tissue_id %in% ids, ]
      rows$system <- s
      if (outline) {
        block_outline <- outline_rows
        block_outline$system <- s
        rows <- rbind(rows, block_outline[, names(rows)])
      }
      rows
    })
    return(do.call(rbind, blocks))
  }

  # organ mode
  lookup <- unique(base[base$tissue_id != "outline", c("tissue_id", "tissue_name")])
  resolved <- resolve_organs(organs, lookup)

  matched <- base[base$tissue_id %in% resolved$tissue_id, ]
  matched[[value_name]] <- resolved$value[match(matched$tissue_id, resolved$tissue_id)]

  if (!outline) {
    return(matched)
  }

  outline_rows <- base[base$tissue_id == "outline", ]
  outline_rows[[value_name]] <- NA

  rbind(matched, outline_rows[, names(matched)])
}
