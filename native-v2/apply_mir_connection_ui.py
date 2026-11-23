#!/usr/bin/env python3
"""MiR V2: migración visual de la sesión remota SIN cambiar handlers ni FFI.

Se aplica DESPUÉS de apply_mir_native.py, finish_mir_identity.py y apply_mir_settings.py.
Las anclas son estrictas para no publicar un build silenciosamente incompleto.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

PALETTE = {
    "bg": "0xFF0B191A",
    "surface": "0xFF132629",
    "field": "0xFF193236",
    "edge": "0xFF315052",
    "accent": "0xFF75E0C1",
    "muted": "0xFFA4C3BB",
    "fg": "0xFFEDF6F3",
}

def replace(text: str, original: str, new: str, label: str) -> str:
    count = text.count(original)
    if count != 1:
        raise RuntimeError(
            f"MiR UI ({label}): se esperaba un único ancla y hay {count}. "
            "Se detiene la compilación para no generar una pantalla heredada."
        )
    return text.replace(original, new, 1)

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream", required=True, type=Path)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args()
    root = args.upstream.resolve()
    repo = args.repo.resolve()
    changed = []

    # Tema MiR compartido, permite estilizar menú, diálogos, títulos,
    # pestañas, ayudas y controles sin modificar lógica funcional.
    src = repo / "native-v2/flutter/mir_connection_theme.dart"
    if not src.is_file():
        raise RuntimeError("Falta tema de sesión MiR")
    target = root / "flutter/lib/mir/mir_connection_theme.dart"
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, target)
    changed.append("flutter/lib/mir/mir_connection_theme.dart")

    path = "flutter/lib/desktop/pages/remote_page.dart"
    remote = (root / path).read_text(encoding="utf-8")
    remote = replace(
        remote,
        "import '../widgets/remote_toolbar.dart';",
        "import '../widgets/remote_toolbar.dart';\n"
        "import 'package:flutter_hbb/mir/mir_connection_theme.dart';",
        "import de identidad para sesiones",
    )
    remote = replace(
        remote,
        "], child: buildBody(context)));",
        "], child: MiRConnectionTheme(\n"
        "          child: Builder(builder: (context) => buildBody(context)))));",
        "tema de la sesión en todas las ventanas remotas",
    )
    (root / path).write_text(remote, encoding="utf-8")
    changed.append(path)

    path = "flutter/lib/desktop/widgets/remote_toolbar.dart"
    toolbar = (root / path).read_text(encoding="utf-8")
    for label, old, new in [
        ("iconos base", "static const Color blueColor = Color(0xFF0874F9);",
         "static const Color blueColor = Color(0xFF193236);"),
        ("hover", "static const Color hoverBlueColor = Color(0xFF1889FF);",
         "static const Color hoverBlueColor = Color(0xFF285A53);"),
        ("inactivo", "static Color inactiveColor = Colors.grey[800]!;",
         "static const Color inactiveColor = Color(0xFF132629);"),
        ("hover inactivo", "static Color hoverInactiveColor = Colors.grey[850]!;",
         "static const Color hoverInactiveColor = Color(0xFF193236);"),
        ("rojo", "static const Color redColor = Color(0xFFE94B50);",
         "static const Color redColor = Color(0xFF754043);"),
        ("rojo hover", "static const Color hoverRedColor = Color(0xFFD93943);",
         "static const Color hoverRedColor = Color(0xFFAD5156);"),
        ("borde", """static Color borderColor(BuildContext context) =>
      MyTheme.color(context).border3 ?? MyTheme.border;""",
         """static Color borderColor(BuildContext context) =>
      const Color(0xFF315052);"""),
        ("separador", """static Color? dividerColor(BuildContext context) =>
      MyTheme.color(context).divider;""",
         """static Color? dividerColor(BuildContext context) =>
      const Color(0xFF315052);"""),
    ]:
        toolbar = replace(toolbar, old, new, label)

    toolbar = replace(
        toolbar,
        """  static MenuStyle defaultMenuStyle(BuildContext context) => MenuStyle(
        side: MaterialStateProperty.all(BorderSide(""",
        """  static MenuStyle defaultMenuStyle(BuildContext context) => MenuStyle(
        backgroundColor: const MaterialStatePropertyAll(Color(0xFF132629)),
        surfaceTintColor: const MaterialStatePropertyAll(Colors.transparent),
        shadowColor: const MaterialStatePropertyAll(Colors.black54),
        foregroundColor: const MaterialStatePropertyAll(Color(0xFFEDF6F3)),
        side: MaterialStateProperty.all(BorderSide(""",
        "fondo de todos los submenús",
    )

    # Barra flotante actual: menú y barra con el fondo y borde de MiR.
    toolbar = replace(
        toolbar,
        """      color: Theme.of(context)
          .menuBarTheme
          .style
          ?.backgroundColor
          ?.resolve(MaterialState.values.toSet()),
      child: SingleChildScrollView(""",
        """      color: const Color(0xFF132629),
      child: SingleChildScrollView(""",
        "fondo barra conexiones",
    )
    toolbar = replace(
        toolbar,
        """        shape: MaterialStatePropertyAll(BeveledRectangleBorder()),
      ).copyWith(
              backgroundColor:
                  Theme.of(context).menuBarTheme.style?.backgroundColor)),""",
        """        shape: MaterialStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12))),
      ).copyWith(
              backgroundColor: const MaterialStatePropertyAll(
                  Color(0xFF132629)))),""",
        "barra de menús con esquinas MiR",
    )

    # Todos los glyphs y ayudas salen de una única función MiR: se conservan
    # los onPressed, los submenús y sus invocaciones al motor.
    replacement = """
String _miRTooltip(String original) {
  switch (original) {
    case 'Pin Toolbar': return 'Fijar barra de conexión';
    case 'Unpin Toolbar': return 'Desfijar barra de conexión';
    case 'Mobile Actions': return 'Acciones móviles';
    case 'Select Monitor': return 'Seleccionar pantalla';
    case 'Control Actions': return 'Acciones de control';
    case 'Display Settings': return 'Pantalla y visualización';
    case 'Keyboard Settings': return 'Teclado';
    case 'Text chat': return 'Chat de texto';
    case 'Chat': return 'Mensajes y llamadas';
    case 'Voice call': return 'Llamada de voz';
    case 'Waiting': return 'Esperando respuesta';
    case 'Start session recording': return 'Iniciar grabación';
    case 'Stop session recording': return 'Detener grabación';
    case 'Close': return 'Cerrar conexión';
    default: return translate(original);
  }
}

IconData? _miRGlyph(String tooltip) {
  switch (tooltip) {
    case 'Pin Toolbar': case 'Unpin Toolbar':
      return Icons.push_pin_outlined;
    case 'Mobile Actions': return Icons.phone_android_rounded;
    case 'Select Monitor': return Icons.monitor_outlined;
    case 'Control Actions': return Icons.tune_rounded;
    case 'Display Settings': return Icons.display_settings_outlined;
    case 'Keyboard Settings': return Icons.keyboard_rounded;
    case 'Chat': case 'Text chat':
      return Icons.chat_bubble_outline_rounded;
    case 'Voice call': return Icons.call_outlined;
    case 'Waiting': return Icons.phone_in_talk_outlined;
    case 'Start session recording': case 'Stop session recording':
      return Icons.fiber_manual_record_rounded;
    case 'Close': return Icons.close_rounded;
    default: return null;
  }
}

Widget _miRActionIcon(String tooltip, Widget? existing, String? asset) {
  final glyph = _miRGlyph(tooltip);
  if (glyph != null) {
    return Icon(glyph, color: const Color(0xFF75E0C1), size: 20);
  }
  if (existing != null) return existing;
  if (asset == null) return const Icon(Icons.settings_outlined,
      color: Color(0xFF75E0C1), size: 20);
  return SvgPicture.asset(
    asset,
    colorFilter: const ColorFilter.mode(Color(0xFF75E0C1), BlendMode.srcIn),
    width: 20, height: 20,
  );
}
"""
    toolbar = replace(
        toolbar,
        "class _IconMenuButton extends StatefulWidget {",
        replacement + "\nclass _IconMenuButton extends StatefulWidget {",
        "iconografía unificada MiR",
    )

    toolbar = replace(
        toolbar,
        """    final icon = widget.icon ??
        SvgPicture.asset(
          widget.assetName!,
          colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
          width: _ToolbarTheme.buttonSize,
          height: _ToolbarTheme.buttonSize,
        );""",
        """    final icon = _miRActionIcon(
      widget.tooltip, widget.icon, widget.assetName);""",
        "iconos de acciones",
    )
    toolbar = replace(
        toolbar,
        """    final icon = widget.icon ??
        SvgPicture.asset(
          widget.svg!,
          colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
          width: _ToolbarTheme.buttonSize,
          height: _ToolbarTheme.buttonSize,
        );""",
        """    final icon = _miRActionIcon(
      widget.tooltip, widget.icon, widget.svg);""",
        "iconos de submenú",
    )
    # Los botones coloreados originales no centraban bien iconos Material.
    # Se reemplazan dos Ink, manteniendo sus menús e interacción.
    icon_deco = """                child: Ink(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(_ToolbarTheme.iconRadius),
                      color: hover ? widget.hoverColor : widget.color,
                    ),
                    child: icon)"""
    icon_new = """                child: Container(
                    width: _ToolbarTheme.buttonSize,
                    height: _ToolbarTheme.buttonSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(_ToolbarTheme.iconRadius),
                      border: Border.all(color: const Color(0xFF315052)),
                      color: hover ? widget.hoverColor : widget.color,
                    ),
                    child: icon)"""
    # El segundo botón tiene cuatro espacios más de indentación.
    submenu_deco = chr(10).join("    " + line for line in icon_deco.splitlines())
    submenu_new = chr(10).join("    " + line for line in icon_new.splitlines())
    if toolbar.count(icon_deco) != 1 or toolbar.count(submenu_deco) != 1:
        raise RuntimeError(
            "Anclas de icono y submenú cambiadas: " +
            f"{toolbar.count(icon_deco)}/{toolbar.count(submenu_deco)}")
    toolbar = toolbar.replace(icon_deco, icon_new, 1)
    toolbar = toolbar.replace(submenu_deco, submenu_new, 1)

    if toolbar.count("message: translate(widget.tooltip),") < 2:
        raise RuntimeError("No se localizaron las ayudas de la barra")
    toolbar = toolbar.replace(
        "message: translate(widget.tooltip),", "message: _miRTooltip(widget.tooltip),")

    # El menú monitor pasa a utilizar también el estilo de MiR.
    toolbar = replace(
        toolbar,
        """        menuStyle: MenuStyle(
            padding:
                MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 6))),""",
        """        menuStyle: _ToolbarTheme.defaultMenuStyle(context).copyWith(
            padding: const MaterialStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 7, vertical: 9))),""",
        "menú de pantallas",
    )

    # Estilizar los ítems desplegados sin romper los eventos que los activan.
    toolbar = replace(
        toolbar,
        """    return MenuItemButton(
        key: key,
        onPressed: onPressed != null""",
        """    return MenuItemButton(
        key: key,
        style: ButtonStyle(
          foregroundColor: const MaterialStatePropertyAll(Color(0xFFEDF6F3)),
          overlayColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.hovered)
                  ? const Color(0xFF193236) : Colors.transparent),
        ),
        onPressed: onPressed != null""",
        "ítems de menú",
    )

    (root / path).write_text(toolbar, encoding="utf-8")
    changed.append(path)

    # La pestaña de sesión utiliza el mismo verde y fondos discretos MiR.
    path = "flutter/lib/desktop/widgets/tabbar_widget.dart"
    tabs = (root / path).read_text(encoding="utf-8")
    start = tabs.index("  static const dark = TabbarTheme(")
    end = tabs.index("  @override", start)
    part = tabs[start:end]
    colors = {
        "selectedTabIconColor: MyTheme.accent": "selectedTabIconColor: Color(0xFF75E0C1)",
        "unSelectedTabIconColor: Color.fromARGB(255, 30, 65, 98)": "unSelectedTabIconColor: Color(0xFFA4C3BB)",
        "selectedTextColor: Colors.white": "selectedTextColor: Color(0xFFEDF6F3)",
        "unSelectedTextColor: Color.fromARGB(255, 192, 192, 192)": "unSelectedTextColor: Color(0xFFA4C3BB)",
        "selectedIconColor: Color.fromARGB(255, 192, 192, 192)": "selectedIconColor: Color(0xFF75E0C1)",
        "unSelectedIconColor: Color.fromARGB(255, 255, 255, 255)": "unSelectedIconColor: Color(0xFFEDF6F3)",
        "dividerColor: Color.fromARGB(255, 64, 64, 64)": "dividerColor: Color(0xFF315052)",
        "hoverColor: Colors.black26": "hoverColor: Color(0xFF193236)",
        "closeHoverColor: Colors.black": "closeHoverColor: Color(0xFF754043)",
        "selectedTabBackgroundColor: Colors.black26": "selectedTabBackgroundColor: Color(0xFF193236)",
    }
    for old, new in colors.items():
        part = replace(part, old, new, "pestaña " + old.split(":")[0])
    tabs = tabs[:start] + part + tabs[end:]
    (root / path).write_text(tabs, encoding="utf-8")
    changed.append(path)

    report = {
        "goal": "Interfaz MiR de sesiones remotas",
        "changed": changed,
        "actions_preserved": True,
        "native_engine_rebuilt": False,
        "validation": {
            "source_patch": "complete",
            "flutter_analyze": "pending",
            "binary": "pending",
            "visual_windows_session": "pending",
            "remote_connection_test": "pending",
        },
        "sha256": {
            path: hashlib.sha256((root / path).read_bytes()).hexdigest()
            for path in changed
        },
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
