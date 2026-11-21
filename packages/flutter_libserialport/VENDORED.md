# Vendored copy of flutter_libserialport 0.6.0 (MIT)

Source: https://pub.dev/packages/flutter_libserialport

Changed only one thing: the Android platform was removed. The phone app
talks Bluetooth through its own Kotlin code and never uses a serial port,
and the package's old Android build file (jcenter) breaks current Android
builds. Desktop platforms (Windows, Linux, macOS) are unchanged.
The bundled libserialport C library stays LGPL-3 (see third_party/).
