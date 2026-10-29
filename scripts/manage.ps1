# SPDX-License-Identifier: GPL-3.0-or-later
#Requires -Version 5.1
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
$ErrorActionPreference = 'Stop'
$python = $null
$prefix = @()
foreach ($name in @('py', 'python3', 'python')) {
    $candidate = Get-Command $name -ErrorAction SilentlyContinue
    if ($candidate -and $candidate.Source -notlike '*WindowsApps*') {
        $candidatePrefix = @()
        if ($name -eq 'py') { $candidatePrefix = @('-3') }
        & $candidate.Source @candidatePrefix -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $python = $candidate.Source
            $prefix = $candidatePrefix
            break
        }
    }
}
if (-not $python) { throw 'Optional management tools require Python 3.8 or newer. Normal input-method installation does not require Python.' }
& $python @prefix -X utf8 (Join-Path $PSScriptRoot 'manage.py') @Arguments
exit $LASTEXITCODE
