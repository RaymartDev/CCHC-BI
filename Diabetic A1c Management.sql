USE [CCHC]
GO
/****** Object:  StoredProcedure [dbo].[Diabetic A1c Management]    Script Date: 3/7/2024 4:19:37 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[Diabetic A1c Management]
AS
BEGIN
declare @start date, @last date, @noteStart date
set @start = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)  
set @last = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)
set @noteStart = CAST(DATEADD(year, -1, @start) as date)

;WITH diabetic_patients AS (
SELECT
	ch.patient_id,
	d1.icd9 AS d1,
	d2.icd9 AS d2,
	d3.icd9 AS d3,
	d4.icd9 AS d4
FROM
	cchc.charge_history ch  
	LEFT JOIN cchc.company_diagnosis d1 ON d1.DIAGNOSIS_ID=ch.DIAGNOSIS_ID_1 AND (d1.ICD9 LIKE 'E10%'  OR d1.ICD9 LIKE 'E11%' OR d1.icd9 LIKE 'O24%' OR d1.icd9 like 'E13%' OR d1.icd9 like 'E09%' or d1.icd9 like 'E08%' )
	LEFT JOIN cchc.company_diagnosis d2 ON d2.DIAGNOSIS_ID=ch.DIAGNOSIS_ID_2 AND (d2.ICD9 LIKE 'E10%'  OR d2.ICD9 LIKE 'E11%' OR d2.icd9 LIKE 'O24%' OR d2.icd9 like 'E13%' OR d2.icd9 like 'E09%' or d2.icd9 like 'E08%' )
	LEFT JOIN cchc.company_diagnosis d3 ON d3.DIAGNOSIS_ID=ch.DIAGNOSIS_ID_3 AND (d3.ICD9 LIKE 'E10%'  OR d3.ICD9 LIKE 'E11%' OR d3.icd9 LIKE 'O24%' OR d3.icd9 like 'E13%' OR d3.icd9 like 'E09%' or d3.icd9 like 'E08%' )
	LEFT JOIN cchc.company_diagnosis d4 ON d4.DIAGNOSIS_ID=ch.DIAGNOSIS_ID_4 AND (d4.ICD9 LIKE 'E10%'  OR d4.ICD9 LIKE 'E11%' OR d4.icd9 LIKE 'O24%' OR d4.icd9 like 'E13%' OR d4.icd9 like 'E09%' or d4.icd9 like 'E08%' )
	JOIN cchc.pr1_view_patient p ON ch.patient_id = p.PATIENTPROFILEID AND p.age >= 18
WHERE 
	(CAST(ch.post_fromdate as date) BETWEEN @noteStart AND @last)
	AND (d1.icd9 IS NOT NULL OR d2.icd9 IS NOT NULL OR d3.icd9 IS NOT NULL OR d4.icd9 IS NOT NULL)
),lab AS (
SELECT DISTINCT lv.result_value, lr.patientprofileid, lr.obr_obs_datetime,
	ROW_NUMBER() OVER(PARTITION BY lr.patientprofileid ORDER BY lr.obr_obs_datetime DESC) as rn
FROM 
	cchc.pr1_lab_result_item li 
	JOIN cchc.pr1_lab_result_set ls ON li.lab_result_set_id = ls.lab_result_set_id AND ls.lab_hist_req_id = 0
	JOIN cchc.pr1_lab_result_req lr ON ls.lab_result_req_id = lr.lab_result_req_id AND lr.lab_hist_req_id = 0
	JOIN cchc.pr1_lab_result_value lv ON li.lab_result_item_id = lv.lab_result_item_id AND lv.lab_hist_req_id = 0
WHERE 
	(CONVERT(date, lr.obr_obs_datetime) BETWEEN @noteStart AND @last)
	AND (result_code = '2040' OR result_code = '50026400' or result_code = '%hgba1c%')
	AND (lv.result_value <> '' AND TRY_CONVERT(numeric(10,2), lv.result_value) IS NOT NULL)
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
),detail AS (
SELECT 
	p.PATIENTID as [Patient ID],
	p.PATIENTPROFILEID as [Patient Profile ID],
	FORMAT(p.BIRTHDATE, 'MM/dd/yyyy') AS DOB,
	age as Age,
	pn.note_datetime,
	COALESCE(phys.provider_name, '') as phys_name,
	COALESCE(dept.short_name, '') as short_name,
	ROW_NUMBER() OVER(PARTITION BY p.PATIENTPROFILEID ORDER BY pn.note_datetime DESC) as rn
FROM 
	(SELECT * FROM cchc.view_medical_note_full WHERE patient_note_id NOT IN (SELECT t2.patient_note_id FROM filtered_notes t2)) pn
	JOIN (SELECT DISTINCT dp.patient_id FROM diabetic_patients dp) dp ON pn.patientprofileid = dp.patient_id
	JOIN cchc.pr1_view_patient p ON pn.patientprofileid = p.PATIENTPROFILEID
	JOIN activeMedicalPhys phys ON pn.doctorid = phys.doctorid
	JOIN cchc.pr1_view_all_department dept ON pn.dept_id = dept.departmentid
WHERE 
	(CONVERT(date, pn.note_datetime) BETWEEN @start AND @last)
	AND (phys.provider_name <> 'Galstyan, Kevin')
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
	AND TRY_CONVERT(numeric(10,2), pnc.data_value) IS NOT NULL
), finalDetail AS (
SELECT 
	phys_name AS Provider,
	short_name as Clinic,
	[Patient Profile ID],
	[Patient ID],
	DOB,
	age as Age,
	FORMAT(det.note_datetime, 'MM/dd/yyyy') AS [Last DOS],
	(CASE
		WHEN nv.data_value IS NOT NULL AND lab.result_value IS NOT NULL THEN IIF(CONVERT(date, nv.note_datetime) >= CONVERT(date, lab.obr_obs_datetime),nv.data_value ,lab.result_value)
		WHEN nv.data_value IS NOT NULL THEN nv.data_value
		WHEN lab.result_value IS NOT NULL THEN lab.result_value
		ELSE ''
	END) AS [Last hgb A1c Result],
	(CASE
		WHEN nv.data_value IS NOT NULL AND lab.result_value IS NOT NULL THEN IIF(CONVERT(date, nv.note_datetime) >= CONVERT(date, lab.obr_obs_datetime),FORMAT(nv.note_datetime, 'MM/dd/yyyy') ,FORMAT(lab.obr_obs_datetime, 'MM/dd/yyyy'))
		WHEN nv.data_value IS NOT NULL THEN FORMAT(nv.note_datetime, 'MM/dd/yyyy')
		WHEN lab.result_value IS NOT NULL THEN FORMAT(lab.obr_obs_datetime, 'MM/dd/yyyy')
		ELSE ''
	END) AS [Result Date]
FROM
	(SELECT * FROM detail WHERE rn = 1) det
	LEFT JOIN (SELECT * FROM noteValue WHERE rn = 1) nv ON det.[Patient Profile ID] = nv.patientprofileid
	LEFT JOIN (SELECT * FROM lab WHERE rn = 1) lab ON det.[Patient Profile ID] = lab.patientprofileid
), final AS (
SELECT 
	Provider,
	Clinic,
	[Patient ID],
	DOB,
	Age,
	[Last DOS],
	[Last hgb A1c Result],
	[Result Date],
	(CASE
		WHEN [Last hgb A1c Result] = '' THEN 'N'
		WHEN TRY_CONVERT(numeric(10,2), [Last hgb A1c Result]) >= 9.0 THEN 'N'
		ELSE 'Y'
	END) AS Met,
	dbo.getTelehealthConsent([Patient Profile ID], CONVERT(date, [Last DOS])) as [Patient Consents to telehealth Visits],
	dbo.getTelephoneConsent([Patient Profile ID], CONVERT(date, [Last DOS])) as [Patient Consents to telephone Visits]
FROM finalDetail
)
SELECT * FROM final
ORDER BY Provider, [Patient ID]
END
