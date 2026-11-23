#!/usr/bin/env python3
"""Verificación estructural de la ventana receptora MiR: no sustituye una sesión real."""
import argparse
from pathlib import Path

def verify(root: Path) -> None:
    s=(root/"flutter/lib/desktop/pages/server_page.dart").read_text(encoding="utf-8")
    for part in (
        "MiRConnectionTheme(child: ConnectionManager())",
        "Permisos de la sesión",
        "Llamada entrante",
        "Llamada de voz activa",
        "Aceptar",
        "Rechazar",
        "Finalizar llamada",
        "Micrófono",
        "_miRCallCard(",
        "cmSwitchPermission(",
        "cmHandleIncomingVoiceCall(",
        "cmCloseVoiceCall(",
        "cmCloseConnection(",
        "AudioInput.getDevicesInfo(",
        "AudioInput.setDevice(",
        "buildPermissionIcon(",
    ):
        if part not in s:
            raise RuntimeError("Receptor MiR: falta " + part)
    if "Color(0xff0071ff)" in s or "Color(0xff00bfe1)" in s:
        raise RuntimeError("Receptor MiR: sigue activa la cabecera azul heredada")
    if s.count("_miRCallCard(") != 3:
        raise RuntimeError("Receptor MiR: falta panel entrante o activo")
    print("OK: receptor MiR, permisos, llamada entrante y activa.")
    print("Pendiente prueba funcional de llamada entre equipos Windows/Android.")

if __name__ == "__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--upstream",type=Path,required=True)
    verify(p.parse_args().upstream)
