/*********************************************************************
 📊 Project: Patient Survival Analysis (METABRIC Dataset)
 🧪 Goal: Explore how tumor stage and surgery type affect survival outcomes
 📂 Author: Monica Wang
*********************************************************************/

-- 1. Create Subtables

-- Patient demographics + survival info
CREATE TABLE patient_info AS
SELECT
    patient_id,
    age_at_diagnosis,
    tumor_size_mm,
    tumor_stage,
    overall_survival_months,
    vital_status
FROM metabric_patients
WHERE (patient_id,
       age_at_diagnosis,
       tumor_size_mm,
       tumor_stage,
       overall_survival_months,
       vital_status) IS NOT NULL;

-- Tumor molecular/clinical features
CREATE TABLE health_info AS
SELECT 
    patient_id,
    cancer_type_detailed,
    cellularity,
    pam50_subtype,
    er_status,
    er_status_ihc,
    her2_status,
    tumor_other_histologic_subtype,
    mutation_count,
    nottingham_index,
    inferred_menopausal_state,
    relapse_free_months,
    relapse_free_status,
    three_gene_subtype
FROM metabric_patients
WHERE (patient_id,
       cancer_type_detailed,
       cellularity,
       pam50_subtype,
       er_status,
       er_status_ihc,
       her2_status,
       tumor_other_histologic_subtype,
       mutation_count,
       nottingham_index,
       inferred_menopausal_state,
       relapse_free_months,
       relapse_free_status,
       three_gene_subtype) IS NOT NULL;

-- Treatment information
CREATE TABLE treatment AS
SELECT 
    patient_id,
    chemotherapy,
    hormone_therapy,
    radio_therapy,
    type_breast_surgery
FROM metabric_patients
WHERE (patient_id,
       chemotherapy,
       hormone_therapy,
       radio_therapy,
       type_breast_surgery) IS NOT NULL;


-- 2. Add Primary & Foreign Keys


ALTER TABLE public.patient_info
  ADD CONSTRAINT patient_id PRIMARY KEY (patient_id);

-- Ensure consistency with health_info
ALTER TABLE health_info
ADD CONSTRAINT health_patient
FOREIGN KEY (patient_id)
REFERENCES patient_info (patient_id)
ON UPDATE CASCADE
ON DELETE SET NULL;

-- Ensure consistency with treatment
ALTER TABLE treatment
ADD CONSTRAINT t_patient
FOREIGN KEY (patient_id)
REFERENCES patient_info (patient_id)
ON UPDATE CASCADE
ON DELETE SET NULL;


-- 3. Tumor Stage Grouping


-- Quick check of tumor_stage distribution
SELECT tumor_stage 
FROM patient_info
ORDER BY tumor_stage DESC;

-- Collapse tumor_stage into 2 groups: early (≤1) vs advanced (2–4)
ALTER TABLE patient_info 
ADD COLUMN IF NOT EXISTS size_group INT;

UPDATE patient_info
SET size_group = CASE
                    WHEN tumor_stage <= 1 THEN 1
                    WHEN tumor_stage <= 4 THEN 2
                 END;


-- 4. Surgery Survival Summary


-- Join patient_info with treatment to get surgery details
SELECT p.patient_id,
       p.size_group,
       p.overall_survival_months,
       t.type_breast_surgery
FROM patient_info p
JOIN treatment t USING (patient_id)
ORDER BY size_group;

-- Count surgeries by stage group
SELECT p.size_group,               
       t.type_breast_surgery,       
       COUNT(*) AS n_cases
FROM patient_info p
JOIN treatment t ON t.patient_id = p.patient_id
WHERE t.type_breast_surgery IS NOT NULL      
GROUP BY p.size_group, t.type_breast_surgery
ORDER BY p.size_group, t.type_breast_surgery;

-- Calculate average survival by group and surgery type
CREATE TABLE surgery_size_summary AS
SELECT
    p.size_group,
    t.type_breast_surgery,
    COUNT(*) AS n_cases,
    ROUND(AVG(p.overall_survival_months), 1) AS avg_survival_mo
