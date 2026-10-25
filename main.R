# ==============================================================================
# MAIN.R: Master pipeline script (Input -> Throughput -> Output)
# ==============================================================================

library(purrr)
library(DBI)
library(RSQLite)

# Load modular functions from R/ directory
source("R/01_input.R")
source("R/02_throughput.R")
source("R/03_output.R")

# ------------------------------------------------------------------------------
# STEP 1: INPUT (Retrieve raw data from CBS StatLine API)
# ------------------------------------------------------------------------------
raw_cpi_data <- fetch_cbs_cpi_data(
  table_id = "83131NED",
  product_patterns = c("^012110 Koffie$", "^011130 Brood$")
)

# ------------------------------------------------------------------------------
# STEP 2: THROUGHPUT (Clean data & calculate quarterly mutations)
# ------------------------------------------------------------------------------
clean_monthly_cpi <- clean_cpi_data(raw_cpi_data)

# A. Demonstrate the function for a single specific reporting period (Assignment 1.2)
focus_period <- "2025-Q3"
message("4. [THROUGHPUT] Calculating quarterly mutation for focus period: ", focus_period)
single_period_result <- calculate_quarterly_change(
  data = clean_monthly_cpi,
  reporting_period = focus_period
)
print(single_period_result)

# B. Apply the exact same function across multiple quarters for historical analysis
quarters_to_analyze <- c(
  "2023-Q1", "2023-Q2", "2023-Q3", "2023-Q4",
  "2024-Q1", "2024-Q2", "2024-Q3", "2024-Q4",
  "2025-Q1", "2025-Q2", "2025-Q3"
)

multi_quarter_results <- map_dfr(
  quarters_to_analyze,
  ~ calculate_quarterly_change(data = clean_monthly_cpi, reporting_period = .x)
)

# ------------------------------------------------------------------------------
# STEP 3: OUTPUT (Save visualizations & store results in SQLite)
# ------------------------------------------------------------------------------
generate_cpi_plots(
  multi_quarter_results = multi_quarter_results,
  single_quarter_result = single_period_result
)

save_to_sqlite(
  clean_monthly_data = clean_monthly_cpi,
  quarterly_results  = multi_quarter_results
)

# Quick verification query to prove the SQLite database works
con <- dbConnect(RSQLite::SQLite(), "output/cpi_database.sqlite")
message("\n--- Verification: Top 6 rows from SQLite table 'cpi_kwartaalmutaties' ---")
print(dbGetQuery(con, "SELECT * FROM cpi_kwartaalmutaties ORDER BY reporting_period DESC LIMIT 6;"))
dbDisconnect(con)

message("\nPipeline completed successfully!")