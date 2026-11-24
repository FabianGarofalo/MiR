# MiR - Corrector del proceso receptor de Windows.
# Nunca modifica servicios, firewall, credenciales ni el servidor.
param([ValidateSet('Diagnostico','Corregir')][string]$Modo='Corregir')
$ErrorActionPreference='Stop'
function Estado {
  return @(Get-CimInstance Win32_Process -Filter "Name='MiR.exe' OR Name='rustdesk.exe'" |
    Where-Object { $_.CommandLine -match '(?i)(?:^|\s)--cm(?:\s|$)' })
}
function EsActual($p,[string]$exe,$snapshot) {
  if (-not $p.ExecutablePath) { return $false }
  if (-not [string]::Equals($p.ExecutablePath,$exe,[StringComparison]::OrdinalIgnoreCase)) { return $false }
  try { return ([datetime]$p.CreationDate) -ge $snapshot.LastWriteTime.AddSeconds(-3) }
  catch { return $false }
}
try {
  $exe=Join-Path $PSScriptRoot 'MiR.exe'
  $app=Join-Path $PSScriptRoot 'data\app.so'
  if (-not (Test-Path -LiteralPath $exe -PathType Leaf) -or -not (Test-Path -LiteralPath $app -PathType Leaf)) {
    throw 'Ejecutar desde la carpeta del portable completo: hacen falta MiR.exe y data\app.so.'
  }
  $exe=(Resolve-Path -LiteralPath $exe).Path
  $stamp=Get-Item -LiteralPath $app
  Write-Host ''
  Write-Host 'MIR - VERSION REAL DEL RECEPTOR'
  Write-Host ('Ejecutable esperado: '+$exe)
  Write-Host ('UI compilada: '+$stamp.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
  $cm=@(Estado)
  if (-not $cm.Count) { Write-Host 'No existe un receptor --cm abierto.' }
  foreach($p in $cm) {
    $correcto=EsActual $p $exe $stamp
    $path=if($p.ExecutablePath){$p.ExecutablePath}else{'<ruta inaccesible>'}
    Write-Host ('PID {0} | {1} | {2}' -f $p.ProcessId, $(if($correcto){'MIR ACTUAL'}else{'OTRA VERSION'}),$path)
  }
  $services=@(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '(?i)^(MiR|MiRHost|RustDesk)$' })
  foreach($svc in $services) {
    Write-Host ('Servicio {0} | {1} | {2}' -f $svc.Name,$svc.State,$svc.PathName)
  }
  $old=@($cm | Where-Object {$_.Name -ieq 'MiR.exe' -and -not (EsActual $_ $exe $stamp)})
  $rust=@($cm | Where-Object {$_.Name -ieq 'rustdesk.exe'})
  $serviceOld=@($services | Where-Object {
    $_.Name -ieq 'MiR' -and $_.PathName -and
    $_.PathName.IndexOf($exe,[StringComparison]::OrdinalIgnoreCase) -lt 0 })
  if($serviceOld.Count) {
    Write-Warning 'El servicio MiR apunta a otro ejecutable. El proceso antiguo puede volver tras reiniciar.'
    Write-Warning 'No se modificara ese servicio automaticamente.'
  }
  if($rust.Count) {
    Write-Warning 'Existe RustDesk como receptor independiente. No se detiene ni se modifica.'
    Write-Warning 'Si las llamadas llegan a RustDesk, seguiran mostrando su propia interfaz.'
  }
  if($Modo -eq 'Diagnostico') { exit 0 }
  if($old.Count) {
    Write-Warning 'El cierre de ventanas receptoras antiguas PUEDE INTERRUMPIR SESIONES REMOTAS EN CURSO.'
    $confirm=Read-Host 'Finaliza las sesiones antes. Escribi CORREGIR para cerrar solo MiR.exe --cm anteriores'
    if($confirm -cne 'CORREGIR') { Write-Host 'Cancelado, sin cambios.'; exit 2 }
    foreach($p in $old) {
      $live=Get-CimInstance Win32_Process -Filter "ProcessId=$($p.ProcessId)" -ErrorAction SilentlyContinue
      if($live -and $live.Name -ieq 'MiR.exe' -and
          $live.CommandLine -match '(?i)(?:^|\s)--cm(?:\s|$)') {
        Stop-Process -Id $p.ProcessId -ErrorAction Stop
        Write-Host ('Cerrado receptor anterior PID '+$p.ProcessId)
      }
    }
    Start-Sleep -Seconds 2
  }
  $current=@(Estado | Where-Object {$_.Name -ieq 'MiR.exe' -and (EsActual $_ $exe $stamp)})
  if(-not $current.Count) {
    Write-Host 'Iniciando MiR.exe --cm de la carpeta actual...'
    Start-Process -FilePath $exe -ArgumentList '--cm' -WorkingDirectory $PSScriptRoot | Out-Null
    Start-Sleep -Seconds 5
    $current=@(Estado | Where-Object {$_.Name -ieq 'MiR.exe' -and (EsActual $_ $exe $stamp)})
  }
  if($current.Count) {
    Write-Host ('Receptor MiR de esta version iniciado: PID '+$current[0].ProcessId)
    if($serviceOld.Count -or $rust.Count) {
      Write-Warning 'Hay otro receptor/servicio presente. Comprueba a cual pertenece el ID que recibe.'
    }
    exit 0
  }
  Write-Warning 'No se pudo confirmar el nuevo receptor. No se han cambiado los servicios.'
  exit 3
} catch {
  Write-Host ('ERROR: '+$_.Exception.Message)
  Write-Host 'No se han modificado servicios, firewall ni contrasenas.'
  exit 1
}
