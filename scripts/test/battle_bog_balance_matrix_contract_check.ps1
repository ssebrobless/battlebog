param(
	[string]$Godot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Invoke-Matrix {
	param(
		[hashtable]$Parameters
	)
	if (-not [string]::IsNullOrWhiteSpace($Godot)) {
		$Parameters.Godot = $Godot
	}
	try {
		$output = & $matrixRunner @Parameters 2>&1 |
			ForEach-Object { $_.ToString() }
		return [pscustomobject]@{
			ExitCode = 0
			Output = ($output -join [Environment]::NewLine)
		}
	} catch {
		return [pscustomobject]@{
			ExitCode = 1
			Output = "$($_.Exception.Message)$([Environment]::NewLine)$($_.ScriptStackTrace)"
		}
	}
}

function Assert-BlockedCardinality {
	param(
		[string]$Stage,
		[int]$ExpectedCount,
		[string]$ExpectedStageSummary,
		[string]$OutputRoot
	)
	$result = Invoke-Matrix -Parameters @{
		ValidateOnly = $true
		Stage = $Stage
		MaxJobs = $ExpectedCount - 1
		OutputRoot = $OutputRoot
	}
	$expected = "Plan contains $ExpectedCount jobs ($ExpectedStageSummary)"
	if ($result.ExitCode -eq 0 -or $result.Output -notmatch [regex]::Escape($expected)) {
		throw "$Stage cardinality check did not fail with '$expected': $($result.Output)"
	}
}

function Write-Utf8NoBomLine {
	param(
		[string]$Path,
		[string]$Line
	)
	$encoding = New-Object System.Text.UTF8Encoding($false)
	[System.IO.File]::WriteAllText(
		$Path,
		$Line + [Environment]::NewLine,
		$encoding
	)
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..\..")).Path
$matrixRunner = Join-Path $scriptRoot "run_balance_matrix.ps1"
if (-not (Test-Path -LiteralPath $matrixRunner -PathType Leaf)) {
	throw "Missing matrix runner '$matrixRunner'."
}

$contractRoot = Join-Path $repoRoot "artifacts\balance-matrix-contract-check"
$resolvedRepo = (Resolve-Path -LiteralPath $repoRoot).Path
if (Test-Path -LiteralPath $contractRoot) {
	$resolvedContract = (Resolve-Path -LiteralPath $contractRoot).Path
	if (-not $resolvedContract.StartsWith(
		$resolvedRepo + [System.IO.Path]::DirectorySeparatorChar,
		[System.StringComparison]::OrdinalIgnoreCase
	)) {
		throw "Refusing to clean contract artifacts outside the repository."
	}
	Remove-Item -LiteralPath $resolvedContract -Recurse -Force
}

$common = @{
	ValidateOnly = $true
	PairingMode = "Mirror"
	SquadIds = @("S1", "S2")
	Seeds = @(7L)
	WorkerCount = 2
	MaxJobs = 2
	OutputRoot = $contractRoot
}

$first = Invoke-Matrix -Parameters $common.Clone()
if ($first.ExitCode -ne 0) {
	throw "Initial validation matrix failed: $($first.Output)"
}
$mergedPath = Join-Path $contractRoot "results.jsonl"
$summaryPath = Join-Path $contractRoot "summary.json"
if (-not (Test-Path -LiteralPath $mergedPath -PathType Leaf)) {
	throw "Validation matrix did not write '$mergedPath'."
}
$firstLines = @(Get-Content -LiteralPath $mergedPath | Where-Object {
	-not [string]::IsNullOrWhiteSpace($_)
})
if ($firstLines.Count -ne 2) {
	throw "Expected two deterministic validation records; found $($firstLines.Count)."
}
$firstHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $mergedPath).Hash
$jobResults = @(Get-ChildItem -LiteralPath (Join-Path $contractRoot "jobs") `
	-Filter "result.jsonl" -Recurse)
if ($jobResults.Count -ne 2) {
	throw "Expected two isolated per-job results; found $($jobResults.Count)."
}
$timestamps = @{}
foreach ($result in $jobResults) {
	$timestamps[$result.FullName] = $result.LastWriteTimeUtc
}

$second = Invoke-Matrix -Parameters $common.Clone()
if ($second.ExitCode -ne 0) {
	throw "Resume validation matrix failed: $($second.Output)"
}
$secondHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $mergedPath).Hash
if ($secondHash -ne $firstHash) {
	throw "Deterministic merge changed after a no-op resume."
}
foreach ($result in $jobResults) {
	$current = (Get-Item -LiteralPath $result.FullName).LastWriteTimeUtc
	if ($current -ne $timestamps[$result.FullName]) {
		throw "Resume rewrote completed job '$($result.FullName)'."
	}
}
$summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
if ([int]$summary.executed_jobs -ne 0 -or [int]$summary.resumed_jobs -ne 2) {
	throw "Resume summary did not report zero executed and two resumed jobs."
}
$manifestPath = Join-Path $contractRoot "manifest.json"
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([string]$manifest.schema -ne "battle_bog.balance_matrix.v3") {
	throw "Matrix manifest did not use the build-safe v3 schema."
}
if (
	[string]::IsNullOrWhiteSpace(
		[string]$manifest.build_identity.identity_sha256
	) -or
	[string]$manifest.contract.build_identity.identity_sha256 -ne
		[string]$manifest.build_identity.identity_sha256 -or
	[string]::IsNullOrWhiteSpace(
		[string]$manifest.build_identity.contract.git_head
	) -or
	[string]::IsNullOrWhiteSpace(
		[string]$manifest.build_identity.contract.dirty_worktree_sha256
	) -or
	[string]::IsNullOrWhiteSpace(
		[string]$manifest.build_identity.contract.source_tree_sha256
	) -or
	[string]::IsNullOrWhiteSpace(
		[string]$manifest.build_identity.contract.runner_ps1_sha256
	) -or
	[string]::IsNullOrWhiteSpace(
		[string]$manifest.build_identity.contract.runner_gd_sha256
	)
) {
	throw "Matrix manifest is missing required deterministic build identity fields."
}
$resultMetadata = @(Get-ChildItem -LiteralPath (Join-Path $contractRoot "jobs") `
	-Filter "matrix-result-metadata.json" -Recurse)
if ($resultMetadata.Count -ne 2) {
	throw "Expected two immutable matrix result metadata files; found $($resultMetadata.Count)."
}
foreach ($metadataFile in $resultMetadata) {
	$metadata = Get-Content -LiteralPath $metadataFile.FullName -Raw |
		ConvertFrom-Json
	if (
		[string]$metadata.schema -ne "battle_bog.balance_matrix_result.v1" -or
		[string]$metadata.build_identity_sha256 -ne
			[string]$manifest.build_identity.identity_sha256 -or
		[string]::IsNullOrWhiteSpace([string]$metadata.result_sha256)
	) {
		throw "Matrix result metadata did not bind its result to the current build."
	}
}

$foreignMetadataPath = $resultMetadata[0].FullName
$foreignMetadataOriginal = Get-Content -LiteralPath $foreignMetadataPath -Raw
$foreignMetadata = $foreignMetadataOriginal | ConvertFrom-Json
$foreignMetadata.build_identity_sha256 = "foreign-build"
Write-Utf8NoBomLine -Path $foreignMetadataPath `
	-Line ($foreignMetadata | ConvertTo-Json -Depth 10 -Compress)
$foreignResult = Invoke-Matrix -Parameters $common.Clone()
Write-Utf8NoBomLine -Path $foreignMetadataPath `
	-Line $foreignMetadataOriginal.TrimEnd()
if (
	$foreignResult.ExitCode -eq 0 -or
	$foreignResult.Output -notmatch "produced by a different build identity"
) {
	throw "Resume accepted result metadata from another build."
}

$buildProbePath = Join-Path $repoRoot "scripts\game\.balance-matrix-build-probe.gd"
if (Test-Path -LiteralPath $buildProbePath) {
	throw "Build-mismatch probe path already exists: '$buildProbePath'."
}
try {
	Write-Utf8NoBomLine -Path $buildProbePath `
		-Line "extends RefCounted # matrix build-identity contract probe"
	$buildMismatch = Invoke-Matrix -Parameters $common.Clone()
	if (
		$buildMismatch.ExitCode -eq 0 -or
		$buildMismatch.Output -notmatch "different build identity"
	) {
		throw "OutputRoot accepted a matrix plan from a changed source build."
	}
} finally {
	Remove-Item -LiteralPath $buildProbePath -Force -ErrorAction SilentlyContinue
}
$postBuildMismatchResume = Invoke-Matrix -Parameters $common.Clone()
if ($postBuildMismatchResume.ExitCode -ne 0) {
	throw "Build-mismatch failure did not release the output-root lock: $($postBuildMismatchResume.Output)"
}

$lockRoot = Join-Path $contractRoot "lock-contention"
New-Item -ItemType Directory -Force -Path $lockRoot | Out-Null
$resolvedLockRoot = (Resolve-Path -LiteralPath $lockRoot).Path
$heldLockPath = Join-Path $resolvedLockRoot ".balance-matrix.lock"
$heldLock = [System.IO.File]::Open(
	$heldLockPath,
	[System.IO.FileMode]::OpenOrCreate,
	[System.IO.FileAccess]::ReadWrite,
	[System.IO.FileShare]::None
)
try {
	$contendedParameters = $common.Clone()
	$contendedParameters.OutputRoot = $lockRoot
	$contended = Invoke-Matrix -Parameters $contendedParameters
	if (
		$contended.ExitCode -eq 0 -or
		$contended.Output -notmatch "already owned by another balance-matrix launcher"
	) {
		throw "A second launcher did not fail clearly on output-root lock contention."
	}
} finally {
	$heldLock.Dispose()
}
$lockRecoveryParameters = $common.Clone()
$lockRecoveryParameters.OutputRoot = $lockRoot
$lockRecovery = Invoke-Matrix -Parameters $lockRecoveryParameters
if ($lockRecovery.ExitCode -ne 0) {
	throw "Output-root lock was not reusable after its owner released it: $($lockRecovery.Output)"
}

$betweenBatchRoot = Join-Path $contractRoot "between-batch-build-change"
$identityCallCount = [ref]0
$baseIdentityJson = $manifest.build_identity | ConvertTo-Json -Depth 10 -Compress
$changingIdentityProvider = {
	param(
		[string]$ProviderRepoRoot,
		[string]$ProviderRunnerPath
	)
	$identityCallCount.Value++
	$identity = $baseIdentityJson | ConvertFrom-Json
	if ($identityCallCount.Value -ge 4) {
		$identity.identity_sha256 = "changed-between-worker-batches"
	}
	return $identity
}.GetNewClosure()
$betweenBatchParameters = $common.Clone()
$betweenBatchParameters.OutputRoot = $betweenBatchRoot
$betweenBatchParameters.WorkerCount = 1
$betweenBatchParameters.BuildIdentityProvider = $changingIdentityProvider
$betweenBatchChange = Invoke-Matrix -Parameters $betweenBatchParameters
if (
	$betweenBatchChange.ExitCode -eq 0 -or
	$betweenBatchChange.Output -notmatch "Build identity changed before worker batch 2"
) {
	throw "Matrix did not fail closed when build identity changed between worker batches."
}
if (
	(Test-Path -LiteralPath (Join-Path $betweenBatchRoot "results.jsonl")) -or
	(Test-Path -LiteralPath (Join-Path $betweenBatchRoot "summary.json"))
) {
	throw "Matrix merged or summarized cross-build results after a between-batch identity change."
}
$betweenBatchResults = @(Get-ChildItem `
	-LiteralPath (Join-Path $betweenBatchRoot "jobs") `
	-Filter "result.jsonl" -Recurse)
if ($betweenBatchResults.Count -ne 1) {
	throw "Between-batch contract expected exactly one completed first-batch result."
}
$betweenBatchRecoveryParameters = $common.Clone()
$betweenBatchRecoveryParameters.OutputRoot = $betweenBatchRoot
$betweenBatchRecoveryParameters.WorkerCount = 1
$betweenBatchRecovery = Invoke-Matrix `
	-Parameters $betweenBatchRecoveryParameters
if ($betweenBatchRecovery.ExitCode -ne 0) {
	throw "Between-batch build abort did not release its lock or resume safely: $($betweenBatchRecovery.Output)"
}

$invalidRoot = Join-Path $contractRoot "invalid"
$invalid = Invoke-Matrix -Parameters @{
	ValidateOnly = $true
	SquadIds = @("S8")
	Seeds = @(7L)
	OutputRoot = $invalidRoot
}
if ($invalid.ExitCode -eq 0 -or $invalid.Output -notmatch "Unknown squad id 'S8'") {
	throw "Unknown squad validation did not fail clearly."
}

$cardinalityRoot = Join-Path $contractRoot "cardinality"
Assert-BlockedCardinality -Stage "StageB5" -ExpectedCount 14 `
	-ExpectedStageSummary "StageB5=14@300s" `
	-OutputRoot (Join-Path $cardinalityRoot "stage-b5")
Assert-BlockedCardinality -Stage "StageB15" -ExpectedCount 14 `
	-ExpectedStageSummary "StageB15=14@900s" `
	-OutputRoot (Join-Path $cardinalityRoot "stage-b15")
Assert-BlockedCardinality -Stage "StageCMain" -ExpectedCount 336 `
	-ExpectedStageSummary "StageCMain=336@900s" `
	-OutputRoot (Join-Path $cardinalityRoot "stage-c-main")
Assert-BlockedCardinality -Stage "StageCExtended" -ExpectedCount 112 `
	-ExpectedStageSummary "StageCExtended=112@1500s" `
	-OutputRoot (Join-Path $cardinalityRoot "stage-c-extended")
Assert-BlockedCardinality -Stage "Full" -ExpectedCount 476 `
	-ExpectedStageSummary "StageB5=14@300s, StageB15=14@900s, StageCMain=336@900s, StageCExtended=112@1500s" `
	-OutputRoot (Join-Path $cardinalityRoot "full")

$defaultFullBlock = Invoke-Matrix -Parameters @{
	ValidateOnly = $true
	Stage = "Full"
	OutputRoot = (Join-Path $cardinalityRoot "full-default-guard")
}
if (
	$defaultFullBlock.ExitCode -eq 0 -or
	$defaultFullBlock.Output -notmatch [regex]::Escape(
		"Plan contains 476 jobs (StageB5=14@300s, StageB15=14@900s, StageCMain=336@900s, StageCExtended=112@1500s), exceeding MaxJobs=32"
	)
) {
	throw "Default MaxJobs safety gate did not block the full 476-job plan."
}

$legacyAll = Invoke-Matrix -Parameters @{
	ValidateOnly = $true
	PairingMode = "All"
	SquadIds = @("S1", "S2")
	Seeds = @(7L)
	MaxJobs = 3
	OutputRoot = (Join-Path $cardinalityRoot "legacy-all")
}
if (
	$legacyAll.ExitCode -eq 0 -or
	$legacyAll.Output -notmatch [regex]::Escape("Plan contains 4 jobs (Legacy=4@180s)")
) {
	throw "Legacy PairingMode=All compatibility cardinality changed."
}

$mixedMode = Invoke-Matrix -Parameters @{
	ValidateOnly = $true
	Stage = "StageB5"
	PairingMode = "Mirror"
	OutputRoot = (Join-Path $cardinalityRoot "mixed-mode")
}
if (
	$mixedMode.ExitCode -eq 0 -or
	$mixedMode.Output -notmatch "Named stage 'StageB5' owns pairing"
) {
	throw "Named-stage and legacy-pairing ambiguity was not rejected."
}

$stageB5Root = Join-Path $contractRoot "named-stage-b5"
$stageB5Parameters = @{
	ValidateOnly = $true
	Stage = "StageB5"
	WorkerCount = 8
	MaxJobs = 14
	OutputRoot = $stageB5Root
}
$stageB5 = Invoke-Matrix -Parameters $stageB5Parameters.Clone()
if ($stageB5.ExitCode -ne 0) {
	throw "StageB5 validation plan failed: $($stageB5.Output)"
}
$stageB5ManifestPath = Join-Path $stageB5Root "manifest.json"
$stageB5SummaryPath = Join-Path $stageB5Root "summary.json"
$stageB5Manifest = Get-Content -LiteralPath $stageB5ManifestPath -Raw |
	ConvertFrom-Json
$stageB5Summary = Get-Content -LiteralPath $stageB5SummaryPath -Raw |
	ConvertFrom-Json
if ([string]$stageB5Manifest.schema -ne "battle_bog.balance_matrix.v3") {
	throw "Named-stage manifest did not use the v3 matrix schema."
}
if ([string]$stageB5Manifest.contract.stage -ne "StageB5") {
	throw "Named-stage manifest did not retain the selected stage."
}
$stageB5Jobs = @($stageB5Manifest.contract.jobs)
if ($stageB5Jobs.Count -ne 14) {
	throw "StageB5 manifest contained $($stageB5Jobs.Count) jobs instead of 14."
}
$stageB5Identities = New-Object System.Collections.Generic.HashSet[string]
foreach ($job in $stageB5Jobs) {
	if (
		[string]$job.stage -ne "StageB5" -or
		[double]$job.max_simulated_sec -ne 300.0 -or
		[string]$job.blue_squad -ne [string]$job.red_squad
	) {
		throw "StageB5 manifest contains an invalid stage, duration, or pairing."
	}
	$identity = "{0}|{1}|{2}|{3}|{4}" -f $job.stage, $job.blue_squad,
		$job.red_squad, $job.seed, $job.max_simulated_sec
	if (-not $stageB5Identities.Add($identity)) {
		throw "StageB5 manifest contains duplicate identity '$identity'."
	}
}
if (
	[int]$stageB5Summary.total_jobs -ne 14 -or
	[int]$stageB5Summary.executed_jobs -ne 14 -or
	[string]$stageB5Summary.stage -ne "StageB5"
) {
	throw "StageB5 execution summary did not report the canonical 14 jobs."
}
$stageB5ResultFiles = @(Get-ChildItem -LiteralPath (Join-Path $stageB5Root "jobs") `
	-Filter "result.jsonl" -Recurse)
if ($stageB5ResultFiles.Count -ne 14) {
	throw "StageB5 did not produce 14 isolated validation results."
}
$stageB5RunDirectories = @($stageB5ResultFiles | ForEach-Object {
	$_.Directory.Name
})
if (@($stageB5RunDirectories | Select-Object -Unique).Count -ne 14) {
	throw "StageB5 job run identities collided."
}
foreach ($runDirectory in $stageB5RunDirectories) {
	if ($runDirectory -notmatch "-stageb5-" -or $runDirectory -notmatch "-sec-300$") {
		throw "Run identity '$runDirectory' does not include stage and duration."
	}
}

$stageB5Resume = Invoke-Matrix -Parameters $stageB5Parameters.Clone()
if ($stageB5Resume.ExitCode -ne 0) {
	throw "StageB5 no-op resume failed: $($stageB5Resume.Output)"
}
$resumedStageB5Summary = Get-Content -LiteralPath $stageB5SummaryPath -Raw |
	ConvertFrom-Json
if (
	[int]$resumedStageB5Summary.executed_jobs -ne 0 -or
	[int]$resumedStageB5Summary.resumed_jobs -ne 14
) {
	throw "StageB5 resume did not report zero executed and 14 resumed jobs."
}

$tamperedResultPath = $stageB5ResultFiles[0].FullName
$originalResultLine = Get-Content -LiteralPath $tamperedResultPath -Raw
$tamperedRecord = $originalResultLine | ConvertFrom-Json
$tamperedRecord.requested.max_simulated_sec = 301.0
Write-Utf8NoBomLine -Path $tamperedResultPath `
	-Line ($tamperedRecord | ConvertTo-Json -Depth 20 -Compress)
$durationMismatch = Invoke-Matrix -Parameters $stageB5Parameters.Clone()
Write-Utf8NoBomLine -Path $tamperedResultPath -Line $originalResultLine.TrimEnd()
if (
	$durationMismatch.ExitCode -eq 0 -or
	$durationMismatch.Output -notmatch "different simulated duration"
) {
	throw "Resume accepted a completed result with the wrong stage duration."
}

$runtimeRoot = Join-Path $contractRoot "runtime-rules"
$runtimeParameters = @{
	Smoke = $true
	PairingMode = "Mirror"
	SquadIds = @("S1")
	Seeds = @(7L)
	WorkerCount = 1
	MaxJobs = 1
	OutputRoot = $runtimeRoot
}
$runtimeRun = Invoke-Matrix -Parameters $runtimeParameters.Clone()
if ($runtimeRun.ExitCode -ne 0) {
	throw "Runtime rules-fingerprint smoke failed: $($runtimeRun.Output)"
}
$runtimeManifest = Get-Content -LiteralPath `
	(Join-Path $runtimeRoot "manifest.json") -Raw | ConvertFrom-Json
$expectedRuntimeFingerprint = [string]$runtimeManifest.expected_rules.fingerprint
if ([string]::IsNullOrWhiteSpace($expectedRuntimeFingerprint)) {
	throw "Runtime matrix did not pin the rules fingerprint from its result record."
}
$runtimeResultPath = @(
	Get-ChildItem -LiteralPath (Join-Path $runtimeRoot "jobs") `
		-Filter "result.jsonl" -Recurse
)[0].FullName
$runtimeOriginalBytes = [System.IO.File]::ReadAllBytes($runtimeResultPath)
$runtimeOriginalLine = Get-Content -LiteralPath $runtimeResultPath -Raw
$runtimeRecord = $runtimeOriginalLine | ConvertFrom-Json
if ([string]$runtimeRecord.match.rules_fingerprint -ne $expectedRuntimeFingerprint) {
	throw "Runtime result and manifest rules fingerprints disagree."
}
$runtimeRecord.match.rules_fingerprint = "tampered-rules-fingerprint"
Write-Utf8NoBomLine -Path $runtimeResultPath `
	-Line ($runtimeRecord | ConvertTo-Json -Depth 30 -Compress)
$rulesMismatch = Invoke-Matrix -Parameters $runtimeParameters.Clone()
[System.IO.File]::WriteAllBytes($runtimeResultPath, $runtimeOriginalBytes)
if (
	$rulesMismatch.ExitCode -eq 0 -or
	$rulesMismatch.Output -notmatch "runtime rules fingerprint"
) {
	throw "Resume accepted a result carrying a different runtime rules fingerprint."
}
$runtimeResume = Invoke-Matrix -Parameters $runtimeParameters.Clone()
if ($runtimeResume.ExitCode -ne 0) {
	throw "Runtime result did not resume after restoring its exact record: $($runtimeResume.Output)"
}

Write-Host "Battle Bog balance matrix contract PASS"
Write-Host "Named stages: StageB5=14, StageB15=14, StageCMain=336, StageCExtended=112, Full=476"
Write-Host "Validated: build-safe resume, exclusive ownership, rules identity, deterministic plans, durations, unique identities, merge, safety gates, legacy compatibility"
