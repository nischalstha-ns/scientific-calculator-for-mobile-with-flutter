package com.example.scientific_calculator

import android.app.admin.DeviceAdminReceiver

/**
 * Device-admin receiver that enables TRUE kiosk mode.
 *
 * A teacher provisions the phone once via ADB:
 *   adb shell dpm set-device-owner com.example.scientific_calculator/.AdminReceiver
 *
 * With the app as device owner, startLockTask() needs no user confirmation
 * and CANNOT be exited by any gesture or button — only the app itself can
 * call stopLockTask() (our teacher-passcode flow). That is the only way on
 * Android to make "only the app is on" literally true; the OS deliberately
 * reserves a pin-exit gesture for non-owner apps as an anti-ransomware rail.
 */
class AdminReceiver : DeviceAdminReceiver()
