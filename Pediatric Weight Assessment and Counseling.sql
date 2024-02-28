SET NOCOUNT ON;
DECLARE @startdate date, @lastdate date, @lastYear date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @lastdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)
set @lastYear = CAST(DATEADD(YEAR, -1, @lastdate) as date)

;WITH patientBase AS (
	SELECT 
		p.PATIENTPROFILEID,
		p.PATIENTID,
		p.age,
		p.BIRTHDATE
	FROM
		cchc.pr1_view_patient p
	WHERE
		(age BETWEEN 3 AND 17)
		AND rn = 1
), pregnantPt AS (
	SELECT 
		ch.patient_id,
		ch.post_fromdate
	FROM 
		cchc.charge_history ch
		JOIN (
			SELECT * FROM activeDiagnosis
			WHERE icd9 IN (
				'Z34', 'Z34.0', 'Z34.00', 'Z34.01', 'Z34.02', 'Z34.03', 'Z34.8', 'Z34.80', 'Z34.81', 'Z34.82',
				'Z34.83', 'Z34.9', 'Z34.90', 'Z34.91', 'Z34.92', 'Z34.93'
			)
		) cd ON ch.diagnosis_id_1 = cd.diagnosis_id OR ch.diagnosis_id_2 = cd.diagnosis_id OR ch.diagnosis_id_3 = cd.diagnosis_id OR ch.diagnosis_id_4 = cd.diagnosis_id
	WHERE 
		CONVERT(DATE, ch.post_fromdate) BETWEEN @lastYear AND @lastdate
),filtered_notes AS (
	SELECT 
		pn.patient_note_id
	FROM
		cchc.pr1_patient_note pn
		JOIN view_activePhys phys ON pn.doctorid = phys.doctorid
	WHERE
		CONVERT(date, pn.note_datetime) BETWEEN @startdate AND @lastdate
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
),patientSeen AS (
	SELECT 
		p.PATIENTID,
		p.PATIENTPROFILEID,
		pn.note_datetime,
		phys.provider_name,
		p.age,
		ROW_NUMBER() OVER(PARTITION BY p.PATIENTPROFILEID ORDER BY pn.note_datetime DESC) AS rn
	FROM
		(SELECT * FROM cchc.view_medical_note_full WHERE patient_note_id NOT IN (SELECT t2.patient_note_id FROM filtered_notes t2)) pn
		JOIN patientBase p ON pn.patientprofileid = p.PATIENTPROFILEID
		JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
		JOIN view_activePhys phys ON phys.doctorid = pn.doctorid
	WHERE
		(CONVERT(DATE, pn.note_datetime) BETWEEN @startdate and @lastdate)
		AND pnc.template_field_id IN (14358, 14646, 14359)
), nutritionCounseling AS (
	SELECT 
		pn.patientprofileid,
		pnc.data_value,
		ROW_NUMBER() OVER(PARTITION BY pn.patientprofileid ORDER BY pn.note_datetime DESC) AS rn
	FROM
		cchc.pr1_patient_note pn
			JOIN
		cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
	WHERE
		pnc.template_field_id =14359
		AND (CONVERT(DATE, pn.note_datetime) BETWEEN @startdate AND @lastdate)
), physicalCounseling AS (
	SELECT 
		pn.patientprofileid,
		pnc.data_value,
		ROW_NUMBER() OVER(PARTITION BY pn.patientprofileid ORDER BY pn.note_datetime DESC) AS rn
	FROM
		cchc.pr1_patient_note pn
			JOIN
		cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
	WHERE
		pnc.template_field_id =14358
		AND (CONVERT(DATE, pn.note_datetime) BETWEEN @startdate AND @lastdate)
),vitals AS (
	SELECT 
		pn.patientprofileid,
		pnc.data_value,
		pn.note_datetime,
		ROW_NUMBER() OVER(PARTITION BY pn.patientprofileid ORDER BY pn.note_datetime DESC) AS rn
	FROM
		cchc.pr1_patient_note pn
			JOIN
		cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
	WHERE
		pnc.template_field_id =14646
		AND (CONVERT(DATE, pn.note_datetime) BETWEEN @startdate AND @lastdate)
),
detail AS (
	SELECT 
		provider_name AS Provider,
		PATIENTID AS [Patient ID],
		age AS Age,
		FORMAT(latestDetail.note_datetime, 'MM/dd/yyyy') AS DOS,
		IIF(nc.data_value IS NULL, 0, nc.data_value) AS [Nutrition Counseling Doc'd],
		IIF(pc.data_value IS NULL, 0, pc.data_value) AS [Activity Counseling Doc'd],
		dbo.getTelehealthConsent(latestDetail.PATIENTPROFILEID, CONVERT(date, latestDetail.note_datetime)) AS [Patient Consents to telehealth Visits],
		dbo.getTelephoneConsent(latestDetail.PATIENTPROFILEID, CONVERT(date, latestDetail.note_datetime)) AS [Patient Consents to telephone Visits],
		vt.data_value AS Vital
	FROM 
		patientSeen latestDetail
		LEFT JOIN (SELECT patientprofileid, data_value FROM nutritionCounseling WHERE rn = 1) nc ON latestDetail.PATIENTPROFILEID = nc.patientprofileid
		LEFT JOIN (SELECT patientprofileid, data_value FROM physicalCounseling WHERE rn = 1) pc ON latestDetail.PATIENTPROFILEID = pc.patientprofileid
		LEFT JOIN (SELECT patientprofileid, data_value, note_datetime FROM vitals WHERE rn = 1) vt ON latestDetail.PATIENTPROFILEID = vt.patientprofileid AND CONVERT(date, latestDetail.note_datetime) = CONVERT(date, vt.note_datetime)
	WHERE
		 rn = 1
		 AND latestDetail.PATIENTPROFILEID NOT IN (SELECT patient_id FROM pregnantPt)
)
SELECT 
	Provider,
	[Patient ID],
	Age,
	DOS,
	[Nutrition Counseling Doc'd],
	[Activity Counseling Doc'd],
	IIF([Nutrition Counseling Doc'd] = 1 AND [Activity Counseling Doc'd] = 1, IIF(Vital is null, 'N', 'Y'), 'N') AS Met,
	[Patient Consents to telehealth Visits],
	[Patient Consents to telephone Visits]
FROM detail 
ORDER BY Provider,[Patient ID]