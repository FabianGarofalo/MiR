# MiR — Acceso remoto | Windows + Android

**MiR V1 | Desarrollado por EcoEtika S.A.S. | Distribución gratuita**

MiR es un proyecto de aplicación de acceso remoto personal con identidad visual propia. El objetivo es controlar y recibir conexiones desde una sola instalación Windows y, más adelante, desde Android.

## Qué está disponible realmente

| Componente | Estado |
| --- | --- |
| Gestor Windows V1.5 (Go + PowerShell) | Código fuente publicado en [legacy-v1.5](legacy-v1.5/) y compilación de GitHub Actions verificada |
| Creador autónomo V1.5 | Se genera en [Actions](../../actions/workflows/compilar-gestor-v1.5.yml) bajo ejecución manual; necesita el motor local para crear portable e instalador |
| Barra flotante y cierre por desconexión | Componentes Flutter experimentales en [native_pending](native_pending/); todavía **no están conectados al cliente remoto** |
| MiR V2 Windows nativo | Pendiente de integración y compilación del motor Flutter/Rust |
| Receptor independiente | Todavía no verificado sin instalación previa; **no desinstalar** el cliente anterior |
| MiR Android APK | Pendiente |
| Firma digital | Pendiente; no se distribuyen binarios como firmados |

## Código y compilación

- `legacy-v1.5/`: código de gestor, empaquetador y receptor de transición. No se sube el ejecutable ni las bibliotecas del motor original ni los datos de equipos.
- `.github/workflows/compilar-gestor-v1.5.yml`: compila el creador de Windows x64. **No compila MiR V2 nativo.**
- `native_pending/`: widgets, política de desconexión y pruebas Flutter.
- `docs/INTEGRACION_NATIVA.md`: alcance y criterios de aceptación de V2.
- `tools/Verificar-ReceptorMiR.ps1`: auditoría local de solo lectura; no habilita por sí sola la desinstalación del cliente anterior.

## Seguridad

No subir IDs remotos personales, contraseñas, certificados, tokens, configuraciones locales, diagnósticos, claves privadas ni registros de sesión. El repositorio está público.

No desinstalar una instalación de acceso remoto que ya funciona hasta validar en dos equipos que MiR inicia su propio receptor después de reiniciar, acepta conexiones antes del PIN de Windows y permite control desde Android.

## Licencias

La base tecnológica utiliza componentes del proyecto de código abierto [RustDesk](https://github.com/rustdesk/rustdesk). Deben conservarse los avisos legales, créditos y obligaciones de la licencia AGPL-3.0 y licencias de dependencias, aunque la interfaz pública muestre la marca MiR.
