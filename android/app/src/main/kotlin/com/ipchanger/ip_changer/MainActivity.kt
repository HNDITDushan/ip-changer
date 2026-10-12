package com.ipchanger.ip_changer

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ip_changer/data_toggle")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isServiceEnabled" -> result.success(DataToggleService.instance != null)
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "isMobileDataEnabled" ->
                        result.success(DataToggleService.isMobileDataEnabled(this))
                    "toggle" -> {
                        val service = DataToggleService.instance
                        if (service == null) {
                            result.error("service_disabled", null, null)
                        } else {
                            service.start(
                                call.argument<Int>("waitSeconds") ?: 5,
                                call.argument<String>("screen") ?: "panel",
                                call.argument<String>("customLabel"),
                            ) { error ->
                                if (error == null) {
                                    result.success(null)
                                } else {
                                    result.error(error, null, null)
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
