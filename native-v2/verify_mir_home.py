#!/usr/bin/env python3
"""Validación estructural de la pantalla MiR nativa, no reemplaza la prueba visual."""
from __future__ import annotations

import argparse
from pathlib import Path

def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--upstream", type=Path, required=True)
    opts = p.parse_args()
    root = opts.upstream
    home = (root / "flutter/lib/desktop/pages/desktop_home_page.dart").read_text(encoding="utf-8")
    shell = (root / "flutter/lib/mir/mir_home_shell.dart").read_text(encoding="utf-8")

    assert "return _buildBlock(child: const MiRHomeShell());" in home
    assert "import 'package:flutter_hbb/mir/mir_home_shell.dart';" in home
    for label in ("Mis equipos", "Mi equipo / Receptor",
                  "Sesiones y archivos", "Diagnóstico"):
        assert label in shell, label
    for color in ("0xFF0B191A", "0xFF132629", "0xFF193236",
                  "0xFF315052", "0xFF75E0C1"):
        assert color in shell, color
    assert "PeerTabPage()" in shell
    assert "connect(context, id, isFileTransfer: files)" in shell
    assert "model.serverId.text" in shell
    assert "model.serverPasswd.text" in shell
    assert "bind.mainUpdateTemporaryPassword()" in shell
    assert "bind.mainGetConnectStatus()" in shell
    assert "OnlineStatusWidget()" in shell
    for text in ("SvcStatus.connecting", "'Conectando…'", "'Sin conexión'",
                 "'Abrir diagnóstico de conexión'", "_diagnosticTick++"):
        assert text in shell, f"Estado de conexión sin diagnóstico: {text}"
    assert "'Revisar conexión'" not in shell
    assert "Image.asset('assets/MiR_logo.png'" in shell
    assert "El modo portable debería recibir conexiones" in shell
    assert "MiRReceiverDiagnostics()" in shell
    receiver = (root / "flutter/lib/mir/mir_receiver_diagnostics.dart").read_text(encoding="utf-8")
    for check in ("mainGetBoolOption(kOptionStopService)",
                  "mainSetBoolOption(kOptionStopService, false)",
                  "bind.mainGetMyId()", "bind.mainGetConnectStatus()",
                  "Habilitar recepción"):
        assert check in receiver, check
    assert "MiR V2 | Desarrollado por EcoEtika S.A.S." in shell
    assert "mainGotoInstall(" not in shell
    assert "Stop-Service" not in shell
    assert "RustDesk.exe" not in shell
    assert "rustdesk.exe" not in shell
    print("MiR V2: portada propia, cuatro áreas y llamadas nativas verificadas en código.")

if __name__ == "__main__":
    main()
