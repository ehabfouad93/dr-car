# Renault Logan 2015 / Dacia Logan II (K7M 1.6 8v, manual): non-engine module fault codes (ABS, airbag/SRS, UCH, instrument cluster, power steering, network)

> Research conditions: in this session only web search result summaries could be read. Direct fetches of scribd.com (Renault MR fault-finding manuals), daciaclub.ro, mr-fix.info and the DDT4ALL GitHub repo were blocked by the session's network policy. So **no Renault primary DF table could be read in full**. Every DF number below is either quoted from a secondary source (cited) or marked UNVERIFIED. The app database must take DF numbers and wording from a real dump of the car's ECUs (DDT4ALL / PyRen / CLIP). Do not hard-code the DF numbers listed here as fact.
>
> Important structural point for the app: **Renault DF numbers belong to one ECU, not to the whole car.** DF006 in the ABS ECU and DF006 in the UCH are different faults. The database key must be (ECU type + ECU software/variant + DF number), not the DF number alone. The secondary sources below that mix DFs across ECUs show what goes wrong when the key is the DF number alone.

## ABS: system type, common DFs, Logan-specific causes

### Takeaway
Logan I (2004-2012) fault-finding documentation uses a **Bosch 8.1** ABS, with DF006 = front left wheel speed sensor circuit. I could not find a source naming the ABS on the Logan II (2013+) or its DF list (Bosch 9 is likely but unconfirmed). The most common real-world faults are wheel speed sensor and wiring faults and corroded encoder/tone rings, mostly at the rear. The Logan II rear sensors are active (Hall/magnetic-encoder) sensors.

