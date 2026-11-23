// MiR V2 — pantalla principal nativa de EcoEtika.
// Las conexiones, el ID propio, la contraseña y la agenda usan el motor real.
// No crea, detiene ni reemplaza servicios Windows automáticamente.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/peer_tab_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/mir/mir_settings_router.dart';
import 'package:get/get.dart';

const _background = Color(0xFF0B191A);
const _card = Color(0xFF132629);
const _field = Color(0xFF193236);
const _edge = Color(0xFF315052);
const _accent = Color(0xFF75E0C1);
const _muted = Color(0xFFA4C3BB);
const _foreground = Color(0xFFEDF6F3);
const _warning = Color(0xFFF6BE73);

class MiRHomeShell extends StatefulWidget {
  const MiRHomeShell({super.key});

  @override
  State<MiRHomeShell> createState() => _MiRHomeShellState();
}

class _MiRHomeShellState extends State<MiRHomeShell> {
  final TextEditingController _remoteId = TextEditingController();
  int _section = 0;
  bool _showPassword = false;
  int _diagnosticTick = 0;
  bool _inSettings = false;
  SettingsTabKey _selectedSettingsTab = SettingsTabKey.general;

  static const _sections = <String>[
    'Mis equipos',
    'Mi equipo / Receptor',
    'Sesiones y archivos',
    'Diagnóstico',
  ];

  @override
  void initState() {
    super.initState();
    MiRSettingsRouter.homeMounted = true;
    MiRSettingsRouter.revision.addListener(_onSettingsRequested);
  }

