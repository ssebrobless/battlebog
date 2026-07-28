param(
	[string]$Godot = "",
	[string]$Manifest = "tests\visual\manifest.json",
	[string]$Scenario = "",
	[string]$RunId = "",
	[int]$TimeoutSec = 300,
	[ValidateSet("PvAI", "Competitive")]
	[string]$CameraPreset = "PvAI",
	[ValidateSet("Diagnostic", "Evaluator", "Performance")]
	[string]$CaptureMode = "Diagnostic",
	[switch]$Capture,
	[switch]$List,
	[switch]$Validate
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3.0

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

function Convert-ToNativeArgument {
	param([AllowEmptyString()][string]$Value)
	if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') {
		return $Value
	}
	$builder = New-Object System.Text.StringBuilder
	[void]$builder.Append('"')
	$backslashes = 0
	foreach ($character in $Value.ToCharArray()) {
		if ($character -eq '\') {
			$backslashes += 1
			continue
		}
		if ($character -eq '"') {
			[void]$builder.Append(('\' * (($backslashes * 2) + 1)))
			[void]$builder.Append('"')
			$backslashes = 0
			continue
		}
		if ($backslashes -gt 0) {
			[void]$builder.Append(('\' * $backslashes))
			$backslashes = 0
		}
		[void]$builder.Append($character)
	}
	if ($backslashes -gt 0) {
		[void]$builder.Append(('\' * ($backslashes * 2)))
	}
	[void]$builder.Append('"')
	return $builder.ToString()
}

function Stop-ProcessTree {
	param([int]$ProcessId)
	$taskKill = Join-Path $env:SystemRoot "System32\taskkill.exe"
	if (Test-Path -LiteralPath $taskKill) {
		$null = & $taskKill /PID $ProcessId /T /F 2>&1
	}
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
	$output = ""
	$exitCode = -1
	$process = $null
	try {
		$startInfo = New-Object System.Diagnostics.ProcessStartInfo
		$startInfo.FileName = $GodotPath
		$startInfo.Arguments = (@($Arguments) | ForEach-Object {
			Convert-ToNativeArgument ([string]$_)
		}) -join " "
		$startInfo.WorkingDirectory = $RepoRoot
		$startInfo.UseShellExecute = $false
		$startInfo.CreateNoWindow = $true
		$startInfo.RedirectStandardOutput = $true
		$startInfo.RedirectStandardError = $true
		$process = New-Object System.Diagnostics.Process
		$process.StartInfo = $startInfo
		if (-not $process.Start()) {
			throw "Godot process start returned false."
		}
		$stdoutTask = $process.StandardOutput.ReadToEndAsync()
		$stderrTask = $process.StandardError.ReadToEndAsync()
		if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
			Stop-ProcessTree -ProcessId $process.Id
			if (-not $process.WaitForExit(5000)) {
				$process.Kill()
				$process.WaitForExit()
			}
			$exitCode = 124
		} else {
			$exitCode = [int]$process.ExitCode
		}
		$stdout = $stdoutTask.Result.TrimEnd()
		$stderr = $stderrTask.Result.TrimEnd()
		$outputParts = @(
			@($stdout, $stderr) |
				Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
		)
		$output = $outputParts -join [Environment]::NewLine
		if ($exitCode -eq 124) {
			$output = "Timed out after $TimeoutSeconds seconds.`n$output".Trim()
		}
	} finally {
		if ($null -ne $process) {
			$process.Dispose()
		}
	}

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

$selectedModes = @(
	@($Capture.IsPresent, $List.IsPresent, $Validate.IsPresent) |
		Where-Object { $_ }
)
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
$cameraZoom = if ($CameraPreset -eq "PvAI") {
	@(2.6, 2.6)
} else {
	@(2.2, 2.2)
}

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
$semanticSchemaPath = Join-Path $repoRoot "tests\visual\semantic_capture.schema.json"
if (-not (Test-Path -LiteralPath $semanticSchemaPath -PathType Leaf)) {
	throw "Semantic capture schema is missing: $semanticSchemaPath"
}
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
	"--bb-visual-output=$($runDirectory.Replace('\', '/'))",
	"--bb-camera-preset=$CameraPreset",
	"--bb-capture-mode=$CaptureMode"
)
if (-not [string]::IsNullOrWhiteSpace($Scenario)) {
	$arguments += "--bb-visual-scenario=$Scenario"
}

$godotVersion = (& $godotPath --version 2>&1 | Select-Object -First 1).ToString().Trim()
$runMetadata = [ordered]@{
	schema_version = 1
	run_id = $RunId
	mode = $mode
	camera_preset = $CameraPreset
	capture_mode = $CaptureMode
	camera_zoom = [ordered]@{
		x = $cameraZoom[0]
		y = $cameraZoom[1]
	}
	scenario_filter = $Scenario
	capture_started_utc = (Get-Date).ToUniversalTime().ToString("o")
	capture_completed_utc = $null
	status = "started"
	git = Get-GitProvenance $repoRoot
	manifest = [ordered]@{
		path = $manifestPath
		sha256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
		fixed_step_hz = $fixedStepHz
		viewport = [ordered]@{
			width = $viewportWidth
			height = $viewportHeight
		}
		renderer = $renderer
	}
	project_settings = [ordered]@{
		path = (Join-Path $repoRoot "project.godot")
		sha256 = (Get-FileHash -LiteralPath (Join-Path $repoRoot "project.godot") -Algorithm SHA256).Hash.ToLowerInvariant()
	}
	semantic_schema = [ordered]@{
		path = $semanticSchemaPath
		sha256 = (Get-FileHash -LiteralPath $semanticSchemaPath -Algorithm SHA256).Hash.ToLowerInvariant()
	}
	godot = [ordered]@{
		executable = $godotPath
		executable_sha256 = (Get-FileHash -LiteralPath $godotPath -Algorithm SHA256).Hash.ToLowerInvariant()
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
Write-Host "Camera:  $CameraPreset ($($cameraZoom -join ', '))"
Write-Host "Capture: $CaptureMode"
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

if ($result.Output -notmatch "BB_VISUAL_CAPTURE_COMPLETE") {
	throw "Capture exited without its completion marker. See $logPath"
}

$artifactChecker = Join-Path $scriptRoot "battle_bog_visual_capture_artifact_check.ps1"
if (-not (Test-Path -LiteralPath $artifactChecker -PathType Leaf)) {
	throw "Visual capture artifact checker is missing: $artifactChecker"
}
& $artifactChecker `
	-ArtifactRoot $runDirectory `
	-Manifest $manifestPath `
	-CameraPreset $CameraPreset `
	-CaptureMode $CaptureMode `
	-Scenario $Scenario
if ($LASTEXITCODE -ne 0) {
	throw "Visual capture artifact validation failed with exit code $LASTEXITCODE."
}

$semanticCount = @(
	Get-ChildItem -LiteralPath $runDirectory -Filter "*.json" -File |
		Where-Object { $_.Name -ne "run_metadata.json" }
).Count
$runMetadata.status = "passed"
$runMetadata.result.verified_semantic_captures = $semanticCount
Write-RunMetadata -Path $metadataPath -Metadata $runMetadata

Write-Host ""
if ($CaptureMode -eq "Performance") {
	Write-Host "Visual capture passed: $semanticCount semantic captures (no screenshot readback)"
} else {
	Write-Host "Visual capture passed: $semanticCount PNG/semantic pairs"
}
Write-Host "Artifacts: $runDirectory"
