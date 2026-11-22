# MiR V1.5 - Auditoria local de SOLO LECTURA. No consulta IDs, contrasenas ni datos de sesion.
$ErrorActionPreference='Stop'
$lines = New-Object System.Collections.Generic.List[string]
function Add([string]$line){$script:lines.Add($line)}
Add 'MiR V1.5 | Verificacion de independencia del receptor'
Add ('Fecha de consulta: '+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Add 'Comprobacion exclusivamente local, sin cambios en configuracion ni servicios.'
Add ' '
$hostPath=Join-Path $env:ProgramFiles 'MiR\Host\RustDesk.exe'
$enginePath=Join-Path $env:LOCALAPPDATA 'MiRemoto\Engine\v1.0\RustDesk.exe'
$installed=Join-Path $env:LOCALAPPDATA 'Programs\MiR\MiR.exe'
Add ('MiR instalado: '+$(if(Test-Path -LiteralPath $installed -PathType Leaf){'SI'}else{'NO'}))
Add ('Motor MiR incorporado: '+$(if(Test-Path -LiteralPath $enginePath -PathType Leaf){'SI'}else{'NO'}))
Add ('Receptor MiR en Program Files: '+$(if(Test-Path -LiteralPath $hostPath -PathType Leaf){'SI'}else{'NO'}))
try {
  $svc=Get-CimInstance -ClassName Win32_Service -Filter "Name='RustDesk'" -ErrorAction Stop
  if($null -eq $svc){
    Add 'Servicio de recepcion: NO REGISTRADO';$serviceIntegrated=$false
  }else{
    Add ('Estado del servicio de recepcion: '+$svc.State)
    # El nombre de servicio es un identificador interno. No revela credenciales ni IDs.
    $isMiRPath=([string]$svc.PathName -match '(?i)\\MiR\\Host\\RustDesk\.exe')
    Add ('El servicio apunta al receptor MiR: '+$(if($isMiRPath){'SI'}else{'NO'}))
    $serviceIntegrated=$isMiRPath -and ($svc.State -eq 'Running') -and (Test-Path -LiteralPath $hostPath -PathType Leaf)
  }
}catch{
  Add 'Servicio de recepcion: NO SE PUDO INSPECCIONAR';$serviceIntegrated=$false
}
Add ' '
if($serviceIntegrated){
  Add 'RESULTADO: CANDIDATO A INDEPENDENCIA, TODAVIA NO AUTORIZADO PARA DESINSTALAR.'
  Add 'El servicio corre desde MiR, pero falta validar en este equipo:'
  Add '  [ ] Conexion desde otro Windows despues de reiniciar y antes del PIN.'
  Add '  [ ] Conexion desde Android despues de reiniciar y antes del PIN.'
  Add '  [ ] Recepcion con la pantalla bloqueada.'
  Add '  [ ] Verificar que el motor de MiR no consume recursos de la instalacion anterior.'
}else{
  Add 'RESULTADO: NO DESINSTALAR EL CLIENTE ANTERIOR.'
  Add 'El receptor MiR integrado no esta confirmado como servicio operativo.'
}
Add ' '
Add 'Si vas a migrar, hacelo fisicamente frente a cada equipo y conserva un respaldo.'
$lines | ForEach-Object { Write-Output $_ }