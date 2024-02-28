SET NOCOUNT ON;
DECLARE @startdate date, @lastdate date, @lastYear date, @priorstart date, @priorlast date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @lastdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)
set @priorstart = CAST(DATEADD(MONTH, -1, @startdate) as date)
set @priorlast = CAST(DATEADD(MONTH, -1, @lastdate) as date)


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
),sealant_candidate AS (
	SELECT DISTINCT
		chart.PATID
	FROM 
		DDB_PROC_LOG_BASE chart
		JOIN DDB_PROC_CODE_BASE cp ON chart.PROC_CODEID = cp.PROC_CODEID
	WHERE 
		chart.CHART_STATUS = 102
		AND (CONVERT(date, chart.PLDATE) BETWEEN @priorstart AND @lastdate)
		AND (cp.ADACODE IN ('C9017'))
		AND HISTORY = 0
),sealant_placed AS (
	SELECT DISTINCT
		chart.PATID,
		FORMAT(PLDATE, 'MM/dd/yyyy') AS dos,
		CONCAT(phys.NAME_LAST, ', ', phys.NAME_FIRST) AS Provider
	FROM 
		DDB_PROC_LOG_BASE chart
		JOIN DDB_PROC_CODE_BASE cp ON chart.PROC_CODEID = cp.PROC_CODEID
		JOIN activeProvider phys ON chart.PROVID = phys.URSCID
	WHERE 
		chart.CHART_STATUS = 102
		AND (CONVERT(date, chart.PLDATE) BETWEEN @priorstart AND @lastdate)
		AND (cp.ADACODE IN ('D1351'))
		AND HISTORY = 0
),carries_risk AS (
	SELECT DISTINCT
		chart.PATID,
		p.PatExtID,
		p.PATACCOUNTNUMBER,
		IIF(sp.PATID IS NULL, CONCAT(phys.NAME_LAST, ', ', phys.NAME_FIRST), sp.Provider) AS Provider,
		short_name,
		p.age,
		FORMAT(PLDATE, 'MM/dd/yyyy') AS dos,
		sp.dos AS [Sealant Date]
	FROM 
		DDB_PROC_LOG_BASE chart
		JOIN (SELECT * FROM activePatients WHERE rn = 1) p ON chart.PATID = p.PATID
		JOIN DDB_PROC_CODE_BASE cp ON chart.PROC_CODEID = cp.PROC_CODEID
		JOIN activeProvider phys ON chart.PROVID = phys.URSCID
		JOIN department dept ON chart.ClinicAppliedTo = dept.URSCID
		LEFT JOIN sealant_placed sp ON chart.PATID = sp.PATID
	WHERE 
		chart.CHART_STATUS = 102
		AND (CONVERT(date, chart.PLDATE) BETWEEN @priorstart AND @priorlast)
		AND (cp.ADACODE IN ('D0601', 'D0602', 'D0603'))
		AND HISTORY = 0
		AND (age BETWEEN 6 AND 9)
		AND chart.PATID IN (SELECT sc.PATID FROM sealant_candidate sc)
)
SELECT 
	Provider,
	short_name AS Clinic,
	PATACCOUNTNUMBER AS [Patient ID],
	age AS Age,
	dos AS [Mod to High Risk Assessed],
	ISNULL([Sealant Date], '') AS [Sealant Date],
	IIF([Sealant Date] IS NULL, 'N', 'Y') AS [Sealant Placed]
FROM carries_risk
ORDER BY
	Provider, [Patient ID]