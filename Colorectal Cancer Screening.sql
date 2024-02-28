SET NOCOUNT ON;
declare @startdate date, @lastdate date, @noteStart date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @lastdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)
set @noteStart = CAST(DATEADD(YEAR, -2, @startdate) as date)

;WITH includedPatients AS (
	SELECT 
		PATIENTID,
		PATIENTPROFILEID,
		sex,
		BIRTHDATE,
		age
	FROM cchc.pr1_view_patient
	WHERE 
		age BETWEEN 45 AND 75
),lab AS (
	SELECT lv.result_value, lr.patientprofileid, lr.obr_obs_datetime,
		ROW_NUMBER() OVER(PARTITION BY lr.patientprofileid ORDER BY lr.obr_obs_datetime DESC) as rn
	FROM 
		cchc.pr1_lab_result_item li 
		JOIN cchc.pr1_lab_result_set ls ON li.lab_result_set_id = ls.lab_result_set_id AND li.lab_hist_req_id = ls.lab_hist_req_id
		JOIN cchc.pr1_lab_result_req lr ON ls.lab_result_req_id = lr.lab_result_req_id AND ls.lab_hist_req_id = lr.lab_hist_req_id
		JOIN cchc.pr1_lab_result_value lv ON li.lab_result_item_id = lv.lab_result_item_id AND li.lab_hist_req_id = lv.lab_hist_req_id
	WHERE 
		(li.result_code IN ('75400597','75400599','2008','2096' ,'2097'))
		AND (CONVERT(date,lr.obr_obs_datetime) BETWEEN @noteStart AND @lastdate)
),labInOffice AS (
	SELECT lv.result_value, lr.patientprofileid, lr.obr_obs_datetime,
		ROW_NUMBER() OVER(PARTITION BY lr.patientprofileid ORDER BY lr.obr_obs_datetime DESC) as rn
	FROM 
		cchc.pr1_lab_result_item li 
		JOIN cchc.pr1_lab_result_set ls ON li.lab_result_set_id = ls.lab_result_set_id AND li.lab_hist_req_id = ls.lab_hist_req_id
		JOIN cchc.pr1_lab_result_req lr ON ls.lab_result_req_id = lr.lab_result_req_id AND ls.lab_hist_req_id = lr.lab_hist_req_id
		JOIN cchc.pr1_lab_result_value lv ON li.lab_result_item_id = lv.lab_result_item_id AND li.lab_hist_req_id = lv.lab_hist_req_id
	WHERE 
		(li.result_code LIKE 'RESULT_1' AND li.result_desc LIKE 'Occult%')
		AND (CONVERT(date,lr.obr_obs_datetime) BETWEEN @noteStart AND @lastdate)
), FOBT AS (
	SELECT 
		document_id,
		patientprofileid,
		doc_date,
		s3_datetime,
		ROW_NUMBER() OVER(PARTITION BY patientprofileid ORDER BY doc_date DESC) as rn
	FROM cchc.pr1_document
	WHERE
		file_name LIKE '%FOBT%'
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
), medicalVisits AS (
	SELECT 
		p.PATIENTPROFILEID,
		phys.provider_name Provider,
		dept.short_name AS Clinic,
		p.PATIENTID AS [Patient ID],
		p.sex AS Gender,
		FORMAT(p.BIRTHDATE, 'MM/dd/yyyy') AS DOB,
		p.age AS Age,
		FORMAT(note.note_datetime, 'MM/dd/yyyy') AS DOS,
		ROW_NUMBER() OVER(PARTITION BY p.PATIENTPROFILEID ORDER BY note.note_datetime DESC) AS rn
	FROM 
		(SELECT * FROM cchc.view_medical_note_full WHERE patient_note_id NOT IN (SELECT t2.patient_note_id FROM filtered_notes t2)) note
		JOIN includedPatients p ON p.PATIENTPROFILEID = note.patientprofileid
		JOIN (
			SELECT * FROM activeMedicalPhys t2
			WHERE t2.provider_name NOT IN ('Galstyan, Kevin')
		) phys ON note.doctorid = phys.doctorid
		JOIN cchc.pr1_view_all_department dept ON note.dept_id = dept.departmentid
	WHERE
		CAST(note.note_datetime AS date) BETWEEN @startdate AND @lastdate
)
SELECT 
	mv.Provider,
	mv.Clinic,
	mv.[Patient ID],
	mv.Gender,
	mv.DOB,
	mv.Age,
	mv.DOS,
	IIF(lab.obr_obs_datetime is null, '', FORMAT(lab.obr_obs_datetime, 'MM/dd/yyyy')) AS [Last FIT Date],
	IIF(labIO.obr_obs_datetime is null, '', FORMAT(labIO.obr_obs_datetime, 'MM/dd/yyyy')) AS [In Office FOBT],
	IIF(fobt.doc_date is null, '', FORMAT(fobt.doc_date, 'MM/dd/yyyy')) AS [Last FOBT Scanned],
	dbo.getTelehealthConsent(mv.PATIENTPROFILEID, CONVERT(date, mv.DOS)) AS [Patient Consents to Telehealth Visit],
	dbo.getTelephoneConsent(mv.PATIENTPROFILEID, CONVERT(date, mv.DOS)) AS [Patient Consents to Telephone Visit]
FROM
	medicalVisits mv
	LEFT JOIN (SELECT * FROM lab WHERE rn = 1) lab ON mv.PATIENTPROFILEID = lab.patientprofileid
	LEFT JOIN (SELECT * FROM labInOffice WHERE rn = 1) labIO ON mv.PATIENTPROFILEID = labIO.patientprofileid
	LEFT JOIN (SELECT * FROM FOBT WHERE rn = 1) fobt ON mv.PATIENTPROFILEID = fobt.patientprofileid
WHERE mv.rn = 1 