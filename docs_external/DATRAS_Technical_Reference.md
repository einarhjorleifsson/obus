# DATRAS Technical Reference

Synthesised from ICES DATRAS specification documents (all in `docs_external/DATRAS_documentation/`):

| File | Description |
|------|-------------|
| `3.1.DATRAS_dataproducts_units.pdf` | Units in DATRAS Products, v3.1 (2021) |
| `DATRAS_FAQs.pdf` | DATRAS FAQs, v3.0 (2014) |
| `Indices_Calculation_Steps_IBTS.pdf` | NS-IBTS indices calculation procedure, v1.2 (2022) |
| `Indices_Calculation_Steps_BITS.pdf` | BITS indices calculation procedure, v1.1 (2013) |
| `ALK_automated_substitution.pdf` | Automated ALK substitution procedure (2020) |
| `Swept_area_km2_algorithms_pdf.pdf` | Swept area calculation algorithms, v1.4 (2022) |
| `Final_report_to_EU_Bootstrap_calculation.pdf` | Bootstrap confidence limits for abundance indices (2007) |
| `Workshop_report_on_variance_estimation.pdf` | DATRAS workshop on confidence limit estimation (2006) |
| `SWC-IBTS_and_ROCKALL_IndicesCalculation_pre2011.pdf` | SWC-IBTS/Rockall historical indices (pre-2011) |
| `BITS_AreaWeights.csv` | BITS depth-stratum area weights (km²) by SD and depth layer |
| `BITS_ConversionFactor_to_TVL.csv` | BITS gear conversion factors for cod CPUE to TVL equivalent |

This file is a domain reference for field names, units, and data conventions across all
DATRAS record types. For obus package code-flow notes see AGENTS.md.

---

## Record-type join key

HH, HL, and CA records are linked by their **first 11 fields**:

> Quarter · Country · Ship · Gear · StNo · HaulNo · Year

(plus RecordType, SweepLngt, GearEx, DoorType — completing position 1–11)

In practice, the meaningful subset is: **Survey + Year + Quarter + Country + Ship + Gear + StNo + HaulNo**.
`dr_add_id()` builds a unique `.id` from Survey, Year, Quarter, Country, Platform, Gear, StationName, HaulNumber.

---

## Field dependencies

Several DATRAS fields have values or units that can only be interpreted correctly
in the context of another field — sometimes from the same record, sometimes from
the HH table. The tables below map those relationships.

### Raw DATRAS fields

| Field | Table | Depends on | Dep. table | Nature of dependency |
|-------|-------|-----------|------------|----------------------|
| `TotalNo` | HL | `DataType` | HH | R/S: total fish in haul. C: total raised to 1 hr haul |
| `NoMeas` | HL | `DataType` | HH | R/S: fish measured in sub-sample. C: fish measured (or NA) |
| `SubFactor` | HL | `DataType` | HH | R: must be ≥ 1. S: must be > 1. C: must be = 1 |
| `SubWgt` | HL | `DataType` | HH | R/S: weight of sub-sampled fish. C: weight raised to 1 hr |
| `CatCatchWgt` | HL | `DataType` | HH | R/S: total catch weight (same scope as TotalNo). C: raised to 1 hr |
| `HLNoAtLngt` | HL | `DataType` | HH | R/S: fish at this length in sub-sample. C: fish per hour at this length |
| `CatIdentifier` | HL | `DataType` | HH | R/S: ≥ 1, up to 5 size-sorting categories. C: always 1 |
| `LngtClass` | HL | `LngtCode` | HL | `"."` or `"0"`: value in mm (divide by 10 for cm). `"1"`,`"2"`,`"5"`: value already in cm |
| `SpecCode` | HL/CA | `SpecCodeType` | HL/CA | `W`: WoRMS AphiaID. `T`: ITIS TSN. `N`: NODC code |
| `AreaCode` | CA | `AreaType` | CA | Code system depends on area type (ICES rect, national, etc.) |
| `Maturity` | CA | `MaturityScale` | CA | Maturity code meaning depends on which scale was used (ICES, national, etc.) |
| `LT_Weight` | LT | `UnitWgt` | LT | Physical unit of weight varies per record |
| `LT_Items` | LT | `UnitItem` | LT | Physical unit of count varies per record |

### Column added to server parquets

The HH, HL, and CA parquets on the server contain the original DATRAS exchange
fields (new-style names) plus one obus-added column:

| Column | Function | Inputs | Rule |
|--------|----------|--------|------|
| `.id` | `dr_add_id()` | Survey, Year, Quarter, Country, Platform, Gear, StationName, HaulNumber (HH/HL/CA) | Paste 8 fields with `":"` separator |

### User-pipeline derived fields

These are not stored anywhere; compute them in your own pipeline with `dr_add_*`
functions after fetching the raw parquet data.

| Derived field | Function | Inputs (table) | Formula / rule |
|---------------|----------|---------------|----------------|
| `date` | `dr_add_date()` | Year, Month, Day (HH) | `make_date(Year, Month, Day)` |
| `time` | `dr_add_starttime()` | Year, Month, Day, TimeShot (HH) | Parse `TimeShot` as hhmm, combine with date |
| `length_cm` | `dr_add_length_cm()` | LngtClass, LngtCode (HL) | LngtCode `"."`/`"0"`: `LngtClass / 10`. Others: `LngtClass` |
| `length_mm` | `dr_add_length_mm()` | LngtClass, LngtCode (HL) | LngtCode `"."`/`"0"`: `LngtClass`. Others: `LngtClass * 10` |
| `n_haul` | `dr_add_n_and_cpue()` | HLNoAtLngt, SubFactor (HL); DataType, HaulDur (HH) | R/S/P: `HLNoAtLngt * SubFactor`. C: `HLNoAtLngt * SubFactor * HaulDur / 60` |
| `n_hour` | `dr_add_n_and_cpue()` | HLNoAtLngt, SubFactor (HL); DataType, HaulDur (HH) | R/S/P: `HLNoAtLngt * SubFactor / HaulDur * 60`. C: `HLNoAtLngt * SubFactor` |

