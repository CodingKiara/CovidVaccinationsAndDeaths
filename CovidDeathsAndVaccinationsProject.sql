-- COVID deaths and vaccinations


-- Looking at the total cases vs total deaths
-- shows liklihood of dying if you contract covid in the USA
SELECT location, date, total_cases, total_deaths, (CAST(total_deaths as numeric))/ CAST(total_cases as numeric)*100 as deathpercentage
FROM Deaths
WHERE location like '%states%'
ORDER BY 1,2


-- Looking at total cases vs the population
-- Shows what percent of the population contracted covid
SELECT location, date, total_cases, population, (CAST(total_cases as numeric))/ CAST(population as numeric)*100 as Percent_contracted
FROM Deaths
WHERE location like '%states%'
ORDER BY 1,2


-- Looking at countries with highest infection rate compared to population
SELECT location, population, MAX(total_cases) as highest_infection_count, MAX(total_cases) / population * 100 as Percent_Contracted
FROM Deaths
WHERE continent is not null
GROUP BY Population, location
ORDER BY Percent_Contracted desc


-- CONTINENT BREAKDOWN
SELECT location, MAX(CAST(total_deaths as int)) as total_death_count
FROM Deaths
WHERE continent is null
AND location not like '%income%'
AND location not like '%union%'
GROUP BY location
ORDER BY total_death_count desc



-- Showing countries with the highest death count per population
SELECT location, population, MAX(CAST(total_deaths as int)) as total_death_count
FROM Deaths
WHERE continent is not null
GROUP BY Population, location
ORDER BY total_death_count desc


-- GLOBAL NUMBERS

SELECT SUM(new_cases) as total_cases, SUM(new_deaths) as total_deaths, SUM(new_deaths) / SUM(new_cases) * 100 as DeathPercentage
FROM Deaths
--WHERE location like '%states%'
WHERE continent is not null 
AND new_cases <> 0
-- GROUP BY date
ORDER BY 1,2



-- Looking at total population vs vaccinations

SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.location ORDER BY dea.location, dea.date) as rolling_people_vaccinated
FROM Deaths dea
JOIN Vaccinations vac
	ON dea.location = vac.location 
	AND dea.date = vac.date
WHERE dea.continent is not null  
ORDER BY 2,3


-- USING CTE

WITH PopvsVac (Continent, location, date, population, new_vaccinations, rolling_people_vaccinated)
as 
(
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.location ORDER BY dea.location, dea.date) as rolling_people_vaccinated
FROM Deaths dea
JOIN Vaccinations vac
	ON dea.location = vac.location 
	AND dea.date = vac.date
WHERE dea.continent is not null  
--ORDER BY 2,3
)

SELECT *, (rolling_people_vaccinated/population) * 100 as percent_pop_vaccinated
FROM PopvsVac


-- TEMP TABLE

DROP TABLE IF EXISTS #PercentPopulationVaccinated
CREATE TABLE #PercentPopulationVaccinated
(
continent nvarchar(255),
location nvarchar(255),
date datetime,
population numeric,
new_vaccinations numeric,
rolling_people_vaccinated numeric
)

INSERT INTO #PercentPopulationVaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.location ORDER BY dea.location, dea.date) as rolling_people_vaccinated
FROM Deaths dea
JOIN Vaccinations vac
	ON dea.location = vac.location 
	AND dea.date = vac.date
WHERE dea.continent is not null  
--ORDER BY 2,3

SELECT *, (rolling_people_vaccinated/population) * 100 as percent_pop_vaccinated
FROM #PercentPopulationVaccinated



-- creating view to store data for later visualizations: rolling people vaccinated

CREATE VIEW PercentPopulationVaccinated as
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.location ORDER BY dea.location, dea.date) as rolling_people_vaccinated
FROM Deaths dea
JOIN Vaccinations vac
	ON dea.location = vac.location 
	AND dea.date = vac.date
WHERE dea.continent is not null  
--ORDER BY 2,3


SELECT *
FROM PercentPopulationVaccinated

-- creating view to store data for later visualizations: global covid deaths
CREATE VIEW world_total_cases_and_deaths as
SELECT SUM(new_cases) as total_cases, SUM(new_deaths) as total_deaths, SUM(new_deaths) / SUM(new_cases) * 100 as DeathPercentage
FROM Deaths
--WHERE location like '%states%'
WHERE continent is not null 
AND new_cases <> 0
-- GROUP BY date
--ORDER BY 1,2
GO

-- creating view to store data for later visualizations: continent breakdown 
CREATE VIEW continent_breakdown_of_deaths as
SELECT location, MAX(CAST(total_deaths as int)) as total_death_count
FROM Deaths
WHERE continent is null
AND location not like '%income%'
AND location not like '%union%'
GROUP BY location
--ORDER BY total_death_count desc
GO


-- death percentage in america AFTER hitting 50% vaccinated population versus before-- lives saved???

SELECT SUM(dea.new_cases) as total_cases, SUM(dea.new_deaths) as total_deaths, SUM(new_deaths) / SUM(new_cases) * 100 as DeathPercentage
INTO Post50PercentVaccinatedStats_USA
FROM Deaths dea
	JOIN Vaccinations vac ON dea.location = vac.location 
	AND dea.date = vac.date
WHERE dea.location like '%states%'
AND dea.continent is not null 
AND vac.total_vaccinations > (dea.population / 2)
ORDER BY 1,2

SELECT SUM(dea.new_cases) as total_cases, SUM(dea.new_deaths) as total_deaths, SUM(new_deaths) / SUM(new_cases) * 100 as DeathPercentage
INTO Pre50PercentVaccinatedStats_USA
FROM Deaths dea
	JOIN Vaccinations vac ON dea.location = vac.location 
	AND dea.date = vac.date
WHERE dea.location like '%states%'
AND dea.continent is not null 
AND vac.total_vaccinations <= (dea.population / 2)
ORDER BY 1,2

-- SHOWING PRE AND POST 50% VACCINATION DEATH RATES (USA)
-- creating view to store data for later visualizations: death rates pre and post 50% vaccinated populace

CREATE VIEW MajorityVaccinatedDeathsVersusBefore as
SELECT *
FROM Pre50PercentVaccinatedStats_USA
UNION ALL
SELECT *
FROM Post50PercentVaccinatedStats_USA
GO

-- A guess at how many lives may have been saved by a majority vaccinated populace:
-- creating view to store data for later visualizations: extrapolating pre majority vaccinated populace death rates to determine potential deaths had COVID been allowed to continue

CREATE VIEW PotentialLivesSaved as
SELECT total_cases as total_cases_post_majority_vaccinated_populace, .175 * post.total_cases as potential_total_deaths, total_deaths as actual_total_deaths, (.175 * post.total_cases) - post.total_deaths as potential_lives_saved
FROM Post50PercentVaccinatedStats_USA post
GO

-- note: This is a linear view of how COVID deaths could have continued, and that is not the most accurate approach.

