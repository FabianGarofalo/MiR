; MiR V2 — instalador candidato a prueba. NO realiza migraciones del servicio receptor.
; Requiere /DSourceDir=... al invocar ISCC. Preserva licencias en el paquete.
#ifndef SourceDir
  #error "Es obligatorio proporcionar SourceDir"
#endif

#define MyAppName "MiR"
#define MyVersion "2.0.0-preview"
#define MyPublisher "EcoEtika S.A.S."
#define AppExecutable "rustdesk.exe"

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
