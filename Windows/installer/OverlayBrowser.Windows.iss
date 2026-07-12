#ifndef SourceDir
  #error SourceDir must point to the published application directory.
#endif
#ifndef BootstrapperPath
  #error BootstrapperPath must point to MicrosoftEdgeWebview2Setup.exe.
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif
#ifndef AppVersion
  #error AppVersion must match VersionPrefix from Windows/Directory.Build.props.
#endif

#define AppName "Overlay Browser"
#define AppExeName "OverlayBrowser.Windows.exe"

[Setup]
AppId={{16C17C44-DC56-4D80-8602-BB856D1F409F}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=SafeScreen
DefaultDirName={localappdata}\Programs\OverlayBrowser
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=OverlayBrowser-Windows-x64-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
CloseApplications=force
RestartApplications=no
UninstallDisplayIcon={app}\{#AppExeName}
VersionInfoVersion={#AppVersion}
VersionInfoProductName={#AppName}

[Files]
Source: "{#SourceDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BootstrapperPath}"; DestDir: "{tmp}"; DestName: "MicrosoftEdgeWebview2Setup.exe"; Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"

[Run]
Filename: "{tmp}\MicrosoftEdgeWebview2Setup.exe"; Parameters: "/silent /install"; StatusMsg: "Installing Microsoft Edge WebView2 Runtime..."; Flags: runhidden waituntilterminated
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
