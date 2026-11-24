import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/mir/mir_receiver_layout.dart';

/// Tests geométricos del receptor, sin abrir una sesión real.
class _Case {
  const _Case(this.name,
      {this.permissions = true,
      this.call = false,
      this.elevate = false,
      this.switchSides = false,
      this.pending = false});
  final String name;
  final bool permissions;
  final bool call;
  final bool elevate;
  final bool switchSides;
  final bool pending;
}

const cases = <_Case>[
  _Case('solicitud pendiente', pending: true),
  _Case('solicitud pendiente con elevar', pending: true, elevate: true),
  _Case('sesion autorizada sin elevar'),
  _Case('sesion autorizada con elevar', elevate: true),
  _Case('llamada entrante sin elevar', call: true),
  _Case('llamada entrante con elevar', call: true, elevate: true),
  _Case('llamada activa sin elevar', call: true),
  _Case('llamada activa con elevar', call: true, elevate: true),
  _Case('cambio de control', switchSides: true),
  _Case('cambio de control y elevar', switchSides: true, elevate: true),
  _Case('conexion finalizada', permissions: false),
  _Case('transferencia de archivos', permissions: false),
  _Case('terminal', permissions: false),
  _Case('camara', permissions: true),
  _Case('redireccion de puertos', permissions: false),
];

Widget _fixture(_Case scenario, double width, double height) {
  final callHeight = scenario.call ? 122.0 : 0.0;
  final elevateHeight = scenario.elevate ? 44.0 : 0.0;
  final switchHeight = scenario.switchSides ? 44.0 : 0.0;
  final pendingHeight = scenario.pending ? 112.0 : 0.0;
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: MiRReceiverLayout(
            information: Column(
              key: const ValueKey('info-content'),
              children: [
                const SizedBox(
                    key: ValueKey('receiver-header'), height: 98),
                if (scenario.permissions)
                  const SizedBox(
                    key: ValueKey('receiver-permissions'), height: 172),
              ],
            ),
            criticalActions: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (scenario.call)
                  SizedBox(
                    key: const ValueKey('call-controls'), height: callHeight),
                if (scenario.switchSides)
                  SizedBox(
                    key: const ValueKey('switch-control'),
                    height: switchHeight),
                if (scenario.pending)
                  SizedBox(
                    key: const ValueKey('accept-cancel'),
                    height: pendingHeight),
                if (scenario.elevate && !scenario.pending)
                  SizedBox(
                    key: const ValueKey('elevate-control'),
                    height: elevateHeight),
                const SizedBox(
                    key: ValueKey('last-critical-action'), height: 44),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final scenario in cases) {
    testWidgets('${scenario.name}: 280 x 480, acciones completas',
        (tester) async {
      await tester.pumpWidget(_fixture(scenario, 280, 480));
      await tester.pumpAndSettle();
      final information = tester.getRect(
        find.byKey(const ValueKey('mir-receiver-information-scroll')));
      final actions = tester.getRect(
        find.byKey(const ValueKey('mir-receiver-action-scroll')));
      final last = tester.getRect(
        find.byKey(const ValueKey('last-critical-action')));
      expect(tester.takeException(), isNull);
      expect(information.bottom <= actions.top + 1, isTrue,
          reason: 'No deben superponerse las dos regiones');
      expect(last.bottom <= actions.bottom + 1, isTrue,
          reason: 'El boton inferior debe verse sin desplazarse');
      if (scenario.call) {
        final call = tester.getRect(
          find.byKey(const ValueKey('call-controls')));
        expect(call.top >= actions.top - 1, isTrue);
        expect(call.bottom <= actions.bottom + 1, isTrue,
            reason: 'Aceptar/Rechazar llamada deben estar totalmente visibles');
      }
    });
  }

  for (final height in [260.0, 320.0, 380.0]) {
    testWidgets('ventana reducida 250 x ${height}: dos scrolls sin overlap',
        (tester) async {
      const scenario=_Case('llamada entrante y elevacion',
          call: true, elevate: true);
      await tester.pumpWidget(_fixture(scenario, 250, height));
      await tester.pumpAndSettle();
      final information = tester.getRect(
        find.byKey(const ValueKey('mir-receiver-information-scroll')));
      final actionsFinder = find.byKey(
        const ValueKey('mir-receiver-action-scroll'));
      final actions = tester.getRect(actionsFinder);
      expect(tester.takeException(), isNull);
      expect(information.bottom <= actions.top + 1, isTrue);
      expect(actions.height <= height * .68 + 1, isTrue);
      // La zona de acciones puede tener scroll si la altura es insuficiente.
      await tester.drag(actionsFinder, const Offset(0, -240));
      await tester.pumpAndSettle();
      final last= tester.getRect(find.byKey(
        const ValueKey('last-critical-action')));
      expect(last.bottom <= actions.bottom + 1, isTrue,
          reason: 'Desconectar debe poder alcanzarse mediante scroll');
      expect(last.top >= actions.top - 1, isTrue);
    });
  }
}
