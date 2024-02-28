SET NOCOUNT ON
declare @startDate date, @endDate date, @patientNoteStartDate date, @last2Year date
set @startDate = CONVERT(date,DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0))
set @endDate =CONVERT(date,DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1))
set @patientNoteStartDate= CONVERT(date,DATEADD(month,-6,@startDate)) --PatientNote Date from:last year
set @last2Year = CONVERT(date, DATEADD(year, -2, @startDate))

;WITH patients AS (
	SELECT 
		PATIENTPROFILEID,
		PATIENTID
	FROM 
		(SELECT * FROM cchc.pr1_view_patient WHERE rn = 1) p
	WHERE 
		age >= 18 
), lastMonth AS (
	SELECT 
		pn.patientprofileid
	FROM 
		cchc.pr1_patient_note pn
		JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
	WHERE
		pnc.template_field_id IN (14375,14451,14452,14450,14449) AND (CONVERT(date, pn.note_datetime) BETWEEN @last2Year AND @endDate)
),filtered_notes AS (
	SELECT 
		pn.patient_note_id
	FROM
		cchc.pr1_patient_note pn
		JOIN view_activePhys phys ON pn.doctorid = phys.doctorid
	WHERE
		CONVERT(date, pn.note_datetime) BETWEEN @startdate AND @endDate
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
), notes AS (
SELECT        pn.*, emr_t.template_name
FROM    (SELECT * FROM latest_note WHERE patient_note_id NOT IN (SELECT t2.patient_note_id FROM filtered_notes t2)) pn JOIN cchc.pr1_template emr_t ON pn.template_id = emr_t.template_id
WHERE emr_t.TEMPLATE_NAME NOT LIKE '%Nurse%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Labs%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%cchc%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE 'ob%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE 'gyn%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%inter%'
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%podiatry%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%care%' 
      AND emr_t.TEMPLATE_NAME NOT LIKE '%PM160%' 
	  AND emr_t.TEMPLATE_NAME NOT LIKE '%Return%' 
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
	  AND emr_t.TEMPLATE_NAME NOT IN('Questions For The Doctor', 'SDoH Data Questions')
	  AND emr_t.template_name <> 'SDoH Case Management Engagement'
	  AND emr_t.template_type_id NOT IN (69,77,76,64,79,86,66,92,84,63,70,104,94,98,65,32)
), physicians AS (
SELECT 
	doctorid,
	provider_name,
	first_name,
	last_name,
	degree,
	individual_npi
FROM (SELECT * FROM view_activePhys_all WHERE rn = 1) phys
WHERE
	UPPER(degree) NOT IN ('DDS', 'DPM', 'LCSW')
	AND ISNULL(degree,'') <> ''
	AND ISNULL(individual_npi, '') <> ''
	AND provider_name NOT IN 
		('Martirosyan, Bessy', 'Alexanian, Ruzanna',  'Karayan, Sooren', 'Samonte, Vladimir', 'Ter- Zakarian, Hovik', 'Ter-Zakarian, Hovanes', 'Walker, Bradley', 'Yeretzian, Arpee', 'Vega, Ana')
),final AS (
SELECT 
	p.PATIENTID,
	p.PATIENTPROFILEID,
	pn.note_datetime,
	phys.provider_name,
	phys.degree,
	dept.short_name,
	ROW_NUMBER() OVER(PARTITION BY p.patientprofileid ORDER BY pn.note_datetime DESC) AS rank_num
FROM 
	notes pn 
	JOIN patients p ON pn.patientprofileid = p.PATIENTPROFILEID
	JOIN cchc.pr1_view_all_department dept ON pn.dept_id = dept.departmentid
	JOIN view_activePhys_all phys ON pn.doctorid = phys.doctorid
WHERE
	pn.patientprofileid IN (SELECT patientprofileid FROM lastMonth)
	AND (CONVERT(date, pn.note_datetime) BETWEEN @startDate AND @endDate)
), cessationBilling AS (
	SELECT
		ch.patient_id
	FROM 
		cchc.charge_history ch
		JOIN (SELECT * FROM activeProcedure WHERE procedure_number IN(848,849)) cp ON ch.procedure_id = cp.procedure_id
	WHERE 
		CONVERT(date, ch.post_fromdate) BETWEEN @patientNoteStartDate AND @endDate
),latest AS (
	SELECT 
		provider_name,
		short_name,
		PATIENTID,
		note_datetime,
		IIF(final.PATIENTPROFILEID IN (SELECT patient_id FROM cessationBilling) OR dbo.getDataValuePrio(@patientNoteStartDate,final.PATIENTPROFILEID,CONVERT(date, note_datetime), 14451, '0') = '1' or dbo.getDataValuePrio(@patientNoteStartDate,final.PATIENTPROFILEID,CONVERT(date, note_datetime), 14375, '0') = '1', 1, 0) AS [Cessation Received],
		dbo.getDataValue(final.PATIENTPROFILEID,CONVERT(date, note_datetime), 14450) AS [Not Tobacco User],
		dbo.getDataValue(final.PATIENTPROFILEID,CONVERT(date, note_datetime), 14449) AS [Uses Tobacco],
		dbo.getTelehealthConsent(final.PATIENTPROFILEID, CONVERT(date, note_datetime)) AS [Patient Consent to Telehealth Visit],
		dbo.getTelephoneConsent(final.PATIENTPROFILEID, CONVERT(date, note_datetime)) AS [Patient Consent to Telephone Visit]
	FROM 
		final 
	WHERE 
		rank_num = 1
	
)
SELECT 
	provider_name AS Provider,
	short_name AS Clinic,
	PATIENTID AS [Patient ID],
	FORMAT(note_datetime, 'MM/dd/yyyy') AS DOS,
	IIF([Uses Tobacco] = '1' OR [Not Tobacco User] = '1', 1, 0) AS [Use Doc''d],
	COALESCE([Not Tobacco User], 0) AS [Not Tobacco User],
	COALESCE([Uses Tobacco], 0) AS [Uses Tobacco],
	(CASE 
		WHEN [Not Tobacco User] = '1' OR [Uses Tobacco] = '0' THEN 0
		ELSE COALESCE([Cessation Received], 0)
	END) AS [Cessation Received],
	(CASE
		WHEN [Not Tobacco User] = '1' THEN 'Y'
		WHEN [Uses Tobacco] = '1' AND [Cessation Received] = '1' THEN 'Y'
		ELSE 'N'
	END) AS Met,
	[Patient Consent to Telehealth Visit],
	[Patient Consent to Telephone Visit]
FROM latest 
ORDER BY provider_name,PATIENTID