---

## Sentinel values

| Value | Meaning |
|-------|---------|
| `-9`  | Missing / not applicable. Not a real value. Replaced with `NA` in obus fetchers. |

---

## DataType (HH field, also governs HL interpretation)

Four reporting modes used by national submitters:

| DataType | Name | Meaning |
|----------|------|---------|
| `R` | Raw / recorded by haul | Sorted catch; some species may be subsampled. SubFactor ≥ 1. |
| `S` | Sub-sampled | Bulk unsorted catch sub-sampled before sorting. SubFactor > 1. |
| `C` | CPUE | All counts already raised to 1 hour of hauling. SubFactor = 1. |
| `P` | Pseudocategory / size-stratified | Sorted catch split into explicit size strata, each with its own CatIdentifier and SubFactor. Arithmetic identical to R. |

### Typical on-board sampling process

NOTE: This is inferred from the data structure, so possibly wrong.

**DataType R — sort, then optionally subsample:**
The full catch is sorted by species on deck. For low-abundance species the entire sorted pile is
counted and measured (SubFactor = 1). For abundant species a random weight sub-sample is drawn from
the sorted pile; only that sub-sample is measured, and SubFactor = total_sorted_weight /
subsample_weight encodes the raising factor. `HLNoAtLngt` is the measured count in the sub-sample;
`TotalNo ≈ sum(HLNoAtLngt) × SubFactor` recovers the estimated total catch.

**DataType P — size-stratified subsampling:**
Same general flow as R, but the sorted catch is further divided into explicit size strata before
subsampling. Each stratum gets its own CatIdentifier and SubFactor. A typical pattern is that
abundant medium-sized fish are subsampled (SubFactor > 1) while rare large (or very small) fish
are fully enumerated in their own CatIdentifier (SubFactor = 1) — simply because there are too few
of them to bother subsampling. For example: 169 fish at 280–370 mm measured from a subsample with
SubFactor 2.65 (CatIdentifier 21); 2 fish at 380–390 mm all measured with SubFactor 1
(CatIdentifier 22). The arithmetic is identical to R: `n_haul = HLNoAtLngt × SubFactor`, applied
per stratum.

**DataType S — subsample first, then sort:**
The bulk catch is too large to sort entirely. A random weight sub-sample is drawn from the *unsorted*
pile; that sub-sample is then sorted and measured. SubFactor > 1 always. `HLNoAtLngt` is the measured
count in the sub-sample; `TotalNo ≈ sum(HLNoAtLngt) × SubFactor` recovers the estimated total catch.

**DataType C — national lab pre-raises before submission:**
The national laboratory has already standardised all counts to a 1-hour tow before submitting to
DATRAS. The submission does **not** contain raw haul counts; it contains CPUE values. This does
*not* imply that every fish was individually measured — the lab may well have applied its own
sub-sampling protocol on-board — but any such raising was resolved internally and is invisible in
the submitted data. SubFactor = 1 (no further raising is required by the recipient).
`HLNoAtLngt` is fish *per hour* at that length, not fish in a physical sub-sample.

### HL field rules per DataType

| HL field | DataType R | DataType S | DataType C |
|----------|-----------|-----------|-----------|
| `TotalNo` | Total fish (species/sex/category) in haul | Same | Total fish raised to 1 hr haul |
| `NoMeas` | Fish measured in sub-sample | Same | Fish measured, or -9 if not recorded |
| `SubFactor` | ≥ 1; TotalNo = NoMeas × SubFactor | > 1; same | Always 1 (no raising needed) |
| `SubWgt` | Weight of sub-sampled fish (NoMeas) | Same | Weight raised to 1 hr (or -9) |
| `CatCatchWgt` | Catch weight (same scope as TotalNo) | Same | Catch weight raised to 1 hr |
| `HLNoAtLngt` | Fish in sub-sample at this length; TotalNo = Sum(HLNoAtLngt) × SubFactor | Same | Fish *per hour* at this length (CPUE); TotalNo = Sum(HLNoAtLngt) |
| `CatIdentifier` | Category ID (≥1); use 1 if only one category | Same | Always 1 |

`dr_add_n_and_cpue()` back-converts DataType C to per-haul counts:
`n_haul = HLNoAtLngt × SubFactor × HaulDur / 60`; `n_hour = HLNoAtLngt × SubFactor`.
For R/S/P: `n_haul = HLNoAtLngt × SubFactor`; `n_hour = n_haul / HaulDur × 60`.

### CatIdentifier

Used when a species catch is size-sorted into subgroups with different sub-sampling factors within the
same haul/species/sex. Up to 5 categories per species per haul. If no size sorting occurred, CatIdentifier = 1.
Different sex codes for the same species do **not** require different CatIdentifier values.

---

## Exchange Data field units — HH record

