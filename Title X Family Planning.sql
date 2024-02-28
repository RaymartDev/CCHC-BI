SET NOCOUNT ON;
declare @startdate date, @lastdate date, @lastYear date
set @startdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0) as date)
set @lastdate = CAST(DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) as date)
set @lastYear = CAST(DATEADD(YEAR, -1, @startdate) as date)
;WITH activePatients AS (
	SELECT *,DATEDIFF(hour,birth_date,GETDATE())/8766 AS age,ROW_NUMBER() OVER(PARTITION BY patient_id ORDER BY modified_date DESC) AS rn FROM cchc.patient WHERE active_yn = 'Y' and deleted_yn <> 'Y' and company_id = 9
), titleXVisits AS (
	SELECT 
		pn.PATIENTPROFILEID,
		CAST(pn.note_datetime as date) AS DOS,
		pn.note_datetime,
		pnc.data_value
	FROM 
		cchc.pr1_patient_note pn 
		JOIN cchc.pr1_template pt ON pn.template_id = pt.template_id
		JOIN cchc.pr1_patient_note_control pnc ON pn.patient_note_id = pnc.patient_note_id
	WHERE 
		pnc.template_field_id IN(7220)
		AND (YEAR(pn.note_datetime) = YEAR(@startdate))
		AND pnc.data_value IS NOT NULL AND TRIM(pnc.data_value) <> ''
), filter AS (
	SELECT 
		dev_ch.patient_id,
		dev_ch.post_fromdate,
		ROW_NUMBER() OVER(PARTITION BY dev_ch.patient_id ORDER BY dev_ch.post_fromdate DESC) AS rn
	FROM 
		(SELECT * FROM cchc.charge_history WHERE CONVERT(date, post_fromdate) BETWEEN @lastYear AND @lastdate) AS dev_ch 
		INNER JOIN activeDiagnosis AS dev_d ON dev_d.diagnosis_id = dev_ch.diagnosis_id_1 OR dev_d.diagnosis_id = dev_ch.diagnosis_id_2 OR dev_d.diagnosis_id = dev_ch.diagnosis_id_3 OR 
                                                      dev_d.diagnosis_id = dev_ch.diagnosis_id_4
		INNER JOIN activeProcedure AS dev_cp ON dev_ch.procedure_id = dev_cp.procedure_id
	WHERE
		dev_cp.procedure_code IN ('1965','1966','59100','59812','59150','59151','59120','59121','59820','59821','59830','59840',
									'59841','59850','59851','59852','59855','59856','59857','59866','59870','88304')
		OR
		dev_d.icd9 IN ('O04.5','O04.87','O04.6','O04.84','O04.82','O04.83','O04.81','O04.7','O04.85','O04.86','O04.88','O04.89',
						'O04.85','O04.89','O04.80','Z33.2','O07.0','O07.1','O07.37','O07.34','O07.32','O07.33','O07.31','O07.2',
						'O07.35','O07.36','O07.38','O07.39','O07.30','O07.4','A34','O08.0','O08.1','O08.6','O08.4','O08.5','O08.3',
						'O08.2','O08.7','O08.82', 'O08.81', 'O08.83','O08.89','O08.9','10A07ZZ','10A08ZZ','10D17ZZ','10D18ZZ',
						'10A07ZZ','10A08ZZ','10A00ZZ','10A03ZZ','10A04ZZ')
		--dev_d.icd9 IN ('Z90.710', 'Z98.51', 'Z98.52', 'Z90.711','Z90.712','Z98.51', 'Z30.2', 'N95.0', 'N95.1', 'N95.2', 'N95.8', 'N95.9')
), kepts AS (
	SELECT
		appt.patientprofileid,
		CAST(appt.booking_date as date) dos,
		appt.doctorid,
		appt.departmentid
	FROM 
		cchc.pr1_view_patientappt appt
		JOIN medicalVisitTypes vt ON appt.visit_type_id = vt.visit_type_id
	WHERE 
		(appt.status = 'appt kept')
		AND (CONVERT(date,booking_date) between @startdate and @lastdate)
),charges AS (
	SELECT 
		dev_ch.patient_id,
		dev_ch.post_fromdate,
		ROW_NUMBER() OVER(PARTITION BY dev_ch.patient_id ORDER BY dev_ch.post_fromdate DESC) AS rn
	FROM 
		(SELECT * FROM cchc.charge_history WHERE CONVERT(date, post_fromdate) BETWEEN @lastYear AND @lastdate) AS dev_ch 
		INNER JOIN cchc.company_procedure AS dev_cp ON dev_ch.procedure_id = dev_cp.procedure_id 
		INNER JOIN cchc.company_diagnosis AS dev_d ON dev_d.diagnosis_id = dev_ch.diagnosis_id_1 OR dev_d.diagnosis_id = dev_ch.diagnosis_id_2 OR dev_d.diagnosis_id = dev_ch.diagnosis_id_3 OR 
                                                      dev_d.diagnosis_id = dev_ch.diagnosis_id_4
	WHERE 
		(dev_cp.procedure_code IN ('FAMILY PLANNING','Z9750', 'S9445', '87081', '99401U6', '99402U6', '99403U6', 'Z9752', 'Z9753', 'Z9754', 'Z9751', '91030',
								'J7301', 'A4269U3', 'X1500', 'J105', 'J1055', 'X6051', 'J1050', 'J1050UD', 'J1055', 'J3490',
								'J3490U8', 'X6051', 'J1050', 'J3490U8', 'A4261', 'J7307UD', '57170', '57170ZK', '11975',
								'11981', '58300', '58300AG', '58300UA', 'J7300', 'METH', 'X1522', 'J7300UD', 'X1522','X1522UD',
								'X1514', '58301', '58301AG', 'J7296', 'A4267', 'J7298', 'J7298UD', 'X7722', '58611', '58605','91030')
		--dev_cp.procedure_code IN ('99213', '99203', '11982', '99212', '99448', 'G2012', '99395', 'G0101', '81002', '99202', '58301', '99204', '99214,', '99401', 'J3490', 'J1050', '11976', 
        --                                              '99402', '11981', 'J7307', '58300', 'J7298', 'J7296', '99215', '11983', 'J7300', '99000', '99447', '99442', 'S9445', '11200', 'J7301', '99446')
		OR dev_d.icd9 IN ('Z30.011','Z30.013','Z30.014','Z30.015','Z30.016','Z30.017','Z30.018','Z30.019','Z30.012','Z30.02','Z30.09','Z30.430','Z30.432','Z30.433','Z30.2','Z30.40','Z30.41','Z30.431','Z30.44','Z30.45','Z30.46','Z30.49','Z30.42','Z30.8','Z30.9','Z31.0','Z31.7','Z31.89','Z31.41','Z31.42','Z31.49','Z31.430','Z31.438','Z31.440','Z31.441','Z31.448','Z31.61', 'Z31.62','Z31.69','Z31.9','Z98.51','Z98.52','Z31.83','Z31.84','Z31.89','Z31.90','Z97.5'))
), charges_2 AS (
	SELECT 
		dev_ch.patient_id,
		dev_ch.post_fromdate,
		ROW_NUMBER() OVER(PARTITION BY dev_ch.patient_id ORDER BY dev_ch.post_fromdate DESC) AS rn
	FROM 
		(SELECT * FROM cchc.charge_history WHERE CONVERT(date, post_fromdate) BETWEEN @lastYear AND @lastdate) AS dev_ch 
		INNER JOIN cchc.company_procedure AS dev_cp ON dev_ch.procedure_id = dev_cp.procedure_id 
		INNER JOIN cchc.company_diagnosis AS dev_d ON dev_d.diagnosis_id = dev_ch.diagnosis_id_1 OR dev_d.diagnosis_id = dev_ch.diagnosis_id_2 OR dev_d.diagnosis_id = dev_ch.diagnosis_id_3 OR 
                                                      dev_d.diagnosis_id = dev_ch.diagnosis_id_4
	WHERE 
		dev_cp.procedure_code IN ('57510','57511','86631', '86632', '87110', '87270', '87320','87490','87491','87810',
										'CHLAMYDIA','G9228','57452','57454','57455','57456','57460','87800','54050','54055',
										'54056','54057','54060','54065','58100','87081','87590','87591','GONORRHEA','87850','86695',
										'86696','87255','86689','86701','86702','86703','87389','HIV','87536','G0298','G0432','G0433',
										'G0435','G0475','S3645','87624','85014','85018','57460','56501','57061','88112','88141','88142',
										'88150','88164','88175','P3000','P3001','PAP','Q0091','57410','86592','86593','86780','SYPHILIS',
										'86780','87210','G8806','G9113','G9114','G9115','G9116','G9117','G9618','Q0111','S0610','S0612','S0613')

		OR dev_d.icd9 IN ('B20', 'Z21','Z71.7','A60.00','A60.01','A60.02','A60.03','A60.04','A60.09','A60.1','A60.9','B00.1',
							'B00.9','A63.0','A63.0','B07.9','B08.1','B97.7','Z11.51','A51.0','A51.5','A51.9','A51.31','A51.39',
							'A51.49','A52.11','A52.12','A52.13','A52.14','A52.15','A52.16','A52.76','A52.8','A52.9','A53.0',
							'A53.9','A54.9','A54.29','A54.01','A54.02','A54.09','A54.1','A54.22','A54.23','A54.03','A54.24','A54.29',
							'A54.21','A54.00','A54.01','A54.5','A54.6','A74.9','N34.1','A56.19','A56.4','A56.3','A56.00','A56.01',
							'A56.02','A56.09','A56.19','A56.2','A56.8','A63.8','A64','B37.3','A59.01','A59.03','C51.9','C54.1','C54.2',
							'C54.3','C54.8','C54.9','C56.1','C56.2','D06.0','D06.1','D06.7','D06.9','D07.0','D07.30','D07.2','D07.1',
							'D07.39', 'D07.5','D07.4','D07.60','D07.69','D25.9','D28.0','E28.2','E29.0','E89.5','E29.1','E29.8','E29.9',
							'F52.0','F52.1','F52.21','F52.22','F52.31','F52.32','F52.4','F52.5','F52.6','F52.8','F52.9','I86.1','K62.6',
							'K62.7','K62.81','K62.82','K62.89','K62.9','N30.00','N30.01','N34.1','N34.1','N34.2','N40.0','N40.1',
							'N40.2','N40.3','N42.83','N41.0','N41.1','N41.2','N41.3','N51','N41.4','N41.8','N41.9','N42.0','N42.1',
							'N42.89','N42.3','N42.89','N42.9','N43.0','N43.1','N43.2','N43.3','N45.4','N45.1','N45.2','N45.3','N51',
							'N47.1','N47.2','N47.3','N47.4','N47.5','N47.6','N47.7','N47.8','N46.01','N46.11','N46.029','N46.9','N48.0',
							'N47.6','N48.1','N48.29','N48.30','N48.31','N48.32','N48.33','N48.39','N48.0','N50.1','N48.89','N52.01',
							'N52.02','N52.03','N52.1','N52.2','N52.31','N52.32','N52.33','N52.34','N52.39','N52.9',
							'N48.6','N48.5','N48.82','N48.89','N48.9','N48.0','N43.40','N43.41','N43.42','N44.00','N44.01','N44.02',
							'N44.03', 'N44.04','N50.0','N49.9','N51','R36.1','N50.1','N50.8','N53.14','N44.2','N44.8','N50.3','N50.8',
							'N53.12','N50.9','R10.2','C50.911','C50.912','C50.919','N60.01','N60.02','N60.09','N60.11','N60.12','N60.19',
							'N60.21','N60.22','N60.29','N60.31','N60.32','N60.39','N60.41','N60.42','N60.49','N60.81','N60.82','N60.89',
							'N60.91','N60.92','N60.99','N61','N62','N63','N64.0','N64.1','N64.2','N64.89','N64.3','N64.4','N64.51',
							'N64.52','N64.53', 'N64.59','O91.23','R92.8','R92.0','R92.1','R92.2','N70.01', 'N70.02','N70.03',
							'N70.11','N70.12','N70.13','N70.91','N70.92','N70.93','N73.0','N73.1','N73.2','N73.3','N73.4','N73.5','N73.6',
							'N73.8','N73.9','N71.0','N71.1','N71.9','N72','N76.0','N76.1','N76.2','N76.3','N77.1','N75.0','N75.1','N75.8',
							'N76.4','N76.6','N77.0','N76.81','N75.9','N76.5','N76.89','N73.9','N80.0','N80.1','N80.2','N80.3','N80.4',
							'N80.5','N80.6','N80.8','N80.9','N81.9','N81.10','N81.11','N81.12','N81.0','N81.6','N81.81','N81.89','N81.2',
							'N81.3','N81.4','N81.5','N99.3','N81.89','N81.83','N81.84','N81.82','N81.2','N81.85','N82.0','N82.1','N82.4',
							'N82.5','N82.8','N82.9','N83.0','N83.1','N83.20','N83.29','N83.33','N83.4','N83.51','N83.52','N83.53','N83.8',
							'N83.7','N99.83','N83.9','N84.0','N84.8','N84.9','N85.3','N85.2','N85.00','N85.01','N85.02','N85.7','N85.6',
							'N85.4','N85.5','N85.8','N85.9','Q51.10','Q51.11','Q51.2','Q51.0','Q51.3','Q51.4','Q51.810','Q51.811','Q51.818',
							'Q51.9','D26.0','D26.1','D26.7','D26.9','N86','N87.9','N87.0','N87.1','N88.0','N88.1','N88.2','N88.3','N88.4',
							'N84.1','N88.8','N88.9','Q51.5','Q51.820','Q51.821','Q51.828','N89.0','N89.1','N89.3','N89.4','N89.5','N99.2',
							'N89.6','N89.8','N84.2','N89.9','Q52.10','Q52.11','Q52.2','Q52.4','N90.0','N90.1','N90.4','N90.5','N90.89',
							'N90.6','N84.3','N90.7','N90.89','N90.9','N94.1','N94.2','N94.0','N94.4','N94.5','N94.6','N94.3','N94.89',
							'N39.9','N94.819','N94.810','N94.818','N94.89','N91.0','N91.1','N91.2','N91.3','N91.4','N91.5','N92.0',
							'N92.1','N92.2','N92.3','N92.5','N92.6','N93.0','N93.8','N93.9','N92.4','N97.0','E23.0','N97.1','N97.2',
							'N97.8','N97.9','N94.89','N90.810','N90.811','N90.812','N90.813','N90.818','T83.711A','N94.89','N94.9',
							'Q52.5','Q52.6','Q52.70','Q52.71','Q52.79','Q52.8','R30.9','R35.0','R36.0','R36.9','R68.82','R87.619',
							'R87.610','R87.611','R87.612','R87.613','R87.810','R87.614','R87.616','R87.615','R87.820','R87.628',
							'R87.620','R87.621','R87.622','R87.623','R87.811','R87.624','R87.625','R87.628','R87.629','T83.39XA',
							'Z20.2','Z30.8','Z01.411','Z01.419','Z11.4','Z11.3','Z12.39','Z08','Z01.42','Z12.4','Z12.5','Z12.71',
							'Z12.73','Z12.72','Z22.4','Z72.53','Z72.51','Z72.52')
), shortCode AS ( 
	SELECT DISTINCT p.patient_id, (CASE WHEN ps.code LIKE 'YES TRANSLAT%' THEN 'TRANSLATION NEEDED - YES' WHEN ps.code LIKE 'NO TRANSLAT%' THEN 'TRANSLATION NOT NEEDED - NO' END) As code
	FROM activePatients p LEFT JOIN cchc.patient_shortcode ps ON p.patient_id = ps.patient_id
	WHERE ps.code LIKE '%TRANSLAT%'
), financialClass AS (
	SELECT 
		c.patient_id, 
		fc.description AS financial_class_id,
		ROW_NUMBER() OVER(PARTITION BY c.patient_id ORDER BY c.post_fromdate DESC) AS rn
	FROM 
		cchc.charge_history c
		JOIN cchc.financial_class fc ON c.financial_class_id_1 = fc.financial_class_id OR c.financial_class_id_2 = fc.financial_class_id OR c.financial_class_id_3 = fc.financial_class_id
	WHERE
		CONVERT(DATE, c.post_fromdate) BETWEEN @lastYear AND @lastdate
),povertyLevel AS (
	SELECT p.patient_id, 
		fmd.poverty_status
	FROM cchc.fee_matrix_detail fmd, 
		cchc.patient p  
	WHERE p.company_id = 9 
		AND p.active_yn = 'Y' 
		AND fmd.company_id = p.company_id  
		AND fmd.family_size =   (SELECT IIF(MAX(d2.family_size) < IIF(p.family_size is null, 1, p.family_size), MAX(d2.family_size), IIF(p.family_size is null, 1, p.family_size)) FROM cchc.fee_matrix_detail d2  
								WHERE d2.fee_matrix_id = fmd.fee_matrix_id)  
										AND fmd.income_from <= IIF(p.income is null, 0, p.income)
										AND fmd.income_to >= (SELECT IIF(MAX(d3.income_to) < IIF(p.income is null, 0, p.income), MAX(d3.income_to), IIF(p.income is null, 0, p.income)) FROM cchc.fee_matrix_detail d3 WHERE d3.fee_matrix_id = fmd.fee_matrix_id  
										AND d3.family_size = fmd.family_size )
), final AS (
SELECT DISTINCT
	'CCHC' AS Agency,
	ISNULL(dept.short_name, '') AS Site,
	p.patient_number AS [Patient ID],
	FORMAT(p.birth_date, 'MM/dd/yyyy') AS DOB,
	p.sex AS Sex,
	p.age AS Age,
	r.description AS Race,
	r2.description AS Ethnicity,
	IIF(p.family_size is null, 1, p.family_size) AS [Family Size],
	IIF(p.income is null, 0.00, p.income) AS [Weekly Income],
	k.dos AS [Visit Date],
	ISNULL(phys.degree,'') AS [Provider Type],
	COALESCE(fc.financial_class_id, '') AS [Principle Health Coverage],
	p.zip AS [Zip Code],
	COALESCE((SELECT TOP 1 code FROM shortCode sc WHERE sc.patient_id=p.patient_id), '') AS [Limited English Proficiency],
	IIF(emp.description IS NULL, '', emp.description) AS Homeless,
	(SELECT TOP 1 tx.data_value FROM titleXVisits tx WHERE (tx.PATIENTPROFILEID = k.patientprofileid AND k.dos >= tx.DOS) ORDER BY tx.note_datetime DESC) AS [Birth Control Method],
	(SELECT TOP 1 poverty_status FROM povertyLevel pl WHERE pl.patient_id = p.patient_id) AS [Poverty Level]
FROM 
	kepts k 
	JOIN (
		SELECT 
			p.* 
		FROM 
			activePatients p 
		WHERE 
			(p.rn = 1)
				AND
			((p.sex = 'M' AND p.age BETWEEN 12 and 60)
			OR (p.sex = 'F' AND p.age BETWEEN 12 and 55))
				AND
			(p.patient_id NOT IN (SELECT f.patient_id FROM filter f)
			AND p.patient_id IN (SELECT c.patient_id FROM charges c)
			AND p.patient_id IN (SELECT c.patient_id FROM charges_2 c))
		) p ON k.patientprofileid = p.patient_id
	JOIN cchc.pr1_view_all_department dept ON k.departmentid = dept.departmentid
	JOIN view_activePhys phys ON k.doctorid = phys.doctorid
	LEFT JOIN cchc.pr1_view_all_lists emp ON p.employment_status_id = emp.medlistsid
	LEFT JOIN cchc.pr1_view_all_lists r ON p.race_id = r.medlistsid
	LEFT JOIN cchc.pr1_view_all_lists r2 ON p.ethnicity_id = r2.medlistsid
	LEFT JOIN (SELECT * FROM financialClass WHERE rn = 1) fc ON p.patient_id = fc.patient_id
WHERE 
	phys.degree IN('MD', 'PA', 'MS PA-C', 'NP', 'DO')
)

SELECT 
	Agency,
	Site,
	[Patient ID],
	DOB,
	Sex,
	Age,
	Race,
	Ethnicity,
	[Family Size],
	[Weekly Income],
	FORMAT([Visit Date], 'MM/dd/yyyy') AS [Visit Date],
	[Provider Type],
	[Principle Health Coverage],
	[Zip Code],
	[Limited English Proficiency],
	Homeless,
	IIF([Birth Control Method] is null, '', [Birth Control Method]) AS [Birth Control Method],
	[Poverty Level]
FROM final
ORDER BY [Patient ID]