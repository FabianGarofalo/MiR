// MiR V2 — identidad única para sesiones remotas, menú, cuadros y ayudas.
// Este tema cambia la presentación, no los handlers del motor remoto.
import 'package:flutter/material.dart';

class MiRConnectionTheme extends StatelessWidget {
  const MiRConnectionTheme({super.key, required this.child});
  final Widget child;

  static const background = Color(0xFF0B191A);
  static const surface = Color(0xFF132629);
  static const field = Color(0xFF193236);
  static const border = Color(0xFF315052);
  static const accent = Color(0xFF75E0C1);
  static const muted = Color(0xFFA4C3BB);
  static const foreground = Color(0xFFEDF6F3);
  static const danger = Color(0xFFE78C86);

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final menuShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: border, width: 0.8),
    );
    return Theme(
      data: base.copyWith(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          onPrimary: background,
          secondary: accent,
          onSecondary: background,
          surface: surface,
          onSurface: foreground,
          background: background,
          onBackground: foreground,
          error: danger,
        ),
        scaffoldBackgroundColor: background,
        canvasColor: surface,
        cardColor: surface,
        dialogBackgroundColor: surface,
        dividerColor: border,
        iconTheme: const IconThemeData(color: accent, size: 19),
        textTheme: base.textTheme.apply(
          bodyColor: foreground,
          displayColor: foreground,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: surface,
          surfaceTintColor: Colors.transparent,
          shape: menuShape,
          textStyle: const TextStyle(color: foreground, fontSize: 13),
          elevation: 10,
        ),
        dialogTheme: DialogTheme(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          shape: menuShape,
          titleTextStyle: const TextStyle(
              color: foreground, fontSize: 17, fontWeight: FontWeight.w700),
          contentTextStyle: const TextStyle(
              color: foreground, fontSize: 13.5),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          textStyle: const TextStyle(color: foreground, fontSize: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        menuTheme: MenuThemeData(
          style: MenuStyle(
            backgroundColor: const MaterialStatePropertyAll(surface),
            surfaceTintColor: const MaterialStatePropertyAll(Colors.transparent),
            shape: MaterialStatePropertyAll(menuShape),
            side: const MaterialStatePropertyAll(
              BorderSide(color: border, width: 0.8)),
            padding: const MaterialStatePropertyAll(
              EdgeInsets.symmetric(vertical: 7, horizontal: 5)),
          ),
        ),
        menuBarTheme: MenuBarThemeData(
          style: MenuStyle(
            backgroundColor: const MaterialStatePropertyAll(surface),
            surfaceTintColor: const MaterialStatePropertyAll(Colors.transparent),
            padding: const MaterialStatePropertyAll(EdgeInsets.zero),
            elevation: const MaterialStatePropertyAll(0),
          ),
        ),
        menuButtonTheme: MenuButtonThemeData(
          style: ButtonStyle(
            foregroundColor: const MaterialStatePropertyAll(foreground),
            overlayColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.hovered) ||
              states.contains(MaterialState.focused)
                ? accent.withOpacity(0.13)
                : Colors.transparent),
            textStyle: const MaterialStatePropertyAll(
              TextStyle(color: foreground, fontSize: 13)),
            shape: MaterialStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.selected) ? accent : field),
          checkColor: const MaterialStatePropertyAll(background),
        ),
        radioTheme: RadioThemeData(
          fillColor: const MaterialStatePropertyAll(accent),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.selected) ? accent : muted),
          trackColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.selected) ? field : border),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: field,
          contentTextStyle: const TextStyle(color: foreground),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      child: child,
    );
  }
}
