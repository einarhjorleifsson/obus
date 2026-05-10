#' Set variable types
#'
#' Used when downloading raw data to ensures consistency in column types
#'
#' The column type setting is according to [DATRAS_Field_descriptions_and_example_file_May2022.xlsx]("www.ices.dk\/data/Documents\/DATRAS\/DATRAS_Field_descriptions_and_example_file_May2022.xlsx")
#' with some additional guesswork for flexfile variables
#'
#' @param d A DATRAS exchange table
#'
#' @return A table of same dimention as input

dr_settypes <- function(d) {

  key_chr <- dr_fields |> dplyr::filter(DataFormat == "char") |> dplyr::pull(FieldName) |> unique()
  key_int <- dr_fields |> dplyr::filter(DataFormat == "int") |> dplyr::pull(FieldName) |> unique()
  key_dbl <- dr_fields |> dplyr::filter(DataFormat == "decimal") |> dplyr::pull(FieldName) |> unique()

  d <-
    d |>
    dplyr::mutate(dplyr::across(dplyr::any_of(key_chr), as.character))  |>
    dplyr::mutate(dplyr::across(dplyr::any_of(key_int), as.integer))  |>
    dplyr::mutate(dplyr::across(dplyr::any_of(key_dbl), as.numeric))

  return(d)

}
