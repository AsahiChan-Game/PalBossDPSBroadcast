$ErrorActionPreference = "Stop"

$testDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDirectory = Split-Path -Parent $testDirectory
$mainScript = Join-Path $projectDirectory "Scripts\main.lua"
$configScript = Join-Path $projectDirectory "Scripts\config.lua"

Write-Host "[1/4] Parsing Lua sources"
& npx --yes --package=luaparse luaparse --quiet --file $mainScript
if ($LASTEXITCODE -ne 0) { throw "main.lua parse failed" }
& npx --yes --package=luaparse luaparse --quiet --file $configScript
if ($LASTEXITCODE -ne 0) { throw "config.lua parse failed" }

Write-Host "[2/4] Auditing forbidden crash-path APIs"
$forbidden = "ExecuteWithDelay|SendSystemAnnounce|GetIndividualCharacterParameterByActor|IsBossPal_Database\(|IsTowerBossPal\(|FindAllOf"
$matches = & rg -n $forbidden $mainScript
if ($LASTEXITCODE -eq 0) {
    $matches | Write-Host
    throw "forbidden API found in main.lua"
}

Write-Host "[3/4] Validating strict UTF-8"
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
foreach ($file in @($mainScript, $configScript, (Join-Path $testDirectory "test_main.lua"))) {
    [void]$utf8.GetString([System.IO.File]::ReadAllBytes($file))
}

Write-Host "[4/4] Running integration, thread-affinity, lifetime, and stress tests"
Push-Location $testDirectory
try {
    & npx --yes --package=fengari-node-cli fengari test_main.lua
    if ($LASTEXITCODE -ne 0) { throw "Lua integration test failed" }
}
finally {
    Pop-Location
}

Write-Host "All offline checks passed. No PalServer process or live-server file was accessed."
