# دكتور اللوجان — Logan Doctor

Arabic-first Android OBD app built only for the **Renault Logan 2015 (Logan II / X52), K7M 1.6 8v petrol, manual JH3**.
It talks to a cheap ELM327 reader (classic Bluetooth, BLE, or Wi-Fi).

## What works in this version

| Tab | What it does |
|---|---|
| التوصيل (Connect) | Pick a paired reader, BLE scan, or Wi-Fi / laptop emulator. Tests the reader on first connect and says if it is a weak v2.1 clone. |
| الفحص (Scan) | Stored / pending / permanent engine codes, freeze frame, Check Engine state, which modules answered. Every code has an Arabic name, severity (آمن تسوق / صلّح خلال أسبوع / وقّف العربية), Logan-specific causes, cheap checks, fix steps, parts and the Renault DF number. "Clear" sits far from "Rescan", needs two confirms, saves the scan first and is blocked if the car moves. |
| القراءات (Live) | Big numeric coolant temperature (the Logan cluster has no gauge), battery volts, RPM, speed, throttle, MAP, IAT, fuel trims, O2 sensors, timing. |
| Alerts | Coolant > 105 °C, charging < 13.2 V with engine running (3 readings in a row), new fault, Check Engine on, reader left plugged in with engine off. They keep running with the screen off (Android foreground service). |
| الكمبيوترات (All modules) | Scans every Logan II computer on the CAN bus: engine 7E0/7E8, ABS 740/760, airbag 752/772, UCH 745/765, cluster 743/763, plus optional ones. Reads and clears each module's faults. With a definition file loaded: **reads every sensor** and runs **control tests** (cooling fan on/off, fuel pump, purge valve, cluster…). |
| السجل (History) | Every scan saved locally (SQLite). |
| AI explain | One tap per code → Claude explains it in Egyptian Arabic with the full scan, freeze frame, live data and the owner's notes. The key stays on the server. |

### Control tests — safety rules built in
* Car must be stopped (speed read from the engine ECU = 0); engine-ECU tests also need the engine off (ignition on).
* Every test stops by itself after 2–30 s and always sends "return control to ECU", even if the link drops.
* Brakes (ABS), airbag and power steering: **no control at all**.
* Airbag faults are not cleared while a "crash stored / computer" code is present.
* Never sent, whatever the file or UI says: security access (27), flashing (34–37, 3D), config/VIN writes (2E, 3B), routines (31), comm control (28, 85). Enforced in two places: the request classifier and the low-level ELM driver.

## Desktop app (Windows / Linux / macOS)

Same code base and the same safety rules as the phone app, laid out as a workbench for checking and developing:

| Page | What it does |
|---|---|
| التوصيل (Connect) | Pick the serial port + baud rate. A paired Bluetooth ELM327 shows up as a COM port on Windows ("Standard Serial over Bluetooth link"), `/dev/rfcomm0` on Linux. USB cables and Wi-Fi readers / the emulator also work. |
| قايمة التأكيد (Checklist) | The 20 "confirm on the real car" items from the research report. Automatic tests for platform, all modules (500 and 250 kbps), ECU identities, fault-code service, supported PIDs and reader capability. A fan-temperature logger and a CNG fuel-trim logger. Fields for the manual checks (ohmmeter, fuel pressure, cluster menu…). Results are saved and exported as a Markdown report. |
| فحص الموتور / العدادات | Same engine scan, fault guide and gauges as the phone app. |
| رسم بياني (Chart) | Live chart of any PID + CSV recording for analysis. |
| الكمبيوترات والتحكم | Every Logan II computer: faults, clear, all sensors and control tests (fan on/off…) from imported DDT4ALL definition files. |
| كونسول المطور (Console) | Send raw commands to the reader, the engine or any module (the length byte is added for you). Shows every byte sent and received; the log can be saved. Commands that flash ECUs, unlock security access or write configuration/VIN stay blocked here too. |

Saved files (checklist, exports, logs, ECU definitions) go to `Documents/LoganDoctor`.

Run it from source:

```bash
flutter run -d windows
```

Ready-made builds: push this folder to a GitHub repository. `.github/workflows/build.yml` then builds the Windows app, the Linux app and the Android APK on every push (download them from the run's *Artifacts*).

Developer shortcuts (environment variables): `LOGAN_CONNECT=127.0.0.1:35000` auto-connects, `LOGAN_TAB=n` opens a page, `LOGAN_PROBES=1` runs the automatic checks, `LOGAN_LIVE=1` starts live data.

Screenshots (desktop app connected to the ELM327-emulator): `docs/screenshots/`.

Desktop limits: classic Bluetooth only (through the COM port); BLE readers are not supported on desktop yet. Phone alerts (notifications) are Android-only; the desktop shows alerts inside the app.

## DDT4ALL integration
* The module addresses and the scan sequence (`ATCAF0`, `ATFCSH…`, `10C0` session, `2180` ident, `17FF00` / `1902AF` faults, `14FF00` clear) match DDT4ALL and pyren.
* The app reads **DDT4ALL-format JSON ECU files** (requests + data items, both endiannesses, scaled values, lists). In the module screen press **"حمّل ملف تعريف"** and pick the JSON for that computer.
* The ECU definition files are **not shipped** with the app. They come from Renault's DDT2000 database, so the owner imports their own. Easiest way to find which file fits the car: plug in once with DDT4ALL on a laptop and note each computer's detected name.
* No DDT4ALL code is used (it is GPL-3). The reader in `lib/obd/ddt.dart` is our own implementation of the file format.

## Build

```bash
flutter pub get
```

```bash
flutter test
```

The end-to-end test (`test/emulator_test.dart`) runs automatically when the ELM327-emulator is listening on port 35000 (`elm -n 35000 -s car`), otherwise it is skipped.

```bash
flutter build apk --release --dart-define=SUPABASE_URL=https://YOUR.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Needs the Flutter SDK (tested with 3.50.1) and the Android SDK. The APK could not be built in the cloud session that wrote this code, because Google's Android SDK download site was blocked there. Build it on your PC with Android Studio installed.

### AI backend (Supabase)

```bash
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
```

```bash
supabase functions deploy explain-code
```

### Test without a car
Install the free ELM327 emulator on a laptop and run it on TCP port 35000:

```bash
pip install ELM327-emulator
```

```bash
elm -n 35000
```

In the app: Connect → "قارئ Wi-Fi أو محاكي على اللابتوب" → `LAPTOP_IP:35000` (phone and laptop on the same Wi-Fi).

## Fault guide
`assets/logan_dtc.json` is generated by `tools/build_dtc_db.py` (edit the table there, then run `python3 tools/build_dtc_db.py`).
72 engine codes with Logan-specific text. Unknown codes fall back to an Arabic family description, so no code shows "no description".

## Open points — confirm on the real car
The deep research is in `reports/Renault Logan 2015 diagnostics.md`. Many sites were blocked during research, so these still need checking on a real Logan:
1. Which engine ECU it is (EMS3120 / EMS3132 / SIM32): read the `2180` reply in the modules screen.
2. Which Mode 01 values it supports (the app asks the car, but log the list).
3. Fan switch-on temperatures, warm idle RPM and MAP.
4. DF numbers marked "محتاج تأكيد" (injectors DF040–043 vs DF026/DF052).
5. Real reply format of each module (KWP `17FF00` vs UDS `1902AF`).
6. Test with both a v1.5 (PIC18F25K80) and a v2.1 reader.

## Licences
* Bluetooth is our own Kotlin code (`android/.../ObdBluetooth.kt`). `flutter_blue_plus` needs a paid licence for for-profit apps and `flutter_blue_classic` is GPL-3, so neither is used.
* Other packages (provider, sqflite, http, permission_handler, shared_preferences, file_picker, path_provider, flutter_libserialport) are MIT/BSD.
* The desktop serial port uses libserialport, which is LGPL-3. It is loaded as a separate shared library, which LGPL allows in a closed-source app; keep it as a separate file and include its licence when you distribute.
