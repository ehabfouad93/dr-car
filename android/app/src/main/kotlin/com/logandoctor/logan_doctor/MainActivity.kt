package com.logandoctor.logan_doctor

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Wires the Dart side to our own Bluetooth + notification code.
 *   method channel  "logan/bt"      : list, connect, write, close, notify, startService, stopService
 *   event channel   "logan/bt/data" : bytes from the reader
 */
class MainActivity : FlutterActivity() {
    private lateinit var bt: ObdBluetooth

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        bt = ObdBluetooth(applicationContext)

        EventChannel(messenger, "logan/bt/data").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) { bt.sink = sink }
            override fun onCancel(args: Any?) { bt.sink = null }
        })

        MethodChannel(messenger, "logan/bt").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "bonded" -> result.success(bt.bondedDevices())
                    "scanBle" -> bt.scanBle(call.argument<Int>("ms") ?: 6000) { result.success(it) }
                    "connectClassic" -> bt.connectClassic(call.argument<String>("address")!!) { err ->
                        if (err == null) result.success(true) else result.error("connect", err, null)
                    }
                    "connectBle" -> bt.connectBle(call.argument<String>("address")!!) { err ->
                        if (err == null) result.success(true) else result.error("connect", err, null)
                    }
                    "write" -> { bt.write(call.argument<ByteArray>("data")!!); result.success(null) }
                    "close" -> { bt.close(); result.success(null) }
                    "notify" -> {
                        Notifier.alert(
                            applicationContext,
                            call.argument<Int>("id") ?: 1,
                            call.argument<String>("title") ?: "",
                            call.argument<String>("body") ?: "",
                        )
                        result.success(null)
                    }
                    "startService" -> { MonitorService.start(applicationContext); result.success(null) }
                    "stopService" -> { MonitorService.stop(applicationContext); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("bt", e.message, null)
            }
        }
    }

    override fun onDestroy() {
        bt.close()
        MonitorService.stop(applicationContext)
        super.onDestroy()
    }
}
