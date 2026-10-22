# SPDX-License-Identifier: GPL-3.0-or-later
#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Engine)
. (Join-Path $PSScriptRoot 'windows-common.ps1')

function Assert-Test([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "TEST FAILED: $Message" }
}
function Assert-Rejected([scriptblock]$Action, [string]$Message) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    Assert-Test $rejected $Message
}
# Parse every script with the current PowerShell engine (CI tests both 5.1 and 7).
Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' | ForEach-Object {
    $tokens = $null; $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    Assert-Test ($errors.Count -eq 0) "PowerShell parser: $($_.Name) $errors"
    Assert-Test (-not ([IO.File]::ReadAllBytes($_.FullName) | Where-Object { $_ -gt 127 })) 'PowerShell 5.1 scripts must remain ASCII'
}
$cache = Join-Path $script:ProjectRoot '.cache/windows-test'
[IO.Directory]::CreateDirectory($cache) | Out-Null
$unicode = ([string][char]0x4E2D) + ([string][char]0x6587)
$sandbox = Join-Path $cache ("isolated $unicode-" + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($sandbox) | Out-Null
$original = "# existing configuration`npatch: {}`n"
Write-Utf8File (Join-Path $sandbox 'default.custom.yaml') $original
Write-Utf8File (Join-Path $sandbox 'rime.lua') '-- existing private extension'
$privatePhrase = -join ([char[]](0x661F, 0x6F9C, 0x5DE5, 0x4F5C, 0x5BA4))
$privatePhrase += "`txinglangongzuoshi`t1000`n"
Write-Utf8File (Join-Path $sandbox 'custom_phrase.txt') $privatePhrase
$aggregate = [IO.File]::ReadAllText((Join-Path $script:ProjectRoot 'rime/luna_pinyin.tech.dict.yaml'), $script:Utf8)
Write-Utf8File (Join-Path $sandbox 'luna_pinyin.tech.dict.yaml') ($aggregate + "`n# private imports retained`n")
Write-Utf8File (Join-Path $sandbox 'private.userdb/sentinel') 'private learning data'
Write-Utf8File (Join-Path $sandbox 'squirrel.custom.yaml') 'existing macOS configuration'
$marker = Join-Path $sandbox 'backups/.rime-bilingual-windows-last-backup'

Assert-Rejected { Get-SafeChildPath $sandbox '../escape' } 'Reject parent traversal'
Assert-Rejected { Get-SafeChildPath $sandbox 'dir\..\escape' } 'Reject Windows traversal'
Assert-Rejected { Get-SafeChildPath $sandbox 'file:stream' } 'Reject alternate data streams'
Assert-Test ((Resolve-RimeDirectory ($sandbox + [IO.Path]::DirectorySeparatorChar)) -eq $sandbox) 'Normalize a trailing separator'
Assert-Rejected { Get-SafeChildPath ([IO.Path]::GetPathRoot($sandbox)) 'file' } 'Reject a filesystem root'
if ($env:OS -eq 'Windows_NT') {
    Assert-Rejected { Get-SafeChildPath $sandbox 'C:\outside' } 'Reject rooted Windows paths'
    Assert-Rejected { Assert-DeploymentTarget $sandbox '' } 'Do not deploy another registered directory'
    $encoding = Get-NativePathEncoding
    $representable = $true
    try { $encoding.GetBytes($sandbox) | Out-Null } catch { $representable = $false }
    if ($representable) { Assert-NativeRimeDirectory $sandbox }
    else { Assert-Rejected { Assert-NativeRimeDirectory $sandbox } 'Reject unsupported native paths before overwriting settings' }
}
& (Join-Path $PSScriptRoot 'deploy.ps1') -UserDir $sandbox -Preview
Assert-Test (-not (Test-Path -LiteralPath $marker)) 'Preview must not create a backup or overwrite settings'
Assert-Test ([IO.File]::ReadAllText((Join-Path $sandbox 'default.custom.yaml')) -eq $original) 'Preview preserves configuration'
& (Join-Path $PSScriptRoot 'deploy.ps1') -UserDir $sandbox -SkipDeploy -FontPreset compact
Assert-Test (Test-Path -LiteralPath $marker -PathType Leaf) 'Backup pointer exists'
$theme = [IO.File]::ReadAllText((Join-Path $sandbox 'weasel.custom.yaml'), $script:Utf8)
Assert-Test ($theme.Contains('style/font_point: 15') -and $theme.Contains('style/comment_font_point: 12')) 'Compact Windows font preset'
Assert-Test ([IO.File]::ReadAllText((Join-Path $sandbox 'squirrel.custom.yaml')) -eq 'existing macOS configuration') 'Do not install or overwrite the macOS theme'
Assert-Test ([IO.File]::ReadAllText((Join-Path $sandbox 'rime.lua')) -eq '-- existing private extension') 'Preserve rime.lua'
Assert-Test ([IO.File]::ReadAllText((Join-Path $sandbox 'luna_pinyin.tech.dict.yaml')).Contains('# private imports retained')) 'Preserve aggregate dictionary'
Add-Content -LiteralPath (Join-Path $sandbox 'luna_pinyin.tech.dict.yaml') -Value '# private import added after installation' -Encoding UTF8

# Reject a corrupt manifest before restoring any otherwise valid path.
$backup = [IO.File]::ReadAllText($marker, $script:Utf8)
$manifestFile = Join-Path $backup 'deployed-files.json'
$validManifest = [IO.File]::ReadAllText($manifestFile, $script:Utf8)
$manifest = $validManifest | ConvertFrom-Json
# Exercise an older backup that listed the untouched private aggregate.
$manifest.Files += 'luna_pinyin.tech.dict.yaml'
Write-Utf8File (Join-Path $backup 'previous/luna_pinyin.tech.dict.yaml') $aggregate
$validManifest = $manifest | ConvertTo-Json -Depth 4
$manifest.Files += '../escape'
Write-Utf8File $manifestFile ($manifest | ConvertTo-Json -Depth 4)
$beforeHash = (Get-FileHash -LiteralPath (Join-Path $sandbox 'default.custom.yaml')).Hash
Assert-Rejected { & (Join-Path $PSScriptRoot 'rollback.ps1') -UserDir $sandbox -SkipDeploy } 'Reject corrupt rollback manifest'
Assert-Test ((Get-FileHash -LiteralPath (Join-Path $sandbox 'default.custom.yaml')).Hash -eq $beforeHash) 'No partial rollback on invalid manifest'
Write-Utf8File $manifestFile $validManifest

if ($Engine) {
    Assert-Test ($env:OS -eq 'Windows_NT') 'Windows engine test requires Windows'
    $installer = Join-Path $cache 'weasel-0.17.4-installer.exe'
    Get-CheckedDownload 'https://github.com/rime/weasel/releases/download/0.17.4/weasel-0.17.4.0-installer.exe' `
        $installer 'cf509534a8f5f8af9c98ed7cbb8f135439f145a8cbe7e50ede42bb5b5ab45c29'
    $weasel = Join-Path $cache 'weasel-0.17.4'
    if (-not (Test-Path -LiteralPath (Join-Path $weasel 'rime.dll'))) {
        # NSIS has duplicate x64/x86 filenames. Keep the first (x64), never overwrite with x86.
        & 7z x '-aos' "-o$weasel" $installer | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'Cannot extract official Weasel installer.' }
    }
    $dll = [IO.File]::ReadAllBytes((Join-Path $weasel 'rime.dll'))
    $peOffset = [BitConverter]::ToInt32($dll, 0x3c)
    Assert-Test ([BitConverter]::ToUInt16($dll, $peOffset + 4) -eq 0x8664) 'Engine fixture must be x64'
    $header = Join-Path $cache 'rime_api.h'
    Get-CheckedDownload 'https://raw.githubusercontent.com/rime/librime/1.16.0/src/rime_api.h' `
        $header '6eb5629162c44761e7b878f1b122f464de5c8685bd3cd5ac1e8519badc6d6424'
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    $visualStudio = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    Assert-Test ([bool]$visualStudio) 'Visual C++ build tools must be installed'
    $vcvars = Join-Path $visualStudio 'VC/Auxiliary/Build/vcvars64.bat'
    $binary = Join-Path $cache 'rime-engine.exe'
    $source = Join-Path $script:ProjectRoot 'tests/rime_engine.cpp'
    $object = Join-Path $cache 'rime-engine.obj'
    $build = Join-Path $cache 'build-engine.cmd'
    Write-Utf8File $build "@echo off`r`ncall `"$vcvars`" >nul`r`nif errorlevel 1 exit /b 1`r`ncl /nologo /std:c++17 /EHsc /utf-8 /I`"$cache`" /Fo`"$object`" `"$source`" /Fe`"$binary`"`r`n"
    & cmd.exe /d /c $build
    if ($LASTEXITCODE -ne 0) { throw 'Windows engine harness compilation failed.' }
    $previousWeasel = $env:RIME_TEST_WEASEL_DIR
    # PowerShell file operations above exercise Chinese paths. The stock Lua module
    # requires a path representable by the process ANSI code page (1252 on CI).
    $engineDirectory = Join-Path $cache ("engine caf" + [char]0xE9 + '-' + [Guid]::NewGuid().ToString('N'))
    Assert-NativeRimeDirectory $engineDirectory
    Move-Item -LiteralPath $sandbox -Destination $engineDirectory
    try {
        $env:RIME_TEST_WEASEL_DIR = $weasel
        foreach ($schema in @('luna_pinyin_simp', 'wanxiang')) {
            & $binary $engineDirectory $schema
            if ($LASTEXITCODE -ne 0) { throw "Real Windows engine test failed: $schema" }
            & $binary $engineDirectory $schema --check-learning
            if ($LASTEXITCODE -ne 0) { throw "User dictionary persistence test failed: $schema" }
        }
        & (Join-Path $PSScriptRoot 'verify.ps1') -UserDir $engineDirectory
    } finally {
        $env:RIME_TEST_WEASEL_DIR = $previousWeasel
        Move-Item -LiteralPath $engineDirectory -Destination $sandbox
    }
}
& (Join-Path $PSScriptRoot 'rollback.ps1') -UserDir $sandbox -SkipDeploy
Assert-Test ([IO.File]::ReadAllText((Join-Path $sandbox 'default.custom.yaml')) -eq $original) 'Restore original settings'
Assert-Test ([IO.File]::ReadAllText((Join-Path $sandbox 'private.userdb/sentinel')) -eq 'private learning data') 'Preserve user learning data'
Assert-Test ([IO.File]::ReadAllText((Join-Path $sandbox 'custom_phrase.txt'), $script:Utf8) -eq $privatePhrase) 'Preserve private phrases on installation and rollback'
Assert-Test ([IO.File]::ReadAllText((Join-Path $sandbox 'luna_pinyin.tech.dict.yaml'), $script:Utf8).Contains('# private import added after installation')) 'Rollback preserves private imports added after installation'
Assert-Test (-not (Test-Path -LiteralPath (Join-Path $sandbox 'lua/internet_english_filter.lua'))) 'Remove newly installed files on rollback'
Assert-Rejected { & (Join-Path $PSScriptRoot 'rollback.ps1') -UserDir $sandbox -SkipDeploy } 'Reject repeated rollback'
Write-Host "Windows installer/rollback tests passed. PowerShell $($PSVersionTable.PSVersion). Sandbox: $sandbox"