FROM patient_info p
JOIN treatment t ON t.patient_id = p.patient_id
WHERE t.type_breast_surgery IN ('Breast Conserving', 'Mastectomy')
GROUP BY p.size_group, t.type_breast_surgery
ORDER BY p.size_group, t.type_breast_surgery;


-- 5. Patient-Level Survival Table


CREATE TABLE patient_surgery_survival AS 
SELECT
    p.patient_id,
    p.size_group,
    t.type_breast_surgery,
    p.overall_survival_months  AS actual_survival,
    s.avg_survival_mo          AS group_avg_survival
FROM patient_info p
JOIN treatment t USING (patient_id)
JOIN surgery_size_summary s
       ON s.size_group = p.size_group
      AND s.type_breast_surgery = t.type_breast_surgery;

ALTER TABLE patient_surgery_survival
ADD CONSTRAINT surgery_survival
FOREIGN KEY (patient_id)
REFERENCES patient_info (patient_id)
ON UPDATE CASCADE
ON DELETE SET NULL;


-- 6. Identify Underperformers


-- Patients whose survival < group average
CREATE TABLE patient_underperformers AS
SELECT  pss.patient_id,
        pss.type_breast_surgery,
        pss.size_group,
        h.er_status_ihc,
        h.her2_status,
        h.mutation_count,
        h.nottingham_index,
        h.inferred_menopausal_state,
        h.cellularity
FROM patient_surgery_survival pss
JOIN health_info h ON h.patient_id = pss.patient_id
WHERE pss.actual_survival < pss.group_avg_survival
ORDER BY size_group DESC;


-- 7. Performance Views


-- Low performers (below average survival)
CREATE OR REPLACE VIEW v_perf AS
SELECT
    pu.patient_id,
    TRUE AS low_perf,
    pu.size_group,
    pu.type_breast_surgery,
    pu.er_status_ihc,
    pu.her2_status,
    pu.mutation_count,
    pu.nottingham_index,
    pu.inferred_menopausal_state,
    pu.cellularity,
    t.chemotherapy,
    t.hormone_therapy,
    t.radio_therapy,
    t.type_breast_surgery AS planned_surgery_type
FROM patient_underperformers pu
LEFT JOIN treatment t USING (patient_id);

-- High performers (meeting/exceeding avg survival)
CREATE OR REPLACE VIEW v_perf_rest AS
SELECT
    pss.patient_id,
    FALSE AS low_perf,        
    pss.actual_survival,
    pss.group_avg_survival,
    pss.size_group,
    pss.type_breast_surgery,                                      
    hi.er_status_ihc,
    hi.her2_status,
    hi.inferred_menopausal_state,
    hi.cellularity,
    hi.mutation_count,
    hi.nottingham_index,
    tr.chemotherapy,
    tr.hormone_therapy,
    tr.radio_therapy,
    tr.type_breast_surgery AS planned_surgery_type
FROM patient_surgery_survival pss
LEFT JOIN health_info hi USING (patient_id)
LEFT JOIN treatment tr USING (patient_id)
WHERE pss.actual_survival >= pss.group_avg_survival;

-- Combined view
CREATE OR REPLACE VIEW v_perf_all AS
SELECT * FROM v_perf        
UNION ALL
SELECT * FROM v_perf_rest;


-- 8. Summary Statistics Export


-- Export multi-factor summary of underperformers vs others
COPY (
WITH
    num AS (...),
    surg AS (...),
    er AS (...),
    her2 AS (...),
    meno AS (...),
    cell AS (...),
    comb AS (...),
    corr AS (...),
    chi AS (...),
    long AS (...),
    ct AS (...),
    tot AS (...),
    rr_or AS (...),
    size_stats AS (...),
    mut_notts AS (...),
    pct_low_surg AS (...)
-- Final SELECT that unions everything
SELECT 'n_patients', n_patients::text FROM num
UNION ALL
SELECT 'min_mut_cnt', min_mut_cnt::text FROM num
...
SELECT * FROM pct_low_surg
ORDER BY 1
) TO 'E:\SQL\FINAL\v_perf.csv'
WITH (FORMAT CSV, HEADER);


