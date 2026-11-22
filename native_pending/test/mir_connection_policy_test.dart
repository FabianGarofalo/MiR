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
  test('varias pérdidas de conexión generan un único cierre', () async {
    var cierres = 0;
    final policy = MiRConnectionPolicy(
      closeSession: () => cierres++,
      gracePeriod: const Duration(milliseconds: 20),
    );
    policy.onConnected();
    policy.onConnectionLost();
    policy.onConnectionLost();
    await Future<void>.delayed(const Duration(milliseconds: 55));
    expect(cierres, 1);
    policy.dispose();
  });

  test('dos sesiones tienen temporizadores independientes', () async {
    var cierresPrimera = 0;
    var cierresSegunda = 0;
    final primera = MiRConnectionPolicy(
      closeSession: () => cierresPrimera++,
      gracePeriod: const Duration(milliseconds: 20),
    );
    final segunda = MiRConnectionPolicy(
      closeSession: () => cierresSegunda++,
      gracePeriod: const Duration(milliseconds: 20),
    );
    primera.onConnected();
    segunda.onConnected();
    primera.onConnectionLost();
    await Future<void>.delayed(const Duration(milliseconds: 55));
    expect(cierresPrimera, 1);
    expect(cierresSegunda, 0);
    primera.dispose();
    segunda.dispose();
  });

  test('el cierre de la sesión cancela el temporizador pendiente', () async {
    var cierres = 0;
    final policy = MiRConnectionPolicy(
      closeSession: () => cierres++,
      gracePeriod: const Duration(milliseconds: 20),
    );
    policy.onConnected();
    policy.onConnectionLost();
    policy.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 55));
    expect(cierres, 0);
  });

}
