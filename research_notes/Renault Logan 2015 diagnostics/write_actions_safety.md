# Write/control actions on Renault Logan 2015 / Dacia Logan II (K7M 1.6 8v petrol, manual) via ELM327 — what is possible and what is safe

Scope note: Primary Renault workshop documents (MR388/MR426 "Fault finding" manuals) are only available as Scribd copies, which could not be fetched in this session (scribd.com, x-engineer.org and faolex.fao.org were blocked by the session network). Several findings therefore rely on search-result excerpts of those documents, and many protocol-level details are from general ISO 14230/14229 knowledge rather than a fetched source; these are flagged as inferences. Information from Clio/Megane/Sandero/Duster/Zoe/Logan III is flagged where used.

## 1. Clearing DTCs (Mode 04 vs Renault 14FF00 / 14FFFF(FF) per module; what cannot be cleared; side effects)

### Takeaway
Clearing codes is the most useful and lowest-risk write action, but it must be module-aware: generic Mode 04 only reaches the engine ECU and resets readiness monitors/freeze frame; Renault-specific clears (KWP2000 service 0x14 / UDS 0x14) are needed for ABS/airbag/UCH, and the airbag module must never be cleared when it reports a "computer present or stored"/crash fault (DF001) because that erases evidence and is prohibited by Renault's procedure.

