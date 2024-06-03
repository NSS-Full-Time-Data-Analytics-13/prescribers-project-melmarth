--1. How many npi numbers appear in the prescriber table but not in the prescription table?
SELECT DISTINCT npi
FROM prescriber
EXCEPT
SELECT npi
FROM prescription
;



--2.a. Find the top five drugs (generic_name) prescribed by prescribers with the specialty of Family Practice.
SELECT generic_name
	, SUM(total_claim_count) AS total_claims
FROM prescriber INNER JOIN prescription USING (npi)
				INNER JOIN drug USING (drug_name)
WHERE specialty_description = 'Family Practice'
GROUP BY generic_name
ORDER BY total_claims DESC
LIMIT 5
;

--  b. Find the top five drugs (generic_name) prescribed by prescribers with the specialty of Cardiology.
SELECT generic_name
	, SUM(total_claim_count) AS total_claims
FROM prescriber INNER JOIN prescription USING (npi)
				INNER JOIN drug USING (drug_name)
WHERE specialty_description = 'Cardiology'
GROUP BY generic_name
ORDER BY total_claims DESC
LIMIT 5
;

--  c. Which drugs are in the top five prescribed by Family Practice prescribers and Cardiologists? Combine what you did for parts a and b into a single query to answer this question.
SELECT DISTINCT generic_name
FROM prescriber INNER JOIN prescription USING (npi)
				INNER JOIN drug USING (drug_name)
WHERE generic_name IN(
		SELECT generic_name
		FROM prescriber INNER JOIN prescription USING (npi)
						INNER JOIN drug USING (drug_name)
		WHERE specialty_description = 'Family Practice'
		GROUP BY generic_name
		ORDER BY SUM(total_claim_count) DESC
		LIMIT 5)
	AND generic_name IN(
		SELECT generic_name
		FROM prescriber INNER JOIN prescription USING (npi)
						INNER JOIN drug USING (drug_name)
		WHERE specialty_description = 'Cardiology'
		GROUP BY generic_name
		ORDER BY SUM(total_claim_count) DESC
		LIMIT 5)
;



--3. Your goal in this question is to generate a list of the top prescribers in each of the major metropolitan areas of Tennessee.
--  a. First, write a query that finds the top 5 prescribers in Nashville in terms of the total number of claims (total_claim_count) across all drugs. Report the npi, the total number of claims, and include a column showing the city.
SELECT prescriber.npi, SUM(total_claim_count) AS total_claims, nppes_provider_city AS city
FROM prescription LEFT JOIN prescriber USING(npi)
WHERE nppes_provider_city = 'NASHVILLE'
GROUP BY prescriber.npi, city
ORDER BY total_claims DESC
LIMIT 5
;

--  b. Now, report the same for Memphis.
SELECT prescriber.npi, SUM(total_claim_count) AS total_claims, nppes_provider_city AS city
FROM prescription LEFT JOIN prescriber USING(npi)
WHERE nppes_provider_city = 'MEMPHIS'
GROUP BY prescriber.npi, city
ORDER BY total_claims DESC
LIMIT 5
;

--  c. Combine your results from a and b, along with the results for Knoxville and Chattanooga.
SELECT *
FROM (
	SELECT ranks.npi
		, total_claims
		, city
		, RANK() OVER(PARTITION BY city ORDER BY total_claims DESC) ranking
	FROM (
		SELECT prescriber.npi, SUM(total_claim_count) AS total_claims, nppes_provider_city AS city
		FROM prescription LEFT JOIN prescriber USING(npi)
		WHERE nppes_provider_city IN ('NASHVILLE', 'MEMPHIS', 'KNOXVILLE', 'CHATTANOOGA')
		GROUP BY prescriber.npi, city
		ORDER BY city, total_claims) AS ranks)
WHERE ranking <= 5
;



--4. Find all counties which had an above-average number of overdose deaths. Report the county name and number of overdose deaths.
WITH od_by_county AS (
	SELECT county
		, SUM(overdose_deaths) AS total_od_deaths
	FROM overdose_deaths AS o LEFT JOIN fips_county AS f
		ON o.fipscounty = f.fipscounty::numeric
	GROUP BY county)

SELECT *
FROM od_by_county
WHERE total_od_deaths > (SELECT AVG(total_od_deaths)
						 FROM od_by_county)
ORDER BY total_od_deaths DESC
;



--5.a. Write a query that finds the total population of Tennessee.
SELECT SUM(population) AS tn_pop
FROM fips_county LEFT JOIN population USING(fipscounty)
WHERE state = 'TN'
;

--  b. Build off of the query that you wrote in part a to write a query that returns for each county that county's name, its population, and the percentage of the total population of Tennessee that is contained in that county.
SELECT county, SUM(population)
	, ROUND(100 * SUM(population) / (SELECT SUM(population) AS tn_pop
								FROM fips_county LEFT JOIN population USING(fipscounty)
								WHERE state = 'TN'),2) AS percent_tn_pop
FROM fips_county LEFT JOIN population USING(fipscounty)
WHERE state = 'TN'
GROUP BY county
ORDER BY percent_tn_pop DESC NULLS LAST
;