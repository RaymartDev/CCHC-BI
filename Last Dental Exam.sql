SET NOCOUNT ON;
DECLARE @startdate date, @lastdate date, @lastYear date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @lastdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)
set @lastYear = CAST(DATEADD(YEAR, -1, @lastdate) as date)

;WITH pncData AS (
	SELECT
		pn.patientprofileid,
		pnc.data_value,
		ROW_NUMBER() OVER(PARTITION BY pn.patientprofileid ORDER BY CONVERT(date, pnc.data_value) DESC) AS rn
	FROM
		cchc.pr1_patient_note pn
		JOIN cchc.pr1_view_patient p ON p.PATIENTPROFILEID = pn.patientprofileid AND p.ageMonth >= 12 AND p.age <= 5
		JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id AND pnc.template_field_id = 9273
	WHERE
		TRY_CONVERT(date, pnc.data_value) BETWEEN @lastYear AND @lastdate
), detail AS (
SELECT 
	p.PATIENTID,
	FORMAT(pn.note_datetime, 'MM/dd/yyyy') AS DOS,
	dept.short_name AS Clinic,
	phys.provider_name,
	p.age AS Age,
	ageMonth AS [Age In Month],
	pncD.data_value,
	ROW_NUMBER() OVER(PARTITION BY p.PATIENTPROFILEID ORDER BY pn.note_datetime DESC) AS rn
FROM 
	cchc.view_medical_note_full pn
	JOIN cchc.pr1_view_patient p ON p.PATIENTPROFILEID = pn.patientprofileid AND p.ageMonth >= 12 AND p.age <= 5
	JOIN cchc.pr1_view_all_department dept ON pn.dept_id = dept.departmentid
	JOIN view_activePhys phys ON pn.doctorid = phys.doctorid
	LEFT JOIN (SELECT * FROM pncData WHERE rn = 1) pncD ON pn.patientprofileid = pncD.patientprofileid
WHERE
	CONVERT(date, pn.note_datetime) BETWEEN @startdate AND @lastdate
)
SELECT
	provider_name AS Provider,
	Clinic,
	PATIENTID AS [Patient ID],
	Age,
	[Age In Month],
	DOS AS [Last Visit Date],
	ISNULL(data_value, '') AS [Last Dental Exam],
	IIF(data_value IS NULL, 'N', 'Y') AS [Exam in Last 12 Months]
FROM
	(SELECT * FROM detail WHERE rn = 1) detail
ORDER BY 
	Provider,
	Clinic,
	[Patient ID]