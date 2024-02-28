SET NOCOUNT ON;
DECLARE @startdate date, @lastdate date, @lastYear date, @priorstart date, @priorlast date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @lastdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)
set @priorstart = CAST(DATEADD(MONTH, -1, @startdate) as date)
set @priorlast = CAST(DATEADD(DAY, -1, @startdate) as date)

;WITH department AS (
	SELECT 
		URSCID,
		CASE
			WHEN RSCID = 'No_Clinic' THEN ''
			WHEN RSCID = 'EAGLEROCK' THEN 'ER'
			WHEN RSCID = 'SUNLAND' THEN 'SL'
			WHEN RSCID = 'CENTRAL' THEN 'CENT'
			WHEN RSCID = 'INACTIVE' THEN RSCID
			WHEN RSCID = 'GLENDALE' THEN 'GL'
			WHEN RSCID IS NULL THEN ''
			ELSE RSCID
		END AS short_name
	FROM DDB_CLINIC_INFO
), activePatients AS (
	SELECT
		PATID,
		PATDB,
		PatExtID,
		PATACCOUNTNUMBER,
		OriginalPatId,
		CONCAT(LASTNAME, ', ', FIRSTNAME) AS fullname,
		DATEDIFF(hour,BIRTHDATE,GETDATE())/8766 AS age,
		ROW_NUMBER() OVER(PARTITION BY PATID ORDER BY DDB_LAST_MOD DESC) AS rn
	FROM 
		DDB_PAT_BASE
	WHERE 
		STATUS=1
		AND (LASTNAME NOT LIKE 'test' OR FIRSTNAME NOT LIKE 'test')
), activeProvider AS (
	SELECT 
		RSCDB,
		URSCID,
		NAME_LAST,
		NAME_FIRST,
		NAME_TITLE,
		ActiveFlag,
		IsNonPerson
	FROM dbo.DDB_RSC_BASE 
	WHERE 
		RSCTYPE=1 
		AND NAME_LAST IS NOT NULL 
		AND NAME_FIRST IS NOT NULL
		AND NAME_LAST <> 'DEF_PROV'
		AND NAME_LAST <> 'Walk-In'
		AND NAME_LAST NOT LIKE 'test'
		AND NAME_FIRST NOT LIKE 'test'
		AND NAME_LAST NOT LIKE 'cchc'
		AND NAME_FIRST NOT LIKE 'cchc'
		AND ActiveFlag = 1 
		AND IsNonPerson = 0
), crown_delivered AS (
	SELECT DISTINCT
		chart.PATID,
		FORMAT(PLDATE, 'MM/dd/yyyy') AS dos
	FROM 
		DDB_PROC_LOG_BASE chart
		JOIN (SELECT * FROM activePatients WHERE rn = 1) p ON chart.PATID = p.PATID
		JOIN DDB_PROC_CODE_BASE cp ON chart.PROC_CODEID = cp.PROC_CODEID
	WHERE 
		chart.CHART_STATUS = 102
		AND (CONVERT(date, chart.PLDATE) BETWEEN @priorstart AND @lastdate)
		AND (cp.ADACODE IN ('D2752', 'D2790', 'D2791', 'D2799'))
		AND HISTORY = 0
), crown_impressions AS (
	SELECT DISTINCT
		chart.PATID,
		p.PatExtID,
		p.PATACCOUNTNUMBER,
		CONCAT(phys.NAME_LAST, ', ', phys.NAME_FIRST) AS Provider,
		short_name,
		p.age,
		FORMAT(PLDATE, 'MM/dd/yyyy') AS dos,
		cd.dos AS Delivered
	FROM 
		DDB_PROC_LOG_BASE chart
		JOIN (SELECT * FROM activePatients WHERE rn = 1) p ON chart.PATID = p.PATID
		JOIN DDB_PROC_CODE_BASE cp ON chart.PROC_CODEID = cp.PROC_CODEID
		JOIN activeProvider phys ON chart.PROVID = phys.URSCID
		JOIN department dept ON chart.ClinicAppliedTo = dept.URSCID
		LEFT JOIN crown_delivered cd ON chart.PATID = cd.PATID
	WHERE 
		chart.CHART_STATUS = 102
		AND (CONVERT(date, chart.PLDATE) BETWEEN @priorstart AND @priorlast)
		AND (cp.ADACODE IN ('C2002'))
		AND HISTORY = 0
)
SELECT 
	Provider,
	short_name AS Clinic,
	PATACCOUNTNUMBER AS [Patient ID],
	dos AS [Impression Taken],
	ISNULL(Delivered, '') AS [Crown Delivered],
	IIF(Delivered IS NOT NULL, 
	IIF(DATEDIFF(DAY, CONVERT(date,dos), CONVERT(date, Delivered)) <= 28, 'Y', 'N')
	, 'N') AS [Within 28 Days]
FROM crown_impressions
ORDER BY Provider, [Patient ID]