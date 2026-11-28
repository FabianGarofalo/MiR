# MiR V2 | Activacion asistida del receptor nativo Windows
# Requiere ejecucion LOCAL, elevacion y consentimiento. No detiene servicios previos.
[CmdletBinding()]
param([switch]$SoloVerificar)
$ErrorActionPreference='Stop'
$names=@('MiR','MiRHost','RustDesk')
function Servicios {
  @(Get-CimInstance Win32_Service -ErrorAction Stop |
    Where-Object { $names -contains $_.Name })
}
function Resultado([string]$msg,[int]$code) { Write-Host $msg; exit $code }
try {
  $exe=Join-Path $PSScriptRoot 'MiR.exe'
  $snapshot=Join-Path $PSScriptRoot 'data\app.so'
  $dll=Join-Path $PSScriptRoot 'librustdesk.dll'
  foreach($file in @($exe,$snapshot,$dll)) {
    if(-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Falta archivo del motor: $(Split-Path $file -Leaf)" }
  }
  $exe=(Resolve-Path -LiteralPath $exe).Path
  $installedRoot=Join-Path $env:ProgramFiles 'MiR'
  if(-not $SoloVerificar -and
      -not $exe.StartsWith(($installedRoot.TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase)) {
    throw 'El registro del servicio solo esta permitido desde MiR instalado en Program Files. El portable nunca instala un servicio.'
  }
  $services=@(Servicios)
  if($services.Count -gt 0) {
    Write-Host 'Se detecto un receptor instalado:'
    foreach($service in $services) {
      Write-Host ("{0}: {1}, inicio {2}" -f $service.Name,$service.State,$service.StartMode)
    }
    Resultado 'No se reemplazo ningun servicio. Verifica localmente cual receptor recibe conexiones.' 3
  }
  if($SoloVerificar) { Resultado 'No hay servicio receptor. La prueba previa al PIN sigue pendiente.' 0 }
  $principal=[Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent())
  if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # El archivo debe existir dentro de Program Files para ser ejecutado elevado.
    $script = Join-Path $installedRoot 'MiR_Activar_Receptor.ps1'
    if(-not [string]::Equals($PSCommandPath,$script,[StringComparison]::OrdinalIgnoreCase)) {
      throw 'La elevacion solo esta permitida desde el instalador MiR.'
    }
    Write-Host 'Solicitando autorizacion de administrador de Windows...'
    $child=Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -PassThru -ArgumentList @(
      '-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $script + '"')
    )
    exit $child.ExitCode
  }
  Write-Host ''
  Write-Host 'MiR | Activar receptor nativo de Windows'
  Write-Host 'Esta operacion puede cerrar procesos MiR actuales; NO ejecutar conectado de forma remota.'
  Write-Host 'El servicio se crea con el motor nativo y solo sera considerado candidato hasta probarlo antes del PIN.'
  Write-Host 'Ninguna contrasena ni PIN se configura desde este script.'
  $ok=Read-Host 'Con acceso fisico a esta PC y otra forma de recuperar la conexion, escribi INSTALAR'
  if($ok -cne 'INSTALAR') { Resultado 'Cancelado. No hubo cambios.' 2 }
  # Revision adicional inmediatamente antes de registrar.
  if(@(Servicios).Count -gt 0) { Resultado 'Aparecio otro servicio. Cancelado sin modificaciones.' 3 }
  $p=Start-Process -FilePath $exe -ArgumentList '--install-service' -WorkingDirectory $PSScriptRoot -Wait -PassThru
  Start-Sleep -Seconds 3
  $after=@(Servicios)
  if($after.Count -ne 1) {
    throw 'El motor no dejo exactamente un servicio reconocido. NO se considera instalado.'
  }
  $s=$after[0]
  $actual=([string]$s.PathName).IndexOf($exe,[StringComparison]::OrdinalIgnoreCase) -ge 0
  if($s.Name -ne 'MiR' -or -not $actual) {
    throw 'El servicio nuevo no se identifica como MiR usando este ejecutable; revisarlo localmente antes de usarlo.'
  }
  if($s.State -ne 'Running') {
    throw 'Se registro el servicio MiR, pero NO esta en ejecucion. Revisar con acceso local.'
  }
  Write-Host 'Servicio MiR detectado y en ejecucion.'
  Write-Host 'PENDIENTE: comprobar acceso desatendido real tras reinicio/WoL, en pantalla bloqueada y antes del PIN.'
  exit 0
} catch {
  Write-Host ('ERROR: '+$_.Exception.Message)
  Write-Host 'Si el registro fue parcial, no desinstales MiR: inspecciona primero el estado del servicio.'
  exit 1
}
