# Renault Logan 2015 (Logan II, X52/L52) 1.6 8v K7M + JH3: ECU modules and diagnostic protocols

Research context: notes for an OBD app developer. Primary hard evidence comes from the source code of two open-source Renault diagnostic tools that were cloned and inspected locally: DDT4ALL (github.com/cedricp/ddt4all, current master) and pyren (github mirror github.com/emtee40/pyren-OBD2). Many other web pages (Renault Egypt brochure, Russian wiring-diagram sites, obdii365 blog) could not be fetched from this research environment (network allowlist), so several hardware-supplier facts rest only on search-result snippets and are flagged.

Note on platform codes: in DDT4ALL/pyren, Renault project codes are **X90** = Logan I / Sandero I (2004-2012) and **X52** = Logan II / Sandero II (2012-2020). "L90"/"L52" are the Renault-branded (non-Dacia, e.g. Russia/Egypt/Middle East) variants of the same platforms; diagnostic addressing is shared. Whether the Egyptian "2015 Logan" is a Logan II (X52-family, "completely restyled in 2014") or a late Logan I must be confirmed on the car (VIN position 4-6 / CLIP vehicle selection).

## Q1. Which engine ECU is fitted to the 2013-2016 Logan K7M, and which variants for Egypt?

### Takeaway
The K7M 1.6 8v in Logan/Sandero uses a Continental (ex-Siemens VDO) EMS31xx family ECU; the two names repeatedly associated with Logan/Sandero K7M are **EMS3120** and **EMS3132** (EMS3125 is for H4M/K4M on newer Lada/Duster/Kaptur). No source found settles which one an Egyptian 2015 car has, or its Euro level; this must be read from the ECU label/2180 identification on a real car.

