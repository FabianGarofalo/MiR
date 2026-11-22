# MiR V2 | Prevalidación de independencia — SOLO LECTURA
# No solicita contraseñas ni IDs, NO detiene servicios, NO desinstala software.
[CmdletBinding()]
param(
    [switch]$ConexionEntreWindowsValidada,
    [switch]$AndroidValidado,
    [switch]$AccesoAntesDelPinValidado,
    [switch]$BloqueoValidado,
    [switch]$ReinicioValidado,
    [switch]$TransferenciaValidada
)

$ErrorActionPreference = 'Stop'
$checks = [ordered]@{}
$messages = New-Object System.Collections.Generic.List[string]

function Test-NormalizedPathInMiR([string] $path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $false }
    # Solo verifica rutas bajo Program Files/MiR (no ejecuta ni reemplaza).
    $programs = @([Environment]::GetFolderPath('ProgramFiles'),
        [Environment]::GetFolderPath('ProgramFilesX86'))
    foreach ($dir in $programs) {
        if (-not [string]::IsNullOrWhiteSpace($dir)) {
            $root = [IO.Path]::GetFullPath((Join-Path $dir 'MiR')).TrimEnd('\') + '\'
            if ($path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
    }
    return $false
}
function Get-BinaryFromService([string] $command) {
    $command = $command.Trim()
    if ($command -match '^"([^"]+\.exe)"') { return $Matches[1] }
    if ($command -match '^(.+?\.exe)(?:\s|$)') { return $Matches[1] }
    return ''
}

$services = @(Get-CimInstance Win32_Service | Where-Object {
    $_.Name -match '^(RustDesk|MiR|MiRHost)$' -or $_.DisplayName -match '^(RustDesk|MiR|MiR Host)$'
})
$running = @($services | Where-Object { $_.State -eq 'Running' })
$mirService = @($running | Where-Object {
    $path = Get-BinaryFromService ([string]$_.PathName)
    if (-not (Test-NormalizedPathInMiR $path)) { return $false }
    return (Test-Path -LiteralPath $path -PathType Leaf)
})

$checks['Servicio activo integrado en MiR'] = ($mirService.Count -eq 1)
$checks['Un solo receptor remoto activo'] = ($running.Count -eq 1)
$checks['Windows a Windows validado'] = [bool]$ConexionEntreWindowsValidada
$checks['Android a Windows validado'] = [bool]$AndroidValidado
$checks['Recepción antes del PIN validada'] = [bool]$AccesoAntesDelPinValidado
$checks['Recepción con pantalla bloqueada validada'] = [bool]$BloqueoValidado
$checks['Recepción después del reinicio validada'] = [bool]$ReinicioValidado
$checks['Transferencia validada'] = [bool]$TransferenciaValidada

Write-Host 'MiR | Verificación previa a retirar el cliente remoto anterior'
Write-Host 'La herramienta no realiza cambios en esta computadora.'
foreach ($key in $checks.Keys) {
    $value = [bool]$checks[$key]
    Write-Host ("{0}: {1}" -f $key, $(if ($value) { 'VERIFICADO' } else { 'PENDIENTE' }))
}

$ok = @($checks.Values | Where-Object { -not [bool]$_ }).Count -eq 0
if ($ok) {
    Write-Host ''
    Write-Host 'PREVALIDACIÓN COMPLETA. Requiere todavía revisión manual y respaldo antes de desinstalar.'
    Write-Host 'NO se ha desinstalado, detenido ni migrado ningún servicio.'
    exit 0
}
Write-Host ''
Write-Host 'NO DESINSTALAR: faltan verificaciones o el servicio receptor sigue fuera de MiR.'
exit 2
