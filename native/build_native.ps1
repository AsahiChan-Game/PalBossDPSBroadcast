param(
    [string]$UE4SSSource = "$env:LOCALAPPDATA\Temp\codex-re-ue4ss-v3.0.1",
    [string]$FmtSource = "$env:LOCALAPPDATA\Temp\codex-fmt-11.2.0",
    [string]$ZydisSource = "$env:LOCALAPPDATA\Temp\zydis-4.1.1",
    [string]$ZycoreSource = "$env:LOCALAPPDATA\Temp\zycore-c-1.5.2",
    [Parameter(Mandatory = $true)]
    [string]$UE4SSDll,
    [string]$BuildDirectory = "$PSScriptRoot\build-native"
)

$ErrorActionPreference = "Stop"
$expectedCommit = "c2ac246447a8bcd92541070cb474044e7a2bbbe6"

if (-not (Test-Path -LiteralPath $UE4SSDll -PathType Leaf)) {
    throw "UE4SS.dll not found: $UE4SSDll"
}
if (-not (Test-Path -LiteralPath "$UE4SSSource\.git" -PathType Container)) {
    throw "UE4SS source checkout not found: $UE4SSSource"
}

$actualCommit = (& git -C $UE4SSSource rev-parse HEAD).Trim()
if ($actualCommit -ne $expectedCommit) {
    throw "UE4SS source commit mismatch. Expected $expectedCommit, got $actualCommit"
}
if (-not (Test-Path -LiteralPath "$FmtSource\include\fmt\core.h" -PathType Leaf)) {
    throw "fmt 11.2.0 source was not found: $FmtSource"
}
if (-not (Test-Path -LiteralPath "$ZydisSource\include\Zydis\Zydis.h" -PathType Leaf)) {
    throw "Zydis 4.1.1 source was not found: $ZydisSource"
}
if (-not (Test-Path -LiteralPath "$ZycoreSource\include\Zycore\Types.h" -PathType Leaf)) {
    throw "Zycore source was not found: $ZycoreSource"
}

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath).Trim()
if (-not $vsPath) {
    throw "Visual Studio C++ build tools were not found"
}
$toolVersion = (Get-Content -LiteralPath (Join-Path $vsPath "VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt") -Raw).Trim()
$toolDirectory = Join-Path $vsPath "VC\Tools\MSVC\$toolVersion\bin\Hostx64\x64"
$dumpbin = Join-Path $toolDirectory "dumpbin.exe"
$libTool = Join-Path $toolDirectory "lib.exe"
$vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"

New-Item -ItemType Directory -Path $BuildDirectory -Force | Out-Null
$defPath = Join-Path $BuildDirectory "UE4SS.def"
$libPath = Join-Path $BuildDirectory "UE4SS.lib"
$dumpPath = Join-Path $BuildDirectory "UE4SS.exports.txt"

& $dumpbin /nologo /exports $UE4SSDll | Set-Content -LiteralPath $dumpPath -Encoding ASCII
if ($LASTEXITCODE -ne 0) {
    throw "dumpbin failed with exit code $LASTEXITCODE"
}

$exports = [System.Collections.Generic.List[string]]::new()
foreach ($line in Get-Content -LiteralPath $dumpPath) {
    if ($line -match '^\s+\d+\s+[0-9A-Fa-f]+\s+[0-9A-Fa-f]+\s+(\S+)\s*$') {
        $exports.Add($Matches[1])
    }
}
if ($exports.Count -lt 100) {
    throw "Unexpected UE4SS export count: $($exports.Count)"
}

$defLines = [System.Collections.Generic.List[string]]::new()
$defLines.Add("LIBRARY UE4SS")
$defLines.Add("EXPORTS")
foreach ($export in $exports) {
    $defLines.Add("    $export")
}
[System.IO.File]::WriteAllLines($defPath, $defLines, [System.Text.UTF8Encoding]::new($false))

& $libTool /nologo "/def:$defPath" /machine:x64 "/out:$libPath"
if ($LASTEXITCODE -ne 0) {
    throw "lib.exe failed with exit code $LASTEXITCODE"
}

$environmentLines = & cmd.exe /d /c "`"$vcvars`" >nul && set"
foreach ($line in $environmentLines) {
    if ($line -match '^([^=]+)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], "Process")
    }
}

$includeDirectories = @(
    "$PSScriptRoot\include",
    "$UE4SSSource\UE4SS\include",
    "$UE4SSSource\UE4SS\generated_include",
    "$UE4SSSource\deps\first\Unreal\include",
    "$UE4SSSource\deps\first\Unreal\include\Unreal",
    "$UE4SSSource\deps\first\Unreal\include\Unreal\Core",
    "$UE4SSSource\deps\first\Unreal\generated_include",
    "$UE4SSSource\deps\first\LuaMadeSimple\include",
    "$UE4SSSource\deps\first\LuaRaw\include",
    "$UE4SSSource\deps\first\String\include",
    "$UE4SSSource\deps\first\File\include",
    "$UE4SSSource\deps\first\Function\include",
    "$UE4SSSource\deps\first\Helpers\include",
    "$UE4SSSource\deps\first\Constructs\include",
    "$UE4SSSource\deps\first\DynamicOutput\include",
    "$UE4SSSource\deps\first\ASMHelper\include",
    "$FmtSource\include",
    "$ZydisSource\include",
    "$ZycoreSource\include"
)
$includeArguments = @()
foreach ($directory in $includeDirectories) {
    $includeArguments += "/I$directory"
}

$nativeArguments = @(
    "/nologo", "/std:c++latest", "/EHsc", "/MD", "/O2", "/W4", "/utf-8",
    "/DUE_BUILD_SHIPPING=1", "/DUE_GAME=1",
    "/DPLATFORM_WINDOWS=1", "/DPLATFORM_MICROSOFT=1",
    "/DOVERRIDE_PLATFORM_HEADER_NAME=Windows", "/DUBT_COMPILED_PLATFORM=Win64",
    "/D_WIN32_WINNT=0x0A00", "/DWINVER=0x0A00",
    "/DFMT_HEADER_ONLY=1",
    "/D_UNICODE", "/DUNICODE", "/DWIN32_LEAN_AND_MEAN", "/LD",
    "/Fo:$BuildDirectory\BossDPSNativeCollector.obj",
    "$PSScriptRoot\src\BossDPSNativeCollector.cpp"
) + $includeArguments + @(
    "/link", $libPath, "/OUT:$BuildDirectory\main.dll",
    "/IMPLIB:$BuildDirectory\BossDPSNativeCollector.lib"
)
& cl.exe @nativeArguments
if ($LASTEXITCODE -ne 0) {
    throw "Native build failed with exit code $LASTEXITCODE"
}

$testArguments = @(
    "/nologo", "/std:c++latest", "/EHsc", "/MD", "/O2", "/W4",
    "$PSScriptRoot\tests\collector_stress.cpp",
    "/I$PSScriptRoot\include",
    "/Fo:$BuildDirectory\collector_stress.obj",
    "/Fe:$BuildDirectory\collector_stress.exe"
)
& cl.exe @testArguments
if ($LASTEXITCODE -ne 0) {
    throw "Native stress-test build failed with exit code $LASTEXITCODE"
}
& "$BuildDirectory\collector_stress.exe"
if ($LASTEXITCODE -ne 0) {
    throw "Native stress test failed with exit code $LASTEXITCODE"
}

Write-Host "Native collector built: $BuildDirectory\main.dll"
