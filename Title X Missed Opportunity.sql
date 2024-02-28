SET NOCOUNT ON;
declare @startdate date, @lastdate date, @lastYear date, @yearStart date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @lastdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)
set @lastYear = CAST(DATEADD(YEAR, -1, @startdate) as date)
set @yearStart = CONVERT(date, DATEADD(yy, DATEDIFF(yy, 0, @lastdate), 0))
;WITH activePatients AS (
	SELECT *,DATEDIFF(hour,birth_date,GETDATE())/8766 AS age,ROW_NUMBER() OVER(PARTITION BY patient_id ORDER BY modified_date DESC) AS rn FROM cchc.patient WHERE active_yn = 'Y' and deleted_yn <> 'Y' and company_id = 9
), titleXVisits AS (
	SELECT 
		pn.PATIENTPROFILEID,
		CAST(pn.note_datetime as date) AS DOS
	FROM 
		cchc.pr1_patient_note pn 
		JOIN cchc.pr1_template pt ON pn.template_id = pt.template_id
	WHERE 
		template_name LIKE '%title%'
		AND CONVERT(DATE, pn.note_datetime) BETWEEN @yearStart AND @lastdate
),filter AS (
	SELECT 
		dev_ch.patient_id,
		dev_ch.post_fromdate
	FROM 
		(SELECT * FROM cchc.charge_history WHERE CONVERT(date, post_fromdate) BETWEEN @lastYear AND @lastdate) AS dev_ch 
		INNER JOIN activeDiagnosis AS dev_d ON dev_d.diagnosis_id = dev_ch.diagnosis_id_1 OR dev_d.diagnosis_id = dev_ch.diagnosis_id_2 OR dev_d.diagnosis_id = dev_ch.diagnosis_id_3 OR 
                                                      dev_d.diagnosis_id = dev_ch.diagnosis_id_4
	WHERE dev_d.icd9 IN('Z90.710', 'Z98.51', 'Z98.52', 'Z90.711','Z90.712','Z98.51', 'Z30.2', 'N95.0', 'N95.1', 'N95.2', 'N95.8', 'N95.9')
), charges AS (
	SELECT 
		dev_ch.patient_id,
		dev_ch.post_fromdate
	FROM 
		(SELECT * FROM cchc.charge_history WHERE CONVERT(date, post_fromdate) BETWEEN @lastYear AND @lastdate) AS dev_ch 
		INNER JOIN activeProcedure AS dev_cp ON dev_ch.procedure_id = dev_cp.procedure_id 
		INNER JOIN activeDiagnosis AS dev_d ON dev_d.diagnosis_id = dev_ch.diagnosis_id_1 OR dev_d.diagnosis_id = dev_ch.diagnosis_id_2 OR dev_d.diagnosis_id = dev_ch.diagnosis_id_3 OR 
                                                      dev_d.diagnosis_id = dev_ch.diagnosis_id_4
	WHERE 
		dev_cp.procedure_code IN ('99213', '99203', '11982', '99212', '99448', 'G2012', '99395', 'G0101', '81002', '99202', '58301', '99204', '99214,', '99401', 'J3490', 'J1050', '11976', 
                                                      '99402', '11981', 'J7307', '58300', 'J7298', 'J7296', '99215', '11983', 'J7300', '99000', '99447', '99442', 'S9445', '11200', 'J7301', '99446')
		OR dev_d.icd9 IN ('Z30.011','Z30.013','Z30.014','Z30.015','Z30.016','Z30.017','Z30.018','Z30.019','Z30.012','Z30.02','Z30.09','Z30.430','Z30.432','Z30.433','Z30.2','Z30.40','Z30.41','Z30.431','Z30.44','Z30.45','Z30.46','Z30.49','Z30.42','Z30.8','Z30.9','Z31.0','Z31.7','Z31.89','Z31.41','Z31.42','Z31.49','Z31.430','Z31.438','Z31.440','Z31.441','Z31.448','Z31.61', 'Z31.62','Z31.69','Z31.9','Z98.51','Z98.52','Z31.83','Z31.84','Z31.89','Z31.90','Z97.5')
), kepts AS (
	SELECT
		appt.patientprofileid,
		CAST(appt.booking_date as date) dos,
		appt.doctorid,
		appt.departmentid,
		vt.short_desc,
		vt.description
	FROM 
		cchc.pr1_view_patientappt appt
		JOIN medicalVisitTypes vt ON appt.visit_type_id = vt.visit_type_id
	WHERE 
		(appt.status = 'appt kept')
		AND (CAST(appt.booking_date as date) between @startdate and @lastdate)
), detail AS (
SELECT DISTINCT
	p.patient_id,
	p.patient_number,
	p.birth_date,
	p.sex,
	p.age,
	k.dos,
	k.short_desc,
	dept.short_name,
	phys.provider_name,
	ROW_NUMBER() OVER(PARTITION BY p.patient_id ORDER BY k.dos DESC) AS rn 
FROM
	(
		SELECT 
			* 
		FROM (SELECT * FROM activePatients WHERE rn = 1)  activePatients
		WHERE 
			age between 12 and 50
	) p 
	JOIN kepts k ON k.patientprofileid = p.patient_id
	JOIN cchc.pr1_view_all_department dept ON k.departmentid = dept.departmentid
	JOIN view_activePhys phys ON k.doctorid = phys.doctorid
WHERE 
	(k.dos BETWEEN @startdate and @lastdate)
	AND phys.degree IN('MD', 'PA', 'MS PA-C', 'NP', 'DO')
	AND p.patient_id IN (SELECT c.patient_id FROM charges c)
	AND p.patient_id NOT IN (SELECT f.patient_id FROM filter f)
), bcm AS (
SELECT 
	pn.patientprofileid,
	CONVERT(date, pn.note_datetime) AS DOS,
	pnc.data_value,
	pt.template_name,
	ROW_NUMBER() OVER(PARTITION BY pn.patientprofileid ORDER BY pn.note_datetime DESC) AS rn
FROM 
	cchc.pr1_patient_note pn
	JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
	JOIN cchc.pr1_template pt ON pn.template_id = pt.template_id
WHERE
	pnc.template_field_id IN (7220,9340)
	AND CONVERT(date, pn.note_datetime) BETWEEN @startdate AND @lastdate
	AND pt.template_name NOT LIKE '%title%'
	AND ISNULL(TRIM(data_value), '') NOT IN('', '..', '...', '.')
), titleXbcm AS (
SELECT 
	pn.patientprofileid,
	CONVERT(date, pn.note_datetime) AS DOS,
	pnc.data_value,
	pt.template_name,
	ROW_NUMBER() OVER(PARTITION BY pn.patientprofileid ORDER BY pn.note_datetime DESC) AS rn
FROM 
	cchc.pr1_patient_note pn
	JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
	JOIN cchc.pr1_template pt ON pn.template_id = pt.template_id
WHERE
	pnc.template_field_id = 7220
	AND CONVERT(date, pn.note_datetime) BETWEEN @lastYear AND @lastdate
	AND pt.template_name LIKE '%title%'
	AND ISNULL(TRIM(data_value), '') NOT IN('', '..', '...', '.')
), latestDetail AS (
	SELECT 
		patient_number AS [Patient ID],
		FORMAT(birth_date, 'MM/dd/yyyy') AS [Date of Birth],
		sex AS Gender,
		age AS Age,
		FORMAT(d.dos, 'MM/dd/yyyy') AS DOS,
		short_name AS Clinic,
		provider_name AS Provider,
		IIF((SELECT TOP 1 tx.patientprofileid FROM titleXVisits tx WHERE tx.patientprofileid = d.patient_id) IS NULL, 0, 1) AS Completed,
		short_desc,
		(SELECT TOP 1 tb.data_value FROM titleXbcm tb WHERE tb.patientprofileid = d.patient_id AND tb.DOS <= CONVERT(date, d.dos) ORDER BY tb.DOS DESC) AS [Title X BC],
		(SELECT TOP 1 b.data_value FROM bcm b WHERE b.patientprofileid = d.patient_id AND b.DOS = CONVERT(date, d.dos) ORDER BY b.DOS DESC) AS [Visit BC]
	FROM 
		(SELECT * FROM detail WHERE rn = 1) d
), final AS (
SELECT 
	[Patient ID],
	[Date of Birth],
	Gender,
	Age,
	DOS,
	Clinic,
	Provider,
	Completed,
	IIF(Completed = 0, 1, 0) AS Missed,
	IIF(Completed = 0, 'N', 'Y') AS [Met Goal],
	short_desc AS [Visit Type],
	ISNULL([Title X BC], '') AS [Title X BC],
	ISNULL([Visit BC], '') AS [Visit BC]
FROM latestDetail
)
SELECT * FROM final
ORDER BY Clinic, Provider, [Patient ID]