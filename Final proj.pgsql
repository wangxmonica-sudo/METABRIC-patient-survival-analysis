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
three_gene_subtype) is not NULL

CREATE TABLE treatment AS
SELECT patient_id,
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

ALTER TABLE public.patient_info /* add primary.foreign key to each table*/
  ADD CONSTRAINT patient_id   
  PRIMARY KEY (patient_id);     

INSERT INTO patient_info (patient_id)
SELECT DISTINCT h.patient_id
FROM   health_info h
LEFT   JOIN patient_info p USING (patient_id) /*keeps ID from both table match*/
WHERE  p.patient_id IS NULL;

ALTER TABLE health_info
ADD CONSTRAINT health_patient
FOREIGN KEY (patient_id)
REFERENCES patient_info (patient_id)
ON UPDATE CASCADE
ON DELETE SET NULL;  

INSERT INTO patient_info (patient_id)
SELECT DISTINCT t.patient_id
FROM   treatment t
LEFT   JOIN patient_info p USING (patient_id)
WHERE  p.patient_id IS NULL;

ALTER TABLE treatment
ADD CONSTRAINT t_patient
FOREIGN KEY (patient_id)
REFERENCES patient_info (patient_id)
ON UPDATE CASCADE
ON DELETE SET NULL;  

select tumor_stage from patient_info /* check range of tumor stage*/
order by tumor_stage desc;

SELECT /* separate tumor stage to 2 groups*/
    CASE
        WHEN tumor_stage <= 1 THEN 1      
        WHEN tumor_stage <= 4 THEN 2     
    END AS size_group,
    COUNT(*) AS n_cases
FROM   patient_info
GROUP  BY size_group
ORDER  BY size_group;


ALTER TABLE patient_info /* add column by tumor stage group for further analysis*/
ADD COLUMN IF NOT EXISTS size_group int;
UPDATE patient_info
SET    size_group = CASE
           WHEN tumor_stage <= 1 THEN 1
           WHEN tumor_stage <= 4 THEN 2
       END;

SELECT p.patient_id,
p.size_group,
p.overall_survival_months,
t.type_breast_surgery
from patient_info AS p JOIN treatment AS t USING (patient_id)
ORDER BY size_group; /* join patient_info to treatment table by using patient_id
list each patient_id, tumor_stage_gourp,and the treatment recevied (foucs on surgery)*/

SELECT /* how many surgeries performed to each group*/
    p.size_group,               
    t.type_breast_surgery,       
    COUNT(*) AS n_cases
FROM   patient_info  AS p
JOIN   treatment     AS t
       ON t.patient_id = p.patient_id
WHERE  t.type_breast_surgery IS NOT NULL      
GROUP  BY p.size_group, t.type_breast_surgery
ORDER  BY p.size_group,
          t.type_breast_surgery;

CREATE TABLE surgery_size_summary AS
SELECT
    p.size_group,
    t.type_breast_surgery,
    COUNT(*)                       AS n_cases,
    ROUND(AVG(p.overall_survival_months), 1) AS avg_survival_mo
FROM   patient_info AS p
JOIN   treatment     AS t  ON t.patient_id = p.patient_id
WHERE  t.type_breast_surgery IN ('Breast Conserving', 'Mastectomy')
GROUP  BY p.size_group, t.type_breast_surgery
ORDER  BY p.size_group, t.type_breast_surgery;
 /* calcualte the avg survival_mo for each group
with different surgery*/

CREATE TABLE patient_surgery_survival AS 
SELECT
    p.patient_id,
    p.size_group,
    t.type_breast_surgery,
    p.overall_survival_months  AS actual_survival,
    s.avg_survival_mo          AS group_avg_survival
FROM   patient_info  p
JOIN   treatment     t USING (patient_id)
JOIN   surgery_size_summary s
       ON s.size_group          = p.size_group
      AND s.type_breast_surgery = t.type_breast_surgery;
/* summary of surgery types, tumor stage, actul survival,
and avg survival rate*/

INSERT INTO patient_info (patient_id)
SELECT DISTINCT s.patient_id
FROM   patient_surgery_survival s
LEFT   JOIN patient_info p USING (patient_id) /*keeps ID from both table match*/
WHERE  p.patient_id IS NULL;

ALTER TABLE patient_surgery_survival /* add forgein key to link with parent table*/
ADD CONSTRAINT surgery_survival
FOREIGN KEY (patient_id)
REFERENCES patient_info (patient_id)
ON UPDATE CASCADE
ON DELETE SET NULL; 

SELECT table_name,
       column_name                   AS field,
       data_type                     AS type,
       is_nullable
FROM   information_schema.columns
WHERE  table_schema = 'public'
  AND  table_name IN ('patient_info', 'health_info', 'treatment','patient_surgery_survival')
ORDER  BY table_name, ordinal_position;
/* dictionary for the tables*/

