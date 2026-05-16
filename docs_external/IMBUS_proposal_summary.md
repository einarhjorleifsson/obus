# IMBUS Project — Proposal Summary

**Full title:** Implementing More and Better Use of ICES Survey data  
**Acronym:** IMBUS  
**Call:** EMFAF-2025-PIA-FisheriesScientificAdvice  
**Proposal number:** 101241455  
**Duration:** 24 months  
**Total budget:** ~€599k (80% EU co-funding, ~€479k EU contribution)  
**Official start date:** 2025-09-01 (may shift)  
**Document updated:** 2026-05-16 — project is at month ~8.5 of 2

---

## Background and Rationale

Fisheries-independent bottom trawl surveys are conducted annually under the EU Data Collection
Framework. Beyond their traditional role in informing catch advice, these data are increasingly used for
ecosystem assessments, climate change tracking, and biodiversity monitoring. However, their broader
use is hampered by two problems:

1. **Access:** Accessing and merging the data requires a high level of technical skill. Non-scientific
   users (Advisory Councils, fisheries organizations, NGOs, managers) find the data largely out of reach.
2. **Quality:** Quality control has historically been post-operational — months after data collection,
   often too late to correct errors at source.

IMBUS addresses both problems through standardized tools and improved on-vessel quality assurance.

---

## Consortium

| Partner | Country | Role |
|---|---|---|
| DTU Aqua | Denmark | Coordinator |
| ICES | Denmark | Partner — WP5 lead |
| Marine Institute | Ireland | Partner — WP3 lead |
| EV-ILVO | Belgium | Partner — WP4 lead |
| CSIC/IEO | Spain | Partner |
| Martin Pastoors (SC) | Netherlands | Subcontractor — WP6 coordinator |
| Einar Hjörleifsson (SC) | Iceland | Subcontractor — **WP2 coordinator** |
| Laurence Kell (SC) | UK | Subcontractor — WP3/WP4 |

---

## Work Packages Overview

Calendar dates assume 2025-09-01 start (month 1 = Sep 2025).

| WP | Title | Lead | Duration | Calendar |
|---|---|---|---|---|
| WP1 | Project management and coordination | DTU/Hvingel | M1–M24 | Sep 2025 – Aug 2027 |
| WP2 | User requirements, data formats and meta-data | **DTU/Hjörleifsson** | M1–M12 | Sep 2025 – **Aug 2026** |
| WP3 | Implementing quality control tools on survey vessels | MI/Stokes | M1–M24 | Sep 2025 – Aug 2027 |
| WP4 | Making better use of survey data | EV-ILVO/Sys | M1–M24 | Sep 2025 – Aug 2027 |
| WP5 | Sustainability, replication and exploitation | ICES/Soni | M1–M24 | Sep 2025 – Aug 2027 |
| WP6 | Dissemination and communication | DTU/Pastoors | M1–M24 | Sep 2025 – Aug 2027 |

**WP2 closes in ~3 months (Aug 2026).**

---

## WP2 in Detail — User Requirements, Data Formats and Meta-data

**Lead:** Einar Hjörleifsson (subcontracted to DTU)  
**Duration:** M1–M12  
**Budget:** ~€43k (incl. €20k subcontracting)

### Objectives

1. Assess user requirements of different user groups for potential applications of survey data.
2. Develop a data format that can be used to generate the products described in WP3–5.
3. Generate meta-data descriptions of the overall data.
4. Process current DATRAS data into the new format, correcting detected errors and accounting for zero
   observations and length/weight conversions.

### Tasks

| Task | Name | Description |
|---|---|---|
| T2.1 | User requirements | Workshops/sessions with end-users (scientists, Advisory Councils, fisheries organizations, NGOs) to specify requirements guiding further IMBUS work |
| T2.2 | Integration of data | Download and merge HH, HL and CA record types; standardize across surveys and time; handle zero observations and length/weight conversions; correct units and taxa names |
| T2.3 | Data formats and meta-data | Document all data formats and meta-data produced in T2.2 |
| T2.4 | Distribution of data | Disseminate raw and standardized DATRAS data on an ICES web portal in R-binary and parquet format |

### Deliverables and status

| Deliverable | Description | Month | Calendar date | Status |
|---|---|---|---|---|
| D2.1 | User requirements document | M6 | Feb 2026 | ✅ Complete — delivered ~2 months late (2026-04-02); 55 respondents, 18 formal requirements |
| D2.2 | Data formats and meta-data documentation | M11 | Jul 2026 | 🔶 Draft written (May 2026, `D2.2_data_formats_metadata_draft.md`); needs review and finalisation |
| D2.3 | Integrated data product (R-binary and parquet) | M12 | Aug 2026 | 🔶 Due in ~3 months — core HH/HL/CA parquets live at `heima.hafro.is/~einarhj/datras/`; hosting is personal server, not ICES |
| D2.4 | Data product on ICES web portal (parquet) | M12 | Aug 2026 | 🔴 Requires transfer to ICES open access portal — pending WP5/ICES coordination |

