package com.example.scientific_calculator

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "ns_calculator/exam_lock"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startLock" -> {
                        // Screen pinning: blocks Home / Recents / app switching
                        // until stopLockTask(). Without device-owner rights the
                        // system asks the user to confirm once.
                        val pinned = try {
                            startLockTask()
                            true
                        } catch (_: Exception) {
                            false
                        }
                        try {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } catch (_: Exception) { }
                        result.success(pinned)
                    }
                    "stopLock" -> {
                        try {
                            stopLockTask()
                        } catch (_: Exception) { }
                        try {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } catch (_: Exception) { }
                        result.success(null)
                    }
                    "setSecure" -> {
                        val secure = call.argument<Boolean>("secure") ?: false
                        try {
                            if (secure) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                        } catch (_: Exception) { }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