CREATE TABLE patient_underperformers AS /*underperformers with detailed health info for 
future analysis*/
SELECT  pss.patient_id,
        pss.type_breast_surgery,
        pss.size_group,
        h.er_status_ihc,
        h.her2_status,
        h.mutation_count,
        h.nottingham_index,
        h.inferred_menopausal_state,
        h.cellularity
FROM    patient_surgery_survival AS pss
JOIN    health_info             AS h
          ON h.patient_id = pss.patient_id
WHERE   pss.actual_survival < pss.group_avg_survival
order by size_group DESC;


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
FROM   patient_underperformers pu
LEFT   JOIN treatment t USING (patient_id);
/* Drop first in case an old definition lingers */
DROP VIEW IF EXISTS v_perf_rest;

CREATE OR REPLACE VIEW v_perf_rest AS /*patients meeting the avg_survival*/
SELECT
    pss.patient_id,
    FALSE                                    AS low_perf,        
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
    tr.type_breast_surgery      AS planned_surgery_type
FROM   patient_surgery_survival pss
LEFT   JOIN health_info         hi USING (patient_id)
LEFT   JOIN treatment           tr USING (patient_id)
WHERE  pss.actual_survival >= pss.group_avg_survival;  

CREATE OR REPLACE VIEW v_perf_all AS
SELECT * FROM v_perf        
UNION ALL
SELECT * FROM v_perf_rest;  


/*summary for v_perf*/
COPY (
WITH
num AS (
    SELECT
        COUNT(*)                                   AS n_patients,
        MIN(mutation_count)                        AS min_mut_cnt,
        MAX(mutation_count)                        AS max_mut_cnt,
        ROUND(AVG(mutation_count),2)               AS avg_mut_cnt,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY mutation_count) AS p50_mut_cnt,
        MIN(nottingham_index)                      AS min_notts,
        MAX(nottingham_index)                      AS max_notts,
        ROUND(AVG(nottingham_index),2)             AS avg_notts,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY nottingham_index) AS p50_notts
    FROM v_perf
),
/*create each columm*/
surg AS (
    SELECT 'surgery_'||type_breast_surgery AS metric,
           COUNT(*)||' ('||
           ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),1)||'%)' AS val
    FROM v_perf
    GROUP  BY type_breast_surgery
),
er AS (
    SELECT 'ER_'||er_status_ihc,
           COUNT(*)||' ('||
           ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),1)||'%)'
    FROM v_perf
    GROUP  BY er_status_ihc
),
her2 AS (
    SELECT 'HER2_'||her2_status,
           COUNT(*)||' ('||
           ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),1)||'%)'
    FROM v_perf
    GROUP  BY her2_status
),
meno AS (
    SELECT 'meno_'||inferred_menopausal_state,
           COUNT(*)||' ('||
           ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),1)||'%)'
    FROM v_perf
    GROUP  BY inferred_menopausal_state
),
cell AS (
    SELECT 'cell_'||cellularity,
           COUNT(*)||' ('||
           ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),1)||'%)'
    FROM v_perf
    GROUP  BY cellularity
),
comb AS (
    SELECT
        'combo_' ||
        CASE WHEN chemotherapy THEN 'Chemo-Yes' ELSE 'Chemo-No' END
        || ' | Hormone-' || COALESCE(hormone_therapy,'Unknown')
        || ' | Radio-'   || COALESCE(radio_therapy,'Unknown')       AS metric,

        COUNT(*) || ' (' ||
        ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) || '%)'  AS val
    FROM   v_perf
    GROUP  BY chemotherapy, hormone_therapy, radio_therapy
),

corr AS (
    SELECT 'corr_mut_notts_underperf' AS metric,
           CORR(mutation_count::numeric, nottingham_index)::text AS val
    FROM v_perf
),

chi AS (
    WITH obs AS (
        SELECT type_breast_surgery AS row_cat,
               chemotherapy::text  AS col_cat,
               COUNT(*)            AS o
        FROM   v_perf
        GROUP  BY type_breast_surgery, chemotherapy
    ),
    row_tot AS ( SELECT row_cat, SUM(o) AS r_tot FROM obs GROUP BY row_cat ),
    col_tot AS ( SELECT col_cat, SUM(o) AS c_tot FROM obs GROUP BY col_cat ),
    grand   AS ( SELECT SUM(o)  AS n_tot FROM obs ),
    exp AS (
        SELECT o.o,
               (r.r_tot * c.c_tot)::numeric / g.n_tot AS e
        FROM   obs o
        JOIN   row_tot r ON r.row_cat = o.row_cat
        JOIN   col_tot c ON c.col_cat = o.col_cat
        CROSS  JOIN grand g
    )
    SELECT 'chi2_surg_chemo_underperf' AS metric,
           ROUND(SUM((o-e)*(o-e)/e),4)::text || ' (dof=1)' AS val
    FROM exp
),

