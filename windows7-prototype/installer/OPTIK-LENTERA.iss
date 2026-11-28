#define MyAppName "OPTIK LENTERA"
#define MyAppVersion "0.2.1"
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
Source: "NDP48-x86-x64-AllOS-ENU.exe"; Flags: dontcopy

[Icons]
Name: "{group}\OPTIK LENTERA"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\OPTIK LENTERA"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\OPTIK LENTERA"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Jalankan OPTIK LENTERA"; Flags: postinstall nowait skipifsilent

[Code]
function IsDotNet48Installed: Boolean;
var
  ReleaseValue: Cardinal;
begin
  Result := False;
  if IsWin64 then
  begin
    if RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Release', ReleaseValue) then
      Result := ReleaseValue >= 528040;
  end;
  if not Result then
  begin
    if RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Release', ReleaseValue) then
      Result := ReleaseValue >= 528040;
  end;
end;

function InitializeSetup: Boolean;
var
  ResultCode: Integer;
begin
  Result := True;
  if not IsDotNet48Installed then
  begin
    try
      ExtractTemporaryFile('NDP48-x86-x64-AllOS-ENU.exe');
    except
      MsgBox('Komponen .NET Framework 4.8 tidak dapat disiapkan. Instalasi OPTIK LENTERA dibatalkan.', mbError, MB_OK);
      Result := False;
      exit;
    end;

    if not Exec(ExpandConstant('{tmp}\NDP48-x86-x64-AllOS-ENU.exe'),
      '/passive /norestart', '', SW_SHOW, ewWaitUntilTerminated, ResultCode) then
    begin
      MsgBox('Penginstal .NET Framework 4.8 tidak dapat dijalankan. Instalasi OPTIK LENTERA dibatalkan.', mbError, MB_OK);
      Result := False;
      exit;
    end;

    if not IsDotNet48Installed then
    begin
      if ResultCode = 3010 then
        MsgBox('Windows perlu dimulai ulang untuk menyelesaikan pemasangan .NET Framework 4.8. Restart komputer, lalu jalankan installer OPTIK LENTERA sekali lagi.', mbInformation, MB_OK)
      else
        MsgBox('Pemasangan .NET Framework 4.8 belum berhasil (kode ' + IntToStr(ResultCode) + '). Pastikan Windows 7 SP1 sudah terpasang dan diperbarui, lalu coba lagi.', mbError, MB_OK);
      Result := False;
      exit;
    end;
  end;
end;
