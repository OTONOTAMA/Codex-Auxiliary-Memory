[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetProjectRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false, $true)
$packageRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$payloadRoot = Join-Path $packageRoot 'payload'
$sourceBundle = Join-Path $payloadRoot 'AI_MEMORY_BUNDLE'
$sourceAdapter = Join-Path $payloadRoot '.codex\hooks\ai-memory-adapter.ps1'
$sourceDocs = Join-Path $payloadRoot 'docs'
$targetRoot = [System.IO.Path]::GetFullPath($TargetProjectRoot)
$targetBundle = Join-Path $targetRoot 'AI_MEMORY_BUNDLE'
$targetCodex = Join-Path $targetRoot '.codex'
$targetHooks = Join-Path $targetCodex 'hooks'
$targetHooksJson = Join-Path $targetCodex 'hooks.json'
$targetAdapter = Join-Path $targetHooks 'ai-memory-adapter.ps1'

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Update-TargetManifest {
    $manifestPath = Join-Path $targetBundle 'manifest.toml'
    $lines = [System.IO.File]::ReadAllLines($manifestPath, $utf8NoBom)
    $result = New-Object System.Collections.Generic.List[string]
    $inBundleIntegrity = $false
    $inHostIntegrity = $false
    $integrityCount = 0

    foreach ($line in $lines) {
        if ($line -eq '[integrity]') {
            $inBundleIntegrity = $true
            $inHostIntegrity = $false
            $result.Add($line)
            continue
        }
        if ($line -eq '[host_adapter.integrity]') {
            $inBundleIntegrity = $false
            $inHostIntegrity = $true
            $result.Add($line)
            continue
        }
        if ($line -match '^\[') {
            $inBundleIntegrity = $false
            $inHostIntegrity = $false
        }

        if ($inBundleIntegrity -and $line -match '^"(?<relative>[^"]+)"\s*=\s*"[^"]*"\s*$') {
            $relative = $Matches.relative.Replace('/', '\')
            $filePath = Join-Path $targetBundle $relative
            if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                throw "Manifest integrity source is missing: $filePath"
            }
            $hash = Get-Sha256 -Path $filePath
            $result.Add('"' + $Matches.relative + '" = "' + $hash + '"')
            $integrityCount++
            continue
        }

        if ($inHostIntegrity -and $line -match '^hooks_json_sha256\s*=') {
            $result.Add('hooks_json_sha256 = "' + (Get-Sha256 -Path $targetHooksJson) + '"')
            continue
        }
        if ($inHostIntegrity -and $line -match '^script_sha256\s*=') {
            $result.Add('script_sha256 = "' + (Get-Sha256 -Path $targetAdapter) + '"')
            continue
        }
        $result.Add($line)
    }

    for ($index = 0; $index -lt $result.Count; $index++) {
        if ($result[$index] -match '^file_count_excluding_manifest\s*=') {
            $result[$index] = 'file_count_excluding_manifest = ' + $integrityCount
        }
    }

    Write-Utf8NoBom -Path $manifestPath -Content (($result -join "`r`n") + "`r`n")
}

if (-not (Test-Path -LiteralPath $targetRoot -PathType Container)) {
    throw "Target project root does not exist: $targetRoot"
}
if (-not (Test-Path -LiteralPath $sourceBundle -PathType Container)) {
    throw "Package payload is incomplete: $sourceBundle"
}
if (-not (Test-Path -LiteralPath $sourceAdapter -PathType Leaf)) {
    throw "Package payload is incomplete: $sourceAdapter"
}

$conflicts = @(
    @($targetBundle, $targetHooksJson, $targetAdapter) + @(
        if (Test-Path -LiteralPath $sourceDocs -PathType Container) {
            Get-ChildItem -LiteralPath $sourceDocs -File | ForEach-Object { Join-Path $targetRoot $_.Name }
        }
    ) |
        Where-Object { Test-Path -LiteralPath $_ }
)
if ($conflicts.Count -gt 0) {
    Write-Output 'INSTALLATION_STATUS = BLOCKED_EXISTING_TARGET'
    Write-Output 'Existing files were not changed:'
    $conflicts | ForEach-Object { Write-Output "  $_" }
    Write-Output 'Ask Codex to inspect scope and plan a minimal authorized merge; do not overwrite memory or trust.'
    exit 2
}

New-Item -ItemType Directory -Path $targetHooks -Force | Out-Null
Copy-Item -LiteralPath $sourceBundle -Destination $targetBundle -Recurse
Copy-Item -LiteralPath $sourceAdapter -Destination $targetAdapter

if (Test-Path -LiteralPath $sourceDocs -PathType Container) {
    Get-ChildItem -LiteralPath $sourceDocs -File | ForEach-Object {
        $destination = Join-Path $targetRoot $_.Name
        if (Test-Path -LiteralPath $destination) {
            throw "Companion document already exists after payload copy: $destination"
        }
        Copy-Item -LiteralPath $_.FullName -Destination $destination
    }
}

$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$portableCommand = 'powershell.exe -NoLogo -NoProfile -NonInteractive -File "' + $targetAdapter + '" -Mode HookSessionStart'
$windowsCommand = $windowsPowerShell + ' -NoLogo -NoProfile -NonInteractive -File "' + $targetAdapter + '" -Mode HookSessionStart'
$hooksObject = [ordered]@{
    description = 'Lightweight AI memory bootstrap for this project.'
    hooks = [ordered]@{
        SessionStart = @(
            [ordered]@{
                matcher = '^(startup|resume|clear|compact)$'
                hooks = @(
                    [ordered]@{
                        type = 'command'
                        command = $portableCommand
                        commandWindows = $windowsCommand
                        timeout = 3
                        statusMessage = 'Loading compact AI memory'
                        additionalContextLimit = 1800
                    }
                )
            }
        )
    }
}
$hooksJson = $hooksObject | ConvertTo-Json -Depth 10
Write-Utf8NoBom -Path $targetHooksJson -Content ($hooksJson + "`r`n")

Update-TargetManifest

Write-Output "TARGET_PROJECT_ROOT = $targetRoot"
Write-Output 'INSTALLATION_SCOPE = PROJECT'
Write-Output 'MEMORY_SCOPE = SHARED_BY_CHATS_USING_THIS_PROJECT_INSTALLATION'
Write-Output 'GLOBAL_INSTALLATION = NOT_PROVIDED; AUTO_CROSS_PC_SHARING = NONE'
Write-Output 'INSTALLATION_STATUS = FILES_INSTALLED'
Write-Output 'DETERMINISTIC_TESTS = PENDING_RUN_FIRST'
Write-Output 'ADAPTER_STATUS = PENDING_RUN_AFTER_TESTS'
Write-Output 'LIVE_SESSIONSTART_INJECTION = UNVERIFIED'
Write-Output 'LIVE_POST_COMPACTION_REINJECTION = UNVERIFIED'
Write-Output 'Run test_adapter_v0.2.ps1 first, then run the installed adapter Status mode.'
Write-Output 'Then restart or resume Codex and verify live injection.'
exit 0


