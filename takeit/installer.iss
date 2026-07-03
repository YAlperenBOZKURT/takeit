; Passed in by CI via `ISCC.exe /DMyAppVersion=x.y.z installer.iss` (see
; release.yml) so the installer's DisplayVersion — what Windows shows in
; "Apps & Features" / Add-Remove Programs — always matches the release tag
; instead of being frozen at whatever version was hardcoded here.
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

[Setup]
AppName=TakeIt
AppVersion={#MyAppVersion}
AppPublisher=TakeIt
DefaultDirName={autopf}\TakeIt
DefaultGroupName=TakeIt
UninstallDisplayIcon={app}\takeit.exe
OutputDir=build\installer
OutputBaseFilename=TakeIt_Setup
Compression=lzma2
SolidCompression=yes
SetupIconFile=windows\runner\resources\app_icon.ico
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern

[Files]
Source: "build\windows\x64\runner\Release\takeit.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\TakeIt"; Filename: "{app}\takeit.exe"
Name: "{autodesktop}\TakeIt"; Filename: "{app}\takeit.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\takeit.exe"; Description: "Launch TakeIt"; Flags: nowait postinstall skipifsilent
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""TakeIt TCP"" dir=in action=allow protocol=tcp localport=53317 program=""{app}\takeit.exe"""; Flags: runhidden
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""TakeIt UDP"" dir=in action=allow protocol=udp localport=53317 program=""{app}\takeit.exe"""; Flags: runhidden

[UninstallRun]
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""TakeIt TCP"""; Flags: runhidden; RunOnceId: "DelTCPRule"
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""TakeIt UDP"""; Flags: runhidden; RunOnceId: "DelUDPRule"
