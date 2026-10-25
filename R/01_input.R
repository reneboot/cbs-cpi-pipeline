# ==============================================================================
# 01_INPUT.R: Retrieve raw CPI data directly from CBS StatLine API
# ==============================================================================

library(cbsodataR)
library(dplyr)

fetch_cbs_cpi_data <- function(table_id = "83131NED", 
                               product_patterns = c("^012110 Koffie$", "^011130 Brood$")) {
  
  message("1. [INPUT] Fetching metadata from CBS StatLine table: ", table_id)
  meta <- cbs_get_meta(table_id)
  
  # Look up the exact CBS keys for our chosen products in Bestedingscategorieen
  categories <- meta$Bestedingscategorieen
  
  selected_categories <- categories |>
    filter(grepl(paste(product_patterns, collapse = "|"), Title, ignore.case = TRUE))
  
  if (nrow(selected_categories) < 2) {
    stop("Could not find both target products in CBS metadata. Check product_patterns.")
  }
  
  message("   Selected products: ", paste(selected_categories$Title, collapse = " & "))
  
  # Retrieve only the selected products directly from the API (no CSV/Excel used)
  message("2. [INPUT] Downloading observations from StatLine API...")
  raw_data <- cbs_get_data(
    id = table_id,
    Bestedingscategorieen = selected_categories$Key
  ) |>
    # Built-in cbsodataR helpers: convert CBS codes into readable labels and actual Dates
    cbs_add_label_columns() |>
    cbs_add_date_column()
  
  return(raw_data)
}