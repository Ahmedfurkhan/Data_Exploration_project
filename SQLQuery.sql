/*
Covid 19 Data Exploration  

Skills used: Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views, Converting Data Types

*/

Select *
From [Ahmed sql project]..CovidDeaths$
Where continent is not null 
order by 3,4


-- Select Data that we are going to be starting with

Select Location, date, total_cases, new_cases, total_deaths, population
From [Ahmed sql project]..CovidDeaths$
Where continent is not null 
order by 1,2


-- Total Cases vs Total Deaths
-- Shows likelihood of dying if you contract covid in your country

Select Location, date, total_cases,total_deaths, (total_deaths*100/total_cases) as DeathPercentage
From [Ahmed sql project]..CovidDeaths$
Where location like '%states%'
and continent is not null 
order by 1,2


-- Total Cases vs Population
-- Shows what percentage of population infected with Covid

Select Location, date, Population, total_cases,  (total_cases/population)*100 as PercentPopulationInfected
From [Ahmed sql project]..CovidDeaths$
--Where location like '%states%'
order by 1,2


-- Countries with Highest Infection Rate compared to Population

Select Location, Population, MAX(total_cases) as HighestInfectionCount,  Max((total_cases/population))*100 as PercentPopulationInfected
From [Ahmed sql project]..CovidDeaths$
--Where location like '%states%'
Group by Location, Population
order by PercentPopulationInfected desc


-- Countries with Highest Death Count per Population

Select Location, MAX(cast(Total_deaths as int)) as TotalDeathCount
From [Ahmed sql project]..CovidDeaths$
--Where location like '%states%'
Where continent is not null 
Group by Location
order by TotalDeathCount desc



-- BREAKING THINGS DOWN BY CONTINENT

-- Showing contintents with the highest death count per population

Select continent, MAX(cast(Total_deaths as int)) as TotalDeathCount
From [Ahmed sql project]..CovidDeaths$
--Where location like '%states%'
Where continent is not null 
Group by continent
order by TotalDeathCount desc



-- GLOBAL NUMBERS

Select SUM(new_cases) as total_cases, SUM(cast(new_deaths as int)) as total_deaths, SUM(cast(new_deaths as int))/SUM(New_Cases)*100 as DeathPercentage
From [Ahmed sql project]..CovidDeaths$
--Where location like '%states%'
where continent is not null 
--Group By date
order by 1,2



-- Total Population vs Vaccinations
-- Shows Percentage of Population that has recieved at least one Covid Vaccine

SELECT 
    dea.continent, 
    dea.location, 
    dea.date, 
    dea.population, 
    vac.new_vaccinations,
    ISNULL(SUM(CONVERT(BIGINT, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date), 0) AS RollingPeopleVaccinated,
    CASE
        WHEN dea.population = 0 THEN 0  -- To avoid division by zero
        ELSE (ISNULL(SUM(CONVERT(BIGINT, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date), 0) * 100.0) / dea.population
    END AS RollingVaccinationPercentage
FROM [Ahmed sql project]..CovidDeaths$ dea
JOIN [Ahmed sql project]..CovidVacinations$ vac
    ON dea.location = vac.location
    AND dea.date = vac.date
WHERE dea.continent IS NOT NULL 
ORDER BY dea.location, dea.date;


-- Using CTE to perform Calculation on Partition By in previous query

WITH PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
AS
(
    SELECT 
        dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
        SUM(CONVERT(BIGINT, vac.new_vaccinations)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) as RollingPeopleVaccinated
    FROM [Ahmed sql project]..CovidDeaths$ dea
    JOIN [Ahmed sql project]..CovidVacinations$ vac
	    ON dea.location = vac.location
	    AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL 
)

SELECT 
    *,
    CASE
        WHEN Population = 0 THEN 0  -- To avoid division by zero
        ELSE (RollingPeopleVaccinated * 100.0) / Population
    END AS VaccinationPercentage
FROM PopvsVac;


-- Using Temp Table to perform Calculation on Partition By in previous query

DROP TABLE IF EXISTS #PercentPopulationVaccinated;

CREATE TABLE #PercentPopulationVaccinated (
    Continent NVARCHAR(255),
    Location NVARCHAR(255),
    Date DATETIME,
    Population NUMERIC,
    New_vaccinations NUMERIC,
    RollingPeopleVaccinated NUMERIC
);

INSERT INTO #PercentPopulationVaccinated
SELECT 
    dea.continent, 
    dea.location, 
    dea.date, 
    dea.population, 
    vac.new_vaccinations,
    SUM(CONVERT(BIGINT, vac.new_vaccinations)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS RollingPeopleVaccinated
FROM [Ahmed sql project]..CovidDeaths$ dea
JOIN [Ahmed sql project]..CovidVacinations$ vac
	ON dea.location = vac.location
	AND dea.date = vac.date;

SELECT 
    *,
    CASE
        WHEN Population = 0 THEN 0  -- To avoid division by zero
        ELSE (RollingPeopleVaccinated * 100.0) / Population
    END AS VaccinationPercentage
FROM #PercentPopulationVaccinated;


-- Creating View to store data for later visualizations

CREATE VIEW PercentPopulationVaccinated AS
WITH CTE AS (
    SELECT 
        dea.continent, 
        dea.location, 
        dea.date, 
        dea.population, 
        vac.new_vaccinations,
        SUM(CONVERT(BIGINT, COALESCE(vac.new_vaccinations, 0))) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) as RollingPeopleVaccinated
    FROM [Ahmed sql project]..CovidDeaths$ dea
    JOIN [Ahmed sql project]..CovidVacinations$ vac
        ON dea.location = vac.location
        AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL
)
SELECT
    continent,
    location,
    date,
    population,
    new_vaccinations,
    RollingPeopleVaccinated,
    CASE
        WHEN population = 0 THEN 0  -- Handle division by zero
        ELSE (1.0 * RollingPeopleVaccinated / population) * 100.0
    END AS VaccinationPercentage
FROM CTE;


Select *
From PercentPopulationVaccinated where PercentPopulationVaccinated.continent is not null

