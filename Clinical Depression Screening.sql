SET NOCOUNT ON;
declare @start date, @last date, @noteStart date
set @start = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)  
set @last = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)
set @noteStart = CAST(DATEADD(year, -1, @start) as date)

;WITH patientBase AS (
	SELECT * FROM cchc.pr1_view_patient WHERE rn = 1 AND age >= 12
), eligPatients AS (
	SELECT 
		pn.patientprofileid
	FROM 
		cchc.pr1_patient_note pn
		JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
	WHERE 
		(CAST(pn.note_datetime AS DATE) BETWEEN @start and @last)
		AND pnc.template_field_id IN (3696,15095,15096,15097,15423)
),hxDepression AS (
	SELECT 
		ch.patient_id,
		ch.post_fromdate,
		ROW_NUMBER() OVER(PARTITION BY ch.patient_id ORDER BY ch.post_fromdate DESC) AS rn
	FROM 
		cchc.charge_history ch
		JOIN activeDiagnosis cd ON cd.diagnosis_id = ch.diagnosis_id_1 OR cd.diagnosis_id = ch.diagnosis_id_2 OR cd.diagnosis_id = ch.diagnosis_id_3 OR cd.diagnosis_id = ch.diagnosis_id_4
	WHERE
		(CONVERT(date, ch.post_fromdate) BETWEEN @noteStart AND @last)
		AND cd.icd9 BETWEEN 'F30' AND 'F39'
), PHQ9patients AS (
SELECT 
	pn.patientprofileid,
	pn.note_datetime,
	pnc.data_value,
	ROW_NUMBER() OVER(PARTITION BY pn.patientprofileid ORDER BY pn.note_datetime DESC, CONVERT(INT, pnc.data_value) DESC) AS rn
FROM 
	cchc.pr1_patient_note pn
	JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
WHERE
	TRIM(pnc.data_value) <> '' AND TRY_CAST(pnc.data_value AS INT) IS NOT NULL
	AND pnc.template_field_id IN (15095,15096,15097,3696, 15958)
	AND (CONVERT(DATE, pn.note_datetime) BETWEEN @noteStart AND @last)
), PHQ2patients AS (
SELECT 
	pn.patientprofileid,
	pn.note_datetime,
	(CASE 
		WHEN TRY_CAST(LEFT(pnc.data_value, 2) as int) is not null THEN LEFT(pnc.data_value, 2)
		ELSE LEFT(pnc.data_value, 1)
	END) AS data_value,
	ROW_NUMBER() OVER(PARTITION BY pn.patientprofileid ORDER BY pn.note_datetime DESC) AS rn
FROM 
	cchc.pr1_patient_note pn
	JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
WHERE
	TRIM(pnc.data_value) <> ''
	AND pnc.template_field_id IN (15423, 15957, 15815,15816)
	AND (CAST(pn.note_datetime AS DATE) BETWEEN @noteStart and @last)
), Follow_Up AS (
SELECT 
	pn.patientprofileid,
	pn.note_datetime,
	pnc.data_value,
	ROW_NUMBER() OVER(PARTITION BY pn.patientprofileid ORDER BY pn.note_datetime DESC) AS rn
FROM 
	cchc.view_medical_note_full pn
	JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
WHERE
	TRIM(pnc.data_value) <> '' AND TRY_CAST(pnc.data_value AS INT) IS NOT NULL
	AND pnc.template_field_id IN (15143)
	AND (CAST(pn.note_datetime AS DATE) BETWEEN @noteStart and @last)
),filtered_notes AS (
	SELECT 
		pn.patient_note_id
	FROM
		cchc.pr1_patient_note pn
		JOIN view_activePhys phys ON pn.doctorid = phys.doctorid
	WHERE
		CONVERT(date, pn.note_datetime) BETWEEN @start AND @last
		AND (
			(phys.provider_name = 'Ghanevati, Mahin' AND (DATEPART(weekday,pn.note_datetime) = 3 AND DATEPART(hour, pn.note_datetime) > 18))
			AND (phys.provider_name = 'Solarte, David' AND (DATEPART(weekday, pn.note_datetime) IN (3,5) AND DATEPART(hour, pn.note_datetime) > 17 AND DATEPART(MINUTE, pn.note_datetime) >= 30))
			AND (phys.provider_name = 'Cayago, Rachelle' AND (DATEPART(weekday, pn.note_datetime) IN (3,5) AND DATEPART(hour, pn.note_datetime) > 17 AND DATEPART(MINUTE, pn.note_datetime) >= 30))
			AND (phys.provider_name = 'Barraza, Henry' AND (DATEPART(weekday, pn.note_datetime) IN (2,4,5) AND DATEPART(hour, pn.note_datetime) > 19 AND DATEPART(MINUTE, pn.note_datetime) >= 30))
			AND (phys.provider_name = 'Manoukian, Arthur' AND (DATEPART(weekday, pn.note_datetime) IN (2,3,4,5,6) AND DATEPART(hour, pn.note_datetime) > 19))
			AND (phys.provider_name = 'Godes, Irina' AND (DATEPART(weekday, pn.note_datetime) IN (3,4) AND DATEPART(hour, pn.note_datetime) > 19))
			AND (phys.provider_name = 'Michael, Manar' AND (DATEPART(weekday, pn.note_datetime) IN (3,4) AND DATEPART(hour, pn.note_datetime) > 19))
			AND (phys.provider_name = 'Justiniani, Mary' AND (DATEPART(weekday, pn.note_datetime) IN (2,3,4,5,6) AND DATEPART(hour, pn.note_datetime) > 18) AND DATEPART(minute, pn.note_datetime) >= 30)
		)
), medicalNotes AS (
	SELECT 
		phys.provider_name AS Provider,
		dept.short_name AS Clinic,
		p.PATIENTID AS [Patient ID],
		p.age AS Age,
		FORMAT(pn.note_datetime, 'MM/dd/yyyy') AS DOS,
		p.PATIENTPROFILEID,
		ROW_NUMBER() OVER (PARTITION BY p.PATIENTPROFILEID ORDER BY pn.note_datetime DESC) AS rn
	FROM 
		(SELECT * FROM cchc.view_medical_note_full WHERE patient_note_id NOT IN (SELECT t2.patient_note_id FROM filtered_notes t2)) pn
		JOIN patientBase p ON pn.patientprofileid = p.PATIENTPROFILEID
		JOIN eligPatients pt ON pn.patientprofileid = pt.patientprofileid
		JOIN activeMedicalPhys phys ON pn.doctorid = phys.doctorid
		JOIN cchc.pr1_view_all_department dept ON pn.dept_id = dept.departmentid
	WHERE 
		(CAST(pn.note_datetime AS DATE) BETWEEN @start and @last)
		AND phys.provider_name NOT IN ('Galstyan, Kevin')
), final AS (
SELECT 
	mn.PATIENTPROFILEID,
	mn.Provider,
	mn.Clinic,
	mn.[Patient ID],
	mn.Age,
	mn.DOS,
	(CASE
		WHEN Age < 18 THEN phq9.data_value
		WHEN Age >= 18 AND (phq2.data_value IS NULL OR phq2.data_value = '0') THEN (IIF(phq9.data_value IS NOT NULL, phq9.data_value, phq2.data_value))
		WHEN Age >= 18 AND (CONVERT(date, phq2.note_datetime) <= CONVERT(date, phq9.note_datetime)) THEN phq9.data_value
		ELSE phq2.data_value
	END) AS [Last PHQ Score],
	(CASE
		WHEN Age < 18 THEN phq9.data_value
		WHEN Age >= 18 AND (phq2.data_value IS NULL OR phq2.data_value = '0') THEN IIF(phq9.note_datetime IS NULL, phq2.note_datetime, phq9.note_datetime)
		WHEN Age >= 18 AND (CONVERT(date, phq2.note_datetime) <= CONVERT(date, phq9.note_datetime)) THEN phq9.note_datetime
		ELSE phq2.note_datetime
	END) AS [Last Resort],
	TRY_CONVERT(date,dbo.getMedicalValue(mn.PATIENTPROFILEID, @last, 15593)) AS screen1,
	TRY_CONVERT(date,dbo.getMedicalValue(mn.PATIENTPROFILEID, @last, 14765)) AS screen2,
	(SELECT TOP 1 t2.note_datetime FROM cchc.view_medical_note_full t2 WHERE (CONVERT(DATE, t2.note_datetime) BETWEEN @noteStart AND CONVERT(DATE, mn.DOS)) AND t2.template_name like 'phq screen%' AND t2.patientprofileid = mn.PATIENTPROFILEID) AS [Last PHQ Date],
	fu.data_value AS [Follow Up Plan]
FROM 
	medicalNotes mn
	LEFT JOIN (SELECT * FROM PHQ2patients WHERE rn = 1) phq2 ON mn.PATIENTPROFILEID = phq2.patientprofileid
	LEFT JOIN (SELECT * FROM PHQ9patients WHERE rn = 1) phq9 ON mn.PATIENTPROFILEID = phq9.patientprofileid
	LEFT JOIN (SELECT * FROM Follow_Up WHERE rn = 1) fu ON mn.PATIENTPROFILEID = fu.patientprofileid
WHERE 
	(mn.rn = 1) and mn.patientprofileid NOT IN (SELECT patient_id FROM hxDepression)
), clean AS (
SELECT 
	PATIENTPROFILEID,
	Provider,
	Clinic,
	[Patient ID],
	Age,
	DOS,
	IIF([Last PHQ Score] IS NULL, '', [Last PHQ Score]) AS [Last PHQ Score],
	(CASE
		WHEN screen1 BETWEEN @noteStart AND @last THEN FORMAT(screen1, 'MM/dd/yyyy')
		WHEN screen2 BETWEEN @noteStart AND @last THEN FORMAT(screen2, 'MM/dd/yyyy')
		ELSE ''
	END) AS [Last PHQ Date],
	IIF((TRY_CONVERT(date,dbo.getMedicalValue(PATIENTPROFILEID, @last, 15593)) BETWEEN @noteStart and @last OR TRY_CONVERT(date, dbo.getMedicalValue(PATIENTPROFILEID, @last, 14765)) BETWEEN @noteStart AND @last), '1', '0') AS Screened,
	IIF(TRY_CAST([Last PHQ Score] AS INT) > 9, '1', '0') AS [Positive Result],
	IIF([Follow Up Plan] IS NULL, '0', IIF([Follow Up Plan] = '1', '1', '0')) AS [Follow-Up Plan]
FROM final
)
SELECT 
	Provider,
	Clinic,
	[Patient ID],
	Age,
	DOS,
	[Last PHQ Score],
	IIF([Last PHQ Date] IS NULL, '', [Last PHQ Date]) AS [Last PHQ Date],
	CONVERT(int,Screened) AS Screened,
	CONVERT(int, [Positive Result]) AS [Positive Result],
	CONVERT(int,[Follow-Up Plan]) AS [Follow-Up Plan],
	(CASE 
		WHEN Screened = '1' AND([Positive Result] = '1' AND [Follow-Up Plan] = '1') THEN 'Y'
		WHEN Screened = '1' AND([Positive Result] = '0' AND [Follow-Up Plan] = '0') THEN 'Y'
		ELSE 'N'
	END) AS Met,
	dbo.getTelehealthConsent(clean.PATIENTPROFILEID, CONVERT(date, DOS)) AS [Patient Consents to Telehealth Visit],
	dbo.getTelephoneConsent(clean.PATIENTPROFILEID, CONVERT(date, DOS)) AS [Patient Consents to Telephone Visit]
FROM clean
ORDER BY 
	Provider, Clinic, [Patient ID]