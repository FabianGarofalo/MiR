// MiR: diagnóstico de la recepción portable, distinto del estado de ID/Relay.
// No instala servicios ni modifica claves, firewall o configuración de red.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/mir/mir_receiver_process_probe.dart';

const _bg = Color(0xFF193236);
const _edge = Color(0xFF315052);
const _accent = Color(0xFF75E0C1);
const _text = Color(0xFFEDF6F3);
const _muted = Color(0xFFA4C3BB);
const _warning = Color(0xFFF6BE73);

class MiRReceiverDiagnostics extends StatefulWidget {
  const MiRReceiverDiagnostics({super.key});

  @override
  State<MiRReceiverDiagnostics> createState() => _MiRReceiverDiagnosticsState();
}

class _ReceiverStatus {
  const _ReceiverStatus(this.serverState, this.hasId, this.paused);
  final int serverState;
  final bool hasId;
  final bool paused;
}

class _MiRReceiverDiagnosticsState extends State<MiRReceiverDiagnostics> {
  late Future<_ReceiverStatus> _status;
  bool _changing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<_ReceiverStatus> _getStatus() async {
    final connection = jsonDecode(await bind.mainGetConnectStatus())
        as Map<String, dynamic>;
    final id = (await bind.mainGetMyId()).trim();
    final stopped = await mainGetBoolOption(kOptionStopService);
    return _ReceiverStatus(
      connection['status_num'] is int
          ? connection['status_num'] as int
          : -1,
      id.isNotEmpty && !id.contains('...'),
      stopped,
    );
  }

  void _refresh() {
    setState(() => _status = _getStatus());
  }

  Future<void> _enableReceiving() async {
    if (_changing) return;
    setState(() => _changing = true);
    try {
      // Exactamente el control de RustDesk, no inicia un segundo servidor.
      // El motor aplica la opción en su propia lógica.
      await mainSetBoolOption(kOptionStopService, false);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Recepción habilitada en la configuración. '
            'Probá una conexión desde otra computadora con MiR abierto.'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No fue posible habilitar la recepción. '
            'Revisá Ajustes > General.'),
      ));
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  Widget _line(String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: _muted, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 12.5,
            fontWeight: FontWeight.w600, height: 1.35)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReceiverStatus>(
      future: _status,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(snapshot.hasError
                ? 'No se pudo consultar el estado del receptor.'
                : 'Comprobando recepción…',
                style: const TextStyle(color: _warning)),
            TextButton.icon(
              onPressed: _refresh, icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ]);
        }
        final status = snapshot.data!;
        final rendezvous = status.serverState == 1
            ? 'Conectado al servidor de intermediación'
            : status.serverState == 0
                ? 'Conectando al servidor…'
                : 'Sin conexión con el servidor';
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _bg, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _edge),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _line('Servidor ID/Relay', rendezvous,
                status.serverState == 1 ? _accent : _warning),
            _line('ID de recepción',
                status.hasId ? 'Disponible' : 'No disponible todavía',
                status.hasId ? _text : _warning),
            _line('Recepción en esta computadora',
                status.paused
                    ? 'Desactivada en la configuración'
                    : 'Habilitada en la configuración (requiere prueba entrante)',
                status.paused ? _warning : _accent),
            const Text(
              'La conexión al servidor NO garantiza que se acepten '
              'sesiones entrantes. Verificá con otra computadora usando '
              'el ID mostrado en Mi equipo.',
              style: TextStyle(color: _muted, fontSize: 11.5, height: 1.4)),
            const SizedBox(height: 12),
            const MiRReceiverRuntimeCard(),
            const SizedBox(height: 11),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (status.paused)
                FilledButton.icon(
                  onPressed: _changing ? null : _enableReceiving,
                  icon: const Icon(Icons.play_circle_outline, size: 17),
                  label: const Text('Habilitar recepción'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent, foregroundColor: const Color(0xFF0B191A)),
                ),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Actualizar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _edge)),
              ),
            ]),
          ]),
        );
      },
    );
  }
}
