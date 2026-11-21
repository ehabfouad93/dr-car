package com.logandoctor.logan_doctor

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothSocket
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.UUID
import kotlin.concurrent.thread

/**
 * Minimal ELM327 link over classic Bluetooth (SPP) or BLE (UART-style GATT).
 * Permissions are requested on the Dart side before any call here.
 */
@SuppressLint("MissingPermission")
class ObdBluetooth(private val ctx: Context) {
    var sink: EventChannel.EventSink? = null

    private val main = Handler(Looper.getMainLooper())
    private val adapter: BluetoothAdapter? =
        (ctx.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter

    private var socket: BluetoothSocket? = null
    private var gatt: BluetoothGatt? = null
    private var bleWrite: BluetoothGattCharacteristic? = null

    private fun emit(bytes: ByteArray) = main.post { sink?.success(bytes) }
    private fun emitClosed() = main.post { sink?.error("closed", "link lost", null) }

    // ---------- Discovery ----------

    fun bondedDevices(): List<Map<String, String>> =
        adapter?.bondedDevices?.map {
            mapOf("name" to (it.name ?: "?"), "address" to it.address, "type" to "classic")
        } ?: emptyList()

    fun scanBle(ms: Int, done: (List<Map<String, String>>) -> Unit) {
        val scanner = adapter?.bluetoothLeScanner ?: return done(emptyList())
        val found = LinkedHashMap<String, Map<String, String>>()
        val cb = object : ScanCallback() {
            override fun onScanResult(type: Int, r: ScanResult) {
                val name = r.device.name ?: r.scanRecord?.deviceName ?: return
                found[r.device.address] = mapOf("name" to name, "address" to r.device.address, "type" to "ble")
            }
        }
        scanner.startScan(cb)
        main.postDelayed({
            try { scanner.stopScan(cb) } catch (_: Exception) {}
            done(found.values.toList())
        }, ms.toLong())
    }

    // ---------- Classic SPP (most cheap ELM327 readers) ----------

    fun connectClassic(address: String, done: (String?) -> Unit) {
        close()
        val dev = adapter?.getRemoteDevice(address) ?: return done("no adapter")
        thread {
            try {
                adapter.cancelDiscovery()
                val s = connectSpp(dev)
                socket = s
                main.post { done(null) }
                val input = s.inputStream
                val buf = ByteArray(512)
                while (true) {
                    val n = input.read(buf)
                    if (n < 0) break
                    if (n > 0) emit(buf.copyOf(n))
                }
            } catch (e: Exception) {
                if (socket == null) main.post { done(e.message ?: "connect failed") }
            }
            if (socket != null) emitClosed()
        }
    }

    /** Some clones only accept the insecure socket or the reflection fallback. */
    private fun connectSpp(dev: BluetoothDevice): BluetoothSocket {
        val errors = mutableListOf<String>()
        val attempts = listOf<() -> BluetoothSocket>(
            { dev.createRfcommSocketToServiceRecord(SPP) },
            { dev.createInsecureRfcommSocketToServiceRecord(SPP) },
            {
                dev.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                    .invoke(dev, 1) as BluetoothSocket
            },
        )
        for (make in attempts) {
            try {
                val s = make()
                s.connect()
                return s
            } catch (e: Exception) {
                errors.add(e.message ?: e.javaClass.simpleName)
            }
        }
        throw IllegalStateException(errors.joinToString(" / "))
    }

    // ---------- BLE (Vgate iCar Pro BLE, OBDLink CX, FFF0/FFE0 clones) ----------

    fun connectBle(address: String, done: (String?) -> Unit) {
        close()
        val dev = adapter?.getRemoteDevice(address) ?: return done("no adapter")
        var reported = false
        fun report(err: String?) { if (!reported) { reported = true; main.post { done(err) } } }

        val cb = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(g: BluetoothGatt, status: Int, state: Int) {
                if (state == BluetoothProfile.STATE_CONNECTED) {
                    g.requestMtu(247)
                } else if (state == BluetoothProfile.STATE_DISCONNECTED) {
                    if (!reported) report("BLE connect failed ($status)") else emitClosed()
                    g.close()
                }
            }

            override fun onMtuChanged(g: BluetoothGatt, mtu: Int, status: Int) { g.discoverServices() }

            override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
                val chars = g.services.flatMap { it.characteristics }
                val notify = chars.firstOrNull { it.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0 }
                val write = chars.firstOrNull {
                    it.properties and (BluetoothGattCharacteristic.PROPERTY_WRITE or
                        BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0 &&
                        !it.uuid.toString().startsWith("00002a")
                }
                if (notify == null || write == null) { report("not an OBD reader"); g.disconnect(); return }
                bleWrite = write
                g.setCharacteristicNotification(notify, true)
                notify.getDescriptor(CCCD)?.let { d ->
                    if (Build.VERSION.SDK_INT >= 33) {
                        g.writeDescriptor(d, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
                    } else {
                        @Suppress("DEPRECATION")
                        d.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        @Suppress("DEPRECATION")
                        g.writeDescriptor(d)
                    }
                }
                report(null)
            }

            @Deprecated("pre-33")
            override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic) {
                @Suppress("DEPRECATION")
                c.value?.let { emit(it) }
            }

            override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray) {
                emit(value)
            }
        }
        gatt = dev.connectGatt(ctx, false, cb, BluetoothDevice.TRANSPORT_LE)
    }

    // ---------- I/O ----------

    fun write(data: ByteArray) {
        socket?.let { s -> thread { try { s.outputStream.write(data); s.outputStream.flush() } catch (_: Exception) { emitClosed() } }; return }
        val g = gatt ?: return
        val c = bleWrite ?: return
        // ELM commands are short; chunk to 20 bytes for old BLE stacks.
        data.toList().chunked(20).forEach { part ->
            val bytes = part.toByteArray()
            val type = if (c.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0)
                BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE else BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            if (Build.VERSION.SDK_INT >= 33) {
                g.writeCharacteristic(c, bytes, type)
            } else {
                @Suppress("DEPRECATION")
                c.value = bytes
                c.writeType = type
                @Suppress("DEPRECATION")
                g.writeCharacteristic(c)
            }
        }
    }

    fun close() {
        try { socket?.close() } catch (_: Exception) {}
        socket = null
        try { gatt?.disconnect(); gatt?.close() } catch (_: Exception) {}
        gatt = null
        bleWrite = null
    }

    companion object {
        val SPP: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        val CCCD: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }
}
