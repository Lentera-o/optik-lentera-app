#define MyAppName "OPTIK LENTERA"
#define MyAppVersion "0.2.0"
#define MyAppPublisher "OPTIK LENTERA"
#define MyAppExeName "OPTIK-LENTERA.exe"

[Setup]
AppId={{A9D77D14-2D80-4E2A-9E47-6F0F4F90B2A1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\OPTIK-LENTERA
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\installer-output
OutputBaseFilename=OPTIK-LENTERA-Setup-Windows7
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Buat ikon di Desktop"; GroupDescription: "Pintasan:"; Flags: checkedonce

[Files]
Source: "..\bin\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\OPTIK LENTERA"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\OPTIK LENTERA"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\OPTIK LENTERA"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Jalankan OPTIK LENTERA"; Flags: postinstall nowait skipifsilent