| Field (old-style) | Unit / vocab |
|-------------------|-------------|
| `RecordType` | vocab.ices.dk ref=191 |
| `Quarter` | vocab.ices.dk ref=12 |
| `Country` | vocab.ices.dk ref=4 |
| `Ship` | vocab.ices.dk ref=3 |
| `Gear` | vocab.ices.dk ref=2 |
| `SweepLngt` | Metres |
| `GearEx` | vocab.ices.dk ref=97 |
| `DoorType` | vocab.ices.dk ref=98 |
| `StNo` | National station code/number |
| `HaulNo` | Numeric |
| `Year` | yyyy |
| `Month` | vocab.ices.dk ref=13 |
| `Day` | dd |
| `TimeShot` | GMT, **hhmm** |
| `DepthStratum` | vocab.ices.dk ref=99 |
| `HaulDur` | **Minutes** |
| `DayNight` | vocab.ices.dk ref=8 |
| `ShootLat` | Degree.Decimal Degree |
| `ShootLong` | Degree.Decimal Degree |
| `HaulLat` | Degree.Decimal Degree |
| `HaulLong` | Degree.Decimal Degree |
| `StatRec` | ICES statistical rectangle (based on shooting position) |
| `Depth` | **Metres** (bottom depth; equals trawling depth for bottom trawls) |
| `HaulVal` | vocab.ices.dk ref=1 |
| `HydroStNo` | National hydrographic station code |
| `StdSpecRecCode` | vocab.ices.dk ref=88 |
| `BySpecRecCode` | vocab.ices.dk ref=89 |
| `DataType` | vocab.ices.dk ref=9 |
| `Netopening` | Metres |
| `Rigging` | vocab.ices.dk ref=181 |
| `Tickler` | vocab.ices.dk ref=182 |
| `Distance` | **Metres** |
| `Warplngt` | Metres |
| `Warpdia` | Millimetres |
| `WarpDen` | Kg per linear metre |
| `DoorSurface` | Square metres |
| `DoorWgt` | Kilograms |
| `DoorSpread` | Metres |
| `WingSpread` | Metres |
| `Buoyancy` | Kilograms |
| `KiteDim` | Square metres |
| `WgtGroundRope` | Kilograms |
| `TowDir` | Degrees |
| `GroundSpeed` | Knots |
| `SpeedWater` | Knots |
| `SurCurDir` | Degrees |
| `SurCurSpeed` | Metres/second |
| `BotCurDir` | Degrees |
| `BotCurSpeed` | Metres/second |
| `WindDir` | Degrees |
| `WindSpeed` | Metres/second |
| `SwellDir` | Degrees |
| `SwellHeight` | Metres |
| `SurTemp` | Celsius degrees |
| `BotTemp` | Celsius degrees |
| `SurSal` | PSU |
| `BotSal` | PSU |
| `ThermoCline` | vocab.ices.dk ref=112 |
| `ThClineDepth` | Metres |
| `CodendMesh` | Millimetres |
| `SecchiDepth` | Metres |
| `Turbidity` | NTU |
| `TidePhase` | Minutes |
| `TideSpeed` | Metres/second |
| `PelSampType` | vocab.ices.dk ref=1391 |
| `MinTrawlDepth` | Metres |
| `MaxTrawlDepth` | Metres |
| `DateofCalculation` | YYYYMMDD |

## Exchange Data field units — HL record (additional fields)

| Field (old-style) | Unit / vocab |
|-------------------|-------------|
| `SpecCodeType` | vocab.ices.dk ref=96 |
| `SpecCode` | datras.ices.dk species query |
| `SpecVal` | vocab.ices.dk ref=5 |
| `Sex` | vocab.ices.dk ref=17 |
| `TotalNo` | Number of fish |
| `CatIdentifier` | vocab.ices.dk ref=16 |
| `NoMeas` | Number of fish |
| `SubFactor` | Factor of subsampling |
| `SubWgt` | **Grams** |
| `CatCatchWgt` | **Grams** |
| `LngtCode` | vocab.ices.dk ref=18 |
| `LngtClass` | **mm** for mm and ½-cm classes; **cm** for cm classes |
| `HLNoAtLngt` | Number of fish |
| `DevStage` | vocab.ices.dk ref=1397 |
| `LenMeasType` | vocab.ices.dk ref=1392 |
| `ValidAphiaID` | Valid WoRMS AphiaID |
| `AreaType` | vocab.ices.dk ref=10 |
| `AreaCode` | See AreaType vocab |

## Exchange Data field units — CA record (additional fields)

| Field (old-style) | Unit / vocab |
|-------------------|-------------|
| `Maturity` | vocab.ices.dk ref=128 |
| `PlusGr` | vocab.ices.dk ref=14 (`"+"` = plus-group age) |
| `AgeRings` | Years |
| `CANoAtLngt` | Number of fish |
| `IndWgt` | **Grams** |
| `MaturityScale` | vocab.ices.dk CodeID=201781 |
| `FishID` | Sample ID (national lab) |
| `GenSamp` | vocab.ices.dk ref=1390 |
| `StomSamp` | vocab.ices.dk ref=1390 |
| `AgeSource` | vocab.ices.dk ref=1393 |
| `AgePrepMet` | vocab.ices.dk ref=1394 |
| `OtGrading` | vocab.ices.dk ref=1395 |
| `ParSamp` | vocab.ices.dk ref=1390 |

---

## Litter Exchange Data (LT record)

Haul-level join: Survey · Year · Quarter · Country · Ship · Gear · StNo · HaulNo.

