param(
    [string]$Version = "3.4.1",
    [string]$OutputDirectory = "$PSScriptRoot\..\dist"
)

$ErrorActionPreference = "Stop"
$projectDirectory = Split-Path -Parent $PSScriptRoot
$nativeDll = Join-Path $PSScriptRoot "build-native\main.dll"
if (-not (Test-Path -LiteralPath $nativeDll -PathType Leaf)) {
    throw "Native DLL is missing. Run native\build_native.ps1 first."
}

$stagingRoot = Join-Path $OutputDirectory "PalBossDPSBroadcast-v$Version"
$luaMod = Join-Path $stagingRoot "BossDPSBroadcast"
$nativeMod = Join-Path $stagingRoot "BossDPSNativeCollector"

New-Item -ItemType Directory -Path (Join-Path $luaMod "Scripts") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $nativeMod "dlls") -Force | Out-Null

Copy-Item -LiteralPath (Join-Path $projectDirectory "enabled.txt") -Destination $luaMod -Force
Copy-Item -LiteralPath (Join-Path $projectDirectory "Scripts\main.lua") -Destination (Join-Path $luaMod "Scripts") -Force
Copy-Item -LiteralPath (Join-Path $projectDirectory "Scripts\config.lua") -Destination (Join-Path $luaMod "Scripts") -Force
Copy-Item -LiteralPath (Join-Path $projectDirectory "Scripts\commentary.lua") -Destination (Join-Path $luaMod "Scripts") -Force
Copy-Item -LiteralPath (Join-Path $projectDirectory "Scripts\localization.lua") -Destination (Join-Path $luaMod "Scripts") -Force
Copy-Item -LiteralPath (Join-Path $projectDirectory "Scripts\locales") -Destination (Join-Path $luaMod "Scripts\locales") -Recurse -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "enabled.txt") -Destination $nativeMod -Force
Copy-Item -LiteralPath $nativeDll -Destination (Join-Path $nativeMod "dlls\main.dll") -Force

$zipPath = Join-Path $OutputDirectory "PalBossDPSBroadcast-v$Version-win64.zip"
Compress-Archive -LiteralPath $luaMod, $nativeMod -DestinationPath $zipPath -CompressionLevel Optimal -Force

$dllHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $nativeDll).Hash
Write-Host "Release package ready: $zipPath"
Write-Host "main.dll SHA256: $dllHash"
