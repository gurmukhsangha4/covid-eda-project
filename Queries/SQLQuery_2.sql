-- ================================================================
-- 13. View: PercentPopulationVac
--    Purpose: Expose Canada’s daily vaccination status for use in
--             dashboards and downstream views.
--    Columns:
--      continent            – Continent name
--      location             – Country name (Canada)
--      ReportDate           – Date of record
--      population           – Total population
--      people_vaccinated    – Cumulative count of people with ≥1 dose
--      people_fully_vaccinated – Cumulative count of people fully vaccinated
--      RollingPplVac        – Cumulative doses administered (running sum)
-- ================================================================
USE CovidProject;
GO

CREATE OR ALTER VIEW dbo.PercentPopulationVac
AS
SELECT
  dea.continent,
  dea.location,
  dea.[date]            AS ReportDate,
  dea.population,
  vac.people_vaccinated,
  vac.people_fully_vaccinated,
  SUM(CAST(vac.new_vaccinations AS INT))
    OVER (PARTITION BY dea.location ORDER BY dea.[date])
    AS RollingPplVac
FROM
  dbo.[COVID-DEATHS]       AS dea
  JOIN dbo.[COVID-VACANATIONS] AS vac
    ON dea.location = vac.location
   AND dea.[date]   = vac.[date]
WHERE
  dea.continent IS NOT NULL
  AND dea.location IN (
  'Canada', 'United States', 'United Kingdom',
  'France', 'Germany', 'Italy', 'Japan'
)
GO


-- ================================================
-- 14. View: Vaccination vs Case Decline (Canada)
--    Compare cumulative doses to 7-day average new cases
-- ================================================
USE CovidProject;
GO

CREATE OR ALTER VIEW dbo.VaccinationCaseDeclineCanada
AS
WITH metrics AS (
  SELECT
    dea.location,
    dea.[date]       AS ReportDate,
    dea.population,
    /* cumulative doses administered */
    SUM(CAST(vac.new_vaccinations AS INT))
      OVER (PARTITION BY dea.location
            ORDER BY dea.[date])
      AS RollingPplVac,
    /* 7-day average of new cases */
    SUM(dea.new_cases)
      OVER (
        PARTITION BY dea.location
        ORDER BY dea.[date]
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
      ) / 7.0
      AS avg_weekly_cases
  FROM dbo.[COVID-DEATHS]      AS dea
  JOIN dbo.[COVID-VACANATIONS] AS vac
    ON dea.location = vac.location
   AND dea.[date]   = vac.[date]
  WHERE dea.continent IS NOT NULL
    AND dea.location = 'Canada'
)
SELECT
  ReportDate,
  /* percent doses per person */
  ROUND(100.0 * RollingPplVac / NULLIF(population, 0), 2)
    AS pct_vaccinated,
  /* smoothed new-case trend */
  ROUND(avg_weekly_cases, 2) AS avg_weekly_cases
FROM metrics;
GO


-- ================================================================
-- 15. View: G7 Time to First 50% Vaccination & Death Rate
--    “When did each G7 country hit half-population doses, and how
--     much of their population had died by then?”
-- ================================================================
CREATE OR ALTER VIEW dbo.G7_TimeTo50PercentVaccinated
AS
WITH metrics AS (
  SELECT
    dea.location,
    dea.[date]       AS ReportDate,
    dea.population,
    /* cumulative doses */
    SUM(CAST(vac.new_vaccinations AS INT))
      OVER (PARTITION BY dea.location
            ORDER BY dea.[date])
      AS RollingPplVac,
    /* cumulative deaths */
    SUM(dea.new_deaths)
      OVER (PARTITION BY dea.location
            ORDER BY dea.[date])
      AS RollingDeaths
  FROM dbo.[COVID-DEATHS]      AS dea
  JOIN dbo.[COVID-VACANATIONS] AS vac
    ON dea.location = vac.location
   AND dea.[date]   = vac.[date]
  WHERE dea.continent IS NOT NULL
    AND dea.location IN (
      'Canada','United States','United Kingdom',
      'France','Germany','Italy','Japan'
    )
),
first50 AS (
  SELECT
    location,
    ReportDate,
    population,
    RollingDeaths,
    ROW_NUMBER() OVER (
      PARTITION BY location
      ORDER BY ReportDate
    ) AS rn
  FROM metrics
  WHERE RollingPplVac >= population * 0.5
)
SELECT
  location AS Country,
  ReportDate AS Date_50pct_Vaccinated,
  /* % of population dead by that milestone */
  ROUND(100.0 * RollingDeaths / NULLIF(population, 0), 2)
    AS pct_died_to_date
FROM first50
WHERE rn = 1;
GO


-- ===================================================================
-- 16. View: G7 Peak Death Day vs Vaccination & Case Outcomes
--    For each G7 country, show the worst single-day death spike,
--    vaccine coverage, cumulative deaths & cases, and CFR at that date.
-- ===================================================================
CREATE OR ALTER VIEW dbo.G7_PeakDeathVaccinationOutcomes
AS
WITH metrics AS (
  SELECT
    dea.location,
    dea.[date]       AS ReportDate,
    dea.population,
    /* cleansed vaccination counts */
    CAST(REPLACE(vac.people_vaccinated,     ',', '') AS BIGINT)
      AS People_Vaccinated,
    CAST(REPLACE(vac.people_fully_vaccinated, ',', '') AS BIGINT)
      AS People_Fully_Vaccinated,
    dea.new_deaths,
    dea.new_cases,
    /* running totals */
    SUM(dea.new_deaths) 
      OVER (PARTITION BY dea.location ORDER BY dea.[date]) 
      AS Cumulative_Deaths,
    SUM(dea.new_cases) 
      OVER (PARTITION BY dea.location ORDER BY dea.[date]) 
      AS Cumulative_Cases
  FROM dbo.[COVID-DEATHS]      AS dea
  JOIN dbo.[COVID-VACANATIONS] AS vac
    ON dea.location = vac.location
   AND dea.[date]   = vac.[date]
  WHERE dea.continent IS NOT NULL
    AND dea.location IN (
      'Canada','United States','United Kingdom',
      'France','Germany','Italy','Japan'
    )
),
peak AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY location
      ORDER BY new_deaths DESC, ReportDate
    ) AS rn
  FROM metrics
)
SELECT
  location AS Country,
  ReportDate AS Peak_Death_Date,
  new_deaths AS Peak_Death_Count,
  /* vaccine coverage at peak */
  ROUND(100.0 * People_Vaccinated     / population, 2)
    AS pct_at_least_one_dose,
  ROUND(100.0 * People_Fully_Vaccinated / population, 2)
    AS pct_fully_vaccinated,
  /* outcomes at peak */
  ROUND(100.0 * Cumulative_Deaths / population, 2)
    AS pct_died_to_date,
  ROUND(100.0 * Cumulative_Cases  / population, 2)
    AS pct_cases_to_date,
  /* case fatality ratio (%) */
  ROUND(
    100.0 * Cumulative_Deaths
          / NULLIF(Cumulative_Cases, 0)
  , 2) AS case_fatality_ratio_pct
FROM peak
WHERE rn = 1;
GO
