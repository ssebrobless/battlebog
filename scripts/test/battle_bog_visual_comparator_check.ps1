[CmdletBinding()]
param(
	[string]$Godot = "C:\Godot\Godot_v4.6-stable_win64_console.exe",
	[string]$AttemptToken = "",
	[int]$CaptureTimeoutSec = 300,
	[switch]$SkipReplacement
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3.0

$stopwatch = [Diagnostics.Stopwatch]::StartNew()
$completedChecks = New-Object Collections.Generic.List[string]

function Get-FullPath {
	param([string]$Path)
	return [IO.Path]::GetFullPath($Path)
}

function Assert-UnderRoot {
	param(
		[string]$Path,
		[string]$Root,
		[string]$Label,
		[switch]$AllowRoot
	)
	$fullPath = Get-FullPath $Path
	$fullRoot = (Get-FullPath $Root).TrimEnd("\", "/")
	if ($AllowRoot -and
		$fullPath.Equals($fullRoot, [StringComparison]::OrdinalIgnoreCase)) {
		return $fullPath
	}
	$prefix = $fullRoot + [IO.Path]::DirectorySeparatorChar
	if (-not $fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
		throw "$Label resolves outside '$fullRoot': $fullPath"
	}
	return $fullPath
}

function Assert-NoReparsePoints {
	param(
		[string]$Path,
		[string]$StopRoot,
		[string]$Label
	)
	$fullPath = Assert-UnderRoot $Path $StopRoot $Label -AllowRoot
	$fullStop = (Get-FullPath $StopRoot).TrimEnd("\", "/")
	$current = $fullPath
	while ($true) {
		if (Test-Path -LiteralPath $current) {
			$item = Get-Item -LiteralPath $current -Force
			if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
				throw "$Label traverses a reparse point: $current"
			}
		}
		if ($current.Equals($fullStop, [StringComparison]::OrdinalIgnoreCase)) {
			return
		}
		$parent = Split-Path -Parent $current
		if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) {
			throw "$Label escaped '$fullStop' while checking reparse points."
		}
		$current = $parent
	}
}

function Assert-Parses {
	param([string]$Path)
	$tokens = $null
	$errors = $null
	[Management.Automation.Language.Parser]::ParseFile(
		$Path,
		[ref]$tokens,
		[ref]$errors
	) | Out-Null
	if ($errors.Count -gt 0) {
		throw "$Path has PowerShell parser errors: $($errors -join ' | ')"
	}
}

function Read-Json {
	param([string]$Path)
	return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-Json {
	param(
		[string]$Path,
		[object]$Value
	)
	$Value | ConvertTo-Json -Depth 100 |
		Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-Sha256 {
	param([string]$Path)
	return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-TreeSnapshot {
	param([string]$Root)
	$resolved = (Resolve-Path -LiteralPath $Root).Path
	$entries = @(
		Get-ChildItem -LiteralPath $resolved -File -Recurse |
			Sort-Object FullName |
			ForEach-Object {
				$relative = $_.FullName.Substring($resolved.Length).
					TrimStart("\", "/").Replace("\", "/")
				"$relative|$(Get-Sha256 $_.FullName)"
			}
	)
	return $entries -join "`n"
}

function Get-CaptureContentFingerprint {
	param([string]$RunRoot)
	$lines = @(
		Get-ChildItem -LiteralPath $RunRoot -File |
			Where-Object {
				$_.Extension -in @(".png", ".json") -and
				$_.Name -ne "run_metadata.json"
			} |
			Sort-Object Name |
			ForEach-Object { "$($_.Name)|$(Get-Sha256 $_.FullName)" }
	)
	$bytes = [Text.Encoding]::UTF8.GetBytes($lines -join "`n")
	$sha = [Security.Cryptography.SHA256]::Create()
	try {
		return ([BitConverter]::ToString($sha.ComputeHash($bytes))).
			Replace("-", "").ToLowerInvariant()
	} finally {
		$sha.Dispose()
	}
}

function Invoke-ExpectedFailure {
	param(
		[scriptblock]$Command,
		[string]$Label,
		[string]$Pattern = ".+"
	)
	$output = ""
	$failed = $false
	try {
		$output = (& $Command 2>&1 | ForEach-Object { $_.ToString() }) -join "`n"
	} catch {
		$failed = $true
		$output = "$output`n$($_.Exception.Message)".Trim()
	}
	if (-not $failed) {
		throw "$Label unexpectedly succeeded."
	}
	if ($output -notmatch $Pattern) {
		throw "$Label failed for the wrong reason. Output: $output"
	}
	$completedChecks.Add($Label)
	Write-Host "REFUSAL PASS: $Label"
}

function Invoke-Git {
	param(
		[string]$WorkingTree,
		[string[]]$Arguments,
		[string]$Label
	)
	$previousPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		$output = @(& git -C $WorkingTree @Arguments 2>&1)
		$exitCode = $LASTEXITCODE
	} finally {
		$ErrorActionPreference = $previousPreference
	}
	if ($exitCode -ne 0) {
		throw "$Label failed: $($output -join ' | ')"
	}
	return @($output)
}

function Assert-Clean {
	param([string]$WorkingTree)
	$status = @(Invoke-Git $WorkingTree @(
		"status", "--porcelain=v1", "--untracked-files=all"
	) "Git status")
	if ($status.Count -ne 0) {
		throw "Disposable worktree is not clean: $($status -join ' | ')"
	}
}

function Copy-Capture {
	param(
		[string]$VisualRoot,
		[string]$SourceId,
		[string]$DestinationId
	)
	$source = Assert-UnderRoot (Join-Path $VisualRoot $SourceId) $VisualRoot `
		"Capture clone source"
	$destination = Assert-UnderRoot (Join-Path $VisualRoot $DestinationId) $VisualRoot `
		"Capture clone destination"
	Assert-NoReparsePoints $source $VisualRoot "Capture clone source"
	if (Test-Path -LiteralPath $destination) {
		throw "Capture clone destination already exists: $destination"
	}
	Copy-Item -LiteralPath $source -Destination $destination -Recurse
	$metadataPath = Join-Path $destination "run_metadata.json"
	$metadata = Read-Json $metadataPath
	$metadata.run_id = $DestinationId
	Write-Json $metadataPath $metadata
	return $destination
}

function Get-FirstSemanticPath {
	param(
		[string]$RunRoot,
		[string]$VisualRoot
	)
	Assert-UnderRoot $RunRoot $VisualRoot "Mutated capture" | Out-Null
	$semantic = Get-ChildItem -LiteralPath $RunRoot -Filter "*.json" -File |
		Where-Object { $_.Name -ne "run_metadata.json" } |
		Sort-Object Name |
		Select-Object -First 1
	if ($null -eq $semantic) {
		throw "Capture has no semantic frame: $RunRoot"
	}
	Assert-UnderRoot $semantic.FullName $VisualRoot "Semantic mutation target" | Out-Null
	return $semantic.FullName
}

function Invoke-Capture {
	param(
		[string]$Runner,
		[string]$GodotPath,
		[string]$RunId,
		[int]$TimeoutSec
	)
	Write-Host "CAPTURE: $RunId"
	& $Runner -Godot $GodotPath -Capture -Scenario "neutral_smoke" `
		-RunId $RunId -CameraPreset "PvAI" -CaptureMode "Diagnostic" `
		-TimeoutSec $TimeoutSec
	if ($LASTEXITCODE -ne 0) {
		throw "Capture '$RunId' failed with exit code $LASTEXITCODE."
	}
}

function Invoke-Prepare {
	param(
		[string]$PromoteScript,
		[string[]]$RunIds,
		[string]$Token
	)
	& $PromoteScript -Prepare -RunId $RunIds -AttemptToken $Token
	if ($LASTEXITCODE -ne 0) {
		throw "Evidence preparation '$Token' failed with exit code $LASTEXITCODE."
	}
}

function New-Approval {
	param(
		[string]$Path,
		[string]$SourceManifestPath,
		[string]$SelectedRunId,
		[string]$SourceGitSha,
		[bool]$Replace,
		[string]$ExpectedOldHash = ""
	)
	$approval = [ordered]@{
		token = "HUMAN_APPROVED"
		source_manifest_sha256 = Get-Sha256 $SourceManifestPath
		selected_primary_run_id = $SelectedRunId
		source_git_sha = $SourceGitSha
		reviewer = "battle-bog-r2b-contract-harness"
		reason = "SYNTHETIC CONTRACT TEST ONLY - disposable worktree evidence"
		replace = $Replace
		expected_old_manifest_sha256 = if ($Replace) { $ExpectedOldHash } else { $null }
	}
	Write-Json $Path $approval
}

function Commit-DecisionOnly {
	param(
		[string]$WorkingTree,
		[string]$Label
	)
	$decisionPath = Join-Path $WorkingTree "docs\BATTLE_BOG_DECISIONS.md"
	Add-Content -LiteralPath $decisionPath -Encoding UTF8 -Value @"

### R2B synthetic contract decision: $Label

- Scope: disposable contract-test worktree only.
- Evidence: synthetic HUMAN_APPROVED packet generated by the executable harness.
- Production authority: none; this entry must never be promoted to the main branch.
"@
	Invoke-Git $WorkingTree @("add", "--", "docs/BATTLE_BOG_DECISIONS.md") `
		"Stage decision-only change" | Out-Null
	$staged = @(Invoke-Git $WorkingTree @("diff", "--cached", "--name-only") `
		"Inspect staged decision")
	if ($staged.Count -ne 1 -or $staged[0] -ne "docs/BATTLE_BOG_DECISIONS.md") {
		throw "Decision commit staged unexpected files: $($staged -join ', ')"
	}
	Invoke-Git $WorkingTree @(
		"-c", "user.name=Battle Bog Contract Harness",
		"-c", "user.email=battle-bog-contract@example.invalid",
		"commit", "-m", "R2B contract: record synthetic $Label decision"
	) "Commit decision-only change" | Out-Null
	Assert-Clean $WorkingTree
}

function Commit-BaselineFixture {
	param(
		[string]$WorkingTree,
		[string]$BaselineRelativePath
	)
	Invoke-Git $WorkingTree @("add", "--", $BaselineRelativePath) `
		"Stage disposable baseline" | Out-Null
	$staged = @(Invoke-Git $WorkingTree @("diff", "--cached", "--name-only") `
		"Inspect staged baseline")
	$unexpected = @($staged | Where-Object {
		-not $_.StartsWith("$($BaselineRelativePath.Replace('\', '/'))/",
			[StringComparison]::Ordinal)
	})
	if ($staged.Count -eq 0 -or $unexpected.Count -gt 0) {
		throw "Baseline fixture commit staged unexpected files: $($staged -join ', ')"
	}
	Invoke-Git $WorkingTree @(
		"-c", "user.name=Battle Bog Contract Harness",
		"-c", "user.email=battle-bog-contract@example.invalid",
		"commit", "-m", "R2B contract: commit disposable baseline fixture"
	) "Commit disposable baseline" | Out-Null
	Assert-Clean $WorkingTree
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..\..")).Path
$executionRoot = Get-FullPath (Join-Path $repoRoot "artifacts\execution\r2b")
if (-not (Test-Path -LiteralPath $executionRoot -PathType Container)) {
	New-Item -ItemType Directory -Path $executionRoot -Force | Out-Null
}
Assert-UnderRoot $executionRoot $repoRoot "R2B execution root"
Assert-NoReparsePoints $executionRoot $repoRoot "R2B execution root"

if ([string]::IsNullOrWhiteSpace($AttemptToken)) {
	$AttemptToken = "contract-" +
		(Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmss") + "-" +
		[Guid]::NewGuid().ToString("N").Substring(0, 8)
}
if ($AttemptToken -notmatch "^[A-Za-z0-9][A-Za-z0-9._-]{0,47}$") {
	throw "AttemptToken must be a closed ASCII identifier of at most 48 characters."
}
if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
	throw "Godot executable is missing: $Godot"
}
$godotPath = (Resolve-Path -LiteralPath $Godot).Path
$godotEvidenceCommand = $godotPath

$attemptRoot = Assert-UnderRoot (Join-Path $executionRoot $AttemptToken) `
	$executionRoot "Contract attempt"
if (Test-Path -LiteralPath $attemptRoot) {
	throw "Contract attempt already exists: $attemptRoot"
}
New-Item -ItemType Directory -Path $attemptRoot | Out-Null
$worktreeRoot = Assert-UnderRoot (Join-Path $attemptRoot "worktree") `
	$attemptRoot "Disposable worktree"

$sourceHeadOutput = @(Invoke-Git $repoRoot @("rev-parse", "HEAD") `
	"Resolve committed source HEAD")
$sourceHead = ([string]$sourceHeadOutput[0]).Trim()
if ($sourceHead -notmatch "^[a-f0-9]{40}$") {
	throw "Could not resolve the committed source HEAD."
}

Write-Host "Creating disposable worktree at $worktreeRoot"
Invoke-Git $repoRoot @("worktree", "add", "--detach", $worktreeRoot, $sourceHead) `
	"Create disposable worktree" | Out-Null
Assert-UnderRoot $worktreeRoot $attemptRoot "Disposable worktree"
Assert-NoReparsePoints $worktreeRoot $attemptRoot "Disposable worktree"

$worktreeScripts = Join-Path $worktreeRoot "scripts\test"
$runnerPath = Join-Path $worktreeScripts "run_visual_regression.ps1"
$promotePath = Join-Path $worktreeScripts "promote_visual_baseline.ps1"
$comparePath = Join-Path $worktreeScripts "compare_visual_regression.ps1"
$metricsPath = Join-Path $worktreeScripts "visual\image_metrics.gd"
$visualRoot = Join-Path $worktreeRoot "artifacts\visual-regression"
$worktreeExecutionRoot = Join-Path $worktreeRoot "artifacts\execution\r2b"
$baselineRelative = "tests\visual\baselines\windows-x86_64-godot4.6-gl_compatibility"
$baselineRoot = Join-Path $worktreeRoot $baselineRelative

foreach ($path in @($runnerPath, $promotePath, $comparePath)) {
	Assert-Parses $path
}

$warmupStdout = Join-Path $attemptRoot "godot-editor-warmup.stdout.log"
$warmupStderr = Join-Path $attemptRoot "godot-editor-warmup.stderr.log"
Write-Host "Warming fresh Godot project metadata and global class cache."
$warmup = Start-Process -FilePath $godotPath -ArgumentList @(
	"--headless",
	"--editor",
	"--path", $worktreeRoot,
	"--quit"
) -Wait -PassThru -WindowStyle Hidden `
	-RedirectStandardOutput $warmupStdout `
	-RedirectStandardError $warmupStderr
$classCache = Join-Path $worktreeRoot ".godot\global_script_class_cache.cfg"
if ($warmup.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $classCache -PathType Leaf)) {
	$warmupErrors = if (Test-Path -LiteralPath $warmupStderr) {
		Get-Content -LiteralPath $warmupStderr -Raw
	} else {
		""
	}
	throw "Fresh-worktree Godot warm-up failed with exit code $($warmup.ExitCode): $warmupErrors"
}
$completedChecks.Add("Fresh-worktree Godot class-cache warm-up")

$metricsSource = Get-Content -LiteralPath $metricsPath -Raw
foreach ($assertion in @(
	'or bool(mae["passes"]["mae"])',
	'or not bool(mae["passes"]["roi_ssim"])',
	'or not bool(mae["passes"]["changed_pixels"])',
	'or bool(changed["passes"]["changed_pixels"])',
	'or bool(ssim["passes"]["roi_ssim"])'
)) {
	if (-not $metricsSource.Contains($assertion)) {
		throw "Metric self-test is missing exclusive assertion: $assertion"
	}
}
$metricOutput = (& $godotPath --headless --path $worktreeRoot `
	--script $metricsPath -- --self-test 2>&1 |
	ForEach-Object { $_.ToString() }) -join "`n"
if ($LASTEXITCODE -ne 0 -or $metricOutput -notmatch "BB_IMAGE_METRICS_SELF_TEST_OK") {
	throw "Image metric exclusive-failure self-test failed: $metricOutput"
}
$completedChecks.Add("Exclusive MAE/SSIM/changed-pixel metric failures")

$idStem = "ct" + [Guid]::NewGuid().ToString("N").Substring(0, 8)
$captureIds = @("$idStem-a", "$idStem-b", "$idStem-c")
foreach ($captureId in $captureIds) {
	Invoke-Capture $runnerPath $godotEvidenceCommand $captureId $CaptureTimeoutSec
}
Assert-Clean $worktreeRoot
$captureFingerprints = @($captureIds | ForEach-Object {
	Get-CaptureContentFingerprint (Join-Path $visualRoot $_)
})
$usedEvidenceReplicas = @($captureFingerprints | Select-Object -Unique).Count -ne 1
$evidenceCaptureIds = @($captureIds)
if ($usedEvidenceReplicas) {
	Invoke-ExpectedFailure {
		& $promotePath -Prepare -RunId $captureIds `
			-AttemptToken "$idStem-independent-determinism"
	} "Independent captures expose raster nondeterminism" "byte-identical"
	$replicaOne = "$idStem-evidence-r1"
	$replicaTwo = "$idStem-evidence-r2"
	Copy-Capture $visualRoot $captureIds[0] $replicaOne | Out-Null
	Copy-Capture $visualRoot $captureIds[0] $replicaTwo | Out-Null
	$evidenceCaptureIds = @($captureIds[0], $replicaOne, $replicaTwo)
}

Invoke-ExpectedFailure {
	& $promotePath -Prepare `
		-RunId @($captureIds[0], $captureIds[0], $captureIds[2]) `
		-AttemptToken "$idStem-duplicate"
} "Duplicate capture IDs" "exactly three distinct"

Invoke-ExpectedFailure {
	& $promotePath -Prepare `
		-RunId @($captureIds[0], $captureIds[1], "$idStem-missing") `
		-AttemptToken "$idStem-missing-attempt"
} "Missing capture"

$dirtyId = "$idStem-dirty"
$dirtyRoot = Copy-Capture $visualRoot $captureIds[2] $dirtyId
$dirtyMetadataPath = Join-Path $dirtyRoot "run_metadata.json"
$dirtyMetadata = Read-Json $dirtyMetadataPath
$dirtyMetadata.git.dirty = $true
Write-Json $dirtyMetadataPath $dirtyMetadata
Invoke-ExpectedFailure {
	& $promotePath -Prepare `
		-RunId @($captureIds[0], $captureIds[1], $dirtyId) `
		-AttemptToken "$idStem-dirty-attempt"
} "Dirty capture" "dirty"

$failedId = "$idStem-failed"
$failedRoot = Copy-Capture $visualRoot $captureIds[2] $failedId
$failedMetadataPath = Join-Path $failedRoot "run_metadata.json"
$failedMetadata = Read-Json $failedMetadataPath
$failedMetadata.status = "failed"
Write-Json $failedMetadataPath $failedMetadata
Invoke-ExpectedFailure {
	& $promotePath -Prepare `
		-RunId @($captureIds[0], $captureIds[1], $failedId) `
		-AttemptToken "$idStem-failed-attempt"
} "Failed capture" "passed capture"

$mixedId = "$idStem-mixed"
$mixedRoot = Copy-Capture $visualRoot $captureIds[2] $mixedId
$mixedMetadataPath = Join-Path $mixedRoot "run_metadata.json"
$mixedMetadata = Read-Json $mixedMetadataPath
$mixedMetadata.host.os = "$($mixedMetadata.host.os)-synthetic-mismatch"
Write-Json $mixedMetadataPath $mixedMetadata
Invoke-ExpectedFailure {
	& $promotePath -Prepare `
		-RunId @($captureIds[0], $captureIds[1], $mixedId) `
		-AttemptToken "$idStem-mixed-attempt"
} "Mixed provenance"

$nonidenticalId = "$idStem-nonidentical"
$nonidenticalRoot = Copy-Capture $visualRoot $captureIds[2] $nonidenticalId
$nonidenticalSemanticPath = Get-FirstSemanticPath $nonidenticalRoot $visualRoot
$nonidenticalSemantic = Read-Json $nonidenticalSemanticPath
$nonidenticalSemantic.seed = [int]$nonidenticalSemantic.seed + 1
Write-Json $nonidenticalSemanticPath $nonidenticalSemantic
Invoke-ExpectedFailure {
	& $promotePath -Prepare `
		-RunId @($captureIds[0], $captureIds[1], $nonidenticalId) `
		-AttemptToken "$idStem-nonidentical-attempt"
} "Nonidentical semantic evidence"

$malformedRoiId = "$idStem-malformed-roi"
$malformedRoiRoot = Copy-Capture $visualRoot $captureIds[2] $malformedRoiId
$malformedRoiPath = Get-FirstSemanticPath $malformedRoiRoot $visualRoot
$malformedRoi = Read-Json $malformedRoiPath
$malformedRoi.critical_regions_px.body[0].width = 0
Write-Json $malformedRoiPath $malformedRoi
Invoke-ExpectedFailure {
	& $promotePath -Prepare `
		-RunId @($captureIds[0], $captureIds[1], $malformedRoiId) `
		-AttemptToken "$idStem-malformed-roi-attempt"
} "Malformed ROI"

$emptyRoiId = "$idStem-empty-roi"
$emptyRoiRoot = Copy-Capture $visualRoot $captureIds[2] $emptyRoiId
$emptyRoiPath = Get-FirstSemanticPath $emptyRoiRoot $visualRoot
$emptyRoi = Read-Json $emptyRoiPath
$emptyRoi.critical_regions_px.body = @()
$emptyRoi.critical_regions_px.contact = @()
$emptyRoi.critical_regions_px.telegraph = @()
Write-Json $emptyRoiPath $emptyRoi
Invoke-ExpectedFailure {
	& $promotePath -Prepare `
		-RunId @($captureIds[0], $captureIds[1], $emptyRoiId) `
		-AttemptToken "$idStem-empty-roi-attempt"
} "Empty ROI"

$missingFrameId = "$idStem-missing-frame"
$missingFrameRoot = Copy-Capture $visualRoot $captureIds[2] $missingFrameId
$missingFramePath = Get-FirstSemanticPath $missingFrameRoot $visualRoot
Assert-UnderRoot $missingFramePath $visualRoot "Missing-frame mutation"
Remove-Item -LiteralPath $missingFramePath
Invoke-ExpectedFailure {
	& $promotePath -Prepare `
		-RunId @($captureIds[0], $captureIds[1], $missingFrameId) `
		-AttemptToken "$idStem-missing-frame-attempt"
} "Missing frame"

$extraFrameId = "$idStem-extra-frame"
$extraFrameRoot = Copy-Capture $visualRoot $captureIds[2] $extraFrameId
$extraSourceSemantic = Get-FirstSemanticPath $extraFrameRoot $visualRoot
$extraSourcePng = [IO.Path]::ChangeExtension($extraSourceSemantic, ".png")
$extraSemantic = Assert-UnderRoot (Join-Path $extraFrameRoot "synthetic.extra.frame.json") `
	$visualRoot "Extra semantic frame"
$extraPng = Assert-UnderRoot (Join-Path $extraFrameRoot "synthetic.extra.frame.png") `
	$visualRoot "Extra PNG frame"
Copy-Item -LiteralPath $extraSourceSemantic -Destination $extraSemantic
Copy-Item -LiteralPath $extraSourcePng -Destination $extraPng
Invoke-ExpectedFailure {
	& $promotePath -Prepare `
		-RunId @($captureIds[0], $captureIds[1], $extraFrameId) `
		-AttemptToken "$idStem-extra-frame-attempt"
} "Extra frame"

$evidenceToken = "$idStem-evidence"
Invoke-Prepare $promotePath $evidenceCaptureIds $evidenceToken
$sourceManifestRelative = "artifacts\execution\r2b\$evidenceToken\source-run-manifest.json"
$sourceManifestPath = Join-Path $worktreeRoot $sourceManifestRelative
$sourceManifest = Read-Json $sourceManifestPath
$approvalRelative = "artifacts\execution\r2b\$evidenceToken\approval.synthetic.json"
$approvalPath = Join-Path $worktreeRoot $approvalRelative
New-Approval $approvalPath $sourceManifestPath $evidenceCaptureIds[0] `
	([string]$sourceManifest.source_git_sha) $false

Commit-DecisionOnly $worktreeRoot "initial promotion"

$badApprovalRelative = "artifacts\execution\r2b\$evidenceToken\approval.bad-binding.json"
$badApprovalPath = Join-Path $worktreeRoot $badApprovalRelative
$badApproval = Read-Json $approvalPath
$badApproval.source_manifest_sha256 = ("0" * 64)
Write-Json $badApprovalPath $badApproval
Invoke-ExpectedFailure {
	& $promotePath -Promote `
		-SourceRunManifest $sourceManifestRelative `
		-ApprovalJson $badApprovalRelative
} "Bad approval binding" "approval|binding"

& $promotePath -Promote -SourceRunManifest $sourceManifestRelative `
	-ApprovalJson $approvalRelative
if ($LASTEXITCODE -ne 0 -or
	-not (Test-Path -LiteralPath (Join-Path $baselineRoot "manifest.json"))) {
	throw "Initial disposable promotion failed."
}
$completedChecks.Add("Initial disposable promotion")

Invoke-ExpectedFailure {
	& $promotePath -Promote `
		-SourceRunManifest $sourceManifestRelative `
		-ApprovalJson $approvalRelative
} "Overwrite without Replace" "already exists|Replace|clean repository"

$wrongOldHash = "f" * 64
if ($wrongOldHash -eq (Get-Sha256 (Join-Path $baselineRoot "manifest.json"))) {
	$wrongOldHash = "e" * 64
}
$wrongReplaceApprovalRelative =
	"artifacts\execution\r2b\$evidenceToken\approval.wrong-old-hash.json"
$wrongReplaceApprovalPath = Join-Path $worktreeRoot $wrongReplaceApprovalRelative
New-Approval $wrongReplaceApprovalPath $sourceManifestPath $evidenceCaptureIds[0] `
	([string]$sourceManifest.source_git_sha) $true $wrongOldHash
Invoke-ExpectedFailure {
	& $promotePath -Promote `
		-SourceRunManifest $sourceManifestRelative `
		-ApprovalJson $wrongReplaceApprovalRelative `
		-Replace -ExpectedOldManifestSha256 $wrongOldHash
} "Wrong old baseline hash" "hash|Replacement|clean repository"

$baselineBefore = Get-TreeSnapshot $baselineRoot
$compareOutputRelative = "artifacts\execution\r2b\$idStem-compare-initial"
& $comparePath -Godot $godotEvidenceCommand -BaselineRoot $baselineRelative `
	-CandidateRoot "artifacts\visual-regression\$($captureIds[0])" `
	-OutputRoot $compareOutputRelative -Scenario "neutral_smoke"
if ($LASTEXITCODE -ne 0) {
	throw "Identical comparator pass failed."
}
$baselineAfter = Get-TreeSnapshot $baselineRoot
if ($baselineBefore -cne $baselineAfter) {
	throw "Comparator changed the baseline tree."
}
$completedChecks.Add("Identical comparator and baseline immutability")

if (-not $SkipReplacement) {
	Commit-BaselineFixture $worktreeRoot $baselineRelative

	$replacementStem = "rt" + [Guid]::NewGuid().ToString("N").Substring(0, 8)
	$replacementIds = @(
		"$replacementStem-a",
		"$replacementStem-b",
		"$replacementStem-c"
	)
	foreach ($captureId in $replacementIds) {
		Invoke-Capture $runnerPath $godotEvidenceCommand $captureId $CaptureTimeoutSec
	}
	Assert-Clean $worktreeRoot
	$replacementFingerprints = @($replacementIds | ForEach-Object {
		Get-CaptureContentFingerprint (Join-Path $visualRoot $_)
	})
	$replacementEvidenceIds = @($replacementIds)
	if (@($replacementFingerprints | Select-Object -Unique).Count -ne 1) {
		Invoke-ExpectedFailure {
			& $promotePath -Prepare -RunId $replacementIds `
				-AttemptToken "$replacementStem-independent-determinism"
		} "Replacement captures expose raster nondeterminism" "byte-identical"
		$replacementReplicaOne = "$replacementStem-evidence-r1"
		$replacementReplicaTwo = "$replacementStem-evidence-r2"
		Copy-Capture $visualRoot $replacementIds[0] $replacementReplicaOne | Out-Null
		Copy-Capture $visualRoot $replacementIds[0] $replacementReplicaTwo | Out-Null
		$replacementEvidenceIds = @(
			$replacementIds[0],
			$replacementReplicaOne,
			$replacementReplicaTwo
		)
		$usedEvidenceReplicas = $true
	}

	$replacementEvidenceToken = "$replacementStem-evidence"
	Invoke-Prepare $promotePath $replacementEvidenceIds $replacementEvidenceToken
	$replacementManifestRelative =
		"artifacts\execution\r2b\$replacementEvidenceToken\source-run-manifest.json"
	$replacementManifestPath = Join-Path $worktreeRoot $replacementManifestRelative
	$replacementManifest = Read-Json $replacementManifestPath
	$replacementApprovalRelative =
		"artifacts\execution\r2b\$replacementEvidenceToken\approval.synthetic.json"
	$replacementApprovalPath = Join-Path $worktreeRoot $replacementApprovalRelative
	$oldManifestHash = Get-Sha256 (Join-Path $baselineRoot "manifest.json")
	New-Approval $replacementApprovalPath $replacementManifestPath `
		$replacementEvidenceIds[0] ([string]$replacementManifest.source_git_sha) `
		$true $oldManifestHash

	Commit-DecisionOnly $worktreeRoot "replacement promotion"
	& $promotePath -Promote `
		-SourceRunManifest $replacementManifestRelative `
		-ApprovalJson $replacementApprovalRelative `
		-Replace -ExpectedOldManifestSha256 $oldManifestHash
	if ($LASTEXITCODE -ne 0) {
		throw "Disposable exact-hash replacement failed."
	}
	$completedChecks.Add("Exact-hash disposable replacement")

	$replacementBaselineBefore = Get-TreeSnapshot $baselineRoot
	$replacementCompareOutput =
		"artifacts\execution\r2b\$replacementStem-compare"
	& $comparePath -Godot $godotEvidenceCommand -BaselineRoot $baselineRelative `
		-CandidateRoot "artifacts\visual-regression\$($replacementEvidenceIds[0])" `
		-OutputRoot $replacementCompareOutput -Scenario "neutral_smoke"
	if ($LASTEXITCODE -ne 0) {
		throw "Post-replacement identical comparator pass failed."
	}
	$replacementBaselineAfter = Get-TreeSnapshot $baselineRoot
	if ($replacementBaselineBefore -cne $replacementBaselineAfter) {
		throw "Comparator changed the replaced baseline tree."
	}
	$completedChecks.Add("Post-replacement comparator immutability")
}

$stopwatch.Stop()
$summary = [ordered]@{
	schema_version = 1
	kind = "battle_bog_r2b_contract_harness_result"
	status = "passed"
	source_head = $sourceHead
	attempt_token = $AttemptToken
	disposable_worktree = $worktreeRoot
	elapsed_seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
	replacement_exercised = (-not $SkipReplacement)
	independent_captures_byte_identical = (-not $usedEvidenceReplicas)
	synthetic_evidence_replicas_used = $usedEvidenceReplicas
	check_count = $completedChecks.Count
	checks = @($completedChecks)
	limitations = @(
		"The synthetic approval has no production authority.",
		"Wall-clock-driven creature rendering makes independent captures byte-different; promotion mechanics use clearly labeled replicas when this occurs.",
		"The disposable worktree is intentionally retained for inspection.",
		"Interruption-at-every-instruction and reparse-point creation are not injected.",
		"Production baseline promotion remains a separate human-gated operation."
	)
}
$summaryPath = Join-Path $attemptRoot "contract-result.json"
Write-Json $summaryPath $summary

Write-Host ""
Write-Host "Battle Bog executable R2B contract harness passed."
Write-Host "Runtime: $($summary.elapsed_seconds) seconds"
Write-Host "Checks:  $($summary.check_count)"
Write-Host "Result:  $summaryPath"
Write-Host "Worktree retained: $worktreeRoot"
Write-Host "LIMITATION: synthetic approval only; no main-checkout baseline was touched."
