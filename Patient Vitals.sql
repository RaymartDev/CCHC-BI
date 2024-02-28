SET NOCOUNT ON;
declare @start date, @last date, @noteStart date
set @start = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)  
set @last = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)
set @noteStart = CAST(DATEADD(year, -1, @start) as date)

;WITH patients_info AS (
    SELECT 
		PATIENTID,
		PATIENTPROFILEID,
		age
	FROM cchc.pr1_view_patient p
	WHERE (rn = 1) AND p.age >= 3

), first_note AS (
	SELECT 
		patientprofileid,
		dept_id,
		doctorid,
		note_datetime
	FROM cchc.pr1_patient_note pn
	JOIN cchc.pr1_template pt ON pn.template_id = pt.template_id
	WHERE (template_name LIKE 'gyn%' OR template_name LIKE 'ob%' OR template_name LIKE 'opto%' OR template_name LIKE 'podia%') AND (CONVERT(DATE, pn.note_datetime) BETWEEN @start AND @last)

),filtered_notes AS (
	SELECT 
		pn.patient_note_id
	FROM
		cchc.view_medical_note_full pn
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
), final_note AS (
	SELECT
		patientprofileid,
		dept_id,
		doctorid,
		note_datetime
	FROM (SELECT * FROM cchc.view_medical_note_full  WHERE patient_note_id NOT IN(SELECT t2.patient_note_id FROM filtered_notes t2)) pn
	WHERE (CONVERT(DATE, note_datetime) BETWEEN @start AND @last)
), med_note AS (
	SELECT 
		dept.short_name AS Clinic,
		phys.provider_name AS Provider,
		p.PATIENTID AS [Patient ID],
		p.age AS Age,
		FORMAT(pn.note_datetime, 'MM/dd/yyyy') AS DOS,
		dbo.getDataValueExact(p.PATIENTPROFILEID, CONVERT(DATE, pn.note_datetime), 1716) AS Height,
		dbo.getDataValueExact(p.PATIENTPROFILEID, CONVERT(DATE, pn.note_datetime), 1717) AS Weight,
		dbo.getDataValueExact(p.PATIENTPROFILEID, CONVERT(DATE, pn.note_datetime), 12848) AS BP,
		dbo.getDataValueExact(p.PATIENTPROFILEID, CONVERT(DATE, pn.note_datetime), 1347) AS Temperature,
		dbo.getDataValueExact(p.PATIENTPROFILEID, CONVERT(DATE, pn.note_datetime), 11253) AS Pulse,
		dbo.getDataValueExact(p.PATIENTPROFILEID, CONVERT(DATE, pn.note_datetime), 11254) AS Respiratory,
		dbo.getTelehealthConsent(p.PATIENTPROFILEID, CONVERT(DATE, pn.note_datetime)) AS [Patient Consents to Telehealth Visit],
		dbo.getTelephoneConsent(p.PATIENTPROFILEID, CONVERT(DATE, pn.note_datetime)) AS [Patient Consents to TelePhone Visit],
		ROW_NUMBER() OVER(PARTITION BY p.patientprofileid ORDER BY pn.note_datetime DESC) AS rn
	FROM 
		(SELECT * FROM first_note
		UNION SELECT * FROM final_note) pn
		JOIN patients_info p ON pn.patientprofileid = p.PATIENTPROFILEID
		JOIN cchc.pr1_view_all_department dept ON pn.dept_id = dept.departmentid
		JOIN (SELECT * FROM view_activePhys_all WHERE provider_name NOT LIKE '%cpsp%') phys ON pn.doctorid = phys.doctorid
	WHERE 
		(CONVERT(DATE, note_datetime) BETWEEN  @start and @last)
)

SELECT
	Clinic,
	Provider,
	[Patient ID],
	Age,
	DOS,
	IIF(Height IS NULL OR Weight IS NULL OR BP IS NULL OR Temperature IS NULL OR Pulse IS NULL OR Respiratory IS NULL, 'N','Y') AS MET,
	IIF(Height IS NULL, 0, 1) AS Height,
	IIF(Weight IS NULL, 0, 1) AS Weight,
	IIF(BP IS NULL, 0, 1) AS BP,
	IIF(Temperature IS NULL, 0, 1) AS Temperature,
	IIF(Pulse IS NULL, 0, 1) AS Pulse,
	IIF(Respiratory IS NULL, 0, 1) AS Respiratory,
	[Patient Consents to Telehealth Visit],
	[Patient Consents to TelePhone Visit]
FROM med_note
WHERE rn = 1
ORDER BY Clinic, Provider, [Patient ID]