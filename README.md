# Casus 1: Kwartaalmutatie Consumentenprijzen (CPI) Pijplijn in R & SQLite

Dit repository bevat een geautomatiseerde, zelfstandige en reproduceerbare datapijplijn in **R** voor het ophalen, valideren, berekenen en visualiseren van de kwartaalmutatie van de consumentenprijsindex (CPI) voor twee bestedingscategorieën (**Koffie** en **Brood**) op basis van CBS StatLine data[cite: 1, 19, 23].

---

## 1. Projectstructuur & Procesarchitectuur (Input - Throughput - Output)

Conform de richtlijnen voor reproduceerbare statistische productiestraten zijn **Input**, **Throughput** en **Output** strikt van elkaar gescheiden in modulaire scripts[cite: 1, 19, 23]:

```text
├── main.R                          # Hoofdscript: voert de volledige pijplijn van A tot Z uit
├── README.md                       # Documentatie van tooling, architectuur en methodologie
├── R/
│   ├── 01_input.R                  # INPUT: Directe API-extractie en metadata-filtering (cbsodataR)
│   ├── 02_throughput.R             # THROUGHPUT: Data-opschoning, validatie en rekenfunctie kwartaalmutatie
│   └── 03_output.R                 # OUTPUT: Genereren van ggplot2-grafieken en opslag in SQLite-database
└── output/
    ├── cpi_database.sqlite         # Lokale SQLite-database met opgeschoonde maanddata en kwartaalcijfers
    └── figures/
        ├── 01_kwartaalmutatie_trend.png  # Lijngrafiek van de kwartaalmutaties (2023-Q1 t/m 2025-Q3)
        └── 02_kwartaalmutatie_focus.png  # Staafdiagram voor de geselecteerde focusperiode (2025-Q3)```
```
# Gedetailleerde processtappen:

1. Input (R/01_input.R) – fetch_cbs_cpi_data():   
  - Maakt rechtstreeks vanuit R verbinding met de CBS StatLine OData API via het pakket cbsodataR (tabel 83131NED: Consumentenprijzen; prijsindex 2015=100), zonder gebruik te maken van externe .csv- of .xlsx-bestanden.   
  - Haalt eerst de tabel-metadata op (cbs_get_meta()) en filtert dynamisch op de categorie-sleutels voor Koffie (012110 Koffie) en Brood (011130 Brood), zodat alleen de benodigde data via de API wordt gedownload.   
  - Voegt via cbs_add_label_columns() en cbs_add_date_column() gestandaardiseerde datumkolommen en leesbare productlabels toe. 

2. Throughput (R/02_throughput.R) – clean_cpi_data() & calculate_quarterly_change():   
  - Data-opschoning (clean_cpi_data): Filtert uitsluitend op maandcijfers (Perioden_freq == "M", waarmee jaarcijfers worden uitgesloten), verwijdert eventuele ontbrekende waarden (NA) en controleert defensief op dubbele observaties per product en maand.   
  - Rekenfunctie (calculate_quarterly_change): Neemt de opgeschoonde dataset en een reporting_period (bijv. "2025-Q3") als input-parameter.   
  - Validatie & Methodologie: De functie controleert eerst of zowel het doelkwartaal ($t$) als het voorgaande kwartaal ($t-1$) exact 3 onderliggende maandcijfers bevatten. Indien een kwartaal incompleet is, stopt de functie direct met een duidelijke foutmelding (fail-fast). Vervolgens wordt per kwartaal het rekenkundig gemiddelde van de drie maandindices berekend ($\bar{P}_t$) en wordt de procentuele kwartaalmutatie berekend:
  
  $$\bar{P}_t = \frac{P_{t,1} + P_{t,2} + P_{t,3}}{3}$$ 
  $$\text{Kwartaalmutatie}_t (\%) = \left( \frac{\bar{P}_t}{\bar{P}_{t-1}} - 1 \right) \times 100$$

3. Output (R/03_output.R) – generate_cpi_plots() & save_to_sqlite():
  - Visualisaties (generate_cpi_plots): Genereert twee publicatieklare grafieken met ggplot2 en slaat deze op in output/figures/:
    - 01_kwartaalmutatie_trend.png: Historisch verloop van de kwartaalmutaties van Koffie en Brood over de periode 2023-Q1 t/m 2025-Q3
    - 02_kwartaalmutatie_focus.png: Directe vergelijking van de kwartaalmutatie in de focusperiode
  - Lokale Database (save_to_sqlite): Schrijft zowel de opgeschoonde maandreeks als de berekende kwartaalmutaties weg naar een lokale SQLite-database (output/cpi_database.sqlite). Dankzij on.exit(dbDisconnect(con)) wordt de databaseverbinding altijd veilig gesloten.

# Gebruikte Tooling & R-Pakketten

R (getest op R >= 4.2.0)   
cbsodataR: Officiële OData API-client voor het programmatisch ophalen van CBS StatLine tabellen en metadata.   
dplyr & lubridate: Voor datamanipulatie, datumrekenkunde (%m-%, %m+%) en aggregatie van maand- naar kwartaalniveau.   
purrr: Voor het functioneel itereren (map_dfr()) van calculate_quarterly_change() over een vector van meerdere verslagperioden.   
ggplot2: Voor het maken en exporteren van de grafieken.   
DBI & RSQLite: Voor het aanmaken, beheren en bevragen van de lokale SQLite-database zonder dat een externe databaseserver nodig is.


# Database Schema (output/cpi_database.sqlite)
De SQLite-database bevat twee tabellen:
  - cpi_maandcijfers_clean: Bevat de opgeschoonde maandelijkse broncijfers (product_code, product, month, cpi_index).
  - cpi_kwartaalmutaties: Bevat de berekende kwartaalgemiddelden en procentuele kwartaalmutaties.
  

# Installatie & Uitvoering (Reproduceerbaarheid)

Volg onderstaande stappen om het volledige proces lokaal te reproduceren:   
  - Clone dit repository (of download de projectmap) en open de hoofdmap als project in RStudio.
  - Installeer de vereiste R-pakketten (eenmalig uitvoeren in de R-console):
  
  install.packages(c("cbsodataR", "dplyr", "lubridate", "ggplot2", "DBI", "RSQLite", "purrr"))
  
  - Start de volledige pijplijn door main.R uit te voeren:
  
  source("main.R")
  
  - Controleer de output
    - De console toont de voortgang per stap (1 t/m 6) en print ter verificatie de meest recente rijen rechtstreeks vanuit de SQLite-database.
    - De grafieken staan in output/figures/ en de SQLite-database staat in output/cpi_database.sqlite.
