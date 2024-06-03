--1.  a. Which prescriber had the highest total number of claims (totaled over all drugs)? Report the npi and the total number of claims.
SELECT npi, SUM(total_claim_count) AS total_claims
FROM prescription
GROUP BY npi
ORDER BY total_claims DESC
LIMIT 1
;

--    b. Repeat the above, but this time report the nppes_provider_first_name, nppes_provider_last_org_name,  specialty_description, and the total number of claims.
WITH top_claim AS (
	SELECT npi, SUM(total_claim_count) AS total_claims
	FROM prescription
	GROUP BY npi
	ORDER BY total_claims DESC
	LIMIT 1)
SELECT nppes_provider_first_name, nppes_provider_last_org_name,  specialty_description, total_claims
FROM top_claim LEFT JOIN prescriber USING(npi)
;



--2.  a. Which specialty had the most total number of claims (totaled over all drugs)?
SELECT specialty_description, SUM(total_claim_count) AS total_claims
FROM prescription INNER JOIN prescriber USING(npi)
GROUP BY specialty_description
ORDER BY total_claims DESC
;

--    b. Which specialty had the most total number of claims for opioids?
SELECT specialty_description, SUM(total_claim_count) AS total_claims
FROM prescription INNER JOIN prescriber USING(npi)
WHERE drug_name IN (
	SELECT drug_name
	FROM drug
	WHERE opioid_drug_flag = 'Y'
)
GROUP BY specialty_description
ORDER BY total_claims DESC
;

--    c. **Challenge Question:** Are there any specialties that appear in the prescriber table that have no associated prescriptions in the prescription table?
SELECT specialty_description, SUM(total_claim_count) AS total_claims
FROM prescription RIGHT JOIN prescriber USING(npi)
GROUP BY specialty_description
HAVING SUM(total_claim_count) IS NULL
;

--    d. **Difficult Bonus:** *Do not attempt until you have solved all other problems!* For each specialty, report the percentage of total claims by that specialty which are for opioids. Which specialties have a high percentage of opioids?
WITH opioid_count AS (
	SELECT specialty_description
		, SUM(total_claim_count) AS opioid_claims
	FROM prescription INNER JOIN prescriber USING(npi)
	WHERE drug_name IN (
		SELECT drug_name
		FROM drug
		WHERE opioid_drug_flag = 'Y')
	GROUP BY specialty_description)
	
SELECT specialty_description
	, opioid_claims
	, SUM(total_claim_count) AS total_claims
	, ROUND(100 * opioid_claims / SUM(total_claim_count),2) AS percent_opioid
FROM prescription INNER JOIN prescriber USING(npi)
	LEFT JOIN opioid_count USING(specialty_description)
GROUP BY specialty_description, opioid_claims
ORDER BY percent_opioid DESC NULLS LAST
;


	
--3.  a. Which drug (generic_name) had the highest total drug cost?
SELECT generic_name
FROM prescription JOIN drug USING (drug_name)
ORDER BY total_drug_cost DESC
;
--or if you meant total, total_drug_cost
SELECT generic_name, SUM(total_drug_cost) AS total_cost
FROM prescription JOIN drug USING (drug_name)
GROUP BY generic_name
ORDER BY total_cost DESC
;

--    b. Which drug (generic_name) has the hightest total cost per day? **Bonus: Round your cost per day column to 2 decimal places. Google ROUND to see how this works.**
SELECT generic_name, ROUND(total_drug_cost / (total_30_day_fill_count * 30), 2) AS cost_per_day
FROM prescription LEFT JOIN drug USING(drug_name)
GROUP BY generic_name
ORDER BY cost_per_day DESC
LIMIT 10
;



--4.  a. For each drug in the drug table, return the drug name and then a column named 'drug_type' which says 'opioid' for drugs which have opioid_drug_flag = 'Y', says 'antibiotic' for those drugs which have antibiotic_drug_flag = 'Y', and says 'neither' for all other drugs. **Hint:** You may want to use a CASE expression for this. See https://www.postgresqltutorial.com/postgresql-tutorial/postgresql-case/ 
SELECT drug_name, CASE WHEN opioid_drug_flag = 'Y' THEN 'opioid'
					   WHEN antibiotic_drug_flag = 'Y' THEN 'antibiotic'
					   ELSE 'neither' END AS drug_type
FROM drug
;

--    b. Building off of the query you wrote for part a, determine whether more was spent (total_drug_cost) on opioids or on antibiotics. Hint: Format the total costs as MONEY for easier comparision.
WITH drug_types AS (
	SELECT drug_name, CASE WHEN opioid_drug_flag = 'Y' THEN 'opioid'
						   WHEN antibiotic_drug_flag = 'Y' THEN 'antibiotic'
						   ELSE 'neither' END AS drug_type
	FROM drug)
