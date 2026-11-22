#!/usr/bin/env python3
"""MiR V2: pruebas de identidad sobre el árbol real del cliente Flutter/Rust."""
from __future__ import annotations
import argparse
from pathlib import Path

def main() -> None:
    arg = argparse.ArgumentParser()
    arg.add_argument("--upstream", required=True, type=Path)
    opts = arg.parse_args()
    root = opts.upstream
    def read(path: str) -> str:
        return (root / path).read_text(encoding="utf-8")

    core = read("src/core_main.rs")
    assert '*config::APP_NAME.write().unwrap() = "MiR".to_owned();' in core
    cmake = read("flutter/windows/CMakeLists.txt")
    assert 'set(BINARY_NAME "MiR")' in cmake
    assert 'set(BINARY_NAME "rustdesk")' not in cmake
    cpp = read("flutter/windows/runner/main.cpp")
    assert 'std::wstring app_name = L"MiR"' in cpp
    assert 'LoadLibraryA("librustdesk.dll")' in cpp  # la biblioteca interna permanece
    resource = read("flutter/windows/runner/Runner.rc")
    for token in (
        'VALUE "InternalName", "MiR"',
        'VALUE "OriginalFilename", "MiR.exe"',
        'VALUE "ProductName", "MiR"',
        'VALUE "CompanyName", "EcoEtika S.A.S."',
        'VALUE "LegalCopyright", "Copyright'
    ):
        assert token in resource, token

    home = read("flutter/lib/desktop/pages/desktop_home_page.dart")
    assert "child: loadPowered(context)" not in home
    assert "assets/MiR_logo.png" in home
    about = read("flutter/lib/desktop/pages/desktop_setting_page.dart")
    assert "MiR V2 | Desarrollado por EcoEtika S.A.S." in about
    assert "Desarrollado sobre la base de RustDesk (AGPL-3.0)" in about

    for path in ("res/icon.ico", "res/tray-icon.ico", "res/icon.png"):
        assert (root / path).stat().st_size > 1000, path
    print("OK: ejecutable MiR.exe, servicio MiR, nombre de ventana y logos propios.")
    print("OK: licencia y motor internamente conservados.")
    print("ATENCION: las pruebas de código no prueban recepción tras reinicio/antes del PIN.")

if __name__ == "__main__":
    main()
