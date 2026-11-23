// Navegación MiR: ajustes dentro de la misma ventana, sin pestañas RustDesk.
import 'package:flutter/foundation.dart';

class MiRSettingsRouter {
  MiRSettingsRouter._();

  static bool homeMounted = false;
  static int requestedTabIndex = 0;
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool open(int index) {
    if (!homeMounted) return false;
    requestedTabIndex = index < 0 ? 0 : index;
    revision.value += 1;
    return true;
  }
}
