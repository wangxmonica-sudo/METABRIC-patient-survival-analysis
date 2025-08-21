
---

## Data Dictionary (columns used in this repo)

**Core identifiers & outcomes**
- `patient_id` — Unique patient/sample identifier  
- `age_at_diagnosis` (years) — Age at diagnosis  
- `tumor_size_mm` (mm) — Primary tumor size  
- `tumor_stage` (1–4) — Clinical stage as ordinal 1–4  
- `overall_survival_months` (months) — Time from diagnosis to death/last contact  
- `vital_status` — Survival status at last follow-up (e.g., Alive/Dead)

**Clinical & molecular features**
- `cancer_type_detailed` — Histologic diagnosis  
- `cellularity` — Tumor cellularity (Low/Moderate/High)  
- `pam50_subtype` — Molecular subtype (Luminal A/B, Basal, HER2-enriched, Normal-like)  
- `er_status` / `er_status_ihc` — Estrogen receptor status (assay / IHC)  
- `her2_status` — HER2 status (Positive/Negative)  
- `tumor_other_histologic_subtype` — Additional histology annotation  
- `mutation_count` — Total somatic mutation count  
- `nottingham_index` — Nottingham Prognostic Index  
- `inferred_menopausal_state` — Pre/Post  
- `relapse_free_months` (months) — Time to relapse or censoring  
- `relapse_free_status` — Relapse event indicator  
- `three_gene_subtype` — e.g., ER+/HER2−, ER−/HER2+, Triple Negative, ER+/HER2+

**Therapies & procedures**
- `chemotherapy` (boolean) — Chemotherapy administered  
- `hormone_therapy` — Yes/No/Unknown  
- `radio_therapy` — Yes/No/Unknown  
- `type_breast_surgery` — Breast Conserving or Mastectomy

**Derived in this repo**
- `size_group` — Tumor stage grouping (1 = early ≤1, 2 = advanced 2–4)  
- `actual_survival` — Alias of `overall_survival_months` in summaries  
- `group_avg_survival` — Avg survival for the same (`size_group` × `type_breast_surgery`) cohort  
- `low_perf` — TRUE if `actual_survival` < `group_avg_survival`  
- `planned_surgery_type` — Alias used in views

> **Note:** This repo includes only a small sample CSV for reproducibility. Please download the full dataset from the sources below.
