# Componentes experimentales de MiR

Este directorio **no es la aplicación de acceso remoto**: contiene widgets y utilidades Flutter listos para integrar al fork nativo del motor.

- `lib/mir_session_toolbar.dart`: barra flotante con siete callbacks obligatorios; hoy **no envía acciones remotas**.
- `lib/mir_connection_policy.dart`: cierre de una sesión luego de 15 segundos sin conectividad si ya había conectado. **Debe recibir eventos reales**.
- `test/mir_connection_policy_test.dart`: tres pruebas unitarias de la política.
- `pubspec.yaml`: dependencias mínimas de las pruebas.

Para probar localmente, con Flutter instalado:

```sh
cd native_pending
flutter pub get
flutter test
flutter analyze --no-fatal-infos
```

**La compilación y las pruebas de estos componentes no autorizan desinstalar el software anterior.**
