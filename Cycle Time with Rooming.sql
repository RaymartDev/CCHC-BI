SET NOCOUNT ON;
declare @startdate date, @endd date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @endd = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)
;WITH arrived AS(
SELECT *, ROW_NUMBER() OVER(PARTITION BY bookings_id ORDER BY appt_tracking_id DESC) AS rn
FROM cchc.appt_tracking WHERE tracking_type = 'Arrived' AND active_yn = 'Y'
), registered AS(
SELECT *, ROW_NUMBER() OVER(PARTITION BY bookings_id ORDER BY appt_tracking_id DESC) AS rn
FROM cchc.appt_tracking WHERE tracking_type = 'Registered' AND active_yn = 'Y'
), admitted AS(
SELECT *, ROW_NUMBER() OVER(PARTITION BY bookings_id ORDER BY appt_tracking_id DESC) AS rn
FROM cchc.appt_tracking WHERE tracking_type = 'Admitted' AND active_yn = 'Y'
), discharged AS(
SELECT *, ROW_NUMBER() OVER(PARTITION BY bookings_id ORDER BY appt_tracking_id DESC) AS rn
FROM cchc.appt_tracking WHERE tracking_type = 'Discharged' AND active_yn = 'Y'
), provIn AS(
SELECT *, ROW_NUMBER() OVER(PARTITION BY bookings_id ORDER BY appt_tracking_id DESC) AS rn
FROM cchc.appt_tracking WHERE tracking_type = 'PROV IN' AND active_yn = 'Y'
), xm AS(
SELECT *, ROW_NUMBER() OVER(PARTITION BY bookings_id ORDER BY appt_tracking_id DESC) AS rn
FROM cchc.appt_tracking WHERE tracking_type = 'XM COMP' AND active_yn = 'Y'
), final AS (
SELECT 
	appt.appointmentid,
	p.PATIENTID,
	md.short_name,
	CONCAT(p.LAST, ', ', p.FIRST) AS fullname,
	appt.booking_date,
	vt.description,
	'med' AS Type,
	phys.provider_name,
	IIF(reg.start_datetime is null or arr.start_datetime is null, -1, CONVERT(int,abs(datediff(mi, arr.start_datetime, reg.start_datetime)))) AS [Arrived To Registered],
	IIF(reg.start_datetime is null or ad.start_datetime is null, -1, CONVERT(int,abs(datediff(mi, reg.start_datetime, ad.start_datetime)))) AS [Registered To Admitted],
	IIF(ad.start_datetime is null or pi.start_datetime is null, -1, CONVERT(int,abs(datediff(mi, ad.start_datetime, pi.start_datetime)))) AS [Admitted To Provider In],
	IIF(xm.start_datetime is null or pi.start_datetime is null, -1, CONVERT(int,abs(datediff(mi, pi.start_datetime, xm.start_datetime)))) AS [Provider In To Exam Complete],
	IIF(xm.start_datetime is null or dc.start_datetime is null, -1, CONVERT(int,abs(datediff(mi, xm.start_datetime, dc.start_datetime)))) AS [Exam Complete To Discharge],
	DATEDIFF(mi, appt.pat_arrived, appt.pat_discharged) as [Total Cycle Time],
	DATEDIFF(mi, appt.pat_registered, appt.pat_discharged) as [Total Telehealth Cycle Time],
	IIF(vt.description LIKE '%telehealth%' OR vt.description LIKE 'phone%', 1,0) AS Telehealth,
	ROW_NUMBER() OVER(PARTITION BY p.PATIENTPROFILEID ORDER BY appt.booking_date DESC) AS rn
FROM 
	cchc.pr1_view_patientappt appt
	JOIN cchc.pr1_view_patient p ON appt.patientprofileid = p.PATIENTPROFILEID
	JOIN view_activePhys phys ON appt.doctorid = phys.doctorid
	JOIN cchc.pr1_view_all_department md ON appt.departmentid = md.departmentid
	JOIN ops_visits vt  ON appt.visit_type_id = vt.visit_type_id
	LEFT JOIN (SELECT * FROM arrived WHERE rn = 1) arr ON appt.appointmentid = arr.bookings_id
	LEFT JOIN (SELECT * FROM registered WHERE rn = 1) reg ON appt.appointmentid = reg.bookings_id
	LEFT JOIN (SELECT * FROM admitted WHERE rn = 1) ad ON appt.appointmentid = ad.bookings_id
	LEFT JOIN (SELECT * FROM discharged WHERE rn = 1) dc ON appt.appointmentid = dc.bookings_id
	LEFT JOIN (SELECT * FROM provIn WHERE rn = 1) pi ON appt.appointmentid = pi.bookings_id
	LEFT JOIN (SELECT * FROM xm WHERE rn = 1) xm ON appt.appointmentid = xm.bookings_id
WHERE
	CONVERT(date, appt.booking_date) BETWEEN @startdate AND @endd
	AND appt.status = 'appt kept'
	AND 
		vt.description NOT LIKE 'Behavioral Health%'
		AND vt.description NOT LIKE 'BH%'
		AND vt.description NOT LIKE 'opt%'
), final2 AS (
SELECT 
	appt.appointmentid,
	p.PATIENTID,
	md.short_name,
	CONCAT(p.LAST, ', ', p.FIRST) AS fullname,
	appt.booking_date,
	vt.description,
	'bh' AS Type,
	phys.provider_name,
	IIF(reg.start_datetime is null or arr.start_datetime is null, -1, CONVERT(int,abs(datediff(mi, arr.start_datetime, reg.start_datetime)))) AS [Arrived To Registered],
	IIF(reg.start_datetime is null or ad.start_datetime is null, -1, CONVERT(int,abs(datediff(mi, reg.start_datetime, ad.start_datetime)))) AS [Registered To Admitted],
	IIF(ad.start_datetime is null or pi.start_datetime is null, -1, CONVERT(int,abs(datediff(mi, ad.start_datetime, pi.start_datetime)))) AS [Admitted To Provider In],
	IIF(xm.start_datetime is null or pi.start_datetime is null, -1, CONVERT(int,abs(datediff(mi, pi.start_datetime, xm.start_datetime)))) AS [Provider In To Exam Complete],
	IIF(xm.start_datetime is null or dc.start_datetime is null, -1, CONVERT(int,abs(datediff(mi, xm.start_datetime, dc.start_datetime)))) AS [Exam Complete To Discharge],
	DATEDIFF(mi, appt.pat_arrived, appt.pat_discharged) as [Total Cycle Time],
	DATEDIFF(mi, appt.pat_registered, appt.pat_discharged) as [Total Telehealth Cycle Time],
	IIF(vt.description LIKE '%telehealth%' OR vt.description LIKE 'phone%', 1,0) AS Telehealth,
	ROW_NUMBER() OVER(PARTITION BY p.PATIENTPROFILEID ORDER BY appt.booking_date DESC) AS rn
FROM 
	cchc.pr1_view_patientappt appt
	JOIN cchc.pr1_view_patient p ON appt.patientprofileid = p.PATIENTPROFILEID
	JOIN view_activePhys phys ON appt.doctorid = phys.doctorid
	JOIN cchc.pr1_view_all_department md ON appt.departmentid = md.departmentid
	JOIN ops_visits vt  ON appt.visit_type_id = vt.visit_type_id
	LEFT JOIN (SELECT * FROM arrived WHERE rn = 1) arr ON appt.appointmentid = arr.bookings_id
	LEFT JOIN (SELECT * FROM registered WHERE rn = 1) reg ON appt.appointmentid = reg.bookings_id
	LEFT JOIN (SELECT * FROM admitted WHERE rn = 1) ad ON appt.appointmentid = ad.bookings_id
	LEFT JOIN (SELECT * FROM discharged WHERE rn = 1) dc ON appt.appointmentid = dc.bookings_id
	LEFT JOIN (SELECT * FROM provIn WHERE rn = 1) pi ON appt.appointmentid = pi.bookings_id
	LEFT JOIN (SELECT * FROM xm WHERE rn = 1) xm ON appt.appointmentid = xm.bookings_id
WHERE
	CONVERT(date, appt.booking_date) BETWEEN @startdate AND @endd
	AND appt.status = 'appt kept'
	AND 
		(vt.description LIKE 'bh%' 
		OR vt.description LIKE 'behavioral%')
), final3 AS (
SELECT 
	appt.appointmentid,
	p.PATIENTID,
	md.short_name,
	CONCAT(p.LAST, ', ', p.FIRST) AS fullname,
	appt.booking_date,
	vt.description,
	'opt' AS Type,
	phys.provider_name,
	IIF(reg.start_datetime is null or arr.start_datetime is null, -1, CONVERT(int,abs(datediff(mi, arr.start_datetime, reg.start_datetime)))) AS [Arrived To Registered],
	IIF(reg.start_datetime is null or ad.start_datetime is null, -1, CONVERT(int,abs(datediff(mi, reg.start_datetime, ad.start_datetime)))) AS [Registered To Admitted],
	IIF(ad.start_datetime is null or pi.start_datetime is null, -1, CONVERT(int,abs(datediff(mi, ad.start_datetime, pi.start_datetime)))) AS [Admitted To Provider In],
	IIF(xm.start_datetime is null or pi.start_datetime is null, -1, CONVERT(int,abs(datediff(mi, pi.start_datetime, xm.start_datetime)))) AS [Provider In To Exam Complete],
	IIF(xm.start_datetime is null or dc.start_datetime is null, -1, CONVERT(int,abs(datediff(mi, xm.start_datetime, dc.start_datetime)))) AS [Exam Complete To Discharge],
	DATEDIFF(mi, appt.pat_arrived, appt.pat_discharged) as [Total Cycle Time],
	DATEDIFF(mi, appt.pat_registered, appt.pat_discharged) as [Total Telehealth Cycle Time],
	IIF(vt.description LIKE '%telehealth%' OR vt.description LIKE 'phone%', 1,0) AS Telehealth,
	ROW_NUMBER() OVER(PARTITION BY p.PATIENTPROFILEID ORDER BY appt.booking_date DESC) AS rn
FROM 
	cchc.pr1_view_patientappt appt
	JOIN cchc.pr1_view_patient p ON appt.patientprofileid = p.PATIENTPROFILEID
	JOIN view_activePhys phys ON appt.doctorid = phys.doctorid
	JOIN cchc.pr1_view_all_department md ON appt.departmentid = md.departmentid
	JOIN ops_visits vt  ON appt.visit_type_id = vt.visit_type_id
	LEFT JOIN (SELECT * FROM arrived WHERE rn = 1) arr ON appt.appointmentid = arr.bookings_id
	LEFT JOIN (SELECT * FROM registered WHERE rn = 1) reg ON appt.appointmentid = reg.bookings_id
	LEFT JOIN (SELECT * FROM admitted WHERE rn = 1) ad ON appt.appointmentid = ad.bookings_id
	LEFT JOIN (SELECT * FROM discharged WHERE rn = 1) dc ON appt.appointmentid = dc.bookings_id
	LEFT JOIN (SELECT * FROM provIn WHERE rn = 1) pi ON appt.appointmentid = pi.bookings_id
	LEFT JOIN (SELECT * FROM xm WHERE rn = 1) xm ON appt.appointmentid = xm.bookings_id
WHERE
	CONVERT(date, appt.booking_date) BETWEEN @startdate AND @endd
	AND appt.status = 'appt kept'
	AND description LIKE 'opt%'
)
SELECT 
	short_name AS Clinic,
	provider_name AS Provider,
	PATIENTID AS [Patient ID],
	FORMAT(booking_date, 'MM/dd/yyyy') AS DOS,
	description AS [Visit Type],
	[Arrived To Registered],
	[Registered To Admitted],
	[Admitted To Provider In],
	[Provider In To Exam Complete],
	[Exam Complete To Discharge],
	[Total Cycle Time],
	[Total Telehealth Cycle Time],
	appointmentid AS [Appt Id],
	Type,
	Telehealth
FROM
	final
UNION
SELECT 
	short_name AS Clinic,
	provider_name AS Provider,
	PATIENTID AS [Patient ID],
	FORMAT(booking_date, 'MM/dd/yyyy') AS DOS,
	description AS [Visit Type],
	[Arrived To Registered],
	[Registered To Admitted],
	[Admitted To Provider In],
	[Provider In To Exam Complete],
	[Exam Complete To Discharge],
	[Total Cycle Time],
	[Total Telehealth Cycle Time],
	appointmentid AS [Appt Id],
	Type,
	Telehealth
FROM
	final2
UNION
SELECT 
	short_name AS Clinic,
	provider_name AS Provider,
	PATIENTID AS [Patient ID],
	FORMAT(booking_date, 'MM/dd/yyyy') AS DOS,
	description AS [Visit Type],
	[Arrived To Registered],
	[Registered To Admitted],
	[Admitted To Provider In],
	[Provider In To Exam Complete],
	[Exam Complete To Discharge],
	[Total Cycle Time],
	[Total Telehealth Cycle Time],
	appointmentid AS [Appt Id],
	Type,
	Telehealth
FROM
	final3
ORDER BY 
	Type,Clinic,Provider,[Patient ID]