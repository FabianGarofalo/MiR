import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/mir/mir_wake_on_lan.dart';

void main() {
  group('MiR Wake-on-LAN', () {
    test('normaliza MAC con separadores habituales', () {
      expect(
        MiRMagicPacket.normalizeMac('00-11-22-33-44-55'),
        '00:11:22:33:44:55',
      );
      expect(
        MiRMagicPacket.normalizeMac('0011.2233.4455'),
        '00:11:22:33:44:55',
      );
    });

    test('genera magic packet estándar de 102 bytes', () {
      final packet = MiRMagicPacket.create('00:11:22:33:44:55');
      expect(packet.length, 102);
      expect(packet.sublist(0, 6), [255, 255, 255, 255, 255, 255]);
      final mac = [0, 17, 34, 51, 68, 85];
      for (var i = 0; i < 16; i++) {
        expect(packet.sublist(6 + i * 6, 12 + i * 6), mac);
      }
    });

    test('rechaza MAC truncada, sin hex y con dirección multicast', () {
      for (final invalid in [
        '',
        '00:11:22',
        '00:11:22:33:44:GG',
        '00:00:00:00:00:00',
        'FF:FF:FF:FF:FF:FF',
        '01:00:5E:00:00:01',
        '00:11:22:33:44:55invalido',
      ]) {
        expect(() => MiRMagicPacket.create(invalid), throwsFormatException,
            reason: 'MAC invalidada: ' + invalid);
      }
    });
  });
}
