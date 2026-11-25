#!/usr/bin/env python3
"""Fix an upstream build.py packaging path in a disposable CI checkout only.

The original Rust and Flutter compilation succeeds, but upstream's packaging
assumes the virtual display DLL is in target/release/deps. Cargo normally emits
the cdylib in target/release. Do not silently omit the DLL.
"""
from __future__ import annotations
import argparse
from pathlib import Path

def main():
    cli = argparse.ArgumentParser()
    cli.add_argument("--upstream", type=Path, required=True)
    args = cli.parse_args()
    build_py = args.upstream / "build.py"
    source = build_py.read_text(encoding="utf-8")
    old = """    shutil.copy2('target/release/deps/dylib_virtual_display.dll',
                 flutter_build_dir_2)"""
    replacement = """    virtual_display_candidates = [
        Path('target/release/dylib_virtual_display.dll'),
        Path('target/release/deps/dylib_virtual_display.dll'),
    ]
    virtual_display_dll = next(
        (p for p in virtual_display_candidates if p.is_file()), None
    )
    if virtual_display_dll is None:
        raise FileNotFoundError(
            'Cargo compiled virtual-display crate but expected DLL is absent: '
            + ', '.join(str(p) for p in virtual_display_candidates)
        )
    if virtual_display_dll.stat().st_size < 10000:
        raise RuntimeError('Virtual display DLL too small, packaging blocked')
    Path(flutter_build_dir_2).mkdir(parents=True, exist_ok=True)
    shutil.copy2(str(virtual_display_dll), flutter_build_dir_2)
    print('MiR host: virtual display DLL bundled from', virtual_display_dll)"""
    if source.count(old) != 1:
        raise RuntimeError("Upstream build.py changed; refusing blind patch")
    if "from pathlib import Path" not in source:
        source = "from pathlib import Path\n" + source if not source.startswith("#!") else source.replace("\n", "\nfrom pathlib import Path\n", 1)
    source = source.replace(old, replacement)
    build_py.write_text(source, encoding="utf-8")
    print("Patched only disposable upstream/build.py; service source unchanged")

if __name__ == "__main__":
    main()
