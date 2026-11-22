# MiR V2 — Validación real en Windows

Este procedimiento se usa **solo después de que GitHub Actions entregue un paquete MiR V2 que contenga `MiR.exe`** y que haya pasado el arranque automático en Windows.

## Etapa 1. Cliente MiR sin alterar el receptor anterior

1. En una notebook con acceso físico, descomprimir completamente `MiR_V2_Portable_PREVIEW_SIN_FIRMA.zip`.
2. Verificar que el programa principal sea **`MiR.exe`**. Es normal que la carpeta tenga DLLs técnicas del motor, incluyendo `librustdesk.dll`.
3. Ejecutar `MiR.exe`, mantener funcionando la instalación remota anterior y conectarse a la **otra** notebook con su ID y contraseña actuales.
4. Probar imagen, mouse, teclado, portapapeles, múltiples monitores, transferencia de archivos, audio y cierre de sesión.
5. Verificar ícono, título de ventana y todas las pantallas. Capturar textos o imágenes que todavía no presenten la marca MiR.

Este primer uso NO modifica el servicio original.

## Etapa 2. Receptor propio MiR en un Windows sin servicio anterior

1. Con acceso físico y una vía alternativa de recuperación, instalar MiR V2.
2. Si **no hay** servicio RustDesk instalado, el instalador ofrece *Instalar receptor MiR para acceso desatendido* (opción no marcada por defecto).
3. Activar esa opción para registrar el servicio **MiR**; no se instala ni ejecuta un cliente remoto externo.
4. En PowerShell de administrador, inspeccionar el estado sin alterar nada: `Get-CimInstance Win32_Service -Filter "Name='MiR'" | Select Name,State,PathName,StartMode`.
5. Confirmar que el servicio apunta a `C:\Program Files\MiR\MiR.exe` (o el directorio elegido).
6. Conectarse desde otra PC, después de bloquear Windows, después de reiniciarlo y antes de ingresar el PIN. Probar también desde Android.

**Si existe un servicio RustDesk anterior, MiR no lo elimina ni desactiva y no ofrece instalar otro receptor automáticamente.** La migración a MiR debe hacerse presencialmente, con respaldo, dos equipos disponibles y la posibilidad de recuperar el servicio anterior.

## Etapa 3. Retiro de la instalación anterior

No se retira la instalación anterior hasta superar todas las pruebas siguientes:

- [ ] Windows a Windows.
- [ ] Android a Windows.
- [ ] Pantalla bloqueada.
- [ ] Inicio del servicio después del reinicio.
- [ ] Acceso antes del PIN.
- [ ] Transferencia de archivos, portapapeles y monitores.
- [ ] Reconexión y cierre por desconexión de 15 segundos.
- [ ] Servicio MiR configurado y comprobado, sin depender de rutas del cliente anterior.

El script `tools/VALIDAR_INDEPENDENCIA_MIR.ps1` ayuda a inspeccionar el estado y **no desinstala ni cambia servicios**.

## Seguridad

MiR V2 preview no tiene firma digital. No desactivar Defender/Avast para instalarlo. Una advertencia o bloqueo requiere revisar el análisis antes de continuar. No subir contraseñas, credenciales, claves ni ID de equipos al repositorio público.
