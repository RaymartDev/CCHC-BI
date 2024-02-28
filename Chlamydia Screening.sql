SET NOCOUNT ON
declare @startDate date, @endDate date, @patientNoteStartDate date
set @startDate = CONVERT(date, DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0))--CONVERT(date, '5/1/2023')--
set @endDate = CONVERT(date, DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1))--CONVERT(date, '5/31/2023')--
set @patientNoteStartDate= CONVERT(date,DATEADD(year,-1,@startDate)) --PatientNote Date from:last year

DECLARE @procedureCodes TABLE (code VARCHAR(10))

INSERT INTO @procedureCodes (code)
VALUES 
('11975'), ('11976'), ('11977'), ('57022'), ('57170'), ('58300'), ('58301'), ('58600'), ('58605'), ('58611'), 
('58615'), ('58970'), ('58974'), ('58976'), ('59000'), ('59001'), ('59012'), ('59015'), ('59020'), ('59025'), 
('59030'), ('59050'), ('59051'), ('59070'), ('59072'), ('59074'), ('59076'), ('59100'), ('59120'), ('59121'), 
('59130'), ('59135'), ('59136'), ('59140'), ('59150'), ('59151'), ('59160'), ('59200'), ('59300'), ('59320'), 
('59325'), ('59350'), ('59400'), ('59409'), ('59410'), ('59412'), ('59414'), ('59425'), ('59426'), ('59430'), 
('59510'), ('59514'), ('59515'), ('59525'), ('59610'), ('59612'), ('59614'), ('59618'), ('59620'), ('59622'), 
('59812'), ('59820'), ('59821'), ('59830'), ('59840'), ('59841'), ('59850'), ('59851'), ('59852'), ('59855'), 
('59856'), ('59857'), ('59866'), ('59870'), ('59871'), ('59897'), ('59898'), ('59899'), ('76801'), ('76805'), 
('76811'), ('76813'), ('76815'), ('76816'), ('76817'), ('76818'), ('76819'), ('76820'), ('76821'), ('76825'), 
('76826'), ('76827'), ('76828'), ('76941'), ('76945'), ('76946'), ('80055'), ('81025'), ('82105'), ('82106'), 
('82143'), ('82731'), ('83632'), ('58300UA'), ('58300UA'), ('58301AG'), ('58301ZK'), ('83661'), ('83662'), 
('83663'), ('83664'), ('84163'), ('84702'), ('84703'), ('84704'), ('86592'), ('86593'), ('86631'), ('86632'), 
('87110'), ('87164'), ('87166'), ('87270'), ('87320'), ('87490'), ('87491'), ('87492'), ('87590'), ('87591'), 
('87592'), ('87620'), ('87621'), ('87622'), ('87660'), ('87800'), ('87801'), ('87808'), ('87810'), ('87850'), 
('88141'), ('88142'), ('88143'), ('88147'), ('88148'), ('88150'), ('88152'), ('88153'), ('88154'), ('88155'), 
('88164'), ('88165'), ('88166'), ('88167'), ('88174'), ('88175'), ('88235'), ('88267'), ('88269')

DECLARE @icd9 TABLE (
  icd9_value VARCHAR(10)
)

-- Insert values into the temporary table
INSERT INTO @icd9 (icd9_value)
VALUES ('042'), ('054.10'), ('054.11'), ('054.12'), ('054.19'), ('078.11'), ('078.88'), ('079.4'), ('079.51'), ('079.52'),
       ('079.53'), ('079.88'), ('079.98'), ('091'), ('092'), ('093'), ('094'), ('095'), ('096'), ('097'), ('098.0'),
       ('098.10'), ('098.11'), ('098.15'), ('098.16'), ('098.17'), ('098.18'), ('098.19'), ('098.2'), ('098.30'),
       ('098.31'), ('098.35'), ('098.8'), ('099'), ('131'), ('614'), ('615'), ('616'), ('622.3'), ('623.4'), ('626.7'),
       ('628'), ('795.0'), ('795.1'), ('996.32'), ('V01.6'), ('V02.7'), ('VO2.8'), ('V08'), ('V15.7'), ('V22'), ('V23'),
       ('V24'), ('V26'), ('V27'), ('V28'), ('V45.5'), ('V61.5'), ('V61.6'), ('V61.7'), ('V69.2'), ('V72.3'), ('V72.4'),
       ('V73.81'), ('V73.88'), ('V73.98'), ('V74.5'), ('V76.2')

