# MiR V1.5 — gestor Windows (legacy)

La compilación de **esta carpeta** reconstruye el gestor Go/PowerShell V1.5 que se probó entre dos computadoras. No recompila el cliente Flutter/Rust ni sustituye todas sus ventanas. No es MiR V2.

## Estado del código fuente
El ZIP original incluye recursos PNG e ICO, código Go/PowerShell y ejecutables generados. En este repositorio público se publican **solo fuentes y recursos**, nunca contraseñas, datos locales ni los binarios del motor original. Hasta importar esos archivos de forma segura, la compilación CI exige su presencia y falla con un mensaje explícito.

## Cómo compilar
```powershell
cd legacy-v1.5
./BUILD-WINDOWS.ps1
```
Requiere Windows x64, PowerShell y Go 1.23. Produce `dist/MiR_Crear_Autonomos_V1.5.exe` con hash SHA-256.

No instalar ni migrar el receptor basándose en una compilación: primero validar físicamente en las notebooks, incluido acceso antes de ingresar PIN, Android y funcionamiento tras reiniciar. Conservar atribuciones y avisos legales del motor subyacente.
