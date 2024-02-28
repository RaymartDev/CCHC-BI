SET NOCOUNT ON;
declare @startdate date, @lastdate date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @lastdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)

;WITH bookings AS (
SELECT
	appt.appointmentid,
	appt.patientprofileid,
	appt.booking_date,
	appt.departmentid,
	appt.doctorid,
	appt.cancel_comment,
	appt.cancelled_by,
	med.short_name,
	status,
	appt.start_minutes,
	phys.provider_name,
	p.PATIENTID,
	med.short,
	appt.disposition,
	appt.canceled,
	vt.short_desc
FROM
	cchc.pr1_view_patientappt appt
	JOIN cchc.pr1_view_patient p ON appt.patientprofileid = p.PATIENTPROFILEID
	JOIN ops_visits vt ON appt.visit_type_id = vt.visit_type_id
	JOIN cchc.pr1_view_all_department med ON appt.departmentid = med.departmentid
	JOIN view_activePhys phys ON appt.doctorid = phys.doctorid
WHERE
	(CONVERT(date, booking_date) BETWEEN @startdate AND @lastdate)
	AND status NOT IN ('booked', 'registered', 'confirmed')
	AND 
		description NOT LIKE '%nurse%'
		AND description NOT LIKE '%cpsp%'
		AND description NOT LIKE 'Walk IN%'
		AND description NOT LIKE 'Walk-IN%'
		AND short_desc NOT IN ('HOLIDAY','MEETING','PTO', 'ADMIN', 'DO NOT USE')
), futureAppt AS (
SELECT
	appt.appointmentid,
	appt.patientprofileid,
	appt.booking_date,
	appt.booked_by_date,
	status,
	short_desc,
	p.PATIENTID,
	appt.start_minutes,
	ROW_NUMBER() OVER(PARTITION BY p.patientprofileid ORDER BY booked_by_date DESC) AS rn
FROM
	cchc.pr1_view_patientappt appt
	JOIN cchc.pr1_view_patient p ON appt.patientprofileid = p.PATIENTPROFILEID
	JOIN ops_visits vt ON appt.visit_type_id = vt.visit_type_id
	JOIN cchc.pr1_view_all_department med ON appt.departmentid = med.departmentid
WHERE
	CONVERT(date, appt.booked_by_date) BETWEEN @startdate AND @lastdate
	AND 
		description NOT LIKE '%nurse%'
		AND description NOT LIKE '%cpsp%'
		AND description NOT LIKE 'Walk IN%'
		AND description NOT LIKE 'Walk-IN%'
		AND short_desc NOT IN ('HOLIDAY','MEETING','PTO', 'ADMIN', 'DO NOT USE')
), noShowReason AS (
SELECT 
	appointmentid,
	response_text
FROM cchc.pr1_view_patientapptresp
WHERE question = 'NO SHOW -  REASON'
), noShowReason1 AS (
SELECT 
	appointmentid,
	response_text
FROM cchc.pr1_view_patientapptresp
WHERE question = 'NO SHOW - 1ST ATTEMPT'
), noShowReason2 AS (
SELECT 
	appointmentid,
	response_text
FROM cchc.pr1_view_patientapptresp
WHERE question = 'NO SHOW - 2ND ATTEMPT'
), final AS (
SELECT 
	b.patientprofileid,
	b.appointmentid AS [Appointment ID],
	b.short_name AS Dept,
	b.provider_name AS Provider,
	b.PATIENTID AS [Patient ID],
	FORMAT(b.booking_date, 'MM/dd/yyyy') AS DOS,
	CASE
		WHEN b.status = 'cancelled' AND (b.cancelled_by = 37465493 OR b.disposition = 2) THEN 'Cancelled by Patient'
		WHEN b.status = 'cancelled' AND (b.cancelled_by <> 37465493 OR b.disposition = 3) THEN 'Cancelled by Doctor'
		WHEN b.status = 'booked' THEN 'Booked'
		WHEN b.status = 'no show' THEN 'No Show'
		WHEN b.status = 'appt kept' THEN 'Appt Kept'
		WHEN b.status = 'admitted' THEN 'Admitted'
		ELSE b.status
	END AS [Appt Status],
	b.canceled AS Cancelled,
	IIF(b.status NOT IN ('no show', 'cancelled'), '', 
		FORMAT(fa.booking_date, 'MM/dd/yyyy')
	) AS [Future Appt],
	IIF(b.status = 'appt kept', '', IIF(b.status = 'cancelled', IIF((b.cancel_comment IS NULL OR b.cancel_comment = '') AND (b.cancelled_by = 37465493), 'Cancelled on Patient Portal', ISNULL(b.cancel_comment, '')), ISNULL(b.cancel_comment, ''))) AS [Cancellation Reason],
	IIF(b.status = 'no show', IIF(TRIM(ns.response_text) = '-', '', ISNULL(ns.response_text, '')), '') AS [No Show Reason],
	IIF(b.status = 'appt kept', 0, 1) AS [Not Completed],
	IIF(b.status = 'no show', ISNULL(ns1.response_text, ''), '') AS [No Show 1st Comment],
	IIF(b.status = 'no show', ISNULL(ns2.response_text, ''), '') AS [No Show 2nd Comment],
	IIF(b.status NOT IN ('no show', 'cancelled', 'appt kept', 'booked'), 1, 0) AS Unknown,
	b.short,
	IIF(fa.booking_date IS NOT NULL AND b.status NOT IN ('no show', 'cancelled'), CONVERT(varchar, DATEDIFF(day, b.booking_date, fa.booking_date)) ,'') AS raw_day
FROM 
	bookings b
	LEFT JOIN futureAppt fa ON b.patientprofileid = fa.patientprofileid AND b.short_desc = fa.short_desc AND ((CONVERT(date, b.booking_date) < CONVERT(date, fa.booking_date)) OR (CONVERT(date, b.booking_date) = CONVERT(date, fa.booking_date) AND fa.start_minutes > b.start_minutes))
	LEFT JOIN noShowReason ns ON b.appointmentid = ns.appointmentid
	LEFT JOIN noShowReason1 ns1 ON b.appointmentid = ns1.appointmentid
	LEFT JOIN noShowReason2 ns2 ON b.appointmentid = ns2.appointmentid
	LEFT JOIN cchc.pr1_view_all_staff st ON b.cancelled_by = st.staffid
), raw AS (
SELECT 
	patientprofileid,
	[Appointment ID],
	Dept,
	Provider,
	[Patient ID],
	DOS,
	[Appt Status],
	Cancelled,
	ISNULL([Future Appt], '') AS [Future Appt],
	[Cancellation Reason],
	[No Show Reason],
	[No Show 1st Comment],
	[No Show 2nd Comment],
	Unknown,
	short,
	IIF(ISNULL([Future Appt], '') <> '' AND [Appt Status] IN ('No Show', 'Cancelled'),DATEDIFF(day, CONVERT(date, DOS), CONVERT(date, [Future Appt])),0) AS days
FROM final
WHERE
	raw_day = '' OR TRY_CONVERT(int, raw_day) >= 0
), final_raw AS (
SELECT *, ROW_NUMBER() OVER(PARTITION BY [Patient ID],[Appointment ID] ORDER BY days) AS rn_day
FROM raw
)
SELECT 
	[Appointment ID],
	Dept,
	[Patient ID],
	DOS,
	[Appt Status],
	Cancelled,
	[Future Appt],
	[Cancellation Reason],
	[No Show Reason],
	[No Show 1st Comment],
	[No Show 2nd Comment],
	Unknown,
	short
FROM final_raw 
WHERE 
	rn_day = 1
ORDER BY 
	[Appt Status], [Patient ID]