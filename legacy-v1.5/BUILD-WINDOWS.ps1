# MiR V1.5 — compilación reproducible del gestor legacy, no del cliente nativo V2.
# Ejecutar desde el directorio legacy-v1.5 en Windows x64 con Go 1.23.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $root

function Required([string] $path) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Falta archivo fuente: $path" }
}
@(
 'cmd/hostctl/main.go',
 'cmd/uninstaller/main.go',
 'cmd/creator/main.go',
 'cmd/installer/main.go',
 'cmd/installer/engine.go',
 'cmd/portable/main.go',
 'cmd/portable/engine.go',
 'payload/MiRemoto.ps1',
 'payload/MiRemoto.ico',
 'payload/assets/MiR_logo.png',
 'payload/assets/MiR_icono.png',
 'payload/assets/EcoEtika_logo.png'
) | ForEach-Object { Required $_ }

$env:GOOS = 'windows'
$env:GOARCH = 'amd64'
$env:CGO_ENABLED = '0'
New-Item -ItemType Directory -Force -Path 'dist' | Out-Null
$go = Get-Command go -ErrorAction Stop
Write-Host "MiR V1.5 | Compilación de gestor Windows usando $($go.Source)"

function Build([string] $out, [string] $package) {
  Write-Host "Compilando $package -> $out"
  & go build -trimpath -ldflags '-H=windowsgui' -o $out $package
  if ($LASTEXITCODE -ne 0) { throw "Falló la compilación Go de $package" }
  Required $out
}

# 1. Herramienta de instalación de receptor que se incluye en los recursos del gestor.
Build 'payload/MiR_Host.exe' './cmd/hostctl'

# 2. Contenedor de recursos del portable; sin credenciales ni IDs de usuario.
if (Test-Path 'cmd/portable/payload.zip') { Remove-Item 'cmd/portable/payload.zip' -Force }
Compress-Archive -Path 'payload/*' -DestinationPath 'cmd/portable/payload.zip' -CompressionLevel Optimal -Force
Required 'cmd/portable/payload.zip'

# 3. Portable base.
Build 'cmd/portable/MiR_Portable.exe' './cmd/portable'
Copy-Item 'cmd/portable/MiR_Portable.exe' 'cmd/installer/MiR_Portable.exe' -Force
Copy-Item 'cmd/portable/MiR_Portable.exe' 'cmd/creator/MiR_Base.exe' -Force

# 4. Desinstalador base.
Build 'cmd/installer/MiR_Desinstalar_Base.exe' './cmd/uninstaller'
Copy-Item 'payload/MiRemoto.ico' 'cmd/installer/MiRemoto.ico' -Force

# 5. Instalador base.
Build 'cmd/creator/MiR_Instalador_Base.exe' './cmd/installer'

# 6. Creador final que permite integrar el motor disponible en el equipo.
Build 'dist/MiR_Crear_Autonomos_V1.5.exe' './cmd/creator'

Get-FileHash 'dist/MiR_Crear_Autonomos_V1.5.exe' -Algorithm SHA256 |
  Select-Object Algorithm,Hash,Path | Format-List | Out-String |
  Set-Content -Encoding UTF8 'dist/SHA256.txt'
Write-Host 'Compilación del gestor V1.5 completada. No es un cliente nativo MiR V2.'
Write-Host 'No desinstales ningún servicio de recepción previo basándote solo en este build.'
