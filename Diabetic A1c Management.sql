SET NOCOUNT ON;
declare @start date, @last date, @noteStart date
set @start = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)  
set @last = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)
set @noteStart = CAST(DATEADD(year, -1, @start) as date)
;WITH diabetic_patients AS (
	SELECT
		ch.patient_id,
		ch.patient_number, 
		ch.post_fromdate,
		FORMAT(p.BIRTHDATE, 'MM/dd/yyyy') as DOB,
		p.age,
		d.icd9,
		ROW_NUMBER() OVER(PARTITION BY ch.patient_id ORDER BY ch.post_fromdate DESC) as rn
	FROM
		cchc.charge_history ch  
		join cchc.company_diagnosis d ON (d.DIAGNOSIS_ID=ch.DIAGNOSIS_ID_1
													OR d.DIAGNOSIS_ID=ch.DIAGNOSIS_ID_2
													OR d.DIAGNOSIS_ID=ch.DIAGNOSIS_ID_3
													OR d.DIAGNOSIS_ID=ch.DIAGNOSIS_ID_4)
		JOIN (SELECT * FROM cchc.pr1_view_patient WHERE rn < 2 and (age >= 18)) p ON ch.patient_id = p.PATIENTPROFILEID
	WHERE 
		(d.ICD9 LIKE 'E10%'  OR d.ICD9 LIKE 'E11%' OR d.icd9 LIKE 'O24%' OR d.icd9 like 'E13%' OR d.icd9 like 'E09%' or d.icd9 like 'E08%' )
		and (CAST(ch.post_fromdate as date) >= @noteStart and CAST(ch.post_fromdate as date) <= @last)
),lab AS (
	SELECT lv.result_value, lr.patientprofileid, lr.obr_obs_datetime,
		ROW_NUMBER() OVER(PARTITION BY lr.patientprofileid ORDER BY lr.obr_obs_datetime DESC) as rn
	FROM 
		cchc.pr1_lab_result_item li 
		JOIN cchc.pr1_lab_result_set ls ON li.lab_result_set_id = ls.lab_result_set_id
		JOIN cchc.pr1_lab_result_req lr ON ls.lab_result_req_id = lr.lab_result_req_id
		JOIN cchc.pr1_lab_result_value lv ON li.lab_result_item_id = lv.lab_result_item_id
		JOIN cchc.pr1_view_patient p ON lr.patientprofileid = p.PATIENTPROFILEID
	WHERE 
		(CONVERT(date, lr.obr_obs_datetime) BETWEEN @noteStart AND @last)
		AND (result_code = '2040' OR result_code = '50026400' or result_code = '%hgba1c%')
		AND (lv.result_value <> '' AND TRY_CONVERT(decimal, lv.result_value) IS NOT NULL)
	
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
),

detail AS (
	SELECT 
		dp.patient_number as [Patient ID],
		dp.patient_id as [Patient Profile ID],
		DOB,
		age as Age,
		pn.note_datetime,
		COALESCE(phys.provider_name, '') as phys_name,
		COALESCE(dept.short_name, '') as short_name,
		ROW_NUMBER() OVER(PARTITION BY dp.patient_id ORDER BY pn.note_datetime DESC) as rn
	FROM 
		diabetic_patients dp 
		JOIN (SELECT * FROM cchc.view_medical_note_full WHERE patient_note_id NOT IN (SELECT t2.patient_note_id FROM filtered_notes t2)) pn ON dp.patient_id = pn.patientprofileid
		JOIN activeMedicalPhys phys ON pn.doctorid = phys.doctorid
		JOIN cchc.pr1_view_all_department dept ON pn.dept_id = dept.departmentid
	WHERE 
		(CONVERT(date, pn.note_datetime) BETWEEN @start AND @last)
		and (phys.provider_name <> 'Galstyan, Kevin')
), noteValue AS (
SELECT
	pn.note_datetime, 
	pn.patientprofileid,
	pnc.data_value,
	ROW_NUMBER() OVER(PARTITION BY pn.patientprofileid ORDER BY pn.note_datetime DESC) AS rn
FROM
	cchc.pr1_patient_note pn JOIN 
	cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
WHERE
	CONVERT(date, pn.note_datetime) BETWEEN @noteStart AND @last
	AND pnc.template_field_id = 3680
	AND TRY_CONVERT(decimal, pnc.data_value) IS NOT NULL
), finalDetail AS (
	SELECT 
		phys_name AS Provider,
		short_name as Clinic,
		[Patient ID],
		[Patient Profile ID],
		DOB,
		age as Age,
		dp.note_datetime,
		FORMAT(dp.note_datetime, 'MM/dd/yyyy') as [Last DOS],
		(SELECT TOP 1 t3.data_value FROM cchc.pr1_patient_note t2 JOIN cchc.pr1_patient_note_control t3 ON t2.patient_note_id = t3.patient_note_id
			WHERE (CAST(t2.note_datetime as date) >= @noteStart and CAST(t2.note_datetime as date) <= @last) 
				and t2.patientprofileid = dp.[Patient Profile ID] and t3.template_field_id = 3680 and t3.data_value is not null and t3.data_value != '' and TRY_CONVERT(decimal, t3.data_value) is not null
			ORDER BY t2.note_datetime DESC) as [Last hgb A1c Result],
		(SELECT TOP 1 FORMAT(t2.note_datetime, 'MM/dd/yyyy') FROM cchc.pr1_patient_note t2 JOIN cchc.pr1_patient_note_control t3 ON t2.patient_note_id = t3.patient_note_id
			WHERE (CAST(t2.note_datetime as date) >= @noteStart and CAST(t2.note_datetime as date) <= @last)
				and t2.patientprofileid = dp.[Patient Profile ID] and t3.template_field_id = 3680 and t3.data_value is not null and t3.data_value != '' and TRY_CONVERT(decimal, t3.data_value) is not null
			ORDER BY t2.note_datetime DESC) as [Result Date],
		(
			SELECT TOP 1 t2.result_value FROM lab t2
			WHERE t2.patientprofileid = dp.[Patient Profile ID]
			ORDER BY t2.obr_obs_datetime DESC
		) AS [Lab Result],
		(
			SELECT TOP 1 FORMAT(t2.obr_obs_datetime, 'MM/dd/yyyy') FROM lab t2
			WHERE t2.patientprofileid = dp.[Patient Profile ID]
			ORDER BY t2.obr_obs_datetime DESC
		) AS [Lab Date]
	FROM 
		(SELECT * FROM detail WHERE rn = 1) dp
		LEFT JOIN (SELECT * FROM noteValue WHERE rn = 1) nv ON dp.[Patient Profile ID] = nv.patientprofileid 
),


