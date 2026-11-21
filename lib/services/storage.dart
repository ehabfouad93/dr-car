import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Folder for app files. Some desktops have no "Documents" folder
/// configured, so fall back to the app-support folder, then temp.
Future<Directory> appDataDir([String sub = '']) async {
  Directory base;
  try {
    base = await getApplicationDocumentsDirectory();
  } catch (_) {
    try {
      base = await getApplicationSupportDirectory();
    } catch (_) {
      base = Directory.systemTemp;
    }
  }
  final d = Directory(sub.isEmpty ? base.path : '${base.path}/$sub');
  if (!d.existsSync()) d.createSync(recursive: true);
  return d;
}
