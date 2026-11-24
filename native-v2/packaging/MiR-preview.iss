; MiR V2 — instalador candidato a prueba. NO realiza migraciones del servicio receptor.
; Requiere /DSourceDir=... al invocar ISCC. Preserva licencias en el paquete.
#ifndef SourceDir
  #error "Es obligatorio proporcionar SourceDir"
#endif

#define MyAppName "MiR"
#define MyVersion "2.7.0-preview"
#define MyPublisher "EcoEtika S.A.S."
#define AppExecutable "MiR.exe"

[Setup]
AppId={{971D5EA3-0B64-408D-9D10-566C42E51265}
AppName={#MyAppName}
AppVersion={#MyVersion}
AppVerName={#MyAppName} {#MyVersion}
AppPublisher={#MyPublisher}
AppPublisherURL=https://www.ecoetika.com/
DefaultDirName={autopf}\MiR
DefaultGroupName=MiR
OutputDir={#SourceDir}\..
OutputBaseFilename=MiR_V2_Instalador_PREVIEW_SIN_FIRMA
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile={#SourceDir}\MiR.ico
UninstallDisplayIcon={app}\{#AppExecutable}
Uninstallable=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
LicenseFile={#SourceDir}\LICENCE
ChangesAssociations=no

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\MiR"; Filename: "{app}\{#AppExecutable}"; IconFilename: "{app}\MiR.ico"
Name: "{autodesktop}\MiR"; Filename: "{app}\{#AppExecutable}"; IconFilename: "{app}\MiR.ico"; Tasks: desktopicon

[Tasks]
Name: desktopicon; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Opciones adicionales:"; Flags: unchecked

[Run]
Filename: "{app}\{#AppExecutable}"; Description: "Iniciar MiR"; Flags: nowait postinstall skipifsilent

[Code]
// Esta entrega es exclusivamente el cliente MiR.
// Su ejecutable Flutter NO está validado para reemplazar ni registrar un
// servicio Windows. La gestión del receptor tendrá otro instalador nativo
// después de las pruebas SCM, acceso desatendido y recuperación.

// Aviso explícito: el instalador no sustituye un receptor previo. Sin
// avisarlo, MiR podría abrir su portada nueva y seguir mostrando la ventana
// receptora azul de otra instalación.
procedure CurStepChanged(CurStep: TSetupStep);
var
  PathActual: String;
  ExistePrevio: Boolean;
begin
  if (CurStep <> ssPostInstall) or WizardSilent then
    Exit;
  ExistePrevio := RegKeyExists(HKLM, 'SYSTEM\CurrentControlSet\Services\RustDesk');
  if RegQueryStringValue(HKLM, 'SYSTEM\CurrentControlSet\Services\MiR',
       'ImagePath', PathActual) then
    if Pos(Lowercase(ExpandConstant('{app}')), Lowercase(PathActual)) = 0 then
      ExistePrevio := True;
  if ExistePrevio then
    MsgBox('Existe otro servicio receptor instalado. MiR no lo reemplazó. ' +
           'Una solicitud puede seguir abriendo la interfaz antigua. ' +
           'Abrí MiR > Mi equipo / Receptor > Proceso receptor real ' +
           'para identificar qué versión atiende la conexión. ' +
           'También podés ejecutar MiR_Corregir_Receptor.cmd sin ' +
           'modificar servicios.', mbInformation, MB_OK);
end;

// Protección: si el servicio receptor usa archivos bajo MiR, impedimos una
// desinstalación que dejaría ese servicio apuntando a un ejecutable eliminado.
function ReceptorDependeDeMiR(const NombreServicio: String): Boolean;
var
  Ruta: String;
begin
  Result := False;
  if RegQueryStringValue(HKLM,
       'SYSTEM\CurrentControlSet\Services\' + NombreServicio,
       'ImagePath', Ruta) then
    Result := Pos(Lowercase(ExpandConstant('{app}')), Lowercase(Ruta)) > 0;
end;

function InitializeUninstall(): Boolean;
begin
  Result := not (
    ReceptorDependeDeMiR('RustDesk') or
    ReceptorDependeDeMiR('MiR') or
    ReceptorDependeDeMiR('MiRHost')
  );
  if not Result then
    MsgBox('El receptor remoto utiliza archivos de MiR. Para evitar perder acceso, primero desactivá el receptor de forma local y verificá una vía alternativa de conexión. La desinstalación fue cancelada.', mbError, MB_OK);
end;