### Cited Findings
- Mode 04 clears emission-related diagnostic info: stored DTCs, freeze frame, stored test data and monitor results, and turns off the MIL; monitors revert to "not ready" and need a full drive cycle — [x-engineer.org Mode $04 (via search excerpt)](https://x-engineer.org/?p=5201); [Motor Age "10 modes of OBD-II"](https://www.vehicleservicepros.com/motorage/technicians/drivability/10-modes-obdii?page=0%2C1); [Snap-on OBD-II Service Modes](https://www.snapon.com/DiagnosticsManuals/Help/OBDII/Content/Common/Help%20Topics/OBD/OBDII%20Service%20Modes.htm); [AutoSuccess readiness monitors](https://www.autosuccessonline.com/?p=71964)
- Search excerpts did not state that Mode 04 resets long-term fuel trims/adaptives; sources treat trims as live Mode 01 PIDs — [AutoSuccess](https://www.autosuccessonline.com/?p=71964); [Saab 9-2X OBD-II operation](https://saabwisonline.com/9-2x-9346/2005/2-engine/engine-diagnostics-2-0t/obd-ii-general-scan-tool/technical-description/operation) (see Inferences — this is manufacturer-dependent).
- A DDT4ALL user could not clear UCH (BCM) DTCs on a Renault Zoe ph1 with a Chinese ELM327 (PIC18F25K80): the adapter hit "BUFFER FULL" while reading ~30 stored-but-unconfirmed codes; a maintainer noted "The error clear command 14FFFF, you didn't send"; fix suggestions were enabling CFC (ATCFC0) / an STN-based adapter (STN1110, vLinker FS) — [DDT4ALL discussion #1081](https://www.github.com/cedricp/ddt4all/discussions/1081) (Zoe, not Logan).
- In the same thread pyren showed 4 faults vs ~30 in DDT4ALL; status byte "10" meant tests not completed since last clear (stored but unconfirmed) — [DDT4ALL #1081](https://www.github.com/cedricp/ddt4all/discussions/1081)
- PyRen (CLIP-database mode) supports "Clear DTCs" and lists LOGAN (136), LOGAN II/SANDERO II (151), NEW SANDERO/LOGAN (191) as supported; needs an ELM327 "with FlowControl support (original one or chinese v1.5)" — [pyren-OBD2 README](https://github.com/emtee40/pyren-OBD2)
- Renault airbag fault-finding: "It is prohibited to use command RZ001 Clear fault memory when DF001 Computer is present or stored"; DF001 remedy is to replace the airbag computer (component code 756), recheck, then unlock the new unit — [Renault airbag fault finding (Scribd copy, via search excerpt)](https://www.scribd.com/document/609392295/Renault); [Renault Clio airbag manual](https://www.manualslib.com/manual/458384/Renault-Clio.html?page=44)
- Airbag computers ship "locked" to avoid accidental triggering (warning light lit); locking "prevents accidental erasing of the registered contexts of impacts"; after a deployment the unit cannot be locked until an unlock command is given — [Renault Clio airbag manual, manualslib](https://www.manualslib.com/manual/458384/Renault-Clio.html?page=12) (Clio-era Temic/Autoliv documentation, not Logan-specific)
- Abrites sells crash-data clearing / "Airbag, UCH and EPS renewal" as a separate licensed function (RR014), i.e. not a plain DTC clear — [Abrites RR014](https://abrites.com/partial/rr014)
- Renault fault-finding documents advise: after any repair clear computer memory, road test, then re-check with the diagnostic tool — [Fault summary table (Scribd, via search excerpt)](https://www.scribd.com/document/401418049/Fault-summary-table)

### Inferences
- Exact services (from ISO 14230/14229 knowledge, not fetched source): KWP2000 ClearDiagnosticInformation = 0x14 + groupOfDTC (Renault commonly uses 14 FF 00 = "all DTCs", positive response 54 FF 00); UDS ClearDiagnosticInformation = 14 FF FF FF (response 54). The DDT4ALL maintainer's "14FFFF" is the 2-byte group form used by some Renault KWP-on-CAN ECUs. The app should take the exact clear request from the ECU's DDT4ALL XML / CLIP definition rather than hard-coding.
- Logan II (2013+) modules are expected to be on diagnostic CAN (ISO 15765, 500 kbps, 11-bit, Renault addressing e.g. engine 7E0/7E8, ABS 760/740, airbag 772/792, UCH 745/765) — this is commonly cited in DDT4ALL/pyren configs but was NOT verified for this car in this session.
- Recommendation: Mode 04 on engine — OFFER WITH WARNING (readiness monitors reset → car fails an OBD-based inspection until a drive cycle; freeze frame lost — read and save first). Renault 0x14 on engine/ABS/UCH/cluster — OFFER WITH WARNING (engine off, ignition on, read and log first). Airbag clear — OFFER ONLY IF no DF001/"computer stored"/crash-recorded fault is present; otherwise BLOCK; never offer crash-data erase or unlock/lock commands.
- Clearing on the K7M likely does not erase idle/fuel adaptives (Renault keeps a separate RZ "reset adaptives" command), but this is unverified for this ECU.

### Gaps
- Exact per-module clear request bytes and ECU types for Logan II K7M (Siemens/Continental EMS31xx vs Sagem S3000) not confirmed — Renault MR documents on Scribd were unreachable.
- Whether the Logan II airbag ECU (Autoliv/Continental) rejects 0x14 when crash-locked or silently accepts it — not found.

## 2. Actuator tests (KWP 0x30 / UDS 0x2F / 0x31) on K7M ECU and other modules

### Takeaway
Renault's CLIP database defines "equipment tests"/actuator commands (AC0xx) per ECU and both PyRen (CLIP mode) and DDT4ALL can execute them over ELM327, but I found no Logan-K7M-specific list; the typical set (fan low/high, fuel pump relay, purge canister, A/C compressor, idle actuator, injectors, cluster gauges, ABS pump/valves) should be treated as ECU-dependent and gated by engine-off/speed-0 preconditions.

### Cited Findings
- PyRen can "Execute equipment tests (depends on ECU)" and "Change configuration (depends on ECU)"; it warns "BE VERY CAREFUL. ONLY YOU RESPONSIBLE FOR ALL YOU ARE DOING WITH YOUR CAR" — [pyren-OBD2 README](https://github.com/emtee40/pyren-OBD2)
- DDT4ALL README: non-expert mode is intended to be harmless; Expert mode should only be used if you understand CAN/ECUs since "serious damage is possible on a live vehicle"; plugin system exists for vehicle-specific procedures (airbag/EPS resets); supports KWP2000 and DoIP — [DDT4ALL GitHub](https://github.com/cedricp/ddt4all)
- Abrites Renault/Dacia diagnostics list actuator tests among functions (commercial reference for availability) — [Abrites Renault/Dacia manual](https://abrites.com/media/user_manuals/html/abrites-diagnostics-for-renault-dacia-user-manual/index.html)
- A Siemens SIM32/SIM321 petrol injection is listed for Logan/Sandero/Thalia 2 in a Renault document (ECU-to-engine mapping not confirmed); Sagem S3000 is the other common K7M-era ECU — [Scribd fault table (search excerpt)](https://www.scribd.com/document/401418049/Fault-summary-table); [ecutesting.com S3000](https://www.ecutesting.com/common-faults/renault/s3000-ecu/)
- K7M idle on Clio is by idle stepper (IAC) in the throttle body (cable throttle) — [DS idle air control](https://www.ds.ind.br/en/products/idle-air-control-iac/1624) (Clio K7M parts listing)
- Fuel pump is energised ~1 s at each ignition-on (priming) on a Renault injection system (different ECU, flagged) — search excerpt of [Renault service manual demo](https://krutilvertel.com/pdf/demo/motorist/service-manual-renault-symbol-2009-demo.pdf)

### Inferences
- Service mapping (ISO knowledge, unverified for this car): KWP2000 InputOutputControlByLocalIdentifier = 0x30 <LID> <controlOption> [state] (pos. resp 0x70); StartRoutineByLocalIdentifier = 0x31 (resp 0x71), StopRoutine = 0x32. UDS equivalents: 0x2F InputOutputControlByIdentifier (DID, 03 = shortTermAdjustment, 00 = returnControlToECU), 0x31 RoutineControl (01 start/02 stop/03 results). Most Renault ECUs require a diagnostic session first (KWP 10 C0 / 10 85-type "extended" or UDS 10 03) and a TesterPresent (3E) keep-alive during the test; actuator tests normally do NOT require 0x27 security access on Renault (unverified).
- Risk ranking for an app (proposed):
  - Low (OFFER WITH WARNINGS, engine off, speed 0, timed auto-stop, explicit "return control" on exit): cooling fan low/high (keep hands clear — fan can start unexpectedly), A/C compressor clutch (only engine running per CLIP, so prefer not offering), canister purge valve, fuel pump relay (short timed run; fire risk if lines open), instrument cluster gauge sweep / warning-lamp test, horn/lights/wipers/central locking from UCH.
  - Medium (OFFER WITH STRONG WARNINGS or advanced-mode only): idle stepper position commands (can stall/raise idle; engine running), individual injector tests (engine off injects fuel into a cylinder — hydrolock/washdown risk if repeated; engine running = cylinder cut, catalyst heat).
  - High (NEVER OFFER in consumer app): ABS pump motor and inlet/outlet valve tests and ABS "bleed" routines (brake loss if interrupted with pedal pressed; Renault requires vehicle stationary and often bleeding procedure), airbag/pretensioner related commands, anything on EPS.
- An interrupted 0x30/0x2F (dropped Bluetooth link) normally ends when the ECU session times out (~5 s without TesterPresent) and control returns to ECU — but a fan/pump could run until timeout; ABS valves left in a state mid-routine is the main hazard. Unverified for specific ECUs.

### Gaps
- No fetched source lists the exact AC-codes/LIDs for the Logan II K7M ECU, ABS (Bosch 8.1/9?), cluster or UCH; Renault MR388/MR426 PDFs (Scribd) unreachable.
- DDT4ALL Logan XML screen names not retrieved (ECU database zip not downloaded).

## 3. Relearns / resets (idle adaptives, TDC/flywheel learning, service interval, injector codes, key programming)

### Takeaway
Resets of adaptives (RZ-type commands) and service-interval reset are low-risk; TDC/flywheel target learning is done by driving (decel) rather than a command on most Renault petrol ECUs; injector coding is diesel-only (K9K dCi) and n/a for K7M; key/immobiliser programming needs security access/PIN and must not be offered.

### Cited Findings
- Injector coding discussions for Dacia concern the 1.5 dCi (K9K), e.g. "codage injecteurs dacia sandero 1.5 dci" — [PlaneteRenault forum](https://www.planeterenault.com/forum/codage-injecteurs-dacia-sandero-1-5-dci-68-ch-t56883.html?amp=1); [dailydriven.ro Logan injector corrections](https://dailydriven.ro/de/uberprufung-der-wertekorrekturen-der-einspritzdusen-bei-dacia-logan-766129)
- Key learning for Dacia is sold as a dedicated licensed function (Abrites RR027 "Dacia 2020+ key learning"); UCH renewal (RR014) separately — [American Key Supply RR027](https://www.americankeysupply.com/product/19813); [Abrites RR014](https://abrites.com/partial/rr014)
- Abrites notes new-generation UCH (SWEET 400) on Logan III/Sandero III 2020+ needs a CB012 connection (i.e., not plain OBD) — [Abrites Renault/Dacia page](https://abrites.com/page/renault-dacia)

### Inferences
- Idle/adaptive reset (Renault "RZ" reset of adaptives, implemented via 0x31 routine or 0x3B write) — OFFER WITH WARNINGS (engine off; car may idle roughly until relearned; follow with warm-up idle). Command bytes unverified.
- Flywheel/TDC target learning: on Renault petrol ECUs typically learned automatically during decelerations (unverified for K7M); app should explain the procedure, not command it.
- Service interval reset on Logan II is done from the cluster trip button per owner manual on many markets (not verified here); diagnostic reset via cluster write — offer with warning only if confirmed.
- Key programming/immobiliser/UCH virginising — NEVER OFFER (requires 0x27 security access and Renault PIN; risk of non-start).

### Gaps
- No source found for the exact K7M adaptive reset command/LID on Logan II; no source confirming Logan II service-interval reset method.

## 4. Configuration (VIN, DRL, auto-lock, speed-dependent locking) via DDT4ALL/PyRen on UCH

### Takeaway
UCH configuration (CF-type parameters such as CF272 single-door opening, auto-lock while driving) is possible via CLIP/DDT tools with ignition on, but carries real risk (wrong values, half-written configs, lost functions); a backup dump before any change and battery support are mandatory, and a consumer app should at most offer a short whitelist of reversible options, ideally not at all in v1.

### Cited Findings
- Renault UCH configuration is done in the tool's Repair Mode → Configuration tab with ignition on, then verified in the configuration reading menu; CF272 "Single Door Opening" changes unlock behaviour (one press driver door, second press all) — [Renault UCH fault finding MR426 (Scribd, via search excerpt)](https://www.scribd.com/document/512930490/MR426B9087B000)
- Dacia owner manual lists "lock doors during driving"/automatic locking as user-adjustable functions — [Dacia Logan user manual](https://www.user-manual.dacia.com/el/node/1802)
- PyRen DDT mode can save ECU configuration dumps, compare, and roll back configuration; Expert mode (`--exp`) needed to press DDT buttons — [pyren-OBD2 README](https://github.com/emtee40/pyren-OBD2)
- DDT4ALL warns Expert mode can cause "serious damage ... on a live vehicle"; author disclaims responsibility — [DDT4ALL GitHub](https://github.com/cedricp/ddt4all)
- Logan III (2022) owner using DDT4ALL needed gateway (SGW) unlock; afterwards reported widespread dashboard warnings and lost functions (steering wheel, parking sensors), then "NO DATA" on all ECUs — [DDT4ALL discussion #1631](https://github.com/cedricp/ddt4all/discussions/1631) (Logan III, not Logan II — Logan II has no SGW as far as known)
- A Sandero owner using DDT4ALL/RenoLink dumps hit firmware and speed-limiter display problems on the cluster, unresolved — [PlaneteRenault thread](https://www.planeterenault.com/forum/sandero-cherche-1-backup-firmware-calc-sandero-ii-phase-1-t58535.html?amp=1)
- Abrites offers module recovery/configuration transfer for Sandero II/Duster Continental UCH — evidence that bad UCH configs/firmware need specialist recovery — [Abrites RR031](https://abrites.com/partial/rr031)
- A DDT4ALL thread attributes problems to a flat battery during a session — [DDT4ALL discussion #1089 (via search summary)](https://www.github.com/cedricp/ddt4all/discussions/1089)
- DDT4ALL modification on a Clio caused tail lights to light with DRL (side effect of coding) — [ClioSport DDT4ALL modifications](https://cliosport.net/threads/ddt4all-modifications.826511)

### Inferences
- Configuration writes use KWP 0x3B WriteDataByLocalIdentifier (or 0x2E WriteDataByIdentifier on UDS) inside an extended session; on many Renault UCH variants CF writes do not need 0x27, which is exactly why they are dangerous in a consumer app (no second barrier). VIN write (0x3B/0x2E VIN record) — NEVER OFFER (legal/identity, and engine ECU VIN tied to immobiliser on some ECUs).
- Recommendation: v1 app = read-only display of configuration; any write = advanced mode with mandatory full read-back backup, battery >12.4 V / charger, engine off, write single byte, read-back verify, one-click restore. DRL/auto-lock are the only candidates and only after confirming the exact UCH variant (Continental vs others).

### Gaps
- Exact Logan II UCH variant, CF parameter list and byte layout not retrieved; no confirmed bricking report for Logan II UCH specifically.

## 5. Actions needing security access (0x27) or flashing (0x34/0x36) and legal issues (odometer, emissions, Egypt)

### Takeaway
Anything requiring SecurityAccess (0x27), RequestDownload/TransferData (0x34/0x36/0x37), immobiliser/key, odometer, VIN or emissions calibration must be hard-blocked in the app; odometer alteration is illegal in most jurisdictions (US federal law explicit), Egypt's specific odometer provision was not found, and Egyptian traffic law fines vehicles whose exhaust breaches environmental standards.

### Cited Findings
- US 49 U.S.C. §32703 "Preventing tampering" prohibits advertising, selling, using or installing a device that makes an odometer register a mileage different from the true distance — [Cornell LII 49 USC 32703](https://www.law.cornell.edu/uscode/text/49/32703)
- US EPA enforcement policy on vehicle tampering and aftermarket defeat devices (updated 23 Nov 2020); FY2020–2023 national initiative against defeat devices — [EPA Clean Air Northeast tampering page](https://cleanairnortheast.epa.gov/tampering.html)
- Western Australia: odometer changing illegal under Australian Consumer Law, max penalty $50,000 — [WA Consumer Protection](https://consumerprotection.wa.gov.au/odometer-tampering)
- Saudi guidance treats rolling back odometers as commercial fraud (regional comparison, not Egypt) — [thelawsa.com](https://thelawsa.com/%D8%B9%D9%82%D9%88%D8%A8%D8%A9-%D8%A7%D9%84%D8%AA%D9%84%D8%A7%D8%B9%D8%A8-%D9%81%D9%8A-%D8%B9%D8%AF%D8%A7%D8%AF-%D8%A7%D9%84%D8%B3%D9%8A%D8%A7%D8%B1%D8%A9/)
- Egypt Environment Law No. 4 of 1994 (65 articles), executive regulation Decree 338/1995 (amended 2009, 2015); the regulation bars vehicles whose exhaust pollutants exceed limits set by EEAA with the Interior and Industry ministries — [UNEP LEAP Law 4/1994](https://leap.unep.org/en/countries/eg/national-legislation/law-no-4-1994-environment); [UNEP LEAP Decree 338/1995](https://leap.unep.org/en/countries/eg/national-legislation/decree-no-338-1995-issuing-implementing-regulation-environment)
- Egypt traffic law amendment (Art. 72 bis 2) fines LE 5,000–15,000 for violations threatening public safety or environment, including exhaust breaching environmental standards — [Egypt Independent](https://www.egyptindependent.com/?p=2816363)
- Egyptian used-car guides recommend comparing odometer with service records (odometer fraud is a recognised problem) — [Hatla2ee](https://eg.hatla2ee.com/news/200833/كيف-تكتشف-عداد-الكيلومترات-المزيف-في-ا/)

### Inferences
- Block list (app must refuse to send, enforced by a whitelist of allowed SIDs rather than a blacklist): 0x27 SecurityAccess, 0x34/0x35/0x36/0x37 download/upload/transfer, 0x3D WriteMemoryByAddress, 0x11 ECUReset beyond a soft reset, 0x28 CommunicationControl, 0x85 ControlDTCSetting, 0x2E/0x3B writes to VIN/odometer/immobiliser/calibration identifiers, programming session 0x10 02 (UDS) / 0x10 85 (KWP programming). Allowed: 0x10 default/extended, 0x3E, 0x14, 0x18/0x19/0x17 read DTC, 0x21/0x22 read, and a curated list of 0x30/0x2F/0x31 IDs.
- In Egypt, odometer rollback during a sale would most likely fall under general fraud (Penal Code) / Consumer Protection Law 181/2018 — NOT verified. Disabling emissions functions (catalyst/O2 monitor, EGR/purge) could expose the owner under the traffic-law exhaust provision above.
- App should carry a liability disclaimer, require explicit per-action confirmation, and log every write (timestamp, ECU, request, response).

### Gaps
- No Egyptian article specifically penalising odometer tampering found; Law 4/1994 article text (Art. 36 vehicle exhaust) could not be fetched (faolex blocked).

## 6. ELM327 clone reliability (v1.5 PIC18F25K80 vs v2.1) for multi-frame/session commands; dropped link risk

### Takeaway
Cheap "v2.1" clones frequently lack half the AT command set (flow-control, header/CAN filter commands) and are unsuitable for Renault session-based writes; a PIC18F25K80 "v1.5" clone or, better, an STN-based adapter (vLinker FS, OBDLink) is needed, and even then Bluetooth drops make long or safety-relevant routines risky.

### Cited Findings
- Adapters reported as "v2.1" often have a main chip that "doesn't support a half of original ELM327 commands and logic"; some vendors relabelled the same firmware as v1.5; test with ATR1/ATCF700 and look for "?" — [FORScan forum: known problems with China clones](https://forum.forscan.org/viewtopic.php?p=5601)
- Genuine ELM327 is a PIC18F25K80; flow-control commands added in v1.1 — [Wikipedia ELM327](https://en.wikipedia.org/wiki/ELM327)
- Some "v1.5" clones cannot send CAN RTR frames and silently drop them — [Linux kernel can327 docs](https://docs.kernel.org/6.3/networking/device_drivers/can/can327.html)
- repair.wiki: ensure the ELM327 has the original PIC18F25K80 chip "otherwise there will be connection errors" for Renault tools — [repair.wiki Renault](https://repair.wiki/w/Renault)
- PyRen requires FlowControl support (original or Chinese v1.5); "ELM327-BT not compatible with Android 7.0 and above, use ELM327-WiFi" — [pyren-OBD2 README](https://github.com/emtee40/pyren-OBD2)
- DDT4ALL lists adapters: ELM327 original, clone ("try different baud settings"), VLinker FS ("most stable"), vGate iCar Pro, OBDLink SX/EX, ELS27 — [DDT4ALL GitHub](https://github.com/cedricp/ddt4all)
- Clone PIC18F25K80 ELM gave "BUFFER FULL" on multi-frame UCH DTC reads; fix was ATCFC0 or STN adapter — [DDT4ALL #1081](https://www.github.com/cedricp/ddt4all/discussions/1081)
- Firmware replacement for ELM327 BT v1.5 clones is documented by ediabaslib (shows hardware variability) — [ediabaslib replace ELM327 firmware](https://uholeschak.github.io/ediabaslib/docs/Replace_Elm327_BT_Mini_Firmware.html)

### Inferences
- App should run an adapter capability probe at connect (ATI, AT@1, ATSH xxx, ATCRA/ATCF/ATCM, ATFCSH/ATFCSD/ATFCSM 1, ATCFC0, ATCAF0) and disable all write/control features if any return "?".
- Mitigations for dropped links: keep writes single-frame where possible, send TesterPresent, use explicit "return control to ECU" on exit/reconnect, require engine off for most actions, and never run routines whose interruption leaves hardware in an unsafe state (ABS bleed, programming). Note pyren's claim about BT on Android 7+ conflicts with common experience of Android BT ELM apps working (e.g., Torque) — likely specific to pyren's Python BT stack; flag as uncertain.

### Gaps
- No quantitative failure-rate data for clone adapters; no Logan-specific report of a bricked module from a dropped ELM link.

## Summary risk-ranked table (proposed for the app; services from ISO knowledge, IDs per ECU from DDT4ALL/CLIP DB)

| # | Action | Service | Preconditions | Main risk | Recommendation |
|---|---|---|---|---|---|
| 1 | Read DTC/freeze frame (baseline) | 03/02, KWP 17/18, UDS 19 | ign on | none | Offer |
| 2 | Clear engine DTC (generic) | 04 | ign on, engine off | monitors not ready, freeze frame lost | Offer with warning |
| 3 | Clear engine/ABS/UCH/cluster DTC (Renault) | 14 FF 00 (KWP) / 14 FF FF FF (UDS) | ign on, engine off, read+log first | masks fault | Offer with warning |
| 4 | Clear airbag DTC | 14 … | no DF001/crash fault present | erases crash evidence; prohibited when DF001 | Offer with strong warning + auto-block on DF001 |
| 5 | Cluster gauge/lamp test, UCH outputs (horn, locks, lights) | 30 / 2F / 31 | speed 0, engine off | minor | Offer with warnings |
| 6 | Cooling fan LS/HS, purge valve, fuel pump relay | 30 / 2F | engine off, speed 0, timed | moving fan; fuel leak | Offer with warnings |
| 7 | Adaptive values reset (idle/fuel) | 31 or 3B (ECU-specific) | engine off | rough idle until relearn | Offer with warnings (if command confirmed) |
| 8 | Idle stepper / injector tests | 30 / 2F | engine state per CLIP | stall, fuel wash, cat heat | Advanced mode only |
| 9 | UCH config (auto-lock, DRL) | 3B / 2E | backup, battery support | lost functions, needs recovery | Advanced only, or never in v1 |
| 10 | ABS pump/valve tests, bleed | 30 / 31 | stationary, bleeding procedure | brake loss | Never offer |
| 11 | Airbag lock/unlock/crash erase | 31/3B | — | safety, evidence | Never offer |
| 12 | Keys/immobiliser, VIN, odometer | 27 + 3B/2E | PIN | illegal/no-start | Never offer |
| 13 | Flashing/remap/emissions disable | 10 02/85, 27, 34/36/37 | — | brick, illegal | Never offer (block at SID level) |
