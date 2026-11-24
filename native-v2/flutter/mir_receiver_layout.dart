// Layout del receptor MiR con dos áreas de desplazamiento independientes.
// La botonera (llamada/autorizar/desconectar) nunca queda debajo de permisos.
import 'package:flutter/material.dart';

class MiRReceiverLayout extends StatelessWidget {
  const MiRReceiverLayout({
    super.key,
    required this.information,
    required this.criticalActions,
  });

  final Widget information;
  final Widget criticalActions;

  static const background = Color(0xFF0B191A);
  static const divider = Color(0xFF315052);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, viewport) {
      final availableHeight = viewport.hasBoundedHeight
          ? viewport.maxHeight
          : 520.0;
      // En ventanas bajas la botonera dispone de hasta el 68 % de la altura
      // y su propio scroll. En ventanas normales ocupa SOLO lo que necesita.
      final footerLimit = availableHeight * 0.68;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('mir-receiver-information-scroll'),
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 12),
                child: information,
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: footerLimit),
              child: SingleChildScrollView(
                key: const ValueKey('mir-receiver-action-scroll'),
                physics: const ClampingScrollPhysics(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
                  decoration: const BoxDecoration(
                    color: background,
                    border: Border(
                      top: BorderSide(color: divider, width: 0.7),
                    ),
                  ),
                  child: criticalActions,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
