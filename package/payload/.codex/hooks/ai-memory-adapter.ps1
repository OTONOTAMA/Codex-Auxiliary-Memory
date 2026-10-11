param(
    [ValidateSet('HookSessionStart', 'Validate', 'Status', 'CommitHotState')]
    [string]$Mode = 'HookSessionStart'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false, $true)
[Console]::InputEncoding = $script:Utf8NoBom
[Console]::OutputEncoding = $script:Utf8NoBom
$OutputEncoding = $script:Utf8NoBom

$script:ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script:BundleRoot = [System.IO.Path]::GetFullPath((Join-Path $script:ProjectRoot 'AI_MEMORY_BUNDLE'))
$script:RuntimeRoot = [System.IO.Path]::GetFullPath((Join-Path $script:BundleRoot 'runtime'))
$script:ManifestPath = Join-Path $script:BundleRoot 'manifest.toml'
$script:IndexPath = Join-Path $script:BundleRoot 'index.md'
$script:CurrentStatePath = Join-Path $script:BundleRoot 'state\current.md'
$script:HotStatePath = Join-Path $script:RuntimeRoot 'HOT_STATE.md'
$script:CandidatePath = Join-Path $script:RuntimeRoot 'HOT_STATE.candidate.md'
$script:LogPath = Join-Path $script:RuntimeRoot 'adapter.log'
$script:RotatedLogPath = Join-Path $script:RuntimeRoot 'adapter.log.1'
$script:TargetMaxBytes = 4096
$script:HardMaxBytes = 16384
$script:LogMaxBytes = 32768
$script:AllowedSources = @('startup', 'resume', 'clear', 'compact')

function Test-PathInsideRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    return $fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            return ([System.BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToUpperInvariant()
        }
        finally {
            $sha.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-HeaderValue {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $pattern = '(?m)^' + [regex]::Escape($Name) + '\s*=\s*(.+?)\s*$'
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        return $null
    }
    return $match.Groups[1].Value.Trim()
}

function New-ValidationResult {
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$Code,
        [Parameter(Mandatory = $true)][string]$Message,
        [int64]$Bytes = 0,
        [string]$Content = '',
        [string]$SourceHash = ''
    )

    return [pscustomobject]@{
        status = $Status
        code = $Code
        message = $Message
        bytes = $Bytes
        content = $Content
        source_current_sha256 = $SourceHash
    }
}

function Test-HotState {
    param([Parameter(Mandatory = $true)][string]$Path)

    foreach ($required in @($script:ManifestPath, $script:IndexPath, $script:CurrentStatePath)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
            return New-ValidationResult -Status 'UNVERIFIED' -Code 'REQUIRED_SOURCE_MISSING' -Message ([System.IO.Path]::GetFileName($required))
        }
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return New-ValidationResult -Status 'UNVERIFIED' -Code 'HOT_STATE_MISSING' -Message 'HOT_STATE.md is missing.'
    }

    if (-not (Test-PathInsideRoot -Path $Path -Root $script:RuntimeRoot)) {
        return New-ValidationResult -Status 'UNVERIFIED' -Code 'PATH_OUTSIDE_RUNTIME_ROOT' -Message 'HOT_STATE path is outside the runtime root.'
    }

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -gt $script:HardMaxBytes) {
        return New-ValidationResult -Status 'UNVERIFIED' -Code 'HOT_STATE_HARD_LIMIT' -Message 'HOT_STATE exceeds the hard byte limit.' -Bytes $bytes.Length
    }

    try {
        $content = $script:Utf8NoBom.GetString($bytes)
    }
    catch {
        return New-ValidationResult -Status 'UNVERIFIED' -Code 'HOT_STATE_ENCODING' -Message 'HOT_STATE is not valid UTF-8.' -Bytes $bytes.Length
    }

    $formatVersion = Get-HeaderValue -Content $content -Name 'FORMAT_VERSION'
    $authority = Get-HeaderValue -Content $content -Name 'AUTHORITY'
    $bundleId = Get-HeaderValue -Content $content -Name 'BUNDLE_ID'
    $declaredHash = Get-HeaderValue -Content $content -Name 'SOURCE_CURRENT_SHA256'

    if ($formatVersion -ne '1') {
        return New-ValidationResult -Status 'UNVERIFIED' -Code 'FORMAT_VERSION' -Message 'Unsupported HOT_STATE format version.' -Bytes $bytes.Length
    }
    if ($authority -ne 'DERIVED_NON_CANONICAL') {
        return New-ValidationResult -Status 'UNVERIFIED' -Code 'AUTHORITY_INVALID' -Message 'HOT_STATE authority must be DERIVED_NON_CANONICAL.' -Bytes $bytes.Length
    }
    if ($bundleId -ne 'AI_SUPPLEMENTARY_MEMORY_BUNDLE') {
        return New-ValidationResult -Status 'UNVERIFIED' -Code 'BUNDLE_ID_INVALID' -Message 'Unexpected Bundle identity.' -Bytes $bytes.Length
    }
    if ($declaredHash -notmatch '^[A-Fa-f0-9]{64}$') {
        return New-ValidationResult -Status 'UNVERIFIED' -Code 'SOURCE_HASH_INVALID' -Message 'SOURCE_CURRENT_SHA256 is missing or invalid.' -Bytes $bytes.Length
    }

    $actualHash = Get-Sha256 -Path $script:CurrentStatePath
    if ($declaredHash.ToUpperInvariant() -ne $actualHash) {
        return New-ValidationResult -Status 'STALE' -Code 'SOURCE_HASH_MISMATCH' -Message 'HOT_STATE does not match state/current.md.' -Bytes $bytes.Length -SourceHash $actualHash
    }

    if ($bytes.Length -gt $script:TargetMaxBytes) {
        return New-ValidationResult -Status 'DEGRADED' -Code 'HOT_STATE_TARGET_LIMIT' -Message 'HOT_STATE exceeds the normal bootstrap target.' -Bytes $bytes.Length -SourceHash $actualHash
    }

    return New-ValidationResult -Status 'PASS' -Code 'OK' -Message 'HOT_STATE is valid.' -Bytes $bytes.Length -Content $content -SourceHash $actualHash
}

