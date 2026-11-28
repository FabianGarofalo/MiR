#!/usr/bin/env python3
"""MiR: control estático de la interfaz remota en el árbol compilado.

No sustituye la prueba visual ni prueba una conexión entrante Windows/Android.
"""
import argparse
from pathlib import Path

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream", type=Path, required=True)
    args = parser.parse_args()
    root = args.upstream
    toolbar = (root / "flutter/lib/desktop/widgets/remote_toolbar.dart").read_text(encoding="utf-8")
    remote = (root / "flutter/lib/desktop/pages/remote_page.dart").read_text(encoding="utf-8")
    theme = (root / "flutter/lib/mir/mir_connection_theme.dart").read_text(encoding="utf-8")
    tabs = (root / "flutter/lib/desktop/widgets/tabbar_widget.dart").read_text(encoding="utf-8")

    for text in (
        "widget.tooltip, widget.icon, widget.assetName)",
        "widget.tooltip, widget.icon, widget.svg)",
        "_miRTooltip(widget.tooltip)",
        "Fijar barra de conexión",
        "Seleccionar pantalla",
        "Pantalla y visualización",
        "Acciones de control",
        "Mensajes y llamadas",
        "Iniciar grabación",
        "Cerrar conexión",
        "Color(0xFF193236)",
        "Color(0xFF75E0C1)",
        "_ControlMenu(", "_DisplayMenu(", "_KeyboardMenu(",
        "_VoiceCallMenu(", "_RecordMenu(", "_CloseMenu(",
        "bind.sessionRequestVoiceCall(sessionId: ffi.sessionId)",
        "Enviar Ctrl+Alt+Supr",
        "bind.sessionCtrlAltDel(sessionId: ffi.sessionId)",
    ):
        assert text in toolbar, "Falta componente visual o acción real: " + text
    for obsolete in (
        "static const Color blueColor = Color(0xFF0874F9);",
        "static const Color hoverBlueColor = Color(0xFF1889FF);",
    ):
        assert obsolete not in toolbar, "Color RustDesk anterior: " + obsolete
    assert "MiRConnectionTheme(" in remote
    assert "Builder(builder: (context) => buildBody(context))" in remote
    for part in ("popupMenuTheme:", "dialogTheme:", "tooltipTheme:",
                 "menuTheme:", "menuButtonTheme:", "menuBarTheme:"):
        assert part in theme, "Falta estilo de pantalla secundaria: " + part
    assert "selectedTabIconColor: Color(0xFF75E0C1)" in tabs
    assert "selectedTabBackgroundColor: Color(0xFF193236)" in tabs
    print("OK: iconos, paneles, menú, tooltip, diálogo, pestañas y motor conservado.")
    print("Pendiente: prueba visual con ventanas de sesión y receptor Windows real.")

if __name__ == "__main__":
    main()
