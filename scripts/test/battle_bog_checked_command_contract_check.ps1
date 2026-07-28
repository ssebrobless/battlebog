[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Assert-Contract {
	param(
		[bool]$Condition,
		[string]$Message
	)
	if (-not $Condition) {
		throw "Checked-command contract assertion failed: $Message"
	}
}

function Read-Result {
	param(
		[string]$ArtifactRoot,
		[string]$CommandId
	)
	$resultPath = Join-Path $ArtifactRoot "$CommandId.result.json"
	Assert-Contract (Test-Path -LiteralPath $resultPath -PathType Leaf) "$CommandId result JSON exists"
	$raw = [System.IO.File]::ReadAllText($resultPath)
	Assert-Contract (-not [string]::IsNullOrWhiteSpace($raw)) "$CommandId result JSON is nonempty"
	try {
		return $raw | ConvertFrom-Json
	} catch {
		throw "Checked-command contract assertion failed: $CommandId result JSON parses: $($_.Exception.Message)"
	}
}

function Invoke-WrapperCase {
	param(
		[string]$Wrapper,
		[string]$ArtifactRoot,
		[string]$Executable,
		[string[]]$Arguments,
		[int]$TimeoutSec,
		[string]$ExpectedMarker,
		[string]$CommandId
	)

	$captured = @()
	$errorRecord = $null
	try {
		$captured = @(& $Wrapper `
			-Executable $Executable `
			-Arguments $Arguments `
			-TimeoutSec $TimeoutSec `
			-ExpectedMarker $ExpectedMarker `
			-CommandId $CommandId `
			-ArtifactRoot $ArtifactRoot 2>&1 6>&1)
	} catch {
		$errorRecord = $_
	}
	return [pscustomobject]@{
		Output = @($captured | ForEach-Object { $_.ToString() })
		ErrorRecord = $errorRecord
	}
}

function Assert-CommonResult {
	param(
		[object]$Result,
		[string]$CommandId,
		[string]$ArtifactRoot
	)

	Assert-Contract ([int]$Result.schema_version -eq 1) "$CommandId schema version"
	Assert-Contract ([string]$Result.command_id -eq $CommandId) "$CommandId identity"
	Assert-Contract (-not [string]::IsNullOrWhiteSpace([string]$Result.exact_command)) "$CommandId exact command"
	Assert-Contract ($Result.arguments -is [array]) "$CommandId arguments array"
	Assert-Contract ([int]$Result.timeout_sec -gt 0) "$CommandId timeout"
	Assert-Contract ([string]$Result.source_tree_fingerprint -match '^[0-9a-f]{64}$') "$CommandId source fingerprint"
	Assert-Contract ([DateTime]::Parse([string]$Result.started_utc).Kind -ne [DateTimeKind]::Unspecified) "$CommandId start UTC"
	Assert-Contract ([DateTime]::Parse([string]$Result.ended_utc).Kind -ne [DateTimeKind]::Unspecified) "$CommandId end UTC"
	Assert-Contract ([int64]$Result.duration_ms -ge 0) "$CommandId duration"
	Assert-Contract ($Result.timed_out -is [bool]) "$CommandId timed_out boolean"
	Assert-Contract ($Result.completion_marker_found -is [bool]) "$CommandId marker boolean"
	Assert-Contract ([int]$Result.matched_test_count -ge 0) "$CommandId matched test count"
	Assert-Contract ($Result.strict_output_issues -is [array]) "$CommandId strict issues array"
	Assert-Contract ($Result.non_pass_test_rows -is [array]) "$CommandId non-pass rows array"
	Assert-Contract ($Result.passed -is [bool]) "$CommandId passed boolean"

	$expectedStdout = Join-Path $ArtifactRoot "$CommandId.stdout.log"
	$expectedStderr = Join-Path $ArtifactRoot "$CommandId.stderr.log"
	Assert-Contract ([string]$Result.stdout_log_path -eq $expectedStdout) "$CommandId stdout path"
	Assert-Contract ([string]$Result.stderr_log_path -eq $expectedStderr) "$CommandId stderr path"
	Assert-Contract (Test-Path -LiteralPath $expectedStdout -PathType Leaf) "$CommandId stdout exists"
	Assert-Contract (Test-Path -LiteralPath $expectedStderr -PathType Leaf) "$CommandId stderr exists"
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$wrapper = Join-Path $scriptRoot "run_checked_command.ps1"
Assert-Contract (Test-Path -LiteralPath $wrapper -PathType Leaf) "wrapper exists"

$powershell = Join-Path $PSHOME "powershell.exe"
if (-not (Test-Path -LiteralPath $powershell -PathType Leaf)) {
	$powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
	"battle-bog-checked-command-" + [Guid]::NewGuid().ToString("N")
)
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
	$fixture = Join-Path $tempRoot "fixture.ps1"
	$runAllFixture = Join-Path $tempRoot "run_all.ps1"
	$childFixture = Join-Path $tempRoot "timeout_child.ps1"
	$parentFixture = Join-Path $tempRoot "timeout_parent.ps1"
	$fakeGit = Join-Path $tempRoot "git.exe"

	[System.IO.File]::WriteAllText($fixture, @'
param([string]$Mode)
switch ($Mode) {
	"pass" {
		Write-Output "fixture stdout"
		[Console]::Error.WriteLine("fixture stderr")
		Write-Output "EXPECTED_MARKER"
		exit 0
	}
	"nonzero" {
		Write-Output "fixture nonzero stdout"
		[Console]::Error.WriteLine("fixture nonzero stderr")
		exit 7
	}
	"missing" {
		Write-Output "fixture completed without its required token"
		exit 0
	}
	"test_pass" {
		Write-Output "battle_bog_probe.gd PASS 1 probe.log"
		exit 0
	}
	"test_zero" {
		Write-Output "No tests matched."
		exit 0
	}
	"test_strict" {
		Write-Output "battle_bog_probe.gd PASS 1 probe.log"
		Write-Output "strict_output_issue: synthetic actionable output"
		exit 0
	}
	"test_nonpass" {
		Write-Output "battle_bog_probe.gd FAIL 1 probe.log"
		exit 0
	}
	default {
		exit 9
	}
}
'@)
	Copy-Item -LiteralPath $fixture -Destination $runAllFixture
	Copy-Item -LiteralPath $env:ComSpec -Destination $fakeGit
	[System.IO.File]::WriteAllText($childFixture, @'
param([string]$Sentinel)
[System.IO.File]::WriteAllText("$Sentinel.started", "$PID")
Start-Sleep -Seconds 8
[System.IO.File]::WriteAllText($Sentinel, "child survived")
'@)
	[System.IO.File]::WriteAllText($parentFixture, @'
param(
	[string]$ChildFixture,
	[string]$Sentinel
)
& (Join-Path $PSHOME "powershell.exe") -NoProfile -ExecutionPolicy Bypass -File $ChildFixture -Sentinel $Sentinel
'@)

	$passRoot = Join-Path $tempRoot "pass"
	New-Item -ItemType Directory -Path $passRoot | Out-Null
	$passCase = Invoke-WrapperCase `
		-Wrapper $wrapper `
		-ArtifactRoot $passRoot `
		-Executable $powershell `
		-Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $fixture, "-Mode", "pass") `
		-TimeoutSec 10 `
		-ExpectedMarker "EXPECTED_MARKER" `
		-CommandId "pass"
	Assert-Contract ($null -eq $passCase.ErrorRecord) "pass case does not throw"
	Assert-Contract ($passCase.Output.Count -eq 1) "pass case prints exactly one line"
	Assert-Contract ($passCase.Output[0] -eq "BB_CHECKED_COMMAND_OK id=pass") "pass marker"
	$passResult = Read-Result -ArtifactRoot $passRoot -CommandId "pass"
	Assert-CommonResult -Result $passResult -CommandId "pass" -ArtifactRoot $passRoot
	Assert-Contract ([bool]$passResult.passed) "pass result passes"
	Assert-Contract ([int]$passResult.exit_code -eq 0) "pass exit code"
	Assert-Contract ([bool]$passResult.completion_marker_found) "pass marker found"
	Assert-Contract ([string]$passResult.failure_reason -eq "") "pass failure reason empty"
	Assert-Contract ((Get-Content -LiteralPath $passResult.stdout_log_path -Raw) -match "fixture stdout") "pass stdout captured"
	Assert-Contract ((Get-Content -LiteralPath $passResult.stderr_log_path -Raw) -match "fixture stderr") "pass stderr captured"

	$nonzeroRoot = Join-Path $tempRoot "nonzero"
	New-Item -ItemType Directory -Path $nonzeroRoot | Out-Null
	$nonzeroCase = Invoke-WrapperCase `
		-Wrapper $wrapper `
		-ArtifactRoot $nonzeroRoot `
		-Executable $powershell `
		-Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $fixture, "-Mode", "nonzero") `
		-TimeoutSec 10 `
		-ExpectedMarker "" `
		-CommandId "nonzero"
	Assert-Contract ($null -ne $nonzeroCase.ErrorRecord) "nonzero case throws"
	Assert-Contract ($nonzeroCase.Output.Count -eq 0) "nonzero case prints no pass marker"
	$nonzeroResult = Read-Result -ArtifactRoot $nonzeroRoot -CommandId "nonzero"
	Assert-CommonResult -Result $nonzeroResult -CommandId "nonzero" -ArtifactRoot $nonzeroRoot
	Assert-Contract (-not [bool]$nonzeroResult.passed) "nonzero result fails"
	Assert-Contract ([int]$nonzeroResult.exit_code -eq 7) "nonzero exit preserved"
	Assert-Contract ([string]$nonzeroResult.failure_reason -eq "nonzero_exit") "nonzero reason"
	Assert-Contract ((Get-Content -LiteralPath $nonzeroResult.stderr_log_path -Raw) -match "fixture nonzero stderr") "nonzero stderr captured"

	$missingRoot = Join-Path $tempRoot "missing"
	New-Item -ItemType Directory -Path $missingRoot | Out-Null
	$missingCase = Invoke-WrapperCase `
		-Wrapper $wrapper `
		-ArtifactRoot $missingRoot `
		-Executable $powershell `
		-Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $fixture, "-Mode", "missing") `
		-TimeoutSec 10 `
		-ExpectedMarker "EXPECTED_MARKER" `
		-CommandId "missing"
	Assert-Contract ($null -ne $missingCase.ErrorRecord) "missing-marker case throws"
	Assert-Contract ($missingCase.Output.Count -eq 0) "missing-marker case prints no pass marker"
	$missingResult = Read-Result -ArtifactRoot $missingRoot -CommandId "missing"
	Assert-CommonResult -Result $missingResult -CommandId "missing" -ArtifactRoot $missingRoot
	Assert-Contract (-not [bool]$missingResult.passed) "missing-marker result fails"
	Assert-Contract ([int]$missingResult.exit_code -eq 0) "missing-marker exit preserved"
	Assert-Contract (-not [bool]$missingResult.completion_marker_found) "missing marker absent"
	Assert-Contract ([string]$missingResult.failure_reason -eq "missing_marker") "missing-marker reason"

	foreach ($testCase in @(
		@("test_zero", "zero_matched_tests"),
		@("test_strict", "strict_output_issue"),
		@("test_nonpass", "non_pass_test_row")
	)) {
		$mode = [string]$testCase[0]
		$expectedReason = [string]$testCase[1]
		$caseRoot = Join-Path $tempRoot $mode
		New-Item -ItemType Directory -Path $caseRoot | Out-Null
		$case = Invoke-WrapperCase `
			-Wrapper $wrapper `
			-ArtifactRoot $caseRoot `
			-Executable $powershell `
			-Arguments @(
				"-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
				$runAllFixture, "-Mode", $mode
			) `
			-TimeoutSec 10 `
			-ExpectedMarker "" `
			-CommandId $mode
		Assert-Contract ($null -ne $case.ErrorRecord) "$mode case throws"
		$result = Read-Result -ArtifactRoot $caseRoot -CommandId $mode
		Assert-CommonResult -Result $result -CommandId $mode -ArtifactRoot $caseRoot
		Assert-Contract (-not [bool]$result.passed) "$mode result fails"
		Assert-Contract (
			[string]$result.failure_reason -eq $expectedReason
		) "$mode failure reason"
	}

	$diffRoot = Join-Path $tempRoot "diff-output"
	New-Item -ItemType Directory -Path $diffRoot | Out-Null
	$diffCase = Invoke-WrapperCase `
		-Wrapper $wrapper `
		-ArtifactRoot $diffRoot `
		-Executable $fakeGit `
		-Arguments @("/d", "/s", "/c", "echo synthetic diff output", "diff", "--check") `
		-TimeoutSec 10 `
		-ExpectedMarker "" `
		-CommandId "diff-output"
	Assert-Contract ($null -ne $diffCase.ErrorRecord) "diff-output case throws"
	$diffResult = Read-Result -ArtifactRoot $diffRoot -CommandId "diff-output"
	Assert-CommonResult -Result $diffResult -CommandId "diff-output" -ArtifactRoot $diffRoot
	Assert-Contract (
		[string]$diffResult.failure_reason -eq "diff_check_output"
	) "diff-output failure reason"

	$timeoutRoot = Join-Path $tempRoot "timeout"
	New-Item -ItemType Directory -Path $timeoutRoot | Out-Null
	$sentinel = Join-Path $tempRoot "timeout-sentinel.txt"
	$timeoutCase = Invoke-WrapperCase `
		-Wrapper $wrapper `
		-ArtifactRoot $timeoutRoot `
		-Executable $powershell `
		-Arguments @(
			"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $parentFixture,
			"-ChildFixture", $childFixture, "-Sentinel", $sentinel
		) `
		-TimeoutSec 2 `
		-ExpectedMarker "" `
		-CommandId "timeout"
	Assert-Contract ($null -ne $timeoutCase.ErrorRecord) "timeout case throws"
	Assert-Contract ($timeoutCase.Output.Count -eq 0) "timeout case prints no pass marker"
	$timeoutResult = Read-Result -ArtifactRoot $timeoutRoot -CommandId "timeout"
	Assert-CommonResult -Result $timeoutResult -CommandId "timeout" -ArtifactRoot $timeoutRoot
	Assert-Contract (-not [bool]$timeoutResult.passed) "timeout result fails"
	Assert-Contract ([bool]$timeoutResult.timed_out) "timeout flag"
	Assert-Contract ([int]$timeoutResult.exit_code -eq 124) "timeout exit code"
	Assert-Contract ([string]$timeoutResult.failure_reason -eq "timeout") "timeout reason"
	Assert-Contract (Test-Path -LiteralPath "$sentinel.started" -PathType Leaf) "timeout child started"
	$childPid = [int]([System.IO.File]::ReadAllText("$sentinel.started"))
	Start-Sleep -Seconds 7
	Assert-Contract (-not (Test-Path -LiteralPath $sentinel)) "timeout child cannot write after tree termination"
	Assert-Contract ($null -eq (Get-Process -Id $childPid -ErrorAction SilentlyContinue)) "timeout child process terminated"
} finally {
	if (Test-Path -LiteralPath $tempRoot) {
		Remove-Item -LiteralPath $tempRoot -Recurse -Force
	}
}

Write-Output "BB_CHECKED_COMMAND_CONTRACT_OK"