| Field | Unit / vocab |
|-------|-------------|
| `LTREF` | Litter reference list ref=1381 |
| `PARAM` | Litter parameter (see LTREF vocab) |
| `LTSZC` | Litter size category ref=1380 |
| `UnitWgt` | Units for LT_Weight ref=1421 |
| `LT_Weight` | Litter weight (unit per prev. field) |
| `UnitItem` | Units for LT_Items ref=1422 |
| `LT_Items` | Number of litter items |
| `LTSRC` | Litter source ref=1382 |
| `TYPPL` | Type of polymer ref=1385 |
| `LTPRP` | Additional litter properties ref=1403 |
| `Reserved1`, `Reserved2` | System reserved, always -9 |

---

## CPUE per length per haul (CPUEL)

Standard and other species. CPUE = numbers per **1 hour of hauling**.

| Field | Unit |
|-------|------|
| `LngtClass` | Millimetres |
| `CPUE_number_per_hour` | Catch in numbers per hour |
| `HaulDur` | Minutes |
| `Depth` | Metres |
| `ShootLat/Long` | Degree.Decimal Degree |
| `DateTime` | dd/mm/yyyy hh:mm:ss (beware Excel reformatting) |
| `DateofCalculation` | YYYYMMDD |

---

## CPUE per age per haul (CPUEA)

Standard species only. Age columns `Age_0` … `Age_10` = catch in numbers per hour.
Plus-group age determined per species per survey by expert group (e.g. NS-IBTS = Age_6).

---

## Indices (IDX)

Standard species only. Age columns `Age_0` … `Age_15` = **number per hour per area** for standard gear.

| Field | Unit / vocab |
|-------|-------------|
| `IndexArea` | vocab.ices.dk ref=162 |
| `PlusGr` | vocab.ices.dk ref=14 (renamed `PlusGrAge` in obus to avoid clash with CA `PlusGr`) |
| `Sex` | vocab.ices.dk ref=17 |

CPUE zeroes in CPUE products: species absent from haul but reported by ≥ 1 country in the same
survey/year/quarter → zero-records added automatically for all hauls in that combination.

---

## NS-IBTS Indices — Calculation Procedure

*Source: ICES Data Centre DATRAS Procedure Document v1.2 (2022), "NS-IBTS indices calculation procedure"*

Indices are calculated per **index area** (species-specific). For most species the index is the mean
numbers/hour at age per statistical rectangle, averaged over rectangles in the index area. For
**herring, sprat, and saithe** the rectangle mean is **weighted** by the proportion of the rectangle's
area with water depth 10–200 m (NS) or 10–250 m (Skagerrak/Kattegat, RFA 8–9).

### General rules

- Only valid hauls are used.
- When ALK observations are sparse, data are borrowed from neighbouring roundfish areas (RFA); see ALK supplementation below.
- For **herring and sprat**, only **day hauls** are used (based on `DayNight` code).
- **Herring in RFA 8 and 9, Q1**: age ≥ 2 CPUE is set to zero (assumed spring spawners).
- Two extra indices exist for Downs herring juveniles (length ≤ 12.5 cm): `NS_Her1to9` (standard) and `NS_Her1to7` (CPUE in RFA 8–9 set to zero).

### Calculation steps

**Step I — ALK by RFA** (from CA records)

1. Extract raw age-at-length data for species + index area.
2. Build ALK by roundfish area (RFA), in 1 cm classes (0.5 cm for herring/sprat).
3. Fill empty RFAs from neighbouring areas (see ALK supplementation).
4. Aggregate to plus group: ages ≥ plus group age are summed into the plus group cell.

**Step II — CPUE per haul per length class** (from HL records)

1. Apply species recording code rules; select only valid hauls.
2. Apply day/night filter (herring/sprat: day hauls only).
3. Count valid hauls per statistical rectangle.
4. Add zero rows for absent length classes.
5. Raise to total numbers: `NumberAtLength × SubsamplingFactor`.
6. Sum over `SpeciesCategory` and `SpeciesSex`.
7. If `DataType ≠ C`: `NoAtHaul = count × (60 / HaulDuration)` → convert to per-hour.
8. Sum CPUE per haul per length per statistical rectangle (per RFA).

**Step III — Fill ALK for all length classes (ALKRFA)**

- Length class < minimum ALK length → age = 1 (Q1) or age = 0 (Q2–4).
- Minimum < length class < maximum: borrow from nearest ALK entry (average if equidistant).
- Length class > maximum ALK length → assign to plus group.
- Merge filled ALK with CPUE by year, quarter, length class.

**Step IV — CPUE at age by length class (CPUEALK)**

1. Merge ALKRFA and CPUE by year, quarter, RFA, length class.
2. Sum numbers at length per age per statistical rectangle.
3. Sum valid hauls per statistical rectangle.
4. Mean CPUE at age per statistical rectangle = (2) / (3).

**Step IVa — Weighted CPUE** (herring, sprat, saithe only)

As step IV but hauls weighted by depth-stratum area weight of the rectangle (Annex 3 weights).
Weighted mean CPUE = Σ(numbers at age) / Σ(weights of valid hauls).

**Step V — Index**

1. Sum CPUE per age over all fished rectangles in the index area.
2. Count number of fished rectangles in the index area.
3. Index = (1) / (2) → mean numbers/hour/rectangle for the index area.

### Index area and species parameters (Annex 1)

Parameters governing ALK filling, length filtering, and weighting, by index area and quarter.

