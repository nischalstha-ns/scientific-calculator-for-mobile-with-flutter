package com.example.scientific_calculator

import android.Manifest
import android.app.ActivityManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.telecom.TelecomManager
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import android.view.View
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "ns_calculator/exam_lock"
    private var pendingPermResult: MethodChannel.Result? = null
    private val permRequestCode = 1401
    private var callWatch: Any? = null

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
                        try { stopLockTask() } catch (_: Exception) { }
                        try {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } catch (_: Exception) { }
                        result.success(null)
                    }
                    "setSecure" -> {
                        val secure = call.argument<Boolean>("secure") ?: false
                        try {
                            if (secure) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } catch (_: Exception) { }
                        result.success(null)
                    }
                    "setDnd" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        setDnd(on, result)
                    }
                    "openDndSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                        } catch (_: Exception) { }
                        result.success(null)
                    }
                    "setKeepScreenOn" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        try {
                            if (on) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } catch (_: Exception) { }
                        result.success(null)
                    }
                    "setImmersive" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        setImmersiveMode(on)
                        result.success(null)
                    }
                    "setCallDecline" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        setCallDecline(on, result)
                    }
                    "isPinned" -> isPinned(result)
                    else -> result.notImplemented()
                }
            }
    }

    // ── Do Not Disturb ─────────────────────────────────────────
    // Silences notifications, message sounds and alarms during the exam.
    // Needs the special "Do Not Disturb access" (granted once in Settings).
    private fun setDnd(on: Boolean, result: MethodChannel.Result) {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (!nm.isNotificationPolicyAccessGranted) {
                result.success(mapOf("ok" to false, "needsSettings" to true))
                return
            }
            nm.setInterruptionFilter(
                if (on) NotificationManager.INTERRUPTION_FILTER_NONE
                else NotificationManager.INTERRUPTION_FILTER_ALL
            )
            result.success(mapOf("ok" to true, "needsSettings" to false))
        } catch (_: Exception) {
            result.success(mapOf("ok" to false, "needsSettings" to false))
        }
    }

    // ── Auto-decline calls ─────────────────────────────────────
    // Ends incoming calls while the exam runs. Needs ANSWER_PHONE_CALLS
    // + READ_PHONE_STATE (runtime permissions, asked when enabling).
    private fun setCallDecline(on: Boolean, result: MethodChannel.Result) {
        if (!on) {
            unregisterCallWatch()
            result.success(mapOf("ok" to true))
            return
        }
        val perms = arrayOf(
            Manifest.permission.ANSWER_PHONE_CALLS,
            Manifest.permission.READ_PHONE_STATE
        )
        val missing = perms.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isNotEmpty()) {
            pendingPermResult = result
            ActivityCompat.requestPermissions(this, missing.toTypedArray(), permRequestCode)
            return
        }
        registerCallWatch()
        result.success(mapOf("ok" to true))
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permRequestCode) {
            val ok = grantResults.isNotEmpty() &&
                    grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            if (ok) registerCallWatch()
            pendingPermResult?.success(mapOf("ok" to ok))
            pendingPermResult = null
        }
    }

    private fun registerCallWatch() {
        unregisterCallWatch()
        try {
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            if (Build.VERSION.SDK_INT >= 31) {
                val cb = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                    override fun onCallStateChanged(state: Int) {
                        if (state == TelephonyManager.CALL_STATE_RINGING) endCurrentCall()
                    }
                }
                tm.registerTelephonyCallback(mainExecutor, cb)
                callWatch = cb
            } else {
                @Suppress("DEPRECATION")
                val listener = object : PhoneStateListener() {
                    @Suppress("DEPRECATION")
                    override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                        if (state == TelephonyManager.CALL_STATE_RINGING) endCurrentCall()
                    }
                }
                @Suppress("DEPRECATION")
                tm.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
                callWatch = listener
            }
        } catch (_: Exception) { }
    }

    private fun endCurrentCall() {
        try {
            val telecom = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            telecom.endCall()
        } catch (_: Exception) { }
    }

    private fun unregisterCallWatch() {
        try {
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            val w = callWatch ?: return
            if (Build.VERSION.SDK_INT >= 31 && w is TelephonyCallback) {
                tm.unregisterTelephonyCallback(w)
            } else {
                @Suppress("DEPRECATION")
                tm.listen(w as PhoneStateListener, PhoneStateListener.LISTEN_NONE)
            }
        } catch (_: Exception) { } finally {
            callWatch = null
        }
    }

    // ── Immersive fullscreen ───────────────────────────────────
    private fun setImmersiveMode(on: Boolean) {
        try {
            if (Build.VERSION.SDK_INT >= 30) {
                window.insetsController?.let {
                    val types = android.view.WindowInsets.Type.statusBars() or
                            android.view.WindowInsets.Type.navigationBars()
                    if (on) {
                        it.hide(types)
                        it.systemBarsBehavior =
                            android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                    } else {
                        it.show(types)
                    }
                }
            } else {
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = if (on) {
                    (View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                            or View.SYSTEM_UI_FLAG_FULLSCREEN
                            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                            or View.SYSTEM_UI_FLAG_LAYOUT_STABLE)
                } else {
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                }
            }
        } catch (_: Exception) { }
    }

    // ── Pin state ──────────────────────────────────────────────
    private fun isPinned(result: MethodChannel.Result) {
        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            result.success(am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE)
        } catch (_: Exception) {
            result.success(false)
        }
    }
}
