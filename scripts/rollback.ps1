# SPDX-License-Identifier: GPL-3.0-or-later
#Requires -Version 5.1
[CmdletBinding()]
param([string]$UserDir = $env:RIME_USER_DIR, [string]$WeaselDir = $env:RIME_WEASEL_DIR, [switch]$SkipDeploy)
. (Join-Path $PSScriptRoot 'windows-common.ps1')
$target = Resolve-RimeDirectory $UserDir
if (-not $SkipDeploy) { $WeaselDir = Assert-DeploymentTarget $target $WeaselDir }
$pointer = Get-SafeChildPath $target 'backups/.rime-bilingual-windows-last-backup'
if (-not (Test-Path -LiteralPath $pointer -PathType Leaf)) { throw 'No Windows backup recorded for this target.' }
$backup = [IO.Path]::GetFullPath([IO.File]::ReadAllText($pointer, $script:Utf8).Trim())
$backupName = [IO.Path]::GetFileName($backup)
if ([IO.Path]::GetDirectoryName($backup) -ine (Join-Path $target 'backups') -or $backupName -notlike 'qingjian-learning-*') {
    throw 'Backup path is outside the permitted directory.'
}
$backup = Get-SafeChildPath $target "backups/$backupName"
$manifestFile = Join-Path $backup 'deployed-files.json'
$manifest = [IO.File]::ReadAllText($manifestFile, $script:Utf8) | ConvertFrom-Json
if ($manifest.Version -ne 1 -or $manifest.Target -ine $target -or $manifest.State -notin @('installing', 'installed')) {
    throw 'Backup manifest has an invalid version, target or state (or was already rolled back).'
}
$files = @($manifest.Files)
if (-not $files.Count -or @($files | Sort-Object -Unique).Count -ne $files.Count) { throw 'Empty or duplicate manifest paths.' }
# Validate the entire manifest and all paths before moving any installed file.
foreach ($relative in $files) {
    foreach ($root in @($target, (Join-Path $backup 'previous'))) {
        $file = Get-SafeChildPath $root $relative
        if (Test-Path -LiteralPath $file -PathType Container) { throw "File conflicts with directory: $file" }
    }
}
$withdrawn = Join-Path $backup ('rolled-back-' + [Guid]::NewGuid().ToString('N'))
foreach ($relative in $files) {
    # Older manifests included an existing aggregate even though installation preserved it.
    if ($relative -eq 'luna_pinyin.tech.dict.yaml' -and
        (Test-Path -LiteralPath (Get-SafeChildPath (Join-Path $backup 'previous') $relative) -PathType Leaf)) { continue }
    $current = Get-SafeChildPath $target $relative
    if (Test-Path -LiteralPath $current -PathType Leaf) {
        $retained = Get-SafeChildPath $withdrawn $relative
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($retained)) | Out-Null
        Move-Item -LiteralPath $current -Destination $retained
    }
    $previous = Get-SafeChildPath (Join-Path $backup 'previous') $relative
    if (Test-Path -LiteralPath $previous -PathType Leaf) { Copy-PayloadFile $previous $current }
}
$manifest.State = 'rolled-back'
Write-Utf8File $manifestFile ($manifest | ConvertTo-Json -Depth 4)
if (-not $SkipDeploy) { Invoke-WeaselDeployment $WeaselDir }
Write-Host "Restored backup: $backup`nWithdrawn files retained in: $withdrawn"
