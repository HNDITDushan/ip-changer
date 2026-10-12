import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One completed change attempt.
class IpChange {
  IpChange({required this.time, required this.previousIp, required this.newIp});

  final DateTime time;
  final String? previousIp;
  final String? newIp;

  bool get changed => newIp != null && newIp != previousIp;

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'previousIp': previousIp,
    'newIp': newIp,
  };

  factory IpChange.fromJson(Map<String, dynamic> json) => IpChange(
    time: DateTime.parse(json['time'] as String),
    previousIp: json['previousIp'] as String?,
    newIp: json['newIp'] as String?,
  );
}

/// User settings and change history, persisted on the device.
class AppSettings {
  AppSettings._(this._prefs);

  static const _maxHistory = 50;

  final SharedPreferences _prefs;

  static Future<AppSettings> load() async =>
      AppSettings._(await SharedPreferences.getInstance());

  /// Seconds mobile data stays off (Android).
  int get waitSeconds => _prefs.getInt('waitSeconds') ?? 5;
  set waitSeconds(int value) => _prefs.setInt('waitSeconds', value);

  /// Which system screen the Android service uses: panel, data_usage or mobile_network.
  String get androidScreen => _prefs.getString('androidScreen') ?? 'panel';
  set androidScreen(String value) => _prefs.setString('androidScreen', value);

  /// Extra label for the mobile data switch, for phones not set to English.
  String get customLabel => _prefs.getString('customLabel') ?? '';
  set customLabel(String value) => _prefs.setString('customLabel', value);

  /// Name of the shortcut the iOS app runs.
  String get shortcutName => _prefs.getString('shortcutName') ?? 'Change IP';
  set shortcutName(String value) => _prefs.setString('shortcutName', value);

  List<IpChange> get history => (_prefs.getStringList('history') ?? [])
      .map((e) => IpChange.fromJson(jsonDecode(e) as Map<String, dynamic>))
      .toList();

  void addHistory(IpChange change) {
    final entries = [change, ...history].take(_maxHistory);
    _prefs.setStringList(
      'history',
      entries.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  void clearHistory() => _prefs.remove('history');
}
