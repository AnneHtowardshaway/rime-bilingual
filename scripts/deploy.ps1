# SPDX-License-Identifier: GPL-3.0-or-later
#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$UserDir = $env:RIME_USER_DIR,
    [string]$WeaselDir = $env:RIME_WEASEL_DIR,
    [ValidateSet('large', 'compact')][string]$FontPreset = 'large',
    [switch]$Preview,
    [switch]$SkipDeploy
)
. (Join-Path $PSScriptRoot 'windows-common.ps1')
$target = Resolve-RimeDirectory $UserDir
if (-not $Preview -and -not $SkipDeploy) { $WeaselDir = Assert-DeploymentTarget $target $WeaselDir }
$resources = Get-WanxiangResources
$payload = @(Get-PayloadFiles $resources)
$relativePaths = @($payload | ForEach-Object { $_.Relative } | Sort-Object -Unique)
if ($relativePaths.Count -ne $payload.Count) { throw 'Duplicate payload paths.' }
foreach ($item in $payload) {
    if (-not (Test-Path -LiteralPath $item.Source -PathType Leaf)) { throw "Missing source: $($item.Source)" }
    $destination = Get-SafeChildPath $target $item.Relative
    if (Test-Path -LiteralPath $destination -PathType Container) { throw "File conflicts with a directory: $destination" }
}
Write-Host "Target: $target`nFont: $FontPreset`nFiles to install/replace (existing files will be backed up):"
$relativePaths | ForEach-Object { Write-Host $_ }
if ($Preview) { Write-Host 'Preview complete. No input-method files changed; download cache may have been populated.'; return }

$stamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$backup = Get-SafeChildPath $target "backups/qingjian-learning-$stamp"
[IO.Directory]::CreateDirectory($backup) | Out-Null
$manifest = @{ Version = 1; Target = $target; Files = $relativePaths; FontPreset = $FontPreset; State = 'installing' }
Write-Utf8File (Join-Path $backup 'deployed-files.json') ($manifest | ConvertTo-Json -Depth 4)
foreach ($relative in $relativePaths) {
    $existing = Get-SafeChildPath $target $relative
    if (Test-Path -LiteralPath $existing -PathType Leaf) {
        Copy-PayloadFile $existing (Get-SafeChildPath (Join-Path $backup 'previous') $relative)
    }
}
# Record recovery information before the first overwrite, including partial installations.
Write-Utf8File (Join-Path $target 'backups/.rime-bilingual-windows-last-backup') $backup
foreach ($item in $payload) {
    $destination = Get-SafeChildPath $target $item.Relative
    if ($item.Relative -eq 'luna_pinyin.tech.dict.yaml' -and (Test-Path -LiteralPath $destination -PathType Leaf)) { continue }
    Copy-PayloadFile $item.Source $destination
}
if ($FontPreset -eq 'compact') {
    $file = Join-Path $target 'weasel.custom.yaml'
    $content = [IO.File]::ReadAllText($file, $script:Utf8)
    $content = $content.Replace('style/font_point: 17', 'style/font_point: 15').Replace('style/comment_font_point: 16', 'style/comment_font_point: 12')
    Write-Utf8File $file $content
}
$manifest.State = 'installed'
Write-Utf8File (Join-Path $backup 'deployed-files.json') ($manifest | ConvertTo-Json -Depth 4)
if (-not $SkipDeploy) { Invoke-WeaselDeployment $WeaselDir }
Write-Host "Installed Wanxiang Base $script:WanxiangVersion and bilingual extensions.`nBackup: $backup"
if ($SkipDeploy) { Write-Host 'Native Weasel deployment was skipped. Compile the target before running verify.ps1.' }
