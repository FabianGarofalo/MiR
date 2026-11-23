#!/usr/bin/env python3
"""Aplicar Ajustes MiR a la fuente Flutter fijada.

Mantiene los controladores originales de permisos/red/impresora y reemplaza
navegación, contenedor, estilo y Acerca de. No modifica el servicio receptor.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import shutil
from pathlib import Path

def once(src: str, old: str, new: str, title: str) -> str:
    count = src.count(old)
    if count != 1:
        raise RuntimeError(f"{title}: esperado 1, encontrado {count}")
    return src.replace(old, new, 1)

def apply(upstream: Path, repo: Path) -> list[str]:
    changes = []
    for name in ("mir_about_page.dart", "mir_settings_router.dart"):
        source = repo / "native-v2/flutter" / name
        target = upstream / "flutter/lib/mir" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        changes.append(f"flutter/lib/mir/{name}")

    tabpath = "flutter/lib/desktop/pages/desktop_tab_page.dart"
    src = (upstream / tabpath).read_text(encoding="utf-8")
    src = once(src,
        "import 'package:flutter_hbb/common.dart';",
        "import 'package:flutter_hbb/common.dart';\nimport 'package:flutter_hbb/mir/mir_settings_router.dart';",
        "Import en navegación")
    src = once(src,
        """  static void onAddSetting(
      {SettingsTabKey initialPage = SettingsTabKey.general}) {
    try {""",
        """  static void onAddSetting(
      {SettingsTabKey initialPage = SettingsTabKey.general}) {
    // MiR: se muestra dentro de la portada, no como pestaña RustDesk separada.
    if (isWindows &&
        MiRSettingsRouter.open(DesktopSettingPage.tabKeys.indexOf(initialPage))) {
      return;
    }
    try {""",
        "Enrutamiento de Ajustes")
    (upstream / tabpath).write_text(src, encoding="utf-8")
    changes.append(tabpath)

    settingspath = "flutter/lib/desktop/pages/desktop_setting_page.dart"
    settings = (upstream / settingspath).read_text(encoding="utf-8")
    settings = once(settings,
        "import 'package:flutter_hbb/common.dart';",
        "import 'package:flutter_hbb/common.dart';\nimport 'package:flutter_hbb/mir/mir_about_page.dart';",
        "Import Acerca de MiR")
    settings = once(settings, "const Color _accentColor = MyTheme.accent;",
        "const Color _accentColor = Color(0xFF75E0C1);", "Acento MiR")
    settings = once(settings, "children.add(const _About());",
        "children.add(const MiRAboutPage());", "Acerca de real en MiR")

    a = settings.index("class _DesktopSettingPageState")
    start = settings.index("  @override\n  Widget build(BuildContext context) {\n    super.build(context);\n    return Scaffold(", a)
    end = settings.index("  Widget _header(BuildContext context) {", start)
    replacement = """  String _mirLabel(SettingsTabKey key) {
    switch (key) {
      case SettingsTabKey.general: return 'General';
      case SettingsTabKey.safety: return 'Seguridad';
      case SettingsTabKey.network: return 'Red';
      case SettingsTabKey.display: return 'Pantalla';
      case SettingsTabKey.account: return 'Cuenta';
      case SettingsTabKey.printer: return 'Impresora';
      case SettingsTabKey.about: return 'Acerca de MiR';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: const Color(0xFF0B191A),
      child: _buildBlock(
        children: <Widget>[
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
                decoration: const BoxDecoration(
                  color: Color(0xFF0B191A),
                  border: Border(bottom: BorderSide(color: Color(0xFF315052))),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _settingTabs().map((tab) => Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: Obx(() {
                        final selected = selectedTab.value == tab.key;
                        return OutlinedButton.icon(
                          onPressed: () {
                            final index = DesktopSettingPage.tabKeys.indexOf(tab.key);
                            if (index >= 0) {
                              controller.jumpToPage(index);
                              selectedTab.value = tab.key;
                            }
                          },
                          icon: Icon(selected ? tab.selected : tab.unselected, size: 17),
                          label: Text(_mirLabel(tab.key), maxLines: 1),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: selected
                                ? const Color(0xFF75E0C1)
                                : const Color(0xFFEDF6F3),
                            backgroundColor: selected
                                ? const Color(0xFF193236)
                                : const Color(0xFF132629),
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFF75E0C1)
                                  : const Color(0xFF315052),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                          ),
                        );
                      }),
                    )).toList(),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: const Color(0xFF0B191A),
                  child: PageView(
                    controller: controller,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _children(),
                  ),
                ),
              ),
            ],
          )),
        ],
      ),
    );
  }

"""
    settings = settings[:start] + replacement + settings[end:]
    (upstream / settingspath).write_text(settings, encoding="utf-8")
    changes.append(settingspath)

    tabs = "flutter/lib/desktop/widgets/tabbar_widget.dart"
    src = (upstream / tabs).read_text(encoding="utf-8")
    src = once(src, "child: loadIcon(16),",
        """child: Image.asset(
                             'assets/MiR_icono.png',
                             width: 19, height: 19,
                             fit: BoxFit.contain),""",
        "Icono global de ventana")
    (upstream / tabs).write_text(src, encoding="utf-8")
    changes.append(tabs)

    # Iconografía común visible en ventanas nativas y menús auxiliares.
    icon = repo / "legacy-v1.5/payload/assets/MiR_icono.png"
    if not icon.is_file():
        raise RuntimeError("Falta icono original MiR")
    icons = {
        "flutter/assets/MiR_icono.png": icon,
        "flutter/assets/icon.png": icon,
    }
    for dest, src in icons.items():
        path = upstream / dest
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, path)
        changes.append(dest)
    return changes

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--upstream", type=Path, required=True)
    ap.add_argument("--repo", type=Path, required=True)
    ap.add_argument("--report", type=Path, default=Path("native-v2/mir-settings-report.json"))
    args = ap.parse_args()
    changes = apply(args.upstream.resolve(), args.repo.resolve())
    obj = {"mir_settings": True, "tabs": 7, "integrated_navigation": True,
           "separate_window": False, "own_about_page": True,
           "old_labels_outside_legal": False,
           "changes": [{"path": p, "sha256": hashlib.sha256(
               (args.upstream / p).read_bytes()).hexdigest()} for p in changes]}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(obj, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(obj, ensure_ascii=False, indent=2))
