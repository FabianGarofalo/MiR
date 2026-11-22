#!/usr/bin/env python3
"""MiR V2 | Aplicar adaptación nativa al cliente remoto fijado.
NO instala servicios, NO toca credenciales, NO supone que el binario sea seguro de desinstalar.
La barra existente conserva sus acciones REALES mediante FFI y los permisos del motor.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

PINNED = "95cca3f661f635b3cc85c04935fe8d96d8f432ef"
TOOLBAR = "flutter/lib/desktop/widgets/remote_toolbar.dart"
MODEL = "flutter/lib/models/model.dart"
TITLEBAR = "flutter/lib/desktop/widgets/titlebar_widget.dart"
RESOURCE = "flutter/windows/runner/Runner.rc"
PUBSPEC = "flutter/pubspec.yaml"

def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: ancla cambió (esperado 1, obtenido {count})")
    return text.replace(old, new, 1)

def require_upstream(root: Path) -> str:
    if not (root / ".git").exists():
        raise RuntimeError("El árbol de origen debe ser un checkout Git")
    sha = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    if sha != PINNED:
        raise RuntimeError(f"Versión de origen no reconocida: {sha}; esperado {PINNED}")
    for item in (TOOLBAR, MODEL, TITLEBAR, RESOURCE, PUBSPEC):
        if not (root / item).is_file():
            raise RuntimeError(f"Falta fuente: {item}")
    return sha

def write_text(root: Path, relative: str, data: str, changed: list[str]) -> None:
    (root / relative).write_text(data, encoding="utf-8")
    changed.append(relative)

def apply_native(root: Path, repo: Path) -> dict:
    upstream = require_upstream(root)
    changed: list[str] = []

    toolbar = (root / TOOLBAR).read_text(encoding="utf-8")
    for label, original, replacement in (
        ("Azul", "static const Color blueColor = MyTheme.button;", "static const Color blueColor = Color(0xFF0874F9);"),
        ("Azul hover", "static const Color hoverBlueColor = MyTheme.accent;", "static const Color hoverBlueColor = Color(0xFF1889FF);"),
        ("Rojo", "static const Color redColor = Colors.redAccent;", "static const Color redColor = Color(0xFFE94B50);"),
        ("Rojo hover", "static const Color hoverRedColor = Colors.red;", "static const Color hoverRedColor = Color(0xFFD93943);"),
        ("Radio botón", "static const double iconRadius = 8;", "static const double iconRadius = 11;"),
        ("Radio menú", "static double menuBorderRadius = isWindows ? 5.0 : 7.0;", "static double menuBorderRadius = 12.0;"),
        ("Radio menú interno", "static const double menuButtonBorderRadius = 3.0;", "static const double menuButtonBorderRadius = 9.0;"),
        ("Radio barra", "final toolbarBorderRadius = BorderRadius.all(Radius.circular(4.0));", "final toolbarBorderRadius = BorderRadius.all(Radius.circular(12.0));"),
    ):
        toolbar = replace_once(toolbar, original, replacement, label)
    # Las acciones nativas de la barra se conservan: _MobileActionMenu,
    # _MonitorMenu, _ControlMenu, _DisplayMenu, _KeyboardMenu, _VoiceCallMenu,
    # _RecordMenu y _CloseMenu. No superponer otro widget.
    for action in ("_PinMenu(", "_ControlMenu(", "_DisplayMenu(", "_KeyboardMenu(",
                   "_VoiceCallMenu(", "_RecordMenu(", "_CloseMenu("):
        if action not in toolbar:
            raise RuntimeError(f"Acción nativa faltante: {action}")
    # Acción de llamada: si no hay llamada activa, mostrar control para iniciarla
    # usando la función real del motor (antes la UI la ocultaba).
    toolbar = replace_once(
        toolbar,
        """          default:
            return Offstage();
        }
      },
    );
  }

  Widget buildCallWaiting(BuildContext context) {""",
        """          default:
            return _IconMenuButton(
              assetName: 'assets/voice_call.svg',
              tooltip: 'Voice call',
              onPressed: () =>
                  bind.sessionRequestVoiceCall(sessionId: ffi.sessionId),
              color: _ToolbarTheme.blueColor,
              hoverColor: _ToolbarTheme.hoverBlueColor,
            );
        }
      },
    );
  }

  Widget buildCallWaiting(BuildContext context) {""",
        "Habilitar llamada de voz real"
    )
    write_text(root, TOOLBAR, toolbar, changed)

    titlebar = (root / TITLEBAR).read_text(encoding="utf-8")
    for label, old, new in (
        ("Azul título", "const sidebarColor = Color(0xFF0C6AF6);", "const sidebarColor = Color(0xFF0874F9);"),
        ("Fondo inicio", "const backgroundStartColor = Color(0xFF0583EA);", "const backgroundStartColor = Color(0xFF08191A);"),
        ("Fondo fin", "const backgroundEndColor = Color(0xFF0697EA);", "const backgroundEndColor = Color(0xFF102C2C);"),
    ):
        titlebar = replace_once(titlebar, old, new, label)
    write_text(root, TITLEBAR, titlebar, changed)

    # La cabecera nativa mostrará la marca MiR directamente en Flutter.
    home_rel = "flutter/lib/desktop/pages/desktop_home_page.dart"
    home = (root / home_rel).read_text(encoding="utf-8")
    home = replace_once(
        home, "child: loadLogo(),",
        """child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Image.asset('assets/MiR_logo.png',
              width: 170, fit: BoxFit.contain),
        ),""",
        "Logo MiR dentro del cliente"
    )
    write_text(root, home_rel, home, changed)

    settings_rel = "flutter/lib/desktop/pages/desktop_setting_page.dart"
    settings = (root / settings_rel).read_text(encoding="utf-8")
    settings = replace_once(
        settings, "child: _Card(title: translate('About RustDesk'), children: [",
        """child: _Card(title: 'Acerca de MiR', children: [
          Image.asset('assets/MiR_logo.png', height: 46,
            fit: BoxFit.contain),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('MiR V1 | Desarrollado por EcoEtika S.A.S. | Distribución gratuita'),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Desarrollado sobre la base de RustDesk (AGPL-3.0).'),
          ),
          Image.asset('assets/EcoEtika_logo.png',
            height: 38, fit: BoxFit.contain),""",
        "Acerca de MiR con atribución legal"
    )
    write_text(root, settings_rel, settings, changed)

    for name in ("MiR_logo.png", "EcoEtika_logo.png"):
        branding_src = repo / "legacy-v1.5/payload/assets" / name
        if not branding_src.is_file():
            raise RuntimeError(f"Falta recurso visual: {name}")
        branding_dst = root / "flutter/assets" / name
        shutil.copyfile(branding_src, branding_dst)
        changed.append(f"flutter/assets/{name}")

    model = (root / MODEL).read_text(encoding="utf-8")
    model = replace_once(
        model, "import 'dart:async';",
        "import 'dart:async';\nimport '../mir/mir_connection_policy.dart';",
        "Import política"
    )
    model = replace_once(
        model, "class FfiModel with ChangeNotifier {",
        """class FfiModel with ChangeNotifier {
  // MiR: cierra una sesión establecida luego de desconexión prolongada.
  // El receptor local no se detiene, no se borran credenciales.
  late final MiRConnectionPolicy _miRConnectionPolicy =
      MiRConnectionPolicy(closeSession: () => closeConnection());""",
        "Modelo sesión"
    )
    model = replace_once(
        model, "    resetRestartReconnectState();\n    clearPermissions();",
        "    resetRestartReconnectState();\n    if (isWindows) _miRConnectionPolicy.dispose();\n    clearPermissions();",
        "Liberar temporizador"
    )
    model = replace_once(
        model, "      } else if (name == 'connection_ready') {\n        setConnectionType(",
        "      } else if (name == 'connection_ready') {\n        if (isWindows) _miRConnectionPolicy.onConnected();\n        setConnectionType(",
        "Sesión conectada"
    )
    model = replace_once(
        model,
        "    // Disable relative mouse mode on any error-type message to ensure cursor is released.",
        """    // MiR: si la sesión estuvo conectada y se pierde la comunicación,
    // permitir un máximo de 15 segundos para volver antes de cerrar la pestaña.
    // No aplica durante autenticación ni a solicitudes de clave o 2FA.
    if (isWindows && (type == 'restarting' ||
        type == 'restarting-show' || title == 'Connection Error')) {
      _miRConnectionPolicy.onConnectionLost();
    }

    // Disable relative mouse mode on any error-type message to ensure cursor is released.""",
        "Sesión interrumpida"
    )
    write_text(root, MODEL, model, changed)

    src_policy = repo / "native_pending/lib/mir_connection_policy.dart"
    if not src_policy.is_file():
        raise RuntimeError("Falta política MiR fuente")
    dst_policy = root / "flutter/lib/mir/mir_connection_policy.dart"
    dst_policy.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src_policy, dst_policy)
    changed.append("flutter/lib/mir/mir_connection_policy.dart")

    meta = (root / RESOURCE).read_text(encoding="utf-8")
    for label, old, new in (
        ("Empresa", 'VALUE "CompanyName", "Purslane Tech Pte. Ltd."',
         'VALUE "CompanyName", "EcoEtika S.A.S."'),
        ("Descripción", 'VALUE "FileDescription", "RustDesk Remote Desktop"',
         'VALUE "FileDescription", "MiR | Acceso remoto"'),
        ("Producto", 'VALUE "ProductName", "RustDesk"',
         'VALUE "ProductName", "MiR"'),
    ):
        meta = replace_once(meta, old, new, label)
    # Preservar OriginalFilename y LegalCopyright del origen para no atribuir
    # propiedad del código previo a EcoEtika ni interferir con componentes nativos.
    write_text(root, RESOURCE, meta, changed)

    icon = repo / "legacy-v1.5/payload/MiRemoto.ico"
    if icon.is_file():
        target_icon = root / "flutter/windows/runner/resources/app_icon.ico"
        target_icon.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(icon, target_icon)
        changed.append("flutter/windows/runner/resources/app_icon.ico")
    else:
        raise RuntimeError("No se encontró el ícono MiR para el ejecutable")

    pubspec = (root / PUBSPEC).read_text(encoding="utf-8")
    pubspec = replace_once(pubspec, "description: Your Remote Desktop Software",
                           "description: MiR | Acceso remoto - EcoEtika S.A.S.",
                           "Descripción")
    write_text(root, PUBSPEC, pubspec, changed)

    report = {
        "source_revision": upstream,
        "actions": "reused_upstream_live_actions",
        "native_session_disconnect": "integrated_into_FfiModel_on_connection_ready_and_errors",
        "changed_files": [
            {"path": path, "sha256": hashlib.sha256((root / path).read_bytes()).hexdigest()}
            for path in changed
        ],
        "remote_host_tested": False,
        "binary_compiled": False,
        "safe_to_uninstall_original": False,
        "notes": [
            "El servicio receptor y el binario de Rust todavía tienen nombres técnicos originales.",
            "No reemplazar ni desinstalar el servicio existente sin pruebas en Windows.",
            "Conservar LICENSE y avisos AGPL-3.0 del origen."
        ]
    }
    return report

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream", type=Path, required=True)
    parser.add_argument("--repo", type=Path, default=Path("."))
    parser.add_argument("--report", type=Path, default=Path("native-v2/native-patch-report.json"))
    args = parser.parse_args()
    report = apply_native(args.upstream.resolve(), args.repo.resolve())
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()
