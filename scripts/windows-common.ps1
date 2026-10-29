# SPDX-License-Identifier: GPL-3.0-or-later
# Keep PowerShell sources ASCII for Windows PowerShell 5.1 (no BOM required).
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$script:ProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:Utf8 = New-Object Text.UTF8Encoding($false)
$script:WanxiangVersion = 'v17.10.3'
$script:BaseHash = 'b01a9d62a0717c15b4669ea237226f13028ebe017bd2ed728cf92a2c0151bf1a'
$script:ModelHash = 'e34500ab44626dc039a0641792ecba98ab63307646eb3d29186be56608ffe094'
$script:ModelAssetId = '676604065'
$script:UpstreamFiles = @(
    'default.yaml', 'wanxiang.schema.yaml', 'wanxiang.dict.yaml',
    'wanxiang_algebra.yaml', 'wanxiang_symbols.yaml',
    'wanxiang_mixedcode.schema.yaml', 'wanxiang_mixedcode.dict.yaml',
    'wanxiang_reverse.schema.yaml', 'wanxiang_reverse.dict.yaml',
    'wanxiang_english.schema.yaml', 'wanxiang_english.dict.yaml', 'version.txt'
)

function Write-Utf8File([string]$File, [string]$Text) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($File)) | Out-Null
    [IO.File]::WriteAllText($File, $Text, $script:Utf8)
}

function Get-RegisteredRimeDirectory {
    if ($env:OS -ne 'Windows_NT') { throw 'Specify -UserDir outside Windows.' }
    $setting = Get-ItemProperty -LiteralPath 'HKCU:\Software\Rime\Weasel' -ErrorAction SilentlyContinue
    if ($null -ne $setting -and $setting.PSObject.Properties['RimeUserDir'] -and $setting.RimeUserDir) {
        return [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($setting.RimeUserDir))
    }
    return [IO.Path]::GetFullPath((Join-Path $env:APPDATA 'Rime'))
}

