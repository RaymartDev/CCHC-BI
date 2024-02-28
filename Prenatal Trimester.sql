SET NOCOUNT ON;
declare @start date, @end date
set @start =CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @end =CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)

;WITH filtered_notes AS (
	SELECT 
		pn.patient_note_id
	FROM
		cchc.pr1_patient_note pn
		JOIN view_activePhys phys ON pn.doctorid = phys.doctorid
	WHERE
		CONVERT(date, pn.note_datetime) BETWEEN @start AND @end
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
), prenatalTrimester AS (
SELECT 
	pn.patientprofileid,
	pn.note_datetime,
	pnc.data_value,
	tf.field_name,
	ROW_NUMBER() OVER(PARTITION BY pn.patientprofileid ORDER BY pn.note_datetime) AS rn
FROM
	cchc.pr1_patient_note pn
	JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
	JOIN cchc.pr1_template_field tf ON pnc.template_field_id = tf.template_field_id
WHERE
	pnc.template_field_id IN (12164,12166,12168)
	AND pnc.data_value = '1'
	AND (CONVERT(date, pn.note_datetime) BETWEEN @start AND @end)
),prenatalTrimesterNonCCHC AS (
SELECT 
	pn.patientprofileid,
	pn.note_datetime,
	pnc.data_value,
	tf.field_name,
	ROW_NUMBER() OVER(PARTITION BY pn.patientprofileid ORDER BY pn.note_datetime DESC) AS rn
FROM
	cchc.pr1_patient_note pn
	JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
	JOIN cchc.pr1_template_field tf ON pnc.template_field_id = tf.template_field_id
WHERE
	pnc.template_field_id IN (12165,12167,12169)
	AND pnc.data_value = '1'
	AND (CONVERT(date, pn.note_datetime) BETWEEN @start AND @end)
), ACOG AS (
SELECT 
	pn.note_datetime,
	wn.field_name AS NONCCHC,
	wc.field_name AS WithCCHC,
	staff.fullname,
	wc.data_value AS [WITH CCHC],
	wn.data_value AS [NON CCHC],
	p.PATIENTID
FROM
	cchc.pr1_patient_note pn
	JOIN cchc.pr1_view_patient p ON pn.patientprofileid = p.PATIENTPROFILEID
	JOIN cchc.pr1_template pt ON pn.template_id = pt.template_id
	JOIN cchc.pr1_view_all_staff staff ON pn.doctorid = staff.doctorid
	LEFT JOIN (SELECT * FROM prenatalTrimester WHERE rn = 1) wc ON pn.patientprofileid = wc.patientprofileid
	LEFT JOIN (SELECT * FROM prenatalTrimesterNonCCHC WHERE rn = 1) wn ON pn.patientprofileid = wn.patientprofileid
WHERE
	pt.template_name LIKE '%Initial ACOG Clinical Note%'
	AND (CONVERT(date, pn.note_datetime) BETWEEN @start AND @end)
	AND (pn.patient_note_id NOT IN (SELECT t2.patient_note_id FROM filtered_notes t2))
)
SELECT 
	fullname AS Provider,
	PATIENTID AS [Patient ID],
	FORMAT(note_datetime, 'MM/dd/yyyy') AS DOS,
	IIF(WithCCHC IS NULL, IIF(NONCCHC IS NULL, '',RIGHT(NONCCHC, 6)), RIGHT(WithCCHC, 7)) AS Description,
	IIF(WithCCHC IS NULL, 0, 1) AS [Begin With First Trimester]
FROM ACOG
ORDER BY Provider,[Patient ID]