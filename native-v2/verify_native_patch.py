#!/usr/bin/env python3
"""Prueba estructural del parche nativo MiR (no es prueba de conexión real)."""
from __future__ import annotations
import argparse
from pathlib import Path

def verify(root: Path) -> None:
    toolbar = (root / "flutter/lib/desktop/widgets/remote_toolbar.dart").read_text(encoding="utf-8")
    model = (root / "flutter/lib/models/model.dart").read_text(encoding="utf-8")
    assert "static const Color blueColor = Color(0xFF0874F9);" in toolbar
    assert "BorderRadius.all(Radius.circular(12.0))" in toolbar
    # Se reutilizan los controles realmente conectados al motor nativo.
    for token in ("_ControlMenu(", "_DisplayMenu(", "_KeyboardMenu(",
                  "_RecordMenu(", "_VoiceCallMenu(", "_CloseMenu("):
        assert token in toolbar, f"Falta acción: {token}"
    # Eventos REALES de conexión y error; el receptor no se debe cerrar.
    assert "_miRConnectionPolicy.onConnected();" in model
    assert "_miRConnectionPolicy.onConnectionLost();" in model
    assert "MiRConnectionPolicy(closeSession: () => closeConnection())" in model
    assert (root / "flutter/lib/mir/mir_connection_policy.dart").is_file()
    resource = (root / "flutter/windows/runner/Runner.rc").read_text(encoding="utf-8")
    assert 'VALUE "ProductName", "MiR"' in resource
    assert 'VALUE "CompanyName", "EcoEtika S.A.S."' in resource
    assert 'VALUE "LegalCopyright", "Copyright' in resource
    icon = root / "flutter/windows/runner/resources/app_icon.ico"
    assert icon.is_file() and icon.stat().st_size > 1000
    print("MiR: adaptación de interfaz, eventos y atribución verificada (sin compilar).")

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--upstream", type=Path, required=True)
    args = p.parse_args()
    verify(args.upstream)
