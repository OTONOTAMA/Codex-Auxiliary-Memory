param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:BundleRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $script:BundleRoot '..'))
$script:SourceAdapter = Join-Path $script:ProjectRoot '.codex\hooks\ai-memory-adapter.ps1'
$script:HooksJson = Join-Path $script:ProjectRoot '.codex\hooks.json'
$script:PowerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$script:TempRoot = Join-Path $PSScriptRoot ('.tmp-v02-' + [guid]::NewGuid().ToString('N'))
$script:Pass = 0
$script:Fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Write-Utf8 {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, $script:Utf8NoBom)
}

function New-HotStateContent {
    param(
        [string]$CurrentHash,
        [string]$Body = 'fixture state'
    )
    return @"
# AI MEMORY HOT STATE

FORMAT_VERSION = 1
AUTHORITY = DERIVED_NON_CANONICAL
BUNDLE_ID = AI_SUPPLEMENTARY_MEMORY_BUNDLE
BUNDLE_VERSION = 0.2
GENERATED_AT = 2026-10-05T00:00:00+09:00
VALIDATED_AT = 2026-10-05T00:00:00+09:00
VALIDATION_STATUS = PASS
SOURCE_CURRENT = state/current.md
SOURCE_CURRENT_SHA256 = $CurrentHash

## Current objective

$Body

## Retrieval pointers

- AI_MEMORY_BUNDLE/state/current.md
"@
}

function New-Fixture {
    $root = Join-Path $script:TempRoot ([guid]::NewGuid().ToString('N'))
    $hookDir = Join-Path $root '.codex\hooks'
    $bundle = Join-Path $root 'AI_MEMORY_BUNDLE'
    $runtime = Join-Path $bundle 'runtime'
    $state = Join-Path $bundle 'state'
    foreach ($dir in @($hookDir, $runtime, $state)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    Copy-Item -LiteralPath $script:SourceAdapter -Destination (Join-Path $hookDir 'ai-memory-adapter.ps1')
    Write-Utf8 -Path (Join-Path $bundle 'manifest.toml') -Content "bundle_id = `"AI_SUPPLEMENTARY_MEMORY_BUNDLE`"`n"
    Write-Utf8 -Path (Join-Path $bundle 'index.md') -Content "# fixture index`n"
    Write-Utf8 -Path (Join-Path $state 'current.md') -Content "# fixture current state`n"
    $currentHash = Get-Sha256 -Path (Join-Path $state 'current.md')
    Write-Utf8 -Path (Join-Path $runtime 'HOT_STATE.md') -Content (New-HotStateContent -CurrentHash $currentHash)
    return $root
}

function Invoke-Adapter {
    param(
        [string]$FixtureRoot,
        [string]$Mode,
        [string]$InputJson = ''
    )

    $adapter = Join-Path $FixtureRoot '.codex\hooks\ai-memory-adapter.ps1'
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:PowerShellExe
    $psi.Arguments = '-NoLogo -NoProfile -NonInteractive -File "' + $adapter + '" -Mode ' + $Mode
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    [void]$process.Start()
    if (-not [string]::IsNullOrEmpty($InputJson)) {
        $process.StandardInput.Write($InputJson)
    }
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    return [pscustomobject]@{
        exit_code = $process.ExitCode
        stdout = $stdout.Trim()
        stderr = $stderr.Trim()
    }
}

function New-SessionStartEvent {
    param([string]$Source = 'startup')
    return [ordered]@{
        session_id = 'test-session'
        transcript_path = 'C:\secret-transcript-MUST-NOT-BE-READ.jsonl'
        cwd = 'C:\untrusted-cwd'
        hook_event_name = 'SessionStart'
        model = 'test-model'
        source = $Source
    } | ConvertTo-Json -Compress
}

function Run-Test {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        $script:Pass++
        Write-Output "PASS $Name"
    }
    catch {
        $script:Fail++
        Write-Output "FAIL $Name :: $($_.Exception.Message)"
    }
}

New-Item -ItemType Directory -Force -Path $script:TempRoot | Out-Null

