package com.vital101.vital

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "com.vital101.vital/ble_service"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        startService(
                            BleForegroundService.ACTION_START,
                            call.argument("title"),
                            call.argument("message"),
                        )
                        result.success(null)
                    }
                    "update" -> {
                        startService(
                            BleForegroundService.ACTION_UPDATE,
                            call.argument("title"),
                            call.argument("message"),
                        )
                        result.success(null)
                    }
                    "stop" -> {
                        val intent = Intent(this, BleForegroundService::class.java)
                            .setAction(BleForegroundService.ACTION_STOP)
                        startService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startService(action: String, title: String?, message: String?) {
        val intent = Intent(this, BleForegroundService::class.java)
            .setAction(action)
            .putExtra(BleForegroundService.EXTRA_TITLE, title ?: "Vitals 101")
            .putExtra(
                BleForegroundService.EXTRA_MESSAGE,
                message ?: "Connected to your device",
            )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}
