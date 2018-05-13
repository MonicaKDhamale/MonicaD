--1. Determine the number of active ads on the site per day (use generate_series).

--Postgres Query:

SELECT c."activedate" as "ActiveDate",COUNT(a."id") as "#ActiveAds"
FROM public."Ads" a
LEFT OUTER JOIN LATERAL 
(SELECT generate_series(MIN("create"),DATE(now()),'1 day') as ActiveDate FROM public."Ads") c
ON true
WHERE c."activedate" >= a."publish" AND  c."activedate" <= a."delete" 
GROUP BY c."activedate"
ORDER BY c."activedate";


--SOL Server Query:
BEGIN

DECLARE @StartDate DATETIME = (SELECT MIN(create)  as SDate FROM dbo.Ads)
DECLARE @EndDate DATETIME = CONVERT(DATE,GETDATE())
;WITH Generate_series_cte
AS
(
    SELECT @StartDate AS [ActiveDate]
    UNION ALL
    SELECT DATEADD(dd, 1, [ActiveDate]) FROM Generate_series_cte 
    WHERE DATEADD(dd, 1, [ActiveDate]) <= @EndDate
)

SELECT [ActiveDate], COUNT(id) as [#ActiveAds]
FROM Generate_series_cte 
CROSS JOIN dbo.Ads 
WHERE [ActiveDate] >= CONVERT(DATE,publish) AND [ActiveDate] <= CONVERT(DATE,delete)
GROUP BY [ActiveDate]
ORDER BY [ActiveDate]
OPTION (MAXRECURSION 0)
END


--2. Determine the YoY growth of Beef Cattle ads in county Tipperary from 2016 to 2017 (use lag).

--Postgres Query:


SELECT * INTO temporary table YearMonth 
FROM (
		SELECT generate_series(cast(MIN(EXTRACT(MONTH FROM "Ads"."publish")) as integer),cast(MAX(EXTRACT(MONTH FROM "Ads"."publish")) as integer),1) as "Month"
		FROM public."Ads" 
		WHERE EXTRACT(year FROM "Ads"."publish") IN (2016,2017)
	) as a
LEFT OUTER JOIN LATERAL 
		(
			SELECT generate_series(cast(MIN(EXTRACT(YEAR FROM "Ads"."publish")) as integer),cast(MAX(EXTRACT(YEAR FROM "Ads"."publish")) as integer),1) as "Year"
			FROM public."Ads" 
			WHERE EXTRACT(year FROM "Ads"."publish") IN (2016,2017)
		) b ON true 
ORDER BY "b"."Year", "a"."Month"


SELECT "Year", "Month",count("a"."id") "TotalAds",
        --,lag(count("a"."id")) OVER( partition by "Month" ORDER BY "Month","Year" ) "PYAds"
	    (CASE 
		 	 WHEN cast(count("a"."id") - lag(count("a"."id")) OVER( partition by "Month" ORDER BY "Month","Year") as integer) IS NULL THEN 0
		     ELSE cast(count("a"."id") - lag(count("a"."id")) OVER( partition by "Month" ORDER BY "Month","Year") as integer)
		 END) "YoY Growth"	
FROM "yearmonth"
LEFT JOIN 
		(
			SELECT "Ads".* FROM public."Ads" 
			LEFT JOIN public."category" ON category."id" = "Ads"."category_id"
			LEFT JOIN public."region" ON region."id" = "Ads"."region_id"
			WHERE category."subsubcategory" = 'Beef Cattle' AND region."county"= 'Tipperary' AND EXTRACT(YEAR FROM "Ads"."publish") IN (2017,2016)
		) a ON EXTRACT(MONTH FROM "a"."publish") = "Month" AND EXTRACT(YEAR FROM "a"."publish") = "Year"
GROUP BY "Month","Year" 
Order BY "Month" ,"Year"

