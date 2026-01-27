# A map of old-new field/variable names
url <- "https://www.ices.dk/data/Documents/DATRAS/DATRAS_NewHeaders_Lookup_Dec2024.xlsx"
download.file(url, destfile = paste0("data-raw/", basename(url)))

# A map of new fields, including types
url <- "https://www.ices.dk/data/Documents/DATRAS/DATRAS_Field_descriptions_and_example_file_December2025.xlsx"
download.file(url, destfile = paste0("data-raw/", basename(url)))