  void _onSettingsRequested() {
    if (!mounted) return;
    final index = MiRSettingsRouter.requestedTabIndex;
    final tabs = DesktopSettingPage.tabKeys;
    if (index < 0 || index >= tabs.length) return;
    final requested = tabs[index];
    if (!_inSettings) {
      setState(() {
        _selectedSettingsTab = requested;
        _inSettings = true;
      });
    } else if (_selectedSettingsTab != requested) {
      setState(() => _selectedSettingsTab = requested);
      // Preservar controlador y controles de ajustes; solo cambia la sección.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _inSettings) DesktopSettingPage.switch2page(requested);
      });
    }
  }

  void _backToMiR() {
    if (_inSettings) setState(() => _inSettings = false);
  }

  @override
  void dispose() {
    MiRSettingsRouter.revision.removeListener(_onSettingsRequested);
    MiRSettingsRouter.homeMounted = false;
    _remoteId.dispose();
    super.dispose();
  }

  void _connect({bool files = false}) {
    final id = _remoteId.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá el ID del equipo remoto.')),
      );
      return;
    }
    connect(context, id, isFileTransfer: files);
  }

  void _settings(SettingsTabKey page) {
    MiRSettingsRouter.open(DesktopSettingPage.tabKeys.indexOf(page));
  }

  Widget _cardBox({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _edge, width: 0.8),
      ),
      padding: padding,
      child: child,
    );
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
              color: _foreground, fontSize: 18, fontWeight: FontWeight.w700,
            )),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12.5)),
        ],
      ],
    );
  }

  Widget _action(String text, IconData icon, VoidCallback onPressed,
      {bool secondary = false}) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        foregroundColor: secondary ? _foreground : _background,
        backgroundColor: secondary ? _field : _accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: secondary ? const BorderSide(color: _edge) : BorderSide.none,
        ),
        minimumSize: const Size(0, 41),
        padding: const EdgeInsets.symmetric(horizontal: 15),
      ),
    );
  }

  Widget _quickConnect({bool isFiles = false}) {
    return _cardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(isFiles ? 'Transferir archivos' : 'Conectar con un equipo',
            subtitle: 'Usá el ID remoto. La conexión se realiza mediante el motor integrado de MiR.'),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(
              controller: _remoteId,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _connect(files: isFiles),
              style: const TextStyle(color: _foreground),
              decoration: const InputDecoration(
                hintText: 'ID o dirección del equipo',
                prefixIcon: Icon(Icons.computer_outlined, color: _muted),
              ),
            )),
            const SizedBox(width: 10),
            _action(isFiles ? 'Transferir' : 'Conectar',
              isFiles ? Icons.folder_open_outlined : Icons.arrow_forward_rounded,
              () => _connect(files: isFiles)),
          ]),
          if (!isFiles) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _connect(files: true),
                icon: const Icon(Icons.drive_folder_upload_outlined, size: 18),
                label: const Text('Transferir archivos'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _devices() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _quickConnect(),
      const SizedBox(height: 13),
      Expanded(
        child: _cardBox(
          padding: const EdgeInsets.fromLTRB(15, 14, 8, 9),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionTitle('Mis equipos',
                subtitle: 'Recientes, favoritos, equipos descubiertos y libreta de contactos.'),
            const SizedBox(height: 12),
            // PeerTabPage es la agenda REAL del motor. Mantiene sus acciones de
            // conexión, favoritos, libretas y permisos, sin base de datos paralela.
            const Expanded(child: PeerTabPage()),
          ]),
        ),
      ),
    ]);
  }

  Widget _fieldLabel(String text, String value,
      {IconData? icon, bool allowCopy = false}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      if (icon != null) ...[
        Icon(icon, color: _accent, size: 20),
        const SizedBox(width: 11),
      ],
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 6),
          SelectableText(value.isEmpty ? 'Generando…' : value,
            style: const TextStyle(
              color: _foreground, fontSize: 18, fontWeight: FontWeight.w600,
            )),
        ],
      )),
      if (allowCopy && value.isNotEmpty)
        IconButton(
          tooltip: 'Copiar',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$text copiado')),
            );
          },
          icon: const Icon(Icons.copy_rounded, color: _accent),
        ),
    ]);
  }

  Widget _myComputer() {
    final model = gFFI.serverModel;
    return SingleChildScrollView(
      child: LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final myId = AnimatedBuilder(
          animation: model.serverId,
          builder: (context, _) => _fieldLabel(
            'ID de esta computadora', model.serverId.text,
            icon: Icons.badge_outlined, allowCopy: true,
          ),
        );
        final oneTimePassword = AnimatedBuilder(
          animation: model.serverPasswd,
          builder: (context, _) => Row(children: [
            Expanded(child: _fieldLabel(
              'Contraseña de un solo uso',
              _showPassword ? model.serverPasswd.text : '••••••••',
              icon: Icons.key_outlined,
              allowCopy: _showPassword,
            )),
            IconButton(
              tooltip: _showPassword ? 'Ocultar contraseña' : 'Ver contraseña',
              icon: Icon(_showPassword ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined, color: _accent),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
            IconButton(
              tooltip: 'Generar contraseña nueva',
              icon: const Icon(Icons.refresh_rounded, color: _accent),
              onPressed: () => bind.mainUpdateTemporaryPassword(),
            ),
          ]),
        );
        final identification = _cardBox(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Esta computadora',
                subtitle: 'Compartí el ID y una contraseña únicamente con personas autorizadas.'),
            const SizedBox(height: 20),
            myId,
            const Divider(height: 30, color: _edge),
            oneTimePassword,
            const SizedBox(height: 15),
            _action('Configuración de seguridad', Icons.shield_outlined,
                () => _settings(SettingsTabKey.safety), secondary: true),
          ],
        ));
        final receiver = _cardBox(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Receptor MiR',
                subtitle: 'Acceso desatendido y arranque con Windows.'),
            const SizedBox(height: 17),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, color: _warning, size: 21),
              const SizedBox(width: 10),
              Expanded(child: Text(
                bind.mainIsInstalled()
                    ? 'MiR figura instalado. Verificá el servicio antes de confiar en el acceso desatendido.'
                    : 'Modo portable: para recibir conexiones antes del PIN necesitás instalar el receptor MiR. No se modifica automáticamente otro servicio existente.',
                style: const TextStyle(color: _foreground, fontSize: 13, height: 1.45),
              )),
            ]),
            const SizedBox(height: 17),
            _action('Configuración de red', Icons.settings_ethernet_rounded,
                () => _settings(SettingsTabKey.network), secondary: true),
            const SizedBox(height: 10),
            const Text(
              'Antes de reemplazar una instalación anterior, comprobá la recepción tras reiniciar y con la pantalla bloqueada.',
              style: TextStyle(color: _muted, fontSize: 12.5),
            ),
          ],
        ));
        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: narrow
            ? Column(children: [
                identification, const SizedBox(height: 14), receiver,
              ])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: identification),
                const SizedBox(width: 14),
                Expanded(child: receiver),
              ]),
        );
      }),
    );
  }

  Widget _sessions() {
    return SingleChildScrollView(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _quickConnect(isFiles: true),
        const SizedBox(height: 14),
        _cardBox(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Control y sesiones',
              subtitle: 'Herramientas disponibles durante una conexión remota autorizada.'),
            const SizedBox(height: 17),
            const Wrap(spacing: 16, runSpacing: 12, children: [
              _Capability(Icons.mouse_outlined, 'Mouse y teclado'),
              _Capability(Icons.monitor_outlined, 'Monitores'),
              _Capability(Icons.content_paste_outlined, 'Portapapeles'),
              _Capability(Icons.folder_copy_outlined, 'Transferencia'),
              _Capability(Icons.call_outlined, 'Llamada'),
              _Capability(Icons.fiber_manual_record_outlined, 'Grabación'),
            ]),
            const SizedBox(height: 15),
            const Text(
              'Las opciones de cada sesión se abren en la barra del escritorio remoto. Sus permisos dependen del equipo receptor.',
              style: TextStyle(color: _muted, fontSize: 12.5),
            ),
          ],
        )),
      ],
    ));
  }

  Widget _diagnostics() {
    return SingleChildScrollView(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cardBox(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Diagnóstico local',
                subtitle: 'Información de estado sin exportar contraseñas ni identificadores.'),
            const SizedBox(height: 16),
            FutureBuilder<String>(
              key: ValueKey(_diagnosticTick),
              future: bind.mainGetConnectStatus(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Text('Comprobando conexión…',
                    style: TextStyle(color: _muted));
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return const Text('No se pudo consultar el estado de conexión.',
                    style: TextStyle(color: _warning));
                }
                try {
                  final status = jsonDecode(snapshot.data!) as Map<String, dynamic>;
                  final num = status['status_num'];
                  final message = num == 1
                      ? 'Conectado al servicio de intermediación'
                      : num == 0
                          ? 'Conectando…'
                          : 'Conexión no disponible. Revisá la red y la configuración del servidor.';
                  return _fieldLabel('Estado de la conexión', message,
                    icon: Icons.network_check_rounded);
                } catch (_) {
                  return const Text('Estado no disponible.',
                      style: TextStyle(color: _warning));
                }
              },
            ),
            const SizedBox(height: 18),
            Wrap(spacing: 12, runSpacing: 10, children: [
              _action('Actualizar', Icons.refresh_rounded,
                  () => setState(() => _diagnosticTick++)),
              _action('Configurar red', Icons.settings_ethernet,
                  () => _settings(SettingsTabKey.network), secondary: true),
              _action('Acerca de MiR', Icons.info_outline,
                  () => _settings(SettingsTabKey.about), secondary: true),
            ]),
          ],
        )),
        const SizedBox(height: 14),
        _cardBox(child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MiR V2 | Desarrollado por EcoEtika S.A.S.',
                style: TextStyle(color: _foreground, fontWeight: FontWeight.w600)),
            SizedBox(height: 9),
            Text('Tecnología de control remoto de código abierto integrada. Créditos y licencia en Acerca de MiR.',
                style: TextStyle(color: _muted, fontSize: 12.5)),
          ],
        )),
      ],
    ));
  }

  Widget _body() {
    if (_inSettings) {
      return DesktopSettingPage(
        key: const ValueKey('mir-settings-inline'),
        initialTabkey: _selectedSettingsTab,
      );
    }
    switch (_section) {
      case 0: return _devices();
      case 1: return _myComputer();
      case 2: return _sessions();
      default: return _diagnostics();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mirTheme = theme.copyWith(
      textTheme: theme.textTheme.apply(
          bodyColor: _foreground, displayColor: _foreground),
      scaffoldBackgroundColor: _background,
      colorScheme: const ColorScheme.dark(
        primary: _accent, onPrimary: _background,
        surface: _card, onSurface: _foreground,
        background: _background, onBackground: _foreground,
      ),
      dividerColor: _edge,
      cardTheme: CardTheme(
        color: _card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _edge, width: 0.8),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) =>
            states.contains(MaterialState.selected) ? _accent : _field),
        checkColor: MaterialStateProperty.all(_background),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: _field,
        hintStyle: const TextStyle(color: _muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: _edge),
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _edge),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _accent, width: 1.2),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
    return Theme(
      data: mirTheme,
      child: Container(
        color: _background,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              Image.asset('assets/MiR_logo.png', width: 126, height: 54,
                fit: BoxFit.contain),
              const SizedBox(width: 18),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Acceso remoto | Windows + Android',
                    style: TextStyle(color: _foreground, fontSize: 14,
                        fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Control y acceso desatendido desde una sola aplicación',
                    style: TextStyle(color: _muted, fontSize: 11)),
                ],
              )),
              IconButton(
                tooltip: 'Configuración',
                onPressed: () => _settings(SettingsTabKey.general),
                icon: const Icon(Icons.settings_outlined, color: _muted),
              ),
            ]),
          ),
          if (_inSettings)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 10),
              child: Row(children: [
                OutlinedButton.icon(
                  onPressed: _backToMiR,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Volver a MiR'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accent,
                    side: const BorderSide(color: _edge),
                    backgroundColor: _field,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(child: Text('AJUSTES DE MiR',
                  style: TextStyle(color: _foreground, fontSize: 14,
                    fontWeight: FontWeight.w700))),
              ]),
            ),
          if (!_inSettings) Container(
            padding: const EdgeInsets.fromLTRB(15, 1, 15, 12),
            child: LayoutBuilder(builder: (context, c) {
              final width = c.maxWidth;
              return Wrap(spacing: 7, runSpacing: 7,
                children: List.generate(_sections.length, (index) {
                  final selected = _section == index;
                  final maxWidth = width < 770 ? (width - 7) / 2 : (width - 21) / 4;
                  return SizedBox(
                    width: maxWidth,
                    height: 39,
                    child: OutlinedButton(
                      onPressed: () => setState(() => _section = index),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: selected ? _accent : _foreground,
                        backgroundColor: selected ? _field : _card,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        side: BorderSide(color: selected ? _accent : _edge),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(_sections[index], maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: width < 580 ? 11 : 12.5)),
                    ),
                  );
                }),
              );
            }),
          ),
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
            child: _body(),
          )),
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _edge))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              const Expanded(child: Text(
                'MiR V2 | Desarrollado por EcoEtika S.A.S. | Distribución gratuita',
                style: TextStyle(color: _muted, fontSize: 10),
                maxLines: 2)),
              const SizedBox(width: 8),
              Offstage(offstage: true, child: OnlineStatusWidget()),
              const SizedBox(width: 5),
              Obx(() {
                final current = stateGlobal.svcStatus.value;
                final ready = current == SvcStatus.ready;
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, size: 8,
                    color: ready ? _accent : _warning),
                  const SizedBox(width: 6),
                  Text(ready ? 'Conectado' : 'Revisar conexión',
                    style: TextStyle(
                      color: ready ? _accent : _warning, fontSize: 11)),
                ]);
              }),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Capability extends StatelessWidget {
  const _Capability(this.icon, this.title);
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 13),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _edge),
      ),
      child: Row(children: [
        Icon(icon, color: _accent, size: 21),
        const SizedBox(width: 10),
        Expanded(child: Text(title,
          style: const TextStyle(color: _foreground, fontSize: 12.5))),
      ]),
    );
  }
}
