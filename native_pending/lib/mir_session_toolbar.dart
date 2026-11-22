// MiR | Barra de herramientas Flutter para una sesión remota.
// Requiere integrarse con acciones REALES del motor remoto; NO controla por sí sola.
import 'dart:math' as math;
import 'package:flutter/material.dart';

class MiRSessionToolbar extends StatefulWidget {
  const MiRSessionToolbar({
    super.key,
    required this.onPinChanged,
    required this.onQuickActions,
    required this.onScreen,
    required this.onKeyboard,
    required this.onVoiceCall,
    required this.onToggleRecording,
    required this.onCloseSession,
    this.isRecording = false,
    this.isConnected = true,
  });

  final ValueChanged<bool> onPinChanged;
  final VoidCallback onQuickActions;
  final VoidCallback onScreen;
  final VoidCallback onKeyboard;
  final VoidCallback onVoiceCall;
  final VoidCallback onToggleRecording;
  final VoidCallback onCloseSession;
  final bool isRecording;
  final bool isConnected;

  @override
  State<MiRSessionToolbar> createState() => _MiRSessionToolbarState();
}

class _MiRSessionToolbarState extends State<MiRSessionToolbar> {
  Offset offset = const Offset(18, 12);
  bool pinned = true;

  Widget tool({
    required IconData icon,
    required String tooltip,
    required VoidCallback callback,
    Color? color,
    bool enabled = true,
  }) {
    final bg = color ?? const Color(0xFF0874F9);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: enabled ? bg : const Color(0xFF485259),
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: enabled ? callback : null,
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(icon, color: Colors.white, size: 21),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      const width = 304.0;
      final maxX = math.max(0.0, box.maxWidth - width);
      final maxY = math.max(0.0, box.maxHeight - 44);
      final x = offset.dx.clamp(0.0, maxX).toDouble();
      final y = offset.dy.clamp(0.0, maxY).toDouble();
      return Stack(children: [
        Positioned(
          left: x,
          top: y,
          child: GestureDetector(
            onPanUpdate: (d) => setState(() {
              offset = Offset(
                (offset.dx + d.delta.dx).clamp(0.0, maxX).toDouble(),
                (offset.dy + d.delta.dy).clamp(0.0, maxY).toDouble(),
              );
            }),
            child: Material(
              color: const Color(0xFF0B191A),
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  tool(
                    icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    tooltip: 'Fijar barra',
                    color: const Color(0xFF3E4449),
                    callback: () {
                      setState(() => pinned = !pinned);
                      widget.onPinChanged(pinned);
                    },
                  ),
                  tool(
                    icon: Icons.bolt,
                    tooltip: 'Acciones rápidas',
                    callback: widget.onQuickActions,
                    enabled: widget.isConnected,
                  ),
                  tool(
                    icon: Icons.monitor,
                    tooltip: 'Pantalla y monitores',
                    callback: widget.onScreen,
                    enabled: widget.isConnected,
                  ),
                  tool(
                    icon: Icons.keyboard,
                    tooltip: 'Teclado',
                    callback: widget.onKeyboard,
                    enabled: widget.isConnected,
                  ),
                  tool(
                    icon: Icons.call,
                    tooltip: 'Llamada de voz',
                    callback: widget.onVoiceCall,
                    enabled: widget.isConnected,
                  ),
                  tool(
                    icon: widget.isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                    tooltip: widget.isRecording ? 'Detener grabación' : 'Grabar sesión',
                    callback: widget.onToggleRecording,
                    enabled: widget.isConnected,
                  ),
                  tool(
                    icon: Icons.close,
                    tooltip: 'Cerrar sesión',
                    color: const Color(0xFFE94B50),
                    callback: widget.onCloseSession,
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]);
    });
  }
}
