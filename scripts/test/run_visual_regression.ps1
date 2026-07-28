param(
	[string]$Godot = "",
	[string]$Manifest = "tests\visual\manifest.json",
	[string]$Scenario = "",
	[string]$RunId = "",
	[int]$TimeoutSec = 60,
	[switch]$Capture,
	[switch]$List,
	[switch]$Validate
)

$ErrorActionPreference = "Stop"

function Resolve-Executable {
	param([string]$Candidate)
	if ([string]::IsNullOrWhiteSpace($Candidate)) {
		return $null
	}
	if (Test-Path -LiteralPath $Candidate) {
		return (Resolve-Path -LiteralPath $Candidate).Path
	}
	$command = Get-Command $Candidate -ErrorAction SilentlyContinue
	if ($null -ne $command) {
		return $command.Source
	}
	return $null
}

function Resolve-Godot {
	param([string]$Requested)

	$resolved = Resolve-Executable $Requested
	if ($null -ne $resolved) {
		return $resolved
	}

	$resolved = Resolve-Executable $env:GODOT4
	if ($null -ne $resolved) {
		return $resolved
	}

	$resolved = Resolve-Executable "godot"
	if ($null -ne $resolved) {
		return $resolved
	}

	$wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
	if (Test-Path -LiteralPath $wingetRoot) {
		$wingetExecutables = Get-ChildItem -LiteralPath $wingetRoot -Directory -ErrorAction SilentlyContinue |
			Where-Object { $_.Name -match "Godot" } |
			ForEach-Object {
				Get-ChildItem -LiteralPath $_.FullName -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue
			} |
			Where-Object { $_.Name -match "godot" -and $_.Name -notmatch "headless|server" }
		$wingetMatch = $wingetExecutables |
			Where-Object { $_.Name -match "console" } |
			Sort-Object LastWriteTime -Descending |
			Select-Object -First 1
		if ($null -eq $wingetMatch) {
			$wingetMatch = $wingetExecutables |
				Sort-Object LastWriteTime -Descending |
				Select-Object -First 1
		}
		if ($null -ne $wingetMatch) {
			return $wingetMatch.FullName
		}
	}

	throw "Could not locate Godot. Set `$env:GODOT4, pass -Godot, install a 'godot' command, or install Godot through WinGet."
}

