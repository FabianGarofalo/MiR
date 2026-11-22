# MiR — Acceso remoto | Windows + Android

**MiR V1 | Desarrollado por EcoEtika S.A.S. | Distribución gratuita**

Proyecto de acceso remoto personal para Windows y, en etapa posterior, Android. El objetivo es una sola aplicación MiR para controlar y recibir conexiones sin requerir la instalación separada del motor subyacente.

## Estado real a noviembre de 2026

- **MiR V1.5:** gestor de equipos Windows (Go y PowerShell), creador de versiones autónomas y diagnóstico del servicio receptor. La conexión entre Windows y el acceso a pantallas bloqueadas fueron probados por el usuario en sus equipos.
- **MiR V2 nativo:** no está terminado. La barra flotante y la política de cierre por desconexión existen como componentes Flutter independientes, pero **todavía no están conectados al motor ni compilados como cliente remoto nativo**.
- **Android:** el cliente Android personalizado no está compilado.
- **Desinstalación del cliente anterior:** **NO** desinstalar todavía; falta validar el servicio receptor independiente tras reinicio, antes del inicio de sesión y desde Android.

## Organización

`legacy-v1.5/` — código del gestor Windows, sin ejecutables generados ni datos privados (se incorporará en un segundo paso).

`native_pending/` — componentes Flutter/Dart experimentales (se incorporarán para su integración nativa).

`docs/INTEGRACION_NATIVA.md` — etapas y criterios para el cliente completo.

`.github/workflows/` — compilación automatizada del gestor existente y pruebas de componentes, diferenciadas de una compilación nativa completa.

## Publicación

No publicar binarios V2 como terminados hasta integrar cliente Flutter/Rust, acciones de sesión, permisos, servicio receptor, manejo de desconexiones y pruebas reales en Windows y Android. Se deben conservar los créditos, avisos y derechos de terceros requeridos por la licencia AGPL-3.0 y las licencias de dependencias, incluso cuando el producto se presente con marca MiR.

El repositorio está actualmente **público**. No subir contraseñas, identificadores de equipos, datos de conexiones, certificados, tokens ni claves privadas.
