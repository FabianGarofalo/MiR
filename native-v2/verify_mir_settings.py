#!/usr/bin/env python3
"""Inspección reproducible de navegación, identidad y créditos MiR.

Las pruebas visuales y de conexión requieren ejecutar el EXE en Windows.
"""
from pathlib import Path
import argparse
import hashlib

def check(root: Path):
    def source(path): return (root / path).read_text(encoding="utf-8")

    shell = source("flutter/lib/mir/mir_home_shell.dart")
    router = source("flutter/lib/mir/mir_settings_router.dart")
    settings = source("flutter/lib/desktop/pages/desktop_setting_page.dart")
    tabs = source("flutter/lib/desktop/pages/desktop_tab_page.dart")
    title = source("flutter/lib/desktop/widgets/tabbar_widget.dart")
    about = source("flutter/lib/mir/mir_about_page.dart")

    assert "Volver a MiR" in shell and "_backToMiR" in shell
    assert "DesktopSettingPage(" in shell and "_inSettings" in shell
    assert "MiRSettingsRouter.revision.addListener" in shell
    assert "MiRSettingsRouter.revision.removeListener" in shell
    assert "MiRSettingsRouter.open(DesktopSettingPage.tabKeys.indexOf(page))" in shell
    assert "MiRSettingsRouter.open(DesktopSettingPage.tabKeys.indexOf(initialPage))" in tabs
    assert "homeMounted" in router and "revision.value += 1" in router
    assert "children.add(const MiRAboutPage());" in settings
    for legacy in ("About RustDesk", "Slogan_tip", "Purslane Tech Pte. Ltd.",
                   "https://rustdesk.com/privacy.html", "https://rustdesk.com"):
        assert legacy not in settings, f"Marca heredada en Ajustes: {legacy}"
    assert "SingleChildScrollView(" in settings and "PageView(" in settings
    for heading in ("General", "Seguridad", "Red", "Pantalla",
                    "Cuenta", "Impresora", "Acerca de MiR"):
        assert heading in settings, heading
    assert "Text('AJUSTES DE MiR'" in shell
    assert "'assets/MiR_icono.png'" in title
    assert '"MiR",' in title
    icon = root / "flutter/assets/icon.png"
    mi = root / "flutter/assets/MiR_icono.png"
    assert icon.exists() and mi.exists()
    assert hashlib.sha256(icon.read_bytes()).digest() == hashlib.sha256(mi.read_bytes()).digest()
    assert "'assets/MiR_logo.png'" in about
    assert "'assets/EcoEtika_logo.png'" in about
    assert "'https://www.ecoetika.com/'" in about
    assert "Créditos y licencias de terceros" in about
    assert "Purslane Tech Pte. Ltd." in about
    assert "AGPL-3.0" in about
    assert "Slogan_tip" not in about
    assert "Copyright © ${DateTime.now()" not in about
    assert "https://rustdesk.com/privacy.html" not in about
    assert "https://rustdesk.com" not in about
    print("MiR: portada, Ajustes integrados, navegación de regreso, 7 secciones y créditos verificados.")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--upstream", required=True, type=Path)
    args = ap.parse_args()
    check(args.upstream)
