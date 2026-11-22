# MiR V2 — Iteración integrada (22/11/2026)

## Qué se integró en código
- El parche nativo de la revisión fija `95cca3f661f635b3cc85c04935fe8d96d8f432ef` modifica **la barra existente del motor**, sin duplicarla ni dibujar botones decorativos.
- Conserva acciones reales de monitor, teclado, permisos, llamada, grabación y cierre. La llamada de voz puede iniciarse desde la propia barra.
- Los colores, bordes e íconos se adaptan a MiR. Se coloca el logo MiR en el cliente Flutter y el logo transparente de EcoEtika en «Acerca de».
- Se conserva la atribución «Desarrollado sobre la base de RustDesk (AGPL-3.0)» en «Acerca de» y los avisos legales de terceros.
- La política de desconexión cierra **la pestaña afectada** después de 15 segundos de pérdida sostenida, solo si la sesión ya estuvo establecida. No detiene el receptor.

## Compilación y entregables esperados
El workflow `construir-mir-v2-windows.yml` intenta crear desde Flutter/Rust un **candidato no firmado**:
- `MiR_V2_Portable_PREVIEW_SIN_FIRMA.zip`
- `MiR_V2_Instalador_PREVIEW_SIN_FIRMA.exe`

El pipeline debe completar generación de puente, compilación Windows, copia de dependencias, empaquetado y hash SHA-256. **Hasta que termine en verde, no hay ejecutable V2 entregable.** No publicar como versión estable y no afirmar que funciona en tus notebooks sin haberlo probado.

## Receptor independiente: criterio no negociable
- El candidato no migra automáticamente servicios.
- La instalación anterior NO debe desinstalarse hasta que se compruebe que el servicio que recibe conexiones utiliza binarios bajo la nueva instalación MiR y funciona sin depender de procesos, configuraciones o rutas de la instalación anterior.
- Deben repetirse con acceso físico a ambas notebooks: Windows ↔ Windows, Android → Windows, pantalla bloqueada, **antes del PIN**, reinicio remoto, archivos, monitores y portapapeles.
- El script `tools/VALIDAR_INDEPENDENCIA_MIR.ps1` **no modifica nada**; verifica ruta del receptor, estado y constancias expresamente proporcionadas de las pruebas.
- El desinstalador del paquete de prueba bloquea su ejecución si encuentra un servicio que depende de sus archivos.

## Limitaciones aún abiertas
- Los procesos y servicios internos del motor pueden conservar nombres técnicos del proyecto base; quitar esas denominaciones requiere modificar y validar también la gestión del servicio y los componentes Rust, sin romper compatibilidad.
- El binario de prueba no está firmado digitalmente. Firmar requiere credenciales autorizadas de EcoEtika S.A.S. y no garantiza que un antivirus deje de advertir.
- La APK Android personalizada sigue fuera del alcance de esta iteración Windows.
- La compilación CI no verifica por sí misma el acceso desatendido. Nunca ejecutar migración de servicio desde la única conexión remota disponible.

## Seguimiento
- [Parche y validación Flutter/Rust](../actions/workflows/validar-base-nativa.yml)
- [Construcción Windows](../actions/workflows/construir-mir-v2-windows.yml)
- [Plan general](../issues/1)
