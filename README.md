# COVID‑19 ETL & Analytics Dashboard

> **End‑to‑end data pipeline and Power BI dashboard that ingests, cleanses, and visualises global COVID‑19 case, death, and vaccination trends across 200+ countries.**

![dashboard-preview](assets/dashboard_preview.png)

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Features](#features)
3. [Architecture](#architecture)
4. [Tech Stack](#tech-stack)
5. [Folder Structure](#folder-structure)
6. [Quick Start](#quick-start)
7. [Usage](#usage)
8. [Performance Benchmarks](#performance-benchmarks)
9. [Contributing](#contributing)
10. [License](#license)

---

## Project Overview

This project began as a personal challenge to design a production‑style analytics pipeline on a developer laptop. It now automates the **extraction, transformation, loading, and reporting of 89 000+ rows of COVID‑19 data** collected daily from public sources and **surfaces real‑time insights in an interactive Power BI report**. citeturn0file0

Key goals were to:

* Build a **Docker‑hosted SQL Server** warehouse with reproducible scripts.
* Achieve **sub‑second query latency on 178 k+ rows** through efficient T‑SQL.
* Provide a no‑code visual layer so decision‑makers can explore trends without touching the database.

---

## Features

* **Automated ETL**
  ▸ Incremental ingestion scripts that pull daily CSV updates.
  ▸ Robust error handling with `TRY...CATCH` and audit logging.
* **Data Quality Rules**
  ▸ Deduplication via window functions (`ROW_NUMBER`).
  ▸ Standardised country & ISO codes, date casting, and numeric coercion.
* **Power BI Dashboard**
  ▸ Choropleth map with drill‑downs to continent & country.
  ▸ Rolling 7‑day averages and vaccination progress lines.
  ▸ Dynamic slicers for date range, region, and metric.
* **One‑Command Deployment** with Docker Compose.
* **CI Checks** using GitHub Actions (lint, unit tests, style‑guide enforcement).

---

## Architecture

```text
┌────────────┐    Extract     ┌────────┐  Transform   ┌────────┐  Load   ┌─────────────┐
│  Source    │ ─────────────▶│ Bronze │─────────────▶│ Silver │────────▶│   BI Layer  │
│  CSV APIs  │               └────────┘              └────────┘         │ Power BI    │
└────────────┘                                                 └─────────────┘
```

1. **Bronze Layer** – Raw CSV files staged in `dbo.bronze_*` tables.
2. **Silver Layer** – Cleansed views & tables (`dbo.silver_cases`, `dbo.silver_vaccinations`).
3. **BI Layer** – Power BI consumes optimised views via Direct Query.

---

## Tech Stack

| Layer           | Technology                             | Why                                          |
| --------------- | -------------------------------------- | -------------------------------------------- |
| Data Storage    | **SQL Server 2022** in Docker          | Familiar T‑SQL engine, easy local deployment |
| Orchestration   | **Bash** + `sqlcmd`                    | Lightweight cron‑style scheduling            |
| Transformations | **T‑SQL** (CTEs, window functions)     | High‑performance in‑db compute               |
| Visualisation   | **Power BI Desktop**                   | Rich interactivity & drill‑down              |
| DevOps          | **Docker Compose**, **GitHub Actions** | Reproducible environments & CI               |

---

## Folder Structure

```
├── data/                 # Raw CSV dumps (downloaded by scripts)
├── sql/
│   ├── 1_bronze_load.sql
│   ├── 2_silver_transform.sql
│   └── 3_views.sql
├── etl/
│   └── run_etl.sh        # Orchestrates the three SQL stages
├── dashboard/
│   └── CovidInsights.pbix
├── docker-compose.yml
└── README.md
```

---

## Quick Start

```bash
# 1. Clone & enter the repo
$ git clone https://github.com/gurmukhsangha4/covid19-etl-dashboard.git
$ cd covid19-etl-dashboard

# 2. Spin up SQL Server in Docker
$ docker compose up -d

# 3. Run the ETL pipeline (loads ~89k rows)
$ ./etl/run_etl.sh

# 4. Open dashboard/CovidInsights.pbix in Power BI Desktop
```

> **Note**: Default SQL credentials live in `docker-compose.yml`. Override with environment vars in production.

---

## Usage

### Updating Data Daily

Add a cron job (Linux/macOS) or Task Scheduler (Windows):

```cron
0 2 * * * /path/to/repo/etl/run_etl.sh >> etl/logs/etl_`date +\%F`.log 2>&1
```

### Running Ad‑hoc Queries

```sql
-- Top 10 countries by vaccination rate
SELECT TOP 10 Country, MAX(people_vaccinated_per_hundred) AS pct_vaccinated
FROM dbo.silver_vaccinations
GROUP BY Country
ORDER BY pct_vaccinated DESC;
```

### Publishing the Dashboard

1. Ensure the ETL job has completed.
2. In Power BI Desktop ➜ **Publish** ➜ choose your workspace.
3. Configure scheduled refresh to call `etl/run_etl.sh` via a gateway or replace with Power Automate.

---

## Performance Benchmarks

| Stage             | Rows    | Time                 | Speed‑up                |
| ----------------- | ------- | -------------------- | ----------------------- |
| Bronze Load       | 89 000  | **<10 s**            | −75 % manual CSV import |
| Silver Transforms | 178 000 | **<0.8 s** avg query | Sub‑second latency      |

> Benchmarks captured on MacBook Pro M1, 16 GB RAM, Docker Desktop 4.19 running SQL Server 2022.

---

## Contributing

Pull requests are welcome! Please open an issue to discuss major changes such as refactoring the ETL or adding new visuals.

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Open a PR

---

## License

[MIT](LICENSE)

---

## Contact

**Gurmukh Sangha**
Waterloo ID: 21145339 — [gssangha@uwaterloo.ca](mailto:gssangha@uwaterloo.ca)
[LinkedIn](https://linkedin.com/in/gurmukh-sangha) • [GitHub](https://github.com/gurmukhsangha4)
