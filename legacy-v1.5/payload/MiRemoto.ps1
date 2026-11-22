# MiR V1.5 - gestion de equipos y auditoria de independencia; Windows PowerShell 5.1
# Windows 10/11, Windows PowerShell 5.1. No modifica la configuracion de seguridad de RustDesk.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:Version = '1.5.0'
$script:Root = Join-Path $env:LOCALAPPDATA 'MiRemoto'
$script:DataPath = Join-Path $script:Root 'equipos.json'
$script:SettingsPath = Join-Path $script:Root 'config.json'
$script:StartLink = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)) 'MiRemoto.lnk'
$script:devices = New-Object 'System.Collections.Generic.List[object]'
$script:settings = @{ rustdeskPath = '' }
$script:selectedId = ''
$script:loadError = $false

function Color([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
$C = @{
    Window = Color '#0B191A'; Card = Color '#132629'; Field = Color '#193236'
    Edge = Color '#315052'; Accent = Color '#75E0C1'; Text = Color '#EDF6F3'
    Muted = Color '#A4C3BB'; Warn = Color '#F6BE73'; Danger = Color '#F28D88'
}
function Fnt([float]$size=10, [bool]$bold=$false) {
    $style = [System.Drawing.FontStyle]::Regular
    if ($bold) { $style = [System.Drawing.FontStyle]::Bold }
    [System.Drawing.Font]::new('Segoe UI', $size, $style)
}
function Lbl([string]$text,[int]$x,[int]$y,[int]$w,[int]$h,[float]$size=10,[bool]$bold=$false,$color=$null) {
    $l=New-Object System.Windows.Forms.Label
    $l.SetBounds($x,$y,$w,$h); $l.Text=$text; $l.Font=Fnt $size $bold
    $l.ForeColor=if($null -eq $color){$C.Text}else{$color}
    $l.BackColor=[System.Drawing.Color]::Transparent
    return $l
}
# Bordes redondeados para TODOS los botones, incluso cuando se cambia el tamaño.
function RoundButton([System.Windows.Forms.Button]$control) {
    if($control.Width -lt 8 -or $control.Height -lt 8){return}
    $radius=[Math]::Min(12,[Math]::Floor([Math]::Min($control.Width,$control.Height)/3))
    $diam=2*$radius
    $path=New-Object System.Drawing.Drawing2D.GraphicsPath
    try{
        $w=$control.Width - 1; $h=$control.Height - 1
        $path.AddArc(0,0,$diam,$diam,180,90)
        $path.AddArc($w-$diam,0,$diam,$diam,270,90)
        $path.AddArc($w-$diam,$h-$diam,$diam,$diam,0,90)
        $path.AddArc(0,$h-$diam,$diam,$diam,90,90)
        $path.CloseFigure()
        $region=[System.Drawing.Region]::new($path)
        $old=$control.Region
        $control.Region=$region
        if($null -ne $old){$old.Dispose()}
    }finally{$path.Dispose()}
}
function Btn([string]$text,[int]$x,[int]$y,[int]$w,[int]$h,[bool]$primary=$false) {
    $b=New-Object System.Windows.Forms.Button
    $b.Text=$text; $b.SetBounds($x,$y,$w,$h); $b.Font=Fnt 9.5 $primary
    $b.FlatStyle=[System.Windows.Forms.FlatStyle]::Flat; $b.FlatAppearance.BorderSize=1
    $b.Cursor=[System.Windows.Forms.Cursors]::Hand
    if($primary){$b.BackColor=$C.Accent;$b.ForeColor=$C.Window;$b.FlatAppearance.BorderColor=$C.Accent}
    else{$b.BackColor=$C.Field;$b.ForeColor=$C.Text;$b.FlatAppearance.BorderColor=$C.Edge}
    $b.Add_SizeChanged({param($sender,$eventArgs) RoundButton $sender})
    RoundButton $b
    return $b
}
function Txt([int]$x,[int]$y,[int]$w,[int]$h,[bool]$multi=$false) {
    $t=New-Object System.Windows.Forms.TextBox
    $t.SetBounds($x,$y,$w,$h);$t.Font=Fnt 10;$t.BackColor=$C.Field
    $t.ForeColor=$C.Text;$t.BorderStyle='FixedSingle'
    if($multi){$t.Multiline=$true;$t.ScrollBars='Vertical'}
    return $t
}
function Pane([int]$x,[int]$y,[int]$w,[int]$h) {
    $p=New-Object System.Windows.Forms.Panel
    $p.SetBounds($x,$y,$w,$h);$p.BackColor=$C.Card
    return $p
}
function MiRDialog([string]$message,[string]$title='MiR',[bool]$question=$false,[bool]$danger=$false) {
    $dlg=New-Object System.Windows.Forms.Form
    $dlg.Text=$title;$dlg.StartPosition='CenterParent';$dlg.ClientSize=[System.Drawing.Size]::new(630,335)
    $dlg.FormBorderStyle='FixedDialog';$dlg.MinimizeBox=$false;$dlg.MaximizeBox=$false
    $dlg.BackColor=$C.Window;$dlg.ForeColor=$C.Text;$dlg.Font=Fnt 10
    $dlg.ShowInTaskbar=$false
    $iconPath=Join-Path $PSScriptRoot 'MiRemoto.ico'
    if(Test-Path -LiteralPath $iconPath){try{$dlg.Icon=[Drawing.Icon]::new($iconPath)}catch{}}
    $hdr=Pane 0 0 630 66;$dlg.Controls.Add($hdr)
    $hdr.Controls.Add((Lbl $title 24 17 580 32 14 $true $C.Text))
    # Texto no seleccionable: el TextBox anterior mostraba todo resaltado.
    $scroll=New-Object System.Windows.Forms.Panel
    $scroll.SetBounds(22,79,586,187)
    $scroll.AutoScroll=$true
    $scroll.BackColor=$C.Window
    $msgLabel=New-Object System.Windows.Forms.Label
    $msgLabel.AutoSize=$true
    $msgLabel.MaximumSize=[System.Drawing.Size]::new(552,0)
    $msgLabel.Location=[System.Drawing.Point]::new(2,4)
    $msgLabel.Text=$message
    $msgLabel.ForeColor=if($danger){$C.Danger}else{$C.Text}
    $msgLabel.BackColor=$C.Window
    $msgLabel.Font=Fnt 10
    $scroll.Controls.Add($msgLabel)
    $dlg.Controls.Add($scroll)
    $accept=Btn $(if($question){'Continuar'}else{'Aceptar'}) 469 278 136 36 $true
    $accept.DialogResult=[Windows.Forms.DialogResult]::OK;$dlg.Controls.Add($accept)
    if($question){
        $cancel=Btn 'Cancelar' 322 278 136 36
        $cancel.DialogResult=[Windows.Forms.DialogResult]::Cancel;$dlg.Controls.Add($cancel)
        $dlg.CancelButton=$cancel
    }
    $dlg.AcceptButton=$accept
    try{
        if($null -ne $script:form -and $script:form.Visible){
            return ($dlg.ShowDialog($script:form) -eq [Windows.Forms.DialogResult]::OK)
        }
        return ($dlg.ShowDialog() -eq [Windows.Forms.DialogResult]::OK)
    }finally{$dlg.Dispose()}
}
function Notice([string]$message,[string]$title='MiR') {[void](MiRDialog $message $title)}
function ErrorBox([string]$message) {[void](MiRDialog $message 'MiR | Aviso' $false $true)}
function Confirm([string]$message) {return (MiRDialog $message 'MiR | Confirmar' $true)}
function ValidId([string]$id) { return ($id -match '^[A-Za-z0-9][A-Za-z0-9._:@-]{2,99}$') }
function NormalizeDevice($raw) {
    if($null -eq $raw -or $raw.id -isnot [string] -or $raw.name -isnot [string]){return $null}
    $id=$raw.id.Trim();$name=$raw.name.Trim()
    if(-not (ValidId $id) -or $name.Length -lt 1 -or $name.Length -gt 80){return $null}
    $notes=[string]$raw.notes;$group=[string]$raw.group
    if($notes.Length -gt 350){$notes=$notes.Substring(0,350)}
    if($group.Length -gt 35){$group=$group.Substring(0,35)}
    $favorite=($raw.favorite -eq $true)
    $lastUsed=[string]$raw.lastUsed
    if($lastUsed.Length -gt 30){$lastUsed=''}
    return [pscustomobject]@{name=$name;id=$id;group=$group.Trim();notes=$notes;favorite=$favorite;lastUsed=$lastUsed}
}
function EnsureRoot {
    if(-not (Test-Path -LiteralPath $script:Root)){
        [void](New-Item -ItemType Directory -Path $script:Root -Force)
    }
}
function SaveAtomic([string]$path,[string]$json) {
    EnsureRoot
    $tmp="$path.tmp";$bak="$path.bak"
    $utf8=New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tmp,$json,$utf8)
    try {
        if([System.IO.File]::Exists($path)){
            [System.IO.File]::Replace($tmp,$path,$bak,$true)
        }else{[System.IO.File]::Move($tmp,$path)}
    }catch{
        if(Test-Path -LiteralPath $tmp){Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue}
        throw
    }
}
function SaveDevices {
    if($script:loadError){throw 'La base original de equipos contiene errores. No se sobrescribira.'}
    $json=ConvertTo-Json -InputObject @($script:devices.ToArray()) -Depth 5
    SaveAtomic $script:DataPath $json
}
function SaveSettings {
    $json=ConvertTo-Json -InputObject $script:settings -Depth 3
    SaveAtomic $script:SettingsPath $json
}
function LoadData {
    EnsureRoot
    if(Test-Path -LiteralPath $script:SettingsPath){
        try{
            $s=Get-Content -LiteralPath $script:SettingsPath -Encoding UTF8 -Raw | ConvertFrom-Json
            if($s.rustdeskPath -is [string]){$script:settings.rustdeskPath=$s.rustdeskPath}
        }catch{$script:settings.rustdeskPath=''}
    }
    if(Test-Path -LiteralPath $script:DataPath){
        try{
            $raw=Get-Content -LiteralPath $script:DataPath -Encoding UTF8 -Raw | ConvertFrom-Json
            foreach($r in @($raw)){
                $d=NormalizeDevice $r
                if($null -ne $d -and $null -eq (FindDevice $d.id)){$script:devices.Add($d)}
            }
        }catch{
            $script:loadError=$true
            ErrorBox "No se puede leer equipos.json. No voy a sobrescribirlo.`r`n`r`n$($_.Exception.Message)"
        }
    }
}
function FindDevice([string]$id) {
    foreach($d in $script:devices){
        if([string]::Equals([string]$d.id,$id,[StringComparison]::OrdinalIgnoreCase)){return $d}
    }
    return $null
}
function FindRustDesk {
    $paths=New-Object 'System.Collections.Generic.List[string]'
    if($env:ProgramFiles){$paths.Add((Join-Path $env:ProgramFiles 'MiR\Host\RustDesk.exe'))}
    if($env:LOCALAPPDATA){$paths.Add((Join-Path $env:LOCALAPPDATA 'MiRemoto\Engine\v1.0\RustDesk.exe'))}
    # Motor local persistente, extraido del exe autonomo o importado manualmente.
    if($env:LOCALAPPDATA){$paths.Add((Join-Path $env:LOCALAPPDATA 'MiRemoto\Engine\RustDesk.exe'))}
    # Motor portable junto al ejecutable, si se distribuye en carpeta.
    $launchExe=[Environment]::GetEnvironmentVariable('MIREMOTO_LAUNCHER_EXE','Process')
    if($launchExe){$paths.Add((Join-Path ([IO.Path]::GetDirectoryName($launchExe)) 'Engine\RustDesk.exe'))}
    if($script:settings.rustdeskPath){$paths.Add($script:settings.rustdeskPath)}
    $paths.Add((Join-Path $PSScriptRoot 'RustDesk.exe'))
    if($env:ProgramFiles){$paths.Add((Join-Path $env:ProgramFiles 'RustDesk\RustDesk.exe'))}
    $pfx86=[Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if($pfx86){$paths.Add((Join-Path $pfx86 'RustDesk\RustDesk.exe'))}
    if($env:LOCALAPPDATA){
        $paths.Add((Join-Path $env:LOCALAPPDATA 'Programs\RustDesk\RustDesk.exe'))
        $paths.Add((Join-Path $env:LOCALAPPDATA 'RustDesk\RustDesk.exe'))
    }
    try{
        $cmd=Get-Command 'rustdesk.exe' -ErrorAction SilentlyContinue
        if($cmd -and $cmd.Source){$paths.Add([string]$cmd.Source)}
    }catch{}
    foreach($p in $paths){
        if($p -and (Test-Path -LiteralPath $p -PathType Leaf) -and ([IO.Path]::GetFileName($p) -ieq 'RustDesk.exe')){return $p}
    }
    return ''
}
function StartRustDesk([string]$id='',[string]$mode='desktop') {
    $exe=FindRustDesk
    if(-not $exe){ErrorBox 'El motor integrado no está disponible. Abrí MiR desde el portable autónomo generado.';return $false}
    if($id -and -not (ValidId $id)){ErrorBox 'El ID no es valido. No debe contener espacios ni comandos.';return $false}
    try{
        if(-not $id){Start-Process -FilePath $exe -ErrorAction Stop | Out-Null}
        else{
            $flag=if($mode -eq 'files'){'--file-transfer'}else{'--connect'}
            Start-Process -FilePath $exe -ArgumentList @($flag,$id) -ErrorAction Stop | Out-Null
            $d=FindDevice $id
            if($null -ne $d){
                $d.lastUsed=[DateTime]::UtcNow.ToString('o')
                try{SaveDevices}catch{ErrorBox "Sesion iniciada, pero no pude guardar ultimo uso: $($_.Exception.Message)"}
            }
        }
        return $true
    }catch{ErrorBox "El motor no pudo iniciarse: $($_.Exception.Message)";return $false}
}
function ConnectAndMinimize([string]$id,[string]$mode='desktop') {
    if((StartRustDesk $id $mode) -and $chkMinimize.Checked){
        $form.WindowState=[System.Windows.Forms.FormWindowState]::Minimized
    }
}
function GetRustDeskService {
    try{
        $service=Get-Service -Name 'RustDesk' -ErrorAction SilentlyContinue
        if($null -eq $service){return 'Inactivo'}
        $path=''
        try{$path=[string](Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\RustDesk' -Name ImagePath -ErrorAction Stop).ImagePath}catch{}
        $integrated=($path -match '\\MiR\\Host\\RustDesk\.exe')
        if($service.Status -eq 'Running'){
            if($integrated){return 'En ejecucion'}
            return 'Servicio anterior activo (migracion pendiente)'
        }
        if($integrated){return 'Integrado, pero detenido'}
        return 'Servicio anterior detenido (migracion pendiente)'
    }catch{return 'No disponible'}
}
function GetMiRHostIndependence {
    # El resultado NO sustituye una prueba de conexion desde otro equipo y Android.
    try {
        $svc=Get-CimInstance Win32_Service -Filter "Name='RustDesk'" -ErrorAction Stop
        if($null -eq $svc){return 'NO VERIFICADO: receptor no registrado'}
        $path=[string]$svc.PathName
        if($path -notmatch '(?i)\\MiR\\Host\\RustDesk\.exe'){
            return 'DEPENDENCIA ACTIVA: el servicio no apunta al receptor incorporado de MiR'
        }
        $binary=Join-Path $env:ProgramFiles 'MiR\Host\RustDesk.exe'
        if(-not (Test-Path -LiteralPath $binary -PathType Leaf)){
            return 'INCOMPLETO: falta el archivo del receptor integrado'
        }
        if($svc.State -ne 'Running'){
            return 'NO LISTO: receptor MiR registrado pero detenido'
        }
        return 'CANDIDATO: servicio MiR en ejecucion; faltan pruebas desde Windows y Android sin el cliente anterior'
    }catch{return 'NO VERIFICADO: no se pudo consultar el servicio de Windows'}
}
function GetNetworkInfo {
    try{
        $nics=@([System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object {
            $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -ne 'Loopback' -and $_.NetworkInterfaceType -ne 'Tunnel'
        })
        if($nics.Count -gt 0){return 'Adaptador de red activo (Internet no verificado)'}
        return 'Sin adaptador de red activo'
    }catch{return 'No se pudo comprobar la red'}
}
function IsStartupEnabled { return (Test-Path -LiteralPath $script:StartLink -PathType Leaf) }
function SetStartup([bool]$enabled) {
    if($enabled){
        $shell=New-Object -ComObject WScript.Shell
        $lnk=$shell.CreateShortcut($script:StartLink)
        $launchExe=[Environment]::GetEnvironmentVariable('MIREMOTO_LAUNCHER_EXE','Process')
        if($launchExe -and (Test-Path -LiteralPath $launchExe -PathType Leaf) -and ([IO.Path]::GetExtension($launchExe) -ieq '.exe')){
            $lnk.TargetPath=$launchExe
            $lnk.Arguments=''
            $lnk.WorkingDirectory=[IO.Path]::GetDirectoryName($launchExe)
        }else{
            $lnk.TargetPath=Join-Path $PSHOME 'powershell.exe'
            $lnk.Arguments='-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + (Join-Path $PSScriptRoot 'MiRemoto.ps1') + '"'
            $lnk.WorkingDirectory=$PSScriptRoot
        }
        $lnk.Description='MiR - Acceso remoto | Desarrollado por EcoEtika S.A.S.'
        $icon=Join-Path $PSScriptRoot 'MiRemoto.ico'
        if(Test-Path -LiteralPath $icon){$lnk.IconLocation=$icon}
        $lnk.Save()
    }else{
        if(IsStartupEnabled){Remove-Item -LiteralPath $script:StartLink -Force}
    }
}
function SyncExistingStartupShortcut {
    if(-not (IsStartupEnabled)){return}
    $exe=[Environment]::GetEnvironmentVariable('MIREMOTO_LAUNCHER_EXE','Process')
    if(-not $exe -or -not (Test-Path -LiteralPath $exe -PathType Leaf)){return}
    # No redirigir un acceso de inicio existente a un portable que puede moverse de carpeta/USB.
    $installed=Join-Path $env:LOCALAPPDATA 'Programs\MiR\MiR.exe'
    if(-not [String]::Equals($exe,$installed,[StringComparison]::OrdinalIgnoreCase)){return}
    try{
        $shell=New-Object -ComObject WScript.Shell
        $link=$shell.CreateShortcut($script:StartLink)
        if($link.TargetPath -ine $exe){SetStartup $true}
    }catch{}
}
function OwnId {
    $exe=FindRustDesk
    if(-not $exe){throw 'No se encontro el motor remoto integrado o externo.'}
    $si=New-Object System.Diagnostics.ProcessStartInfo
    $si.FileName=$exe;$si.Arguments='--get-id';$si.UseShellExecute=$false
    $si.RedirectStandardOutput=$true;$si.RedirectStandardError=$true;$si.CreateNoWindow=$true
    $p=[System.Diagnostics.Process]::Start($si)
    try{
        if(-not $p.WaitForExit(5000)){
            try{$p.Kill()}catch{}
            throw 'El equipo no respondió a la consulta de ID. Abrí la configuración de conexión para consultarlo.'
        }
        $id=$p.StandardOutput.ReadToEnd().Trim()
        if(-not (ValidId $id)){throw 'No se obtuvo un ID válido. Revisá la configuración de recepción.'}
        return $id
    }finally{$p.Dispose()}
}
function ExportDevices {
    if($script:loadError){ErrorBox 'No se puede exportar: el archivo de origen contiene errores.';return}
    $dlg=New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter='JSON (*.json)|*.json';$dlg.FileName='MiRemoto_equipos.json'
    $dlg.Title='Exportar equipos (sin contrasenas)'
    if($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
        try{
            $json=ConvertTo-Json -InputObject @($script:devices.ToArray()) -Depth 5
            $utf8=New-Object System.Text.UTF8Encoding($false)
            [IO.File]::WriteAllText($dlg.FileName,$json,$utf8)
            Notice 'Equipos exportados. Se preservan los campos históricos del respaldo; no se exportan las contraseñas del motor de conexión.'
        }catch{ErrorBox "No pude exportar: $($_.Exception.Message)"}
    }
}
function ImportDevices {
    if($script:loadError){ErrorBox 'No se puede importar mientras el archivo de equipos original tenga errores.';return}
    $dlg=New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter='JSON (*.json)|*.json';$dlg.Title='Importar equipos MiR'
    if($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){return}
    try{
        if((Get-Item -LiteralPath $dlg.FileName).Length -gt 1048576){throw 'El JSON supera el limite de 1 MB.'}
        $raw=Get-Content -LiteralPath $dlg.FileName -Raw -Encoding UTF8 | ConvertFrom-Json
        $items=@($raw)
        if($items.Count -gt 2000){throw 'Demasiados equipos en el archivo.'}
        $new=New-Object 'System.Collections.Generic.List[object]'
        $skipped=0
        foreach($r in $items){
            $d=NormalizeDevice $r
            if($null -eq $d -or $null -ne (FindDevice ([string]$r.id))){$skipped++;continue}
            $found=$false
            foreach($x in $new){if($x.id -ieq $d.id){$found=$true;break}}
            if($found){$skipped++;continue}
            $new.Add($d)
        }
        if($new.Count -eq 0){Notice "No se encontraron equipos nuevos. Omitidos: $skipped.";return}
        if(-not (Confirm "Se agregaran $($new.Count) equipos nuevos. No se reemplazaran los existentes. Continuar?")){return}
        foreach($d in $new){$script:devices.Add($d)}
        try{SaveDevices}catch{
            foreach($d in $new){[void]$script:devices.Remove($d)}
            throw
        }
        RefreshList
        Notice "Importados: $($new.Count). Omitidos por duplicados o datos incorrectos: $skipped."
    }catch{ErrorBox "No pude importar el archivo: $($_.Exception.Message)"}
}
function HelpUnattended {
    $message=@'
RECEPCION SEGURA EN TU EQUIPO

- Para recibir conexiones con Windows cerrado, activá Receptor MiR (requiere permisos de administrador).
- El equipo debe permanecer encendido y conectado a Internet o a la red local.
- Configurá una contraseña permanente robusta y única; no la compartas.
- Para reemplazar un servicio anterior, realizá la migración localmente, no desde una conexión remota.
- Revisá periódicamente las autorizaciones, actualizaciones y los equipos que pueden conectarse.

MiR no almacena contraseñas en el listado de equipos.
'@
    Notice $message 'MiR | Recepción y seguridad'
}
function ActivateMiRHost {
    $helper=Join-Path $PSScriptRoot 'MiR_Host.exe'
    if(-not (Test-Path -LiteralPath $helper -PathType Leaf)){
        ErrorBox 'Falta el componente del receptor. Ejecutá el paquete autónomo MiR V1 actualizado.'
        return
    }
    if(-not (Confirm 'Se solicitará permiso de administrador para activar el receptor MiR. Si existe un servicio anterior, la migración requerirá tu autorización adicional. ¿Continuar?')){return}
    try{
        $p=Start-Process -FilePath $helper -Verb RunAs -PassThru -Wait -ErrorAction Stop
        UpdateStatus
        $estado=GetRustDeskService
        if($p.ExitCode -ne 0){
            Notice 'La migración no se completó. El asistente mostró el motivo y, si fue posible, restauró el receptor anterior. Comprobá el estado local antes de cerrar sesión o reiniciar.' 'MiR | Migración no completada'
        }elseif($estado -eq 'En ejecucion'){
            Notice 'El receptor MiR figura activo en Windows. Verificá ahora el acceso desde otra computadora antes de retirar instalaciones anteriores.' 'MiR | Receptor activo'
        }else{
            Notice ("No se confirmó la activación del receptor. Estado actual: $estado. Si cancelaste la operación, no se modificó el servicio.") 'MiR | Receptor sin cambios'
        }
    }catch{ErrorBox "No pude iniciar el asistente de receptor: $($_.Exception.Message)"}
}
function MakeReport {
    $exe=FindRustDesk
    $version='No disponible'
    if($exe){try{$version=[Diagnostics.FileVersionInfo]::GetVersionInfo($exe).FileVersion}catch{}}
    $startup=if(IsStartupEnabled){'Activado para este usuario'}else{'Desactivado'}
    $engine=if($exe){'Incorporado y disponible'}else{'No detectado'}
    $os=[Environment]::OSVersion.VersionString
    $report=@(
        'MIR - DIAGNOSTICO LOCAL (sin contraseñas ni IDs)',
        "Version MiR: $script:Version",
        "Windows: $os",
        "Motor remoto: $engine",
        "Version motor: $version",
        "Receptor remoto: $(GetRustDeskService)",
        "Independencia del receptor: $(GetMiRHostIndependence)",
        "Inicio MiR con Windows: $startup",
        "Red: $(GetNetworkInfo)",
        "Equipos guardados: $($script:devices.Count)",
        "Datos locales: $script:Root",
        "Datos recuperados: $(if($script:loadError){'Error al leer JSON'}else{'OK'})",
        'IMPORTANTE: MiR no verifica conectividad externa, permisos ni contraseñas.'
    ) -join [Environment]::NewLine
    return $report
}

LoadData
SyncExistingStartupShortcut

# Nota: la personalizacion definitiva del icono de la barra de tareas
# requiere que la interfaz se ejecute nativamente desde un exe MiR.
# Esta identidad ayuda a que Windows agrupe el formulario MiR de forma coherente.
try {
    if(-not ('MiRAppIdentity' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class MiRAppIdentity {
 [DllImport("shell32.dll", CharSet=CharSet.Unicode)]
 public static extern int SetCurrentProcessExplicitAppUserModelID(string appID);
}
'@
    }
    [void][MiRAppIdentity]::SetCurrentProcessExplicitAppUserModelID('EcoEtika.MiR.Windows')
}catch{}

$form=New-Object System.Windows.Forms.Form
$form.Text='MiR | Acceso remoto'
$form.ClientSize=[System.Drawing.Size]::new(1160,655)
$form.StartPosition='CenterScreen';$form.BackColor=$C.Window;$form.ForeColor=$C.Text
$form.Font=Fnt 10;$form.FormBorderStyle='Sizable';$form.MaximizeBox=$true
$form.AutoScaleMode='None';$form.MinimumSize=[System.Drawing.Size]::new(820,600)
$iconPath=Join-Path $PSScriptRoot 'MiRemoto.ico'
if(Test-Path -LiteralPath $iconPath){try{$form.Icon=[System.Drawing.Icon]::new($iconPath)}catch{}}
# Identidad MiR: logo transparente en cabecera; titulo alternativo si faltara el recurso.
$mirLogoPath=Join-Path $PSScriptRoot 'assets\MiR_logo.png'
if(Test-Path -LiteralPath $mirLogoPath){
    try{
        $picMir=New-Object System.Windows.Forms.PictureBox
        $picMir.SetBounds(25,6,151,63)
        $picMir.BackColor=$C.Window
        $picMir.SizeMode=[System.Windows.Forms.PictureBoxSizeMode]::Zoom
        $picMir.Image=[System.Drawing.Image]::FromFile($mirLogoPath)
        $form.Controls.Add($picMir)
    }catch{$form.Controls.Add((Lbl 'MiR' 26 18 160 49 25 $true))}
}else{$form.Controls.Add((Lbl 'MiR' 26 18 160 49 25 $true))}
# Se elimina la segunda leyenda MiR: el logo es suficiente.
$lblSubtitle=Lbl 'Acceso remoto | Windows + Android' 188 42 560 24 9 $false $C.Muted
$form.Controls.Add($lblSubtitle)
$lblTop=Lbl '' 784 17 356 28 9.5 $true $C.Accent
$lblTop.TextAlign='MiddleRight';$form.Controls.Add($lblTop)
$chkMinimize=New-Object System.Windows.Forms.CheckBox
$chkMinimize.SetBounds(862,49,278,26)
$chkMinimize.Text='Minimizar MiR al conectar'
$chkMinimize.ForeColor=$C.Muted
$chkMinimize.BackColor=$C.Window
$chkMinimize.Font=Fnt 9
$chkMinimize.Checked=$true
$form.Controls.Add($chkMinimize)

# Navegacion MiR propia. Reemplaza las pestanas nativas de WinForms,
# cuyo fondo blanco y bordes cuadrados no admiten el estilo deseado.
$tabs=Pane 20 86 1120 520
$form.Controls.Add($tabs)
$nav=Pane 0 0 1120 43
$nav.BackColor=$C.Window
$tabs.Controls.Add($nav)
$pageHost=Pane 0 43 1120 477
$pageHost.BackColor=$C.Window
$tabs.Controls.Add($pageHost)
$script:MiRPages=@{}
$script:MiRTabButtons=@{}
function TopRoundTab([System.Windows.Forms.Button]$control) {
    if($control.Width -lt 12 -or $control.Height -lt 12){return}
    $radius=11;$diam=22;$w=$control.Width-1;$h=$control.Height-1
    $path=New-Object System.Drawing.Drawing2D.GraphicsPath
    try {
        $path.StartFigure()
        $path.AddArc(0,0,$diam,$diam,180,90)
        $path.AddArc($w-$diam,0,$diam,$diam,270,90)
        $path.AddLine($w,$radius,$w,$h)
        $path.AddLine($w,$h,0,$h)
        $path.AddLine(0,$h,0,$radius)
        $path.CloseFigure()
        $region=[System.Drawing.Region]::new($path)
        $old=$control.Region;$control.Region=$region
        if($null -ne $old){$old.Dispose()}
    }finally{$path.Dispose()}
}
function Tab([string]$name,[string]$key,[int]$index) {
    $page=Pane 0 0 1120 477
    # La ventana compacta distribuye las acciones sin una barra lateral de desplazamiento.
    $page.AutoScroll=$false
    $page.Visible=$false
    $pageHost.Controls.Add($page)
    $script:MiRPages[$key]=$page
    $button=Btn $name (7 + ($index*247)) 4 237 38
    $button.Font=Fnt 9.7 $false
    $button.Add_SizeChanged({param($sender,$e) TopRoundTab $sender})
    TopRoundTab $button
    $nav.Controls.Add($button)
    $script:MiRTabButtons[$key]=$button
    return $page
}
function SelectMiRTab([string]$key) {
    foreach($k in @($script:MiRPages.Keys)) {
        $selected=($k -eq $key)
        $script:MiRPages[$k].Visible=$selected
        $b=$script:MiRTabButtons[$k]
        if($selected){
            $b.BackColor=$C.Field;$b.ForeColor=$C.Accent
            $b.FlatAppearance.BorderColor=$C.Accent
            $script:MiRPages[$k].BringToFront()
        }else{
            $b.BackColor=$C.Card;$b.ForeColor=$C.Text
            $b.FlatAppearance.BorderColor=$C.Edge
        }
    }
}
$tDevices=Tab 'Mis equipos' 'devices' 0
$tLocal=Tab 'Mi equipo / Receptor' 'local' 1
$tFeatures=Tab 'Sesiones y archivos' 'features' 2
$tTools=Tab 'Diagnostico' 'tools' 3
$script:MiRTabButtons['devices'].Add_Click({SelectMiRTab 'devices'})
$script:MiRTabButtons['local'].Add_Click({SelectMiRTab 'local'})
$script:MiRTabButtons['features'].Add_Click({SelectMiRTab 'features'})
$script:MiRTabButtons['tools'].Add_Click({SelectMiRTab 'tools'})
SelectMiRTab 'devices'

# TAB 1: LISTADO Y ACCIONES SOBRE EQUIPOS
$pList=Pane 12 14 683 533;$tDevices.Controls.Add($pList)
$pList.Controls.Add((Lbl 'MIS EQUIPOS' 18 12 200 27 11 $true))
$pList.Controls.Add((Lbl 'Busca, guarda y conecta equipos propios.' 18 41 500 22 9 $false $C.Muted))
$pList.Controls.Add((Lbl 'Buscar' 18 64 66 22 9 $false $C.Muted))
$txtSearch=Txt 98 72 568 31;$pList.Controls.Add($txtSearch)
$list=New-Object System.Windows.Forms.ListView
$list.SetBounds(18,115,648,395);$list.View='Details';$list.FullRowSelect=$true
$list.MultiSelect=$false;$list.HideSelection=$false;$list.GridLines=$false
$list.BackColor=$C.Field;$list.ForeColor=$C.Text;$list.BorderStyle='FixedSingle';$list.Font=Fnt 9.5
[void]$list.Columns.Add('Favorito / Equipo',245)
[void]$list.Columns.Add('ID remoto',220)
[void]$list.Columns.Add('Grupo',155)
$pList.Controls.Add($list)

$pEditor=Pane 706 14 398 533;$tDevices.Controls.Add($pEditor)
$pEditor.Controls.Add((Lbl 'DETALLE DEL EQUIPO' 16 10 360 25 11 $true))
$pEditor.Controls.Add((Lbl 'Nombre' 16 38 350 19 9 $false $C.Muted))
$txtName=Txt 16 58 366 27;$pEditor.Controls.Add($txtName)
$pEditor.Controls.Add((Lbl 'ID del equipo o direccion LAN admitida' 16 89 368 20 9 $false $C.Muted))
$txtId=Txt 16 110 366 27;$pEditor.Controls.Add($txtId)
$pEditor.Controls.Add((Lbl 'Grupo (opcional)' 16 142 366 19 9 $false $C.Muted))
$txtGroup=Txt 16 162 366 27;$pEditor.Controls.Add($txtGroup)
$chkFavorite=New-Object System.Windows.Forms.CheckBox
$chkFavorite.Text='Equipo favorito';$chkFavorite.SetBounds(18,185,270,25)
$chkFavorite.ForeColor=$C.Text;$chkFavorite.BackColor=$C.Card;$chkFavorite.Font=Fnt 9.5
$pEditor.Controls.Add($chkFavorite)
$btnNew=Btn 'Nuevo' 16 212 107 31
$btnSave=Btn 'Guardar' 132 212 128 31 $true
$btnDelete=Btn 'Eliminar' 269 212 113 31
$pEditor.Controls.AddRange(@($btnNew,$btnSave,$btnDelete))
$btnConnect=Btn 'Controlar pantalla' 16 252 366 38 $true
$btnTransfer=Btn 'Transferir archivos' 16 299 366 34
$pEditor.Controls.AddRange(@($btnConnect,$btnTransfer))

$pDevBar=Pane 12 558 1092 48;$tDevices.Controls.Add($pDevBar)
$btnOpen=Btn 'Mi equipo / receptor' 10 8 180 32
$btnCopyId=Btn 'Copiar ID' 200 8 211 32
$btnExportA=Btn 'Exportar equipos' 421 8 198 32
$btnImportA=Btn 'Importar equipos' 629 8 190 32
$btnSecurityA=Btn 'Acceso desatendido' 829 8 252 32
$pDevBar.Controls.AddRange(@($btnOpen,$btnCopyId,$btnExportA,$btnImportA,$btnSecurityA))

# TAB 2: MI EQUIPO
$pStatus=Pane 15 18 1090 228;$tLocal.Controls.Add($pStatus)
$pStatus.Controls.Add((Lbl 'ESTADO DE ESTA COMPUTADORA' 18 7 700 27 12 $true))
$lblService=Lbl '' 20 62 980 25 10 $false $C.Text
$lblExe=Lbl '' 20 96 1030 26 9 $false $C.Muted
$lblNet=Lbl '' 20 128 1030 25 9 $false $C.Muted
$lblMyId=Lbl 'Mi ID remoto: consultar para mostrarlo' 20 158 940 28 10 $true $C.Accent
$pStatus.Controls.AddRange(@($lblService,$lblExe,$lblNet,$lblMyId))
$btnRefresh=Btn 'Actualizar estado' 20 191 205 29
$btnOwnId=Btn 'Consultar mi ID' 234 191 205 29
$btnCopyOwnId=Btn 'Copiar mi ID' 448 191 195 29
$btnLocalRust=Btn 'Activar receptor MiR' 652 191 200 29
$pStatus.Controls.AddRange(@($btnRefresh,$btnOwnId,$btnCopyOwnId,$btnLocalRust))
$pUnatt=Pane 15 263 1090 317;$tLocal.Controls.Add($pUnatt)
$pUnatt.Controls.Add((Lbl 'ACCESO DESATENDIDO Y ARRANQUE' 18 15 1000 30 12 $true))
$pUnatt.Controls.Add((Lbl 'MiR puede actuar como receptor al iniciar Windows cuando activás su servicio de acceso desatendido (requiere autorización de administrador).' 18 54 1040 46 10 $false $C.Text))
$lblStartup=Lbl '' 18 107 1040 25 10 $false $C.Muted
$btnUnatt=Btn 'Activar receptor MiR' 18 143 318 41 $true
$btnStartup=Btn 'Activar inicio de MiR' 349 143 318 41

$btnPower=Btn 'Opciones de energía' 680 143 190 41
$btnDisableHost=Btn 'Desactivar receptor' 882 143 190 41
$pUnatt.Controls.AddRange(@($lblStartup,$btnUnatt,$btnStartup,$btnPower,$btnDisableHost))
$lblUnattWarn=Lbl 'Para recibir conexiones antes del inicio de sesión en Windows, activá el Receptor MiR y configurá una contraseña segura.' 18 209 1050 40 10 $false $C.Warn
$lblUnattTip=Lbl 'El equipo receptor debe permanecer encendido, sin suspensión y conectado a la red. Para Internet utilizamos infraestructura de conexión externa.' 18 261 1050 40 10 $false $C.Muted
$pUnatt.Controls.AddRange(@($lblUnattWarn,$lblUnattTip))

# TAB 3: CAPACIDADES DEL MOTOR (acciones explicitas + informacion)
$pF1=Pane 15 18 528 259;$tFeatures.Controls.Add($pF1)
$pF1.Controls.Add((Lbl 'CONTROL, MONITORES Y PORTAPAPELES' 17 15 490 31 11 $true))
$pF1.Controls.Add((Lbl 'Controlá teclado y mouse, elegí monitores y sincronizá el portapapeles durante una sesión autorizada.' 17 58 490 100 10 $false $C.Text))
$btnOpenF1=Btn 'Elegir equipo para conectar' 17 186 492 42 $false
$pF1.Controls.Add($btnOpenF1)
$pF2=Pane 558 18 547 259;$tFeatures.Controls.Add($pF2)
$pF2.Controls.Add((Lbl 'ARCHIVOS Y CONEXION' 17 15 500 31 11 $true))
$pF2.Controls.Add((Lbl 'Seleccioná un equipo en Mis equipos y elegí Transferir archivos. Las conexiones pueden utilizar Internet o la red local.' 17 58 506 110 10 $false $C.Text))
$btnOpenF2=Btn 'Ir a Mis equipos' 17 186 513 42
$pF2.Controls.Add($btnOpenF2)
$pF3=Pane 15 292 1090 299;$tFeatures.Controls.Add($pF3)
$pF3.Controls.Add((Lbl 'SEGURIDAD Y ACCESO' 17 15 1040 31 11 $true))
$pF3.Controls.Add((Lbl 'Android: podés conectarte desde el celular con el cliente que ya probaste. La APK MiR propia está en desarrollo.' 17 54 1040 46 10 $false $C.Text))
$pF3.Controls.Add((Lbl 'Seguridad: MiR no guarda contraseñas. Para el acceso desatendido, comprobá el receptor y sus permisos.' 17 120 1040 47 10 $false $C.Text))
$pF3.Controls.Add((Lbl 'Red: MiR utiliza el servicio de conexión configurado. La infraestructura independiente sigue pendiente.' 17 184 1040 48 10 $false $C.Muted))
$btnOpenF3=Btn 'Ver seguridad y receptor' 17 236 515 37
$btnShowGuide=Btn 'Ver recomendaciones de seguridad' 545 236 527 37
$pF3.Controls.AddRange(@($btnOpenF3,$btnShowGuide))

# TAB 4: DIAGNOSTICO
$pTools=Pane 15 18 1090 560;$tTools.Controls.Add($pTools)
$pTools.Controls.Add((Lbl 'DIAGNOSTICO LOCAL - SIN CREDENCIALES' 18 14 900 31 11 $true))
$txtReport=Txt 18 55 1054 295 $true
$txtReport.ReadOnly=$true;$txtReport.WordWrap=$false
$txtReport.Font=[System.Drawing.Font]::new('Consolas',9.5)
$pTools.Controls.Add($txtReport)
$btnDiag=Btn 'Actualizar diagnostico' 18 363 248 40 $true
$btnCopyReport=Btn 'Copiar diagnostico' 275 363 240 40
$btnLocate=Btn 'Acerca de MiR' 524 363 265 40
$btnDataFolder=Btn 'Abrir datos locales' 798 363 274 40
$pTools.Controls.AddRange(@($btnDiag,$btnCopyReport,$btnLocate,$btnDataFolder))
$btnExportB=Btn 'Exportar equipos (JSON)' 18 423 514 40
$btnImportB=Btn 'Importar equipos (JSON)' 545 423 527 40
$pTools.Controls.AddRange(@($btnExportB,$btnImportB))
$pTools.Controls.Add((Lbl 'Los respaldos incluyen los datos anteriores; MiR no consulta ni exporta contraseñas almacenadas por el motor.' 18 491 1055 47 10 $false $C.Muted))

$script:MiRFooter=Lbl 'MiR V1 | Desarrollado por EcoEtika S.A.S. | Distribución gratuita' 27 771 855 23 9 $false $C.Muted
$form.Controls.Add($script:MiRFooter)
# Firma institucional proporcionada por el usuario en el extremo inferior derecho.
$ecoLogoPath=Join-Path $PSScriptRoot 'assets\EcoEtika_logo.png'
if(Test-Path -LiteralPath $ecoLogoPath){
    try{
        $picEco=New-Object System.Windows.Forms.PictureBox
        $picEco.SetBounds(952,760,206,40)
        $picEco.BackColor=[System.Drawing.Color]::Transparent
        $picEco.SizeMode=[System.Windows.Forms.PictureBoxSizeMode]::Zoom
        $picEco.Image=[System.Drawing.Image]::FromFile($ecoLogoPath)
        $form.Controls.Add($picEco)
    }catch{}
}

# ESTADO Y EVENTOS
function UpdateStatus {
    $exe=FindRustDesk
    $internal=if($env:LOCALAPPDATA){Join-Path $env:LOCALAPPDATA 'MiRemoto\Engine\v1.0\RustDesk.exe'}else{''}
    if($exe){
        if($internal -and [string]::Equals($exe,$internal,[StringComparison]::OrdinalIgnoreCase)) {
            $lblTop.Text='MiR LISTO PARA CONECTAR'
        }else{$lblTop.Text='MiR LISTO PARA CONECTAR'}
        $lblTop.ForeColor=$C.Accent;$lblExe.Text='Componentes de conexión: disponibles'
    }else{$lblTop.Text='MiR NO PREPARADO';$lblTop.ForeColor=$C.Warn
        $lblExe.Text='No se encontraron los componentes de conexión de MiR. Utilizá el paquete autónomo.'
    }
    $service=GetRustDeskService
    $lblService.Text="Receptor de esta PC: $service"
    $lblService.ForeColor=if($service -eq 'En ejecucion'){$C.Accent}else{$C.Warn}
    $lblNet.Text="Red: $(GetNetworkInfo)"
    if(IsStartupEnabled){
        $lblStartup.Text='Inicio de MiR con Windows: activado para este usuario'
        $btnStartup.Text='Desactivar inicio de MiR'
    }else{
        $lblStartup.Text='Inicio de MiR con Windows: desactivado'
        $btnStartup.Text='Activar inicio de MiR'
    }
    $txtReport.Text=MakeReport
}
function RefreshList([string]$selectId='') {
    $term=$txtSearch.Text.Trim()
    $list.BeginUpdate()
    try{
        $list.Items.Clear()
        $ordered=@($script:devices | Sort-Object @{Expression='favorite';Descending=$true}, @{Expression='name';Descending=$false})
        foreach($d in $ordered){
            $searchText="$($d.name) $($d.id) $($d.group) $($d.notes)"
            if($term -and $searchText.IndexOf($term,[StringComparison]::OrdinalIgnoreCase) -lt 0){continue}
            $prefix=if($d.favorite){'[F] '}else{''}
            $item=[System.Windows.Forms.ListViewItem]::new($prefix+[string]$d.name)
            [void]$item.SubItems.Add([string]$d.id)
            [void]$item.SubItems.Add([string]$d.group)
            $item.Tag=[string]$d.id
            [void]$list.Items.Add($item)
            if($selectId -and $d.id -ieq $selectId){$item.Selected=$true}
        }
    }finally{$list.EndUpdate()}
}
function ClearEditor {
    $script:selectedId=''
    $txtName.Text='';$txtId.Text='';$txtGroup.Text='';$chkFavorite.Checked=$false
    foreach($x in @($list.SelectedItems)){$x.Selected=$false}
    [void]$txtName.Focus()
}
function PickCurrentId {
    $id=$txtId.Text.Trim()
    if(-not $id -and $list.SelectedItems.Count -gt 0){$id=[string]$list.SelectedItems[0].Tag}
    return $id
}
$list.Add_SelectedIndexChanged({
    if($list.SelectedItems.Count -eq 0){return}
    $d=FindDevice ([string]$list.SelectedItems[0].Tag)
    if($null -eq $d){return}
    $script:selectedId=[string]$d.id
    $txtName.Text=[string]$d.name;$txtId.Text=[string]$d.id
    $txtGroup.Text=[string]$d.group
    $chkFavorite.Checked=($d.favorite -eq $true)
})
$list.Add_DoubleClick({
    if($list.SelectedItems.Count -gt 0){ConnectAndMinimize ([string]$list.SelectedItems[0].Tag) 'desktop'}
})
$txtSearch.Add_TextChanged({RefreshList})
$btnNew.Add_Click({ClearEditor})
$btnSave.Add_Click({
    $name=$txtName.Text.Trim();$id=$txtId.Text.Trim();$group=$txtGroup.Text.Trim();$notes=''
    if($script:selectedId){$original=FindDevice $script:selectedId;if($null -ne $original){$notes=[string]$original.notes}}
    if($name.Length -lt 1 -or $name.Length -gt 80){ErrorBox 'El nombre debe tener entre 1 y 80 caracteres.';return}
    if(-not (ValidId $id)){ErrorBox 'ID inválido: usá un ID remoto o una dirección de red admitida, sin espacios.';return}
    if($group.Length -gt 35){ErrorBox 'Grupo máximo: 35 caracteres.';return}
    $dup=FindDevice $id
    if($dup -and $dup.id -ine $script:selectedId){ErrorBox 'Ese ID ya existe.';return}
    try{
        if($script:selectedId){
            $d=FindDevice $script:selectedId
            if($null -eq $d){throw 'El equipo seleccionado ya no existe.'}
            $previous=[pscustomobject]@{name=$d.name;id=$d.id;group=$d.group;notes=$d.notes;favorite=$d.favorite;lastUsed=$d.lastUsed}
            $d.name=$name;$d.id=$id;$d.group=$group;$d.notes=$notes;$d.favorite=$chkFavorite.Checked
            try{SaveDevices}catch{
                $d.name=$previous.name;$d.id=$previous.id;$d.group=$previous.group;$d.notes=$previous.notes;$d.favorite=$previous.favorite
                throw
            }
        }else{
            $d=[pscustomobject]@{name=$name;id=$id;group=$group;notes=$notes;favorite=$chkFavorite.Checked;lastUsed=''}
            $script:devices.Add($d)
            try{SaveDevices}catch{[void]$script:devices.Remove($d);throw}
        }
        $script:selectedId=$id;RefreshList $id;UpdateStatus
    }catch{ErrorBox "No pude guardar: $($_.Exception.Message)"}
})
$btnDelete.Add_Click({
    if(-not $script:selectedId){Notice 'Selecciona un equipo primero.';return}
    $d=FindDevice $script:selectedId
    if($null -eq $d){return}
    if(-not (Confirm "Eliminar '$($d.name)' de MiRemoto? El equipo remoto no sera modificado.")){return}
    try{
        [void]$script:devices.Remove($d)
        try{SaveDevices}catch{$script:devices.Add($d);throw}
        ClearEditor;RefreshList;UpdateStatus
    }catch{ErrorBox "No pude eliminar: $($_.Exception.Message)"}
})
$btnConnect.Add_Click({$id=PickCurrentId;if(-not $id){Notice 'Selecciona o escribe un ID.';return};ConnectAndMinimize $id 'desktop'})
$btnTransfer.Add_Click({$id=PickCurrentId;if(-not $id){Notice 'Selecciona o escribe un ID.';return};ConnectAndMinimize $id 'files'})
$btnOpen.Add_Click({SelectMiRTab 'local'})
$btnCopyId.Add_Click({
    $id=PickCurrentId
    if(-not (ValidId $id)){Notice 'Selecciona un ID valido.';return}
    [System.Windows.Forms.Clipboard]::SetText($id);Notice 'ID copiado al portapapeles.'
})
$btnExportA.Add_Click({ExportDevices})
$btnImportA.Add_Click({ImportDevices})
$btnSecurityA.Add_Click({SelectMiRTab 'local';ActivateMiRHost})
$btnRefresh.Add_Click({UpdateStatus})
$btnOwnId.Add_Click({
    try{$id=OwnId;$lblMyId.Text="Mi ID remoto: $id";$lblMyId.Tag=$id}
    catch{$lblMyId.Tag='';ErrorBox $_.Exception.Message}
})
$btnCopyOwnId.Add_Click({
    $id=[string]$lblMyId.Tag
    if(-not (ValidId $id)){Notice 'Primero presiona Consultar mi ID.';return}
    [System.Windows.Forms.Clipboard]::SetText($id);Notice 'Tu ID fue copiado.'
})
$btnLocalRust.Add_Click({ActivateMiRHost})
$btnUnatt.Add_Click({ActivateMiRHost})
$btnStartup.Add_Click({
    try{SetStartup (-not (IsStartupEnabled));UpdateStatus}
    catch{ErrorBox "No pude cambiar el inicio de sesion: $($_.Exception.Message)"}
})
$btnDisableHost.Add_Click({
    $helper=Join-Path $PSScriptRoot 'MiR_Host.exe'
    if(-not (Test-Path -LiteralPath $helper)){ErrorBox 'No encuentro el componente de administración del receptor.';return}
    if(-not (Confirm 'Desactivar la recepción impide entrar a esta PC antes del inicio de sesión. Realizá esta acción localmente. ¿Continuar?')){return}
    try{Start-Process -FilePath $helper -Verb RunAs -ArgumentList '--deactivate' -Wait -ErrorAction Stop | Out-Null;UpdateStatus}
    catch{ErrorBox $_.Exception.Message}
})
$btnPower.Add_Click({
    try{Start-Process -FilePath 'control.exe' -ArgumentList 'powercfg.cpl' -ErrorAction Stop | Out-Null}
    catch{ErrorBox "No pude abrir Energia de Windows: $($_.Exception.Message)"}
})
$btnOpenF1.Add_Click({SelectMiRTab 'devices'})
$btnOpenF2.Add_Click({SelectMiRTab 'devices'})
$btnOpenF3.Add_Click({SelectMiRTab 'local'})
$btnShowGuide.Add_Click({HelpUnattended})
$btnDiag.Add_Click({UpdateStatus})
$btnCopyReport.Add_Click({[System.Windows.Forms.Clipboard]::SetText($txtReport.Text);Notice 'Diagnostico copiado al portapapeles.'})
$btnLocate.Add_Click({
    Notice "MiR V1 | Desarrollado por EcoEtika S.A.S. | Distribución gratuita`r`n`r`nDesarrollado sobre la base de RustDesk.`r`nCódigo y licencia del motor: https://github.com/rustdesk/rustdesk (AGPL-3.0).`r`nLos avisos de licencia y los derechos de terceros se conservan en la distribución." 'MiR | Acerca de'
})
$btnDataFolder.Add_Click({try{Start-Process -FilePath 'explorer.exe' -ArgumentList ('"'+$script:Root+'"') | Out-Null}catch{ErrorBox $_.Exception.Message}})
$btnExportB.Add_Click({ExportDevices})
$btnImportB.Add_Click({ImportDevices})
# MiR V1.4: todas las solapas principales tienen una distribución compacta.
# No se usan barras de desplazamiento en resoluciones de notebook habituales.
$script:ReflowBusy=$false
function ArrangeMiR {
    if($script:ReflowBusy){return}
    $script:ReflowBusy=$true
    try {
        $fw=[int]$form.ClientSize.Width
        $fh=[int]$form.ClientSize.Height
        if($fw -lt 760 -or $fh -lt 540){return}
        $tabs.SetBounds(20,86,$fw-40,$fh-134)
        $nav.SetBounds(0,0,$tabs.Width,43)
        $pageHost.SetBounds(0,43,$tabs.Width,$tabs.Height-43)
        $navWidth=[int][Math]::Floor(($nav.Width-35)/4)
        for($j=0;$j -lt 4;$j++){
            $key=@('devices','local','features','tools')[$j]
            $script:MiRTabButtons[$key].SetBounds(7+$j*($navWidth+5),4,$navWidth,38)
            TopRoundTab $script:MiRTabButtons[$key]
        }
        foreach($page in @($script:MiRPages.Values)){
            $page.SetBounds(0,0,$pageHost.Width,$pageHost.Height)
            $page.AutoScroll=$false
        }
        $pw=$pageHost.Width-30
        $ph=$pageHost.Height
        # MIS EQUIPOS. Dos columnas en toda la gama de anchos admitidos.
        # La barra de acciones siempre termina dentro del viewport.
        $barY=$ph-49
        $cardH=$barY-19
        $leftW=[int][Math]::Floor(($pw-13)*0.59)
        $rightW=$pw-13-$leftW
        $pList.SetBounds(15,9,$leftW,$cardH)
        $pEditor.SetBounds(28+$leftW,9,$rightW,$cardH)
        $txtSearch.SetBounds(84,63,[Math]::Max(85,$leftW-101),27)
        $list.SetBounds(15,98,$leftW-30,[Math]::Max(100,$cardH-110))
        $lc=$list.ClientSize.Width
        $list.Columns[0].Width=[int][Math]::Floor($lc*0.43)
        $list.Columns[1].Width=[int][Math]::Floor($lc*0.32)
        $list.Columns[2].Width=[Math]::Max(55,$lc-$list.Columns[0].Width-$list.Columns[1].Width-6)
        foreach($field in @($txtName,$txtId,$txtGroup)){$field.Width=$rightW-30}
        # Reducir también el ancho de las leyendas de detalle.
        foreach($control in $pEditor.Controls){if($control -is [System.Windows.Forms.Label]){$control.Width=$rightW-30}}
        $third=[int][Math]::Floor(($rightW-42)/3)
        $btnNew.SetBounds(15,211,$third,31)
        $btnSave.SetBounds(21+$third,211,$third,31)
        $btnDelete.SetBounds(27+2*$third,211,$rightW-42-2*$third,31)
        $btnConnect.SetBounds(15,251,$rightW-30,37)
        $btnTransfer.SetBounds(15,295,$rightW-30,33)
        $pDevBar.SetBounds(15,$barY,$pw,43)
        $actionW=[int][Math]::Floor(($pw-54)/5)
        $actions=@($btnOpen,$btnCopyId,$btnExportA,$btnImportA,$btnSecurityA)
        for($j=0;$j -lt $actions.Count;$j++){
            $actions[$j].SetBounds(8+$j*($actionW+10),4,$actionW,34)
            $actions[$j].Font=Fnt 8.7
        }
        # MI EQUIPO / RECEPTOR. Estado y acciones caben sin barra lateral.
        $pStatus.SetBounds(15,8,$pw,191)
        foreach($control in $pStatus.Controls){if($control -is [System.Windows.Forms.Label]){$control.Width=$pw-36}}
        $lblService.Top=36;$lblExe.Top=60;$lblNet.Top=83;$lblMyId.Top=108
        $statW=[int][Math]::Floor(($pw-50)/4)
        $statButtons=@($btnRefresh,$btnOwnId,$btnCopyOwnId,$btnLocalRust)
        for($j=0;$j -lt 4;$j++){$statButtons[$j].SetBounds(18+$j*($statW+10),151,$statW,31)}
        $pUnatt.SetBounds(15,210,$pw,$ph-218)
        foreach($control in $pUnatt.Controls){if($control -is [System.Windows.Forms.Label]){$control.Width=$pw-36}}
        # Los textos informativos se distribuyen sin superponer botones.
        $unLabels=@($pUnatt.Controls | Where-Object {$_ -is [System.Windows.Forms.Label] -and $_ -ne $lblStartup -and $_ -ne $lblUnattWarn -and $_ -ne $lblUnattTip} | Sort-Object Top)
        if($unLabels.Count -ge 2){$unLabels[0].Top=9;$unLabels[1].SetBounds(18,36,$pw-36,35)}
        $lblStartup.Top=80
        $hostW=[int][Math]::Floor(($pw-54)/4)
        $hostButtons=@($btnUnatt,$btnStartup,$btnPower,$btnDisableHost)
        for($j=0;$j -lt 4;$j++){$hostButtons[$j].SetBounds(18+$j*($hostW+10),111,$hostW,34)}
        if($ph -lt 452){
            $lblUnattWarn.SetBounds(18,152,$pw-36,28)
            $lblUnattTip.Visible=$false
        }else{
            $lblUnattWarn.SetBounds(18,159,$pw-36,35)
            $lblUnattTip.SetBounds(18,199,$pw-36,34)
            $lblUnattTip.Visible=$true
        }
        # SESIONES Y ARCHIVOS. Tarjetas dos arriba y una abajo.
        $half=[int][Math]::Floor(($pw-13)/2)
        $pF1.SetBounds(15,8,$half,184)
        $pF2.SetBounds(28+$half,8,$pw-13-$half,184)
        foreach($panel in @($pF1,$pF2)){
            $labels=@($panel.Controls | Where-Object {$_ -is [System.Windows.Forms.Label]} | Sort-Object Top)
            if($labels.Count -ge 2){$labels[0].SetBounds(15,9,$panel.Width-30,28);$labels[1].SetBounds(15,42,$panel.Width-30,90)}
        }
        $btnOpenF1.SetBounds(15,141,$pF1.Width-30,33)
        $btnOpenF2.SetBounds(15,141,$pF2.Width-30,33)
        $pF3.SetBounds(15,201,$pw,$ph-210)
        $featureLabels=@($pF3.Controls | Where-Object {$_ -is [System.Windows.Forms.Label]} | Sort-Object Top)
        if($featureLabels.Count -ge 4){
            $featureLabels[0].SetBounds(16,9,$pw-32,28)
            $featureLabels[1].SetBounds(16,42,$pw-32,39)
            $featureLabels[2].SetBounds(16,88,$pw-32,39)
            $featureLabels[3].SetBounds(16,133,$pw-32,34)
        }
        $featureBtnW=[int][Math]::Floor(($pw-44)/2)
        if($ph -lt 452){
            $featureLabels[3].Visible=$false
            $btnOpenF3.SetBounds(16,148,$featureBtnW,32)
            $btnShowGuide.SetBounds(26+$featureBtnW,148,$featureBtnW,32)
        }else{
            $featureLabels[3].Visible=$true
            $btnOpenF3.SetBounds(16,181,$featureBtnW,34)
            $btnShowGuide.SetBounds(26+$featureBtnW,181,$featureBtnW,34)
        }
        # DIAGNOSTICO. Sin desplazamiento de ventana; el texto tiene scroll propio.
        $pTools.SetBounds(15,8,$pw,$ph-17)
        foreach($label in $pTools.Controls){if($label -is [System.Windows.Forms.Label]){$label.Width=$pw-34}}
        $reportH=[Math]::Max(120,$pTools.Height-184)
        $txtReport.SetBounds(17,47,$pw-34,$reportH)
        $buttonsY=56+$reportH
        $toolW=[int][Math]::Floor(($pw-49)/4)
        $toolButtons=@($btnDiag,$btnCopyReport,$btnLocate,$btnDataFolder)
        for($j=0;$j -lt 4;$j++){$toolButtons[$j].SetBounds(17+$j*($toolW+5),$buttonsY,$toolW,33)}
        $exportY=$buttonsY+42
        $exportW=[int][Math]::Floor(($pw-39)/2)
        $btnExportB.SetBounds(17,$exportY,$exportW,33)
        $btnImportB.SetBounds(22+$exportW,$exportY,$exportW,33)
        foreach($label in $pTools.Controls){
            if($label -is [System.Windows.Forms.Label] -and $label.Text -like 'Los respaldos*'){
                $label.SetBounds(17,$exportY+42,$pw-34,34)
            }
        }
        # Pie institucional permanente.
        if($null -ne $picEco){$picEco.SetBounds([int][Math]::Max(548,$fw-230),$fh-44,198,36)}
        $script:MiRFooter.SetBounds(24,$fh-36,[Math]::Max(320,$fw-290),22)
        $lblSubtitle.SetBounds(188,42,[Math]::Max(298,$fw-520),24)
        $lblTop.SetBounds([Math]::Max(514,$fw-401),17,[Math]::Min(365,$fw-548),27)
        $chkMinimize.SetBounds([Math]::Max(510,$fw-291),48,270,25)
    }finally{$script:ReflowBusy=$false}
}
$form.Add_Resize({ArrangeMiR})
$screen=[System.Windows.Forms.Screen]::FromControl($form).WorkingArea
$targetW=[Math]::Min(1160,[Math]::Max(820,$screen.Width-60))
$targetH=[Math]::Min(655,[Math]::Max(580,$screen.Height-55))
$form.ClientSize=[System.Drawing.Size]::new([int]$targetW,[int]$targetH)
ArrangeMiR
RefreshList
UpdateStatus
[void][System.Windows.Forms.Application]::Run($form)