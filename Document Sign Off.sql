SET NOCOUNT ON;
declare @startdate date, @lastdate date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @lastdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)

;WITH documents AS (
	SELECT 
		document_id, 
		patientprofileid,
		doctorid,
		file_name,
		doc_date,
		update_datetime,
		staffid,
		created_date,
		signedby,
		dept_id
	FROM 
		cchc.pr1_document
	WHERE 
		CONVERT(date, doc_date) BETWEEN @startdate AND @lastdate
		AND doc_type_id IN (SELECT lookup_id
							FROM cchc.pr1_lookups 
							WHERE 
								lookup_item IN('BCP', 'Consult Report', 'Health Assessment', 'History & Physical', 'Hospital Record', 'Lab', 'Old Clinical Notes', 'SOAP Note', 'X-Ray/Ultrasound'))
), detail AS (
	SELECT 
		phys.provider_name AS Provider,
		dept.short_name AS Clinic,
		p.PATIENTID AS [Patient ID],
		d.created_date AS [Import Date],
		d.update_datetime AS [SignOff Date],
		d.doc_date,
		d.file_name,
		d.document_id,
		staff.fullname
	FROM 
		documents d
		JOIN cchc.pr1_view_patient p ON d.patientprofileid = p.PATIENTPROFILEID
		JOIN view_activePhys phys ON d.doctorid = phys.doctorid
		JOIN cchc.pr1_view_all_department dept ON d.dept_id = dept.departmentid
		LEFT JOIN cchc.pr1_view_all_staff staff ON d.signedby = staff.staffid
), final AS (
	SELECT
		Provider,
		CASE
			WHEN fullname IS NULL THEN 'N'
			WHEN dbo.BusinessDayDiff(CONVERT(date, [Import Date]), CONVERT(date,doc_date)) <= 3 THEN 'Y'
			ELSE 'N'
		END AS [Signed within 3 days],
		CASE
			WHEN fullname IS NULL THEN 'N'
			WHEN dbo.BusinessDayDiff(CONVERT(date, [Import Date]), CONVERT(date,doc_date)) <= 5 THEN 'Y'
			ELSE 'N'
		END AS [Signed within 5 days],
		IIF(fullname IS NULL, 'N', 'Y') AS Signed,
		Clinic,
		[Patient ID],
		FORMAT(doc_date, 'MM/dd/yyyy') AS [Doc Date],
		document_id AS [Document ID],
		FORMAT([Import Date], 'MM/dd/yyyy') AS [Import Date],
		IIF(fullname IS NULL, '', FORMAT([SignOff Date], 'MM/dd/yyyy')) AS [SignOff Date],
		COALESCE(fullname, '') AS [Signed By],
		file_name AS [File Name]
	FROM detail
)
SELECT * FROM 
final ORDER BY Provider, [Patient ID]