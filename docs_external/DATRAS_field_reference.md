# DATRAS Field Reference

Synthesised from ICES DATRAS specification documents:
- `3.1.DATRAS_dataproducts_units.pdf` — Units in DATRAS Products, v3.1 (2021)
- `DATRAS_FAQs.pdf` — DATRAS FAQs, v3.0 (2014)

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

### obus-derived fields

These fields do not exist in the raw exchange data; obus computes them from
the inputs listed. All require the HH and HL tables to be joined on `.id` first
when the input comes from HH.

| Derived field | Function | Inputs (table) | Formula / rule |
|---------------|----------|---------------|----------------|
| `.id` | `dr_add_id()` | Survey, Year, Quarter, Country, Ship/Platform, Gear, StNo/StationName, HaulNo/HaulNumber (HH/HL/CA) | Paste 8 fields with `":"` separator |
| `date` | `dr_add_date()` | Year, Month, Day (HH) | `make_date(Year, Month, Day)` |
| `time` | `dr_add_starttime()` | Year, Month, Day, TimeShot (HH) | Parse `TimeShot` as hhmm, combine with date |
| `length_cm` | `dr_add_length_cm()` | LngtClass, LngtCode (HL) | LngtCode `"."`/`"0"`: `LngtClass / 10`. Others: `LngtClass` |
| `length_mm` | `dr_add_length_mm()` | LngtClass, LngtCode (HL) | LngtCode `"."`/`"0"`: `LngtClass`. Others: `LngtClass * 10` |
| `n_haul` | `dr_add_n_and_cpue()` | HLNoAtLngt, SubFactor (HL); DataType, HaulDur (HH) | R/S/P: `HLNoAtLngt * SubFactor`. C: `HLNoAtLngt * SubFactor * HaulDur / 60` (HLNoAtLngt is per-hour CPUE for DataType C; back-convert to per-haul count) |
| `n_hour` | `dr_add_n_and_cpue()` | HLNoAtLngt, SubFactor (HL); DataType, HaulDur (HH) | R/S/P: `HLNoAtLngt * SubFactor / HaulDur * 60`. C: `HLNoAtLngt * SubFactor` (derived as `n_haul / HaulDur * 60`) |

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

## SMALK

Sex/Maturity/Age/Length/Key product. `CANoAtLngt` = catch in numbers per hour; `IndWgt` = Grams.
Non-BTS surveys: area-level aggregation. BTS/DYFS: ship-level, wide age columns.

---

## ALK (Age-Length Key)

Standard species only. Age columns `Age_0` … `Age_10` = **number of fish** (not per hour).

---

## CPUE per length per hour and swept area

BTS, BTS-VIIa, DYFS, SNS surveys only.

| Field | Unit |
|-------|------|
| `CPUE_number_per_hour` | Catch in numbers per hour of hauling |
| `SweptArea_km2` | Square kilometre |
| `CPUE_number_per_km2` | Catch in numbers per km² |
| `BeamWidth` | Metres |
| `DistanceDerived` | Metres |

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