SELECT drug_type, SUM(total_drug_cost)::money AS total_spent
FROM drug_types INNER JOIN prescription USING(drug_name)
GROUP BY drug_type
ORDER BY total_spent DESC
;



--5.  a. How many CBSAs are in Tennessee? **Warning:** The cbsa table contains information for all states, not just Tennessee.
SELECT DISTINCT cbsaname
FROM cbsa
WHERE cbsaname LIKE '%TN%'
;

--    b. Which cbsa has the largest combined population? Which has the smallest? Report the CBSA name and total population.
SELECT cbsaname, SUM(population) AS cbsa_pop
FROM cbsa LEFT JOIN fips_county USING(fipscounty)
		  LEFT JOIN population USING(fipscounty)
WHERE state = 'TN'
GROUP BY cbsaname
ORDER BY cbsa_pop DESC NULLS LAST
;

--    c. What is the largest (in terms of population) county which is not included in a CBSA? Report the county name and population.
SELECT county, SUM(population) AS total_pop
FROM fips_county LEFT JOIN population USING(fipscounty)
WHERE fipscounty NOT IN (SELECT fipscounty FROM cbsa)
GROUP BY county
ORDER BY total_pop DESC NULLS LAST
;



--6.  a. Find all rows in the prescription table where total_claims is at least 3000. Report the drug_name and the total_claim_count.
SELECT drug_name, total_claim_count
FROM prescription
WHERE total_claim_count >= 3000
;

--    b. For each instance that you found in part a, add a column that indicates whether the drug is an opioid.
SELECT drug_name
	, total_claim_count
	, CASE WHEN drug_name IN (SELECT drug_name FROM drug WHERE opioid_drug_flag = 'Y')
				THEN 'true'
		   ELSE 'false'
		   END AS opioid_tf
FROM prescription
WHERE total_claim_count >= 3000
;

--    c. Add another column to you answer from the previous part which gives the prescriber first and last name associated with each row.
SELECT drug_name
	, total_claim_count
	, CASE WHEN drug_name IN (SELECT drug_name FROM drug WHERE opioid_drug_flag = 'Y')
				THEN 'true'
		   ELSE 'false'
		   END AS opioid_tf
	, CONCAT(nppes_provider_last_org_name, ', ', nppes_provider_first_name)
FROM prescription LEFT JOIN prescriber USING(npi)
WHERE total_claim_count >= 3000
;



--7. The goal of this exercise is to generate a full list of all pain management specialists in Nashville and the number of claims they had for each opioid. **Hint:** The results from all 3 parts will have 637 rows.
--    a. First, create a list of all npi/drug_name combinations for pain management specialists (specialty_description = 'Pain Management') in the city of Nashville (nppes_provider_city = 'NASHVILLE'), where the drug is an opioid (opiod_drug_flag = 'Y'). **Warning:** Double-check your query before running it. You will only need to use the prescriber and drug tables since you don't need the claims numbers yet.
SELECT npi, drug_name
FROM prescriber CROSS JOIN drug
WHERE specialty_description = 'Pain Management'
	AND nppes_provider_city = 'NASHVILLE'
	AND opioid_drug_flag = 'Y'
;

--    b. Next, report the number of claims per drug per prescriber. Be sure to include all combinations, whether or not the prescriber had any claims. You should report the npi, the drug name, and the number of claims (total_claim_count).
--    c. Finally, if you have not done so already, fill in any missing values for total_claim_count with 0. Hint - Google the COALESCE function.
WITH tn_pm_list AS (
	SELECT npi, drug_name
	FROM prescriber CROSS JOIN drug
	WHERE specialty_description = 'Pain Management'
		AND nppes_provider_city = 'NASHVILLE'
		AND opioid_drug_flag = 'Y')
SELECT npi, drug_name, COALESCE(total_claim_count,0) AS total_claims
FROM tn_pm_list LEFT JOIN prescription USING(npi, drug_name)
ORDER BY total_claims DESC
;

-- IF multiple rows in prescription match both npi and drug_name, this would not be accurate. The queries below check that each combination of npi and drug_name are unique. Since they return the same number of rows, each npi, drug combo is unique.
SELECT npi, drug_name
FROM prescription
GROUP BY npi, drug_name
;

SELECT npi, drug_name 
	, SUM(total_claim_count) AS total_claims
FROM prescription
GROUP BY npi, drug_name
ORDER BY total_claims DESC
;