param([Parameter(Mandatory=$true)][string]$HostDir)
$ErrorActionPreference = 'Stop'
$exe = Join-Path $HostDir 'rustdesk.exe'
if (!(Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'No existe rustdesk.exe en host de prueba' }
if (Get-Service RustDesk -ErrorAction SilentlyContinue) { throw 'Runner no limpio: servicio RustDesk instalado' }

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Text;
using System.Runtime.InteropServices;
public static class MiRWindowProbe {
  public delegate bool EnumWindowsCallback(IntPtr h, IntPtr p);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)]
  public static extern IntPtr FindWindow(string klass, string name);
  [DllImport("user32.dll")]
  public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
  [DllImport("user32.dll")]
  static extern bool EnumWindows(EnumWindowsCallback callback, IntPtr param);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)]
  static extern int GetWindowText(IntPtr h, StringBuilder text, int max);
  public static string[] Titles(uint processId) {
    var windows = new List<string>();
    EnumWindows((h,p) => {
      uint actual;
      GetWindowThreadProcessId(h,out actual);
      if (actual==processId) {
        StringBuilder title=new StringBuilder(512);
        GetWindowText(h,title,title.Capacity);
        windows.Add(title.ToString());
      }
      return true;
    }, IntPtr.Zero);
    return windows.ToArray();
  }
}
'@

$firewallName = 'MiR-CI-Host-CM-No-Network'
try {
  New-NetFirewallRule -DisplayName $firewallName -Direction Outbound -Action Block -Program $exe -Profile Any | Out-Null
  foreach ($mode in @('main','cm')) {
    $arguments = if($mode -eq 'main') { @() } else { @('--cm') }
    $p = Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $HostDir -PassThru
    $observed = @()
    try {
      for ($i=0; $i -lt 24; $i++) {
        Start-Sleep -Seconds 1
        $p.Refresh()
        $titles = [MiRWindowProbe]::Titles([uint32]$p.Id)
        if ($titles.Count) {
          foreach ($title in $titles) {
            if ($observed -notcontains $title) {
              $observed += $title
              Write-Host ("WINDOW mode=$mode PID=$($p.Id) title=[$title]")
            }
          }
        }
        if ($p.HasExited) {
          Write-Host "EXIT mode=$mode after $($i+1)s ExitCode=$($p.ExitCode)"
          break
        }
        if ($mode -eq 'main' -and $titles.Count -gt 0) { break }
        if ($mode -eq 'cm' -and $titles -contains 'MiR - Receptor') { break }
      }
      $p.Refresh()
      if ($mode -eq 'main') {
        if (-not $observed.Count) { throw 'El cliente de receptor no logró crear una ventana principal.' }
        if ($p.HasExited) { throw 'El cliente de receptor terminó prematuramente.' }
        Write-Host 'MIR_HOST_MAIN_WINDOW_OK'
      } else {
        if ($observed -contains 'MiR - Receptor') {
          Write-Host 'MIR_HOST_CM_WINDOW_OK'
        } elseif ($p.HasExited) {
          Write-Host 'NOTA: --cm se cerró sin sesión entrante; no equivale a fallo de recepción remota.'
          Write-Host ('CM títulos observados: ' + ($observed -join ' | '))
          Write-Host 'MIR_HOST_CM_WITHOUT_ACTIVE_SESSION_INCONCLUSIVE'
        } else {
          Write-Host ('CM títulos observados: ' + ($observed -join ' | '))
          throw 'CM sin ventana de MIR y sin sesión entrante: requiere prueba con conexión real.'
        }
      }
    } finally {
      if (-not $p.HasExited) { Stop-Process -Id $p.Id -ErrorAction SilentlyContinue }
    }
  }
} finally {
  Remove-NetFirewallRule -DisplayName $firewallName -ErrorAction SilentlyContinue
}
