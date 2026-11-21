# Renault Logan 2015 / Dacia Logan II (K7M 1.6 8v, JH3): live data, relearns, service and common problems (Egypt focus)

> **Research limitations (read first).** This cloud session could only *search*. Fetching full pages was blocked for most hosts (auto.ru, dailydriven.ro, mymotorlist.com, startmycar.com, uk.haynes.com, en.wikipedia.org all failed DNS in the sandbox; only github.com loaded). So most citations below come from search-result snippets, not full-page reads. Treat every number as "to confirm on a real car / against Renault Dialogys or the Egyptian service booklet". Items marked **[UNVERIFIED – background knowledge]** are not backed by a source found in this session. Report writers should not present them as sourced facts.

## 1. Standard OBD Mode 01 PIDs and normal ranges

### Takeaway
I found no source that lists which Mode 01 PIDs the Logan II K7M ECU supports. The app has to ask the car itself (PIDs 0x00/0x20/0x40/...), and should not hard-code a list. Normal-range values found online are rough at best. The radiator fan switch-on point is around 92 °C (aftermarket switch data). Idle spec values seen range from 750 to 850 rpm, depending on K7M variant.

### Cited Findings
- SAE J1979 defines the standard PIDs, but not every vehicle supports every PID, and makers can add their own PIDs. Supported PIDs have to be read from the ECU (PID 00/20/40 bitmasks). — [Wikipedia OBD-II PIDs](https://www.wikipedia.org/wiki/OBD-II_PIDs); [CSS Electronics PID table](https://www.csselectronics.com/pages/obd2-pid-table-on-board-diagnostics-j1979)
- Renault-specific parameters are usually shown in Torque through "extended PID" files. A public example exists for the K9K diesel (Dacia Lodgy), but none for the K7M. — [gdincu/DaciaLodgy-K9K-OBD2-PIDs](https://www.github.com/gdincu/DaciaLodgy-K9K-OBD2-PIDs); [MeganeClubUkraine/k9k_pids](https://github.com/MeganeClubUkraine/k9k_pids)
- Several K7M variants were fitted to Logan/Sandero (K7M 710 2004–2010, later K7M 800, K7M 764 and others). The only idle figure a search snippet gave from Wikipedia was **850 rpm**. — [Wikipedia: Renault K-Type engine](https://en.wikipedia.org/wiki/Renault_K-Type_engine) (snippet only; the page would not load)
- Aftermarket radiator fan switch data for Logan lists switch-on at **92 °C** and switch-off at **82 °C** (2021 Logan III part XEFS3). Logan MCV II part RIDEX 1103T0009 lists shut-off at 82 °C. These are *thermo-switch part* specs. Logan II K7M fans are probably ECU-controlled from the CTS (see Inferences), so these may not apply directly. — [autopartspro Logan III fan switch](https://www.autopartspro.co.uk/carparts-online/radiator-fan-switch/dacia-logan/logan-iii); [autopartspro Logan MCV II](https://www.autopartspro.co.uk/carparts-online/radiator-fan-switch/dacia-logan/logan-mcv-ii)
- StartMyCar gives a normal Logan engine temperature of about 90 °C (190 °F). — [StartMyCar Logan overheating guide](https://www.startmycar.com/dacia/logan/guides/overheating)

### Inferences
- The app should run a supported-PID scan (01 00, 01 20, 01 40) and only show PIDs that respond. On a 2013–2020 EOBD petrol car, the following are very likely present, but **[UNVERIFIED – background knowledge]** until checked on the car: 0x01/0x03 (monitor and fuel-system status), 0x04 (load), 0x05 (ECT), 0x06/0x07 (STFT/LTFT bank 1), 0x0B (MAP; K7M is speed-density with a MAP sensor and no MAF), 0x0C (RPM), 0x0D (speed), 0x0E (timing advance), 0x0F (IAT), 0x11 (TPS), 0x13/0x14/0x15 (O2 sensor location and upstream/downstream voltages), 0x1C (OBD standard), 0x21 (distance with MIL on). Whether 0x42 (control module voltage) is supported is unknown. Older Renault Sirius/SIM32-era ECUs often do not report 0x42, so the app needs a fallback (for example the ELM327 `ATRV` adapter voltage reading).
- Expected normal values for a warm, healthy, naturally aspirated port-injected petrol engine (**generic; confirm on a Logan**):
  - Idle about 750–850 rpm.
  - MAP at warm idle about 30–40 kPa. At key-on with the engine off, MAP should match barometric pressure (about 100 kPa at sea level in Cairo/Alexandria).
  - STFT and LTFT each within ±10 %. A combined total beyond about ±20 % is suspicious.
  - Upstream O2 (zirconia narrowband) switching about 0.1–0.9 V several times a second in closed loop. Downstream O2 fairly steady (about 0.6–0.8 V) if the catalyst works.
  - Timing advance at idle in single digits to the mid-teens of °BTDC.
  - TPS at closed throttle typically reads a few % and not exactly 0.
- **[UNVERIFIED – background knowledge]** Renault workshop data for Logan/Sandero K7M is often quoted as: thermostat starts opening about 89 °C; ECU-commanded fan low speed about 99 °C and high speed about 102 °C; coolant overheat warning about 118 °C. These figures were **not** confirmed by any source in this session. Confirm by logging ECT against the fan relay click on a real car.
- Egypt context: in summer, ambient temperatures above 40 °C and Cairo stop-and-go traffic will keep a Logan with A/C near fan-on temperature for long periods. An ECT that sits at 95–102 °C at idle with A/C on is probably normal, provided the fan cycles. The app's alerts should not trigger at 100 °C, but should warn at about 110 °C and above. (Inference; thresholds still to confirm.)

### Gaps
- No real supported-PID dump from a Logan II K7M was found. The best fix is to capture one from a real car with an ELM327 (`0100`, `0120`, `0140`).
- No confirmed fan on/off temperatures for the ECU-controlled fan, no thermostat opening temperature, and no official idle spec for the K7M 800/K7M 8xx Logan II.
- Whether PID 0x42 is supported is unknown.

## 2. Renault-specific parameters (CLIP/DDT4ALL) and how to read them

### Takeaway
Sources disagree on what injection ECU the Logan II K7M uses: some say Siemens SIM32/SIM321, others Continental EMS3132. Renault tooling reads its parameters through manufacturer services, not Mode 01. The open-source DDT4ALL project (and a Logan-focused fork) is the most practical public source for parameter definitions. I could not extract K7M-specific DIDs.

### Cited Findings
- A repair blog calls the Logan injection ECM a **Continental EMS3132**. — [OBDII365 blog: repair Renault Logan EMS3132 ECM](https://blog.obdii365.com/2024/08/14/how-to-repair-renault-logan-ems3132-ecm/)
- Renault-style fault-finding documents for Logan/Sandero/Thalia 2 instead describe a **Siemens SIM 32 / SIM 321**, 112-track injection and ignition computer. Its immobiliser is wired to the UCH (body control unit). These documents use Renault-style CLIP commands, for example **RZ007 = clear fault memory**. After an impact is detected, the ECU can block starting until the ignition is switched off for about 10 s. — [Scribd: Fault summary table (Renault)](https://www.scribd.com/document/401418049/Fault-summary-table)
- DDT4ALL is an open-source tool for building ECU parameter screens and talking to Renault ECUs over CAN with a cheap ELM327. — [cedricp/ddt4all via awesome.ecosyste.ms](https://awesome.ecosyste.ms/projects/github.com%2Fcedricp%2Fddt4all); [Furtif/ddt4all](https://github.com/Furtif/ddt4all)
- A DDT4ALL fork (dimoroz772) includes `Renault_Logan_2G.docx`, a manual for setting up additional functions on Logan 2G. The page carries a warning that ECU changes are at your own risk. The rest of the repo is mostly MediaNav material. It does not document injection adaptations. — [dimoroz772/DDT4ALL](https://github.com/dimoroz772/DDT4ALL) (fetched)
- A guide for a different ECU family (Rover MEMS) shows the typical meaning of "adaptive values": an ECU reset clears STFT/LTFT and the learned "idle hot (decay)" stepper position, i.e. the IACV steps needed to hold target idle when warm. This is useful as a model, but it is not K7M-specific. — [MEMS FCR: Adaptive Values](https://memsfcr.co.uk/?p=49)

### Inferences
- **[UNVERIFIED – background knowledge]** Logan II (2013+) injection ECUs normally talk over CAN (ISO 15765, 500 kbit/s; request ID 0x7E0, response 0x7E8) using **KWP2000-on-CAN**. Data is read with service **0x21 + 1-byte local identifier** (for example 21 01, 21 A0). Some newer Renault/Continental calibrations use UDS **0x22 + 2-byte DID**. The real IDs for this car have to come from the DDT4ALL XML/JSON definition that matches the ECU's supplier/version reply (service 0x21 0x80 or UDS 22 F1xx identification).
- Typical Renault CLIP "PR" (parameters) for this generation of petrol ECU (names to look for in DDT4ALL, **not confirmed for K7M**): battery/supply voltage; coolant temperature; air temperature; manifold pressure; throttle position; idle-speed regulation setpoint and actual; **idle stepper (RCO/position)**; **idle-regulation adaptive (offset)**; richness (fuel-trim) adaptives at idle and under load; upstream/downstream O2 voltage; fan low/high relay command; A/C compressor request; immobiliser status. Typical "ET" (statuses): fan GMV low/high on, A/C authorised, idle regulation active, closed loop active, immobiliser coded.
- Renault CLIP lists adaptive resets as "RZ" commands. RZ007 (clear faults) is confirmed above. The exact RZ number for "reset adaptives" on this ECU was not found.

### Gaps
- No public K7M/Logan II DDT4ALL definition file was opened, so no DIDs, scaling formulas or parameter names can be given. Next step: clone `cedricp/ddt4all` and its ECU database, then search for "EMS3132", "SIM32" or "K7M".
- The ECU identity for a 2015 Egyptian-market Logan (SIM32 vs EMS3132, possibly differing by year) is unresolved. Read it from the car.

## 3. Idle stepper / throttle body cleaning relearn, battery disconnect, adaptive resets

### Takeaway
No Logan/K7M-specific published relearn procedure was found. The K7M uses a cable throttle plus an ECU-driven stepper (bypass idle air) motor, not an electronic throttle. General practice is that the ECU relearns idle on its own after a warm-up idle period, and that a battery disconnect clears learned values. A Renault tool is needed only to *force* an adaptive reset or to clear faults.

### Cited Findings
- On the K7M the stepper motor is an ECU-controlled bypass valve that sets idle airflow (idle actuator / IAC). — [DS Indústria: Idle Air Control (IAC)](https://www.ds.ind.br/en/products/idle-air-control-iac/1624)
- A dirty idle control valve is listed as a minor K7M fault. — summarised from K7M engine reviews in search results: [AutoHints K7M](https://www.autohints.com/renault-k7m-16l-90hp-inline-4-cylinder-engine-12966); [mymotorlist K7M](https://mymotorlist.com/engines/renault/k7m/)
- Generic guidance (not Renault-specific):
  - Disconnecting the battery erases learned idle values, and idle can be unstable until the ECU relearns.
  - High idle / P0507 is the most common complaint after throttle cleaning.
  - Vacuum leaks from disturbed hoses can cause the same symptoms.
  - A weak battery can interrupt adaptation.
  — [iCarsoft throttle relearn guide](https://icarsoft.com/knowledge/article/throttle-body-relearn-guide); [Sparrowcar rough idle after cleaning](https://sparrowcar.com/blog/rough-idle-after-cleaning-or-replacing-the-throttle-body-causes-and-relearn/); [YourMechanic high idle after cleaning](https://www.yourmechanic.com/question/high-idle-after-throttle-body-cleaning)
- A French-car forum thread discusses adjusting the Renault idle stepper. — [frenchcarforum.co.uk: Idle Stepper Motor adjust](https://frenchcarforum.co.uk/forum/viewtopic.php?p=63751) (not read in full)

### Inferences
- Practical procedure for the app's guidance screen (**generic best practice; confirm on a real car**):
  1. Clean the throttle body and the stepper/bypass passage with the engine off. Do not force the throttle plate open against the stop screw, and never touch the throttle stop screw.
  2. Reconnect everything. Switch the ignition on for about 10–30 s without starting, so the ECU can initialise the stepper.
  3. Start the engine without touching the accelerator. Let it idle until the radiator fan cycles at least once, with A/C, lights and blower off.
  4. Then switch A/C on for a few minutes so the ECU learns the loaded idle.
  5. Drive normally. LTFT and idle adaptives settle over a few drive cycles.
- After a battery disconnect, expect a slightly high or hunting idle at first. Fuel trims and idle adaptives reset, and the radio may need its code. The ECU coding and immobiliser stay intact.
- Persistent high idle after cleaning usually means an air leak, a stuck or damaged stepper, or a throttle stop screw that was moved. It does not mean "needs a computer". Only a forced adaptive reset (CLIP/DDT4ALL "RZ" command) or clearing stored faults needs a diagnostic tool.
- There are no injector-coding or ignition adaptations to relearn on this engine. It uses low-pressure port injection and a coil pack. **[UNVERIFIED]**

### Gaps
- No official Renault (Dialogys/MR) K7M idle-relearn or "RZ adaptive reset" procedure was found online.
- I could not confirm whether the Logan II K7M ECU needs any key-on wait for stepper initialisation.

## 4. Service schedule (oil, timing belt/water pump, plugs, filters, coolant, JH3 oil, brake fluid) incl. Egypt/severe use

### Takeaway
Published intervals conflict, and no Renault Egypt booklet was found. Suggested working values, to confirm with the dealer or booklet:
- **Engine oil:** 10,000 km / 1 year standard; about 5,000–7,500 km in severe Egyptian use.
- **Timing belt + water pump + tensioner:** about 60,000 km (sources say 60,000–120,000 km) or about 4–5 years, whichever comes first.
- **JH3 gearbox:** about 2.8 L of TRJ 75W-80, "lifetime" per Renault.

The K7M has a timing **belt**. Autodoc's "timing chain" claim is very likely wrong.

### Cited Findings
- auto-abc lists the Logan 1.4/1.6 petrol timing belt at **60,000 km**. The 2013 1.1 petrol is listed at 120,000 km, with faster belt wear in sand or salt environments. For the 2013 Logan 1.1 petrol it gives oil every **15,000 km / 1 year**, 5W-30 or 5W-40. — [auto-abc Logan 2007 1.6 petrol](https://www.auto-abc.eu/Dacia-Logan/v20377-2007/service); [auto-abc Logan 2013 1.1](https://www.auto-abc.eu/Dacia-Logan/v20389-2015/service)
- Autodoc says the Logan Express 1.6 (K7M 710) has a timing **chain** to change at about 150,000 km. This conflicts with the belt intervals above and is very likely an error, since the K7M is a belt-driven SOHC 8v (see inference). — [Autodoc](https://www.autodoc.co.uk/car-parts/timing-chain-10511/renault/logan/logan-express/59105-1-6)
- For the Logan generally, OnlineRepairManuals gives oil every 10,000 km / 1 year and the timing belt every 120,000 km / 6 years. These figures are from a generic aggregator. — [onlinerepairmanuals Logan](https://onlinerepairmanuals.com/dacia/logan/)
- Weak water pumps on the K7M are linked to overheating and head-gasket failure, so the pump is normally changed with the belt (see section 5). — [AutoHints K7M](https://www.autohints.com/renault-k7m-16l-90hp-inline-4-cylinder-engine-12966)
- YallaMotor (Egypt/Arabic) suggests changing the Logan's oil every 5,000–7,500 km or at least yearly, the air filter about every 15,000 km, and an annual service at an authorised Renault workshop. These are general articles, not booklet data. — [YallaMotor Logan MCV 2025 tips](https://www.yallamotor.com/ar/news/top-repair-and-maintenance-tips-for-the-2025-renault-logan-mcv-46637); [YallaMotor Logan 2025 maintenance](https://www.yallamotor.com/ar/news/how-to-maintain-your-renault-logan-2025-for-long-term-performance-52195)
- **JH3 gearbox** (paired with the K7M in the Logan):
  - capacity about **2.8 L**;
  - Renault-recommended oil Elf Tranself **TRJ 75W-80** (or NFJ 75W-80);
  - the manufacturer schedules **no oil change** (fill for life). Change only when repairing or if the oil is contaminated.
  — [avtotachki: Renault JH3](https://en.avtotachki.com/mehanicheskaya-korobka-renault-jh3/); [cararac Logan gear oil](https://cararac.com/gear_oil/dacia/logan.html); [renaultbook Logan gearbox](https://www.renaultbook.ru/en/Logan/1_p/transmission/gearbox/osobennosti-konstrukcii-korobki-peredach)
- The official Dacia user manual covers checking the oil level and warns against overfilling. It does not give intervals in the snippet found. — [Dacia user manual: engine oil](https://www.user-manual.dacia.com/en/content/logan/maintenance/accessing-engine-levels/engine-oil)

### Inferences
- **[UNVERIFIED – background knowledge, confirm with the Renault Egypt booklet]**
  - Engine oil: K7M capacity about 3.3–3.5 L with filter. Renault spec RN0700 (e.g. 5W-40 or 10W-40 in hot climates).
  - Spark plugs: about every 30,000 km for standard copper/nickel plugs. Shorten this on CNG-converted cars.
  - Air filter: every 15,000–20,000 km. Halve this in dusty Egyptian conditions.
  - Fuel filter (inline, under the car): about every 30,000–60,000 km.
  - Coolant: Renault Glacéol RX Type D (ethylene glycol, OAT), about every 4–5 years or 90,000–120,000 km. Egyptian owners commonly top up with water, which shortens pump and radiator life.
  - Brake fluid: DOT4 every 2 years.
  - Timing belt kit + water pump: change together at 60,000 km / 4 years. This is the conservative figure widely used in Russia/Romania and suits hot, dusty conditions.
- Egypt counts as "severe" service: heat, dust, short trips, idling in traffic, and CNG use. The app should default to the severe intervals:
  - oil: 5,000–7,500 km;
  - air filter: 7,500–10,000 km;
  - plugs: 20,000 km, or 15,000 km on CNG;
  - timing belt + pump: 60,000 km / 4 years.

### Gaps
- No official Renault Egypt (Renault Egypt / Ghabbour or later distributor) service booklet for the 2015 Logan was found online.
- No source in this session confirmed the K7M oil capacity, the Renault oil spec, the spark plug interval, or the coolant type/interval.

## 5. Common real-world problems (Egypt / hot climate) incl. CNG and fuel quality

### Takeaway
K7M reviews agree on these weak points:
- **Ignition coil pack:** cracks, moisture gets in, and the engine misfires.
- **TDC/crank sensor:** cranks but won't start when hot; oxidised connector.
- **Water pump / overheating:** can lead to head-gasket failure and coolant in the oil.
- **Dirty idle stepper:** unstable idle.

Low-pressure injectors are very tolerant of poor fuel. Egypt-specific data on CNG and Logan failures is anecdotal. CNG generally raises valve and seat wear and changes fuel-trim behaviour.

### Cited Findings
- **Head gasket / overheating:** the most serious K7M issue is head-gasket failure, often caused by a weak coolant pump that fails to circulate coolant. Signs are milky oil, coolant loss without a visible leak, and white smoke. — [AutoHints K7M](https://www.autohints.com/renault-k7m-16l-90hp-inline-4-cylinder-engine-12966); [dailydriven.ro K7M](https://dailydriven.ro/en/renault-k7m-16-8v-engine-specs-issues-reliability-1592247)
- **Ignition coil:** the best-known K7M fault is cracking of the ignition coil. Moisture enters and causes misfire. Reportedly a revised coil appeared around 2012. — [mymotorlist K7M](https://mymotorlist.com/engines/renault/k7m/)
- **TDC sensor:** if the engine cranks but won't fire when hot, the crank (TDC) sensor or its oxidised contacts is the likely cause. The sensor is on the bellhousing above the gearbox; wiggling the wiring is a quick test. — [mymotorlist K7M](https://mymotorlist.com/engines/renault/k7m/); [dailydriven.ro K7M](https://dailydriven.ro/en/renault-k7m-16-8v-engine-specs-issues-reliability-1592247)
- **Injection:** the low-pressure injectors are very resistant to poor-quality fuel and rarely fail. A dirty idle control valve and minor oil leaks are listed as small faults. — [mymotorlist K7M](https://mymotorlist.com/engines/renault/k7m/); [AutoHints K7M](https://www.autohints.com/renault-k7m-16l-90hp-inline-4-cylinder-engine-12966)
- General Logan II problem roundups: [Autodoc blog: Dacia Logan problems](https://www.autodoc.co.uk/info/problems-with-the-dacia-logan); [auto.ru: Logan II used problems (RU)](https://auto.ru/mag/article/nadyozhen-li-renault-logan-ii-pokoleniya-vse-problemy-avtomobilya-s-probegom/); [zr.ru: Renault engine problems (RU)](https://zr.ru/content/articles/917278-osnovnye-problemy-dvigatelej-renault/). These were not readable in full in this session.
- **Overheating causes** for Logan (StartMyCar guide): cooling fan, thermostat, low coolant/leaks, pump. — [StartMyCar](https://www.startmycar.com/dacia/logan/guides/overheating) (snippet only)
- **ECU / immobiliser:** Logan EMS3132 ECM failures can cause no-start. Immobiliser and EEPROM repair is done with tools such as OBDSTAR DC706 or I/O Terminal. — [OBDII365 blog](https://blog.obdii365.com/2024/08/14/how-to-repair-renault-logan-ems3132-ecm/)
- **CNG (natural gas):**
  - An Ain Shams University study notes Egypt's push to convert petrol cars to CNG and the "many technical problems" in vehicles designed for petrol. — [ASU research repository](https://research.asu.edu.eg/handle/123456789/203545)
  - SAE work shows CNG's dry, hot combustion increases valve and seat-insert wear. — [SAE 2016-01-1089](https://saemobilus.sae.org/content/2016-01-1089); [SAE 2026-26-0125](https://saemobilus.sae.org/papers/cng-ffv-fuel-application-exhaust-valve-redesign-robustness-improvement-combat-abnormal-valve-guide-seat-wear-2026-26-0125)
  - Owner reports describe valve problems after aftermarket kits. — [Team-BHP CNG kit problems](https://www.team-bhp.com/forum/technical-stuff/251976-problems-after-market-cng-kit-installation-2.html)
  - A Mexican complaint site lists a CNG-related cylinder-head problem on a 2007 Logan 1.6. — [opinautos](https://www.opinautos.com/mx/renault/logan/defectos/310340/compre-mal)

### Inferences
- **Cooling fan, Egypt:** on Logan II the radiator fan is commanded by the injection ECU from the coolant temperature sensor, through relays and (on non-A/C or low-speed circuits) a resistor. Typical Egyptian failures are:
  - burnt low-speed resistor or relay, so only high speed or no low speed;
  - corroded connectors;
  - a failing CTS (حساس حرارة) giving a wrong gauge and late fan.
  **[UNVERIFIED – background knowledge; no Arabic forum source could be retrieved.]**
  App checks: compare ECT (PID 05) against IAT at cold start (they should be within a few °C). Watch for ECT jumps or a stuck value. Log whether the fan state changes at the expected ECT.
- **Fuel quality (Egypt sells 80, 92 and 95 RON):** the K7M is a low-compression (about 9.5:1) 8v designed for regular fuel, so 92 is generally adequate. 80 RON may cause knock and retarded timing, visible as low timing advance under load. **[UNVERIFIED – no source found; compression ratio is background knowledge.]**
- **CNG conversions, common in Egyptian Logans (taxis and private cars):**
  - Aftermarket sequential or venturi kits emulate or cut the injectors. The ECU still runs closed loop on the O2 sensor, so on gas the fuel trims shift (often lean, with positive LTFT).
  - This can set lean codes (P0171), O2 sensor or heater codes, misfire codes (P0300–P0304) from tired coils/plugs (gas needs higher ignition voltage), and occasionally injector-circuit codes (P0201–P0204) if the emulator is faulty.
  - Advice for the app:
    - record trims separately for petrol and gas modes;
    - remind owners to run petrol periodically;
    - shorten spark plug and coil checks;
    - advise valve-clearance checks. The K7M has adjustable (screw/nut) rockers, so this is possible. **[UNVERIFIED]**
  - All of these are inferences from general CNG behaviour, not from Logan-specific data.
- **Other likely Egypt items to cover in the knowledge base, not sourced here:**
  - fuel pump weakening from running on low fuel or dirty fuel;
  - alternator/regulator wear in heat (check battery voltage of about 13.8–14.5 V at idle);
  - throttle cable and clutch cable wear;
  - engine mounts;
  - A/C compressor load causing idle dips (stepper/adaptive issue).

### Gaps
- Egyptian Arabic forums and Facebook groups (e.g. "لوجان حساس حرارة", "لوجان مروحة الرادياتير") returned no indexable Logan-specific results via search. ContactCars, Hatla2ee and Masrawy turned up only sales/news items, not technical content.
- No source quantified CNG's effect on Logan O2/trim codes or engine life.
- The JH3 gearbox's common faults (e.g. 5th-gear wear, synchro, clutch cable) were not researched or sourced in this session.
