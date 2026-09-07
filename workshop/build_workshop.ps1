$ErrorActionPreference = "Stop"

$workshopDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDirectory = Split-Path -Parent $workshopDirectory
$contentDirectory = Join-Path $workshopDirectory "content"
$contentScripts = Join-Path $contentDirectory "Scripts"
$contentLocales = Join-Path $contentScripts "locales"
$distDirectory = Join-Path $workshopDirectory "dist"

New-Item -ItemType Directory -Path $contentScripts -Force | Out-Null
New-Item -ItemType Directory -Path $contentLocales -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectDirectory "Scripts\main.lua") -Destination (Join-Path $contentScripts "main.lua") -Force
Copy-Item -LiteralPath (Join-Path $projectDirectory "Scripts\commentary.lua") -Destination (Join-Path $contentScripts "commentary.lua") -Force
Copy-Item -LiteralPath (Join-Path $projectDirectory "Scripts\localization.lua") -Destination (Join-Path $contentScripts "localization.lua") -Force
Copy-Item -Path (Join-Path $projectDirectory "Scripts\locales\*.lua") -Destination $contentLocales -Force

$infoPath = Join-Path $contentDirectory "Info.json"
$info = Get-Content -LiteralPath $infoPath -Raw -Encoding UTF8 | ConvertFrom-Json
$expectedWorkshopTitle = -join @([char]0x4E0D, [char]0x8981, [char]0x67E5, [char]0x6211, "D", "P", "S")
if ($info.ModName -ne $expectedWorkshopTitle) { throw "Unexpected Workshop ModName" }
if ($info.PackageName -ne "PalBossDPSBroadcastSP") { throw "Unexpected Workshop PackageName" }
if ($info.Version -ne "1.2.1") { throw "Unexpected Workshop version" }
if ($info.Dependencies -notcontains "UE4SSExperimentalPW") { throw "UE4SS dependency missing" }
if ($info.InstallRule.Count -ne 1 -or $info.InstallRule[0].Type -ne "Lua") { throw "Lua InstallRule missing" }

$configPath = Join-Path $contentScripts "config.lua"
$configText = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
foreach ($requiredSetting in @(
    "config.LocalOnlyMessages = true",
    "config.EnableFunComments = true",
    "config.EnablePalDamageBreakdown = true",
    'config.PalDamageBreakdownScope = "personal"'
)) {
    if (-not $configText.Contains($requiredSetting)) { throw "Workshop config missing: $requiredSetting" }
}

$thumbnailPath = Join-Path $contentDirectory "thumbnail.png"
if (-not (Test-Path -LiteralPath $thumbnailPath)) { throw "Workshop thumbnail.png missing" }
if ((Get-Item -LiteralPath $thumbnailPath).Length -gt 1048576) { throw "Workshop thumbnail exceeds 1 MiB" }

& npx --yes --package=luaparse luaparse --quiet --file (Join-Path $contentScripts "main.lua")
if ($LASTEXITCODE -ne 0) { throw "Workshop main.lua parse failed" }
& npx --yes --package=luaparse luaparse --quiet --file $configPath
if ($LASTEXITCODE -ne 0) { throw "Workshop config.lua parse failed" }
& npx --yes --package=luaparse luaparse --quiet --file (Join-Path $contentScripts "commentary.lua")
if ($LASTEXITCODE -ne 0) { throw "Workshop commentary.lua parse failed" }
& npx --yes --package=luaparse luaparse --quiet --file (Join-Path $contentScripts "localization.lua")
if ($LASTEXITCODE -ne 0) { throw "Workshop localization.lua parse failed" }
foreach ($localePath in Get-ChildItem -LiteralPath $contentLocales -Filter "*.lua" -File) {
    & npx --yes --package=luaparse luaparse --quiet --file $localePath.FullName
    if ($LASTEXITCODE -ne 0) { throw "Workshop locale parse failed: $($localePath.Name)" }
}

New-Item -ItemType Directory -Path $distDirectory -Force | Out-Null
$zipPath = Join-Path $distDirectory "PalBossDPSBroadcastSP-Workshop-v1.2.1.zip"
Compress-Archive -Path (Join-Path $contentDirectory "*") -DestinationPath $zipPath -CompressionLevel Optimal -Force

Write-Host "Workshop package ready: $zipPath"
