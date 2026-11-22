# MiR — Acceso remoto Windows + Android

**MiR V2 | Desarrollado por EcoEtika S.A.S. | Distribución gratuita**

MiR es un cliente y receptor de escritorio remoto de marca propia. Su base tecnológica es el motor Flutter/Rust de código abierto RustDesk, pero **el ejecutable de MiR es `MiR.exe`** y la implementación nativa emplea un **servicio Windows `MiR`**, independiente del servicio denominado `RustDesk`.

## Estado verificable

| Elemento | Estado |
| --- | --- |
| Gestor transitorio V1.5 (Go/PowerShell) | Código publicado en [legacy-v1.5](legacy-v1.5/), compilación Windows comprobada |
| Base Flutter/Rust 1.5.3 | Revisión fijada `95cca3f661f635b3cc85c04935fe8d96d8f432ef` |
| Nombre MiR.exe y servicio MiR | Incorporados a [finish_mir_identity.py](native-v2/finish_mir_identity.py); validación estructural correcta |
| Barra con acciones reales | Se adapta `RemoteToolbar` original (teclado, monitores, llamadas, grabación, cerrar), no se superpone una barra ficticia |
| Cierre tras desconexión | Política integrada en eventos nativos de sesión, con plazo de 15 s después de haber conectado |
| Logotipos, ventana, pestañas y notificaciones | Aplicados mediante parches reproducibles, manteniendo la atribución legal |
| Cliente y receptor Windows V2 | [Construcción nativa](../../actions/workflows/construir-mir-v2-windows.yml); el resultado solo se declara compilado tras terminar en verde |
| Instalador V2 | Preparado con una opción **voluntaria** de servicio receptor MiR cuando no existe un servicio RustDesk instalado |
| Prueba física antes del PIN y tras reinicio | **Pendiente: requiere notebooks reales** |
| APK Android propio | Pendiente |
| Firma digital de EcoEtika S.A.S. | Pendiente de certificado válido |

## Compilación

La única aplicación Windows visible prevista es **MiR.exe**, con DLLs técnicas del motor incluidas en la misma carpeta; **no es necesario instalar RustDesk por separado para iniciar el cliente**.

- [Compilación nativa Windows](../../actions/workflows/construir-mir-v2-windows.yml): desde el código original, aplica los parches MiR y genera un ZIP portable y un instalador sin firmar como **candidatos de prueba**.
- [Validación del parche](../../actions/workflows/validar-base-nativa.yml): verifica la identidad MiR, los cambios de sesión y la atribución sin producir ejecutables.
- [Gestor V1.5](legacy-v1.5/): fuente histórica separada del producto V2.

## Instalación y recepción desatendida

**No desinstalar ni reemplazar el receptor actual basándose únicamente en un build exitoso.** El instalador V2 no desactiva un servicio RustDesk anterior. Solo ofrece crear su propio servicio si no se detecta uno de esos servicios, para evitar pérdida de acceso. Antes de retirar el receptor antiguo hay que verificar localmente, entre dos computadoras y desde Android, pantalla bloqueada, antes del PIN, reinicio, portapapeles, monitores y archivos.

El código de comprobación local está en [tools](tools/). No almacena contraseñas ni IDs personales.

## Licencia y seguridad

La interfaz pública usa MiR, pero se mantienen los créditos, la licencia AGPL-3.0 y los derechos de terceros en Acerca de y documentación legal de distribución. La DLL `librustdesk.dll` es una biblioteca **interna** del motor y no es otro programa que el usuario deba ejecutar.

El repositorio es **público**: no subir contraseñas, claves, tokens, identificadores privados de acceso, certificados de firma ni diagnósticos con datos de equipos.