### Cited Findings
- A ECU-tool catalogue lists **EMS3120** for Renault Logan and Sandero, and **EMS3132** for Renault Logan/Sandero/Symbol plus Nissan Almera and Lada Largus; **EMS3125** is listed for Lada X-Ray and Renault Duster/Kaptur — [ecutools.eu](https://ecutools.eu/chip-tuning/chiptuningpro) (search snippet only)
- A repair article describes a **Continental EMS3132 ECM** in a Renault Logan with a no-start fault (burned resistors) and mentions immobiliser handling via tools such as OBDSTAR DC706 — [obdii365 blog](https://blog.obdii365.com/2024/08/14/how-to-repair-renault-logan-ems3132-ecm/) (search snippet only; page not reachable)
- Lada Largus with K4M is documented with **EMS 3120 (PCM)**; Lada X-Ray H4M with **EMS 3125** — [scandoc Largus K4M EMS3120](https://d1.scandoc.online/last/0/77/7/4); [scandoc X-Ray H4M EMS3125](https://scandoc.online/last/0/77/13/6)
- K7M is the 1.6 8-valve, ~62 kW (84 hp) engine; the ECU drives injectors, relays and the cooling fan (Largus documentation, same engine family) — [autoruk.ru Largus EMS](https://autoruk.ru/en/lada-largus/diagnostics-of-the-engine-management-system-of-the-lada-largus)
- Renault Egypt's 2014 Logan brochure lists "Gasoline 1.6 L 8V 90 hp" and "1.6 L 16V 110 hp" versions; it does not name the engine code — [Renault Egypt Logan 2014 brochure](https://www.renault.com.eg/fbapps/renaultegypt/CountriesData/Egypt/images/Brochures/Logan-2014.pdf) (search snippet); Renault Egypt states Logan was launched in 2008 and "completely restyled in 2014" — [renault.com.eg Logan](https://renault.com.eg/cars/logan/overview.html) (snippet)
- In both DDT4ALL and pyren the engine ECU is Renault diag address **7A**, CAN request **7E0**, response **7E8** for project X52 (and X90) — DDT4ALL `src/ddt4all/resources/projects.json` (projects "[X52] - Dacia Logan", "[X90] - Dacia Logan / Sandero"), [github.com/cedricp/ddt4all](https://github.com/cedricp/ddt4all); pyren `mod_elm.py` dnat/snat, [github.com/emtee40/pyren-OBD2](https://github.com/emtee40/pyren-OBD2)

### Inferences
- For a 2015 Logan II K7M, the engine ECU is most likely a Continental EMS3120 or EMS3132 (Renault part numbers typically 2371xxxxxR / 8201xxxxxx). Both are DiagOnCan (KWP2000-over-CAN, Renault "10C0"/"2180" style) on the X52 platform; the app does not need to distinguish them for transport, only for the data dictionary (local IDs differ by software/Vdiag).
- 90 hp vs 84/87 hp output suggests a K7M variant (e.g. K7M 800/K7M 710/K7M 512) that differs by market and emission calibration; a Euro 2/no-downstream-O2 calibration for some export markets is plausible but unverified for Egypt. Detect it at runtime: Mode 01 PID 13/1D (O2 sensors present) and PID 1C (OBD standard) tell the app whether a rear O2 sensor is configured.
- Logan I (X90) K7M cars (2004-2012) commonly used Siemens/Sagem-era ECUs (e.g. Sagem S3000 / Siemens EMS3110-type) with K-line diagnostics in early years; treat this as unverified.

### Gaps
- No authoritative source mapping Egyptian 2015 Logan K7M to EMS3120 vs EMS3132, nor its Euro level / rear O2 presence. Must be read from the car (2180 ident response gives supplier code, software and Vdiag; or ECU label).
- Sagem S3000 / Delphi use on Logan K7M: no source found in this session.

## Q2. Which ABS, airbag, UCH, cluster, EPS, immobiliser, radio and AC units are fitted?

### Takeaway
Logan II uses a Bosch ABS (Bosch 8.x/9.0 family, Renault P/N 4766xxxxxR, Bosch 0265 23x/0265 8xx), a Continental airbag ECU (Renault 9851xxxxxR / Continental A2C...), and a UCH body computer with the immobiliser function; power steering on Logan II K7M is hydraulic (no EPS ECU expected). Exact families must be confirmed via 2180 identification on the car.

### Cited Findings
- ABS listings for Logan II / Logan MCV II: 476601842R, 476601283R; a Logan/Sandero ABS module 476604621R is cross-referenced to Bosch 0265232718 / 0265801018 — [techniczentrum ABS module](https://techniczentrum.com/fr/pompes-abs/8661-13402-module-abs-dacia-logan-sandero-476604621r-0265232718-0265801018-90bo2aay1.html); [ebay listing](https://www.ebay.de/itm/257050909618) (search snippets)
- A Renault technical document titled "ABS BOSCH 8.1" (Vdiag 04, programming procedure) exists for Renault/Dacia — [Scribd MR453X7938C000](https://www.scribd.com/document/498593009/MR453X7938C000) (snippet)
- Lada (same Renault-Nissan B0 family) with **ABS 9.0** communicates with engine ECU, cluster and diagnostic socket over CAN — [aubito / drive2 summary](https://aubito.ru/en/renault-logan/anti-lock-braking-system-of-the-renault-logan-car) (snippet)
- Second-generation Sandero airbag ECU is a **Continental** unit (shared with Duster and Clio IV), mounted under the centre console; listings show 985102122R / A2C85839702 (Continental) for Duster/Sandero, and older Sandero modules 285580347R, 8201002829, 8201163278 — [ecutesting.com Dacia Sandero airbag](https://www.ecutesting.com/common-faults/dacia/dacia-sandero-airbag-ecu-repair/); [techniczentrum 285580347R / A2C80612911](https://techniczentrum.com/en/airbag-module/311-285580347R--A-A2C80612911.html)
- Steering-wheel airbag 985701142R (Logan II, Sandero, Lodgy, Dokker) is subject to a recall for 2018 production — [car-recalls.eu](https://car-recalls.eu/fr/inscription/dacia-logan-2018-3/) (snippet)
- DDT4ALL's address catalogue for X52 lists these candidate modules and CAN IDs (whether each is fitted is car-specific): ECM 7A, ABS-VDC 01, Airbag-SRS 2C, UCH 26, TDB (cluster) 51, EPS 04, HVAC (climate) 29, UPC-EMM (power/fuse box) 27, Audio 13, Navigation/Media-Nav 58, RemoteEntry 2F, APB 0D, CSHV 28 — DDT4ALL `projects.json`, [github.com/cedricp/ddt4all](https://github.com/cedricp/ddt4all)
- pyren function-to-address map (F2A): function 01 → 7A (injection), 02 → 01 (ABS), 03 → 51 (cluster), 04 → 26 (UCH), 05 → 2C (airbag), 08 → 29 (climate), 18 → 04 (EPS), 20 → 27 (UPC) — pyren `mod_ecu.py`, [github.com/emtee40/pyren-OBD2](https://github.com/emtee40/pyren-OBD2)

### Inferences
- Immobiliser: Renault B0 cars of this era implement the transponder/immobiliser in the **UCH** (address 26), with the engine ECU learning the code; DDT4ALL has a separate "Transpondeur 31" entry but no CAN ID for it in X52, consistent with no stand-alone immobiliser ECU. (Inference from the address table; confirm.)
- EPS (04) is listed generically; Logan II with K7M in most markets has hydraulic power steering, so expect no answer at 742/762. Manual-AC cars have no diagnosable HVAC ECU; automatic climate (29) is unlikely on the Egyptian trim. A basic radio (13) is usually not diagnosable; Media-Nav (58) may be.
- The JH3 manual gearbox has no ECU.

### Gaps
- No source confirming Bosch 8.1 vs 9.0 for the Egyptian Logan II, ESP availability (likely none on base trims), cluster supplier, UCH supplier (Continental vs Valeo/Delphi), or airbag supplier (Continental vs Autoliv/TRW) for this exact car. All must be read via 2180 / 22F18A (supplier) on a real car.

## Q3. Diagnostic bus, CAN IDs and K-line addresses for each module

### Takeaway
On Logan II (X52) every diagnosable module is on **diagnostic CAN 500 kbps, 11-bit, OBD pins 6/14**; there is no K-line in pyren's vehicle table. Logan I (X90) had K-line on pins 7/15 as well as CAN 6/14. The verified X52 ID table (request → response) is: Engine 7E0→7E8, ABS 740→760, Airbag 752→772, UCH 745→765, Cluster 743→763, EPS 742→762, HVAC 744→764, UPC 74D→76D, Audio 712→732, Media-Nav 747→767, RemoteEntry 74C→76C.

### Cited Findings
- pyren vehicle table: X90 LOGAN — ISO (K/L) pins 7-15, CAN1 6-14, CAN2 13-12; X52 LOGAN II/SANDERO II — ISO "----", CAN1 6-14, CAN2 13-12; XJF (Logan III) — CAN 6-14 only — [pyren-OBD2 README](https://github.com/emtee40/pyren-OBD2)
- DDT4ALL projects.json, X52 and X90 identical dnat/snat (request/response): 7A 7E0/7E8; 01 740/760; 2C 752/772; 26 745/765; 51 743/763; 04 742/762; 29 744/764; 27 74D/76D; 13 712/732; 58 747/767; 2F 74C/76C; 0D 755/775; 28 78A/7D7 — [DDT4ALL repo](https://github.com/cedricp/ddt4all) (`src/ddt4all/resources/projects.json`)
- pyren `mod_elm.py` dnat/snat give the same values (7A 7E0/7E8, 01 740/760, 2C 752/772, 26 745/765, 51 743/763, 04 742/762, 29 744/764, 27 74D/76D, 13 712/732) — [pyren-OBD2](https://github.com/emtee40/pyren-OBD2)
- pyren supports "double BRP" ECUs (tries CAN 250 kbps then 500 kbps) via the ecu 'brp' attribute; default is 500 kbps — pyren `mod_elm.py`
- DDT4ALL K-line (KWP2000) addressing uses the same Renault diag address byte in the header: `AT SH 81 <addr> F1`, wake-up `AT WM 81 <addr> F1 3E`, `AT IB10` (10400 baud), slow init `AT SP 4` + `AT IIA <addr>` + `AT SI`, falling back to fast init `AT SP 5` + `AT FI`; ISO8 uses `AT SP 3` — DDT4ALL `src/ddt4all/core/elm/elm.py` (`set_iso_addr`, `set_iso8_addr`)

### Inferences
- Correction to the brief's hypothesis: on Renault DiagOnCan the **ABS diag address is 01** (not 28). Address 28 in DDT4ALL's table is "CSHV" (78A/7D7), not ABS. The CAN IDs in the brief (7E0/7E8, 740/760, 752/772, 745/765, 743/763) are all confirmed.
- K-line addresses for Logan I: per the DDT4ALL code, the KWP header target equals the Renault diag address (7A engine, 26 UCH, 2C airbag, 51 cluster); ABS on Logan I K-line is therefore expected at address 01 or a legacy address, not verified. Logan I ABS (Bosch 8.0) was often K-line only; treat per-module bus on Logan I as must-test.
- CAN2 (pins 13/12) exists in the generic table but nothing on a Logan II K7M is expected there.

### Gaps
- Not verified on a real Egyptian car which IDs actually answer. App should scan all X52 IDs with `10C0` / `2180` and build the module list dynamically.

## Q4. ELM327 command sequence and which clones fail

### Takeaway
Renault DiagOnCan needs raw ISO-TP with custom flow control: `ATSP6`, `ATSH <tx>`, `ATCRA <rx>`, `ATFCSH <tx>`, `ATFCSD 300000`, `ATFCSM1`, then `10C0` to open the Renault diagnostic session and `2180` to identify. Both open-source tools require ELM327s that implement the AT FC flow-control commands (genuine ELM327 or "v1.5" Chinese clones); OBDLink/STN adapters work best.

### Cited Findings
- pyren/DDT4ALL CAN setup per module: `AT SH <TX>`; `AT FC SH <TX>`; `AT FC SD 30 00 00` (BS=0, STmin=0); `AT FC SM 1`; `AT ST FF`; `AT AT 0`; select 500 kbps (`AT SP 6`) or 250 kbps (`AT SP 8`); `AT AT 1`; `AT CRA <RX>`; global init `AT E1/L0/H0/D0`, `AT S0`, `AT AL`, `AT CAF0` (manual PCI byte framing) — pyren `mod_elm.py` lines ~2030-2068; DDT4ALL `elm.py` lines ~1564-1736 ([pyren-OBD2](https://github.com/emtee40/pyren-OBD2), [DDT4ALL](https://github.com/cedricp/ddt4all))
- DDT4ALL probes bus speed by sending raw `0210C0` (single frame: length 2, service 10, sub-function C0) — DDT4ALL `elm.py`
- Session/identification: DDT4ALL ECU scanner opens `10C0` then sends `2180` (expects `61 80 ...`) for KWP-on-CAN ECUs; for UDS ECUs it opens `1003` and reads `22F1A0`, `22F18A` (supplier), `22F194`, `22F195` — DDT4ALL `src/ddt4all/core/ecu/ecu_scanner.py`
- Keep-alive: pyren re-sends the start-session command (`10C0`) after 4 s of silence on CAN rather than 3E; on K-line it uses the ELM wake-up message `81 <addr> F1 3E` every ~3 s (`AT SW 96`) — pyren `mod_elm.py` (`keepAlive = 4`), DDT4ALL `elm.py`
- pyren requirement: "ELM327 adapter with FlowControl support (original one or chinese v1.5)"; ELM327-BT not compatible with Android 7+, use WiFi; `--cfc` option turns off automatic FC — [pyren-OBD2 README](https://github.com/emtee40/pyren-OBD2)
- pyren falls back to `AT CFC0` (software flow control) when it detects frame errors/buffer-full, and for non-OBDLink adapters truncates DTC read `1902xx` to `1902AF` because 38400 baud is "not enough to read full information about errors" — pyren `mod_elm.py` lines ~1210-1235
- DDT4ALL adapter table: ELM327 original (PIC18F25K80), ELM327 clone ("try different baud settings"), VGate iCar Pro, OBDLink SX/EX ("tested and confirmed"), ELS27, Vlinker FS — [DDT4ALL README](https://github.com/cedricp/ddt4all)
- DDT4ALL notes that some ELM327 clones reset formatting after `AT SP`, so it re-applies `AT CAF0/AT S0/AT AL` after protocol selection, and logs "received first frame only — AT CAF0 may have been reset by AT SP, or FC failed" — DDT4ALL `elm.py` ~1207, ~1724

### Inferences
- Minimal app sequence per module (example ABS): `ATZ` / `ATE0` / `ATS0` / `ATH1` / `ATAL` / `ATSP6` / `ATCAF0` / `ATSH740` / `ATCRA760` / `ATFCSH740` / `ATFCSD300000` / `ATFCSM1` / send `0210C0` / then `022180` / multi-frame response handled by the app (reassemble 1x/2x frames). With `ATCAF1` instead, a basic ELM handles ISO-TP itself but still needs `ATFCSH` because Renault ECUs do not answer FC to 7DF-style defaults.
- Typical failing clones: cheap "v2.1" clones that reject `AT FC SH/SD/SM` or `AT CRA`, or drop consecutive frames; these will read Mode 01/03 from the engine but fail on multi-frame Renault responses (2180, 21xx, 17FF00). Flag as community knowledge, not verified here.

### Gaps
- No systematic list of specific failing clone hardware was found; test with the target adapters.

## Q5. Generic OBD vs Renault-specific services; tools; DDT4ALL database

### Takeaway
Generic OBD (7DF/7E0) only reaches the engine ECU (Mode 01/03/04/07/09/0A). Everything else (ABS/airbag/UCH/cluster and the engine's Renault-specific data) needs Renault KWP2000-on-CAN services. DDT4ALL's GitHub repo contains the address tables (`projects.json`) but **not** the per-ECU XML/JSON definitions; those come from a separately supplied DDT2000 database (`ecus/eculist.xml` + ECU XMLs, or a converted `ecu.zip` with `db.json`).

### Cited Findings
- DDT4ALL loads ECU definitions from `options.ecus_dir + "/eculist.xml"` or from `ecu.zip` containing `db.json`; the repo ships only code plus `resources/projects.json` (vehicle → address → CAN ID tables, ~185 projects incl. "[X52] - Dacia Logan", "[X90] - Dacia Logan / Sandero", "[X1327] - Dacia Logan / Sandero", "[XJF] - Renault Logan III", "[XJI] - Dacia Logan III") — DDT4ALL `core/ecu/ecu_database.py`, `resources/projects.json`, [github.com/cedricp/ddt4all](https://github.com/cedricp/ddt4all)
- DDT4ALL protocols recognised: "DiagOnCAN" (ATSP 6), KWP2000 FastInit MonoPoint/MultiPoint (ATSP 5), KWP2000 5-baud init (ATSP 4), ISO8 (ATSP 3), CAN 125 kbps messaging, DoIP — DDT4ALL `core/ecu/ecu_ident.py` header
- pyren lists X52 as supported by both PyRen (CLIP-database based) and DocDB — [pyren-OBD2 README](https://github.com/emtee40/pyren-OBD2)
- Commercial tools claiming Logan II coverage: ABRITES Renault/Dacia (Logan II, Sandero II, Dokker, Lodgy, Duster Ph2) — [abrites.com Renault/Dacia](https://abrites.com/page/renault-dacia)

### Inferences
- Renault KWP-on-CAN service set to implement: `10C0` (Renault diagnostic session), `2180` (ident: part no., supplier, software, Vdiag), `21xx` ReadDataByLocalIdentifier (live data; IDs are per-ECU, from DDT/CLIP database), `17FF00` (ReadDTCByStatus, older KWP ECUs) and/or `1902xx` (UDS-style ReadDTCInformation used by newer Renault ECUs; pyren uses 1902AF), `14FF00` (clear DTCs), `3E` tester present. Exact DTC service per ECU depends on Vdiag; the app should try `1902AF` then fall back to `17FF00`.
- Without the proprietary DDT/CLIP data, an app can still: scan modules, identify them (2180), read/clear DTCs (raw codes, no text), and read generic OBD from the engine. Live data for ABS/airbag/UCH requires mapping 21xx local IDs, which is only in the DDT2000 database (not redistributable).

### Gaps
- Could not verify which DDT XML file names correspond to the Logan II K7M ECUs (database not in repo). Typical names follow `<ECU>_<supplier>_<soft>_<version>.xml`; confirm by running DDT4ALL scan on the car.
- Dialogys/CLIP/Renolink internals not examined (proprietary).
