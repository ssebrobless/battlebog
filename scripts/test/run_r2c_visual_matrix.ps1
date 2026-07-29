param(
	[string]$AttemptToken = "",
	[string]$Godot = "",
	[int]$Repetitions = 3,
	[int]$TimeoutSec = 300
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3.0

if ($Repetitions -lt 3) {
	throw "R2C requires at least three independent repetitions."
}
if ([string]::IsNullOrWhiteSpace($AttemptToken)) {
	$AttemptToken = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssfffZ")
}
if (
	$AttemptToken.Length -gt 80 -or
	$AttemptToken -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$' -or
	$AttemptToken.Contains("..")
) {
	throw "AttemptToken must be a filename-safe token."
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..\..")).Path
$artifactRoot = Join-Path $repoRoot "artifacts\visual-regression"
$aggregateRoot = Join-Path $artifactRoot "r2c-$AttemptToken"
if (Test-Path -LiteralPath $aggregateRoot) {
	throw "R2C aggregate root already exists: $aggregateRoot"
}
New-Item -ItemType Directory -Path $aggregateRoot | Out-Null

$scenarios = @(
	"alligator_player_camera_attack",
	"alligator_shoreline_transition",
	"alligator_latch_death_roll",
	"alligator_death_respawn",
	"alligator_six_actor_density"
)
$cameras = @("PvAI", "Competitive")
$modes = @("Diagnostic", "Evaluator")
$runner = Join-Path $scriptRoot "run_visual_regression.ps1"
$manifestPath = Join-Path $repoRoot "tests\visual\manifest.json"
$schemaPath = Join-Path $repoRoot "tests\visual\semantic_capture.schema.json"

function Get-ArtifactFingerprint {
	param([string]$Root)
	$records = @(
		Get-ChildItem -LiteralPath $Root -File |
			Where-Object { $_.Name -notin @("run_metadata.json", "harness.log") } |
			Sort-Object Name |
			ForEach-Object {
				[ordered]@{
					name = $_.Name
					sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
					bytes = $_.Length
				}
			}
	)
	if ($records.Count -eq 0) {
		throw "Capture root has no immutable frame artifacts: $Root"
	}
	return @($records)
}

function Get-FingerprintSignature {
	param([object[]]$Records)
	return (@($Records | ForEach-Object { "$($_.name):$($_.sha256):$($_.bytes)" }) -join "`n")
}

$entries = @()
try {
	foreach ($scenario in $scenarios) {
		foreach ($camera in $cameras) {
			foreach ($mode in $modes) {
				$slug = "$scenario-$($camera.ToLowerInvariant())-$($mode.ToLowerInvariant())"
				$replicas = @()
				$referenceSignature = $null
				for ($repetition = 1; $repetition -le $Repetitions; $repetition++) {
					$runId = "r2c-$AttemptToken-$slug-r$repetition"
					$arguments = @{
						Scenario = $scenario
						RunId = $runId
						CameraPreset = $camera
						CaptureMode = $mode
						Capture = $true
						TimeoutSec = $TimeoutSec
					}
					if (-not [string]::IsNullOrWhiteSpace($Godot)) {
						$arguments.Godot = $Godot
					}
					& $runner @arguments
					if ($LASTEXITCODE -ne 0) {
						throw "Capture failed for $scenario/$camera/$mode repetition $repetition."
					}
					$runRoot = Join-Path $artifactRoot $runId
					$artifacts = @(Get-ArtifactFingerprint $runRoot)
					$signature = Get-FingerprintSignature $artifacts
					if ($null -eq $referenceSignature) {
						$referenceSignature = $signature
					} elseif ($signature -cne $referenceSignature) {
						throw "Determinism mismatch for $scenario/$camera/$mode repetition $repetition."
					}
					$replicas += [ordered]@{
						repetition = $repetition
						run_id = $runId
						root = [System.IO.Path]::GetRelativePath($repoRoot, $runRoot).Replace("\", "/")
						artifacts = $artifacts
					}
				}
				$entries += [ordered]@{
					scenario = $scenario
					camera_preset = $camera
					capture_mode = $mode
					comparator_status = "not_applicable"
					deterministic = $true
					replicas = $replicas
				}
			}
		}
	}

	if ($entries.Count -ne 20) {
		throw "R2C matrix must contain exactly 20 canonical entries; got $($entries.Count)."
	}
	$index = [ordered]@{
		schema_version = 1
		attempt_token = $AttemptToken
		created_utc = (Get-Date).ToUniversalTime().ToString("o")
		seed = 307
		canonical_entry_count = $entries.Count
		repetitions_per_entry = $Repetitions
		manifest_sha256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
		semantic_schema_sha256 = (Get-FileHash -LiteralPath $schemaPath -Algorithm SHA256).Hash.ToLowerInvariant()
		git_revision = (& git -C $repoRoot rev-parse HEAD).Trim()
		entries = $entries
	}
	$indexPath = Join-Path $aggregateRoot "index.json"
	$index | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $indexPath -Encoding UTF8
	Write-Host "R2C visual matrix passed: 20 canonical entries x $Repetitions repetitions."
	Write-Host "Aggregate index: $indexPath"
} catch {
	$failurePath = Join-Path $aggregateRoot "failure.txt"
	$_.Exception.ToString() | Set-Content -LiteralPath $failurePath -Encoding UTF8
	throw
}