long AS (
    SELECT low_perf, 'surgery' AS factor, type_breast_surgery          AS level FROM v_perf_all
    UNION ALL SELECT low_perf, 'ER',    er_status_ihc                  FROM v_perf_all
    UNION ALL SELECT low_perf, 'HER2',  her2_status                    FROM v_perf_all
    UNION ALL SELECT low_perf, 'meno',  inferred_menopausal_state      FROM v_perf_all
    UNION ALL SELECT low_perf, 'cell',  cellularity                    FROM v_perf_all
    UNION ALL SELECT low_perf, 'chemo', CASE WHEN chemotherapy THEN 'Yes' ELSE 'No' END FROM v_perf_all
    UNION ALL SELECT low_perf, 'hormone', hormone_therapy              FROM v_perf_all
    UNION ALL SELECT low_perf, 'radio',   radio_therapy                FROM v_perf_all
),
ct AS (
    SELECT factor, level,
           COUNT(*) FILTER (WHERE  low_perf)      AS n_low,
           COUNT(*) FILTER (WHERE NOT low_perf)   AS n_rest
    FROM   long
    GROUP  BY factor, level
),
tot AS (
    SELECT COUNT(*) FILTER (WHERE  low_perf)      AS n_low_all,
           COUNT(*) FILTER (WHERE NOT low_perf)   AS n_rest_all
    FROM   v_perf_all
),
rr_or AS (
    SELECT factor,
           level,
           ROUND( (n_low::numeric / n_low_all) /
                  (n_rest::numeric / n_rest_all), 4) AS rr,
           ROUND( (n_low::numeric * (n_rest_all - n_rest)) /
                  (n_rest::numeric * (n_low_all  - n_low)), 4) AS or_val
    FROM   ct, tot
),

size_stats AS (
    SELECT
        'size' || size_group || '_avg_mut' AS metric,
        ROUND(AVG(mutation_count),2)::text AS val
    FROM patient_underperformers
    GROUP BY size_group

    UNION ALL

    SELECT
        'size' || size_group || '_avg_notts',
        ROUND(AVG(nottingham_index),2)::text
    FROM patient_underperformers
    GROUP BY size_group
),

mut_notts AS (
    SELECT 'avg_mut_low',  ROUND(AVG(mutation_count) FILTER (WHERE low_perf),2)::text       FROM v_perf_all
    UNION ALL SELECT 'avg_mut_rest', ROUND(AVG(mutation_count) FILTER (WHERE NOT low_perf),2)::text      FROM v_perf_all
    UNION ALL SELECT 'p50_mut_low',  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY mutation_count) FILTER (WHERE low_perf)::text FROM v_perf_all
    UNION ALL SELECT 'p50_mut_rest', PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY mutation_count) FILTER (WHERE NOT low_perf)::text FROM v_perf_all
    UNION ALL SELECT 'avg_notts_low',  ROUND(AVG(nottingham_index) FILTER (WHERE low_perf),2)::text      FROM v_perf_all
    UNION ALL SELECT 'avg_notts_rest', ROUND(AVG(nottingham_index) FILTER (WHERE NOT low_perf),2)::text FROM v_perf_all
    UNION ALL SELECT 'p50_notts_low',  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY nottingham_index) FILTER (WHERE low_perf)::text FROM v_perf_all
    UNION ALL SELECT 'p50_notts_rest', PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY nottingham_index) FILTER (WHERE NOT low_perf)::text FROM v_perf_all
),

pct_low_surg AS (
    SELECT
        'pct_low_'||type_breast_surgery AS metric,
        ROUND(100.0*SUM(low_perf::int)/COUNT(*),1)::text || '%'       AS val
    FROM   v_perf_all
    GROUP  BY type_breast_surgery
)


SELECT 'n_patients',        n_patients::text FROM num UNION ALL
SELECT 'min_mut_cnt',       min_mut_cnt::text FROM num UNION ALL
SELECT 'max_mut_cnt',       max_mut_cnt::text FROM num UNION ALL
SELECT 'avg_mut_cnt',       avg_mut_cnt::text FROM num UNION ALL
SELECT 'p50_mut_cnt',       p50_mut_cnt::text FROM num UNION ALL
SELECT 'min_notts',         min_notts::text   FROM num UNION ALL
SELECT 'max_notts',         max_notts::text   FROM num UNION ALL
SELECT 'avg_notts',         avg_notts::text   FROM num UNION ALL
SELECT 'p50_notts',         p50_notts::text   FROM num UNION ALL

SELECT * FROM surg UNION ALL
SELECT * FROM er   UNION ALL
SELECT * FROM her2 UNION ALL
SELECT * FROM meno UNION ALL
SELECT * FROM cell UNION ALL
SELECT * FROM comb UNION ALL
SELECT * FROM corr UNION ALL
SELECT * FROM chi  UNION ALL

SELECT 'RR_'||factor||'_'||level, rr::text     FROM rr_or UNION ALL
SELECT 'OR_'||factor||'_'||level, or_val::text FROM rr_or UNION ALL

SELECT * FROM size_stats UNION ALL
SELECT * FROM mut_notts UNION ALL
SELECT * FROM pct_low_surg

ORDER BY 1
) TO 'E:\SQL\FINAL\v_perf.csv'
WITH (FORMAT CSV, HEADER);