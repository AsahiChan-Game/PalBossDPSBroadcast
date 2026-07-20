$ErrorActionPreference = "Stop"

$testDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDirectory = Split-Path -Parent $testDirectory
$mainScript = Join-Path $projectDirectory "Scripts\main.lua"
$configScript = Join-Path $projectDirectory "Scripts\config.lua"
$commentaryScript = Join-Path $projectDirectory "Scripts\commentary.lua"

Write-Host "[1/4] Parsing Lua sources"
& npx --yes --package=luaparse luaparse --quiet --file $mainScript
if ($LASTEXITCODE -ne 0) { throw "main.lua parse failed" }
& npx --yes --package=luaparse luaparse --quiet --file $configScript
if ($LASTEXITCODE -ne 0) { throw "config.lua parse failed" }
& npx --yes --package=luaparse luaparse --quiet --file $commentaryScript
if ($LASTEXITCODE -ne 0) { throw "commentary.lua parse failed" }

Write-Host "[2/4] Auditing forbidden crash-path APIs"
$forbidden = "ExecuteWithDelay|SendSystemAnnounce|GetIndividualCharacterParameterByActor|IsBossPal_Database\(|IsTowerBossPal\(|FindAllOf"
$matches = & rg -n $forbidden $mainScript
if ($LASTEXITCODE -eq 0) {
    $matches | Write-Host
    throw "forbidden API found in main.lua"
}

Write-Host "[3/4] Validating strict UTF-8"
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
foreach ($file in @($mainScript, $configScript, $commentaryScript, (Join-Path $testDirectory "test_main.lua"))) {
    [void]$utf8.GetString([System.IO.File]::ReadAllBytes($file))
}

Write-Host "[4/4] Running integration, thread-affinity, lifetime, and stress tests"
Push-Location $testDirectory
try {
    $testOutput = & npx --yes --package=fengari-node-cli fengari test_main.lua 2>&1
    $testExitCode = $LASTEXITCODE
    $testOutput | Write-Host
    if ($testExitCode -ne 0 -or -not ($testOutput -match "integration/thread/lifetime/stress tests passed")) {
        throw "Lua integration test failed or did not reach its completion marker"
    }
}
finally {
    Pop-Location
}

Write-Host "All offline checks passed. No PalServer process or live-server file was accessed."
