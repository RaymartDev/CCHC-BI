SET NOCOUNT ON;
declare @startdate date, @lastdate date, @lastYear date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @lastdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)
set @lastYear = CAST(DATEADD(YEAR, -1, @startdate) as date)

;WITH dentalPatients AS (
	SELECT 
		p.PATIENTPROFILEID,
		p.PATIENTID,
		dept.short_name,
		ch.post_fromdate,
		CONCAT(phys.last_name, ', ', phys.first_name) AS provider_name,
		cp.procedure_code,
		CASE
			WHEN age2 >= 0 and age2 <= 5 THEN 'A. 0 to 5'
			WHEN age2 >= 6 and age2 <= 13 THEN 'B. 6 to 13'
			WHEN age2 >= 14 and age2 <= 21 THEN 'C. 14 to 21'
			WHEN age2 >= 22 THEN 'D. 22 and Up'
		END AS [Age Range],
		ROW_NUMBER() OVER(PARTITION BY ch.patient_id ORDER BY CONVERT(date,ch.post_fromdate) DESC) rn
	FROM
		cchc.pr1_view_chargehistory ch
		JOIN cchc.pr1_view_patient p ON ch.patient_id = p.PATIENTPROFILEID
		JOIN (SELECT * FROM activeProcedure WHERE procedure_code IN ('D0120', 'D0145', 'D0150')) cp ON ch.procedure_id = cp.procedure_id
		JOIN (SELECT * FROM cchc.physician WHERE degree IN('DMD', 'DDS') and active_yn = 'Y') phys ON ch.physician_id = phys.phys_id OR ch.physician_id_2 = phys.phys_id
		JOIN (SELECT * FROM cchc.pr1_view_all_department WHERE listname LIKE '%dental%' and not listname like 'zz%') dept ON ch.department_id = dept.departmentid
	WHERE
		CONVERT(date, ch.post_fromdate) BETWEEN @lastYear AND @lastdate
		AND ch.status IN (0, 1)
), dentalPatients2 AS (
	SELECT 
		ch.patient_id
	FROM
		cchc.pr1_view_chargehistory ch
		JOIN cchc.pr1_view_patient p ON ch.patient_id = p.PATIENTPROFILEID
		JOIN (SELECT * FROM activeProcedure WHERE procedure_code IN ('C9011')) cp ON ch.procedure_id = cp.procedure_id
		JOIN (SELECT * FROM view_activePhys WHERE degree IN('DMD', 'DDS') and active_yn = 'Y') phys ON ch.physician_id = phys.doctorid OR ch.physician_id_2 = phys.doctorid
		JOIN (SELECT * FROM cchc.pr1_view_all_department WHERE listname LIKE '%dental%' and not listname like 'zz%') dept ON ch.department_id = dept.departmentid
	WHERE
		CONVERT(date, ch.post_fromdate) BETWEEN @lastYear AND @lastdate
)
SELECT 
	provider_name AS [Exam Provider],
	patientid AS [Patient ID],
	[Age Range],
	short_name AS Clinic,
	FORMAT(post_fromdate, 'MM/dd/yyyy') AS [Exam Date],
	procedure_code AS [Procedure Code],
	IIF(PATIENTPROFILEID IN (SELECT patient_id FROM dentalPatients2), 1, 0) AS Met
FROM dentalPatients
WHERE rn = 1
ORDER BY
	provider_name,
	[Age Range],
	PATIENTID
OPTION (FORCE ORDER)