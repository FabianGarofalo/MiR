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
        "SingleChildScrollView(",
        "primaryOnly: false",
        "primaryOnly: true",
        "buildAuthorizedFooter(context)",
        "Solicitud de acceso",
        "Revisá la solicitud antes de permitir el control remoto.",
        "buildUnAuthorized(context)",
        "_miRCallCard(",
    ):
        if part not in s:
            raise RuntimeError("Receptor MiR: falta " + part)
    # La zona variable se desplaza, y la zona de acciones queda fuera de
    # SingleChildScrollView. Evita el corte de «Desconectar» con llamada.
    layout=s[s.index("Widget buildConnectionCard"):s.index("class _AppIcon")]
    assert layout.index("SingleChildScrollView(") < layout.index("primaryOnly: true")
    assert layout.index("primaryOnly: false") < layout.index("primaryOnly: true")
    assert "Expanded(" in layout
    assert "border: Border(top: BorderSide(color: _miREdge" in layout
    if s.count("_CmControlPanel(client: client, primaryOnly: true)") != 1:
        raise RuntimeError("Falta botonera fija inferior")
    if "color: _miRCard" not in s[s.index("buildUnAuthorized"):s.index("Widget buildButton")]:
        raise RuntimeError("Solicitud de acceso sin tema propio")
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
