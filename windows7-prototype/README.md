# OPTIK LENTERA Windows 7 Prototype

A standalone WPF prototype targeting .NET Framework 4.8. This branch is isolated from Android's main branch.

## Safety boundaries
- Offline-only prototype.
- Uses no Google Sheets, Apps Script, Android app data, or real customer records.
- No authentication, network sync, or destructive data operations.
- Prototype UI and navigation only; business workflows are not yet active.

## Build
Open `OptikLentera.Win7.csproj` in Visual Studio with the .NET Framework 4.8 Developer Pack, or run the GitHub Actions workflow `Build OPTIK LENTERA Windows 7 Prototype`.

## Important
A successful CI build proves compilation only. Actual Windows 7 SP1 x64 compatibility must still be verified on a real Windows 7 machine. .NET Framework 4.8 and Windows 7 prerequisites/updates may be required.

Build automation uses the Visual Studio MSBuild locator on a Windows runner.