try {
    Run-Test 'hooks_json_is_valid_and_sessionstart_only' {
        $hooks = Get-Content -LiteralPath $script:HooksJson -Raw | ConvertFrom-Json
        $eventNames = @($hooks.hooks.PSObject.Properties.Name)
        Assert-True ($eventNames.Count -eq 1) 'Expected exactly one hook event.'
        Assert-True ($eventNames[0] -eq 'SessionStart') 'Only SessionStart may be configured.'
        $group = @($hooks.hooks.SessionStart)[0]
        Assert-True ($group.matcher -eq '^(startup|resume|clear|compact)$') 'Unexpected SessionStart matcher.'
        Assert-True ($group.hooks[0].timeout -eq 3) 'Unexpected timeout.'
    }

    Run-Test 'valid_hot_state_passes_validate' {
        $root = New-Fixture
        $result = Invoke-Adapter -FixtureRoot $root -Mode 'Validate'
        $json = $result.stdout | ConvertFrom-Json
        Assert-True ($result.exit_code -eq 0) 'Validate exit code must be zero.'
        Assert-True ($json.status -eq 'PASS') 'Valid HOT_STATE must pass.'
    }

    Run-Test 'sessionstart_injects_bounded_context' {
        $root = New-Fixture
        $result = Invoke-Adapter -FixtureRoot $root -Mode 'HookSessionStart' -InputJson (New-SessionStartEvent -Source 'compact')
        $json = $result.stdout | ConvertFrom-Json
        Assert-True ($result.exit_code -eq 0) 'Hook must continue.'
        Assert-True ($json.continue -eq $true) 'Hook continue must be true.'
        Assert-True ($json.hookSpecificOutput.hookEventName -eq 'SessionStart') 'Wrong hook output identity.'
        Assert-True ($json.hookSpecificOutput.additionalContext -match 'AI_MEMORY_BOOTSTRAP_STATUS = PASS') 'PASS context missing.'
        Assert-True ($json.hookSpecificOutput.additionalContext -notmatch 'secret-transcript') 'Transcript path leaked into output.'
    }

    Run-Test 'successful_no_change_hook_writes_nothing' {
        $root = New-Fixture
        $hot = Join-Path $root 'AI_MEMORY_BUNDLE\runtime\HOT_STATE.md'
        $beforeHash = Get-Sha256 -Path $hot
        $beforeTime = (Get-Item -LiteralPath $hot).LastWriteTimeUtc
        $result = Invoke-Adapter -FixtureRoot $root -Mode 'HookSessionStart' -InputJson (New-SessionStartEvent)
        $afterHash = Get-Sha256 -Path $hot
        $afterTime = (Get-Item -LiteralPath $hot).LastWriteTimeUtc
        Assert-True ($result.exit_code -eq 0) 'Hook failed.'
        Assert-True ($beforeHash -eq $afterHash) 'HOT_STATE content changed.'
        Assert-True ($beforeTime -eq $afterTime) 'HOT_STATE timestamp changed.'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $root 'AI_MEMORY_BUNDLE\runtime\adapter.log'))) 'Success must not create log.'
    }

    Run-Test 'missing_hot_state_is_unverified_not_success' {
        $root = New-Fixture
        Remove-Item -LiteralPath (Join-Path $root 'AI_MEMORY_BUNDLE\runtime\HOT_STATE.md') -Force
        $result = Invoke-Adapter -FixtureRoot $root -Mode 'HookSessionStart' -InputJson (New-SessionStartEvent)
        $json = $result.stdout | ConvertFrom-Json
        Assert-True ($result.exit_code -eq 0) 'Handled failure must not block chat.'
        Assert-True ($json.systemMessage -match 'UNVERIFIED') 'Missing state must be reported UNVERIFIED.'
        Assert-True ($json.hookSpecificOutput.additionalContext -match 'MANUAL_RECOVERY') 'Manual recovery pointer missing.'
    }

    Run-Test 'source_hash_mismatch_is_stale' {
        $root = New-Fixture
        $current = Join-Path $root 'AI_MEMORY_BUNDLE\state\current.md'
        Write-Utf8 -Path $current -Content "# changed after HOT_STATE`n"
        $result = Invoke-Adapter -FixtureRoot $root -Mode 'HookSessionStart' -InputJson (New-SessionStartEvent)
        $json = $result.stdout | ConvertFrom-Json
        Assert-True ($json.systemMessage -match 'STALE') 'Hash mismatch must be STALE.'
        Assert-True ($json.hookSpecificOutput.additionalContext -notmatch 'fixture state') 'Stale semantic content must not be injected.'
    }

    Run-Test 'hard_size_limit_rejects_hot_state' {
        $root = New-Fixture
        $hot = Join-Path $root 'AI_MEMORY_BUNDLE\runtime\HOT_STATE.md'
        Write-Utf8 -Path $hot -Content ('X' * 17000)
        $result = Invoke-Adapter -FixtureRoot $root -Mode 'HookSessionStart' -InputJson (New-SessionStartEvent)
        $json = $result.stdout | ConvertFrom-Json
        Assert-True ($json.systemMessage -match 'UNVERIFIED') 'Oversized state must be UNVERIFIED.'
        Assert-True ($json.hookSpecificOutput.additionalContext -match 'HOT_STATE_HARD_LIMIT') 'Hard-limit code missing.'
    }

    Run-Test 'commit_hot_state_is_verified_and_atomic' {
        $root = New-Fixture
        $runtime = Join-Path $root 'AI_MEMORY_BUNDLE\runtime'
        $current = Join-Path $root 'AI_MEMORY_BUNDLE\state\current.md'
        $candidate = Join-Path $runtime 'HOT_STATE.candidate.md'
        $oldHash = Get-Sha256 -Path (Join-Path $runtime 'HOT_STATE.md')
        Write-Utf8 -Path $candidate -Content (New-HotStateContent -CurrentHash (Get-Sha256 -Path $current) -Body 'new committed state')
        $result = Invoke-Adapter -FixtureRoot $root -Mode 'CommitHotState'
        $json = $result.stdout | ConvertFrom-Json
        $newHash = Get-Sha256 -Path (Join-Path $runtime 'HOT_STATE.md')
        Assert-True ($result.exit_code -eq 0) 'Commit must succeed.'
        Assert-True ($json.status -eq 'PASS') 'Commit status must pass.'
        Assert-True ($oldHash -ne $newHash) 'Target did not change.'
        Assert-True (-not (Test-Path -LiteralPath $candidate)) 'Candidate must be removed after commit.'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $runtime 'HOT_STATE.rollback.md'))) 'Rollback file must be removed after verification.'
    }

    Run-Test 'invalid_candidate_preserves_last_valid_state' {
        $root = New-Fixture
        $runtime = Join-Path $root 'AI_MEMORY_BUNDLE\runtime'
        $candidate = Join-Path $runtime 'HOT_STATE.candidate.md'
        $target = Join-Path $runtime 'HOT_STATE.md'
        $beforeHash = Get-Sha256 -Path $target
        Write-Utf8 -Path $candidate -Content (New-HotStateContent -CurrentHash ('0' * 64) -Body 'invalid candidate')
        $result = Invoke-Adapter -FixtureRoot $root -Mode 'CommitHotState'
        $afterHash = Get-Sha256 -Path $target
        Assert-True ($result.exit_code -ne 0) 'Invalid candidate must fail.'
        Assert-True ($beforeHash -eq $afterHash) 'Last valid target was changed.'
    }

    Run-Test 'failure_log_is_bounded_and_private' {
        $root = New-Fixture
        $runtime = Join-Path $root 'AI_MEMORY_BUNDLE\runtime'
        $hot = Join-Path $runtime 'HOT_STATE.md'
        $log = Join-Path $runtime 'adapter.log'
        Write-Utf8 -Path $log -Content ('L' * 32700)
        Remove-Item -LiteralPath $hot -Force
        $result = Invoke-Adapter -FixtureRoot $root -Mode 'HookSessionStart' -InputJson (New-SessionStartEvent)
        $rotated = Join-Path $runtime 'adapter.log.1'
        Assert-True ($result.exit_code -eq 0) 'Handled failure must continue.'
        Assert-True ((Get-Item -LiteralPath $log).Length -le 32768) 'Active log exceeds bound.'
        Assert-True ((Get-Item -LiteralPath $rotated).Length -le 32768) 'Rotated log exceeds bound.'
        $combined = (Get-Content -LiteralPath $log -Raw) + (Get-Content -LiteralPath $rotated -Raw)
        Assert-True ($combined -notmatch 'secret-transcript') 'Transcript path leaked into log.'
    }

    Run-Test 'adapter_contains_no_network_or_transcript_read_path' {
        $source = Get-Content -LiteralPath $script:SourceAdapter -Raw
        Assert-True ($source -notmatch 'Invoke-WebRequest|Invoke-RestMethod|System\.Net\.WebClient|HttpClient') 'Network primitive found.'
        Assert-True ($source -notmatch 'Get-Content\s+[^\r\n]*transcript_path|ReadAll(Text|Bytes)\([^\r\n]*transcript_path') 'Transcript read primitive found.'
    }
}
finally {
    $fullTemp = [System.IO.Path]::GetFullPath($script:TempRoot)
    $allowedPrefix = [System.IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\') + '\.tmp-v02-'
    if ($fullTemp.StartsWith($allowedPrefix, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $fullTemp)) {
        Remove-Item -LiteralPath $fullTemp -Recurse -Force
    }
}

Write-Output "RESULT pass=$script:Pass fail=$script:Fail total=$($script:Pass + $script:Fail)"
if ($script:Fail -gt 0) {
    exit 1
}
exit 0
