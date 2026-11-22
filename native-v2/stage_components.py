#!/usr/bin/env python3
"""MiR V2 | Comprobación estructural de la base nativa.

NO compila, no reescribe el motor ni certifica un cliente V2.
Copia componentes MiR pendientes a un árbol temporal para futuras integraciones.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

PINNED_UPSTREAM = "95cca3f661f635b3cc85c04935fe8d96d8f432ef"
REQUIRED = (
    "Cargo.toml",
    "flutter/pubspec.yaml",
    "flutter/lib/main.dart",
    "flutter/lib/desktop/pages/remote_page.dart",
    "flutter/lib/desktop/widgets/remote_toolbar.dart",
)

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream", required=True, type=Path)
    parser.add_argument("--components", type=Path, default=Path("native_pending/lib"))
    parser.add_argument("--report", type=Path, default=Path("native-v2/integration-report.json"))
    args = parser.parse_args()
    source = args.upstream.resolve()
    components = args.components.resolve()
    if not source.is_dir():
        raise SystemExit(f"No existe el árbol upstream: {source}")

    actual = subprocess.check_output(
        ["git", "-C", str(source), "rev-parse", "HEAD"], text=True
    ).strip()
    if actual != PINNED_UPSTREAM:
        raise SystemExit(f"Revisión upstream inesperada: {actual}")

    for rel in REQUIRED:
        if not (source / rel).is_file():
            raise SystemExit(f"Falta archivo base: {rel}")

    remote_page = (source / "flutter/lib/desktop/pages/remote_page.dart").read_text(
        encoding="utf-8"
    )
    if "RemoteToolbar" not in remote_page:
        raise SystemExit("No se encuentra RemoteToolbar en la página de sesión")

    originals = (
        "mir_session_toolbar.dart",
        "mir_connection_policy.dart",
    )
    target = source / "flutter/lib/mir"
    target.mkdir(parents=True, exist_ok=True)
    generated = []
    for name in originals:
        source_file = components / name
        if not source_file.is_file():
            raise SystemExit(f"Falta componente MiR: {source_file}")
        target_file = target / name
        shutil.copyfile(source_file, target_file)
        generated.append(
            {"path": str(target_file.relative_to(source)), "sha256": hashlib.sha256(target_file.read_bytes()).hexdigest()}
        )

    report = {
        "upstream": "rustdesk/rustdesk",
        "source_revision": actual,
        "structural_checks": list(REQUIRED),
        "mir_components_staged": generated,
        "wired_to_live_session": False,
        "native_binary_compiled": False,
        "safe_to_uninstall_existing_host": False,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))

if __name__ == "__main__":
    main()
