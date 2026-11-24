#!/usr/bin/env python3
"""Control de la interfaz MiR efectivamente compilada, no solo el fuente Dart.

Previene distribuir una portada MiR con los Ajustes antiguos del motor.
No acredita pruebas remotas reales ni firma digital.
"""
from __future__ import annotations

import argparse
from pathlib import Path

REQUIRED_TEXT = (
    "Volver a MiR",
    "AJUSTES DE MiR",
    "Acerca de MiR",
    "Seguridad",
    "Impresora",
)
REQUIRED_CLASSES = ("_MiRHomeShellState", "MiRAboutPage")


def check(portable: Path) -> None:
    portable = portable.resolve()
    exe = portable / "MiR.exe"
    snapshot = portable / "data" / "app.so"
    assets = portable / "data" / "flutter_assets" / "assets"
    engine = portable / "librustdesk.dll"

    corrector_ps = portable / "MiR_Corregir_Receptor.ps1"
    corrector_cmd = portable / "MiR_Corregir_Receptor.cmd"
    for path in (exe, snapshot, engine, assets / "MiR_logo.png",
                 assets / "EcoEtika_logo.png", assets / "MiR_icono.png",
                 corrector_ps, corrector_cmd):
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError(f"Falta un componente necesario: {path}")

    if (portable / "rustdesk.exe").exists():
        raise RuntimeError("Motor externo inesperado: rustdesk.exe")
    data = snapshot.read_bytes()
    if data[:4] != bytes.fromhex("7f454c46"):
        raise RuntimeError("Snapshot Flutter AOT inválido")
    for label in (*REQUIRED_TEXT, *REQUIRED_CLASSES,
                  "Proceso receptor real", "MiRReceiverRuntimeCard",
                  "Corregir receptor"):
        if label.encode("utf-8") not in data:
            raise RuntimeError(
                f"NO PUBLICAR: la interfaz compilada no contiene {label!r}. "
                "Puede haberse empaquetado la UI anterior."
            )
    ps_text = corrector_ps.read_text(encoding="utf-8")
    for needle in ("Get-CimInstance Win32_Process", "--cm",
                   "Stop-Process -Id", "Read-Host", "Start-Process"):
        if needle not in ps_text:
            raise RuntimeError("Corrector de receptor incompleto: " + needle)
    cmd_text = corrector_cmd.read_text(encoding="utf-8")
    if "MiR_Corregir_Receptor.ps1" not in cmd_text:
        raise RuntimeError("No esta integrada la herramienta Windows")
    print("OK: proceso receptor real identificable; corrector disponible.")
    print("OK: compilado Flutter MiR con regreso, Ajustes y Acerca de.")
    print("Pendiente: inspección visual interactiva y pruebas remotas Windows/Android.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--portable", type=Path, required=True)
    opts = parser.parse_args()
    check(opts.portable)
