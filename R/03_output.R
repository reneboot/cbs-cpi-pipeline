# ==============================================================================
# 03_OUTPUT.R: Generate visualizations and store results in SQLite database
# ==============================================================================

library(ggplot2)
library(DBI)
library(RSQLite)

# 1. Create and save visualizations
generate_cpi_plots <- function(multi_quarter_results, single_quarter_result, output_dir = "output/figures") {
  message("5. [OUTPUT] Generating plots...")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  
  # Plot 1: Time series of quarterly mutations over time (Line Chart)
  p_trend <- ggplot(multi_quarter_results, 
                    aes(x = reporting_period, y = kwartaalmutatie_pct, color = product, group = product)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    labs(
      title = "Kwartaalmutatie Consumentenprijsindex (CPI) over de tijd",
      subtitle = "Procentuele verandering t.o.v. het voorgaande kwartaal (2015 = 100)",
      x = "Verslagperiode (Kwartaal)",
      y = "Kwartaalmutatie (%)",
      color = "Product",
      caption = "Bron: CBS StatLine (83131NED), eigen berekening"
    ) +
    theme_minimal(base_size = 11) +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "bottom",
      plot.title = element_text(face = "bold")
    )
  
  ggsave(
    filename = file.path(output_dir, "01_kwartaalmutatie_trend.png"),
    plot = p_trend, width = 9, height = 5, dpi = 300
  )
  
  # Plot 2: Bar chart for the specific highlighted reporting period
  target_q <- unique(single_quarter_result$reporting_period)
  prev_q   <- unique(single_quarter_result$previous_period)
  
  p_bar <- ggplot(single_quarter_result, 
                  aes(x = product, y = kwartaalmutatie_pct, fill = product)) +
    geom_col(width = 0.5, show.legend = FALSE) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
    geom_text(aes(label = paste0(kwartaalmutatie_pct, "%")), 
              vjust = ifelse(single_quarter_result$kwartaalmutatie_pct >= 0, -0.5, 1.5),
              fontface = "bold") +
    labs(
      title = paste("Kwartaalmutatie CPI in", target_q),
      subtitle = paste("Vergeleken met", prev_q),
      x = "Productcategorie",
      y = "Kwartaalmutatie (%)",
      caption = "Bron: CBS StatLine (83131NED)"
    ) +
    theme_minimal(base_size = 12) +
    
    # Add slightly expanded y-limits so text labels fit cleanly
    scale_y_continuous(expand = expansion(mult = c(0.15, 0.15)))
  
  ggsave(
    filename = file.path(output_dir, "02_kwartaalmutatie_focus.png"),
    plot = p_bar, width = 7, height = 5, dpi = 300
  )
  
  message("   Plots saved to: ", output_dir)
}

# 2. Store results in a local SQLite database
save_to_sqlite <- function(clean_monthly_data, quarterly_results, db_path = "output/cpi_database.sqlite") {
  message("6. [OUTPUT] Writing data and results to local SQLite database: ", db_path)
  dir.create(dirname(db_path), recursive = TRUE, showWarnings = FALSE)
  
  # Open connection to local SQLite file (creates file automatically if not present)
  con <- dbConnect(RSQLite::SQLite(), db_path)
  
  # Ensure database connection always closes when function exits, even if an error occurs
  on.exit(dbDisconnect(con), add = TRUE)
  
  # Convert Date column to ISO string (YYYY-MM-DD) so SQLite stores readable dates
  monthly_for_db <- clean_monthly_data |>
    mutate(month = as.character(month))
  
  # Write tables (overwrite = TRUE ensures idempotency / no duplicates on re-runs)
  dbWriteTable(con, "cpi_maandcijfers_clean", monthly_for_db, overwrite = TRUE)
  dbWriteTable(con, "cpi_kwartaalmutaties", quarterly_results, overwrite = TRUE)
  
  message("   Successfully wrote tables: 'cpi_maandcijfers_clean' and 'cpi_kwartaalmutaties'.")
}