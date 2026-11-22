// Política de desconexión MiR: evita dejar "Conectando" indefinidamente.
// Debe recibir eventos REALES de sesión del cliente nativo; no actúa sobre procesos.
import 'dart:async';

class MiRConnectionPolicy {
  MiRConnectionPolicy({
    required this.closeSession,
    this.gracePeriod = const Duration(seconds: 15),
  });

  final void Function() closeSession;
  final Duration gracePeriod;
  Timer? _graceTimer;
  bool _connectedOnce = false;
  bool _disposed = false;

  /// Invocar exclusivamente cuando se estableció la sesión remota.
  void onConnected() {
    if (_disposed) return;
    _connectedOnce = true;
    _graceTimer?.cancel();
    _graceTimer = null;
  }

  /// Invocar solo si una sesión establecida pierde conexión.
  void onConnectionLost() {
    if (_disposed || !_connectedOnce || _graceTimer != null) return;
    _graceTimer = Timer(gracePeriod, () {
      _graceTimer = null;
      if (!_disposed && _connectedOnce) {
        _connectedOnce = false;
        closeSession();
      }
    });
  }

  void dispose() {
    _disposed = true;
    _graceTimer?.cancel();
    _graceTimer = null;
  }
}