final AS (
SELECT 
	Provider,
	Clinic,
	[Patient ID],
	DOB,
	Age,
	[Last DOS],
	(CASE
		WHEN [Last hgb A1c Result] is not null and [Lab Result] is not null THEN IIF(CAST([Result Date] as date) >= CAST([Lab Date] as date), [Last hgb A1c Result], [Lab Result])
		WHEN [Last hgb A1c Result] is not null THEN CAST([Last hgb A1c Result] as varchar)
		WHEN [Lab Result] is not null THEN CAST([Lab Result] as varchar)
		ELSE ''
	END) as [Last hgb A1c Result],
	--COALESCE([Last hgb A1c Result], 0.0) as [Last hgb A1c Result],
	(CASE
		WHEN [Last hgb A1c Result] is not null and [Lab Result] is not null THEN IIF(CAST([Result Date] as date) >= CAST([Lab Date] as date), [Result Date], [Lab Date])
		WHEN [Result Date] is not null THEN [Result Date]
		WHEN [Lab Date] is not null THEN [Lab Date]
		ELSE ''
	END) as [Result Date],
	(CASE
		WHEN [Last hgb A1c Result] is not null and [Lab Result] is not null THEN IIF(CAST([Result Date] as date) >= CAST([Lab Date] as date), IIF(TRY_CAST([Last hgb A1c Result] as decimal(10,2)) >= 9.0, 'N', 'Y'), IIF(TRY_CAST([Lab Result] as decimal(10,2)) >= 9.0, 'N', 'Y'))
		WHEN ([Last hgb A1c Result] is null or [Last hgb A1c Result] = '') and ([Lab Result] is null or [Lab Result] = '') THEN 'N'
		WHEN [Last hgb A1c Result] is not null and [Lab Result] is not null THEN 
			IIF([Result Date] >= [Lab Date], IIF((TRY_CAST([Last hgb A1c Result] as decimal(10,2)) is not null and TRY_CAST([Last hgb A1c Result] as decimal(10,2)) >= 9.0), 'N', 'Y'), 
			IIF((TRY_CAST([Lab Result] as decimal(10,2)) is not null and TRY_CAST([Lab Result] as decimal(10,2)) >= 9.0), 'N', 'Y'))
		WHEN  
			(TRY_CAST([Last hgb A1c Result] as decimal(10,2)) is not null and TRY_CAST([Last hgb A1c Result] as decimal(10,2)) >= 9.0)
				or
			(TRY_CAST([Lab Result] as decimal(10,2)) is not null and TRY_CAST([Lab Result] as decimal(10,2)) >= 9.0)
			THEN 'N'
		ELSE 'Y'
	END) as Met,
	dbo.getTelehealthConsent([Patient Profile ID], CONVERT(date, note_datetime)) as [Patient Consents to telehealth Visits],
	dbo.getTelephoneConsent([Patient Profile ID], CONVERT(date, note_datetime)) as [Patient Consents to telephone Visits]
FROM finalDetail
)
SELECT * FROM final 
ORDER BY Provider, [Patient ID] 