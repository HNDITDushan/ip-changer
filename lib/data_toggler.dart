import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_settings.dart';

/// Thrown when mobile data could not be cycled; [message] is shown to the user.
class ToggleException implements Exception {
  ToggleException(this.message);
  final String message;
}

const _channel = MethodChannel('ip_changer/data_toggle');

/// Android: whether the accessibility service is switched on.
Future<bool> isAndroidServiceEnabled() async =>
    await _channel.invokeMethod<bool>('isServiceEnabled') ?? false;

Future<void> openAccessibilitySettings() =>
    _channel.invokeMethod<void>('openAccessibilitySettings');

/// Android: turns mobile data off, waits, turns it back on. Completes when data is on again.
Future<void> cycleMobileDataAndroid(AppSettings settings) async {
  try {
    await _channel.invokeMethod<void>('toggle', {
      'waitSeconds': settings.waitSeconds,
      'screen': settings.androidScreen,
      'customLabel': settings.customLabel,
    });
  } on PlatformException catch (e) {
    throw ToggleException(_androidError(e.code));
  }
}

String _androidError(String code) {
  const dataOff = ' Mobile data may still be off - turn it on by hand.';
  switch (code) {
    case 'service_disabled':
      return 'Turn on the IP Changer accessibility service first.';
    case 'busy':
      return 'A change is already running.';
    case 'screen_unavailable':
      return 'This phone cannot open that settings screen. Pick another one in Settings.';
    case 'toggle_not_found':
      return 'Could not find the mobile data switch. Try another screen or set the '
          'switch label in Settings.';
    case 'toggle_no_effect':
      return 'Tapped the mobile data switch but data stayed on.';
    case 'toggle_not_found_data_off':
      return 'Could not find the mobile data switch to turn data back on.$dataOff';
    case 'toggle_no_effect_data_off':
      return 'Tapped the mobile data switch but data did not come back.$dataOff';
    default:
      return 'Could not switch mobile data ($code).';
  }
}

/// iOS: hands over to the Shortcuts app, which is the only thing allowed to
/// switch mobile data. Shortcuts returns to this app when the shortcut ends.
Future<void> runIosShortcut(String shortcutName) async {
  // Built by hand: Uri(queryParameters:) writes spaces as '+', which Shortcuts
  // does not read as a space in the shortcut name.
  final uri = Uri.parse(
    'shortcuts://x-callback-url/run-shortcut'
    '?name=${Uri.encodeComponent(shortcutName)}'
    '&x-success=${Uri.encodeComponent('ipchanger://done')}'
    '&x-cancel=${Uri.encodeComponent('ipchanger://cancel')}'
    '&x-error=${Uri.encodeComponent('ipchanger://error')}',
  );
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched) {
    throw ToggleException('Could not open the Shortcuts app.');
  }
}

bool get isAndroid => Platform.isAndroid;
bool get isIos => Platform.isIOS;