### Key milestones

| Milestone | Description | Month | Calendar date | Status |
|---|---|---|---|---|
| MS2 | User requirements finalized | M6 | Feb 2026 | ✅ Complete (2026-04-02, ~2 months late) |
| MS3 | Data product on ICES open access web portal | M12 | Aug 2026 | 🔴 Depends on D2.4 — ICES transfer pending ||

---

## T2.1 User Requirements — Summary (April 2026)

Two documents were delivered on 2026-04-02:

- **`20260402 IMBUS_T2_1_User_Requirements_v2.docx`** — formal T2.1 requirements report (55
  respondents, 18 formal requirements, authors: Pastoors et al.)
- **`20260402 IMBUS_Survey_User_Requirements_results_v2.docx`** — detailed quantitative results
  annex (charts and open-text tables)

### Respondents

55 stakeholders responded. Classified into two overlapping groups (12 in both):

- **Scientific users** (ICES Expert Group members, academia/research): n = 45
- **Stakeholder users** (government, advisory councils, fishing industry, NGOs): n = 20

### Headline findings

Counts below are from the raw questionnaire data (n = 55); minor discrepancies exist between these
and the docx reports (noted where relevant).

- **3 of 55 respondents do not currently use ICES survey data** (academia, fishing industry,
  government) — a small but relevant potential new-user segment.
- Use frequency: 26 use data "a few times per year"; 11 daily/weekly; 9 monthly; 4 rarely.
- **Data products — first-choice ranking**: Raw survey data (17 respondents) is most often ranked
  #1, followed by abundance/biomass indices (14). By weighted score the docx reverses this order;
  the discrepancy suggests indices are broadly valued but raw data is the primary daily need.
- **Preferred access**: Downloadable files (42), interactive web portal (36), R package (30), API (12).
  *(The docx summary table undercounts by 2–4 for the top two methods.)*
- **Preferred formats**: CSV (45), Excel (33), Shapefiles/GeoJSON (24), Parquet (4).
  *(The docx inverts Excel and Shapefiles — raw data shows Excel clearly higher than Shapefiles.)*
- **Only 4 of 55 respondents explicitly selected Parquet** as a preferred format. CSV and R
  objects are the dominant programmatic access routes; Parquet is not yet a widely known format
  in this user community.
- **R is the dominant analysis tool** (37 respondents); Excel is close behind (33); Python is used
  by only 2 respondents — strongly validating the R-package-first approach.
- The four most-cited challenges in open text: data format complexity (HH/HL/CA structure,
  column name changes), quality-control inconsistencies, poor discoverability, and slow downloads.
- 17 respondents willing to join a follow-up workshop.

### 18 Formal User Requirements

★ = High priority (13 of 18)

Counts in parentheses are from the raw data (n = 55).

| ID | Theme | Requirement | Raw data support | Priority |
|---|---|---|---|---|
| UR-D1 ★ | Data products | Raw DATRAS data with provenance and quality flags | Most-cited first-choice product (17/55) | High |
| UR-D2 ★ | Data products | Standardised, QC-processed datasets with consistent naming and units | Top-4 by weighted rank | High |
| UR-D3 ★ | Data products | Pre-computed abundance/biomass indices compatible with assessment models | 2nd most-cited first-choice (14/55); top weighted rank | High |
| UR-D4 ★ | Data products | Length/age composition data alongside spatial products | Top-4 by weighted rank | High |
| UR-S1 ★ | Spatial/temporal | Haul-level and aggregated spatial products; custom area support | Individual hauls 40/55; ICES rectangle/subdivision 23/55 | High |
| UR-S2 ★ | Spatial/temporal | Full time series with documented breaks, gear changes, and coverage shifts | >20 years: 37/55 | High |
| UR-A1 ★ | Access | CSV + R + Excel + GeoJSON/Shapefile download formats | CSV 45; Excel 33; Shapefiles 24; Parquet 4 | High |
| UR-A2 ★ | Access | Interactive web portal usable without programming skills | 36/55; primary route for non-technical users | High |
| UR-A3 ★ | Access | Updated R package aligned with current DATRAS field names | R package: 30/55; R most-used tool (37/55) | High |
| UR-A4 | Access | Data within weeks of survey completion; notification alerts | Within weeks: 19/55; within days: 8/55 | Medium |
| UR-P1 ★ | Portal | Species, time, and spatial filtering with integrated export | Species filter: 47/55; time filter: 43/55; spatial: 37/55 | High |
| UR-P2 ★ | Portal | Shareable persistent links to standard views and visualisations | — | High |
| UR-U1 | Use cases | Products and documentation address the six primary use case scenarios | Monitoring 40; research 35; stock assessment 32; spatial planning 26 | Medium |
| UR-Q1 ★ | Quality/metadata | Concise per-survey metadata fact sheet: coverage, gear, QC, caveats | Top open-text theme | High |
| UR-Q2 | Quality/metadata | Public mechanism to report and track data errors | Open-text theme | Medium |
| UR-Q3 ★ | Quality/metadata | Documented, reproducible CPUE/index code (TAF/GitHub) | Open-text theme | High |
| UR-Sp1 ★ | Species | Include non-commercial and benthic species in products | Elasmobranchs, benthic inverts mentioned across groups | High |
| UR-Su1 | Surveys | Clearly communicate which surveys are included or outside DATRAS | NS-IBTS dominant; EVHOE, BTS, BITS also cited | Medium |