### Cited findings
- A Renault/Dacia ABS fault-finding document covers the **Bosch 8.1** system and tells the technician to deal with **DF006 "Front left-hand wheel speed sensor circuit"** first when several faults are present. This shows that ABS faults have a priority order. The document applies to the Bosch 8.1 era, not explicitly to Logan II. — [Scribd: Fault summary table (Renault ABS Bosch 8.1)](https://www.scribd.com/document/401418049/Fault-summary-table) (search snippet only; full doc not readable here)
- A secondary DTC site lists DF007 as "rear left-hand wheel speed sensor circuit" (ABS) but also titles DF007 as "rail pressure sensor circuit" (injection), and lists DF001-DF004 under the UCH. This internal contradiction shows that DF numbers are reused per ECU. Do not use the site as a primary key. — [obdii.pro DF007](https://obdii.pro/en/code/DF007)
- Logan II rear ABS sensors are sold as **active sensors**, about 440 mm long (e.g. Wagner ABS00065 rear left for Logan II). One listing gives a **26-tooth ABS ring** for the rear. — [autodoc Logan II TCe 90 ABS sensor](https://www.autodoc.parts/car-parts/abs-sensor-10138/dacia/logan/logan-ii/58612-tce-90); [autopartspro Logan II ABS sensor](https://www.autopartspro.co.uk/carparts-online/abs-sensor/renault-logan/logan-ii)
- Left-rear-specific sensors (e.g. Japanparts ABS-001, "Left Rear", Logan from 2004) and rear-left Hall sensors with cable are listed, so the left and right rear sensors are separate parts. — [spareto ABS-001](https://spareto.com/products/japanparts-sensor-wheel-speed/abs-001); [autodoc Logan ABS sensors](https://www.autodoc.parts/car-parts/abs-sensor-10138/dacia/logan)
- Active sensors read a magnetic encoder built into the wheel bearing. Replacing the bearing without first removing the sensor can damage the sensor, and static discharge can harm active sensors. A failed sensor is a frequent cause of the ABS warning light. — [NTN-SNR wheel speed sensors PDF](https://www.NTN-SNR.com/sites/default/files/2023-01/Wheel%20speed%20sensors_EN.pdf)
- General ABS diagnosis: rear tone ring rust is very common, especially where roads are salted. A light that appears in winter and clears when warm points to the ring. A new sensor will not fix a rusted ring. Rust on the sensor mounting boss changes the air gap. The fix often means replacing the ring or hub/bearing. Clear codes after the repair. — [apextechnation ABS light](https://apextechnation.com/articles/abs-warning-light); [autodashicons ABS after sensor replacement](https://autodashicons.com/abs-light-replacing-wheel-sensor)
- HELLA Tech World has a Logan-specific article "ABS warning lamp not functioning" (title only seen). — [HELLA: Dacia Logan ABS warning lamp not functioning](https://hella.com/techworld/ae/bi/dacia-logan-abs-warning-lamp-not-functioning)
- Generic U0121 = lost communication with ABS module. Causes: ABS module power failure, blown fuse, CAN wiring, flat battery, and rarely module failure. — [RepairPal U0121](https://repairpal.com/obd-ii-code-u0121); [obdadvisor U0121](https://obdadvisor.com/codes/code/u0121-code)

### Inferences
- **Draft ABS table for the app (the DF numbers are UNVERIFIED placeholders except DF006 on Bosch 8.1; confirm them from a DDT4ALL dump of the car's ABS ECU):**

| Fault family | Renault DF (verify) | OBD-style equivalent (generic, verify) | Likely Logan causes | Checks | Fix / parts | Severity |
|---|---|---|---|---|---|---|
| Front L wheel speed sensor circuit | DF006 (Bosch 8.1, cited) | C0035-type | Connector corrosion, chafed lead, sensor failure | Sensor resistance/supply, wiring continuity to ABS ECU, connector pins | Sensor (one per corner) | Fix this week (ABS off, normal brakes remain) |
| Front R / Rear L / Rear R sensor circuit | UNVERIFIED (adjacent DFs) | C0040/C0045/C0050-type | **Rear**: harness under the car exposed to salt; sensor lead damaged when drums or bearings are serviced | As above, plus wiggle test | Sensor, harness repair | Fix this week |
| Wheel speed **signal** implausible / missing teeth | UNVERIFIED | C-code "signal" subtype | Rusty encoder or tone ring, wrong air gap, rust under the sensor boss, bearing or encoder magnet damaged | Live data: compare the 4 speeds while driving; inspect ring and encoder | Clean sensor seat; hub/bearing with encoder or ring | Fix this week |
| Pump motor / valve / ECU internal | UNVERIFIED | C0110-type / internal | Hydraulic unit failure (more common on older Logan I Bosch 8.1 units, unconfirmed) | Check pump motor fuse first, then ECU test | ABS unit repair or exchange, then bleed with the tool | Fix this week. **Stop now if the brake (red) warning lamp is also on** (EBD may be lost) |
| Supply voltage low/high | UNVERIFIED | — | Weak battery, alternator, ground strap | Battery/charging voltage test | Battery/charging repair, clear code | Fix this week |
| Lost comms with ABS | — | U0121 | ABS fuse, flat battery, CAN wiring | Fuses, battery, CAN wiring | Wiring/fuse | Fix this week |

- The severity rule above (ABS light only: normal brakes still work, ABS and red brake light together: stop) is standard ABS/EBD behaviour, not sourced to Dacia here. Confirm it against the owner's manual warning-lamp section.
- Logan I vs II: Logan I documentation = Bosch 8.1. Logan II = probably Bosch 9 (unconfirmed). DF lists likely differ between the two, so tag every DF row by ECU variant.

### Gaps
- Full Renault DF list for the Logan II ABS ECU (MR manual "38C ABS" for X52/L52). Scribd was blocked. Fetch the DDT4ALL ECU XML or read the car with DDT4ALL/PyRen.
- Confirmation of ABS supplier/version on 2013-2020 Logan, and whether ESP was offered on the user's market version.
- Whether the Logan II rear drum hub has an integrated magnetic encoder bearing or a toothed ring on the drum. Sources disagree in type (the "26-tooth ring" listing vs active encoder sensors). **Verify on the car.**

## Airbag / SRS: DFs, clock spring, pretensioners, seat connectors, crash data

### Takeaway
The most common real-world SRS faults are the driver airbag circuit through the clock spring ("spirale") and connectors that work loose or corrode (under-seat plugs where fitted, pretensioner in the B-pillar). These are clearable after repair. A **crash-recorded / "computer locked"** state is not clearable by normal diagnostics: the ECU must be replaced or reset by a specialist. On every SRS fault, the airbags should be treated as not deploying.

### Cited findings
- Renault-family example: Megane CC owner with **DF071 "Driver's front airbag circuit 2 open circuit"** and **DF072 "circuit 1 open circuit"**, which returned after clearing (the clock spring was the suspect). This is a Megane, not a Logan. — [PressReader / Car Mechanics, Airbag system fault](https://www.pressreader.com/uk/car-mechanics-uk/20190801/283562337123109)
- Repair guidance: check the connection at the airbag ECU and the wiring from clock spring to ECU before replacing the clock spring. In one case the plug, not the spring, was faulty. — [vehicleservicepros Autologic fix](https://vehicleservicepros.com/12167402); [2carpros clock spring](https://2carpros.com/questions/clock-spring-32109590--1708502)
- Generic B0001 (driver frontal stage 1) on Dacia Logan: causes are harness, loose connector or airbag module. This is a generic aggregator, low trust. — [obd2-finder B0001 Logan](https://obd2-finder.pages.dev/en/b0001-dacia-logan)
- Clock spring part references: Logan I MCV 255672425R / Valeo 251645. Sandero I (2008-2011) 1255544794R / 6001551364 / Valeo 251646. Symptoms: airbag lamp, dead steering wheel controls, dead horn. — [novaluz clock spring Dacia](https://www.novaluz.pt/en/clock-springs/74-clock-spring-dacia-duster-logan-sandero-5600884702103.html); [novaluz clock spring 2](https://www.novaluz.pt/en/clock-springs/73-clock-spring-airbag-renault-dacia-duster-logan-sandero-5600884702110.html)
- Clock spring is among the most common SRS shop failures at higher mileage. While the airbag lamp is on, the airbag may not deploy. A stored crash code or a blown pretensioner will bring the lamp back after clearing. — [safetyrestore airbag light causes](https://www.safetyrestore.com/blog/airbag-light-causes/)
- Under-seat airbag connectors are dislodged by seat movement or items on the floor. Fixes are reseating, cleaning the contacts or a zip-tie. The pretensioner is in the B-pillar (belt reel), not under the seat. Forum "solder the plug" fixes alter the circuit and are not recommended. These sources are Clio/SEAT forums, not Logan. — [cliosport under-seat connector fix](https://cliosport.net/threads/airbag-connector-under-passenger-seat-fix.625424/); [seatcupra post](https://www.seatcupra.net/forums/goto/post?id=3384248)
- Airbag reset vendor (commercial, unverified) claims **DF194 = "crash data saved"** on Dacia Sandero II, removable only professionally, and B1080 = internal ECU error. — [airbag24 Sandero II airbag ECU repair](https://www.airbag24.de/en/products/dacia-sandero-ii-airbag-steuergeraet-reparatur)
- A reset-tool vendor list names **"Temic OBDII Logan 2"** (and "AB90 OBDII Sandero2") as SRS ECU types. This suggests the Logan II SRS ECU is a Continental/Temic unit, not Autoliv/TRW. Unverified. — [diagcode airbag tool](https://www.diagcode.com/products/airbagtool/); see also [crashdata.co.uk A2C17351701 Sandero 98510332R](https://crashdata.co.uk/product/a2c17351701-dacia-sandero-airbag-module-repair-and-reset-98510332r/) (A2C = Continental part prefix)
- Renault Megane II Autoliv: **DF034 "Computer locked"** after a crash. This is a different car and ECU. — [digital-kaos Megane II Autoliv crash](https://www.digital-kaos.co.uk/forums/showthread.php/295489-Airbag-crash-in-Renault-Megane-II-Autoliv)
- Dacia manual: if the airbag lamp stays on with the engine running, there is a fault. Contact a dealer. — [Dacia Logan user manual](https://www.user-manual.dacia.com/sk/node/4659)

### Inferences
- **Draft SRS table (DFs UNVERIFIED for Logan II except where cited for a sister model):**

| Fault | DF (verify) | Generic B-code (verify) | Logan causes | Checks | Fix | Clearable? | Severity |
|---|---|---|---|---|---|---|---|
| Driver airbag circuit open / resistance | Megane: DF071/DF072. Logan: verify | B0001/B0002-type | Clock spring worn (high mileage, steering-wheel work), connector | Battery disconnected, wait, then check resistance via the tool's live data. **Never probe squibs with an ohmmeter** | Clock spring (verify part no. against the old unit or VIN) | Yes, after repair | Fix this week. Airbag inactive |
| Passenger airbag circuit | verify | B0010-type | Dash connector | As above | Connector/wiring | Yes | Fix this week |
| Belt pretensioner L/R circuit | verify | B0050s-type | B-pillar connector, seat/floor harness | Connector reseat | Connector or pretensioner (replace if fired) | Yes, unless fired | Fix this week |
| Side airbag / under-seat connector (if fitted) | verify | — | Seat movement, corrosion | Reseat, clean contacts | Connector repair (no solder bypass) | Yes | Fix this week |
| Supply voltage | verify | — | Weak battery during cranking | Battery test | Charge or replace battery, then clear | Yes | Safe to drive if it clears |
| **Crash recorded / computer locked** | Sandero II vendor: DF194. Megane: DF034 | — | Deployment or crash event | Read freeze frame | **Replace or reset the SRS ECU** and the fired parts | **No** (not with normal tools) | Fix before relying on the SRS. Specialist job |

- Safety note for the app: SRS work = disconnect the battery and wait (time per Renault, verify). Never probe the squib circuits with a meter, and never bypass a squib with a resistor.

### Gaps
- Confirm the airbag ECU supplier/variant on 2015 Logan (Temic/Continental vs Autoliv/TRW). Read the ECU identification with DDT4ALL.
- Actual Logan II SRS DF list, and which DFs the ECU marks "memorised only" vs "crash". The MR manual (88C) was not readable.
- Whether Logan II front seats carry side airbags (and so under-seat connectors) varies by market and trim. **Verify on the car.**

## UCH (body computer) incl. immobiliser, central locking, lights, door switches

### Takeaway
On Logan, the UCH (Unité Centrale Habitacle) handles immobiliser key recognition (it sends an authorisation code to the engine ECU), central locking and RF remote, and door/brake/clutch switch inputs. Common failures are key-side (transponder or remote battery), power/fuse problems (on Logan the UCH shares a fuse with the diagnostic socket), and aftermarket alarm wiring. DF numbering for the UCH is poorly documented publicly and conflicts between sources.

### Cited findings
- UCH DFs listed by a secondary site: DF001 UCH internal, DF002 steering lock, DF003 clutch switch circuit, DF004 brake switch circuit. The same site also lists DF009 "UCH rear left wheel sensor". Low trust. — [obdii.pro DF007 page (UCH list)](https://obdii.pro/en/code/DF007)
- Logan forum: a **DF044** fault persisted after a starting problem was fixed. On that Logan, the **UCH and the diagnostic connector share one fuse**. An alarm module wired to the UCH power fuse caused communication problems with the UCH. — [daciaclub.ro DF044 thread](https://www.daciaclub.ro/Logan-computer-error-DF044-t38815.html) (search snippet; DF044 meaning not confirmed)
- The UCH reads the key and sends an authorisation code that unlocks the engine ECU. Common causes of no-start are a flat key battery and a damaged or wet key chip. — [startmycar Logan immobilizer](https://www.startmycar.com/dacia/logan/guides/immobilizer-anti-theft-system)
- Only an approved dealer can repair the immobiliser (Dacia manual). An unrecognised key = no start. — [Dacia user manual: engine immobiliser](https://www.user-manual.dacia.com/en/getting-to-know-your-vehicle/engine-immobiliser)
- Renault Key & Immobiliser Memento: the UCH/decoder manages immobiliser authorisation and central locking. Covers emergency code entry and remote resync (on Clio II/Kangoo/Master: hold the lock button ~5 s). Older Renault models. — [Renault Immobiliser Memento PDF](http://www.matrasport.dk/Cars/Espace/vault/JE/IMMOBILISER/RENAULT_IMMO_KEY_MEMENTO.pdf)
- Clio III forum: UCH/BCM faults DF091 (airbag locking switch circuit) and DF066 (multiplexed network). Clio documentation: DF130 "instrument panel not configured" (UCH). French scraped list: DF037 = engine immobiliser, DF055 = immobiliser signal circuit. All are non-Logan or low-trust. — [renaultforums Clio III immobiliser](https://www.renaultforums.co.uk/threads/clio-iii-1-4-16v-immobiliser-issue-fixed.576082/page-2); [Liste code défaut Renault DF (PDF)](https://cdn.prod.website-files.com/65f045721299e692c33c05b0/671d881d6f4c86e304468424_32041547033.pdf); [obdllm Renault common codes](https://obdllm.com/en/blog/renault-common-dtc-codes/)
- DF280 in the UCH reported as immobiliser-related in a Sandero II thread. — [mhhauto Sandero II 2013](https://mhhauto.com/Thread-Dacia-Sandero-II-2013)
- UCH replacement or key programming on Renault/Dacia is done with tools such as OBDSTAR (needs PIN/coding). — [obdii365 OBDSTAR Renault UCH](https://www.obdii365.com/service/program-renault-bcm-uch-with-obdstar-x300-classic-g3.html)
- A Renault/Dacia service document describes the UCH as the passenger compartment connection unit and refers to the Logan/Sandero wiring diagram technical note. — [scribd MR426B9087B000](https://www.scribd.com/document/512930490/MR426B9087B000) (snippet)

### Inferences
- **Draft UCH table (all DF numbers UNVERIFIED):**

| Fault | DF (verify) | Logan causes | Checks | Fix | Severity |
|---|---|---|---|---|---|
| Key not recognised / transponder | verify (DF037/DF055-type on other Renaults) | Key chip damaged or wet, antenna ring, wrong key | Try the spare key, read UCH live "key recognised" status | Spare key, antenna ring, key programming (dealer/locksmith, needs PIN) | Car won't start. Recovery or locksmith |
| Immobiliser code to engine ECU not received / UCH-ECU link | verify | Fuse shared with the OBD socket, alarm wiring, CAN | Fuse check, remove the aftermarket alarm | Repair wiring | Won't start |
| Brake pedal switch circuit | DF004 (secondary source) | Switch out of adjustment or failed | Brake lights work? live data | Switch | Fix this week (also affects the engine ECU) |
| Clutch switch circuit | DF003 (secondary source) | Switch | Live data | Switch | Fix this week |
| Central locking / RF remote | verify | Remote battery, desync, door lock motor | Resync, check the lock motor | Battery, motor | Safe to drive |
| Door switch / courtesy light | verify | Corroded door switch, harness in the door hinge | Live data door open/closed | Switch or harness | Safe to drive (may drain the battery) |
| Multiplex network fault | DF066-type (Clio) | CAN wiring, battery voltage | See the network section | — | Fix this week |
| UCH internal / not configured | DF001 (secondary) / DF130-type | Replaced UCH not coded | Configuration via DDT4ALL/CLIP | Configure | Depends |

### Gaps
- Actual Logan II UCH DF list and the DF044 meaning (the daciaclub thread could not be opened).
- Whether Logan II has a UCH-integrated immobiliser (transponder key, no keyless). This is very likely given the key/remote design but unverified here.
- Fuel gauge path: whether the gauge reads the sender directly in the cluster or via the UCH/CAN on Logan II. No source found.

## Instrument cluster: temperature display, fuel gauge, service reset, hidden menu

### Takeaway
2013-2020 Dacia Sandero/Logan/Duster have **no coolant temperature gauge**, only an over-temperature warning light. Owners read live coolant temperature with an ELM327 OBD app. The official Dacia service reset is to select the "distance before service" screen with the ignition on and hold the trip button about 10 s. I found no verified hidden numeric coolant page for Logan II. A reported hidden test menu (hold the trip button while switching on) applies to older Clio/Logan I clusters and is unverified.

### Cited findings
- Dacia owners (daciaforum.co.uk) say newer Dacias have no temperature gauge, just an over-temp warning light. One owner fitted an ELM327 and phone app to see coolant temperature. — [daciaforum: No temperature gauge](https://www.daciaforum.co.uk/threads/no-temperature-gauge.8185/)
- 2015 Sandero Stepway owner: no temp gauge was the first thing they noticed. — [HonestJohn Sandero Stepway problems](https://www.honestjohn.co.uk/forum/post/index.htm?t=107947)
- Dacia online manual (current-model pages) lists coolant temperature among trip computer screens and describes a needle gauge zone. This applies to newer Logan (III) / equipment-dependent clusters. **It conflicts with the forum reports for 2013-2020**, so it should not be applied to a 2015 Logan without checking. — [Dacia Logan user manual node 1797](https://www.user-manual.dacia.com/lv/node/1797); [node 1802](https://www.user-manual.dacia.com/fi/node/1802)
- Official reset: ignition on, engine off, display "distance before service", press and hold button 2 or 3 for ~10 s until the service distance is shown steadily. After an oil change, reset both service and oil distance where both exist. — [Dacia Logan user manual node 1796](https://www.user-manual.dacia.com/sk/node/1796); [node 1797](https://www.user-manual.dacia.com/lv/node/1797)
- Third-party Logan MK2 videos: scroll with the button on the end of the right-hand wiper stalk, hold ~10 s on the service screen until the spanner and "20000" (km interval) appear. Another describes a different pedal-sequence method (probably another model). — [scegliauto tutorial 39067](https://www.scegliauto.com/en/video/dacia/tutorial/39067/); [scegliauto 67965](https://www.scegliauto.com/en/video/dacia/tutorial/67965/); [scegliauto 49602](https://www.scegliauto.com/en/video/dacia/tutorial/49602/)
- mr-fix.info describes a hidden cluster menu for Renault Clio / Dacia Logan (hold the trip reset button and turn the key to position II) showing engine fault info. It is aimed at older models and unverified for Logan II. — [mr-fix.info p=404](https://mr-fix.info/?p=404) (snippet; page blocked)

### Inferences
- App guidance: on a 2015 Logan, **numeric coolant temperature = OBD PID 0x05 via ELM327** (works over generic OBD on the K7M ECU). Do not promise a cluster page.
- Service reset: use the trip/display button (stalk end or dash button depending on cluster), ignition on, scroll to the spanner/km screen, hold ~10 s. Flag that it varies by cluster.
- Cluster DFs (fuel gauge sender open/short, "instrument panel not configured" after replacement, CAN loss) should be read from the cluster ECU dump. None are verified here.

### Gaps
- A verified Logan II cluster self-test/hidden menu, and whether it shows coolant temperature. **Verify on the car**: hold the trip button while switching the ignition on and record what appears.
- Fuel gauge fault behaviour (Logan known issue: sender/float in the tank pump unit). No source found in this session.

## Power steering (if fitted)

### Takeaway
Parts catalogues list both hydraulic (belt-driven) and electro-hydraulic pumps for the Logan II, so the system type must be checked by VIN or by looking under the bonnet. A conventional belt-driven hydraulic pump has no ECU and no DTCs. Only an electro-hydraulic (GEP) unit or EPS column would log faults.

### Cited findings
- Logan II (L8) and Logan MCV II listings include both hydraulic and electric-hydraulic power steering pumps (2013-2019). — [autopartspro Logan II PS pump](https://www.autopartspro.co.uk/carparts-online/power-steering-pump/dacia-logan/logan-ii); [autopartspro Logan MCV II](https://www.autopartspro.co.uk/carparts-online/power-steering-pump/dacia-logan/logan-mcv-ii)
- An electric pump is listed for K7M Sandero/Logan 2010-2013. — [DiPa commerce pump](https://www.dipacommerce.com/en/pompa-sterzo-idraulica-nuova-dacia-logan.html)
- Autodoc has Logan guides both for a "power steering pump" and for "electric power steering + steering column", meaning EPS exists on some Logan versions. — [autodoc PS pump Logan](https://club.autodoc.co.uk/manuals/steering/power-steering-pump/dacia/logan); [autodoc EPS Logan](https://club.autodoc.co.uk/manuals/electrics/electric-power-steering-steering-column/dacia/logan)

### Inferences
- K7M 1.6 manual 2015: most likely a belt-driven hydraulic pump (no codes). Common faults would be leaks, noisy pump and low fluid. Unverified.

### Gaps
- No DF list found for any Logan steering ECU. Check whether DDT4ALL detects a steering ECU on the car.

## Network / U-codes common on Logan

### Takeaway
No Logan-specific U-code pattern was found. Generic logic applies: several "lost communication" codes at once (U0100 ECM, U0121 ABS, U0155 cluster) point to a shared cause (battery voltage, fuse, ground, CAN wiring) rather than to several failed modules. The Logan-specific clue is that the UCH and the diagnostic socket share a fuse, and aftermarket alarms tapped into UCH power cause communication faults.

### Cited findings
- U0121 = ABS not communicating on CAN. Causes: ABS power, fuse, CAN wiring, flat battery, and rarely the module. U0100/U0126/U0415 often appear alongside it. — [RepairPal U0121](https://repairpal.com/obd-ii-code-u0121); [avtotachki U0121](https://en.avtotachki.com/u0121-narushenie-svyazi-s-modulem-upravleniya-antiblokirovochnoy-tormoznoy-sistemoy-abs/)
- U0155 = lost communication with the instrument cluster. A failing cluster drops off the bus and other modules log U0155 (Ford example). — [ecutesting U0155 Focus](https://www.ecutesting.com/common-faults/ford/u0155-ford-focus/)
- Logan: UCH and diagnostic connector share one fuse. An alarm module wired to the UCH power fuse caused communication problems. — [daciaclub.ro DF044](https://www.daciaclub.ro/Logan-computer-error-DF044-t38815.html)
- Clio-family UCH logs DF066 "multiplexed network" type faults. — [renaultforums Clio III](https://www.renaultforums.co.uk/threads/clio-iii-1-4-16v-immobiliser-issue-fixed.576082/page-2)
- French manufacturer-specific Dacia code pages exist (revue-technique-auto). Not read. — [RTA Dacia codes](https://revue-technique-auto.fr/codes-defauts-obd/38-dacia/code-specifique-constructeur?p=36)

### Inferences
- App rule: if 2 or more U-codes or "multiplex" DFs appear together, show "check battery (>12.4 V at rest, 13.8-14.5 V running), fuses (UCH/OBD fuse), grounds, aftermarket alarm/radio wiring" before any single-module advice. Severity: usually fix this week. If the ECM is lost and the car runs badly, stop.
- Generic OBD readers on Logan read mostly P-codes from the engine ECU. ABS/SRS/UCH DFs need a Renault-protocol tool (DDT4ALL, PyRen, CLIP, Carly etc). Surface this in the app.

### Gaps
- Real-world frequency data for Logan U-codes. No source found.
- **Network access needed to complete this research**: allow scribd.com (Renault MR fault-finding manuals), daciaclub.ro, mr-fix.info and GitHub (cedricp/ddt4all, py-ren ECU databases) to extract the true DF tables. The best approach is still a DDT4ALL scan of the actual car with ECU identification saved.
