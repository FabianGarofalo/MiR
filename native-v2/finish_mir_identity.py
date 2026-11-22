#!/usr/bin/env python3
"""MiR | Identidad nativa Windows: nombre de proceso y servicio, recursos y versión.
El cliente RustDesk se utiliza como MOTOR, no como aplicación externa.
El cambio no instala servicios ni migra contraseñas.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

PINNED = "95cca3f661f635b3cc85c04935fe8d96d8f432ef"

def change_once(root: Path, path: str, from_text: str, to_text: str, changes: list):
    target = root / path
    text = target.read_text(encoding="utf-8")
    n = text.count(from_text)
    if n != 1:
        raise RuntimeError(f"Ancla inesperada en {path}: {n} apariciones de {from_text[:80]!r}")
    target.write_text(text.replace(from_text, to_text, 1), encoding="utf-8")
    changes.append(path)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream", type=Path, required=True)
    parser.add_argument("--repo", type=Path, default=Path("."))
    parser.add_argument("--report", type=Path, default=Path("native-v2/identity-report.json"))
    args = parser.parse_args()
    root = args.upstream.resolve()
    repo = args.repo.resolve()
    revision = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    if revision != PINNED:
        raise RuntimeError(f"Origen no fijado: {revision}")
    changes = []

    # El NOMBRE DE PRODUCTO determina también el nombre del servicio nativo.
    # Lo fijamos dentro del núcleo Rust, no con un simple cambio de nombre del EXE.
    change_once(root, "src/core_main.rs",
        "    crate::load_custom_client();",
        """    crate::load_custom_client();
    // MiR para Windows: nombre propio del proceso, servicio e instalación.
    // No depende de archivos de personalización firmados por terceros.
    #[cfg(windows)]
    {
        *config::APP_NAME.write().unwrap() = "MiR".to_owned();
    }""", changes)

    # Nombre físico generado por CMake y Flutter.
    change_once(root, "flutter/windows/CMakeLists.txt",
        'set(BINARY_NAME "rustdesk")',
        'set(BINARY_NAME "MiR")', changes)
    change_once(root, "flutter/windows/runner/main.cpp",
        'std::wstring app_name = L"RustDesk";',
        'std::wstring app_name = L"MiR";', changes)
    change_once(root, "flutter/windows/runner/main.cpp",
        'window_title = app_name + L" - Connection Manager";',
        'window_title = app_name + L" - Administrador de conexiones";', changes)
    change_once(root, "flutter/windows/runner/main.cpp",
        'window_title = app_name + L" - Install";',
        'window_title = app_name + L" - Instalación";', changes)
    change_once(root, "flutter/windows/runner/Runner.rc",
        'VALUE "InternalName", "rustdesk"',
        'VALUE "InternalName", "MiR"', changes)
    change_once(root, "flutter/windows/runner/Runner.rc",
        'VALUE "OriginalFilename", "rustdesk.exe"',
        'VALUE "OriginalFilename", "MiR.exe"', changes)

    # En las versiones de marca blanca el origen muestra "Powered by RustDesk"
    # en la portada. La atribución permanece en Acerca de y en LICENCE.
    change_once(root, "flutter/lib/desktop/pages/desktop_home_page.dart",
        """      if (bind.isCustomClient())
        Align(
          alignment: Alignment.center,
          child: loadPowered(context),
        ),
""", "", changes)

    # En el panel de Acerca de sí debe mantenerse el crédito del motor.
    # Ajustar solamente el número visible de versión de este paquete.
    change_once(root, "flutter/lib/desktop/pages/desktop_setting_page.dart",
        "MiR V1 | Desarrollado por EcoEtika S.A.S. | Distribución gratuita",
        "MiR V2 | Desarrollado por EcoEtika S.A.S. | Distribución gratuita", changes)

    # Otras etiquetas visibles que tienen texto fijo y no usan get_app_name().
    change_once(root, "flutter/lib/desktop/widgets/tabbar_widget.dart",
        '''                              "RustDesk",
''', '''                              "MiR",
''', changes)
    change_once(root, "src/platform/windows.rs",
        'let caption = "RustDesk Output"',
        'let caption = "MiR"', changes)

    # Recursos comunes del motor: iconos de aplicación, bandeja y capturas.
    ico = repo / "legacy-v1.5/payload/MiRemoto.ico"
    png = repo / "legacy-v1.5/payload/assets/MiR_icono.png"
    if not ico.is_file() or not png.is_file():
        raise RuntimeError("Faltan los recursos originales de MiR")
    assets = {
        "res/icon.ico": ico,
        "res/tray-icon.ico": ico,
        "res/icon.png": png,
    }
    for dest, src in assets.items():
        shutil.copyfile(src, root / dest)
        changes.append(dest)

    # No cambiamos el nombre de la DLL interna librustdesk.dll:
    # el motor la carga explícitamente y no es una aplicación separada.
    report = {
        "upstream_revision": revision,
        "product_name": "MiR",
        "executable_name": "MiR.exe",
        "windows_service_name": "MiR",
        "internal_engine_library": "librustdesk.dll",
        "all_resources_attached": True,
        "patched": sorted(set(changes)),
        "sha256": {p: hashlib.sha256((root / p).read_bytes()).hexdigest()
                   for p in sorted(set(changes))},
        "service_installed": False,
        "host_independence_verified": False,
        "full_native_build_verified": False,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
