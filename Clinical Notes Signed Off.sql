SET NOCOUNT ON;
declare @startdate date, @endd date, @endd2 date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @endd = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)
set @endd2 = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE()), -1) as date)

;WITH patientTable AS (
	SELECT 
		PATIENTID, 
		PATIENTPROFILEID
	FROM cchc.pr1_view_patient
	WHERE rn =1
),filtered_notes AS (
	SELECT 
		pn.patient_note_id
	FROM
		cchc.pr1_patient_note pn
		JOIN view_activePhys phys ON pn.doctorid = phys.doctorid
	WHERE
		CONVERT(date, pn.note_datetime) BETWEEN @startdate AND @endd
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
), med_note AS (
SELECT        pn.*, emr_t.template_name
FROM            (SELECT * FROM latest_note WHERE patient_note_id NOT IN (SELECT t2.patient_note_id FROM filtered_notes t2)) pn JOIN cchc.pr1_template emr_t ON pn.template_id = emr_t.template_id
WHERE		emr_t.TEMPLATE_NAME NOT LIKE '%Nurse%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Labs%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%cchc%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%inter%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%podiatry%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%care%' 
      AND emr_t.TEMPLATE_NAME NOT LIKE '%PM160%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE 'OB%' 
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
	  AND emr_t.TEMPLATE_NAME NOT IN('Questions For The Doctor', 'SDoH Data Questions', 'Income / Self Declaration Form E/S')
	  AND emr_t.template_name <> 'SDoH Case Management Engagement'
	  AND emr_t.template_type_id NOT IN (69,77,79,86,66,92,84,63,70,104,94,98,65,32)
),note AS (
	SELECT 
		pn.patient_note_id, 
		pn.doctorid,
		pn.patientprofileid,
		pn.note_datetime,
		pn.update_datetime,
		d.short_name,
		pn.template_id,
		pn.signedby,
		(phys.last_name + ', ' + phys.first_name + ', ' + phys.degree) AS [Provider],
		pt.template_name
	FROM 
		med_note pn 
		JOIN cchc.pr1_template pt ON pn.template_id = pt.template_id
		JOIN cchc.pr1_view_all_department d ON d.departmentid = pn.dept_id
		JOIN (SELECT * FROM view_activePhys WHERE provider_name <> 'Galstyan, Kevin') phys ON pn.doctorid = phys.doctorid
	WHERE 
		CONVERT(date, pn.note_datetime) BETWEEN @startdate AND @endd
	UNION
	SELECT 
		pn.patient_note_id, 
		pn.doctorid,
		pn.patientprofileid,
		pn.note_datetime,
		pn.update_datetime,
		d.short_name,
		pn.template_id,
		pn.signedby,
		CONCAT(phys.provider_name, IIF(phys.degree IS NULL,'', ', ' + phys.degree)) AS [Provider],
		pt.template_name
	FROM 
		 cchc.pr1_patient_note pn 
		 JOIN (SELECT * FROM cchc.pr1_template WHERE template_id IN (2500,2710)) pt ON pn.template_id = pt.template_id
		 JOIN cchc.pr1_view_all_department  d ON pn.dept_id = d.departmentid
		 JOIN view_activePhys phys ON pn.doctorid = phys.doctorid
	WHERE
		CONVERT(DATE, pn.note_datetime) BETWEEN @startdate AND @endd
), jointTable AS (
	SELECT 
		note.template_name,
		note.signedby,
		patientTable.PATIENTID AS [Patient ID],
		note.patient_note_id AS [Note ID],
		Provider,
		note.short_name AS [Clinic],
		FORMAT(note.note_datetime, 'MM/dd/yyyy') AS [Start Date],
		note.update_datetime AS [SignOff Date]
	FROM 
		patientTable 
		JOIN note note ON patientTable.PATIENTPROFILEID = note.patientprofileid
), final AS (
SELECT
		Provider,
		IIF(dbo.BusinessDayDiff(CONVERT(date, [Start Date]), CONVERT(date,[SignOff Date])) <= 1, 'Y', 'N') AS [Met Goal],
		IIF(signedby <= 0, 0,1) AS [Signed],
		Clinic,
		[Patient ID],
		[Note ID],
		[Start Date],
		(CASE 
			WHEN signedby <= 0 THEN ''
			WHEN ISNULL([SignOff Date], '') = '' THEN ''
			WHEN [SignOff Date] < [Start Date] THEN ''
			ELSE FORMAT([SignOff Date], 'MM/dd/yyyy')
		END) AS [SignOff Date]
		,template_name
	FROM jointTable
	
)
SELECT * FROM final
ORDER BY Provider, [Patient ID]