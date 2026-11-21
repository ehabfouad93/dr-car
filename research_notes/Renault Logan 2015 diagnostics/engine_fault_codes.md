# Engine ECU fault codes: Renault Logan 2015 / Dacia Logan II, 1.6 8v K7M petrol (EMS3132-type ECU)

> Research conditions: web search worked, but page fetches failed. These hosts would not resolve from this session: autoruk.ru, ladaman.ru, renaultbook.ru, sanderologan.ru, club-renault.ru, kitayteka.ru, krutilvertel.com and actronics.co.uk. Every finding below comes from search-result snippets or summaries of those pages, not from full-page reads. Treat each value as "cited but needs confirming on the car" until someone reads the full source.
> Confidence tags used in the table: **[C]** confirmed by at least one cited Renault/Logan/Largus table; **[P]** probable, follows the Renault DF numbering seen in cited tables but not confirmed for EMS3132 K7M; **[?]** conflicting sources or none.

## Q1. Which DF codes the K7M ECU sets, and their P-code equivalents

### Takeaway
No complete, authoritative EMS3132 K7M DF list was readable. The table below is built from these sources:
- the Logan/Sandero DF-to-P table on sanderologan.ru;
- the Lada Largus EMS 31.32 tables on autoruk.ru, largus-mcv.ru and ladaman.ru (the Largus 8v uses the same K7M + EMS3132 package as the Logan II);
- generic Renault DF dictionaries.

These sources disagree on several codes (DF017, DF038, DF054, injector numbering). DF numbers are ECU-specific. The app should key its database on (ECU family, DF number), not on the DF number alone.

