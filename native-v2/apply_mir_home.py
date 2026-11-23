#!/usr/bin/env python3
"""Integra la portada nativa MiR sobre DesktopHomePage del motor fijado.

El motor remoto y sus widgets de sesiones siguen siendo nativos.
No crea funciones ficticias, no arranca/instala servicios y no consulta claves.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

ORIGINAL_BUILD = """  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isIncomingOnly = bind.isIncomingOnly();
    return _buildBlock(
        child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLeftPane(context),
        if (!isIncomingOnly) const VerticalDivider(width: 1),
        if (!isIncomingOnly) Expanded(child: buildRightPane(context)),
      ],
    ));
  }"""
MIR_BUILD = """  @override
  Widget build(BuildContext context) {
    super.build(context);
    // La ventana principal es MiR; se mantienen los eventos originales
    // de bloqueo, sesión, credenciales, conexión y receptor.
    return _buildBlock(child: const MiRHomeShell());
  }"""

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--upstream", type=Path, required=True)
    ap.add_argument("--repo", type=Path, default=Path("."))
    ap.add_argument("--report", type=Path, default=Path("native-v2/mir-home-report.json"))
    args = ap.parse_args()
    upstream = args.upstream.resolve()
    repo = args.repo.resolve()
    source = upstream / "flutter/lib/desktop/pages/desktop_home_page.dart"
    text = source.read_text(encoding="utf-8")
    if text.count(ORIGINAL_BUILD) != 1:
        raise RuntimeError("La pantalla inicial original cambió, no se puede reemplazar en forma segura.")
    if text.count("import 'package:flutter_hbb/common.dart';") != 1:
        raise RuntimeError("Falta import del motor")
    text = text.replace(
        "import 'package:flutter_hbb/common.dart';",
        "import 'package:flutter_hbb/common.dart';\n"
        "import 'package:flutter_hbb/mir/mir_home_shell.dart';",
        1,
    ).replace(ORIGINAL_BUILD, MIR_BUILD, 1)
    source.write_text(text, encoding="utf-8")

    origin = repo / "native-v2/flutter/mir_home_shell.dart"
    if not origin.is_file():
        raise RuntimeError("Falta la implementación nativa de la interfaz MiR.")
    target = upstream / "flutter/lib/mir/mir_home_shell.dart"
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(origin, target)
    report = {
        "home_replaced": True,
        "widget": "MiRHomeShell",
        "navigation": ["Mis equipos", "Mi equipo / Receptor",
                       "Sesiones y archivos", "Diagnóstico"],
        "motor": "original session controller and peer list, no second launcher",
        "sources": {
            "flutter/lib/desktop/pages/desktop_home_page.dart": hashlib.sha256(source.read_bytes()).hexdigest(),
            "flutter/lib/mir/mir_home_shell.dart": hashlib.sha256(target.read_bytes()).hexdigest(),
        },
        "security": "does not register, remove, or migrate receiver service",
        "build_validated": False,
        "live_ui_tested": False,
    }
    output = args.report
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))

if __name__ == "__main__":
    main()