function Protect-LogValue {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return ''
    }
    $clean = $Value -replace '[\r\n\t|]', ' '
    if ($clean.Length -gt 160) {
        return $clean.Substring(0, 160)
    }
    return $clean
}

function Write-AdapterLog {
    param(
        [Parameter(Mandatory = $true)][string]$EventName,
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$ResultCode,
        [Parameter(Mandatory = $true)][string]$ValidationState,
        [Parameter(Mandatory = $true)][long]$DurationMs
    )

    if (-not (Test-Path -LiteralPath $script:RuntimeRoot -PathType Container)) {
        return
    }
    if (-not (Test-PathInsideRoot -Path $script:LogPath -Root $script:BundleRoot)) {
        return
    }

    $line = '{0}|event={1}|source={2}|result={3}|validation={4}|path=runtime/HOT_STATE.md|duration_ms={5}' -f @(
        [DateTimeOffset]::Now.ToString('o'),
        (Protect-LogValue $EventName),
        (Protect-LogValue $Source),
        (Protect-LogValue $ResultCode),
        (Protect-LogValue $ValidationState),
        $DurationMs
    )
    $lineBytes = $script:Utf8NoBom.GetByteCount($line + [Environment]::NewLine)

    if (Test-Path -LiteralPath $script:LogPath -PathType Leaf) {
        $currentLength = (Get-Item -LiteralPath $script:LogPath).Length
        if (($currentLength + $lineBytes) -gt $script:LogMaxBytes) {
            if (Test-Path -LiteralPath $script:RotatedLogPath -PathType Leaf) {
                Remove-Item -LiteralPath $script:RotatedLogPath -Force
            }
            Move-Item -LiteralPath $script:LogPath -Destination $script:RotatedLogPath -Force
        }
    }

    [System.IO.File]::AppendAllText($script:LogPath, $line + [Environment]::NewLine, $script:Utf8NoBom)
}

function New-RecoveryContext {
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$Code
    )

    return @"
AI_MEMORY_BOOTSTRAP_STATUS = $Status
AI_MEMORY_BOOTSTRAP_CODE = $Code
HOT_STATE_AUTHORITY = DERIVED_NON_CANONICAL
MANUAL_RECOVERY = Read AI_MEMORY_BUNDLE/manifest.toml, AI_MEMORY_BUNDLE/index.md, and AI_MEMORY_BUNDLE/state/current.md. Do not reconstruct missing authority from model memory.
"@.Trim()
}

function Write-JsonOutput {
    param([Parameter(Mandatory = $true)]$Value)

    $json = $Value | ConvertTo-Json -Depth 10 -Compress
    [Console]::Out.WriteLine($json)
}

