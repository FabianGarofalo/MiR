# MiR V2 — Integración nativa y criterios de aceptación

## Arquitectura

MiR mantendrá un motor de control remoto de código abierto, integrado en una única distribución y con interfaz pública MiR. Se debe respetar AGPL-3.0 y las licencias de dependencias. No sustituir autenticación ni mecanismos seguros con automatizaciones frágiles.

### Componentes que aún faltan integrar

1. Partir de una **revisión fija** del cliente Flutter/Rust y registrar su commit de origen.
2. Sustituir el encabezado, logo, iconografía, ventanas de sesión y configuración por UI MiR.
3. Conectar `MiRSessionToolbar` a acciones REALES existentes: fijar barra, acciones rápidas, monitores, teclado, llamada, grabación y finalizar sesión. No mostrar controles que no tengan implementación y permisos correctos.
4. Conectar `MiRConnectionPolicy` a cambios reales de estado; cerrar solo la sesión tras 15 s de desconexión sostenida, nunca matar el receptor.
5. Integrar instalador, receptor desatendido y comprobación del servicio con autorización de administrador y rollback.
6. Implementar la migración segura y reversible desde una instalación anterior, sin copiar ni modificar credenciales sin consentimiento.
7. Preparar la firma de código de EcoEtika S.A.S. **solo con certificado autorizado**, sin incluir claves privadas en el repositorio.
8. Compilar Windows x64 y, después de validar el receptor, Android APK.

## Pruebas de aceptación antes de distribuir MiR V2

- Conexión Windows ↔ Windows; pantalla, mouse, teclado y portapapeles.
- Transferencia de archivos, monitores, permisos de audio y grabación.
- Conexión desde Android hacia Windows.
- Recepción antes de ingresar PIN/contraseña y con pantalla bloqueada.
- Reinicio remoto: al perder la conexión, la ventana de sesión se cierra tras 15 s, sin afectar el receptor.
- Receptor inicia luego de reiniciar el sistema y continúa funcionando sin instalación externa del cliente original.
- UI MiR en pantalla principal, sesión remota, preferencias y popups; sin doble barra de herramientas.
- Comprobar Windows Defender/Avast sin desactivar protección; revisión de falsos positivos cuando corresponda.
- Solo tras estas pruebas: desinstalar cliente anterior y validar una nueva conexión.

## Situación actual

Los archivos bajo `native_pending/` son **componentes experimentales no integrados**. El workflow de pruebas valida sus tests Flutter, pero no valida el motor remoto ni genera versiones finales.

## Licencias

Mantener la atribución del motor y sus dependencias en `Acerca de` y los avisos legales de distribución. La marca MiR no cambia esas obligaciones.
