SET NOCOUNT ON;
declare @startdate date, @lastdate date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @lastdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)

;WITH activePatients AS (
	SELECT
		PATIENTID,
		PATIENTPROFILEID,
		age,
		BIRTHDATE
	FROM
		cchc.pr1_view_patient 
	WHERE 
		rn = 1
), acog_notes AS (
	SELECT
		pn.patientprofileid,
		pn.note_datetime,
		dept.short_name,
		phys.provider_name
	FROM
		cchc.pr1_patient_note pn
		JOIN cchc.pr1_template pt ON pn.template_id = pt.template_id
		JOIN cchc.pr1_view_all_department dept ON pn.dept_id = dept.departmentid
		JOIN view_activePhys phys ON pn.doctorid = phys.doctorid
	WHERE
		(CONVERT(date, pn.note_datetime) BETWEEN @startdate AND @lastdate)
		AND pt.template_name LIKE '%initial acog%'
), raw_detail AS (
	SELECT
		p.PATIENTPROFILEID,
		p.PATIENTID,
		acn.provider_name,
		acn.short_name,
		FORMAT(acn.note_datetime, 'MM/dd/yyyy') AS DOS,
		ROW_NUMBER() OVER(PARTITION BY p.PATIENTPROFILEID ORDER BY acn.note_datetime DESC) AS rn
	FROM
		activePatients p
		JOIN acog_notes acn ON acn.patientprofileid = p.PATIENTPROFILEID
), first_t AS (
	SELECT 
		pn.patientprofileid,
		pn.note_datetime,
		pnc.data_value,
		ROW_NUMBER() OVER(PARTITION BY pn.patientprofileid ORDER BY pn.note_datetime DESC) AS rn
	FROM
		cchc.pr1_patient_note pn 
		JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
		JOIN cchc.pr1_template pt ON pn.template_id = pt.template_id
	WHERE
		(CONVERT(date, pn.note_datetime) BETWEEN @startdate AND @lastdate)
		AND TRIM(pnc.data_value) NOT IN ('...', '..', '.','')
		AND TRY_CONVERT(INT, pnc.data_value) IS NOT NULL
		AND pt.template_name LIKE '%initial acog%'
		AND pnc.template_field_id = 15095
), second_t AS (
	SELECT 
		pn.patientprofileid,
		pn.note_datetime,
		pnc.data_value,
		ROW_NUMBER() OVER(PARTITION BY pn.patientprofileid ORDER BY pn.note_datetime DESC) AS rn
	FROM
		cchc.pr1_patient_note pn 
		JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
		JOIN cchc.pr1_template pt ON pn.template_id = pt.template_id
	WHERE
		(CONVERT(date, pn.note_datetime) BETWEEN @startdate AND @lastdate)
		AND TRIM(pnc.data_value) NOT IN ('...', '..', '.','')
		AND TRY_CONVERT(INT, pnc.data_value) IS NOT NULL
		AND pt.template_name LIKE '%initial acog%'
		AND pnc.template_field_id = 15096
), third_t AS (
	SELECT 
		pn.patientprofileid,
		pn.note_datetime,
		pnc.data_value,
		ROW_NUMBER() OVER(PARTITION BY pn.patientprofileid ORDER BY pn.note_datetime DESC) AS rn
	FROM
		cchc.pr1_patient_note pn 
		JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
		JOIN cchc.pr1_template pt ON pn.template_id = pt.template_id
	WHERE
		(CONVERT(date, pn.note_datetime) BETWEEN @startdate AND @lastdate)
		AND TRIM(pnc.data_value) NOT IN ('...', '..', '.','')
		AND TRY_CONVERT(INT, pnc.data_value) IS NOT NULL
		AND pt.template_name LIKE '%initial acog%'
		AND pnc.template_field_id = 15097
),

detail AS (
SELECT 
	PATIENTID,
	DOS,
	provider_name,
	short_name,
	(SELECT TOP 1 t2.data_value FROM first_t t2 WHERE t2.patientprofileid = rd.PATIENTPROFILEID AND CONVERT(date, t2.note_datetime) = rd.DOS) AS [1T],
	(SELECT TOP 1 t2.data_value FROM second_t t2 WHERE t2.patientprofileid = rd.PATIENTPROFILEID AND CONVERT(date, t2.note_datetime) = rd.DOS) AS [2T],
	(SELECT TOP 1 t2.data_value FROM third_t t2 WHERE t2.patientprofileid = rd.PATIENTPROFILEID AND CONVERT(date, t2.note_datetime) = rd.DOS) AS [3T]
FROM 
	raw_detail rd
WHERE
	rd.rn = 1
)
SELECT
	provider_name AS Provider,
	short_name AS Clinic,
	PATIENTID AS [Patient ID],
	DOS AS [Initial OB Date],
	IIF((ISNULL([1T], '') = '') AND (ISNULL([2T], '') = '') AND (ISNULL([3T], '') = ''),0, 1) AS [PHQ9 Documented],
	CASE
		WHEN [3T] IS NOT NULL THEN [3T]
		WHEN [2T] IS NOT NULL THEN [2T]
		WHEN [1T] IS NOT NULL THEN [1T]
		ELSE ''
	END AS [PHQ9 Score]
FROM detail
ORDER BY Provider, [Patient ID]