### Mapping of requirements to {obus}

| ID | Requirement | {obus} coverage | Notes |
|---|---|---|---|
| UR-D1 | Raw DATRAS data with provenance and quality flags | ✅ | `dr_get()`, `dr_con_raw()` provide raw data; `dr_check_*()` implements quality checks |
| UR-D2 | Standardised, QC-processed datasets with consistent naming and units | ✅ | `dr_get(source="parquet")` / `dr_con()` deliver new-style names, correct types, NA-cleaned data |
| UR-D3 | Pre-computed abundance/biomass indices compatible with assessment models | ✅ | `dr_cpue_by_length()`, `dr_cpue_by_haul()` replicate ICES CPUE products from first principles |
| UR-D4 | Length/age composition data alongside spatial products | ✅ | HL/CA parquets provide length and age data; `dr_add_length_cm/mm()` handles units |
| UR-S1 | Haul-level and aggregated spatial products; custom area support | 🔶 | Haul-level lat/lon available in HH; aggregation to ICES rectangles/areas not yet in package |
| UR-S2 | Full time series with documented breaks, gear changes, and coverage shifts | 🔶 | Full 1965–present time series accessible; documentation of breaks/gear changes not systematic |
| UR-A1 | CSV + R + Excel + GeoJSON/Shapefile download formats | 🔶 | Parquet via `dr_get()`; CSV via `collect()` + `write_csv()`; no GeoJSON output yet |
| UR-A2 | Interactive web portal usable without programming skills | 🔴 | Out of scope for {obus} — Shiny portal is a separate deliverable (WP4/WP5) |
| UR-A3 | Updated R package aligned with current DATRAS field names | ✅ | {obus} serves as the modern alternative to icesDATRAS; new-style names throughout |
| UR-A4 | Data within weeks of survey completion; notification alerts | 🔶 | `dr_download()` refreshes parquets from the API; no notification system |
| UR-P1 | Species, time, and spatial filtering with integrated export | 🔶 | The icesDATRAS API filters only by Year and Quarter; `dr_con()` / `dr_get(source="parquet")` allows filtering by any variable (species, spatial area, gear, etc.) before `collect()` — the parquet approach directly addresses this requirement programmatically, though a non-technical portal interface remains WP4/WP5 scope ||
| UR-P2 | Shareable persistent links to standard views and visualisations | 🔴 | Portal links are WP4/WP5 scope |
| UR-U1 | Products and documentation address the six primary use case scenarios | 🔶 | README and vignettes provide worked examples; coverage of all six scenarios incomplete |
| UR-Q1 | Concise per-survey metadata fact sheet: coverage, gear, QC, caveats | 🔴 | `AGENTS.md` covers field-level metadata; per-survey fact sheets not yet produced |
| UR-Q2 | Public mechanism to report and track data errors | 🔶 | GitHub Issues provides an informal mechanism; no formal tracking process |
| UR-Q3 | Documented, reproducible CPUE/index calculation code (TAF/GitHub) | ✅ | `dr_cpue_by_length/haul()` are open, documented, reproducible code on GitHub |
| UR-Sp1 | Include non-commercial and benthic species in products | 🔶 | `dr_lookup_species` covers all taxa in parquets; no curated non-commercial species products yet |
| UR-Su1 | Clearly communicate which surveys are included or outside DATRAS | 🔶 | `dr_lookup_vocabulary` covers survey codes; no explicit survey availability inventory ||

**Key observations from the raw data:**

1. **UR-A3** ("update R package aligned with current DATRAS field names") is explicitly a High
   priority requirement — this is precisely what the new-style naming refactor in {obus} delivers.
   One respondent (ID 41) stated directly: *"My main issue is using Datras new headings and the
   icesDatras package that does not use the new headings"* — a verbatim validation of the refactor.

