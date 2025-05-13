--------------------------------------------------------------
-- COVID Data Exploration Script
-- Author: Gurmukh Sangha
-- Purpose: Analyze global COVID-19 cases, deaths, vaccinations,
--          and key metrics for comparison and visualization.
--------------------------------------------------------------

-- ================================================
-- 1. Preview all country-level death records
--    Excludes sub-regions by filtering out NULL continents
-- ================================================
SELECT *
FROM CovidProject..[COVID-DEATHS] AS cd
WHERE cd.continent IS NOT NULL   -- keep only country‐level data
ORDER BY cd.continent, cd.location;  -- alphabetical by continent, then country

-- ================================================
-- 2. Basic case & death overview for all locations
-- ================================================
SELECT
  cd.Location,
  cd.[date]        AS RecordDate,
  cd.total_cases,
  cd.new_cases,
  cd.total_deaths,
  cd.population
FROM CovidProject..[COVID-DEATHS] AS cd
ORDER BY cd.Location, cd.[date];

-- ================================================
-- 3. Case Fatality Percentage for Canada
--    “Of confirmed cases on a given day, what % died?”
-- ================================================
SELECT
  cd.Location,
  cd.[date]       AS RecordDate,
  cd.total_cases,
  cd.total_deaths,
  ROUND(
    100.0 * cd.total_deaths
          / NULLIF(cd.total_cases, 0)
  , 2)             AS death_pct
FROM CovidProject..[COVID-DEATHS] AS cd
WHERE cd.Location = 'Canada'    -- focus on Canada
ORDER BY cd.Location, cd.[date];

-- ================================================
-- 4. Infection Rate vs Population for Canada
--    “What proportion of Canada’s population got COVID?”
-- ================================================
SELECT
  cd.Location,
  cd.[date]       AS RecordDate,
  cd.total_cases,
  cd.population,
  ROUND(
    100.0 * cd.total_cases
          / NULLIF(cd.population, 0)
  , 2)             AS infected_pct
FROM CovidProject..[COVID-DEATHS] AS cd
WHERE cd.Location = 'Canada'
ORDER BY cd.Location, cd.[date];

-- ================================================
-- 5. Top Global Infection Rates vs Population
--    Find countries with highest % infected at peak case count
-- ================================================
SELECT
  cd.Location,
  cd.population,
  MAX(cd.total_cases) AS max_infection_cnt,
  ROUND(
    100.0 * MAX(cd.total_cases)
          / NULLIF(cd.population, 0)
  , 2)                AS infected_pct
FROM CovidProject..[COVID-DEATHS] AS cd
GROUP BY
  cd.Location,
  cd.population
ORDER BY
  infected_pct DESC;   -- descending by % infected

-- ================================================
-- 6. Top Infection Rates in G7 Countries
-- ================================================
SELECT
  cd.Location,
  cd.population,
  MAX(cd.total_cases) AS max_infection_cnt,
  ROUND(
    100.0 * MAX(cd.total_cases)
          / NULLIF(cd.population, 0)
  , 2)                AS infected_pct
FROM CovidProject..[COVID-DEATHS] AS cd
WHERE cd.Location IN (
  'Canada', 'United States', 'United Kingdom',
  'France', 'Germany', 'Italy', 'Japan'
)
GROUP BY
  cd.Location,
  cd.population
ORDER BY
  infected_pct DESC;

-- ================================================
-- 7. Countries/Areas with the Highest Death Count
--    Global view for regions without continent info
-- ================================================
SELECT
  cd.Location,
  MAX(cd.total_deaths) AS max_deaths
FROM CovidProject..[COVID-DEATHS] AS cd
WHERE cd.continent IS NULL
GROUP BY
  cd.Location
ORDER BY
  max_deaths DESC;

-- ================================================
-- 8. Daily Global Death % vs Cases
--    “What % of new cases ended in death each day worldwide?”
-- ================================================
SELECT
  cd.[date]        AS RecordDate,
  SUM(cd.new_cases)   AS daily_cases,
  SUM(cd.new_deaths)  AS daily_deaths,
  ROUND(
    100.0 * SUM(cd.new_deaths)
          / NULLIF(SUM(cd.new_cases), 0)
  , 2)               AS death_pct
FROM CovidProject..[COVID-DEATHS] AS cd
WHERE cd.continent IS NOT NULL
GROUP BY
  cd.[date]
