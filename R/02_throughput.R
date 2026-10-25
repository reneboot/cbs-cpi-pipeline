# ==============================================================================
# 02_THROUGHPUT.R: Data standardization and quarterly mutation calculation
# ==============================================================================

library(dplyr)
library(lubridate)

# 1. Clean and standardize the raw CBS API data
clean_cpi_data <- function(raw_data) {
  message("3. [THROUGHPUT] Cleaning and standardizing monthly CPI data...")
  
  clean_df <- raw_data |>
    # Keep only monthly figures (exclude annual 'JJ00' averages)
    filter(Perioden_freq == "M") |>
    transmute(
      product_code = trimws(as.character(Bestedingscategorieen)),
      # Remove numeric code prefix (e.g. "012110 Koffie" -> "Koffie") for clean labels
      product      = sub("^[0-9]+\\s+", "", as.character(Bestedingscategorieen_label)),
      month        = as.Date(Perioden_Date),
      cpi_index    = as.numeric(CPI_1)
    ) |>
    # Drop future/unreleased months where CPI is NA
    filter(!is.na(cpi_index)) |>
    arrange(product, month)
  
  # Validation check: ensure no duplicate product-month combinations exist
  if (any(duplicated(clean_df[c("product", "month")]))) {
    stop("Validation Error: Duplicate product-month observations detected!")
  }
  
  return(clean_df)
}

# 2. Required Function: Calculate quarterly mutation for a specific reporting period
#    Input parameter: reporting_period in format "YYYY-Q#" (e.g., "2025-Q3")
calculate_quarterly_change <- function(data, reporting_period) {
  
  # Defensive input checks
  required_cols <- c("product", "month", "cpi_index")
  if (!all(required_cols %in% names(data))) {
    stop("Input data is missing required columns: product, month, cpi_index")
  }
  
  if (length(reporting_period) != 1 || !grepl("^\\d{4}-Q[1-4]$", reporting_period)) {
    stop("Invalid reporting_period format. Please use 'YYYY-Q1' through 'YYYY-Q4'.")
  }
  
  # Parse target year and quarter
  target_year    <- as.integer(substr(reporting_period, 1, 4))
  target_quarter <- as.integer(substr(reporting_period, 7, 7))
  
  # Determine the first day of the target quarter and the previous quarter
  target_start_month <- (target_quarter - 1) * 3 + 1
  target_start_date  <- as.Date(sprintf("%04d-%02d-01", target_year, target_start_month))
  prev_start_date    <- target_start_date %m-% months(3)
  target_end_date    <- target_start_date %m+% months(3)
  
  # Determine label for previous quarter
  prev_period <- ifelse(
    target_quarter == 1,
    paste0(target_year - 1, "-Q4"),
    paste0(target_year, "-Q", target_quarter - 1)
  )
  
  # Filter to the 6 months covering the previous and target quarters
  quarterly_summary <- data |>
    filter(month >= prev_start_date & month < target_end_date) |>
    mutate(quarter_label = paste0(year(month), "-Q", quarter(month))) |>
    group_by(product, quarter_label) |>
    summarise(
      months_count = n_distinct(month),
      avg_cpi      = mean(cpi_index, na.rm = FALSE),
      .groups      = "drop"
    )
  
  # Pivot/compare previous quarter vs target quarter per product
  result <- quarterly_summary |>
    group_by(product) |>
    summarise(
      reporting_period    = reporting_period,
      previous_period     = prev_period,
      prev_months_count   = sum(months_count[quarter_label == prev_period]),
      target_months_count = sum(months_count[quarter_label == reporting_period]),
      cpi_prev_quarter    = avg_cpi[quarter_label == prev_period][1],
      cpi_target_quarter  = avg_cpi[quarter_label == reporting_period][1],
      .groups             = "drop"
    )
  
  # Strict validation: a valid quarterly CPI requires all 3 underlying months
  if (nrow(result) == 0 || 
      any(result$prev_months_count != 3) || 
      any(result$target_months_count != 3) ||
      anyNA(result$cpi_prev_quarter) || 
      anyNA(result$cpi_target_quarter)) {
    stop(paste("Incomplete monthly data (3 months required per quarter) for period:", reporting_period))
  }
  
  # Calculate percentage quarterly mutation: ((P_t / P_{t-1}) - 1) * 100
  result <- result |>
    mutate(
      kwartaalmutatie_pct = round(((cpi_target_quarter / cpi_prev_quarter) - 1) * 100, 2)
    ) |>
    select(
      product, 
      reporting_period, 
      previous_period, 
      cpi_prev_quarter, 
      cpi_target_quarter, 
      kwartaalmutatie_pct
    )
  
  return(result)
}