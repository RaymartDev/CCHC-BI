SET NOCOUNT ON;
DECLARE @startdate date, @lastdate date, @lastYear date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @lastdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)
set @lastYear = CAST(DATEADD(YEAR, -1, @lastdate) as date)

;WITH patientBase AS (
	SELECT 
		p.PATIENTPROFILEID,
		p.PATIENTID,
		p.age,
		p.BIRTHDATE
	FROM
		cchc.pr1_view_patient p
	WHERE
		age >= 18
		AND rn = 1
), pregnantPt AS (
	SELECT 
		ch.patient_id,
		ch.post_fromdate
	FROM 
		cchc.charge_history ch
		JOIN (
			SELECT * FROM activeDiagnosis
			WHERE icd9 IN (
				'Z34', 'Z34.0', 'Z34.00', 'Z34.01', 'Z34.02', 'Z34.03', 'Z34.8', 'Z34.80', 'Z34.81', 'Z34.82',
				'Z34.83', 'Z34.9', 'Z34.90', 'Z34.91', 'Z34.92', 'Z34.93'
			)
		) cd ON ch.diagnosis_id_1 = cd.diagnosis_id OR ch.diagnosis_id_2 = cd.diagnosis_id OR ch.diagnosis_id_3 = cd.diagnosis_id OR ch.diagnosis_id_4 = cd.diagnosis_id
	WHERE 
		CONVERT(DATE, ch.post_fromdate) BETWEEN @lastYear AND @lastdate
), visits AS (
	SELECT 
		p.PATIENTPROFILEID,
		p.PATIENTID,
		p.age,
		phys.provider_name,
		pn.note_datetime,
		ROW_NUMBER() OVER(PARTITION BY p.patientprofileid ORDER BY pn.note_datetime DESC) AS rn
	FROM
		cchc.view_medical_note_full pn 
		JOIN patientBase p ON pn.patientprofileid = p.PATIENTPROFILEID
		JOIN activeMedicalPhys phys ON pn.doctorid = phys.doctorid
	WHERE
		CONVERT(date, pn.note_datetime) BETWEEN @startdate AND @lastdate
		AND pn.patientprofileid NOT IN (SELECT t2.patient_id FROM pregnantPt t2)
		AND phys.provider_name <> 'Galstyan, Kevin'
), final AS (
SELECT
	provider_name AS Provider,
	PATIENTID AS [Patient ID],
	age AS Age, 
	ISNULL(dbo.getDataValueExact(PATIENTPROFILEID,CONVERT(date, note_datetime), 1719), '') AS [Last BMI],
	IIF(dbo.getDataValueExact(PATIENTPROFILEID,CONVERT(date, note_datetime), 1719) IS NULL, 0,1) AS [BMI Recorded],
	IIF(dbo.getDataValueExact(PATIENTPROFILEID,CONVERT(date, note_datetime), 1719) IS NULL, 1, IIF(CONVERT(decimal(10,2), dbo.getDataValueMod(PATIENTPROFILEID,@startdate,@lastdate, 1719)) BETWEEN 18.5 AND 24.9, 0,1)) AS [Out Of Range],
	ISNULL(CONVERT(int, dbo.getDataValueExact(PATIENTPROFILEID,CONVERT(date, note_datetime), 14466)), 0) AS [Wt Mgmt F/u Plan],
	dbo.getTelehealthConsent(PATIENTPROFILEID, CONVERT(date, note_datetime)) AS [Patient Consents to Telehealth Visit],
	dbo.getTelephoneConsent(PATIENTPROFILEID, CONVERT(date, note_datetime)) AS [Patient Consents to TelePhone Visit]
FROM visits 
WHERE rn = 1
)
SELECT 
	Provider,
	[Patient ID],
	Age,
	[Last BMI], 
	[BMI Recorded],
	[Out Of Range],
	[Wt Mgmt F/u Plan],
	CASE 
		WHEN [BMI Recorded] = 0 THEN 'N'
		WHEN [BMI Recorded] = 1 AND [Out Of Range] = 1 AND [Wt Mgmt F/u Plan] = 0 THEN 'N'
		ELSE 'Y'
	END AS Documented,
	[Patient Consents to Telehealth Visit],
	[Patient Consents to TelePhone Visit]
FROM final
ORDER BY Provider, [Patient ID]