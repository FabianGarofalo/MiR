// MiR | Despertar equipos mediante Wake-on-LAN.
// No modifica el servicio receptor ni consulta contraseñas.
// La entrega LAN funciona con paquetes UDP broadcast al puerto 9.
// Para equipos fuera de la LAN se necesita una ruta VPN/broadcast o un
// dispositivo puente encendido en esa LAN; el servidor de ID no reenvía WoL.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:path_provider/path_provider.dart';

class MiRWakeResult {
  const MiRWakeResult(this.id, {required this.viaMac});
  final String id;
  final bool viaMac;
}

class MiRMagicPacket {
  static String normalizeMac(String value) {
    final cleaned =
        value.toUpperCase().replaceAll(':', '').replaceAll('-', '').replaceAll('.', '').replaceAll(' ', '');
    if (!RegExp(r'^[0-9A-F]{12}$').hasMatch(cleaned)) {
      throw const FormatException(
          'Ingresá una dirección MAC válida (ejemplo: 00:11:22:33:44:55).');
    }
    final bytes = <int>[
      for (var i = 0; i < 12; i += 2)
        int.parse(cleaned.substring(i, i + 2), radix: 16),
    ];
    if (bytes.every((byte) => byte == 0) ||
        bytes.every((byte) => byte == 255) ||
        bytes.first.isOdd) {
      throw const FormatException(
          'La MAC debe identificar una placa de red individual.');
    }
    return [
      for (var i = 0; i < 12; i += 2) cleaned.substring(i, i + 2),
    ].join(':');
  }

  static Uint8List create(String mac) {
    final normalized = normalizeMac(mac).replaceAll(':', '');
    final address = <int>[
      for (var i = 0; i < 12; i += 2)
        int.parse(normalized.substring(i, i + 2), radix: 16),
    ];
    final packet = Uint8List(102);
    packet.fillRange(0, 6, 0xff);
    for (var i = 0; i < 16; i++) {
      packet.setRange(6 + (i * 6), 12 + (i * 6), address);
    }
    return packet;
  }

  /// Enviar no significa que el equipo haya despertado.
  static Future<void> sendLocalBroadcast(String mac) async {
    final packet = create(mac);
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      socket.broadcastEnabled = true;
      for (var attempt = 0; attempt < 3; attempt++) {
        final sent = socket.send(
          packet,
          InternetAddress('255.255.255.255'),
          9,
        );
        if (sent != packet.length) {
          throw const SocketException(
              'Windows no pudo enviar el paquete Wake-on-LAN completo.');
        }
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
    } finally {
      socket.close();
    }
  }
}

class MiRWakeSavedDevices {
  static const _fileName = 'mir_wol_lan_devices.json';

  static Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File(directory.path + Platform.pathSeparator + _fileName);
  }

  static Future<Map<String, String>> _read() async {
    final file = await _file();
    if (!await file.exists()) return {};
    if (await file.length() > 65536) {
      throw const FormatException('La agenda Wake-on-LAN es demasiado grande.');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const FormatException('La agenda Wake-on-LAN no es válida.');
    }
    final records = <String, String>{};
    for (final entry in decoded.entries) {
      if (entry.key is String && entry.value is String) {
        records[entry.key as String] = entry.value as String;
      }
    }
    return records;
  }

  static Future<String?> lookup(String id) async {
    final devices = await _read();
    return devices[id.trim()];
  }

  static Future<void> remember(String id, String mac) async {
    final key = id.trim();
    if (key.isEmpty || key.length > 128) {
      throw const FormatException('Ingresá el ID del equipo remoto.');
    }
    final devices = await _read();
    if (devices.length >= 100 && !devices.containsKey(key)) {
      throw const FormatException(
          'La agenda WoL alcanzó su límite de 100 equipos.');
    }
    devices[key] = MiRMagicPacket.normalizeMac(mac);
    final file = await _file();
    // La agenda contiene exclusivamente ID y MAC. Nunca guarda contraseñas.
    await file.writeAsString(jsonEncode(devices), flush: true);
  }
}

class MiRWakeDialog extends StatefulWidget {
  const MiRWakeDialog({super.key, required this.initialId});
  final String initialId;

  @override
  State<MiRWakeDialog> createState() => _MiRWakeDialogState();
}

class _MiRWakeDialogState extends State<MiRWakeDialog> {
  late final TextEditingController _id;
  final _mac = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _id = TextEditingController(text: widget.initialId.trim());
    if (_id.text.isNotEmpty) _loadSavedMac();
  }

  @override
  void dispose() {
    _id.dispose();
    _mac.dispose();
    super.dispose();
  }

  Future<void> _loadSavedMac() async {
    final requested = _id.text.trim();
    if (requested.isEmpty) return;
    try {
      final saved = await MiRWakeSavedDevices.lookup(requested);
      if (mounted && _id.text.trim() == requested && saved != null) {
        _mac.text = saved;
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'No se pudo leer la agenda WoL.');
    }
  }

  Future<void> _wakeMac() async {
    final id = _id.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Ingresá el ID del equipo que querés despertar.');
      return;
    }
    setState(() { _error = null; _busy = true; });
    try {
      final mac = MiRMagicPacket.normalizeMac(_mac.text);
      await MiRMagicPacket.sendLocalBroadcast(mac);
      // La falta de permisos para guardar no debe negar un paquete ya enviado.
      try {
        await MiRWakeSavedDevices.remember(id, mac);
      } catch (_) {
        // La señal ya salió. La MAC deberá ingresarse nuevamente si no se guardó.
      }
      if (mounted) {
        Navigator.of(context).pop(MiRWakeResult(id, viaMac: true));
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on SocketException catch (_) {
      if (mounted) {
        setState(() => _error =
            'No se pudo enviar la señal por la red local. Revisá Wi-Fi/Ethernet y firewall.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo enviar la señal de activación.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _wakeDiscoveredLanId() {
    final id = _id.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Ingresá el ID descubierto en la red local.');
      return;
    }
    // Función real RustDesk: busca la MAC en LanPeers. Si el ID no se descubrió
    // previamente, el motor no tiene MAC y no puede enviar el paquete.
    bind.mainWol(id: id);
    Navigator.of(context).pop(MiRWakeResult(id, viaMac: false));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.power_settings_new_rounded, size: 22),
        SizedBox(width: 10),
        Flexible(child: Text('Despertar equipo')),
      ]),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wake-on-LAN funciona dentro de la misma red local. '
                'El equipo de destino debe admitir y tener activada esta función.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _id,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'ID del equipo en MIR',
                  hintText: 'ID remoto',
                ),
                onSubmitted: (_) => _loadSavedMac(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _mac,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Dirección MAC de Ethernet',
                  hintText: '00:11:22:33:44:55',
                  helperText: 'Se guarda localmente para próximos despertares.',
                  suffixIcon: IconButton(
                    tooltip: 'Cargar MAC guardada para este ID',
                    icon: const Icon(Icons.history_rounded),
                    onPressed: _busy ? null : _loadSavedMac,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'No se puede despertar por Internet usando solamente el ID. '
                'Para otra red se necesita una VPN o un dispositivo puente '
                'encendido allí.',
                style: TextStyle(fontSize: 12),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                )),
              ],
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: _busy ? null : _wakeDiscoveredLanId,
                icon: const Icon(Icons.lan_outlined, size: 18),
                label: const Text('Probar por ID descubierto en LAN'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _wakeMac,
          icon: _busy
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.power_settings_new_rounded, size: 18),
          label: const Text('Enviar señal WoL'),
        ),
      ],
    );
  }
}
