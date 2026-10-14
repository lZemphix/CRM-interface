param(
    [string]$RuntimeDirectory = ''
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not $RuntimeDirectory) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path $vswhere)) { throw 'Visual Studio vswhere was not found.' }
    $installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -ne 0 -or -not $installation) { throw 'Visual C++ toolchain was not found.' }
    $redist = Join-Path $installation 'VC\Redist\MSVC'
    $version = Get-ChildItem $redist -Directory |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending |
        Select-Object -First 1
    if (-not $version) { throw 'Visual C++ redistributable directory was not found.' }
    $crt = Get-ChildItem (Join-Path $version.FullName 'x64') -Directory |
        Where-Object { $_.Name -match '^Microsoft\.VC\d+\.CRT$' } |
        Select-Object -First 1
    if (-not $crt) { throw 'Release x64 CRT directory was not found.' }
    $RuntimeDirectory = $crt.FullName
}

# Package app-local redistributable DLLs, never developer/debug libraries.
python scripts/release.py windows --runtime-directory $RuntimeDirectory
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
