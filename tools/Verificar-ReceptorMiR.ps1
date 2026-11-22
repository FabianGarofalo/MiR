# MiR | Auditoria local de receptor — SOLO LECTURA
# No instala/desinstala, no modifica servicios, no consulta credenciales ni IDs.
$ErrorActionPreference = 'Stop'

function Check-File([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
  return (Test-Path -LiteralPath $Path -PathType Leaf)
}
$programFiles = [Environment]::GetEnvironmentVariable('ProgramFiles')
$localAppData = [Environment]::GetEnvironmentVariable('LOCALAPPDATA')
$miRHost = Join-Path $programFiles 'MiR\Host\RustDesk.exe'
$miREngine = Join-Path $localAppData 'MiRemoto\Engine\v1.0\RustDesk.exe'
$miRInstalled = Join-Path $localAppData 'Programs\MiR\MiR.exe'

Write-Output 'MiR | Auditoria de independencia del receptor'
Write-Output 'Comprobacion local, de solo lectura. No se obtienen credenciales ni IDs.'
Write-Output ('Aplicacion instalada: ' + (Check-File $miRInstalled))
Write-Output ('Motor integrado: ' + (Check-File $miREngine))
Write-Output ('Motor receptor: ' + (Check-File $miRHost))

$integrated = $false
try {
  $svc = Get-CimInstance -ClassName Win32_Service -Filter "Name='RustDesk'"
  if ($null -ne $svc) {
    $executableMatches = ([string]$svc.PathName) -match '(?i)\\MiR\\Host\\RustDesk\.exe'
    $running = $svc.State -eq 'Running'
    Write-Output ('Servicio receptor existente: SI')
    Write-Output ('Servicio en ejecucion: ' + $running)
    Write-Output ('Servicio apunta a MiR Host: ' + $executableMatches)
    $integrated = $running -and $executableMatches -and (Check-File $miRHost)
  } else {
    Write-Output 'Servicio receptor existente: NO'
  }
} catch {
  Write-Output 'Estado del servicio: NO VERIFICABLE'
}

if ($integrated) {
  Write-Output 'RESULTADO: candidato a independencia. TODAVIA NO DESINSTALAR el cliente anterior.'
  Write-Output 'Pendiente: probar recepcion despues de reiniciar Windows, antes del PIN, con pantalla bloqueada y desde Android.'
} else {
  Write-Output 'RESULTADO: NO DESINSTALAR el cliente anterior; el receptor MiR no se confirmo.'
}
