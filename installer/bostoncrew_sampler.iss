#define MyAppName "BOSTONCREW SAMPLER"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "BOSTONCREW"
#define MyAppExeName "BOSTONCREW SAMPLER.exe"

[Setup]
AppId={{2D07A2B1-21B6-45D8-B778-0D79731563CE}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\BOSTONCREW SAMPLER
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\deploy
OutputBaseFilename=BOSTONCREW-SAMPLER-windows-setup
SetupIconFile=..\assets\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\{#MyAppExeName}

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "..\deploy\windows\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
