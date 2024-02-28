SET NOCOUNT ON;

declare @startdate date, @endd date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @endd = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)

;WITH filtered_notes AS (
	SELECT 
		appt.appointmentid
	FROM
		cchc.pr1_view_patientappt appt
		JOIN view_activePhys phys ON appt.doctorid = phys.doctorid
	WHERE
		CONVERT(date, appt.booking_date) BETWEEN @startdate AND @endd
		AND (
			(phys.provider_name = 'Ghanevati, Mahin' AND (DATEPART(weekday,appt.booking_date) = 3 AND DATEPART(hour, appt.booking_date) > 18))
			AND (phys.provider_name = 'Solarte, David' AND (DATEPART(weekday, appt.booking_date) IN (3,5) AND DATEPART(hour, appt.booking_date) > 17 AND DATEPART(MINUTE, appt.booking_date) >= 30))
			AND (phys.provider_name = 'Cayago, Rachelle' AND (DATEPART(weekday, appt.booking_date) IN (3,5) AND DATEPART(hour, appt.booking_date) > 17 AND DATEPART(MINUTE, appt.booking_date) >= 30))
			AND (phys.provider_name = 'Barraza, Henry' AND (DATEPART(weekday, appt.booking_date) IN (2,4,5) AND DATEPART(hour, appt.booking_date) > 19 AND DATEPART(MINUTE, appt.booking_date) >= 30))
			AND (phys.provider_name = 'Manoukian, Arthur' AND (DATEPART(weekday, appt.booking_date) IN (2,3,4,5,6) AND DATEPART(hour, appt.booking_date) > 19))
			AND (phys.provider_name = 'Godes, Irina' AND (DATEPART(weekday, appt.booking_date) IN (3,4) AND DATEPART(hour, appt.booking_date) > 19))
			AND (phys.provider_name = 'Michael, Manar' AND (DATEPART(weekday, appt.booking_date) IN (3,4) AND DATEPART(hour, appt.booking_date) > 19))
			AND (phys.provider_name = 'Justiniani, Mary' AND (DATEPART(weekday, appt.booking_date) IN (2,3,4,5,6) AND DATEPART(hour, appt.booking_date) > 18) AND DATEPART(minute, appt.booking_date) >= 30)
		)
), detail AS (
SELECT DISTINCT
	sb.superbill_datetime,
	p.PATIENTID,
	IIF(sb.signedby <= 0, 0, 1) AS signed,
	dept.short_name AS Clinic,
	phys.provider_name AS Provider,
	sb.created_date,
	sb.update_datetime,
	vt.description
FROM
	cchc.pr1_superbill sb
	JOIN cchc.pr1_view_patient p ON sb.patientprofileid = p.PATIENTPROFILEID
	JOIN (SELECT * FROM cchc.pr1_view_patientappt WHERE appointmentid NOT IN (SELECT t2.appointmentid FROM filtered_notes t2)) appt2 on sb.appointmentid=appt2.appointmentid
	JOIN (
	SELECT * FROM valid_visits
		UNION
	SELECT * FROM cchc.pr1_view_all_visittype
	WHERE visit_type_id IN (53915600,53915594,58788109,58788107)
	) vt ON appt2.visit_type_id = vt.visit_type_id
	JOIN cchc.pr1_view_all_department dept ON sb.dept_id = dept.departmentid
	JOIN view_activePhys phys ON sb.doctorid = phys.doctorid OR sb.doctor2id = phys.doctorid AND provider_name not like '%cpsp%'
WHERE
	CONVERT(date, sb.created_date) BETWEEN @startdate AND @endd
	AND appt2.status = 'appt kept'
	AND vt.description not  like '%cpsp%' 
	AND vt.description not  like 'OB%' 
	AND vt.description not  like 'nurse%' 
	AND vt.description not  like 'cm%' 
	AND vt.description not  like 'dental%' 
	AND vt.description not  like 'mat%' 
), final AS (
SELECT
	signed,
	Clinic,
	Provider,
	PATIENTID AS [Patient ID],
	FORMAT(created_date, 'MM/dd/yyyy') AS [Start Date],
	FORMAT(update_datetime, 'MM/dd/yyyy') AS [Signedoff Date],
	description,
	IIF(dbo.BusinessDayDiff(CONVERT(date, created_date), CONVERT(date,update_datetime)) <= 1, 'Y', 'N') AS METGOAL
FROM
	detail
)
SELECT * FROM final
ORDER BY Clinic, Provider, [Patient ID]