SET NOCOUNT ON;
DECLARE @startdate date, @lastdate date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @lastdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)

;WITH futureAppt AS (
SELECT
	appt.patientprofileid,
	appt.booking_date,
	vt.short_desc,
	phys.provider_name,
	appt.booked_by_date,
	appt.visit_type_id,
	appt.pat_discharged,
	appt.room_datetime,
	appt.examtime,
	apptstart,
	start_minutes,
	status
FROM
	cchc.pr1_view_patientappt appt
	JOIN view_activePhys phys ON appt.doctorid = phys.doctorid
	JOIN ops_visits vt ON appt.visit_type_id = vt.visit_type_id
WHERE
	CONVERT(date, appt.booked_by_date) BETWEEN @startdate AND @lastdate
	AND status <> 'cancelled'
), no_show_appt AS (
SELECT
	appt.start_minutes,
	appt.examtime,
	phys.provider_name,
	dept.short_name,
	p.PATIENTID,
	p.BIRTHDATE,
	p.PATIENTPROFILEID,
	appt.booking_date,
	appt.pat_discharged,
	vt.short_desc,
	appt.visit_type_id,
	appt.room_datetime,
	ROW_NUMBER() OVER(PARTITION BY p.patientprofileid ORDER BY appt.booking_date DESC) AS rn
FROM 
	cchc.pr1_view_patientappt appt
	JOIN cchc.pr1_view_patient p ON appt.patientprofileid = p.PATIENTPROFILEID
	JOIN view_activePhys phys ON appt.doctorid = phys.doctorid
	JOIN cchc.pr1_view_all_department dept ON appt.departmentid = dept.departmentid
	JOIN ops_visits vt ON appt.visit_type_id = vt.visit_type_id
WHERE
	appt.status IN ('no show')
	AND appt.booking_date BETWEEN @startdate AND @lastdate
), detail AS (
SELECT
	provider_name AS Provider,
	short_name AS Clinic,
	PATIENTID AS [Patient ID],
	FORMAT(BIRTHDATE, 'MM/dd/yyyy') AS DOB,
	FORMAT(booking_date, 'MM/dd/yyyy') AS [No Show Date],
	CONVERT(VARCHAR(5), DATEADD(MINUTE, no_show.start_minutes, '00:00'), 108) AS start,
	short_desc AS [Visit Type],
	(
	SELECT TOP 1 FORMAT(fa.booking_date,'MM/dd/yyyy')
	FROM futureAppt fa 
	WHERE 
		fa.patientprofileid = no_show.PATIENTPROFILEID
		AND CONVERT(date, fa.booked_by_date) >= CONVERT(date, no_show.booking_date)
		AND ((CONVERT(date, fa.booking_date) = CONVERT(date, no_show.booking_date) AND fa.start_minutes > no_show.start_minutes) OR (CONVERT(date, fa.booking_date) > CONVERT(date, no_show.booking_date)))
	ORDER BY
		fa.booked_by_date
	) AS [Rescheduled Date],
	(
	SELECT TOP 1 fa.short_desc
	FROM futureAppt fa 
	WHERE 
		fa.patientprofileid = no_show.PATIENTPROFILEID
		AND CONVERT(date, fa.booked_by_date) >= CONVERT(date, no_show.booking_date)
		AND ((CONVERT(date, fa.booking_date) = CONVERT(date, no_show.booking_date) AND fa.start_minutes > no_show.start_minutes) OR (CONVERT(date, fa.booking_date) > CONVERT(date, no_show.booking_date)))
	ORDER BY
		fa.booked_by_date
	) AS [Rescheduled Type],
	(
	SELECT TOP 1 fa.provider_name 
	FROM futureAppt fa 
	WHERE 
		fa.patientprofileid = no_show.PATIENTPROFILEID
		AND CONVERT(date, fa.booked_by_date) >= CONVERT(date, no_show.booking_date)
		AND ((CONVERT(date, fa.booking_date) = CONVERT(date, no_show.booking_date) AND fa.start_minutes > no_show.start_minutes) OR (CONVERT(date, fa.booking_date) > CONVERT(date, no_show.booking_date)))
	ORDER BY
		fa.booked_by_date
	) AS [Rescheduled Provider]
FROM
	no_show_appt no_show
)
SELECT
	Provider,
	Clinic,
	[Patient ID],
	DOB,
	[No Show Date],
	[Visit Type],
	ISNULL([Rescheduled Date], '') AS [Rescheduled Date],
	IIF([Rescheduled Date] = '', '', ISNULL([Rescheduled Type], '')) AS [Rescheduled Type],
	IIF([Rescheduled Date] = '', '', ISNULL([Rescheduled Provider], '')) AS [Rescheduled Provider]
FROM
	detail
ORDER BY
	Provider,
	Clinic,
	[Patient ID]