function Convert-ToGodotPath {
	param(
		[string]$Path,
		[string]$RepoRoot
	)
	$absolute = [System.IO.Path]::GetFullPath($Path)
	$rootPrefix = $RepoRoot.TrimEnd("\", "/") + [System.IO.Path]::DirectorySeparatorChar
	if ($absolute.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
		$relative = $absolute.Substring($rootPrefix.Length).Replace("\", "/")
		return "res://$relative"
	}
	return $absolute.Replace("\", "/")
}

function Invoke-Godot {
	param(
		[string]$GodotPath,
		[string]$RepoRoot,
		[object[]]$Arguments,
		[int]$TimeoutSeconds,
		[string]$LogPath
	)

	$started = Get-Date
	$job = Start-Job -ArgumentList $GodotPath, $RepoRoot, $Arguments -ScriptBlock {
		param(
			[string]$InnerGodotPath,
			[string]$InnerRepoRoot,
			[object[]]$InnerArguments
		)
		Set-Location -LiteralPath $InnerRepoRoot
		$lines = & $InnerGodotPath @InnerArguments 2>&1 |
			ForEach-Object { $_.ToString() }
		[pscustomobject]@{
			ExitCode = $LASTEXITCODE
			Output = ($lines -join [Environment]::NewLine)
		}
	}

	$completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
	$output = ""
	$exitCode = -1
	if ($null -ne $completed) {
		$payload = Receive-Job -Job $job
		if ($null -ne $payload) {
			$exitCode = [int]$payload.ExitCode
			$output = [string]$payload.Output
		}
	} else {
		Stop-Job -Job $job -ErrorAction SilentlyContinue
		$output = "Timed out after $TimeoutSeconds seconds."
	}
	Remove-Job -Job $job -Force -ErrorAction SilentlyContinue

	$elapsedMs = [int]((Get-Date) - $started).TotalMilliseconds
	$header = @(
		"command: `"$GodotPath`" $($Arguments -join ' ')",
		"exit_code: $exitCode",
		"elapsed_ms: $elapsedMs",
		"",
		"--- output ---",
		$output
	)
	Set-Content -LiteralPath $LogPath -Value $header -Encoding UTF8

	return [pscustomobject]@{
		ExitCode = $exitCode
		Output = $output
		ElapsedMs = $elapsedMs
	}
}

function Get-ExactInteger {
	param(
		[object]$Value,
		[string]$Name
	)
	$integerTypes = @(
		[byte], [sbyte], [int16], [uint16],
		[int32], [uint32], [int64], [uint64]
	)
	$isInteger = $false
	foreach ($integerType in $integerTypes) {
		if ($Value -is $integerType) {
			$isInteger = $true
			break
		}
	}
	if (-not $isInteger) {
		throw "$Name must be a JSON integer."
	}
	return [int64]$Value
}

function Test-BenignGodotExitLeak {
	param([string]$Line)
	$trimmed = $Line.Trim()
	$knownPatterns = @(
		"^WARNING:\s+ObjectDB instances leaked at exit \(run with --verbose for details\)\.?$",
		"^ERROR:\s+\d+\s+RID allocations? of type '.+' (?:was|were) leaked at exit\.?$",
		"^ERROR:\s+\d+\s+resources still in use at exit \(run with --verbose for details\)\.?$"
	)
	foreach ($pattern in $knownPatterns) {
		if ($trimmed -match $pattern) {
			return $true
		}
	}
	return $false
}

function Get-ActionableGodotErrors {
	param([string]$Output)
	$errors = @()
	foreach ($line in ($Output -split "\r?\n")) {
		if ($line -notmatch "(?i)(SCRIPT ERROR:|Parse Error:|BB_VISUAL_ERROR:|\bERROR:)") {
			continue
		}
		if (Test-BenignGodotExitLeak $line) {
			continue
		}
		$errors += $line.Trim()
	}
	return $errors
}

function Get-GitProvenance {
	param([string]$RepoRoot)
	$revision = (& git -C $RepoRoot rev-parse HEAD 2>$null | Select-Object -First 1)
	if ([string]::IsNullOrWhiteSpace($revision)) {
		$revision = "unknown"
	} else {
		$revision = $revision.Trim()
	}
	$statusLines = @(& git -C $RepoRoot status --porcelain=v1 --untracked-files=normal 2>$null)
	return [ordered]@{
		revision = $revision
		dirty = ($statusLines.Count -gt 0)
		status = @($statusLines)
	}
}

function Write-RunMetadata {
	param(
		[string]$Path,
		[System.Collections.IDictionary]$Metadata
	)
	$Metadata | ConvertTo-Json -Depth 12 |
		Set-Content -LiteralPath $Path -Encoding UTF8
}

$selectedModes = @($Capture.IsPresent, $List.IsPresent, $Validate.IsPresent) |
	Where-Object { $_ }
if ($selectedModes.Count -gt 1) {
	throw "Choose only one mode: -Capture, -List, or -Validate."
}
$mode = if ($List) { "list" } elseif ($Validate) { "validate" } else { "capture" }

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..\..")).Path
$manifestCandidate = if ([System.IO.Path]::IsPathRooted($Manifest)) {
	$Manifest
} else {
	Join-Path $repoRoot $Manifest
}
if (-not (Test-Path -LiteralPath $manifestCandidate -PathType Leaf)) {
	throw "Visual regression manifest does not exist: $manifestCandidate"
}
$manifestPath = (Resolve-Path -LiteralPath $manifestCandidate).Path
try {
	$manifestData = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
} catch {
	throw "Visual regression manifest is not valid JSON: $manifestPath`n$($_.Exception.Message)"
}
$viewportWidth = Get-ExactInteger $manifestData.viewport.width "viewport.width"
$viewportHeight = Get-ExactInteger $manifestData.viewport.height "viewport.height"
$fixedStepHz = Get-ExactInteger $manifestData.viewport.fixed_step_hz "viewport.fixed_step_hz"
if ($fixedStepHz -le 0) {
	throw "viewport.fixed_step_hz must be positive."
}
$renderer = [string]$manifestData.viewport.renderer

if ([string]::IsNullOrWhiteSpace($RunId)) {
	$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssfffZ")
}
if (
	$RunId.Length -gt 128 -or
	$RunId -in @(".", "..") -or
	$RunId.Contains("..") -or
	$RunId -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$'
) {
	throw "RunId must be 1-128 filename-safe characters, start/end with a letter or number, and may not contain '..'."
}

$artifactRoot = [System.IO.Path]::GetFullPath(
	(Join-Path $repoRoot "artifacts\visual-regression")
)
$runDirectory = [System.IO.Path]::GetFullPath((Join-Path $artifactRoot $RunId))
$artifactPrefix = $artifactRoot.TrimEnd("\", "/") + [System.IO.Path]::DirectorySeparatorChar
if (-not $runDirectory.StartsWith(
	$artifactPrefix,
	[System.StringComparison]::OrdinalIgnoreCase
)) {
	throw "RunId resolves outside the visual-regression artifact root."
}
if (Test-Path -LiteralPath $runDirectory) {
	throw "Visual regression run directory already exists; choose a fresh RunId: $runDirectory"
}
New-Item -ItemType Directory -Path $runDirectory | Out-Null
$logPath = Join-Path $runDirectory "harness.log"
$metadataPath = Join-Path $runDirectory "run_metadata.json"
$godotPath = Resolve-Godot $Godot
$godotManifestPath = Convert-ToGodotPath -Path $manifestPath -RepoRoot $repoRoot
$scenePath = "res://scenes/test/VisualRegressionArena.tscn"

$arguments = @()
if ($mode -ne "capture") {
	$arguments += "--headless"
}
$arguments += @(
	"--path", $repoRoot,
	"--rendering-method", $renderer,
	"--resolution", "$($viewportWidth)x$($viewportHeight)",
	"--fixed-fps", "$fixedStepHz",
	"--scene", $scenePath,
	"--",
	"--bb-visual-mode=$mode",
	"--bb-visual-manifest=$godotManifestPath",
	"--bb-visual-run-id=$RunId",
	"--bb-visual-output=$($runDirectory.Replace('\', '/'))"
)
if (-not [string]::IsNullOrWhiteSpace($Scenario)) {
	$arguments += "--bb-visual-scenario=$Scenario"
}

$godotVersion = (& $godotPath --version 2>&1 | Select-Object -First 1).ToString().Trim()
$runMetadata = [ordered]@{
	schema_version = 1
	run_id = $RunId
	mode = $mode
	scenario_filter = $Scenario
	capture_started_utc = (Get-Date).ToUniversalTime().ToString("o")
	capture_completed_utc = $null
	status = "started"
	git = Get-GitProvenance $repoRoot
	manifest = [ordered]@{
		path = $manifestPath
		sha256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
		fixed_step_hz = $fixedStepHz
	}
	project_settings = [ordered]@{
		path = (Join-Path $repoRoot "project.godot")
		sha256 = (Get-FileHash -LiteralPath (Join-Path $repoRoot "project.godot") -Algorithm SHA256).Hash.ToLowerInvariant()
	}
	godot = [ordered]@{
		executable = $godotPath
		version = $godotVersion
		arguments = @($arguments)
	}
	host = [ordered]@{
		os = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
		os_architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
		process_architecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
		powershell = $PSVersionTable.PSVersion.ToString()
	}
	result = $null
}
Write-RunMetadata -Path $metadataPath -Metadata $runMetadata

Write-Host "Godot:   $godotPath"
Write-Host "Repo:    $repoRoot"
Write-Host "Mode:    $mode"
Write-Host "Manifest: $manifestPath"
Write-Host "Log:     $logPath"

$result = Invoke-Godot `
	-GodotPath $godotPath `
	-RepoRoot $repoRoot `
	-Arguments $arguments `
	-TimeoutSeconds $TimeoutSec `
	-LogPath $logPath

$actionableErrors = @(Get-ActionableGodotErrors $result.Output)
$runMetadata.capture_completed_utc = (Get-Date).ToUniversalTime().ToString("o")
$runMetadata.status = if ($result.ExitCode -eq 0 -and $actionableErrors.Count -eq 0) {
	"godot_succeeded"
} else {
	"failed"
}
$runMetadata.result = [ordered]@{
	exit_code = $result.ExitCode
	elapsed_ms = $result.ElapsedMs
	actionable_errors = @($actionableErrors)
}
Write-RunMetadata -Path $metadataPath -Metadata $runMetadata

if (-not [string]::IsNullOrWhiteSpace($result.Output)) {
	Write-Host ""
	Write-Host $result.Output
}
if ($result.ExitCode -ne 0) {
	throw "Visual regression $mode failed with exit code $($result.ExitCode). See $logPath"
}
if ($actionableErrors.Count -gt 0) {
	throw "Visual regression $mode reported Godot errors: $($actionableErrors -join ' | '). See $logPath"
}

if ($mode -eq "list") {
	if ($result.Output -notmatch "BB_VISUAL_LIST_COMPLETE") {
		throw "List mode exited without its completion marker. See $logPath"
	}
	$runMetadata.status = "passed"
	Write-RunMetadata -Path $metadataPath -Metadata $runMetadata
	Write-Host ""
	Write-Host "Visual regression scenarios listed successfully."
	exit 0
}

if ($mode -eq "validate") {
	if ($result.Output -notmatch "BB_VISUAL_VALIDATE_OK") {
		throw "Validate mode exited without its completion marker. See $logPath"
	}
	$runMetadata.status = "passed"
	Write-RunMetadata -Path $metadataPath -Metadata $runMetadata
	Write-Host ""
	Write-Host "Visual regression manifest and scenario contract validated successfully."
	exit 0
}

$scenarios = @($manifestData.scenarios)
if (-not [string]::IsNullOrWhiteSpace($Scenario)) {
	$scenarios = @($scenarios | Where-Object { $_.id -eq $Scenario })
}
if ($scenarios.Count -eq 0) {
	throw "No manifest scenario matched '$Scenario'."
}

$verifiedPairs = 0
foreach ($scenarioEntry in $scenarios) {
	foreach ($frameValue in @($scenarioEntry.capture_frames)) {
		$frameIndex = [int]$frameValue
		$basename = "{0}.frame_{1:D6}" -f $scenarioEntry.id, $frameIndex
		$pngPath = Join-Path $runDirectory "$basename.png"
		$statePath = Join-Path $runDirectory "$basename.json"
		if (-not (Test-Path -LiteralPath $pngPath -PathType Leaf)) {
			throw "Expected screenshot is missing: $pngPath"
		}
		if ((Get-Item -LiteralPath $pngPath).Length -le 0) {
			throw "Expected screenshot is empty: $pngPath"
		}
		if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
			throw "Expected state JSON is missing: $statePath"
		}
		try {
			$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
		} catch {
			throw "State JSON is invalid: $statePath`n$($_.Exception.Message)"
		}
		if ($state.scenario_id -ne $scenarioEntry.id -or [int]$state.capture_frame -ne $frameIndex) {
			throw "State JSON does not match its expected scenario/frame: $statePath"
		}
		if ([int]$state.viewport.width -ne 1280 -or [int]$state.viewport.height -ne 720) {
			throw "State JSON reports the wrong viewport: $statePath"
		}
		$actualPngHash = (Get-FileHash -LiteralPath $pngPath -Algorithm SHA256).Hash.ToLowerInvariant()
		if ([string]$state.png_sha256 -ne $actualPngHash) {
			throw "State JSON PNG hash does not match the screenshot: $statePath"
		}
		if ([string]$state.runtime.renderer.actual_method -ne $renderer) {
			throw "State JSON reports the wrong active renderer: $statePath"
		}
		$verifiedPairs += 1
	}
}

if ($result.Output -notmatch "BB_VISUAL_CAPTURE_COMPLETE") {
	throw "Capture exited without its completion marker. See $logPath"
}

$runMetadata.status = "passed"
$runMetadata.result.verified_pairs = $verifiedPairs
Write-RunMetadata -Path $metadataPath -Metadata $runMetadata

Write-Host ""
Write-Host "Visual capture passed: $verifiedPairs PNG/state pairs"
Write-Host "Artifacts: $runDirectory"
