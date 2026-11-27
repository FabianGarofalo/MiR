param(
  [Parameter(Mandatory = $true)][string]$HostDir
)
$ErrorActionPreference = 'Stop'
$exe = Join-Path $HostDir 'rustdesk.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
  throw 'No existe rustdesk.exe en la carpeta de prueba'
}
if (Get-Service RustDesk -ErrorAction SilentlyContinue) {
  throw 'No es un Windows aislado: ya existe servicio RustDesk'
}
$existing = @(Get-CimInstance Win32_Process -Filter "Name='rustdesk.exe'" -ErrorAction SilentlyContinue)
if ($existing.Count) { throw 'Ya existen procesos rustdesk.exe y no se debe mezclar receptores' }

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class MiRWindowProbe {
  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern IntPtr FindWindow(string windowClass, string windowName);
  [DllImport("user32.dll")]
  public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
}
'@
$firewallName = 'MiR-CI-Host-CM-No-Network'
$started = $null
try {
  New-NetFirewallRule -DisplayName $firewallName -Direction Outbound -Action Block -Program $exe -Profile Any | Out-Null
  $started = Start-Process -FilePath $exe -ArgumentList '--cm' -WorkingDirectory $HostDir -PassThru
  $found = $false
  for ($i=0; $i -lt 35; $i++) {
    Start-Sleep -Seconds 1
    $started.Refresh()
    if ($started.HasExited) {
      throw ('El proceso --cm terminó antes de abrir ventana: ExitCode=' + $started.ExitCode)
    }
    $h = [MiRWindowProbe]::FindWindow($null, 'MiR - Receptor')
    if ($h -ne [IntPtr]::Zero) {
      [uint32]$windowPid=0
      [void][MiRWindowProbe]::GetWindowThreadProcessId($h,[ref]$windowPid)
      if ($windowPid -eq $started.Id) {
        Write-Host ('MIR_CM_WINDOW_OK PID=' + $windowPid + ' TITLE=MiR - Receptor')
        $found=$true
        break
      }
    }
  }
  if (-not $found) {
    throw 'El receptor --cm continuó abierto pero la ventana MiR - Receptor no apareció en 35 segundos'
  }
  $cm=Get-CimInstance Win32_Process -Filter "ProcessId=$($started.Id)"
  if ($cm.CommandLine -notmatch '(?i)(?:^|\s)--cm(?:\s|$)') {
    throw 'El proceso que abrió la ventana no tiene argumento --cm'
  }
  Write-Host ('MIR_CM_STARTUP_OK exe=' + $cm.ExecutablePath)
} finally {
  if ($started -and -not $started.HasExited) {
    Stop-Process -Id $started.Id -ErrorAction SilentlyContinue
  }
  Remove-NetFirewallRule -DisplayName $firewallName -ErrorAction SilentlyContinue
}
