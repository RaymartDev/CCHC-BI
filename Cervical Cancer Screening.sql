SET NOCOUNT ON;

declare @startdate date, @lastdate date, @last5Years date, @lastYear date, @last3Years date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @lastdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)
set @last3Years = CAST(DATEADD(YEAR, -3, @startdate) as date)
set @lastYear = CAST(DATEADD(YEAR, -1, @startdate) as date)
;WITH female_patients AS (
	SELECT * FROM cchc.pr1_view_patient WHERE (age between 21 and 64)  and (sex = 'F') and (rn = 1)
), cervical_lab_3years AS (
	SELECT DISTINCT
		lr.patientprofileid,
		lr.obr_obs_datetime,
		ROW_NUMBER() OVER(PARTITION BY lr.patientprofileid ORDER BY lr.obr_obs_datetime DESC) AS rn
	FROM 
		cchc.pr1_lab_result_set ls
		JOIN cchc.pr1_lab_result_req lr ON ls.lab_result_req_id = lr.lab_result_req_id
		JOIN cchc.pr1_lab_result_item li ON li.lab_result_set_id = ls.lab_result_set_id
	WHERE 
		(CAST(lr.obr_obs_datetime as date) >= @last3Years and CAST(lr.obr_obs_datetime as date) <= @lastdate)
			AND
		(li.result_code like '%90001256%' or li.result_code like '%APResult%')
			AND
		(
		ls.obr_order_code like '%8011%'
		OR ls.obr_order_code like '%58315%'
		OR ls.obr_order_code like '%58316%'
		OR ls.obr_order_code like '%90933%'
		OR ls.obr_order_code like '%90934%'
		OR ls.obr_order_code like '%92087%'
		OR ls.obr_order_code like '%91339%'
		OR ls.obr_order_code like '%58355%'
		OR ls.obr_order_code like '%91392%'
		OR ls.obr_order_code like '%91393%'
		OR ls.obr_order_code like '%91395%'
		OR ls.obr_order_code like '%91394%'
		OR ls.obr_order_code like '%91906%'
		OR ls.obr_order_code like '%91911%'
		OR ls.obr_order_code like '%91912%'
		OR ls.obr_order_code like '%92012%'
		OR ls.obr_order_code like '%92082%'
		OR ls.obr_order_code like '%92087%'
		OR ls.obr_order_code like '%92088%'
		OR ls.obr_order_code like '%92090%'
		OR ls.obr_order_code like '%92092%'
		OR ls.obr_order_code like '%92094%'
		OR ls.obr_order_code like '%92102%'
		OR ls.obr_order_code like '%92238%'
		OR ls.obr_order_code like '%14499%'
		OR ls.obr_order_code like '%18817X%'
		OR ls.obr_order_code like '%18810X%'
		OR ls.obr_order_code like '%18828X%'
		)
), cervical_lab_3years_latest AS (
	SELECT * FROM cervical_lab_3years WHERE rn = 1
), filtered_notes AS (
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
), medicalNotes AS (
	SELECT pn.*
	FROM cchc.view_medical_note_full pn 
	WHERE 
		(CAST(pn.note_datetime as date) >= @startdate and CAST(pn.note_datetime as date) <= @lastdate)
		AND (pn.patient_note_id NOT IN (SELECT t2.patient_note_id FROM filtered_notes t2))
), providers AS (
	SELECT 
		* 
	FROM activeMedicalPhys
			
), eligVisits AS (
	SELECT 
		patientprofileid, 
		CAST(booking_date as date) AS DOS
	FROM cchc.pr1_view_patientappt 
	WHERE 
		(visit_type_id <> 58849498)
			AND
		(CAST(booking_date AS date) >= @startdate AND CAST(booking_date AS date) <= @lastdate)
),hystertectomy AS (
	SELECT
		ch.patient_id,
		CAST(ch.post_fromdate AS date) AS DOS_CH
	FROM 
		cchc.charge_history ch
		JOIN cchc.company_diagnosis cd ON ch.diagnosis_id_1 = cd.diagnosis_id OR ch.diagnosis_id_2 = cd.diagnosis_id OR ch.diagnosis_id_3 = cd.diagnosis_id OR ch.diagnosis_id_4 = cd.diagnosis_id
	WHERE
		cd.icd9 <> 'Z90.710'
			AND
		(CAST(ch.post_fromdate AS date) >= @last3Years AND CAST(ch.post_fromdate AS date) <= @lastdate)
)
,detail AS (
SELECT 
	CONCAT(providers.last_name, ', ', providers.first_name) AS Provider,
	IIF(dept.short_name is null, '', dept.short_name) AS Clinic,
	female_patients.PATIENTID AS [Patient ID],
	FORMAT(female_patients.BIRTHDATE, 'MM/dd/yyyy') AS DOB,
	female_patients.age AS Age,
	medicalNotes.note_datetime AS DOS,
	cl3.obr_obs_datetime AS [Last Pap Date],
	medicalNotes.patientprofileid,
	ROW_NUMBER() OVER(PARTITION BY female_patients.PATIENTPROFILEID ORDER BY medicalNotes.note_datetime DESC) as rn
FROM 
	medicalNotes 
		JOIN
	female_patients ON medicalNotes.patientprofileid = female_patients.PATIENTPROFILEID
		JOIN
	providers ON medicalNotes.doctorid = providers.doctorid
		JOIN
	cchc.pr1_view_all_department dept ON medicalNotes.dept_id = dept.departmentid
		LEFT JOIN
	cervical_lab_3years_latest cl3 ON medicalNotes.patientprofileid = cl3.patientprofileid
		JOIN
	hystertectomy ON medicalNotes.patientprofileid = hystertectomy.patient_id
		JOIN
	eligVisits ON medicalNotes.patientprofileid = eligVisits.patientprofileid AND CAST(medicalNotes.note_datetime AS date) = eligVisits.DOS
), latestDetail AS (
	SELECT * FROM detail WHERE rn = 1
), final AS (
SELECT 
	Provider,
	Clinic,
	[Patient ID],
	DOB,
	Age,
	FORMAT(DOS, 'MM/dd/yyyy') as DOS,
	IIF([Last Pap Date] is null, '', FORMAT([Last Pap Date], 'MM/dd/yyyy')) as [Last Pap Date],
	dbo.getTelehealthConsent(latestDetail.patientprofileid, CONVERT(date, DOS)) [Patient Consents to telehealth Visits],
	dbo.getTelephoneConsent(latestDetail.patientprofileid, CONVERT(date, DOS)) [Patient Consents to telephone Visits]
FROM latestDetail)

SELECT 
	Provider,
	Clinic,
	[Patient ID],
	DOB,
	Age,
	DOS,
	[Last Pap Date],
	[Patient Consents to telehealth Visits],
	[Patient Consents to telephone Visits]
FROM final 
--WHERE 
	--[Visit Type] not like '%NURVIST%' 
	--AND [Visit Type] not like 'PHONE%'
ORDER BY [Patient ID]