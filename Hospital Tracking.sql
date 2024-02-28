SET NOCOUNT ON;
DECLARE @startdate date, @lastdate date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @lastdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)

;WITH activeNotifications AS (
SELECT 
	notif.notification_id,
	FORMAT(notif.notif_date, 'MM/dd/yyyy') AS notif_date,
	notif.item_description,
	phys.provider_name,
	p.PATIENTID,
	dept.short,
	team_name,
	teamid,
	dept.short_name,
	IIF(notif.completed_flag = 1, 'Y', 'N') AS Completed,
	IIF(notif.completed_datetime IS NULL, '', FORMAT(notif.completed_datetime, 'MM/dd/yyyy')) AS Completed_Date,
	IIF(notif.completed_datetime IS NULL, '', dbo.BusinessDayDiff(CONVERT(date, notif.notif_date), CONVERT(date, notif.completed_datetime))) AS days
FROM 
	cchc.pr1_notification notif
	JOIN cchc.pr1_notification_rule notifR ON notif.notification_rule_id = notifR.notification_rule_id AND notifR.active_flag = 1
	JOIN cchc.pr1_view_patient p ON notif.patientprofileid = p.PATIENTPROFILEID
	JOIN view_activePhys phys ON notif.doctorid = phys.doctorid
	JOIN cchc.pr1_view_all_department dept ON notif.deptid = dept.departmentid
WHERE 
	notif.company_id = 9
	AND teamid IN (8961, 8962)
	AND CONVERT(date, notif_date) BETWEEN @startdate AND @lastdate
)
SELECT 
	PATIENTID AS [Patient ID],
	notification_id AS [Notification ID],
	notif_date AS [Notification Date],
	item_description AS [Template Name],
	provider_name AS Provider,
	short AS Department,
	Completed AS [Notification Completed],
	Completed_Date AS [Completed Date],
	days AS [Days to Complete],
	CASE
		WHEN Completed_Date = '' THEN 'N'
		WHEN days > 10 THEN 'N'
		ELSE 'Y'
	END AS Met,
	CASE
		WHEN Completed_Date = '' THEN 'N'
		WHEN days > 2 THEN 'N'
		ELSE 'Y'
	END AS Met2,
	short_name,
	TRIM(team_name) AS team_name,
	teamid
FROM activeNotifications