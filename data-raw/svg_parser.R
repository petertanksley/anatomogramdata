# Milestone 2/3: parses the EBI Expression Atlas anatomogram SVG source
# directly into a tidy polygon tibble, replacing gganatogram's frozen
# 2018 hardcoded-coordinate snapshot. See dev/NOTES.md for background.
#
# Pure function definitions only -- no top-level side effects, so this can
# be sourced from multiple entry points (data-raw/validate_parser.R,
# data-raw/build_data.R) without re-running anything.
#
# Scope (confirmed by inspecting the male + female sources directly -- see
# dev/NOTES.md for how):
#   - Path commands: M, L, C, A, Z, all ABSOLUTE. No relative commands and
#     no S/Q/T shorthand curves appear anywhere in this source, so they are
#     not supported -- an unrecognized command is a hard error, not a
#     silent misparse.
#   - Shape elements actually used inside tissue groups: <path>, <ellipse>,
#     <circle>, <rect>, and <use> (stamps a shared "leukocyte" icon, id
#     CL_0000738, onto blood-bearing tissues; these are cell-type markers,
#     not anatomical outlines -- worth treating as a separate concern
#     later, see dev/NOTES.md).
#   - Transforms: matrix(), translate(), scale(), possibly chained within
#     one transform= string, and nested through <g>/<a> ancestors.
#   - Numbers may use scientific notation (e.g. "1.4e-6").
#   - <use> can be self-referential (a real cycle found in the female
#     source) -- guarded against, see resolve_element().

library(xml2)
library(dplyr)
library(tibble)
library(stringr)

# ---- number / path tokenizing ------------------------------------------------

svg_number_regex <- "[-+]?(?:[0-9]+\\.[0-9]+|\\.[0-9]+|[0-9]+)(?:[eE][-+]?[0-9]+)?"

tokenize_path <- function(d) {
  d <- str_squish(d)
  # A lookahead-based str_split(d, "(?=[MLCAZ])") stack-overflows PCRE on the
  # very long `d` strings some tissues have (seen on the female source) --
  # match each command-plus-its-arguments directly instead.
  parts <- str_extract_all(d, "[MLCAZ][^MLCAZ]*")[[1]]
  parts <- parts[nzchar(parts)]
  lapply(parts, function(p) {
    cmd <- substr(p, 1, 1)
    rest <- substr(p, 2, nchar(p))
    # Letters can legitimately appear inside numbers (scientific notation,
    # e.g. "1.4e-6"), so check for stray commands by removing every matched
    # number first, rather than flagging any bare letter in `rest`.
    residue <- str_remove_all(rest, svg_number_regex)
    residue <- str_remove_all(residue, "[\\s,]")
    if (nzchar(residue)) {
      stop("Unsupported path command residue '", residue,
           "' -- only absolute M/L/C/A/Z are supported. d=", d)
    }
    nums <- as.numeric(str_extract_all(rest, svg_number_regex)[[1]])
    list(cmd = cmd, args = nums)
  })
}

# ---- curve / arc flattening --------------------------------------------------

flatten_cubic_bezier <- function(p0, p1, p2, p3, n = 12) {
  t <- seq(0, 1, length.out = n + 1)[-1]
  mt <- 1 - t
  x <- mt^3 * p0[1] + 3 * mt^2 * t * p1[1] + 3 * mt * t^2 * p2[1] + t^3 * p3[1]
  y <- mt^3 * p0[2] + 3 * mt^2 * t * p1[2] + 3 * mt * t^2 * p2[2] + t^3 * p3[2]
  cbind(x, y)
}