function Resolve-RimeDirectory([string]$UserDir) {
    if (-not $UserDir) { $resolved = Get-RegisteredRimeDirectory }
    else { $resolved = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($UserDir)) }
    $resolved = $resolved.TrimEnd('\', '/')
    if ($resolved -eq [IO.Path]::GetPathRoot($resolved).TrimEnd('\', '/')) {
        throw 'Use a dedicated Rime user directory, not a filesystem root.'
    }
    return $resolved
}

function Resolve-WeaselDirectory([string]$WeaselDir) {
    if ($WeaselDir) {
        $directory = [IO.Path]::GetFullPath($WeaselDir)
        if (-not (Test-Path -LiteralPath (Join-Path $directory 'WeaselDeployer.exe') -PathType Leaf)) {
            throw "WeaselDeployer.exe not found in: $directory"
        }
        return $directory
    }
    foreach ($key in @('HKLM:\SOFTWARE\Rime\Weasel',
                      'HKLM:\SOFTWARE\WOW6432Node\Rime\Weasel',
                      'HKCU:\SOFTWARE\Rime\Weasel')) {
        $setting = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if ($null -ne $setting -and $setting.PSObject.Properties['InstallDir'] -and $setting.InstallDir) {
            $directory = [IO.Path]::GetFullPath($setting.InstallDir)
            if (Test-Path -LiteralPath (Join-Path $directory 'WeaselDeployer.exe') -PathType Leaf) { return $directory }
        }
    }
    throw 'Install Weasel first, or specify -WeaselDir with its installation directory.'
}

function Get-NativePathEncoding {
    if ($env:OS -ne 'Windows_NT') { throw 'Windows native code page detection requires Windows.' }
    if (-not ('RimeBilingual.NativeCodePage' -as [type])) {
        Add-Type -TypeDefinition 'namespace RimeBilingual { public static class NativeCodePage { [System.Runtime.InteropServices.DllImport("kernel32.dll")] public static extern uint GetACP(); } }'
    }
    if ('System.Text.CodePagesEncodingProvider' -as [type]) {
        [Text.Encoding]::RegisterProvider([Text.CodePagesEncodingProvider]::Instance)
    }
    $codePage = [int]([RimeBilingual.NativeCodePage]::GetACP())
    return [Text.Encoding]::GetEncoding($codePage,
        [Text.EncoderFallback]::ExceptionFallback, [Text.DecoderFallback]::ExceptionFallback)
}

function Assert-NativeRimeDirectory([string]$Directory) {
    $encoding = Get-NativePathEncoding
    try {
        $roundTrip = $encoding.GetString($encoding.GetBytes($Directory))
        if ($roundTrip -cne $Directory) { throw 'Path cannot round-trip.' }
    } catch {
        throw "Weasel Lua cannot represent this directory in Windows code page $($encoding.CodePage): $Directory. Choose a representable Weasel user directory before installation; system locale will not be modified."
    }
}

function Assert-DeploymentTarget([string]$UserDir, [string]$WeaselDir) {
    if ($env:OS -ne 'Windows_NT') { throw 'Native deployment requires Windows. Use -SkipDeploy for isolated tests.' }
    $registered = Get-RegisteredRimeDirectory
    if ($UserDir.TrimEnd('\', '/') -ine $registered.TrimEnd('\', '/')) {
        throw 'Weasel /deploy always uses the registered directory. Use -SkipDeploy for a custom test directory.'
    }
    Assert-NativeRimeDirectory $UserDir
    $installation = Resolve-WeaselDirectory $WeaselDir
    Assert-NativeRimeDirectory $installation
    return $installation
}

function Invoke-WeaselDeployment([string]$WeaselDir) {
    $process = Start-Process -FilePath (Join-Path $WeaselDir 'WeaselDeployer.exe') `
        -ArgumentList '/deploy' -WorkingDirectory $WeaselDir -PassThru -Wait
    if ($process.ExitCode -ne 0) { throw "Weasel deployment failed (exit $($process.ExitCode)). Files and backup remain available." }
}

function Assert-FileHash([string]$File, [string]$Expected) {
    $actual = (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash
    if ($actual -ine $Expected) {
        throw "SHA-256 mismatch: $File. Expected $Expected; got $actual. No unverified resource will be installed."
    }
}

function Get-CheckedDownload([string]$Url, [string]$File, [string]$Hash) {
    if (Test-Path -LiteralPath $File -PathType Leaf) { Assert-FileHash $File $Hash; return }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($File)) | Out-Null
    $temporary = "$File.part-$([Guid]::NewGuid().ToString('N'))"
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    try {
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            try {
                Write-Host "Downloading: $Url"
                Invoke-WebRequest -UseBasicParsing -Uri $Url -Headers @{ Accept = 'application/octet-stream' } -OutFile $temporary -TimeoutSec 180
                break
            } catch {
                if ($attempt -eq 3) { throw }
                Start-Sleep -Seconds 2
            }
        }
        Assert-FileHash $temporary $Hash
        Move-Item -LiteralPath $temporary -Destination $File
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

function Get-WanxiangResources {
    $cache = Join-Path $script:ProjectRoot '.cache/wanxiang'
    $base = Join-Path $cache $script:WanxiangVersion
    $archive = Join-Path $base 'rime-wanxiang-base.zip'
    $model = Join-Path $cache "models/$script:ModelAssetId/wanxiang-lts-zh-hans.gram"
    Get-CheckedDownload "https://github.com/amzxyz/rime-wanxiang/releases/download/$script:WanxiangVersion/rime-wanxiang-base.zip" $archive $script:BaseHash
    Get-CheckedDownload "https://api.github.com/repos/amzxyz/rime-wanxiang-data/releases/assets/$script:ModelAssetId" $model $script:ModelHash
    $source = Join-Path $base 'source'
    if (-not (Test-Path -LiteralPath (Join-Path $source 'wanxiang.schema.yaml'))) {
        if (Test-Path -LiteralPath $source) { throw "Incomplete extraction: $source. Remove that cache directory and retry." }
        $temporary = Join-Path $base "extract-$([Guid]::NewGuid().ToString('N'))"
        try {
            Expand-Archive -LiteralPath $archive -DestinationPath $temporary
            if (-not (Test-Path -LiteralPath (Join-Path $temporary 'wanxiang.schema.yaml'))) { throw 'Invalid Base archive layout.' }
            Move-Item -LiteralPath $temporary -Destination $source
        } finally {
            if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Recurse -Force }
        }
    }
    return @{ Source = $source; Model = $model }
}

function Get-PayloadFiles($Resources) {
    foreach ($relative in $script:UpstreamFiles) {
        [PSCustomObject]@{ Relative = $relative; Source = Join-Path $Resources.Source $relative }
    }
    foreach ($folder in @('lua', 'dicts')) {
        Get-ChildItem -LiteralPath (Join-Path $Resources.Source $folder) -Recurse -File | ForEach-Object {
            [PSCustomObject]@{ Relative = $_.FullName.Substring($Resources.Source.Length + 1).Replace('\', '/'); Source = $_.FullName }
        }
    }
    [PSCustomObject]@{ Relative = 'wanxiang-lts-zh-hans.gram'; Source = $Resources.Model }
    $local = Join-Path $script:ProjectRoot 'rime'
    Get-ChildItem -LiteralPath $local -Recurse -File | Where-Object {
        $_.Name -notin @('squirrel.custom.yaml', 'rime.lua', 'custom_phrase.txt')
    } | ForEach-Object {
        [PSCustomObject]@{ Relative = $_.FullName.Substring($local.Length + 1).Replace('\', '/'); Source = $_.FullName }
    }
}

function Get-SafeChildPath([string]$Root, [string]$Relative) {
    if (-not $Relative -or [IO.Path]::IsPathRooted($Relative) -or
        $Relative -match ':' -or @($Relative -split '[\\/]' | Where-Object { $_ -in @('', '.', '..') }).Count) {
        throw "Unsafe manifest path: $Relative"
    }
    $resolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    if (-not $resolvedRoot -or $resolvedRoot -eq [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Root)).TrimEnd('\', '/')) {
        throw 'A filesystem root is not a permitted installation or backup directory.'
    }
    $result = [IO.Path]::GetFullPath((Join-Path $resolvedRoot $Relative))
    if (-not $result.StartsWith($resolvedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes its root: $Relative"
    }
    # Refuse junctions/symlinks, including the root, before copying or restoring files.
    $ancestor = $result
    while ($ancestor) {
        if (Test-Path -LiteralPath $ancestor) {
            if ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Reparse points are not supported: $ancestor"
            }
        }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
    return $result
}

function Copy-PayloadFile([string]$Source, [string]$Destination) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Destination)) | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Merge-EnglishImports([string]$Destination, [string[]]$PreviousFiles) {
    $content = [IO.File]::ReadAllText($Destination, $script:Utf8)
    $pattern = '(?m)^import_tables:\r?\n((?:(?:[ \t]+-[^\r\n]*|[ \t]*#[^\r\n]*|[ \t]*)\r?\n)*)'
    $imports = New-Object 'System.Collections.Generic.List[string]'
    foreach ($file in @($Destination) + $PreviousFiles) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
        $match = [regex]::Match([IO.File]::ReadAllText($file, $script:Utf8), $pattern)
        foreach ($row in ($match.Groups[1].Value -split '\r?\n')) {
            if ($row -notmatch '^[ \t]+-[ \t]+') { continue }
            $name = ($row -replace '^[ \t]+-[ \t]+', '' -replace '[ \t]*#.*$', '').Trim()
            if ($name -ne 'luna_pinyin' -and $name -match '^[a-zA-Z0-9_.-]+$' -and -not $imports.Contains($name)) {
                $imports.Add($name)
            }
        }
    }
    $match = [regex]::Match($content, $pattern)
    if (-not $match.Success) { throw 'Missing English aggregate import table.' }
    $rows = ($imports | ForEach-Object { "  - $_`n" }) -join ''
    $group = $match.Groups[1]
    Write-Utf8File $Destination ($content.Remove($group.Index, $group.Length).Insert($group.Index, $rows))
}
