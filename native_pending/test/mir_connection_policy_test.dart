import 'package:flutter_test/flutter_test.dart';
import '../lib/mir_connection_policy.dart';

void main() {
  test('no cierra durante la conexión inicial', () async {
    var count = 0;
    final policy = MiRConnectionPolicy(
      closeSession: () => count++,
      gracePeriod: const Duration(milliseconds: 15),
    );
    policy.onConnectionLost();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(count, 0);
    policy.dispose();
  });

  test('desconexión sostenida cierra una sesión establecida', () async {
    var count = 0;
    final policy = MiRConnectionPolicy(
      closeSession: () => count++,
      gracePeriod: const Duration(milliseconds: 15),
    );
    policy.onConnected();
    policy.onConnectionLost();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(count, 1);
    policy.dispose();
  });

  test('una reconexión cancela el cierre', () async {
    var count = 0;
    final policy = MiRConnectionPolicy(
      closeSession: () => count++,
      gracePeriod: const Duration(milliseconds: 50),
    );
    policy.onConnected();
    policy.onConnectionLost();
    policy.onConnected();
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(count, 0);
    policy.dispose();
  });
}