| Index area | Q | Max age | Min length (mm) | Max length (mm) | ALK level | CPUE level | Length class | Area weighted | Day only |
|---|---|---|---|---|---|---|---|---|---|
| NS_Cod | 1 | 6 | 150 | 900 | RFarea | Stat rect | 1 cm | no | no |
| NS_Cod | 2 | 6 | 70 | 1100 | RFarea | Stat rect | 1 cm | no | no |
| NS_Cod | 3 | 6 | 70 | 1100 | RFarea | Stat rect | 1 cm | no | no |
| NS_Cod | 4 | 6 | 70 | 1100 | RFarea | Stat rect | 1 cm | no | no |
| NS_CodCat | 1 | 6 | 150 | 900 | RFarea | Stat rect | 1 cm | no | no |
| NS_CodCat | 3 | 6 | 70 | 1100 | RFarea | Stat rect | 1 cm | no | no |
| NS_Haddock | 1 | 6 | 150 | 600 | RFarea | Stat rect | 1 cm | no | no |
| NS_Haddock | 2 | 6 | 100 | 700 | RFarea | Stat rect | 1 cm | no | no |
| NS_Haddock | 3 | 6 | 100 | 700 | RFarea | Stat rect | 1 cm | no | no |
| NS_Haddock | 4 | 6 | 100 | 700 | RFarea | Stat rect | 1 cm | no | no |
| NS_Herring | 1 | 5 | 150 | 320 | RFarea | Stat rect | 0.5 cm | yes | yes |
| NS_Herring | 2 | 5 | 60 | 340 | RFarea | Stat rect | 0.5 cm | yes | yes |
| NS_Herring | 3 | 5 | 60 | 340 | RFarea | Stat rect | 0.5 cm | yes | yes |
| NS_Herring | 4 | 5 | 60 | 340 | RFarea | Stat rect | 0.5 cm | yes | yes |
| NS_Her1to9 | 1 | 5 | 60 | 125 | RFarea | Stat rect | 0.5 cm | yes | yes |
| NS_Her1to7 | 1 | 5 | 60 | 125 | RFarea | Stat rect | 0.5 cm | yes | yes |
| NS_Mackerel | 1–4 | 6 | 50–200 | 450 | RFarea | Stat rect | 1 cm | no | no |
| NS_NorwayPout | 1–4 | 6 | 50–100 | 250 | RFarea | Stat rect | 1 cm | no | no |
| NS_Plaice IIIa | 1,3 | 10 | 40 | 600 | RFarea | Stat rect | 1 cm | no | no |
| NS_Saithe | 1–4 | 6 | 70–250 | 900–1200 | RFarea | Stat rect | 1 cm | yes | no |
| NS_Sprat IIIa | 1,3 | 6 | 70 | 160 | RFarea | Stat rect | 0.5 cm | yes | yes |
| NS_Sprat IV | 1–4 | 6 | 45 | 160 | RFarea | Stat rect | 0.5 cm | yes | yes |
| NS_Whiting | 1–4 | 6 | 80–150 | 450–800 | RFarea | Stat rect | 1 cm | no | no |

### ALK supplementation (Annex 2)