# Endpoint-to-center parameterization, SVG spec Appendix F.6.
flatten_arc <- function(p0, rx, ry, phi_deg, large_arc, sweep, p1, n = 12) {
  if (rx == 0 || ry == 0) return(matrix(p1, nrow = 1))
  phi <- phi_deg * pi / 180
  cp <- cos(phi); sp <- sin(phi)
  dx2 <- (p0[1] - p1[1]) / 2
  dy2 <- (p0[2] - p1[2]) / 2
  x1p <-  cp * dx2 + sp * dy2
  y1p <- -sp * dx2 + cp * dy2

  rx <- abs(rx); ry <- abs(ry)
  lambda <- x1p^2 / rx^2 + y1p^2 / ry^2
  if (lambda > 1) { s <- sqrt(lambda); rx <- rx * s; ry <- ry * s }

  sign <- if (large_arc != sweep) 1 else -1
  num <- rx^2 * ry^2 - rx^2 * y1p^2 - ry^2 * x1p^2
  den <- rx^2 * y1p^2 + ry^2 * x1p^2
  co <- sign * sqrt(max(0, num / den))
  cxp <- co * (rx * y1p / ry)
  cyp <- co * (-ry * x1p / rx)

  cx <- cp * cxp - sp * cyp + (p0[1] + p1[1]) / 2
  cy <- sp * cxp + cp * cyp + (p0[2] + p1[2]) / 2

  ang <- function(ux, uy, vx, vy) {
    dot <- ux * vx + uy * vy
    len <- sqrt(ux^2 + uy^2) * sqrt(vx^2 + vy^2)
    a <- acos(pmin(1, pmax(-1, dot / len)))
    if (ux * vy - uy * vx < 0) -a else a
  }
  theta1 <- ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
  dtheta <- ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
  if (!sweep && dtheta > 0) dtheta <- dtheta - 2 * pi
  if (sweep && dtheta < 0) dtheta <- dtheta + 2 * pi

  t <- seq(theta1, theta1 + dtheta, length.out = n + 1)[-1]
  x <- cx + rx * cos(phi) * cos(t) - ry * sin(phi) * sin(t)
  y <- cy + rx * sin(phi) * cos(t) + ry * cos(phi) * sin(t)
  cbind(x, y)
}

# ---- path d-string -> subpath vertices ---------------------------------------

parse_svg_path <- function(d) {
  tokens <- tokenize_path(d)
  subpaths <- list()
  subpath_idx <- 0
  cur_pts <- NULL
  cur <- c(NA_real_, NA_real_)
  subpath_start <- c(NA_real_, NA_real_)

  push_subpath <- function() {
    if (!is.null(cur_pts) && nrow(cur_pts) > 0) {
      subpath_idx <<- subpath_idx + 1
      subpaths[[subpath_idx]] <<- cbind(cur_pts, subpath = subpath_idx)
    }
    cur_pts <<- NULL
  }

  for (tok in tokens) {
    a <- tok$args
    if (tok$cmd == "M") {
      push_subpath()
      cur <- c(a[1], a[2])
      subpath_start <- cur
      cur_pts <- matrix(cur, nrow = 1)
      if (length(a) > 2) {
        extra <- matrix(a[-(1:2)], ncol = 2, byrow = TRUE)
        for (i in seq_len(nrow(extra))) {
          cur <- extra[i, ]
          cur_pts <- rbind(cur_pts, cur)
        }
      }
    } else if (tok$cmd == "L") {
      pts <- matrix(a, ncol = 2, byrow = TRUE)
      for (i in seq_len(nrow(pts))) {
        cur <- pts[i, ]
        cur_pts <- rbind(cur_pts, cur)
      }
    } else if (tok$cmd == "C") {
      groups <- matrix(a, ncol = 6, byrow = TRUE)
      for (i in seq_len(nrow(groups))) {
        g <- groups[i, ]
        seg <- flatten_cubic_bezier(cur, g[1:2], g[3:4], g[5:6])
        cur_pts <- rbind(cur_pts, seg)
        cur <- g[5:6]
      }
    } else if (tok$cmd == "A") {
      groups <- matrix(a, ncol = 7, byrow = TRUE)
      for (i in seq_len(nrow(groups))) {
        g <- groups[i, ]
        seg <- flatten_arc(cur, g[1], g[2], g[3], g[4] != 0, g[5] != 0, g[6:7])
        cur_pts <- rbind(cur_pts, seg)
        cur <- g[6:7]
      }
    } else if (tok$cmd == "Z") {
      if (!is.null(cur_pts)) cur_pts <- rbind(cur_pts, subpath_start)
      cur <- subpath_start
    }
  }
  push_subpath()

  if (length(subpaths) == 0) {
    return(tibble(x = numeric(0), y = numeric(0), subpath = integer(0)))
  }
  out <- as.data.frame(do.call(rbind, subpaths))
  names(out) <- c("x", "y", "subpath")
  as_tibble(out)
}

