# Tests for dr_add_id() / .dr_concat_ws().
#
# The contract that matters is ARITY: .id always has eight ":"-separated
# fields, so it can be split back into the eight key columns positionally and
# so it is byte-identical to the DATRAS R package's haul.id. NA fields used to
# be skipped, which broke both properties on 4.59% of hauls; changed
# 2026-09-03.
#
# Every case is checked on BOTH backends. That is the whole reason
# .dr_concat_ws() exists: R's paste() renders NA as "NA" while dbplyr
# translates paste(sep=) to DuckDB's CONCAT_WS(), which drops NA fields, so a
# .id built lazily and one built eagerly would otherwise disagree -- and .id is
# the join key between HH, HL and CA.

.id_fixture <- function() {
  data.frame(
    Survey = "BITS", Year = 1991L, Quarter = 1L, Country = "DE",
    Platform = "06S1", Gear = "H20",
    StationName = c("33", NA, NA),
    HaulNumber  = c(28L, 28L, NA),
    stringsAsFactors = FALSE
  )
}

# Run the same expectations against a data frame and against a DuckDB view of
# it, so a divergence fails rather than hiding until build time.
.id_both <- function(d, name) {
  con <- obus::dr_duckdb()
  lz  <- dplyr::copy_to(con, d, name, overwrite = TRUE)
  list(eager = dr_add_id(d)$.id,
       lazy  = dplyr::pull(dr_add_id(lz), .id))
}

test_that("a complete key gives the eight fields in DR_ID_FIELDS order", {
  d <- .id_fixture()[1, ]
  got <- .id_both(d, "id_complete")

  expect_identical(got$eager, "BITS:1991:1:DE:06S1:H20:33:28")
  expect_identical(got$lazy, got$eager)
})

test_that("an NA field becomes the literal 'NA' rather than being skipped", {
  got <- .id_both(.id_fixture(), "id_na")

  expect_identical(
    got$eager,
    c("BITS:1991:1:DE:06S1:H20:33:28",
      "BITS:1991:1:DE:06S1:H20:NA:28",     # StationName missing
      "BITS:1991:1:DE:06S1:H20:NA:NA")     # StationName and HaulNumber missing
  )
  expect_identical(got$lazy, got$eager)
})

test_that("every .id has exactly eight fields, whatever is missing", {
  got <- .id_both(.id_fixture(), "id_arity")

  for (backend in names(got)) {
    expect_equal(lengths(strsplit(got[[backend]], ":", fixed = TRUE)),
                 rep(8L, 3L), info = backend)
  }
})

test_that(".id splits back into the eight key columns positionally", {
  # The property the skip-NA scheme could not offer: 6,899 archive hauls used
  # to yield a seven-field .id, so this split shifted HaulNumber into the
  # StationName slot.
  d <- .id_fixture()
  out <- dr_add_id(d)

  parts <- do.call(rbind, strsplit(out$.id, ":", fixed = TRUE))
  colnames(parts) <- DR_ID_FIELDS

  expect_identical(parts[, "StationName"], c("33", "NA", "NA"))
  expect_identical(parts[, "HaulNumber"], c("28", "28", "NA"))
  expect_identical(parts[, "Gear"], rep("H20", 3L))
})

test_that("two hauls that the skip-NA scheme would have collided stay distinct", {
  # StationName = NA + HaulNumber = 33  vs  StationName = 33 + HaulNumber = NA
  # both skipped down to "...:H20:33". Fixed arity separates them.
  d <- data.frame(
    Survey = "BITS", Year = 1991L, Quarter = 1L, Country = "DE",
    Platform = "06S1", Gear = "H20",
    StationName = c(NA, "33"),
    HaulNumber  = c(33L, NA),
    stringsAsFactors = FALSE
  )
  got <- .id_both(d, "id_collide")

  expect_identical(got$eager, c("BITS:1991:1:DE:06S1:H20:NA:33",
                                "BITS:1991:1:DE:06S1:H20:33:NA"))
  expect_equal(dplyr::n_distinct(got$eager), 2L)
  expect_identical(got$lazy, got$eager)
})

test_that("a key with nothing in it at all is NA, not eight 'NA' tokens", {
  # "NA:NA:NA:NA:NA:NA:NA:NA" would collide every keyless row onto one .id.
  # Cannot arise in the current archive -- the first six fields are never NA
  # in HH, HL or CA -- but the guard is deliberate.
  d <- .id_fixture()[1, ]
  d[1, ] <- NA
  got <- .id_both(d, "id_allna")

  expect_true(is.na(got$eager))
  expect_true(is.na(got$lazy))
})

test_that(".id is appended last and no working column leaks out", {
  d <- .id_fixture()
  out <- dr_add_id(d)

  expect_identical(names(out), c(DR_ID_FIELDS, ".id"))
  expect_false(".dr_any" %in% names(out))

  con <- obus::dr_duckdb()
  lz  <- dplyr::copy_to(con, d, "id_cols", overwrite = TRUE)
  expect_identical(colnames(dr_add_id(lz)), c(DR_ID_FIELDS, ".id"))
})

test_that("a missing key column is an error, not a silently short .id", {
  d <- .id_fixture()[, setdiff(DR_ID_FIELDS, "StationName")]
  expect_error(dr_add_id(d), "StationName")
})