From 2021, automated supplementation follows:
[ICES ALK automated substitution procedure](https://www.ices.dk/data/Documents/DATRAS/ALK_automated_substitution.pdf) — code at
[github.com/ices-tools-prod/DATRAS/tree/master/ALK_substitution](https://github.com/ices-tools-prod/DATRAS/tree/master/ALK_substitution).

Key change from the old manual procedure: borrowing is done **per age class**, not per whole area.
Rule: for each species, area, and age class, borrow from neighbouring RFAs in order until ≥ 25 otoliths. RFA 10 was added in 2009.

| RFA | Borrows from (in order) |
|-----|------------------------|
| 1 | 2, 3 |
| 2 | 1, 3, 4, 6, 7 |
| 3 | 1, 2, 4 |
| 4 | 2, 3, 5, 6 |
| 5 | 4, 6, 2 |
| 6 | 2, 4, 5, 7 |
| 7 | 2, 6 |
| 8 | 9, 7, 6 |
| 9 | 8, 7, 2 |
| 10 | 5, 6, 4 |

For **saithe and mackerel**, age data are merged across quarters and applied to all RFAs (too few otoliths for per-RFA ALK).

### Statistical rectangle depth-area weights (Annex 3)

Weights = proportion of rectangle area with water depth 10–200 m (NS) or 10–250 m (Skagerrak/Kattegat).
Used for herring, sprat, and saithe indices only. A weight of `1` means the full rectangle is within the depth range; `0` means none of it is.

<details>
<summary>Full weight table (~200 rectangles — click to expand)</summary>

| StatRec | Weight | StatRec | Weight | StatRec | Weight | StatRec | Weight |
|---------|--------|---------|--------|---------|--------|---------|--------|
| 31F1 | 0.60 | 38F0 | 1.00 | 41F6 | 1.00 | 44F1 | 1.00 |
| 31F2 | 0.80 | 38F1 | 1.00 | 41F7 | 1.00 | 44F2 | 1.00 |
| 31F3 | 0.05 | 38F2 | 1.00 | 41F8 | 0.10 | 44F3 | 1.00 |
| 32F1 | 0.80 | 38F3 | 1.00 | 41G0 | 0.20 | 44F4 | 1.00 |
| 32F2 | 1.00 | 38F4 | 1.00 | 41G1 | 0.97 | 44F5 | 0.90 |
| 32F3 | 0.80 | 38F5 | 1.00 | 41G2 | 0.53 | 44F8 | 0.25 |
| 32F4 | 0.01 | 38F6 | 1.00 | 42E7 | 0.40 | 44F9 | 0.80 |
| 33F1 | 0.30 | 38F7 | 1.00 | 42E8 | 1.00 | 44G0 | 0.94 |
| 33F2 | 1.00 | 38F8 | 0.30 | 42E9 | 1.00 | 44G1 | 0.60 |
| 33F3 | 1.00 | 39E8 | 0.50 | 42F0 | 1.00 | 45E6 | 0.40 |
| 33F4 | 0.40 | 39E9 | 1.00 | 42F1 | 1.00 | 45E7 | 1.00 |
| 34F1 | 0.40 | 39F0 | 1.00 | 42F2 | 1.00 | 45E8 | 1.00 |
| 34F2 | 1.00 | 39F1 | 1.00 | 42F3 | 1.00 | 45E9 | 1.00 |
| 34F3 | 1.00 | 39F2 | 1.00 | 42F4 | 1.00 | 45F0 | 1.00 |
| 34F4 | 0.60 | 39F3 | 1.00 | 42F5 | 1.00 | 45F1 | 1.00 |
| 35F0 | 0.80 | 39F4 | 1.00 | 42F6 | 1.00 | 45F2 | 1.00 |
| 35F1 | 1.00 | 39F5 | 1.00 | 42F7 | 1.00 | 45F3 | 1.00 |
| 35F2 | 1.00 | 39F6 | 1.00 | 42F8 | 0.20 | 45F4 | 0.60 |
| 35F3 | 1.00 | 39F7 | 1.00 | 42G0 | 0.32 | 45F8 | 0.30 |
| 35F4 | 0.90 | 39F8 | 0.40 | 42G1 | 0.89 | 45F9 | 0.02 |
| 35F5 | 0.10 | 40E7 | 0.04 | 42G2 | 0.64 | 45G0 | 0.24 |
| 36F0 | 0.90 | 40E8 | 0.80 | 43E7 | 0.03 | 45G1 | 0.55 |
| 36F1 | 1.00 | 40E9 | 1.00 | 43E8 | 0.90 | 46E6 | 0.40 |
| 36F2 | 1.00 | 40F0 | 1.00 | 43E9 | 1.00 | 46E7 | 0.90 |
| 36F3 | 1.00 | 40F1 | 1.00 | 43F0 | 1.00 | 46E8 | 1.00 |
| 36F4 | 1.00 | 40F2 | 1.00 | 43F1 | 1.00 | 46E9 | 1.00 |
| 36F5 | 1.00 | 40F3 | 1.00 | 43F2 | 1.00 | 46F0 | 1.00 |
| 36F6 | 0.90 | 40F4 | 1.00 | 43F3 | 1.00 | 46F1 | 1.00 |
| 36F7 | 0.40 | 40F5 | 1.00 | 43F4 | 1.00 | 46F2 | 1.00 |
| 36F8 | 0.50 | 40F6 | 1.00 | 43F5 | 1.00 | 46F3 | 0.80 |
| 37E9 | 0.20 | 40F7 | 1.00 | 43F6 | 1.00 | 46F9 | 0.30 |
| 37F0 | 1.00 | 40F8 | 0.10 | 43F7 | 1.00 | 46G0 | 0.52 |
| 37F1 | 1.00 | 41E6 | 0.03 | 43F8 | 0.94 | 46G1 | 0.20 |
| 37F2 | 1.00 | 41E7 | 0.80 | 43F9 | 0.41 | 47E6 | 0.80 |
| 37F3 | 1.00 | 41E8 | 1.00 | 43G0 | 0.21 | 47E7 | 0.60 |
| 37F4 | 1.00 | 41E9 | 1.00 | 43G1 | 0.70 | 47E8 | 1.00 |
| 37F5 | 1.00 | 41F0 | 1.00 | 43G2 | 0.30 | 47E9 | 1.00 |
| 37F6 | 1.00 | 41F1 | 1.00 | 44E6 | 0.50 | 47F0 | 1.00 |
| 37F7 | 1.00 | 41F2 | 1.00 | 44E7 | 0.50 | 47F1 | 1.00 |
| 37F8 | 0.80 | 41F3 | 1.00 | 44E8 | 0.90 | 47F2 | 1.00 |
| 38E8 | 0.20 | 41F4 | 1.00 | 44E9 | 1.00 | 47F3 | 0.60 |
| 38E9 | 0.90 | 41F5 | 1.00 | 44F0 | 1.00 | 47F9 | 0.01 |
| | | | | | | 47G0 | 0.30 |
| | | | | | | 47G1 | 0.02 |
| 48E6 | 1.00 | 49E9 | 1.00 | 51E6 | 0.00 | 52E6 | 0.00 |
| 48E7 | 1.00 | 49F0 | 1.00 | 51E7 | 0.00 | 52E7 | 0.00 |
| 48E8 | 0.90 | 49F1 | 1.00 | 51E8 | 0.50 | 52E8 | 0.00 |
| 48E9 | 1.00 | 49F2 | 1.00 | 51E9 | 1.00 | 52E9 | 0.10 |
| 48F0 | 1.00 | 49F3 | 0.50 | 51F0 | 1.00 | 52F0 | 0.20 |
| 48F1 | 1.00 | 50E6 | 0.10 | 51F1 | 1.00 | 52F1 | 0.50 |
| 48F2 | 1.00 | 50E7 | 0.60 | 51F2 | 0.50 | 52F2 | 0.10 |
| 48F3 | 0.50 | 50E8 | 0.70 | 51F3 | 0.00 | 52F3 | 0.00 |
| 48G0 | 0.02 | 50E9 | 0.90 | | | | |
| 49E6 | 0.80 | 50F0 | 1.00 | | | | |
| 49E7 | 1.00 | 50F1 | 1.00 | | | | |
| 49E8 | 0.40 | 50F2 | 1.00 | | | | |
| | | 50F3 | 0.20 | | | | |

</details>

### Aggregation notation (Annex 5)

| Symbol | Meaning |
|--------|---------|
| `A` | Index area |
| `r` | Statistical rectangle |
| `i` | Length class |
| `j` | Age group |
| `H(r)` | Valid hauls in rectangle r |
| `C(r)` | Numbers/hour/haul in rectangle r |
| `C(r,i)` | Numbers/hour/haul in length class i, rectangle r |
| `C(r,j)` | Numbers/hour/haul in age group j, rectangle r |
| `f(a,i,j)` | ALK proportion: fraction of length class i in age j for area a |
| `R(a)` | Number of rectangles sampled in area a |
| `Cr(a)` | Mean numbers/hour/haul in area a = C(a) / R(a) |
| `Cr(a,j)` | Mean numbers/hour/haul at age j in area a = C(a,j) / R(a) |

---

## BITS Indices — Calculation Procedure

*Source: ICES Data Centre DATRAS Procedure Document v1.1 (2013), "BITS indices calculation procedure"*

BITS (Baltic International Trawl Survey) indices differ from NS-IBTS in three key ways:
- Spatial stratification is by **ICES Subdivision (SD)** × **depth layer**, not by statistical rectangle.
- Haul validity includes both `"V"` and `"N"` codes (NS-IBTS uses `"V"` only).
- **Cod CPUE is gear-standardised** to the large TVL trawl using conversion factors before aggregation (see `BITS_ConversionFactor_to_TVL.csv`).

### Depth layers used per SD

| SD | 0–19 m | 20–39 m | 40–59 m | 60–79 m | 80–99 m | 100–120 m | 120–200 m |
|----|--------|---------|---------|---------|---------|-----------|-----------|
| 22 | ✓ | ✓ | ✓ | ✓ | | | |
| 23 | ✓ | ✓ | ✓ | ✓ | | | |
| 24 | ✓ | ✓ | ✓ | ✓ | | | |
| 25 | | ✓ | ✓ | ✓ | ✓ | ✓ | |
| 26 | | ✓ | ✓ | ✓ | ✓ | ✓ | |
| 27 | | ✓ | ✓ | ✓ | ✓ | ✓ | |
| 28 | | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

Depth layer SubArea codes: 8 = 0–19 m, 9 = 20–39 m, 10 = 40–59 m, 11 = 60–79 m, 12 = 80–99 m, 13 = 100–120 m, 14 = 120–200 m.

### Calculation steps (6-step)

**Step I — CPUE per haul per length class** (HL records)

1. Apply species recording code rules; select valid (`"V"`, `"N"`) hauls and `SpecVal = 1 or NULL`.
2. Count valid hauls per SubArea (depth layer within SD).
3. Add zero rows for absent length classes.
4. Raise sub-sample to total: `NumberAtLength × SubsamplingFactor`.
5. Sum over sex and category; convert to per-hour: `count × (60 / HaulDuration)` (if DataType ≠ C).
6. **Multiply by gear conversion factor** (cod only) to standardise to TVL equivalent.

**Step II — ALK by SD** (CA records)

1. Compute age-length key per ICES Subdivision.
2. Apply plus-group rule (ages ≥ plus group age summed into plus group cell).
3. If ALK absent for an SD, borrow from neighbouring SDs (analogue of RFA supplementation).

**Step III — Fill ALK for all length classes** (same logic as NS-IBTS Step III)

**Step IV — CPUE at age per depth stratum**

Apply ALK to CPUE per haul × length; aggregate to CPUE at age per depth stratum (SubArea).

**Step V — Weight depth strata by km²**

Weight each depth stratum's CPUE by its area in km² (see `BITS_AreaWeights.csv`).
Area-weighted mean CPUE per SD = `Σ(CPUE × km²) / Σ(km²)`.

**Step VI — Index per index area**

Sum over depth strata within each SD; then aggregate SDs into the index area mean.

### BITS area weights

`BITS_AreaWeights.csv` gives the km² for each combination of Survey, ICES Subdivision (Area), and depth-layer SubArea (8–14). Used for the Step V weighted mean. Source: Oeberst (2013), WD2, WKBALT.

### BITS gear conversion factors (cod only)

`BITS_ConversionFactor_to_TVL.csv` converts national and small-trawl CPUE to TVL-equivalent. Factors vary by gear code (CHP, DT, FOT, GOV, GRT, H20, HAK, LBT, P20, SON, TVL) and by length class (10 mm bins). Columns: `ConFactor0`, `ConFactor1`, `ConFactor2` corresponding to the three conversion factor variants (see Oeberst 2013 for variable definitions). TVL gear has all factors = 1 (reference trawl).

---

## SMALK

Sex/Maturity/Age/Length/Key product. `CANoAtLngt` = catch in numbers per hour; `IndWgt` = Grams.
Non-BTS surveys: area-level aggregation. BTS/DYFS: ship-level, wide age columns.

---

## ALK (Age-Length Key)

Standard species only. Age columns `Age_0` … `Age_10` = **number of fish** (not per hour).

---

## CPUE per length per hour and swept area

BTS, BTS-VIIa, DYFS, SNS surveys only.

*Source: ICES Data Centre DATRAS Procedure Document v1.4 (2022), "Swept area calculation algorithms"*

| Field | Unit |
|-------|------|
| `CPUE_number_per_hour` | Catch in numbers per hour of hauling |
| `SweptArea_km2` | Square kilometre |
| `CPUE_number_per_km2` | Catch in numbers per km² |
| `BeamWidth` | Metres |
| `DistanceDerived` | Metres |

### Distance calculation (all surveys)

Preferred: `Distance (m) = (HaulDur / 60) × 1852 × GroundSpeed`

Fallback when `GroundSpeed` is missing — great-circle distance from shoot/haul positions:

```
Distance (m) = 1.852 × 360 × (60 / 2π) ×
  acos( cos(ShootLat) × cos(HaulLat) × cos(HaulLon − ShootLon)
      + sin(ShootLat) × sin(HaulLat) )
```

### Beam trawl swept area (BTS, DYFS, SNS)

```
# Single beam (GearEx = "SB")
SweptArea_km2 = BeamWidth × Distance / 1e6

# Double beam (GearEx = "DB") — catches of two nets combined
SweptArea_km2 = 2 × BeamWidth × Distance / 1e6
```

`BeamWidth` is extracted from the `Gear` field (3rd character in metres).  
When `Distance` is missing: `Distance = 1853 × HaulDur / 60`.  
Haul duration must be 5–40 minutes; `GroundSpeed` varies by survey and vessel.

### Otter trawl swept area (NS-IBTS, NEA-IBTS)

`SweptArea_km2` = `WingSpread × Distance / 1e6` (non-herding species) or
`DoorSpread × Distance / 1e6` (herding species).

When `DoorSpread` or `WingSpread` is missing, per-country regression algorithms are applied
(depth-based or depth + time-period based). These are documented per country and survey year
in Table 1 of `Swept_area_km2_algorithms_pdf.pdf`. Notable exceptions:
- NL does not measure wing spread; Scotland's formula is applied instead.
- GER Q1 2019–2020: depth-based regression (survey on *Dana* with German GOV gear).
- GER Q3 2021: Danish regression (survey on *Dana* with Danish trawl).

---

## Confidence Limits and Bootstrap Variance

*Source: ICES 2007 report to EU, "Confidence Limits Estimation of Abundance Indices from Bottom Trawl Survey Data" (`Final_report_to_EU_Bootstrap_calculation.pdf`); ICES DATRAS Workshop 2006 (`Workshop_report_on_variance_estimation.pdf`)*

DATRAS implements a **bootstrap** approach to estimate uncertainty on abundance indices. Standard analytical variance estimators are not used because the sampling design (stratified, with ALK applied post-hoc) does not admit a simple closed-form variance.

### Bootstrap algorithm

1. **Length distribution bootstrapping** — resample hauls within each stratum (statistical rectangle for NS-IBTS; depth layer × SD for BITS) with replacement to obtain bootstrap replicates of the mean CPUE per length class.
2. **ALK bootstrapping** — resample otoliths within each age/length cell to produce bootstrap replicates of the age-length key.
3. Combine bootstrapped length distribution with bootstrapped ALK → bootstrap replicate of index.
4. Repeat a large number of times (typically ≥ 1000); compute percentile-based confidence intervals.

### Haul-level design structure

| Survey | Stratum for bootstrap |
|--------|-----------------------|
| NS-IBTS | Statistical rectangle |
| BITS | Depth layer × SD |
| BTS | Statistical rectangle |
| EVHOE | ICES division |
| SWC-IBTS | Demersal sampling area |

### Notes

- The bootstrap is implemented in DATRAS for the standard derived products (IDX). Confidence limits are not currently exposed in the raw exchange data.
- Number of bootstraps in DATRAS: ≥ 1000 replicates recommended; DATRAS uses 999.
- CPUE from `dr_cpue_by_length` / `dr_cpue_by_haul` does not incorporate this bootstrap — it reflects only the input haul-level CPUE, not index-level uncertainty.

---

## Species codes

| SpecCodeType | Scheme | Era |
|-------------|--------|-----|
| `W` | WoRMS AphiaID (current standard) | Post ~2010 |
| `T` | ITIS TSN | Historical |
| `N` | NODC code | Historical |

All codes mapped to `ValidAphiaID` (valid WoRMS) in HL/CA records for cross-era analysis.

---

## SpecVal (species validity)

Only `SpecVal = 1` records are used for DATRAS derived data product calculation.
Other SpecVal codes indicate partial sampling, calibration hauls, etc. — data may still be useful for
biological studies but are not included in CPUE/index products.

---

## Day / Night definition

Day = 15 min before sunrise to 15 min after sunset.
Calculation follows NOAA solar calculator: http://www.esrl.noaa.gov/gmd/grad/solcalc/

---

## Age plus groups

The maximum age column in age-based products varies by survey and expert group decision:

| Survey | Plus group |
|--------|-----------|
| NS-IBTS | Age_6 (fish aged 6+ all recorded as age 6) |
| Others | Up to Age_10 or Age_15 (IDX) |

---

## Coordinate system

Shooting and haul positions: **Degree.Decimal Degree** (decimal degrees, not decimal minutes).
Statistical rectangles (`StatRec`) based on shooting position.

---

## Litter Assessment Output

OSPAR-compliant product. Adds `OSPARArea`, `MSFDArea`, `EEZ`, `NMArea` to standard haul fields.
`BottomDepth` is based on bathymetric measurements at shooting position.
