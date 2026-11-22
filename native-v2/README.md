# Integración nativa MiR V2

El cliente Flutter/Rust de origen está fijado a la versión 1.5.3, commit
`95cca3f661f635b3cc85c04935fe8d96d8f432ef`.

`stage_components.py` verifica rutas y la presencia de `RemoteToolbar` en el
cliente de origen y copia los componentes Flutter MiR dentro de un árbol temporal.
**NO** conecta sus controles a acciones remotas; no reemplaza el motor, no compila
un cliente final y no modifica el servicio Windows.

La compilación final exige:
1. Aplicar identidad visual y UI MiR dentro del cliente.
2. Integrar callbacks con el `FFI` real, permisos, entrada y eventos de sesión.
3. Incorporar la política de desconexión al ciclo de sesión.
4. Preparar y probar servicio receptor sin instalación original separada.
5. Probar bloqueos, reinicio, antes del PIN, Android, seguridad y archivos.

Los informes de prueba deben registrar qué puntos pasan y cuáles no.
No etiquetar ni distribuir este material como aplicación MiR V2 terminada.
