// Diagnóstico local: distingue MiR.exe visible de MiR.exe --cm receptor.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

const _accent = Color(0xFF75E0C1);
const _muted = Color(0xFFA4C3BB);
const _warning = Color(0xFFF6BE73);
const _surface = Color(0xFF132629);
const _edge = Color(0xFF315052);
const _text = Color(0xFFEDF6F3);

class MiRReceiverRuntimeCard extends StatefulWidget {
  const MiRReceiverRuntimeCard({super.key});

  @override
  State<MiRReceiverRuntimeCard> createState() => _MiRReceiverRuntimeCardState();
}

class _ReceiverReport {
  const _ReceiverReport(this.message, this.warning, this.paths, this.verified);
  final String message;
  final bool warning;
  final List<String> paths;
  final bool verified;
}

class _MiRReceiverRuntimeCardState extends State<MiRReceiverRuntimeCard> {
  late Future<_ReceiverReport> _report;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() { _report = _readReceiver(); });
  }

  static String _norm(String input) =>
      input.trim().replaceAll('/', String.fromCharCode(92)).toLowerCase();

  Future<_ReceiverReport> _readReceiver() async {
    if (!Platform.isWindows) {
      return const _ReceiverReport('Disponible en Windows.', false, [], false);
    }
    const command = r'''
$ErrorActionPreference='Stop'
$receivers=@(Get-CimInstance Win32_Process -Filter "Name='MiR.exe' OR Name='rustdesk.exe'" | Where-Object {$_.CommandLine -match '(?i)(?:^|\s)--cm(?:\s|$)'} | ForEach-Object {
  [pscustomobject]@{Name=$_.Name;PID=$_.ProcessId;Path=$_.ExecutablePath;Started=$(if($_.CreationDate){$_.CreationDate.ToUniversalTime().ToString('o')}else{''})}
})
$services=@(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object {$_.Name -match '(?i)^(MiR|MiRHost|RustDesk)$'} | ForEach-Object {
  [pscustomobject]@{Name=$_.Name;State=$_.State;Path=$_.PathName}
})
[pscustomobject]@{Receivers=$receivers;Services=$services} | ConvertTo-Json -Depth 5 -Compress
''';
    try {
      final process = await Process.run('powershell.exe',
        const ['-NoProfile', '-NonInteractive', '-Command', command])
          .timeout(const Duration(seconds: 12));
      if (process.exitCode != 0) throw const FormatException('CIM no disponible');
      final data = jsonDecode(process.stdout.toString());
      if (data is! Map) throw const FormatException('Formato no valido');
      List<Map<String, dynamic>> array(dynamic source) {
        if (source is List) {
          return source.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e)).toList();
        }
        if (source is Map) return [Map<String, dynamic>.from(source)];
        return [];
      }
      final receiverRows = array(data['Receivers']);
      final serviceRows = array(data['Services']);
      final myExe = Platform.resolvedExecutable;
      final mySnapshot = File(File(myExe).parent.path + Platform.pathSeparator +
          'data' + Platform.pathSeparator + 'app.so');
      final compiled = await mySnapshot.lastModified();
      var oldMiR = false;
      var differentApp = false;
      var wrongService = false;
      var current = false;
      final details = <String>[];
      for (final row in receiverRows) {
        final name = (row['Name'] ?? '').toString().toLowerCase();
        final path = (row['Path'] ?? '').toString();
        final started = DateTime.tryParse((row['Started'] ?? '').toString());
        final matches = name == 'mir.exe' && path.isNotEmpty &&
            _norm(path) == _norm(myExe) && started != null &&
            !started.isBefore(compiled.subtract(const Duration(seconds: 3)));
        if (matches) {
          current = true;
          details.add('MiR actual: ' + path);
        } else if (name == 'mir.exe') {
          oldMiR = true;
          details.add('MiR anterior/no verificable: ' +
              (path.isEmpty ? 'ruta no accesible' : path));
        } else {
          differentApp = true;
          details.add('RustDesk receptor: ' +
              (path.isEmpty ? 'ruta no accesible' : path));
        }
      }
      for (final service in serviceRows) {
        final name = (service['Name'] ?? '').toString().toLowerCase();
        final path = (service['Path'] ?? '').toString();
        if (name == 'mir' && path.isNotEmpty &&
            !path.toLowerCase().contains(myExe.toLowerCase())) {
          wrongService = true;
          details.add('Servicio MiR apunta a: ' + path);
        }
        if (name == 'rustdesk') {
          final state = (service['State'] ?? '').toString();
          details.add('Servicio RustDesk (' + state + '): ' + path);
          if (state.toLowerCase() == 'running') differentApp = true;
        }
      }
      final alert = oldMiR || wrongService || differentApp;
      final message = oldMiR
          ? 'Hay una ventana receptora MiR de otra version. '
              'Puede explicar la interfaz azul.'
          : wrongService
              ? 'El servicio MiR utiliza otro ejecutable. '
                  'La interfaz antigua puede reaparecer.'
              : differentApp
                  ? 'Existe un receptor RustDesk independiente. '
                      'Verifica cual atiende el ID de la llamada.'
                  : current
                      ? 'La ventana receptora pertenece a esta version MiR.'
                      : 'No hay ventana receptora activa. '
                          'Se iniciara cuando llegue una conexion.';
      return _ReceiverReport(message, alert, details, current);
    } catch (_) {
      return const _ReceiverReport(
          'No fue posible verificar el proceso receptor de Windows. '
          'El estado Conectado no confirma la interfaz que atiende llamadas.',
          true, [], false);
    }
  }

  Future<void> _openCorrector() async {
    if (!Platform.isWindows) return;
    final dir = File(Platform.resolvedExecutable).parent.path;
    final corrector = File(dir + Platform.pathSeparator +
        'MiR_Corregir_Receptor.cmd');
    if (!await corrector.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No esta el corrector junto a MiR.exe. '
            'Descomprimi el portable completo.')));
      return;
    }
    try {
      // El script muestra consentimiento antes de cerrar procesos anteriores.
      final safePath = corrector.path.replaceAll("'", "''");
      final safeDir = dir.replaceAll("'", "''");
      final launch = "Start-Process -FilePath '" + safePath +
          "' -WorkingDirectory '" + safeDir + "'";
      final result = await Process.run(
          'powershell.exe', ['-NoProfile', '-NonInteractive',
          '-Command', launch]);
      if (result.exitCode != 0) {
        throw const ProcessException('powershell.exe', [],
            'No se pudo abrir el corrector de receptor', 1);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo abrir la comprobacion. '
            'Ejecuta MiR_Corregir_Receptor.cmd desde la carpeta MiR.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReceiverReport>(
      future: _report,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('Comprobando receptor real…',
              style: TextStyle(color: _muted, fontSize: 11.5));
        }
        final report = snapshot.data!;
        return Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: _surface, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _edge),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(report.warning ? Icons.warning_amber_rounded
                    : Icons.verified_outlined,
                    color: report.warning ? _warning : _accent, size: 18),
                const SizedBox(width: 6),
                const Expanded(child: Text('Proceso receptor real',
                    style: TextStyle(
                      color: _text, fontWeight: FontWeight.w700,
                      fontSize: 12.5))),
              ]),
              const SizedBox(height: 6),
              Text(report.message, style: TextStyle(
                color: report.warning ? _warning : _muted,
                fontSize: 11.5, height: 1.35)),
              for (final entry in report.paths)
                Padding(padding: const EdgeInsets.only(top: 6),
                  child: SelectableText(entry,
                    style: const TextStyle(
                      color: _muted, fontSize: 10.5, height: 1.35))),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Comprobar'),
                  style: OutlinedButton.styleFrom(foregroundColor: _accent),
                ),
                if (report.warning || !report.verified)
                  OutlinedButton.icon(
                    onPressed: _openCorrector,
                    icon: const Icon(Icons.build_outlined, size: 16),
                    label: const Text('Corregir receptor'),
                    style: OutlinedButton.styleFrom(foregroundColor: _accent),
                  ),
              ]),
              const Text('No se modifica ningun servicio automaticamente. '
                  'Cerrar un receptor antiguo requiere confirmacion.',
                  style: TextStyle(color: _muted, fontSize: 10.5)),
            ],
          ),
        );
      },
    );
  }
}
