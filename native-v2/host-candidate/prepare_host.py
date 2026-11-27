#!/usr/bin/env python3
"""Preparar un candidato de receptor MiR SIN alterar el nombre del servicio RustDesk.

IMPORTANTE: El host debe compilar el motor nativo original desde la revision
fijada. No se renombra MiR.exe y no se utiliza la DLL del cliente MiR.
Esta herramienta solo modifica el checkout desechable del CI, NO el equipo.
"""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

PINNED = "95cca3f661f635b3cc85c04935fe8d96d8f432ef"


def cmd(*args: str) -> None:
    subprocess.run(args, check=True)


def ensure_one(path: Path, before: str, after: str) -> None:
    text = path.read_text(encoding="utf-8")
    if text.count(before) != 1:
        raise RuntimeError(f"Ancla inesperada: {path.name}: {before[:75]!r}")
    path.write_text(text.replace(before, after, 1), encoding="utf-8")


def verify_unmodified_service_identity(upstream: Path) -> None:
    main = (upstream / "src/core_main.rs").read_text(encoding="utf-8")
    cmake = (upstream / "flutter/windows/CMakeLists.txt").read_text(encoding="utf-8")
    runner = (upstream / "flutter/windows/runner/main.cpp").read_text(encoding="utf-8")
    # El servicio V1 existente se llama RustDesk: el host candidato conserva
    # esa identidad tecnica. La interfaz visible se identifica como MiR.
    if 'APP_NAME.write().unwrap() = "MiR"' in main:
        raise RuntimeError("BLOQUEADO: el motor del host no puede renombrar el servicio a MiR")
    if 'set(BINARY_NAME "rustdesk")' not in cmake:
        raise RuntimeError("BLOQUEADO: host sin ejecutable nativo RustDesk")
    if 'std::wstring app_name = L"RustDesk";' not in runner:
        raise RuntimeError("BLOQUEADO: cambiar el nombre del servicio puede invalidar SCM")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--upstream", type=Path, required=True)
    p.add_argument("--repo", type=Path, required=True)
    args = p.parse_args()
    upstream, repo = args.upstream.resolve(), args.repo.resolve()
    revision = subprocess.check_output(
        ["git", "-C", str(upstream), "rev-parse", "HEAD"], text=True
    ).strip()
    if revision != PINNED:
        raise RuntimeError("Revision RustDesk no verificada: " + revision)

    verify_unmodified_service_identity(upstream)
    base = repo / "native-v2"
    cmd("python", str(base / "stage_components.py"),
        "--upstream", str(upstream),
        "--components", str(repo / "native_pending/lib"),
        "--report", str(base / "host-stage-report.json"))
    cmd("python", str(base / "apply_mir_native.py"),
        "--upstream", str(upstream), "--repo", str(repo),
        "--report", str(base / "host-native-report.json"))
    # NO aplicar finish_mir_identity.py: cambiaria APP_NAME del servicio
    # del host de RustDesk a MiR y haria fallar el arranque en un servicio V1.
    cmd("python", str(base / "apply_mir_home.py"),
        "--upstream", str(upstream), "--repo", str(repo),
        "--report", str(base / "host-home-report.json"))
    cmd("python", str(base / "apply_mir_settings.py"),
        "--upstream", str(upstream), "--repo", str(repo),
        "--report", str(base / "host-settings-report.json"))
    cmd("python", str(base / "apply_mir_connection_ui.py"),
        "--upstream", str(upstream), "--repo", str(repo),
        "--report", str(base / "host-ui-report.json"))

    patch_files = {
        "flutter/lib/desktop/pages/server_page.dart": "flutter/mir_server_page.dart",
        "flutter/lib/mir/mir_receiver_layout.dart": "flutter/mir_receiver_layout.dart",
        "flutter/lib/mir/mir_receiver_process_probe.dart": "flutter/mir_receiver_process_probe.dart",
        "flutter/test/mir_receiver_layout_test.dart": "flutter/test/mir_receiver_layout_test.dart",
        "flutter/test/mir_wake_on_lan_test.dart": "flutter/test/mir_wake_on_lan_test.dart",
    }
    import shutil
    for target, source in patch_files.items():
        dest = upstream / target
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(base / source, dest)

    # Solo la ventana receptora muestra nombre MiR; la identidad del servicio
    # que Windows registrara sigue siendo RustDesk (no alterar APP_NAME).
    runner = upstream / "flutter/windows/runner/main.cpp"
    ensure_one(runner,
               'window_title = app_name + L" - Connection Manager";',
               'window_title = L"MiR - Receptor";')
    # Ventana principal con marca MiR, SIN cambiar la identidad SCM RustDesk.
    ensure_one(runner,
               '  } else {\n    window_title = app_name;\n  }',
               '  } else {\n    window_title = L"MiR";\n  }')
    verify_unmodified_service_identity(upstream)

    # El dashboard solo necesita verificar la interfaz, el motor permanece
    # RustDesk hasta que las pruebas de servicio y recuperacion sean exitosas.
    cmd("python", str(base / "verify_mir_receiver_ui.py"),
        "--upstream", str(upstream))
    report = {
        "status": "SOURCE_PREPARED_ONLY",
        "upstream_commit": PINNED,
        "service_name": "RustDesk",
        "host_executable": "RustDesk.exe",
        "ui_title": "MiR - Receptor",
        "main_window_title": "MiR",
        "motor_recompiled_from_source": False,
        "service_tested": False,
        "user_host_modified": False,
        "migrator_available": False,
    }
    out = base / "host-identity-report.json"
    out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
