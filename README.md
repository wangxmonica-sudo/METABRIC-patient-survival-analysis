# METABRIC-patient-survival-analysis
This project uses the METABRIC breast cancer dataset (1,900 patient records) to study the relationship between tumor stage, treatment type, and patient survival outcomes.

The entire analysis is implemented in PostgreSQL, showcasing SQL data modeling, cleaning, feature engineering, and statistical analysis techniques commonly used in healthcare data science and general analytics.

# Tools:
PostgreSQL – relational schema design, joins, and constraints

SQL – data cleaning, grouping, aggregation, correlation, chi-square test, risk ratios

CSV Export – summary output for downstream visualization (Python, R, or Tableau)

# Key Features
Designed normalized tables (patient_info, health_info, treatment) with primary/foreign keys.

Grouped patients by tumor stage (early vs advanced) for stratified analysis.

Computed average survival months across treatment/surgery types.

Identified underperforming patients (actual survival < group average).

Ran correlation analysis between mutation count and Nottingham index.

Performed chi-square test for categorical associations (e.g., surgery × chemotherapy).

Calculated risk ratios (RR) and odds ratios (OR) to compare patient outcomes.

Exported consolidated results to CSV for visualization and reporting.

# Example Outputs
Survival statistics grouped by tumor stage and surgery type.

Kaplan–Meier-style summary using SQL aggregation.

CSV output of correlation, chi-square, RR/OR metrics for underperformers vs rest.

# Dataset resources 

**Kaggle:** Breast Cancer (METABRIC) — clinical profiles CSV versions suitable for quick analysis.  
  https://www.kaggle.com/datasets/gunesevitan/breast-cancer-metabric

  **Original studies (for citation):**
- Curtis *et al.* (2012), *Nature*: The genomic and transcriptomic architecture of 2000 breast tumours.  
  https://pmc.ncbi.nlm.nih.gov/articles/PMC3440846/
- Pereira *et al.* (2016), *Nature Communications*: Somatic mutation profiles of 2433 breast cancers refine landscape of driver genes.  
  https://www.nature.com/articles/ncomms11479