;WITH sexuallyActive1 AS (
	Select 
			dev_ch.patient_id,
			dev_ch.post_fromdate,
			ROW_NUMBER() OVER(PARTITION BY dev_ch.patient_id ORDER BY dev_ch.post_fromdate DESC) AS rn
				
FROM (SELECT patient_id, post_fromdate, procedure_id, diagnosis_id_1, diagnosis_id_2,diagnosis_id_3,diagnosis_id_4 FROM cchc.charge_history) dev_ch
JOIN
	(SELECT * FROM activeDiagnosis 
		WHERE 
			(icd10_yn = 'N' AND (icd9 IN (SELECT icd9_value FROM @icd9)))
			OR
			(icd10_yn = 'Y' AND (icd9 LIKE 'A34%'  OR icd9 LIKE 'A51%' OR icd9 LIKE 'A52%' OR icd9 LIKE 'A53%' 
								OR icd9 LIKE 'A54.%' OR icd9 LIKE 'A55%' OR icd9 LIKE 'A56%' OR icd9 LIKE 'A57%'
								OR icd9 LIKE 'A58%' OR icd9 LIKE 'A59.%' OR icd9 LIKE 'A60.%' OR icd9 LIKE 'A63%'
								OR icd9 LIKE 'A64%' OR icd9 LIKE 'B20%' OR icd9 LIKE 'B97.%' OR icd9 LIKE 'F53%'
								OR icd9 LIKE 'G44.%' OR icd9 LIKE 'F52.%' OR icd9 LIKE 'N70%' OR icd9 LIKE 'N71%' 
								OR icd9 LIKE 'N93.%' OR icd9 LIKE 'N94.%' OR icd9 LIKE 'N96%' OR icd9 LIKE 'N97%'
								OR icd9 LIKE 'O09%' OR icd9 LIKE 'O94%' OR icd9 LIKE 'O98%' OR icd9 LIKE 'O99%'
								OR icd9 LIKE 'O9A%' OR icd9 LIKE 'T38.4%' OR icd9 LIKE 'T83.3%' OR icd9 LIKE 'Z03.7%'  
								 OR icd9 LIKE 'Z20.2%'  OR icd9 BETWEEN 'Z30' AND 'Z37'  OR icd9 LIKE 'Z39%'  OR icd9 LIKE 'Z64.0%'
								  OR icd9 LIKE 'Z92.0%'  OR icd9 LIKE 'Z64.1%'  OR icd9 LIKE 'Z72.5%'  OR icd9 LIKE 'Z79.3%' 
								  OR icd9 LIKE 'Z97.5%' OR icd9 LIKE 'Z98.51%' OR icd9 BETWEEN 'O00' AND 'O16' OR icd9 BETWEEN 'O20' AND 'O29' 
								OR icd9 BETWEEN 'O30' AND 'O48' OR icd9 BETWEEN 'O60' AND 'O77' OR icd9 BETWEEN 'O80' AND 'O82' OR icd9 BETWEEN 'O85' AND 'O92'))) dev_d ON dev_ch.diagnosis_id_1 = dev_d.diagnosis_id OR dev_ch.diagnosis_id_2 = dev_d.diagnosis_id OR dev_ch.diagnosis_id_3 = dev_d.diagnosis_id OR dev_ch.diagnosis_id_4 = dev_d.diagnosis_id
),sexuallyactivewomen AS
(
          Select 
			dev_ch.patient_id,
			dev_ch.post_fromdate,
			ROW_NUMBER() OVER(PARTITION BY dev_ch.patient_id ORDER BY dev_ch.post_fromdate DESC) AS rn
				
FROM (SELECT patient_id, post_fromdate, procedure_id FROM cchc.charge_history) dev_ch
	 LEFT JOIN (
		SELECT * FROM activeProcedure
		WHERE procedure_code IN (SELECT code FROM @procedureCodes)
	 ) dev_cp ON dev_ch.PROCEDURE_ID =dev_cp.PROCEDURE_ID
     LEFT JOIN (
		SELECT 
			start_date, patientprofileid, drug_name 
		FROM cchc.pr1_patient_drug
		WHERE
			CONVERT(DATE, start_date) BETWEEN @patientNoteStartDate AND @endDate
			AND (
			 drug_name LIKE 'Nonoxynol-9' OR drug_name LIKE 'VCF Vaginal Contraceptive%' OR drug_name LIKE 'Vaginal Contraceptive%'
				OR drug_name LIKE 'Apri' OR drug_name LIKE 'Balziva%' OR drug_name LIKE 'Cyclessa' OR drug_name LIKE 'Desogen'
				OR drug_name LIKE 'Enpresse' OR drug_name LIKE 'Estrostep%'
				OR drug_name LIKE 'Generes%'
				OR drug_name LIKE 'Gildess%'
				OR drug_name LIKE 'Activella'
				OR drug_name LIKE 'Alesse-28'
				OR drug_name LIKE 'Altavera'
				OR drug_name LIKE 'AndroGel Packets'
				OR drug_name LIKE 'Aviane'
				OR drug_name LIKE 'BIRTH CONTROL%'
				OR drug_name LIKE 'CAMILA%'
				OR drug_name LIKE 'Conceptrol'
				OR drug_name LIKE 'Condoms%'
				OR drug_name LIKE 'CONTRACEPTIVE%'
				OR drug_name LIKE 'Cryselle%'
				OR drug_name LIKE 'Cyclafem%'
				OR drug_name LIKE 'DEPO%'
				OR drug_name LIKE 'drospirenone-ethinyl estradiol'
				OR drug_name LIKE 'EMERGENCY PILL'
				OR drug_name LIKE 'Errin%'
				OR drug_name LIKE 'ethinyl estradiol%'
				OR drug_name LIKE 'Femcon%'
				OR drug_name LIKE 'Gianvi'
				OR drug_name LIKE 'Heather'
				OR drug_name LIKE 'IMPLANON'
				OR drug_name LIKE 'Intrauterine Device (IUD)'OR drug_name LIKE 'IUD%'OR drug_name LIKE 'Jolivette'
				OR drug_name LIKE 'Junel%'
				OR drug_name LIKE 'Kariva%'
				OR drug_name LIKE 'Levlen%'
				OR drug_name LIKE 'levonorgestrel%'
				OR drug_name LIKE 'Levora%'
				OR drug_name LIKE 'Lo Loestrin Fe%'
				OR drug_name LIKE 'Lo/Ovral%'
				OR drug_name LIKE 'Loestrin%'
				OR drug_name LIKE 'Loryna%'
				OR drug_name LIKE 'Low-Ogestrel%'
				OR drug_name LIKE 'Lutera%'
				OR drug_name LIKE 'lybrel%'
				OR drug_name LIKE 'medroxy%'
				OR drug_name LIKE 'MERZALONE%'
				OR drug_name LIKE 'Microgestin%'
				OR drug_name LIKE 'micronor%'
				OR drug_name LIKE 'MINI PILL (BIRTH CONTROL PILLS)%'
				OR drug_name LIKE 'Mircette%'
				OR drug_name LIKE 'Mirena%'
				OR drug_name LIKE 'Modicon%'
				OR drug_name LIKE 'Mononessa%'
				OR drug_name LIKE 'Necon%'
				OR drug_name LIKE 'Next choice%'
				OR drug_name LIKE 'Nora-BE%'
				OR drug_name LIKE 'Nordette%'
				OR drug_name LIKE 'Noreth-Ethinyl Estradiol-Iron%'
				OR drug_name LIKE 'norethindrone%'
				OR drug_name LIKE 'NORGESTIMATE-ETH ESTRADIOL TAB%'
				OR drug_name LIKE 'norgestimate-ethinyl estradiol%'
				OR drug_name LIKE 'nor-plan%'
				OR drug_name LIKE 'NuvaRing%'
				OR drug_name LIKE 'Nor-QD%'
				OR drug_name LIKE 'Nortrel%'
				OR drug_name LIKE 'OC PILLS%'
				OR drug_name LIKE 'OCP%'
				OR drug_name LIKE 'Ocella%'
				OR drug_name LIKE 'Ortho%'
				OR drug_name LIKE 'Ovcon%'
				OR drug_name LIKE 'ParaGard%'
				OR drug_name LIKE 'Plan B%'
				OR drug_name LIKE 'Portia%'
				OR drug_name LIKE 'Premarin%'
				OR drug_name LIKE 'Premphase%'
				OR drug_name LIKE 'Prempro%'
				OR drug_name LIKE 'PROGESTERON%'
				OR drug_name LIKE 'Provera%'
				OR drug_name LIKE 'PT TAKES%'
				OR drug_name LIKE 'Quasense%'
				OR drug_name LIKE 'Reclipsen%'
				OR drug_name LIKE 'Seasonale%'
				OR drug_name LIKE 'Seasonale%'OR drug_name LIKE 'spermicide%'OR drug_name LIKE 'Sprintec%'OR drug_name LIKE 'Sronyx%'
				OR drug_name LIKE 'testosterone%'OR drug_name LIKE 'Tilia Fe%'OR drug_name LIKE 'Tri%'OR drug_name LIKE 'UNKNOWN BCP%'
				OR drug_name LIKE 'USE AS DIRECTED%'OR drug_name LIKE 'vaginal ring%' OR drug_name LIKE 'Velivet%'OR drug_name LIKE 'Yasmin%'OR drug_name LIKE 'Yaz%'OR drug_name LIKE 'Zarah%'
				OR drug_name LIKE 'Zovia%')
	 ) pd ON dev_ch.PATIENT_ID = pd.PATIENTPROFILEID
WHERE
	(CONVERT(DATE, dev_ch.post_fromdate) BETWEEN @patientNoteStartDate AND @endDate) 
	AND (drug_name IS NOT NULL OR dev_cp.procedure_code IS NOT NULL)
),LastMonthLabResults AS
(
  SELECT
	lr.patientprofileid,
	lr.obr_obs_datetime,
	ROW_NUMBER() OVER(PARTITION BY lr.patientprofileid ORDER BY lr.obr_obs_datetime DESC) AS rn
 FROM 
	cchc.pr1_lab_result_item li 
	JOIN cchc.pr1_lab_result_set ls ON li.lab_result_set_id = ls.lab_result_set_id AND li.lab_hist_req_id = ls.lab_hist_req_id
	JOIN cchc.pr1_lab_result_req lr ON ls.lab_result_req_id = lr.lab_result_req_id AND ls.lab_hist_req_id = lr.lab_hist_req_id
	JOIN cchc.pr1_lab_result_value lv ON li.lab_result_item_id = lv.lab_result_item_id AND li.lab_hist_req_id = lv.lab_hist_req_id
	 
WHERE 
	(CONVERT(DATE,lr.obr_obs_datetime) BETWEEN @patientNoteStartDate AND @endDate ) 
	and lv.RESULT_STATUS Is Not Null 
	--AND (li.result_desc in ('7504','70043800', '7505','7506','86005814','85668656','86005810') OR li.result_code LIKE 'CT_PAP%')
	AND li.result_desc IN (
	'ALERT CHLAMYDIA',
	'C trach rRNA XXX QI PCR',
	'C. TRAC/N. GONO SCREEN:',
	'C. TRACHOMATIS AB (IGA)',
	'C. TRACHOMATIS AB (IGG)',
	'C. TRACHOMATIS AB (IGM)',
	'C. TRACHOMATIS CULTURE',
	'C. TRACHOMATIS DNA PROBE RESULT:',
	'C. TRACHOMATIS IGA',
	'C. TRACHOMATIS IGG',
	'C. trachomatis IgG Titer',
	'C. TRACHOMATIS IGM',
	'C. trachomatis IgM Titer',
	'C. TRACHOMATIS RESULT:',
	'C. TRACHOMATIS RNA, TΜΑ',
	'C.TRACHOMATIS (DK) IGA',
	'C.TRACHOMATIS (DK) IGG',
	'C.TRACHOMATIS (DK) IGM',
	'C.TRACHOMATIS (L2) IGA',
	'C.TRACHOMATIS (L2) IGG',
	'C.TRACHOMATIS (L2) IGM',
	'C.TRACHOMATIS RNA, TMA',
	'C.TRACHOMATIS TMA, THROAT',
	'Chlamydia',
	'CHLAMYDIA AMPLIF',
	'CHLAMYDIA IGG ANTIBODY',
	'Chlamydia IgM Panel Interpretation',
	'CHLAMYDIA TRACHOMATIS DNA, SDA',
	'CHLAMYDIA TRACHOMATIS DNA, SDA, PAP VIAL',
	'CHLAMYDIA TRACHOMATIS RNA, TMA',
	'CHLAMYDIA TRACHOMATIS RNA, TMA, RECTAL',
	'CHLAMYDIA TRACHOMATIS RNA, TMA, THROAT',
	'CHLAMYDIA TRACHOMATIS RNA, TMA, UROGENITAL',
	'CHLAMYDIA TRACHOMATIS, TMA (ALT TARGET), UROGENITAL',
	'CHLAMYDIA TRACHOMATIS, TMA (ALTERNATE TARGET)',
	'Chlamydia/ Gonorrhoeae RNA',
	'Chlamydia/Gonorrhoeae RNA',
	'Chlamydia/Gonorrhoeae',
	'CT rRNA (TMA) - Rectal',
	'CT rRNA (TMA) - Throat',
	'CT rRNA (TMA) - Vaginal',
	'CT rRNA (TMA), PAP Vial',
	'CT rRNA (TMA), Probe',
	'CT rRNA (TMA), UR',
	'VAG CHLAMYDIA'
	)
), filtered_notes AS (
	SELECT 
		pn.patient_note_id
	FROM
		cchc.pr1_patient_note pn
		JOIN view_activePhys phys ON pn.doctorid = phys.doctorid
	WHERE
		CONVERT(date, pn.note_datetime) BETWEEN @startdate AND @endDate
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
), Chlamydia AS (
	SELECT 
		p.PATIENTID,
		p.PATIENTPROFILEID,
		p.BIRTHDATE,
		p.age,
		phys.provider_name,
		pn.note_datetime,
		short_name,
		ROW_NUMBER() OVER(PARTITION BY p.PATIENTPROFILEID ORDER BY pn.note_datetime DESC) AS rn
	FROM 
		(SELECT note_datetime, dept_id,patientprofileid, doctorid FROM cchc.view_medical_note_full WHERE patient_note_id NOT IN (SELECT t2.patient_note_id FROM filtered_notes t2)) pn 
		JOIN (SELECT PATIENTID, PATIENTPROFILEID, BIRTHDATE, age, sex FROM cchc.pr1_view_patient WHERE rn = 1) p ON pn.patientprofileid = p.PATIENTPROFILEID
		JOIN (SELECT * FROM activeMedicalPhys) phys ON pn.doctorid = phys.doctorid
		JOIN (SELECT short_name, departmentid FROM cchc.pr1_view_all_department) dept ON pn.dept_id = dept.departmentid
	WHERE 
		(p.age BETWEEN 13 AND 24) AND p.sex = 'F'
		AND (CONVERT(DATE, pn.note_datetime) BETWEEN @startDate AND @endDate)
), latestChlamydia AS (
	SELECT 
		c.PATIENTPROFILEID,
		PATIENTID AS [Patient ID],
		FORMAT(BIRTHDATE, 'MM/dd/yyyy') AS [Date Of Birth],
		age AS Age,
		short_name AS Clinic,
		provider_name AS Provider,
		note_datetime,
		IIF(lab.obr_obs_datetime IS NULL,'', FORMAT(lab.obr_obs_datetime, 'MM/dd/yyyy')) AS [Test Date In Last 12 mo],
		IIF(lab.obr_obs_datetime IS NULL, 'N', 'Y') AS [Met]
	FROM 
		(SELECT * FROM Chlamydia WHERE rn = 1) c
		LEFT JOIN (SELECT * FROM LastMonthLabResults WHERE rn = 1) lab ON c.PATIENTPROFILEID = lab.patientprofileid
	WHERE 
		c.PATIENTPROFILEID IN (SELECT saw.patient_id FROM sexuallyactivewomen saw)
		OR c.PATIENTPROFILEID IN (SELECT saw.patient_id FROM sexuallyActive1 saw)
)
SELECT 
	Provider,
	Clinic,
	[Patient ID],
	[Date Of Birth],
	Age,
	FORMAT(note_datetime, 'MM/dd/yyyy') AS [Last Visit Date],
	[Test Date In Last 12 mo],
	Met,
	dbo.getTelehealthConsent(PATIENTPROFILEID, CONVERT(DATE, note_datetime)) AS [Patient Consents to Telehealth Visit],
	dbo.getTelephoneConsent(PATIENTPROFILEID, CONVERT(DATE, note_datetime)) AS [Patient Consents to Telephone Visit]
FROM latestChlamydia
ORDER BY Provider,[Patient ID]