### Cited Findings
- On Lada Largus, the ECM is an "EMS 31.32"-type unit with a 90-pin connector. — [ladaman.ru Largus EEMS](https://www.ladaman.ru/en/Largus/1/power/ignition/elektronnaya-sistema-upravleniya-dvigatelem-esud)
- Largus EMS 31.32 table, fault-handling priority: deal with DF587 (+5 V sensor supply) and DF514 (fuel pump relay circuit) first if they are current or stored. — [autoruk.ru Largus codes](https://autoruk.ru/lada-largus/kody-neispravnostej-esud-i-ustranenie-neispravnostej-avtomobilya-lada-largus); [largus-mcv.ru](https://largus-mcv.ru/html/neispravnosti-esud.html)
- In the Largus EMS 31.32 tables, DF001 is the coolant temperature sensor circuit (open or short). DF038 is listed only as "ECU". — [autoruk.ru (EN)](https://autoruk.ru/en/lada-largus/ecu-fault-codes-and-troubleshooting-for-lada-largus)
- Largus EMS 31.32 tables: DF040–DF043 are injector circuits for cylinders 1–4; DF082 is the upstream (control) O2 sensor heater circuit; DF091 is vehicle speed information; DF514 is the fuel pump relay circuit; DF587 is the +5 V sensor supply. — [largus-mcv.ru](https://largus-mcv.ru/html/neispravnosti-esud.html); [qvarto.ru Largus](https://qvarto.ru/lada-largus-kody-neispravnostej-i-ix-ustranenie/); [radioradar.net Largus ESUD pt2](https://www.radioradar.net/repair_electronic_technics/autoelectronic_repair/lada_largus_structure_diagnostics_esud_part2.html)
- Logan/Sandero DF-to-P table: DF001 = P0115 coolant temp sensor circuit; DF002 = P0110 intake air temp sensor circuit; DF026 = P0201 injector cyl 1 control circuit; DF009 = P2120 accelerator pedal sensor track 2; DF018 = P0480 low-speed cooling fan control circuit; DF038 = P0606 ECU; DF078 = P2100 motorised throttle control circuit; DF080 = P0010 camshaft phaser (VVT) circuit; DF082 = P0135 upstream O2 sensor heater circuit. — [sanderologan.ru diagnostic codes](https://sanderologan.ru/logan/diagnosticheskie-kody.html)
- Conflict on injector numbering: the Logan/Sandero table gives DF026 = injector 1 (P0201), while the Largus EMS 31.32 tables give DF040–DF043, and generic Renault lists give DF052 = "injector 1". — [sanderologan.ru](https://sanderologan.ru/logan/diagnosticheskie-kody.html); [largus-mcv.ru](https://largus-mcv.ru/html/neispravnosti-esud.html); [avtotachki Renault codes](https://en.avtotachki.com/codes-renault/)
- Conflict on DF017: generic Renault lists (mostly diesel) give "pre-postheating (glow plug) unit control circuit", which cannot apply to a petrol K7M. — [avtotachki Renault codes](https://en.avtotachki.com/codes-renault/); [obd2-code.ru Renault](https://obd2-code.ru/renault/)
- Conflict on DF038: "computer" in Largus and Logan tables, but "rear O2 heater" in one generic list. — [autoruk.ru](https://autoruk.ru/en/lada-largus/ecu-fault-codes-and-troubleshooting-for-lada-largus); [avtotachki](https://en.avtotachki.com/codes-renault/)
- Other generic Renault dictionary entries: DF019 = high-speed cooling fan control circuit; DF057 = upstream O2 sensor; DF086 = coolant pump relay (in another table it is an automatic gearbox solenoid); DF120 = "OBD warning lamp (MIL)" circuit; DF054 is variously injector 3, engine torque controller, or gearbox P/N switch. — [obd2-code.ru Renault](https://obd2-code.ru/renault/); [carscode.ru](https://carscode.ru/obd2/zavodskie-kody-oshibok-renault)
- Generic DF003/DF004 entries ("intake air temp sensor", "coolant temp sensor") come from other Renault ECUs and conflict with the DF001/DF002 meaning above. — [kodyoshibok03.ru DF004](https://kodyoshibok03.ru/kod-oshibki-df004-reno/)
- DF002 is often seen alongside DF058 (lambda) and DF254 (throttle valve) on Megane-type ECUs, and is treated as a priority code there. One listing calls DF002 a throttle potentiometer fault rather than air temp. — [actronics.co.uk DF002 (search summary)](https://www.actronics.co.uk/news/diagnostic-help/renault-df002-error-code); [frenchcarforum Megane](https://frenchcarforum.co.uk/forum/viewtopic.php?p=622234)
- DF080 on Megane (K4M with VVT) was linked to the camshaft dephaser pulley and cleared after a cambelt job. — [frenchcarforum Megane](https://frenchcarforum.co.uk/forum/viewtopic.php?p=622231)
- One DF/P mapping crosswalk lists DF319 = P0340 camshaft sensor, but for a diesel DCM3.4 ECU. — [Renault DF→P article](https://xn--80aafbnb4dkhrbg.xn--90ais/2022/02/25/%D1%80%D0%B0%D1%81%D1%88%D0%B8%D1%84%D1%80%D0%BE%D0%B2%D0%BA%D0%B0-%D0%BA%D0%BE%D0%B4%D0%BE%D0%B2-%D0%BD%D0%B5%D0%B8%D1%81%D0%BF%D1%80%D0%B0%D0%B2%D0%BD%D0%BE%D1%81%D1%82%D0%B8-renault-%D0%B8%D0%B7-df/)
- Generic OBD scanners (ELM327) show P-codes only. Renault DF codes need CLIP or a Renault-aware tool. DDT4All is an open-source Renault tool that supports Read/Clear DTC over ELM327/Vlinker/OBDLink adapters. — [DDT4All GitHub](https://github.com/cedricp/ddt4all); [drive2 Logan ELM327 codes](https://www.drive2.ru/l/451786855025737796/)

### Draft fault table (database seed, Logan II K7M + EMS3132)
Severity scale: **S** = safe to drive; **W** = fix this week; **X** = stop now / do not drive far.
The "Cheap checks" values are taken from the Q2 findings. Values marked "confirm" are not verified for this exact car.

| DF | Generic P | Meaning | Conf. | Likely causes on Logan K7M | Cheap checks | Fix steps / parts | Sev. |
|---|---|---|---|---|---|---|---|
| DF587 | P0641 [P] | +5 V sensor supply fault | [C] (meaning) | A shorted 5 V sensor (MAP, TPS) or chafed harness drags the 5 V supply down | ~5.0 V at the MAP and TPS supply pins with ignition on; unplug sensors one at a time and see if the voltage recovers | Find the shorting sensor or wire; repair harness. **Fix this code first.** | W/X (several sensors read wrong at once) |
| DF514 | P0230 [P] | Fuel pump relay control circuit | [C] (meaning) | Relay, fuse, corroded relay socket, wiring | Listen for a 2–3 s pump prime at key-on; swap the relay; check fuse | Relay / fuse / wiring repair. **Fix this code first.** | X if no start or stalls |
| DF001 | P0115/P0117/P0118 | Coolant temp sensor circuit | [C] | Corroded connector, failed NTC sensor, wiring. Symptoms: fan runs constantly (default mode), hard cold start, high fuel use | Resistance vs temperature (Q2): about 2.2–2.5 kΩ at 25 °C, about 280–370 Ω at 80 °C (confirm). Live data should track the gauge | Clean connector; replace sensor (M12×1.5 thread) and bleed coolant | W (X if the temperature gauge also fails) |
| DF002 | P0110/P0112/P0113 | Intake air temp sensor circuit | [C] (Logan table) / [?] other ECUs | Sensor (on the Logan II K7M often combined with MAP, confirm), connector | NTC, similar curve to the CTS (confirm). Live IAT should be about ambient when cold | Replace sensor / connector | S/W |
| DF003 / DF004 | P0105-P0108 [?] | Possibly MAP sensor circuit / pressure plausibility | [?] | MAP hose cracked or off, sensor, 5 V supply | About 4–4.5 V with key on and engine off; about 1–1.5 V at hot idle (generic MAP behaviour, confirm). Check the vacuum hose | Replace hose or MAP sensor | W |
| DF017 (EMS3132 meaning unconfirmed) | P0335/P0336 | Crankshaft/TDC (flywheel) sensor circuit/signal (on K7M; the generic DF017 "glow plug" meaning is diesel only) | [?] | Sensor on the bellhousing above the flywheel; metal swarf on its tip; connector; damaged flywheel target | Resistance about 200–270 Ω (220 Ω cited for K4M, confirm for K7M). No tacho movement while cranking means no signal | Clean tip; replace sensor; check bolt torque and target teeth | X (no start / sudden stall) |
| DF026 or DF040 (cyl 1) | P0201 | Injector cyl 1 control circuit | [C] mapping conflicts by table | Connector, injector coil, harness | Injector resistance about 12–16 Ω (sources conflict, see Q2). Compare all 4; check 12 V feed | Replace injector or connector (O-rings) | W (X if misfiring heavily: catalyst damage) |
| DF027/DF041 (cyl 2) | P0202 | Injector cyl 2 | [P] | same | same | same | W |
| DF028/DF042 (cyl 3) | P0203 | Injector cyl 3 | [P] | same | same | same | W |
| DF029/DF043 (cyl 4) | P0204 | Injector cyl 4 | [P] | same | same | same | W |
| DF018 | P0480 | Low-speed cooling fan control circuit | [C] | Fan relay / resistor, fuse, fan motor | Command the fan with a scan tool; jump the relay; check fuse | Relay, fan resistor or fan motor | **X** in hot traffic (overheating risk) |
| DF019 | P0481 | High-speed cooling fan control circuit | [C] generic | same | same | same | **X** in hot weather / traffic |
| DF038 | P0606 | ECU internal fault | [C] (Logan/Largus) | Supply/ground problem, water ingress, internal ECU failure | Check battery voltage, ECU grounds and fuses before condemning the ECU | Repair grounds; ECU replace/repair (needs coding and immobiliser match) | W to X depending on symptoms |
| DF082 | P0135 | Upstream O2 sensor heater circuit | [C] | Heater element burnt, connector, fuse | Heater resistance typically a few Ω (generic zirconia, confirm). 12 V present at key-on | Replace upstream O2 sensor | S/W (fuel economy, emissions) |
| DF083 [P] | P0141 | Downstream (rear) O2 sensor heater circuit | [P] | same, rear sensor | same | Replace downstream O2 sensor | S |
| DF057 | P0130–P0134 | Upstream O2 sensor signal | [C] generic | Ageing sensor, exhaust leak before the sensor, misfire | Should switch 0.1–0.9 V at hot idle (generic) | Fix exhaust leaks first, then replace sensor | S/W |
| DF091 | P0500 | Vehicle speed information | [C] | Speed sensor on the gearbox, harness break near the connector (a frequent Logan fault per owners) | Speedo working? Wiring continuity | Repair harness / replace VSS | S (W if the idle/stall behaviour is affected) |
| Idle stepper (DF number unknown) | P0505/P0506/P0507 | Idle air control (stepper motor) circuit or idle speed out of range | [?] | Carbon on the stepper/throttle body; motor coils; air leak | Coil resistance (unsourced, often quoted about 50 Ω per winding, confirm). Clean bypass, then do idle relearn | Clean throttle body and stepper (part 7701206370 cited as K7M stepper); replace if needed | W |
| TPS (DF number unknown, possibly DF003/DF009 family) | P0120–P0123 | Throttle position potentiometer | [?] | Worn track, connector | Smooth sweep from about 0.5 V (closed) to about 4.5 V (WOT) (generic, confirm) | Replace TPS / throttle body | W |
| Knock (DF number unknown) | P0325–P0328 | Knock sensor circuit | [?] | Connector, wrong torque, sensor | Torque 20 N·m (Logan 2); piezo sensor, no DC resistance check | Retorque or replace | S/W |
| Misfire DF123 [?] | P0300–P0304 | Misfire detected (cyl x) | [?] (DF123 mentioned as misfire in one Largus summary) | Plugs, HT leads, ignition coil pack, injectors, air leaks | Swap HT leads between cylinders; coil primary about 0.5 Ω (K4M value); secondary several kΩ (confirm) | Plugs, leads, coil; clean injectors | **X** if the MIL flashes (catalyst damage) |
| Coil (DF number unknown) | P0351–P0352 | Ignition coil primary circuit | [?] | Coil pack, connector | as above | Replace coil pack | X |
| DF120 | P0650 [P] | MIL (OBD warning lamp) circuit | [C] generic | Bulb/LED, cluster wiring | Does the MIL light at key-on? | Repair cluster/wiring | S |
| DF009 | P2120 | Accelerator pedal sensor track 2 | [C] in table | **Probably N/A on cable-throttle K7M** (e-throttle variants only) | — | — | n/a |
| DF078 | P2100 | Motorised throttle control circuit | [C] in table | **Probably N/A on K7M** | — | — | n/a |
| DF080 | P0010 | Camshaft phaser circuit | [C] in table | **N/A on 8v K7M** (no VVT; applies to K4M with a dephaser) | — | — | n/a |

### Inferences
- The sanderologan.ru Logan/Sandero table appears to be a merged list covering K7J/K7M/K4M and several ECUs (it includes e-throttle and VVT codes that an 8v K7M does not have). The app should mark those codes as "not applicable to K7M 8v".
- The DF026 vs DF040 injector conflict probably reflects different ECU generations: the earlier Logan I ECUs (Siemens/Sagem) versus EMS3132. For a 2015 Logan II with EMS3132, the Largus EMS 31.32 numbering (DF040–DF043) is the more likely match, since it is the same engine and ECU family. This needs confirming with DDT4All or CLIP on the car.
- Severity grades are my own engineering judgement from the generic consequences of each fault, not from a Renault source.

### Gaps
- I could not open the full Largus EMS 31.32 table (autoruk.ru), the MR388/MR390 Logan manuals, or a DDT4All/PyRen DTC dictionary, because those hosts were blocked. A full EMS3132 DF list with sub-types (CO, CC.0, CC.1, DEF) is still missing.
- No source confirmed the DF numbers for these on EMS3132: crank sensor, idle stepper, TPS, MAP, knock, coil, misfire or rear O2.
- I found no official DF-to-P crosswalk for EMS3132. P-codes marked [P] are standard SAE meanings matched by function.

## Q2. Sensor specifications on the K7M

### Takeaway
Only a few K7M values were confirmed in snippets:
- knock sensor torque 20 N·m (Logan 2);
- CTS NTC about 2.25 kΩ at about 25 °C and about 280 Ω at about 80 °C (MR388 snippet, garbled; another Renault source says 335 ± 35 Ω at 80 °C);
- crank sensor about 220 Ω (cited for K4M);
- injectors 12–16 Ω (sources disagree);
- fuel pressure: the cited value (3.0 ± 0.2 bar, 2.5 bar under vacuum) conflicts with the commonly assumed 3.5 bar for the returnless Logan system.

Everything else needs confirming against the MR388/MR451 manuals or by measuring a known-good car.

### Cited Findings
- Knock sensor torque is 20 N·m in the Logan 2 manual. Other sources give 20–25 N·m, and a Logan 1 K7M article gives 25 N·m. On K7M the sensor sits in the rear of the block near cylinder 3. — [renaultbook.ru Logan 2 knock sensor K7M/K4M](https://www.renaultbook.ru/en/Logan/2/power/fuel/datchik-detonacii-dvigateley-k7m-i-k4m); [largus-mcv.ru knock sensor](https://largus-mcv.ru/html/dd.html)
- Fuel pressure appears as 3.0 ± 0.2 bar in the rail, and 2.5 ± 0.2 bar with vacuum at idle. 3.5 bar was not confirmed. — [loganlogan.ru K7M injection](https://loganlogan.ru/articles/sistema-vpryska-topliva-dvigatela-k7m-reno-logan.html); [kitayteka.ru K7M](https://kitayteka.ru/viewtopic.php?t=5054) (search summary; the exact attribution between these two is unclear)
- Crankshaft sensor winding about 220 Ω; it sits on the clutch housing above the flywheel. Air gap not found. — [kitayteka.ru K7M](https://kitayteka.ru/viewtopic.php?t=5054); [shamrin.ru Logan 2 crank sensor K7M](https://shamrin.ru/reno-logan-2-datchik-kolenvala-k7m-2/)
- Injector resistance: about 12 Ω at 20 °C in one Logan source, about 12–16 Ω in another; 13.5–15.5 Ω is cited for K4M. — [loganrenault.ru fuel system](https://loganrenault.ru/html/p252.html); [cool-shina.ru injector replacement](https://cool-shina.ru/auto_repair/zamena-forsunok-na-reno-logan-2.html); [kitayteka.ru K4M](https://kitayteka.ru/viewtopic.php?t=5053)
- For K4M (not K7M): CTS 300–370 Ω at 80 °C; crank sensor 220 Ω; coil primary 0.5 Ω, secondary 5,800–8,500 Ω (Nippondenso) or 9,000–12,500 Ω (Sagem). — [kitayteka.ru K4M](https://kitayteka.ru/viewtopic.php?t=5053)
- The Logan MR388 manual (K7J/K7M) lists an NTC coolant sensor with values of about 2,250 Ω near 25 °C and about 280 Ω near 80 °C. The snippet was garbled, so the temperature pairing is inferred. — [MR388 Logan PDF](https://logan-renault.narod.ru/dialogys_pdf/MR388LOGAN1.pdf)
- A Scenic 1 (K7J/K7M-era) CTS page gives 335 ± 35 Ω at 80 °C and 240 ± 30 Ω at 90 °C. — [renaultbook.ru Scenic 1 CTS](https://www.renaultbook.ru/en/Scenic/1/power/cooling/datchik-temperatury-ohlazhdayuschey-zhidkosti-snyatie-ustanovka-i)
- Part listings use M12×1.5 coolant sensors for Logan 1.6 K7M variants (K7M 710 87 hp, K7M 800 84 hp "1.6 MPI 85"). — [Autodoc Logan temperature sensor](https://www.autodoc.co.uk/car-parts/temperature-sensor-74814/dacia/logan/logan-ls/6691-1-6-mpi-85)

### Inferences
- Commonly quoted generic values, not verified here: idle stepper about 50–55 Ω per winding; O2 heater about 3–10 Ω; TPS about 0.5–4.5 V. Store them as "typical, confirm".
- The app should present CTS checks as a curve with tolerance bands, and flag the 280 Ω vs 335 Ω conflict at 80 °C.

### Gaps
- Not found for K7M: idle stepper resistance, ignition coil resistance, MAP sensor voltages, O2 heater resistance, TPS voltage range, crank sensor air gap, or an authoritative fuel pressure for Logan II.

## Q3. K7M specifics: cam sensor, throttle type, coil type, rear O2

### Takeaway
On the 8v K7M:
- **Cable throttle with an idle stepper motor (RXX):** confirmed by sources. The stepper is mounted on the throttle body.
- **Single wasted-spark coil pack, no camshaft sensor, rear O2 present on Euro 4+ Logan II:** consistent with the engine design, but not confirmed by the snippets I could read.

### Cited Findings
- The idle speed regulator sits in the lower part of the throttle body on the 1.6 8v K7M. It controls bypass air with the throttle closed. — [auto.ru Logan logbook](https://auto.ru/logbook/cars/renault/logan/6065201/); [twokarburators.ru RXX](https://twokarburators.ru/shema-rhh-reno-logan/)
- A K7M 8v stepper is sold for Logan/Sandero/Largus (Renault part 7701206370 cited). The EMS pinout has 3 ECU control lines to the idle regulator. — [drive2 part 7701206370](https://www.drive2.ru/parts/renault/7701206370/B9bjwEAAFgY); [drive2 Siemens pinout](https://www.drive2.ru/l/6091914/); [avtoazbuka K7M RXX](https://avtoazbuka.net/products/elektronnyi-regulyator-kholostogo-khoda-lada-largus-lada-largus-k7m-8v-bez-kryshki)
- Idle relearn on a Largus K7M/EMS3132: an owner had a high cold idle (about 2,000 rpm). It was cured by an adaptation done by reconnecting the battery with ignition on, then letting the stepper recalibrate. — [lada-largus.com RXX thread](http://www.lada-largus.com/forum/thread6781-1.html)
- The engine control diagram names B54 crankshaft position sensor and B24 coolant temp sensor, with no camshaft sensor listed in the summary. — [remavtocar.ru Logan EMS](https://remavtocar.ru/renault_logan_upravlenie_dvigatelem.html) (search summary)

### Inferences
- With no cam sensor and no e-throttle, codes P0340 (cam), P2100/P2120 (e-throttle/pedal) and P0010 (VVT) should not appear on a healthy K7M 8v. If they do, the ECU calibration or the reading tool is suspect.

### Gaps
- I did not confirm: the coil type (single 4-output block), rear O2 presence by model year or emissions spec, or the exact ECU on 2013–2020 Logan II K7M (EMS3132 vs Sagem/Siemens variants).
- Differences vs Logan I: Logan I K7M/K7J used earlier Siemens/Sagem ECUs (the pinout thread mentions "Siemens"), and injector DF numbering seems to differ (DF026 vs DF040). Neither point is confirmed.

## Q4. Most common codes on Logan in real life and their usual cause

### Takeaway
The most common real-world engine complaints on K7M Logans are:
- unstable idle or stalling from a dirty idle stepper or throttle body (P0505/P0506-type);
- clogged injectors and weak fuel pumps after 70–90k km (lean or misfire codes, hard hot start);
- MIL faults traced to speed sensor wiring (DF091/P0500);
- coolant sensor connector or sensor faults (DF001/P0115), which put the fan in default mode.

### Cited Findings
- K7J/K7M: deposits in the idle speed regulator (stepper) or throttle body cause hunting idle and stalls at junctions. Cleaning usually fixes it; intake leaks and dirty injectors are other causes. — [enginescope.gr K7J/K7M](https://enginescope.gr/engine/renault-k7j-k7m/)
- 1.4/1.6 MPI Logans show clogged injectors or a failing fuel pump after 70,000–90,000 km, with rough idle and hard warm starts. — [Autodoc blog Logan problems](https://www.autodoc.co.uk/info/problems-with-the-dacia-logan)
- Owner report: an MIL stayed on through three diagnostic checks and was cured by repairing a broken wire in the speed sensor harness. — [StartMyCar Logan dashboard](https://www.startmycar.com/gb/dacia/logan/problems/dashboard)
- A flashing MIL with rough idle on a Logan MCV was traced towards the speed sensor or wiring. The MIL lights permanently when an electrical fault is detected, or when a fault is detected 3 times in a row. — [DaciaClub forum](https://www.daciaclub.ro/Check-Engine-Light-t276664.html)
- The idle stepper connector is among the connectors the Logan injection diagnosis procedure covers. — [MR388 Logan PDF](https://logan-renault.narod.ru/dialogys_pdf/MR388LOGAN1.pdf)

### Inferences
- Suggested ordering for the app's "most likely first" logic:
  - Idle complaints: clean throttle body and stepper, check vacuum leaks, then electrical tests.
  - Misfire: plugs, HT leads, coil, then injectors.
  - Any multi-sensor fault: check DF587 (5 V supply) first.

### Gaps
- No frequency statistics exist. The ranking comes from qualitative owner and blog reports only.
- The English, Russian and Romanian forums with Logan II-specific code histories (logan-club.ru, daciaforum.co.uk) could not be read in this session.
