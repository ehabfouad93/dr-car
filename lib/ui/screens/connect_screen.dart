import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../obd/bt_transport.dart';
import '../../obd/elm327.dart';
import '../../obd/transport.dart';
import '../../services/app_state.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  List<BtDevice> devices = [];
  bool loading = false;
  final hostCtrl = TextEditingController(text: '192.168.0.10:35000');

  Future<bool> _permissions() async {
    final res = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse, // only used by Android 11 and older
      Permission.notification,
    ].request();
    return res[Permission.bluetoothConnect]?.isGranted != false;
  }

  Future<void> _load({bool ble = false}) async {
    setState(() => loading = true);
    try {
      if (!await _permissions()) return;
      final list = ble ? await NativeBt.scanBle() : await NativeBt.bonded();
      list.sort((a, b) => (b.looksLikeObd ? 1 : 0) - (a.looksLikeObd ? 1 : 0));
      setState(() => devices = ble ? [...devices.where((d) => !d.ble), ...list] : list);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('البلوتوث مش شغال: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _status(app),
      const SizedBox(height: 12),
      Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('1. ركّب القارئ في فيشة OBD تحت الدركسيون على الشمال.\n'
              '2. دوّر الكونتاكت (أو شغّل الموتور).\n'
              '3. اعمل Pair للقارئ من إعدادات البلوتوث في الموبايل (الباسورد غالبًا 1234 أو 0000).\n'
              '4. اختار القارئ من تحت.'),
        ),
      ),
      Row(children: [
        Text('القارئات', style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        TextButton.icon(onPressed: loading ? null : () => _load(), icon: const Icon(Icons.refresh), label: const Text('تحديث')),
        TextButton.icon(
            onPressed: loading ? null : () => _load(ble: true),
            icon: const Icon(Icons.bluetooth_searching),
            label: const Text('بحث BLE')),
      ]),
      if (loading) const LinearProgressIndicator(),
      if (!loading && devices.isEmpty)
        const Padding(padding: EdgeInsets.all(16), child: Text('مفيش أجهزة. اعمل Pair للقارئ الأول من إعدادات البلوتوث.')),
      for (final d in devices)
        Card(
          child: ListTile(
            leading: Icon(d.ble ? Icons.bluetooth_connected : Icons.bluetooth, color: d.looksLikeObd ? Colors.blue : null),
            title: Text(d.name),
            subtitle: Text('${d.address}  ${d.ble ? 'BLE' : 'Bluetooth عادي'}${d.looksLikeObd ? '  • غالبًا قارئ OBD' : ''}'),
            trailing: const Icon(Icons.chevron_left),
            onTap: app.busy ? null : () => app.connect(() => BluetoothTransport.connect(d)),
          ),
        ),
      ExpansionTile(
        title: const Text('قارئ Wi-Fi أو محاكي على اللابتوب'),
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(child: TextField(controller: hostCtrl, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'IP:Port'))),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: app.busy
                    ? null
                    : () {
                        final parts = hostCtrl.text.trim().split(':');
                        app.connect(() => TcpTransport.connect(parts[0], int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 35000));
                      },
                child: const Text('وصّل'),
              ),
            ]),
          ),
        ],
      ),
    ]);
  }

  Widget _status(AppState app) {
    final (color, icon, text) = switch (app.link) {
      LinkState.connected => (Colors.green, Icons.check_circle, 'متوصل: ${app.linkLabel}'),
      LinkState.connecting => (Colors.orange, Icons.hourglass_top, app.busyAr),
      LinkState.disconnected => (Colors.grey, Icons.link_off, 'مش متوصل'),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold))),
            if (app.link == LinkState.connected) TextButton(onPressed: app.disconnect, child: const Text('افصل')),
          ]),
          if (app.reader != null) ...[
            const SizedBox(height: 8),
            Text(app.reader!.messageAr,
                style: TextStyle(color: app.reader!.level == ReaderLevel.full ? Colors.green.shade800 : Colors.orange.shade900)),
          ],
          if (app.errorAr != null) ...[
            const SizedBox(height: 8),
            Text(app.errorAr!, style: const TextStyle(color: Colors.red)),
          ],
        ]),
      ),
    );
  }
}
