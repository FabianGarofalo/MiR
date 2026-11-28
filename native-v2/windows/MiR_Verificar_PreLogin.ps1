# MiR | Estado del receptor antes del inicio de sesion (solo lectura).
# No cambia servicios, procesos, firewall, credenciales ni energia.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$names = @('MiR', 'MiRHost', 'RustDesk')
$report = [ordered]@{
  producto = 'MiR'
  revision = 'diagnostico-prelogin-1'
  fecha_utc = (Get-Date).ToUniversalTime().ToString('o')
  servicio = 'No encontrado'
  arranque = 'No disponible'
  estado = 'No disponible'
  ejecutable = 'No verificable'
  ejecutable_en_mir = $false
  cuenta_servicio = 'No disponible'
  procesos_receptor = 0
  acceso_antes_del_pin = 'NO VERIFICADO'
  recomendacion = ''
}
try {
  $svc = @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop |
    Where-Object { $names -contains $_.Name })
  $report.servicio = if ($svc.Count -eq 0) { 'Ausente' } elseif ($svc.Count -gt 1) { 'Multiples servicios encontrados' } else { $svc[0].Name }
  if ($svc.Count -eq 1) {
    $s = $svc[0]
    $report.estado = $s.State
    $report.arranque = $s.StartMode
    $report.cuenta_servicio = if ($s.StartName -eq 'LocalSystem') { 'LocalSystem' } else { 'Cuenta distinta de LocalSystem' }
    # No divulgar rutas locales ni argumentos de lanzamiento.
    $path = [string]$s.PathName
    $report.ejecutable_en_mir = $path -match '(?i)(?:^|[\\/])MiR[\\/]'
    $report.ejecutable = if ($report.ejecutable_en_mir) { 'Ubicado bajo carpeta MiR' } else { 'Fuera de carpeta MiR o ruta no verificable' }
  }
  $processes = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop |
    Where-Object { $_.Name -in @('MiR.exe','rustdesk.exe') -and
      $_.CommandLine -match '(?i)(?:^|\s)--cm(?:\s|$)' })
  $report.procesos_receptor = $processes.Count
  if ($svc.Count -eq 0) {
    $report.recomendacion = 'Modo portable: no hay servicio para acceso antes del PIN. No instalar servicios sin validar el motor.'
  } elseif ($svc.Count -gt 1) {
    $report.recomendacion = 'Receptores coexistentes: identificar localmente cual atiende las conexiones antes de cualquier migracion.'
  } elseif ($svc[0].State -ne 'Running') {
    $report.recomendacion = 'Hay servicio pero no esta en ejecucion. Revisar el registro de eventos local con acceso fisico.'
  } elseif (-not $report.ejecutable_en_mir) {
    $report.recomendacion = 'El servicio en ejecucion no apunta a la carpeta MiR. No desinstalar el receptor existente.'
  } else {
    $report.recomendacion = 'Servicio candidato detectado. Falta prueba real tras WoL, en pantalla bloqueada y antes del PIN.'
  }
} catch {
  $report.servicio = 'No verificable'
  $report.recomendacion = 'No se pudieron consultar servicios/procesos. Ejecutar localmente con los permisos adecuados.'
}
$json = $report | ConvertTo-Json -Depth 3
$target = Join-Path $PSScriptRoot 'MiR_Estado_PreLogin.json'
try {
  [System.IO.File]::WriteAllText($target, $json, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host ('Informe generado: ' + $target)
} catch {
  Write-Host 'No se pudo guardar en esta carpeta; informe mostrado a continuacion:'
  Write-Output $json
}
Write-Host $report.recomendacion