function Invoke-HookSessionStart {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $eventName = 'SessionStart'
    $source = 'unknown'

    try {
        $raw = [Console]::In.ReadToEnd()
        if ([string]::IsNullOrWhiteSpace($raw) -or $raw.Length -gt 65536) {
            throw 'Hook input is missing or exceeds the input bound.'
        }

        $event = $raw | ConvertFrom-Json
        $eventName = [string]$event.hook_event_name
        $source = [string]$event.source

        if ($eventName -ne 'SessionStart') {
            throw 'Unexpected hook event.'
        }
        if ($script:AllowedSources -notcontains $source) {
            throw 'Unexpected SessionStart source.'
        }

        $result = Test-HotState -Path $script:HotStatePath
        $stopwatch.Stop()

        if ($result.status -eq 'PASS') {
            $context = @"
AI_MEMORY_BOOTSTRAP_STATUS = PASS
HOT_STATE_AUTHORITY = DERIVED_NON_CANONICAL
If HOT_STATE conflicts with a declared canonical source, the canonical source wins.
Resolve only the canonical sources required for the current task.

$($result.content)
"@.Trim()
            Write-JsonOutput -Value ([ordered]@{
                continue = $true
                hookSpecificOutput = [ordered]@{
                    hookEventName = 'SessionStart'
                    additionalContext = $context
                }
            })
            return
        }

        Write-AdapterLog -EventName $eventName -Source $source -ResultCode $result.code -ValidationState $result.status -DurationMs $stopwatch.ElapsedMilliseconds
        Write-JsonOutput -Value ([ordered]@{
            continue = $true
            systemMessage = "AI memory bootstrap is $($result.status): $($result.code). Use the manual bootstrap path if memory is required."
            hookSpecificOutput = [ordered]@{
                hookEventName = 'SessionStart'
                additionalContext = (New-RecoveryContext -Status $result.status -Code $result.code)
            }
        })
    }
    catch {
        $stopwatch.Stop()
        try {
            Write-AdapterLog -EventName $eventName -Source $source -ResultCode 'HOOK_INPUT_OR_SCRIPT_ERROR' -ValidationState 'UNVERIFIED' -DurationMs $stopwatch.ElapsedMilliseconds
        }
        catch {
            # Codex will still receive the bounded warning below.
        }

        Write-JsonOutput -Value ([ordered]@{
            continue = $true
            systemMessage = 'AI memory bootstrap is UNVERIFIED because the local hook could not complete.'
            hookSpecificOutput = [ordered]@{
                hookEventName = 'SessionStart'
                additionalContext = (New-RecoveryContext -Status 'UNVERIFIED' -Code 'HOOK_INPUT_OR_SCRIPT_ERROR')
            }
        })
    }
}

function Invoke-Validate {
    $result = Test-HotState -Path $script:HotStatePath
    Write-JsonOutput -Value ([ordered]@{
        status = $result.status
        code = $result.code
        message = $result.message
        bytes = $result.bytes
        source_current_sha256 = $result.source_current_sha256
        project_root = $script:ProjectRoot
        bundle_root = $script:BundleRoot
    })
    if ($result.status -eq 'PASS') {
        exit 0
    }
    exit 1
}

function Invoke-CommitHotState {
    if (-not (Test-Path -LiteralPath $script:CandidatePath -PathType Leaf)) {
        throw 'HOT_STATE.candidate.md is missing.'
    }

    $result = Test-HotState -Path $script:CandidatePath
    if ($result.status -ne 'PASS') {
        Write-JsonOutput -Value ([ordered]@{
            status = 'FAILED'
            code = $result.code
            message = $result.message
            committed = $false
        })
        exit 1
    }

    $candidateBytes = [System.IO.File]::ReadAllBytes($script:CandidatePath)
    $tempPath = Join-Path $script:RuntimeRoot ('HOT_STATE.tmp.' + [guid]::NewGuid().ToString('N'))
    $backupPath = Join-Path $script:RuntimeRoot 'HOT_STATE.rollback.md'

    if (-not (Test-PathInsideRoot -Path $tempPath -Root $script:RuntimeRoot)) {
        throw 'Temporary path escaped the runtime root.'
    }

    try {
        [System.IO.File]::WriteAllBytes($tempPath, $candidateBytes)
        if (Test-Path -LiteralPath $script:HotStatePath -PathType Leaf) {
            if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
                Remove-Item -LiteralPath $backupPath -Force
            }
            [System.IO.File]::Replace($tempPath, $script:HotStatePath, $backupPath, $true)
        }
        else {
            [System.IO.File]::Move($tempPath, $script:HotStatePath)
        }

        $final = Test-HotState -Path $script:HotStatePath
        if ($final.status -ne 'PASS') {
            throw ('Post-commit verification failed: ' + $final.code)
        }

        if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
            Remove-Item -LiteralPath $backupPath -Force
        }
        Remove-Item -LiteralPath $script:CandidatePath -Force

        Write-JsonOutput -Value ([ordered]@{
            status = 'PASS'
            code = 'HOT_STATE_COMMITTED'
            committed = $true
            bytes = $final.bytes
            sha256 = (Get-Sha256 -Path $script:HotStatePath)
        })
        exit 0
    }
    catch {
        if (Test-Path -LiteralPath $tempPath -PathType Leaf) {
            Remove-Item -LiteralPath $tempPath -Force
        }
        if ((Test-Path -LiteralPath $backupPath -PathType Leaf) -and -not (Test-Path -LiteralPath $script:HotStatePath -PathType Leaf)) {
            Move-Item -LiteralPath $backupPath -Destination $script:HotStatePath -Force
        }
        Write-JsonOutput -Value ([ordered]@{
            status = 'FAILED'
            code = 'COMMIT_FAILED'
            message = $_.Exception.Message
            committed = $false
        })
        exit 1
    }
}

switch ($Mode) {
    'HookSessionStart' { Invoke-HookSessionStart }
    'Validate' { Invoke-Validate }
    'Status' { Invoke-Validate }
    'CommitHotState' { Invoke-CommitHotState }
}
