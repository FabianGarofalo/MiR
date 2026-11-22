# Próximo hito de MiR V2

## Objetivo
Generar un único cliente/receptor Windows compilado a partir del motor Flutter/Rust, con interfaz MiR y sin instalación separada del programa original.

## Orden técnico de ejecución

1. Incorporar en una rama de trabajo una revisión fija y licenciada del proyecto base Flutter/Rust.
2. Aplicar el branding de MiR en cliente, ventana de sesión, diálogos, íconos y barra de tareas.
3. Integrar la barra flotante existente en `native_pending/` usando callbacks REALES de la sesión.
4. Conectar la política de desconexión a estados del motor; no finalizar el servicio receptor al cerrar una sesión.
5. Integrar recepción desatendida y configuración de seguridad con permisos explícitos.
6. Compilar nativamente Windows x64 mediante GitHub Actions, manteniendo portable e instalador como artefactos de prueba.
7. Completar pruebas end-to-end en los dos equipos y con Android: reconexión, reinicio, bloqueo, antes del PIN, archivos, portapapeles, grabación y varios monitores.
8. Firmar una versión estable con certificado autorizado y revisar falsos positivos antes de distribuir.
9. SOLO ENTONCES validar el funcionamiento sin el cliente original y proceder a desinstalarlo con respaldo y acceso local.

## Estado actual

El flujo Flutter actualmente verifica componentes aislados; no genera una aplicación remota. La auditoría Windows valida el estado declarado de un servicio, pero NO prueba por sí sola independencia ni permite desinstalar la instalación anterior. El código completo del gestor Go/PowerShell V1.5 todavía no se ha migrado al repositorio.

## Seguridad

No ejecutar cambios en el servicio receptor desde una sesión remota. No copiar ni almacenar credenciales. No subir rutas personales, identificadores de equipos, contraseñas, claves privadas o archivos de diagnóstico al repositorio público.
