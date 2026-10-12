# IP Changer

Changes your mobile data IP by switching mobile data off, waiting a few seconds, and switching it back on. Shows the previous IP and the new IP, and keeps a history.

It only works if your carrier hands out a new IP on reconnect, and Wi-Fi must be off (otherwise you see your Wi-Fi IP).

## How it works

- **Android:** apps are not allowed to switch mobile data directly, so an accessibility service opens the system Internet panel and taps the mobile data switch for you.
- **iPhone:** apps cannot switch mobile data at all, so the app runs a shortcut in Apple's Shortcuts app that does it, then returns to the app.

## One-time setup on the Mac

Flutter is installed at `/Volumes/PortableSSD/dev/flutter`. Add it to your PATH:

```bash
echo 'export PATH="/Volumes/PortableSSD/dev/flutter/bin:$PATH"' >> ~/.zshrc
```

Then install:

- **Android Studio** (for the Android app), and accept the SDK licences with `flutter doctor --android-licenses`.
- **Xcode** from the App Store plus CocoaPods (`brew install cocoapods`) (for the iPhone app).

`flutter doctor` tells you what is still missing.

## Run on Android

1. On the phone, enable Developer options and USB debugging, then connect it by USB.
2. Run `flutter run --release` in this folder.
3. In the app, tap **Open settings** and turn on the **IP Changer** accessibility service.
4. Turn Wi-Fi off and tap **Change IP**.

If you install the APK by copying the file instead of `flutter run`, Android 13+ blocks the accessibility service at first: open App info for IP Changer, tap the three-dot menu, and choose **Allow restricted settings**.

If the app cannot find the mobile data switch, open the app's Settings and try another screen, or type the switch label as your phone shows it (needed when the phone is not in English).

## Run on iPhone

1. Open `ios/Runner.xcworkspace` in Xcode, select the Runner target, and choose your Apple ID under Signing & Capabilities.
2. Connect the iPhone and run `flutter run --release`.
3. In the app, tap **How to set up** and create the "Change IP" shortcut (Mobile Data off, Wait 5 seconds, Mobile Data on).
4. Turn Wi-Fi off and tap **Change IP**.

With a free Apple ID the app must be reinstalled every 7 days.

## Code map

- `lib/home_page.dart`: main screen and the change flow.
- `lib/data_toggler.dart`: Android method channel and iOS shortcut launch.
- `lib/ip_service.dart`: public IP lookup.
- `android/app/src/main/kotlin/com/ipchanger/ip_changer/DataToggleService.kt`: the accessibility service.
