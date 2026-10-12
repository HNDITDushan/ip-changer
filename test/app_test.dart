import 'package:flutter_test/flutter_test.dart';
import 'package:ip_changer/app_settings.dart';
import 'package:ip_changer/ip_service.dart';

void main() {
  test('parseIp accepts addresses and rejects other text', () {
    expect(parseIp('203.0.113.7\n'), '203.0.113.7');
    expect(parseIp('2001:db8::1'), '2001:db8::1');
    expect(parseIp('<html>error</html>'), isNull);
  });

  test('IpChange survives a JSON round trip and reports changes', () {
    final change = IpChange(
      time: DateTime(2026, 10, 12, 9, 30),
      previousIp: '203.0.113.7',
      newIp: '203.0.113.99',
    );
    final copy = IpChange.fromJson(change.toJson());
    expect(copy.previousIp, '203.0.113.7');
    expect(copy.newIp, '203.0.113.99');
    expect(copy.changed, isTrue);
    expect(
      IpChange(time: DateTime(2026), previousIp: 'a', newIp: 'a').changed,
      isFalse,
    );
    expect(
      IpChange(time: DateTime(2026), previousIp: 'a', newIp: null).changed,
      isFalse,
    );
  });
}