ORDER BY
  cd.[date];

-- ================================================
-- 9. Rolling Vaccinations in Canada
--    Cumulative sum of daily new vaccinations
-- ================================================
SELECT
  dea.continent,
  dea.location,
  dea.[date]       AS RecordDate,
  dea.population,
  vac.new_vaccinations,
  SUM(CAST(vac.new_vaccinations AS INT))
    OVER (
      PARTITION BY dea.location
      ORDER BY dea.[date]
    )               AS RollingPplVac
FROM CovidProject..[COVID-DEATHS] AS dea
JOIN CovidProject..[COVID-VACANATIONS] AS vac
  ON dea.location = vac.location
 AND dea.[date]   = vac.[date]
WHERE
  dea.continent IS NOT NULL
  AND dea.location = 'Canada'
ORDER BY
  dea.location,
  dea.[date];

-- ================================================
-- 10. Vaccination vs Case Decline for Canada
--     Compare percent vaccinated to 7-day avg new cases
-- ================================================
;WITH metrics AS (
  SELECT
    dea.location,
    dea.[date]       AS ReportDate,
    dea.population,
    -- cumulative doses administered
    SUM(CAST(vac.new_vaccinations AS INT))
      OVER (PARTITION BY dea.location ORDER BY dea.[date]) AS RollingPplVac,
    -- 7-day average of new cases
    SUM(dea.new_cases)
      OVER (
        PARTITION BY dea.location
        ORDER BY dea.[date]
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
      ) / 7.0   AS avg_weekly_cases
  FROM dbo.[COVID-DEATHS] AS dea
  JOIN dbo.[COVID-VACANATIONS] AS vac
    ON dea.location = vac.location
   AND dea.[date]   = vac.[date]
  WHERE
    dea.continent IS NOT NULL
    AND dea.location = 'Canada'
)
SELECT
  ReportDate,
  ROUND(100.0 * RollingPplVac / NULLIF(population, 0), 2) AS pct_vaccinated,
  ROUND(avg_weekly_cases, 2)                              AS avg_weekly_cases
FROM metrics
ORDER BY ReportDate;
GO

-- ================================================
-- 11. Time to First 50% Vaccinated & Death Rate for G7
-- ================================================
;WITH metrics AS (
  SELECT
    dea.location,
    dea.[date]       AS ReportDate,
    dea.population,
    -- cumulative doses administered
    SUM(CAST(vac.new_vaccinations AS INT))
      OVER (PARTITION BY dea.location ORDER BY dea.[date]) AS RollingPplVac,
    -- cumulative deaths to date
    SUM(dea.new_deaths)
      OVER (PARTITION BY dea.location ORDER BY dea.[date]) AS RollingDeaths
  FROM dbo.[COVID-DEATHS] AS dea
  JOIN dbo.[COVID-VACANATIONS] AS vac
    ON dea.location = vac.location
   AND dea.[date]   = vac.[date]
  WHERE
    dea.continent IS NOT NULL
    AND dea.location IN (
      'Canada', 'United States', 'United Kingdom',
      'France', 'Germany', 'Italy', 'Japan'
    )
),
first50 AS (
  -- pick the first date when dose-pct ≥ 50%
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
  location                        AS Country,
  ReportDate                      AS Date_50pct_Vaccinated,
  ROUND(100.0 * RollingDeaths
        / population, 2)         AS Pct_Died_To_Date
FROM first50
WHERE rn = 1
ORDER BY
  Date_50pct_Vaccinated;
GO

-- ================================================
-- 12. Peak Death Day vs Vaccination & Case Outcomes
-- ================================================
;WITH metrics AS (
  SELECT
    dea.location,
    dea.[date]       AS ReportDate,
    dea.population,
    -- clean & cast vaccination counts
    CAST(REPLACE(vac.people_vaccinated, ',', '') AS BIGINT)       AS People_Vaccinated,
    CAST(REPLACE(vac.people_fully_vaccinated, ',', '') AS BIGINT) AS People_Fully_Vaccinated,
    dea.new_deaths,
    dea.new_cases,
    -- running totals
    SUM(dea.new_deaths) OVER (PARTITION BY dea.location ORDER BY dea.[date]) AS Cumulative_Deaths,
    SUM(dea.new_cases)  OVER (PARTITION BY dea.location ORDER BY dea.[date]) AS Cumulative_Cases
  FROM dbo.[COVID-DEATHS]      AS dea
  JOIN dbo.[COVID-VACANATIONS] AS vac
    ON dea.location = vac.location
   AND dea.[date]   = vac.[date]
  WHERE
    dea.continent IS NOT NULL
    AND dea.location IN (
      'Canada', 'United States', 'United Kingdom',
      'France', 'Germany', 'Italy', 'Japan'
    )
),
peak AS (
  -- identify the single day with the highest death count per country
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY location
      ORDER BY new_deaths DESC, ReportDate
    ) AS rn
  FROM metrics
)
SELECT
  location                        AS Country,
  ReportDate                      AS Peak_Death_Date,
  new_deaths                      AS Peak_Death_Count,
  ROUND(100.0 * People_Vaccinated       / population, 2) AS Pct_At_Least_One_Dose,
  ROUND(100.0 * People_Fully_Vaccinated / population, 2) AS Pct_Fully_Vaccinated,
  ROUND(100.0 * Cumulative_Deaths / population, 2)       AS Pct_Died_To_Date,
  ROUND(100.0 * Cumulative_Cases  / population, 2)       AS Pct_Cases_To_Date,
  ROUND(
    100.0 * Cumulative_Deaths
    / NULLIF(Cumulative_Cases, 0)
  , 2)                                                     AS Case_Fatality_Ratio_Pct
