SET NOCOUNT ON;
declare @startdate date, @lastdate date, @noteMonth date
set @startdate =  CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @lastdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)
set @noteMonth = CAST(DATEADD(MONTH, -4, @startdate) as date)

;WITH patientBase AS (
	SELECT
		PATIENTID,
		PATIENTPROFILEID,
		age,
		BIRTHDATE
	FROM cchc.pr1_view_patient 
	WHERE 
		rn = 1
		AND (age BETWEEN 18 AND 85)
), potentialPatients AS (
	SELECT 
		patientprofileid
	FROM 
		cchc.pr1_patient_note pn
		JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
	WHERE 
		pnc.template_field_id IN (12848, 12849, 13259, 13260)
		AND (CONVERT(DATE, pn.note_datetime) BETWEEN @startdate AND @lastdate)
), dm_ckd AS (
	SELECT 
		dev_ch.patient_id,
		ROW_NUMBER() OVER(PARTITION BY dev_ch.patient_id ORDER BY dev_ch.post_fromdate DESC) AS rn
	FROM 
		cchc.charge_history dev_ch 
		JOIN cchc.company_diagnosis AS dev_d ON dev_d.diagnosis_id = dev_ch.diagnosis_id_1 OR dev_d.diagnosis_id = dev_ch.diagnosis_id_2 OR dev_d.diagnosis_id = dev_ch.diagnosis_id_3 OR 
                                                     dev_d.diagnosis_id = dev_ch.diagnosis_id_4
    WHERE
		(dev_ch.company_id = 9 and  dev_d.company_id=9) 
		AND (CONVERT(date,dev_ch.post_fromdate) BETWEEN @noteMonth AND @lastdate)
		AND (dev_d.icd9 like 'E10%' or dev_d.icd9 like 'E11%' or dev_d.icd9 like 'E13%' or dev_d.icd9 like 'N18%')
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
), med_notes AS (
SELECT        pn.*, emr_t.template_name
FROM            (SELECT * FROM latest_note) pn JOIN cchc.pr1_template emr_t ON pn.template_id = emr_t.template_id
WHERE		emr_t.TEMPLATE_NAME NOT LIKE '%Nurse%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Labs%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%cchc%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%inter%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%care%' 
      AND emr_t.TEMPLATE_NAME NOT LIKE '%PM160%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Return%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Amendment%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Title%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%CPSP%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Communication%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Referral%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%PPD%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Hours%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%HEADS%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Reminder%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Auth%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Quick%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Test%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%IBH%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Message%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Service%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Delivery%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%CCD%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Hospitalization Tracking%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%COVID%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Good Faith Estimate%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE 'BH%'
	  --AND emr_t.template_name NOT LIKE '%PHQ Screening%'
	  AND emr_t.TEMPLATE_NAME NOT IN('Questions For The Doctor', 'SDoH Data Questions')
	  AND emr_t.template_name <> 'SDoH Case Management Engagement'
	  AND emr_t.template_type_id NOT IN (69,77,76,64,79,86,66,84,63,70,104,94,98,65,32)
), capturedVisits AS (
	SELECT 
		p.PATIENTID,
		p.PATIENTPROFILEID,
		p.age,
		p.BIRTHDATE,
		phys.provider_name,
		dept.short_name,
		pn.note_datetime,
		pn.patient_note_id,
		ROW_NUMBER() OVER(PARTITION BY p.PATIENTPROFILEID ORDER BY pn.note_datetime DESC) AS rn
	FROM 
		(SELECT * FROM med_notes WHERE patient_note_id NOT IN (SELECT t2.patient_note_id FROM filtered_notes t2)) pn
		JOIN patientBase p ON pn.patientprofileid = p.PATIENTPROFILEID
		JOIN potentialPatients pp ON pn.patientprofileid = pp.patientprofileid
		JOIN [dbo].[view_activePhys] phys ON pn.doctorid = phys.doctorid
		JOIN cchc.pr1_view_all_department dept ON pn.dept_id = dept.departmentid
	WHERE
		CONVERT(date, pn.note_datetime) BETWEEN @startdate AND @lastdate
), latestVisits AS (
	SELECT 
		PATIENTPROFILEID,
		PATIENTID,
		age,
		BIRTHDATE,
		provider_name,
		short_name,
		note_datetime,
		(
			SELECT TOP 1 t2.data_value
			FROM
				cchc.pr1_patient_note t1
				JOIN cchc.pr1_patient_note_control t2 ON t1.patient_note_id = t2.patient_note_id
			WHERE 
				t2.template_field_id = 12848
				AND t1.patientprofileid = pn.PATIENTPROFILEID
				AND CONVERT(date, t1.note_datetime) = CONVERT(date, pn.note_datetime)
				AND t2.data_value <> '' AND TRY_CONVERT(int, t2.data_value) IS NOT NULL
		) as [1st Systolic BP],
		(
			SELECT TOP 1 t2.data_value
			FROM
				cchc.pr1_patient_note t1
				JOIN cchc.pr1_patient_note_control t2 ON t1.patient_note_id = t2.patient_note_id
			WHERE 
				t2.template_field_id = 12849
				AND t1.patientprofileid = pn.PATIENTPROFILEID
				AND CONVERT(date, t1.note_datetime) = CONVERT(date, pn.note_datetime)
				AND t2.data_value <> '' AND TRY_CONVERT(int, t2.data_value) IS NOT NULL
		) as [1st Diastolic BP],
		(
			SELECT TOP 1 t2.data_value
			FROM
				cchc.pr1_patient_note t1
				JOIN cchc.pr1_patient_note_control t2 ON t1.patient_note_id = t2.patient_note_id
			WHERE 
				t2.template_field_id = 13259
				AND t1.patientprofileid = pn.PATIENTPROFILEID
				AND CONVERT(date, t1.note_datetime) = CONVERT(date, pn.note_datetime)
				AND t2.data_value <> '' AND TRY_CONVERT(int, t2.data_value) IS NOT NULL
		) as [2nd Systolic BP],
		(
			SELECT TOP 1 t2.data_value
			FROM
				cchc.pr1_patient_note t1
				JOIN cchc.pr1_patient_note_control t2 ON t1.patient_note_id = t2.patient_note_id
			WHERE 
				t2.template_field_id = 13260
				AND t1.patientprofileid = pn.PATIENTPROFILEID
				AND CONVERT(date, t1.note_datetime) = CONVERT(date, pn.note_datetime)
				AND t2.data_value <> '' AND TRY_CONVERT(int, t2.data_value) IS NOT NULL
		) as [2nd Diastolic BP],
		IIF(ck.patient_id IS NULL, '1', '0') AS [No DM or CKD]
	FROM 
		capturedVisits pn
		LEFT JOIN (SELECT patient_id FROM dm_ckd WHERE rn = 1) ck ON pn.PATIENTPROFILEID = ck.patient_id
	WHERE 
		pn.rn = 1
), clean AS (
SELECT 
	provider_name AS Provider,
	short_name AS Clinic,
	PATIENTID AS [Patient ID],
	age AS Age,
	[No DM or CKD],
	FORMAT(note_datetime, 'MM/dd/yyyy') AS [Last DOS],
	FORMAT(BIRTHDATE, 'MM/dd/yyyy') AS [DOB],
	IIF([1st Systolic BP] IS NULL, '', [1st Systolic BP]) AS [1st Systolic BP],
	IIF([1st Diastolic BP] IS NULL, '', [1st Diastolic BP]) AS [1st Diastolic BP],
	(CASE
		WHEN [1st Systolic BP] is null and [1st Diastolic BP] is null THEN '0'
		WHEN (age BETWEEN 18 and 59) and TRY_CAST([1st Systolic BP] as int) < 140 and TRY_CAST([1st Diastolic BP] as int) < 90 THEN '1'
		WHEN (age >= 60) and [No DM or CKD] = '0' and TRY_CAST([1st Systolic BP] as int) < 140 and TRY_CAST([1st Diastolic BP] as int) < 90 THEN '1'
		WHEN (age >= 60) and [No DM or CKD] = '1' and TRY_CAST([1st Systolic BP] as int) < 150 and TRY_CAST([1st Diastolic BP] as int) < 90 THEN '1'
		ELSE '0'
	END) AS [1st BP Controlled],
	IIF([2nd Systolic BP] IS NULL, 'na', [2nd Systolic BP]) AS [2nd Systolic BP],
	IIF([2nd Diastolic BP] IS NULL, 'na', [2nd Diastolic BP]) AS [2nd Diastolic BP],
	dbo.getTelehealthConsent(PATIENTPROFILEID, CONVERT(DATE, note_datetime)) AS [Patient Consents to telehealth Visits],
	dbo.getTelephoneConsent(PATIENTPROFILEID, CONVERT(DATE, note_datetime)) AS [Patient Consents to telephone Visits]
FROM 
	latestVisits
), detail AS (
SELECT 
	Provider,
	Clinic,
	[Patient ID],
	Age,
	[No DM or CKD],
	[Last DOS],
	DOB,
	[1st Systolic BP],
	[1st Diastolic BP],
	[1st BP Controlled],
	IIF([2nd Systolic BP] = 'na', '', [2nd Systolic BP]) AS [2nd Systolic BP],
	IIF([2nd Diastolic BP] = 'na', '', [2nd Diastolic BP]) AS [2nd Diastolic BP],
	(CASE 
		WHEN [1st BP Controlled] = '0' and ((TRY_CAST([2nd Systolic BP] as int) is null or TRY_CAST([2nd Systolic BP] as int) = 0) or (TRY_CAST([2nd Diastolic BP] as int) = 0 or TRY_CAST([2nd Diastolic BP] as int) is null)) THEN 'N'
		WHEN [1st BP Controlled] = '0' and ((TRY_CAST([2nd Systolic BP] as int) is null or TRY_CAST([2nd Systolic BP] as int) = 0) and (TRY_CAST([2nd Diastolic BP] as int) = 0 or TRY_CAST([2nd Diastolic BP] as int) is null)) THEN 'N'
		WHEN [1st BP Controlled] = '1' and ((TRY_CAST([2nd Systolic BP] as int) is null or TRY_CAST([2nd Systolic BP] as int) = 0) and (TRY_CAST([2nd Diastolic BP] as int) = 0 or TRY_CAST([2nd Diastolic BP] as int) is null)) then 'Y'
		WHEN (Age >= 18 and Age <= 59) and (TRY_CAST([2nd Systolic BP] as int) < 140 and TRY_CAST([2nd Diastolic BP] as int) < 90) and (TRY_CAST([2nd Systolic BP] as int) != 0 and TRY_CAST([2nd Diastolic BP] as int) != 0) then 'Y'
		WHEN (Age >= 60) and ([No DM or CKD] = '0') and (TRY_CAST([2nd Systolic BP] as int) < 140 and TRY_CAST([2nd Diastolic BP] as int) < 90) and (TRY_CAST([2nd Systolic BP] as int) != 0 and TRY_CAST([2nd Diastolic BP] as int) != 0) then 'Y'
		WHEN (Age >= 60) and ([No DM or CKD] = '1') and (TRY_CAST([2nd Systolic BP] as int) < 150 and TRY_CAST([2nd Diastolic BP] as int) < 90) and (TRY_CAST([2nd Systolic BP] as int) != 0 and TRY_CAST([2nd Diastolic BP] as int) != 0) then 'Y'
		ELSE 'N'
	END) AS [Final BP Controlled],
	[Patient Consents to telehealth Visits],
	[Patient Consents to telephone Visits]
FROM clean
)
SELECT * FROM detail

ORDER BY Provider, Clinic, [Patient ID],[Last DOS]