2. **Parquet is not yet a user-known format.** Only 4 of 55 respondents selected Parquet as a
   preferred format. {obus} uses parquet internally for speed, but the user-facing output should
   default to CSV and R objects. This is already the case via `collect()` and `dr_get()`.

3. **R package access (30/55) outranks API (12/55) by a wide margin.** Python usage is negligible
   (2/55). The R-first approach of {obus} is well-aligned with the actual user base.

4. **Excel is the second most-requested format (33/55)**, ahead of Shapefiles (24/55). The docx
   reports incorrectly inverted these. A helper to export to `.xlsx` (e.g. via `writexl`) may be
   worth adding to vignette examples.

---

## Role of the {obus} Package

{obus} is the primary technical vehicle for WP2. As of 2026-05-16 (month ~8.5), it addresses tasks T2.2 and T2.4 directly:

### T2.2 — Data integration ✅ Largely complete

`dr_get()`, `dr_con()`, and `dr_con_raw()` provide download, merging and standardization of HH, HL
and CA record types across all ICES surveys and years. Implemented:

- Type consistency via `dr_settypes()`; sentinel value replacement (−9 → NA)
- Column name standardization (old → new) via `dr_translate()` with `dictionary` argument
- Species name lookup via `dr_lookup_species`
- Length/weight unit conversions: `dr_add_length_cm()`, `dr_add_length_mm()`
- CPUE arithmetic (DataType-aware): `dr_add_n_and_cpue()`
- Unique haul identifiers (auto-detects naming style): `dr_add_id()`
- Zero-fill: `dr_cpue_by_length(zerofill = TRUE)`
- HL record type classification: `dr_add_record_type()`

Derived product record types (FL, LT, CPUEL, CPUEA, CW, IDX) are accessible via `dr_get()` but
these come from the XML/API path; no pre-built parquets for these yet.

### T2.3 — Data formats and meta-data 🔶 Content exists, formal document pending

`AGENTS.md` in the obus repository is a comprehensive machine-readable specification covering data
schemas, column name mappings (old vs. new style), unit conventions, join keys, DataType arithmetic,
and known issues. This content forms the basis for D2.2 (due Jul 2026) but has not yet been formatted
as a formal project deliverable report.

### T2.4 — Data distribution 🔴 Prototype live; ICES transfer pending

Standardized HH, HL and CA parquet files are live at `https://heima.hafro.is/~einarhj/datras/`
(personal server, not the ICES open access portal). Accessible via:

- `dr_get(source = "parquet")` — full import into R
- `dr_con("HH")` / `dr_con("HL")` / `dr_con("CA")` — lazy DuckDB connection (near-instantaneous)
- `dr_download()` — utility to refresh the hosted parquets from the ICES API

Transfer to the ICES open access web portal (D2.4, MS3, due Aug 2026) requires coordination with
WP5 (ICES/Soni) and is the main outstanding step before the formal deliverable can be claimed.

---

### Summary — WP2 task status as of May 2026

| Task | Status | Gap / next step |
|---|---|---|
| T2.1 User requirements | ✅ Complete | D2.1 delivered 2026-04-02 (~2 months after M6 deadline); 55 respondents, 18 formal requirements |
| T2.2 Data integration | ✅ Largely complete | Minor: derived-product parquets (FL, LT, etc.) not yet pre-built |
| T2.3 Data formats & meta-data | 🔶 Draft complete | `D2.2_data_formats_metadata_draft.md` written (May 2026); review and finalise before Jul 2026 |
| T2.4 Data distribution | 🔴 Prototype only | Transfer parquets from personal server to ICES portal (due Aug 2026) |

---

## Contribution to Other Work Packages

Beyond WP2, {obus} provides infrastructure relevant to other WPs:

- **WP3 (Quality control):** `dr_check_subfactor()`, `dr_check_totalno()`, `dr_check_sentinels()`,
  and `dr_check_all()` implement post-fetch QC logic that complements the on-vessel QA tools being
  built in WP3. These checks detect sentinel values, subsampling factor violations, and TotalNumber
  arithmetic inconsistencies across the full historical DATRAS archive.
- **WP4 (Better use):** `dr_cpue_by_length()` and `dr_cpue_by_haul()` replicate the ICES CPUE
  products from first principles, providing a transparent, reproducible baseline for the further analysis,
  modelling and visualization work in WP4.
- **WP5 (Sustainability):** The R package is openly hosted on GitHub. Data access connects directly
  to ICES-hosted parquet files (once transferred). Both the package and the parquet files conform to
  the FAIR data principles and open-access requirements of D2.4.