# ---- shape elements -> local-coordinate vertices -----------------------------

shape_to_points <- function(el) {
  tag <- xml_name(el)
  if (tag == "path") {
    d <- xml_attr(el, "d")
    if (is.na(d)) return(tibble(x = numeric(0), y = numeric(0), subpath = integer(0)))
    return(parse_svg_path(d))
  }
  if (tag %in% c("ellipse", "circle")) {
    cx <- as.numeric(xml_attr(el, "cx")); cy <- as.numeric(xml_attr(el, "cy"))
    if (tag == "circle") {
      r <- as.numeric(xml_attr(el, "r")); rx <- r; ry <- r
    } else {
      rx <- as.numeric(xml_attr(el, "rx")); ry <- as.numeric(xml_attr(el, "ry"))
    }
    t <- seq(0, 2 * pi, length.out = 49)
    return(tibble(x = cx + rx * cos(t), y = cy + ry * sin(t), subpath = 1L))
  }
  if (tag == "rect") {
    x <- as.numeric(xml_attr(el, "x")); y <- as.numeric(xml_attr(el, "y"))
    w <- as.numeric(xml_attr(el, "width")); h <- as.numeric(xml_attr(el, "height"))
    return(tibble(x = c(x, x + w, x + w, x, x), y = c(y, y, y + h, y + h, y), subpath = 1L))
  }
  tibble(x = numeric(0), y = numeric(0), subpath = integer(0))
}

# ---- transform parsing --------------------------------------------------------

apply_transform_str <- function(pts, transform_str) {
  if (is.na(transform_str) || !nzchar(transform_str)) return(pts)
  calls <- str_match_all(transform_str, "(\\w+)\\(([^)]*)\\)")[[1]]
  if (nrow(calls) == 0) {
    warning("Unrecognized transform syntax: ", transform_str)
    return(pts)
  }
  # Chained SVG transforms compose left-to-right as nested matrix products;
  # applied to concrete points that means the rightmost function acts first.
  for (i in rev(seq_len(nrow(calls)))) {
    fn <- calls[i, 2]
    v <- as.numeric(str_extract_all(calls[i, 3], svg_number_regex)[[1]])
    xy <- switch(fn,
      matrix = list(x = v[1] * pts$x + v[3] * pts$y + v[5],
                    y = v[2] * pts$x + v[4] * pts$y + v[6]),
      translate = list(x = pts$x + v[1],
                        y = pts$y + (if (length(v) > 1) v[2] else 0)),
      scale = list(x = pts$x * v[1],
                    y = pts$y * (if (length(v) > 1) v[2] else v[1])),
      { warning("Unsupported transform function: ", fn); list(x = pts$x, y = pts$y) }
    )
    pts$x <- xy$x; pts$y <- xy$y
  }
  pts
}

# ---- recursive element resolver ----------------------------------------------

