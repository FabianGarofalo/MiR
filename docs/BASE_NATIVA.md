# MiR V2 — base nativa verificada

El cliente base usa Flutter para la interfaz y Rust para la captura, entrada remota,
transporte de datos y servicio receptor. **No** intentaremos reconstruir esas
funciones desde scripts del gestor.

## Punto de partida técnico

Revisión a fijar: etiqueta oficial `rustdesk/rustdesk@1.5.3`, pendiente de
validar commit exacto y dependencias en un workflow separado.

Puntos de integración conocidos de la versión Flutter:
- `flutter/lib/desktop/pages/remote_page.dart`: pantalla remota y ciclo de sesión.
- `flutter/lib/desktop/widgets/remote_toolbar.dart`: barra y acciones actuales.
- `flutter/lib/main.dart`: entrada de la aplicación y ventanas.
- `flutter/pubspec.yaml`: dependencias Flutter.

## Pasos concretos

1. Usar una revisión **fija** del proyecto upstream, registrar commit y licencia.
2. Sustituir recursos visuales y textos de interfaz, manteniendo atribuciones legales.
3. Integrar `MiRSessionToolbar` con acciones reales (no con callbacks vacíos).
4. Conectar `MiRConnectionPolicy` a estados reales de la conexión.
5. Adaptar y probar receptor como servicio Windows, instalación y recuperación.
6. Compilar Windows x64, luego preparar instalador/portable firmables.
7. Probar Android, pantalla bloqueada, antes del PIN, reinicio y desinstalación
   del cliente anterior, exclusivamente cuando la independencia se demuestre.

**Estado:** hasta que estos puntos estén cerrados, el artefacto compilado desde
`legacy-v1.5` NO es MiR V2 nativo. No desinstalar el servicio anterior.
