# SPDX-License-Identifier: GPL-3.0-or-later
#Requires -Version 5.1
[CmdletBinding()]
param([string]$UserDir = $env:RIME_USER_DIR)
. (Join-Path $PSScriptRoot 'windows-common.ps1')
$target = Resolve-RimeDirectory $UserDir
foreach ($relative in @('weasel.custom.yaml', 'default.custom.yaml', 'wanxiang.custom.yaml', 'bilingual_algebra.yaml',
    'bilingual_english.dict.yaml', 'lua/bilingual_english_format.lua', 'lua/internet_english_filter.lua', 'lua/qingjian_gloss_filter.lua',
    'data/internet-english.tsv', 'data/programming-english.tsv', 'data/qingjian-glossary-en.tsv', 'data/technical-glossary-en.tsv',
    'build/default.yaml', 'build/wanxiang.schema.yaml', 'build/bilingual_english.table.bin', 'build/weasel.yaml')) {
    if (-not (Test-Path -LiteralPath (Join-Path $target $relative) -PathType Leaf)) { throw "Missing installed/built file: $relative" }
}
$installedModelHash = (Get-FileHash -LiteralPath (Join-Path $target 'wanxiang-lts-zh-hans.gram') -Algorithm SHA256).Hash
$acceptedModelHashes = @($script:ModelHash, '9eedac1d836f3fdafb61b162035c8937253aedc106be40b2b957d9ab64e9ed89', '8f1b2d3ed2b2755fdd445f6ab103eff613052080b62a0c049f4b166043a16ac4')
if ($installedModelHash -notin $acceptedModelHashes) { throw 'Installed model checksum is not a verified version.' }
foreach ($schema in @('wanxiang')) {
    $content = [IO.File]::ReadAllText((Join-Path $target "build/$schema.schema.yaml"), $script:Utf8)
    $gloss = $content.IndexOf('lua_filter@*qingjian_gloss_filter')
    $english = $content.IndexOf('lua_filter@*internet_english_filter')
    $unique = $content.IndexOf('- uniquifier')
    if ($gloss -lt 0 -or $english -le $gloss -or $unique -le $english) { throw "Invalid bilingual filter order: $schema" }
    if ($content -notmatch 'page_size:\s*6') { throw "Invalid page size: $schema" }
    foreach ($value in @('affix_segmentor@tech_english', 'table_translator@tech_english_vv', 'dictionary: bilingual_english', 'lua_filter@*bilingual_english_format')) {
        if (-not $content.Contains($value)) { throw "Missing English entry: $value" }
    }
}
$defaults = [IO.File]::ReadAllText((Join-Path $target 'default.custom.yaml'), $script:Utf8)
if ([regex]::Matches($defaults, '- schema:').Count -ne 1 -or $defaults -notmatch '- schema: wanxiang') {
    throw 'The scheme list must contain only Wanxiang.'
}
$compiledDefaults = [IO.File]::ReadAllText((Join-Path $target 'build/default.yaml'), $script:Utf8)
foreach ($option in @('internet_english_disabled', 'bilingual_gloss_disabled', 'bilingual_compact')) {
    if (-not $compiledDefaults.Contains('- ' + $option)) { throw "Missing saved option: $option" }
}
$theme = [IO.File]::ReadAllText((Join-Path $target 'build/weasel.yaml'), $script:Utf8)
foreach ($value in @('bilingual_light', 'bilingual_dark', 'Microsoft YaHei')) {
    if (-not $theme.Contains($value)) { throw "Missing Windows theme setting: $value" }
}
Write-Host 'Static Windows verification passed: compiled configuration, filter order and model checksum. Candidate behavior needs the engine test.'
