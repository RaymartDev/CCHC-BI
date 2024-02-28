SET NOCOUNT ON;
declare @startdate date, @lastdate date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date) --MARCH 1 2023
set @lastdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date) --MARCH 31 2023

;WITH exclusions AS (
	SELECT 
		pn.patientprofileid
	FROM
		cchc.pr1_patient_note pn
		JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
	WHERE
		pnc.template_field_id = 15476
		AND CONVERT(date, pn.note_datetime) BETWEEN @startdate AND @lastdate
		AND TRIM(pnc.data_value) IN ('AB/TAB/EAB', 'Decline to state', 'Fetal Demise / Neo. Death', 'Letter sent / Lost to F/U', 'SAB / Miscarriage')
), inclusions AS (
	SELECT 
		pn.patientprofileid
	FROM
		cchc.pr1_patient_note pn
		JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
	WHERE
		pnc.template_field_id = 15085
		AND TRY_CONVERT(date, pnc.data_value) BETWEEN @startdate AND @lastdate
),denominator AS (
	SELECT DISTINCT
		p.PATIENTID,
		pn.note_datetime,
		dept.short_name,
		phys.provider_name,
		p.PATIENTPROFILEID
	FROM
		cchc.pr1_view_patient p
		JOIN cchc.pr1_patient_note pn ON pn.patientprofileid = p.PATIENTPROFILEID
		JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
		JOIN cchc.pr1_view_all_department dept ON pn.dept_id = dept.departmentid
		JOIN view_activePhys phys ON pn.doctorid = phys.doctorid
	WHERE
		pnc.template_field_id IN (15127,15141,15142)
		AND TRIM(pnc.data_value) NOT IN ('.', '..','...','')
		AND CONVERT(date, pn.note_datetime) BETWEEN @startdate AND @lastdate
		AND p.PATIENTPROFILEID NOT IN (SELECT t2.patientprofileid FROM exclusions t2)
		AND p.PATIENTPROFILEID IN (SELECT t2.patientprofileid FROM inclusions t2)
), clean AS (
SELECT 
	short_name AS Clinic,
	provider_name AS Provider,
	PATIENTID AS [Patient ID],
	dbo.getDataValueExact(PATIENTPROFILEID, CONVERT(DATE, note_datetime), 15085) AS DOS,
	dbo.getDataValueExact(PATIENTPROFILEID, CONVERT(DATE, note_datetime), 15127) AS first,
	dbo.getDataValueExact(PATIENTPROFILEID, CONVERT(DATE, note_datetime), 15141) AS second,
	dbo.getDataValueExact(PATIENTPROFILEID, CONVERT(DATE, note_datetime), 15142) AS third,
	ROW_NUMBER() OVER(PARTITION BY PATIENTPROFILEID ORDER BY note_datetime DESC) AS rn
FROM denominator
)
SELECT 
	Clinic,
	Provider,
	[Patient ID],
	DOS,
	CASE 
		WHEN first IS NOT NULL THEN UPPER(first)
		WHEN second IS NOT NULL THEN UPPER(second)
		WHEN third IS NOT NULL THEN UPPER(third)
	END AS Description,
	CASE 
		WHEN first IS NOT NULL THEN IIF(first LIKE 'very low%', 1, 0)
		WHEN second IS NOT NULL THEN IIF(second LIKE 'very low%', 1, 0)
		WHEN third IS NOT NULL THEN IIF(third LIKE 'very low%', 1, 0)
	END AS [<1500g],
	CASE 
		WHEN first IS NOT NULL THEN IIF(first LIKE 'low%', 1, 0)
		WHEN second IS NOT NULL THEN IIF(second LIKE 'low%', 1, 0)
		WHEN third IS NOT NULL THEN IIF(third LIKE 'low%', 1, 0)
	END AS [1501g TO 2500g],
	CASE 
		WHEN first IS NOT NULL THEN IIF(first LIKE 'normal%', 1, 0)
		WHEN second IS NOT NULL THEN IIF(second LIKE 'normal%', 1, 0)
		WHEN third IS NOT NULL THEN IIF(third LIKE 'normal%', 1, 0)
	END AS [>2500g]
FROM clean
WHERE 
	rn = 1
ORDER BY Provider, [Patient ID]