# Resolves any <g>/<a>/<use>/shape element to a tibble(x, y, subpath) in the
# coordinate space of the element's PARENT (i.e. this element's own transform
# has already been applied). Recursing bottom-up like this composes nested
# ancestor transforms correctly without needing to thread a transform stack.
resolve_element <- function(el, doc, ns, use_stack = character(0)) {
  tag <- xml_name(el)
  if (tag == "a") {
    # <a href="...licence.html"> wraps the embedded CC-license badge icon in
    # this source (confirmed by inspection) -- decorative, not tissue
    # geometry, so it's excluded rather than recursed into.
    return(NULL)
  }
  if (tag == "g") {
    kids <- xml_children(el)
    pts_list <- lapply(kids, resolve_element, doc = doc, ns = ns, use_stack = use_stack)
    pts_list <- pts_list[!vapply(pts_list, is.null, logical(1))]
    if (length(pts_list) == 0) return(NULL)
    for (i in seq_along(pts_list)) {
      pts_list[[i]]$subpath <- pts_list[[i]]$subpath + (i - 1) * 1000
    }
    pts <- bind_rows(pts_list)
  } else if (tag == "use") {
    href <- xml_attr(el, "href")
    if (is.na(href)) href <- xml_attr(el, "xlink:href")
    if (is.na(href) || !startsWith(href, "#")) return(NULL)
    target_id <- sub("^#", "", href)
    # Found in the female source: a <use> nested INSIDE the very <g> it
    # references (id="UBERON_0001954" href="#UBERON_0002421", sitting inside
    # <g id="UBERON_0002421">) -- a genuine self-referential cycle in the
    # data, not a hypothetical. Without this guard it recurses forever.
    if (target_id %in% use_stack) {
      warning("`use` cycle detected (", paste(c(use_stack, target_id), collapse = " -> "),
              ") -- skipping")
      return(NULL)
    }
    target <- xml_find_first(doc, paste0("//*[@id='", target_id, "']"), ns)
    if (inherits(target, "xml_missing")) {
      warning("`use` target not found: ", target_id)
      return(NULL)
    }
    pts <- resolve_element(target, doc, ns, use_stack = c(use_stack, target_id))
    if (is.null(pts)) return(NULL)
    ux <- suppressWarnings(as.numeric(xml_attr(el, "x")))
    uy <- suppressWarnings(as.numeric(xml_attr(el, "y")))
    pts$x <- pts$x + (if (is.na(ux)) 0 else ux)
    pts$y <- pts$y + (if (is.na(uy)) 0 else uy)
  } else if (tag %in% c("path", "ellipse", "circle", "rect")) {
    pts <- shape_to_points(el)
  } else {
    return(NULL)
  }
  if (nrow(pts) == 0) return(NULL)
  apply_transform_str(pts, xml_attr(el, "transform"))
}

# ---- top-level extraction ------------------------------------------------------

extract_tissue_paths <- function(svg_path) {
  doc <- read_xml(svg_path)
  ns <- xml_ns(doc)

  collect_layer <- function(layer_id) {
    layer <- xml_find_first(doc, paste0("//d1:g[@id='", layer_id, "']"), ns)
    if (inherits(layer, "xml_missing")) return(tibble())
    kids <- xml_children(layer)
    results <- vector("list", length(kids))
    for (i in seq_along(kids)) {
      el <- kids[[i]]
      pts <- resolve_element(el, doc, ns)
      if (is.null(pts) || nrow(pts) == 0) next
      title_el <- xml_find_first(el, ".//d1:title", ns)
      pts$tissue_name <- if (inherits(title_el, "xml_missing")) NA_character_ else xml_text(title_el)
      pts$tissue_id <- xml_attr(el, "id")
      pts$element_index <- i
      results[[i]] <- pts
    }
    bind_rows(results)
  }

  outline <- collect_layer("LAYER_OUTLINE")
  if (nrow(outline) > 0) outline$tissue_id <- "outline"
  efo <- collect_layer("LAYER_EFO")

  bind_rows(outline, efo) %>%
    mutate(
      ontology = str_extract(tissue_id, "^[A-Za-z]+"),
      polygon_id = paste(tissue_id, element_index, subpath, sep = "_")
    ) %>%
    select(tissue_id, tissue_name, ontology, element_index, subpath, polygon_id, x, y)
}
