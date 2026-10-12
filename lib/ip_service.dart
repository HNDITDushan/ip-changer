import 'dart:io';

import 'package:http/http.dart' as http;

/// Plain-text "what is my IP" endpoints, tried in order.
const _endpoints = [
  'https://api.ipify.org',
  'https://icanhazip.com',
  'https://ifconfig.me/ip',
];

/// Returns [body] as an IP address, or null if it is not one.
String? parseIp(String body) {
  final text = body.trim();
  return InternetAddress.tryParse(text) == null ? null : text;
}

/// The public IP as websites see it, or null when offline.
Future<String?> fetchPublicIp({
  Duration timeout = const Duration(seconds: 4),
}) async {
  for (final url in _endpoints) {
    try {
      final response = await http.get(Uri.parse(url)).timeout(timeout);
      if (response.statusCode == 200) {
        final ip = parseIp(response.body);
        if (ip != null) return ip;
      }
    } catch (_) {
      // Offline or endpoint down; try the next one.
    }
  }
  return null;
}

/// Polls until the connection is back, giving up after [maxWait].
Future<String?> waitForPublicIp({
  Duration maxWait = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(maxWait);
  while (DateTime.now().isBefore(deadline)) {
    final ip = await fetchPublicIp();
    if (ip != null) return ip;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return null;
}