FROM peak
WHERE rn = 1
ORDER BY location;

-- ======================================================================
-- 13. Query: 7-Day Rolling Average of Cases & Deaths per 100 k (G7)
--   Purpose: Normalize COVID-19 incidence and mortality across G7  
--            by computing a 7-day moving average per 100 000 population.
-- ======================================================================
SELECT
  cd.location,
  cd.[date]                   AS RecordDate,

  /* 7-day moving average of new cases, per 100 k population */
  ROUND(
    AVG(100000.0 * cd.new_cases / cd.population)
      OVER (
        PARTITION BY cd.location        -- each country separately
        ORDER BY cd.[date]              -- ordered by date
        ROWS BETWEEN 6 PRECEDING        -- include current + previous 6 days
             AND CURRENT ROW
      )
  , 2)                            AS avg7_cases_per_100k,

  /* 7-day moving average of new deaths, per 100 k population */
  ROUND(
    AVG(100000.0 * cd.new_deaths / cd.population)
      OVER (
        PARTITION BY cd.location
        ORDER BY cd.[date]
        ROWS BETWEEN 6 PRECEDING
             AND CURRENT ROW
      )
  , 2)                            AS avg7_deaths_per_100k

FROM CovidProject..[COVID-DEATHS] AS cd
WHERE
  cd.continent IS NOT NULL       -- only country-level data
  AND cd.location IN (           -- restrict to G7 members
    'Canada',
    'United States',
    'United Kingdom',
    'France',
    'Germany',
    'Italy',
    'Japan'
  )
ORDER BY
  cd.location,
  cd.[date];

-- ================================================================
-- 14. Query: Vaccination Milestone Dates (25%, 50%, 75%) (G7)
--   Purpose: Identify when each G7 country first reached key
--            vaccination thresholds (25%, 50%, 75% of population).
-- ================================================================
;WITH vax AS (
  SELECT
    p.location,
    p.ReportDate,
    p.population,
    /* clean & convert cumulative people_vaccinated */
    CAST(
      REPLACE(p.people_vaccinated, ',', '')
      AS BIGINT
    ) AS pv
  FROM dbo.PercentPopulationVac AS p
  WHERE p.location IN (
    'Canada',
    'United States',
    'United Kingdom',
    'France',
    'Germany',
    'Italy',
    'Japan'
  )
)
SELECT
  v.location,

  /* milestone dates when vaccinated share crossed each threshold */
  MIN(CASE WHEN pv >= population * 0.25 THEN ReportDate END)
    AS date_25pct,
  MIN(CASE WHEN pv >= population * 0.50 THEN ReportDate END)
    AS date_50pct,
  MIN(CASE WHEN pv >= population * 0.75 THEN ReportDate END)
    AS date_75pct
FROM vax AS v
GROUP BY
  v.location
ORDER BY
  date_50pct;  -- sort by the 50% milestone to compare rollout speed
