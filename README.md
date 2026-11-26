# NS Scientific Calculator

A full-featured **scientific calculator for Android** (Flutter) with a real **Exam Mode** — a lockdown that keeps the phone inside the calculator for the duration of an exam.

**Latest release: v1.4.5** — [Download the APK](https://github.com/nischalstha-ns/scientific-calculator-for-mobile-with-flutter/releases/download/v1.4.5/ns-calculator-v1.4.5.apk)

## ✨ Features

- **Real scientific calculator** — `+ − × ÷`, brackets, decimals, `x^y`, `x²`, `√`, `sin/cos/tan` (degrees), `π`, `e`, `Ans`, factorial, random numbers, division-by-zero handling, auto-closing brackets, STAT mode, history & replay
- **Exam Mode (true lockdown)** — once started, the phone stays in the calculator: back button, app switching and the swipe-up unpin gesture are all blocked
- **5-strike tamper system** — back-press, leaving the app, or a wrong passcode each count as a strike (shown as ⚠n/5); the 5th strike triggers a full red hard-lockdown that only the teacher passcode can open
- **Secure passcode** — salted-hash passcode (never stored in plain text); exam state and tamper log survive the app being killed
- **Lock-screen brute-force protection** — the lock screen shows how many passcode attempts are left; 3 wrong codes engage a cooldown (30s, escalating to 60s → 120s → 300s) with a live countdown — and killing the app does not reset it
- **Exam timer** — pick 15 / 30 / 60 / 120 / 180 / 240 minutes or any custom length (up to 24 h); Settings shows the live time left, the exam auto-ends when time expires — even if the app was closed in between
- **True Kiosk (device owner)** — with one-time device-owner provisioning, pinning engages instantly with no dialog and no unpin gesture
- **Extras** — dark mode, physical-feel key click sounds (with mute), responsive layout

## 📱 Install

1. Download the APK from the [latest release](https://github.com/nischalstha-ns/scientific-calculator-for-mobile-with-flutter/releases/tag/v1.4.5).
2. Tap it on your phone and allow installs from this source.

## 🔒 Exam Mode — True Kiosk setup (one time)

Exam Mode works best as a device owner. On the exam phone:

1. Remove all accounts from the phone first (Android refuses a device owner while accounts exist — including the Mi account). Verify with `adb shell dumpsys account` (should print nothing) and `adb shell pm list users` (only Owner should show).
2. On MIUI, enable **USB debugging (Security setting)**.
3. Run: `adb shell dpm set-device-owner com.example.scientific_calculator/.AdminReceiver`
4. Accounts can be re-added right after provisioning succeeds.

Without device-owner provisioning, exam mode still runs with ordinary screen pinning, but Android reserves the swipe-up-and-hold unpin gesture — only True Kiosk removes it fully.

## 🛠️ Build from source

```bash
flutter pub get
flutter build apk --release
```

## 🧩 Tech

Flutter · Dart · `math_expressions` (calculation engine) · `shared_preferences` (persisted exam state) · `audioplayers` (key sounds)

## 📄 License

MIT
