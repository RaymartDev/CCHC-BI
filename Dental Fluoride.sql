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
		PatExtID,
		PATDB,
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
),dentalAppt AS (
	SELECT DISTINCT
		chart.PATID,
		chart.PATDB,
		p.PatExtID,
		p.PATACCOUNTNUMBER,
		p.age,
		chart.CHART_STATUS,
		FORMAT(chart.PLDATE, 'MM/dd/yyyy') AS dos,
		p.fullname AS PATNAME,
		short_name AS Clinic,
		cp.ADACODE,
		CONCAT(phys.NAME_LAST, ', ', phys.NAME_FIRST) AS Provider,
		ROW_NUMBER() OVER(PARTITION BY chart.PATID ORDER BY chart.PLDATE DESC) AS rn
	FROM 
		DDB_PROC_LOG_BASE chart
		JOIN (SELECT * FROM activePatients WHERE rn = 1) p ON chart.PATID = p.PATID
		JOIN department dept ON chart.ClinicAppliedTo = dept.URSCID
		JOIN DDB_PROC_CODE_BASE cp ON chart.PROC_CODEID = cp.PROC_CODEID
		JOIN activeProvider phys ON chart.PROVID = phys.URSCID
	WHERE 
		CONVERT(DATE, chart.PLDATE) BETWEEN @startdate AND @lastdate
		AND chart.CHART_STATUS = 102
		AND TRIM(cp.ADACODE) IN ('D0602', 'D0603')
		AND HISTORY = 0
		AND p.age BETWEEN 0 AND 5
),numerator AS (
	SELECT DISTINCT
		chart.PATID,
		cp.ADACODE,
		chart.CHART_STATUS,
		ROW_NUMBER() OVER(PARTITION BY chart.PATID ORDER BY chart.PLDATE DESC) AS rn
	FROM 
		DDB_PROC_LOG_BASE chart
		JOIN DDB_PROC_CODE_BASE cp ON chart.PROC_CODEID = cp.PROC_CODEID
	WHERE 
		chart.CHART_STATUS = 102
		AND (CONVERT(date, chart.PLDATE) BETWEEN @startdate AND @lastdate)
		AND (cp.ADACODE IN ('D1206'))
		AND HISTORY = 0
), final AS (
SELECT
	da.Provider,
	da.Clinic,
	da.PATACCOUNTNUMBER AS [Patient ID],
	da.age AS Age,
	da.ADACODE AS [Risk Coded],
	da.dos AS DOS,
	IIF(n.PATID IS NULL, 'N', 'Y') AS [Fluoride Treatment]
FROM
	(SELECT * FROM dentalAppt WHERE rn = 1) da
	LEFT JOIN (SELECT * FROM numerator WHERE rn = 1) n ON da.PATID = n.PATID
)
SELECT * FROM final
ORDER BY Provider, [Patient ID]