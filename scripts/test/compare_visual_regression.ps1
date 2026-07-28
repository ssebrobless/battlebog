[CmdletBinding()]
param(
	[string]$Godot = "",
	[Parameter(Mandatory = $true)]
	[string]$BaselineRoot,
	[Parameter(Mandatory = $true)]
	[string]$CandidateRoot,
	[Parameter(Mandatory = $true)]
	[string]$OutputRoot,
	[string]$Scenario = "",
	[int]$TimeoutSec = 300
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3.0

$PlatformSlug = "windows-x86_64-godot4.6-gl_compatibility"
$MaeMaximum = 0.010
$RoiSsimMinimum = 0.985
$ChangedPixelDelta = 0.08
$ChangedPixelRatioMaximum = 0.01
$SafeIdPattern = "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$"
$SafeAnchorPattern = "^[A-Za-z0-9][A-Za-z0-9._:+-]{0,127}$"
$Sha256Pattern = "^[a-f0-9]{64}$"

function Resolve-Executable {
	param([string]$Candidate)
	if (-not [string]::IsNullOrWhiteSpace($Candidate) -and
		(Test-Path -LiteralPath $Candidate -PathType Leaf)) {
		return (Resolve-Path -LiteralPath $Candidate).Path
	}
	if (-not [string]::IsNullOrWhiteSpace($Candidate)) {
		$command = Get-Command $Candidate -ErrorAction SilentlyContinue
		if ($null -ne $command) {
			return $command.Source
		}
	}
	return $null
}

function Resolve-Godot {
	param([string]$Requested)
	foreach ($candidate in @($Requested, $env:GODOT4, "godot")) {
		$resolved = Resolve-Executable $candidate
		if ($null -ne $resolved) {
			return $resolved
		}
	}
	$fallback = "C:\Godot\Godot_v4.6-stable_win64_console.exe"
	if (Test-Path -LiteralPath $fallback -PathType Leaf) {
		return $fallback
	}
	throw "Could not locate Godot."
}

function Resolve-RepoPath {
	param([string]$Path, [string]$RepoRoot)
	if ([string]::IsNullOrWhiteSpace($Path)) {
		throw "Path must not be empty."
	}
	if ([IO.Path]::IsPathRooted($Path)) {
		return [IO.Path]::GetFullPath($Path)
	}
	return [IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Assert-ExactPath {
	param([string]$Actual, [string]$Expected, [string]$Label)
	if (-not $Actual.Equals($Expected, [StringComparison]::OrdinalIgnoreCase)) {
		throw "$Label must resolve exactly to '$Expected'."
	}
}

function Assert-DirectChild {
	param([string]$Path, [string]$Parent, [string]$Label)
	$actualParent = [IO.Path]::GetDirectoryName($Path.TrimEnd("\", "/"))
	if (-not $actualParent.Equals($Parent, [StringComparison]::OrdinalIgnoreCase)) {
		throw "$Label must be a direct child of '$Parent'."
	}
	$leaf = [IO.Path]::GetFileName($Path.TrimEnd("\", "/"))
	Assert-SafeId $leaf "$Label ID"
}

function Assert-SafeId {
	param([string]$Value, [string]$Label)
	if ([string]::IsNullOrWhiteSpace($Value) -or $Value -cnotmatch $SafeIdPattern) {
		throw "$Label must be a closed ASCII identifier."
	}
}

function Assert-NoReparsePoints {
	param([string]$Path, [string]$StopAt, [string]$Label)
	$full = [IO.Path]::GetFullPath($Path)
	$stop = [IO.Path]::GetFullPath($StopAt).TrimEnd("\", "/")
	$current = $full
	while ($true) {
		if (Test-Path -LiteralPath $current) {
			$item = Get-Item -LiteralPath $current -Force
			if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
				throw "$Label contains a reparse point: $current"
			}
		}
		if ($current.Equals($stop, [StringComparison]::OrdinalIgnoreCase)) {
			return
		}
		$parent = [IO.Path]::GetDirectoryName($current.TrimEnd("\", "/"))
		if ([string]::IsNullOrWhiteSpace($parent) -or
			$parent.Equals($current, [StringComparison]::OrdinalIgnoreCase)) {
			throw "$Label is not beneath its trusted root."
		}
		$current = $parent
	}
}

function Read-Json {
	param([string]$Path, [string]$Label)
	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw "$Label is missing: $Path"
	}
	Assert-NoReparsePoints $Path $repoRoot $Label
	try {
		return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
	} catch {
		throw "$Label is invalid JSON: $Path`n$($_.Exception.Message)"
	}
}

function Require-Property {
	param([object]$Object, [string]$Name, [string]$Label)
	if ($null -eq $Object) {
		throw "$Label is null."
	}
	$property = $Object.PSObject.Properties[$Name]
	if ($null -eq $property) {
		throw "$Label is missing '$Name'."
	}
	return $property.Value
}

function Require-SafeId {
	param([object]$Object, [string]$Name, [string]$Label)
	$value = [string](Require-Property $Object $Name $Label)
	Assert-SafeId $value "$Label.$Name"
	return $value
}

function Require-Sha256 {
	param([object]$Object, [string]$Name, [string]$Label)
	$value = [string](Require-Property $Object $Name $Label)
	if ($value -cnotmatch $Sha256Pattern) {
		throw "$Label.$Name must be a lowercase SHA-256 digest."
	}
	return $value
}

function Get-Sha256 {
	param([string]$Path)
	return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-TreeSnapshot {
	param([string]$Root)
	$snapshot = [ordered]@{}
	$items = @(Get-ChildItem -LiteralPath $Root -Recurse -Force | Sort-Object FullName)
	foreach ($item in $items) {
		Assert-NoReparsePoints $item.FullName $Root "Baseline tree"
		$relative = $item.FullName.Substring($Root.TrimEnd("\", "/").Length + 1).
			Replace("\", "/")
		if ($item.PSIsContainer) {
			$snapshot["$relative/"] = "<directory>"
		} else {
			$snapshot[$relative] = Get-Sha256 $item.FullName
		}
	}
	return $snapshot
}

function Assert-SnapshotsEqual {
	param([object]$Before, [object]$After)
	$beforeJson = $Before | ConvertTo-Json -Compress
	$afterJson = $After | ConvertTo-Json -Compress
	if ($beforeJson -cne $afterJson) {
		throw "Comparator detected a mutation in the baseline tree."
	}
}

function Get-RelativeArtifactPath {
	param([string]$Root, [string]$Relative, [string]$Label)
	if ([string]::IsNullOrWhiteSpace($Relative) -or
		[IO.Path]::IsPathRooted($Relative) -or
		$Relative.Contains(":") -or
		$Relative.Contains("\") -or
		$Relative -notmatch "^[A-Za-z0-9._/-]+$") {
		throw "$Label must be a safe slash-separated relative path."
	}
	foreach ($segment in $Relative.Split("/")) {
		if ($segment -eq "." -or $segment -eq ".." -or $segment -notmatch $SafeIdPattern) {
			throw "$Label contains an unsafe path segment."
		}
	}
	$resolved = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
	$prefix = $Root.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
	if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
		throw "$Label resolves outside its allowed root."
	}
	Assert-NoReparsePoints $resolved $Root $Label
	return $resolved
}

function Require-Int {
	param([object]$Value, [string]$Label, [int]$Minimum = [int]::MinValue)
	if ($Value -isnot [byte] -and $Value -isnot [int16] -and
		$Value -isnot [int32] -and $Value -isnot [int64]) {
		throw "$Label must be an integer."
	}
	$result = [int]$Value
	if ($result -lt $Minimum) {
		throw "$Label must be at least $Minimum."
	}
	return $result
}

function Get-CriticalRoi {
	param([object]$State, [string]$Label)
	$viewport = Require-Property $State "viewport" $Label
	$viewportWidth = Require-Int (Require-Property $viewport "width" "$Label.viewport") "$Label.viewport.width" 1
	$viewportHeight = Require-Int (Require-Property $viewport "height" "$Label.viewport") "$Label.viewport.height" 1
	$critical = Require-Property $State "critical_regions_px" $Label
	$left = $viewportWidth
	$top = $viewportHeight
	$right = 0
	$bottom = 0
	$count = 0
	foreach ($kind in @("body", "contact", "telegraph")) {
		$regions = @(Require-Property $critical $kind "$Label.critical_regions_px")
		foreach ($region in $regions) {
			$x = Require-Int (Require-Property $region "x" "$Label.$kind") "$Label.$kind.x" 0
			$y = Require-Int (Require-Property $region "y" "$Label.$kind") "$Label.$kind.y" 0
			$width = Require-Int (Require-Property $region "width" "$Label.$kind") "$Label.$kind.width" 1
			$height = Require-Int (Require-Property $region "height" "$Label.$kind") "$Label.$kind.height" 1
			if ($x + $width -gt $viewportWidth -or $y + $height -gt $viewportHeight) {
				throw "$Label.$kind rectangle exceeds the viewport."
			}
			$left = [Math]::Min($left, $x)
			$top = [Math]::Min($top, $y)
			$right = [Math]::Max($right, $x + $width)
			$bottom = [Math]::Max($bottom, $y + $height)
			$count++
		}
	}
	if ($count -eq 0 -or $right -le $left -or $bottom -le $top) {
		throw "$Label has an empty critical-region union; full-frame fallback is forbidden."
	}
	return [ordered]@{
		x = $left
		y = $top
		width = $right - $left
		height = $bottom - $top
	}
}

function Assert-RoiEqual {
	param([object]$Actual, [object]$Expected, [string]$Label)
	foreach ($name in @("x", "y", "width", "height")) {
		$actualValue = Require-Int (Require-Property $Actual $name $Label) "$Label.$name" 0
		$expectedValue = Require-Int (Require-Property $Expected $name "$Label expected") "$Label expected.$name" 0
		if ($actualValue -ne $expectedValue) {
			throw "$Label differs at '$name'."
		}
	}
}

function ConvertTo-CanonicalJson {
	param([object]$Value)
	return $Value | ConvertTo-Json -Depth 32 -Compress
}

function Assert-CanonicalEqual {
	param([object]$Baseline, [object]$Candidate, [string]$Label)
	if ((ConvertTo-CanonicalJson $Baseline) -cne (ConvertTo-CanonicalJson $Candidate)) {
		throw "Candidate provenance differs from the baseline at '$Label'."
	}
}

function Assert-SemanticIdentity {
	param([object]$Baseline, [object]$Candidate, [string]$Label)
	$fields = @(
		"schema_version", "scenario_id", "action_id", "seed", "camera_preset",
		"camera_zoom", "capture_mode", "frame", "tick", "actor_id", "target_id",
		"phase", "outcome", "projected_contact", "contact_truth", "terrain",
		"depth", "named_anchors", "snapshot", "critical_regions_px", "viewport",
		"diagnostic_labels", "screenshot_readback_count", "runtime"
	)
	foreach ($field in $fields) {
		$first = ConvertTo-CanonicalJson (Require-Property $Baseline $field "Baseline semantic")
		$second = ConvertTo-CanonicalJson (Require-Property $Candidate $field "Candidate semantic")
		if ($first -cne $second) {
			throw "$Label semantic identity differs at '$field'."
		}
	}
}

function ConvertTo-ProcessArgument {
	param([string]$Value)
	if ($Value -notmatch '[\s"]') {
		return $Value
	}
	return '"' + ($Value -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
}

function Stop-ProcessTree {
	param([int]$ProcessId)
	& taskkill.exe /PID $ProcessId /T /F 2>&1 | Out-Null
}

function Invoke-Metrics {
	param(
		[string]$GodotPath,
		[string]$RepoRoot,
		[string]$BaselinePng,
		[string]$CandidatePng,
		[object]$Roi,
		[string]$OutputPath,
		[int]$TimeoutSeconds
	)
	$roiText = "{0},{1},{2},{3}" -f
		[int]$Roi.x, [int]$Roi.y, [int]$Roi.width, [int]$Roi.height
	$arguments = @(
		"--headless", "--path", $RepoRoot,
		"--script", "scripts/test/visual/image_metrics.gd", "--",
		"--baseline=$BaselinePng", "--current=$CandidatePng",
		"--roi=$roiText", "--output=$OutputPath"
	)
	$start = [Diagnostics.ProcessStartInfo]::new()
	$start.FileName = $GodotPath
	$start.Arguments = (($arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join " ")
	$start.WorkingDirectory = $RepoRoot
	$start.UseShellExecute = $false
	$start.CreateNoWindow = $true
	$start.RedirectStandardOutput = $true
	$start.RedirectStandardError = $true
	$process = [Diagnostics.Process]::new()
	$process.StartInfo = $start
	if (-not $process.Start()) {
		throw "Could not start image metrics."
	}
	$stdoutTask = $process.StandardOutput.ReadToEndAsync()
	$stderrTask = $process.StandardError.ReadToEndAsync()
	if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
		Stop-ProcessTree $process.Id
		if (-not $process.WaitForExit(5000)) {
			$process.Dispose()
			throw "Image metrics timed out after $TimeoutSeconds seconds and process-tree cleanup did not finish within 5 seconds."
		}
		$process.Dispose()
		throw "Image metrics timed out after $TimeoutSeconds seconds."
	}
	$stdout = $stdoutTask.GetAwaiter().GetResult()
	$stderr = $stderrTask.GetAwaiter().GetResult()
	$exitCode = $process.ExitCode
	$process.Dispose()
	$combined = ($stdout + "`n" + $stderr).Trim()
	if ($exitCode -ne 0 -or $combined -notmatch "BB_IMAGE_METRICS_OK") {
		throw "Image metrics failed with exit code $exitCode`n$combined"
	}
}

if ($TimeoutSec -lt 1 -or $TimeoutSec -gt 3600) {
	throw "TimeoutSec must be between 1 and 3600."
}
if (-not [string]::IsNullOrWhiteSpace($Scenario)) {
	Assert-SafeId $Scenario "Scenario"
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..\..")).Path
$lockedBaseline = [IO.Path]::GetFullPath(
	(Join-Path $repoRoot "tests\visual\baselines\$PlatformSlug")
)
$candidateParent = [IO.Path]::GetFullPath(
	(Join-Path $repoRoot "artifacts\visual-regression")
)
$outputParent = [IO.Path]::GetFullPath(
	(Join-Path $repoRoot "artifacts\execution\r2b")
)
$baselinePath = Resolve-RepoPath $BaselineRoot $repoRoot
$candidatePath = Resolve-RepoPath $CandidateRoot $repoRoot
$outputPath = Resolve-RepoPath $OutputRoot $repoRoot

Assert-ExactPath $baselinePath $lockedBaseline "BaselineRoot"
Assert-DirectChild $candidatePath $candidateParent "CandidateRoot"
Assert-DirectChild $outputPath $outputParent "OutputRoot"
foreach ($requiredDirectory in @($baselinePath, $candidatePath)) {
	if (-not (Test-Path -LiteralPath $requiredDirectory -PathType Container)) {
		throw "Required input directory does not exist: $requiredDirectory"
	}
}
Assert-NoReparsePoints $baselinePath $repoRoot "BaselineRoot"
Assert-NoReparsePoints $candidatePath $repoRoot "CandidateRoot"
Assert-NoReparsePoints $outputParent $repoRoot "OutputRoot parent"
if (Test-Path -LiteralPath $outputPath) {
	throw "OutputRoot already exists: $outputPath"
}

$baselineSnapshotBefore = Get-TreeSnapshot $baselinePath
$comparisonError = $null
try {
	New-Item -ItemType Directory -Path $outputPath | Out-Null
	Assert-NoReparsePoints $outputPath $repoRoot "OutputRoot"

	$baselineManifestPath = Join-Path $baselinePath "manifest.json"
	$baseline = Read-Json $baselineManifestPath "Baseline manifest"
	$candidateMetadata = Read-Json (Join-Path $candidatePath "run_metadata.json") "Candidate metadata"
	if ([int](Require-Property $baseline "schema_version" "Baseline manifest") -ne 1) {
		throw "Baseline manifest schema_version must be 1."
	}
	if ([string](Require-Property $baseline "platform" "Baseline manifest") -cne $PlatformSlug) {
		throw "Baseline platform must be '$PlatformSlug'."
	}
	if ([string](Require-Property $candidateMetadata "status" "Candidate metadata") -cne "passed" -or
		[string](Require-Property $candidateMetadata "mode" "Candidate metadata") -cne "capture") {
		throw "Candidate must be a passed capture run."
	}
	$candidateGit = Require-Property $candidateMetadata "git" "Candidate metadata"
	$candidateDirty = Require-Property $candidateGit "dirty" "Candidate metadata.git"
	if ($candidateDirty -isnot [bool] -or $candidateDirty) {
		throw "Candidate must record clean git metadata."
	}
	$baselineProvenance = Require-Property $baseline "provenance" "Baseline manifest"
	$baselineRenderer = [string](Require-Property $baseline "renderer" "Baseline manifest")
	$candidateManifest = Require-Property $candidateMetadata "manifest" "Candidate metadata"
	Assert-CanonicalEqual `
		(Require-Property $baselineProvenance "visual_manifest_sha256" "Baseline provenance") `
		(Require-Property $candidateManifest "sha256" "Candidate metadata.manifest") `
		"visual_manifest_sha256"
	Assert-CanonicalEqual `
		(Require-Property $baselineProvenance "visual_manifest_sha256" "Baseline provenance") `
		(Get-Sha256 (Join-Path $repoRoot "tests\visual\manifest.json")) `
		"current_visual_manifest_sha256"
	$candidateProject = Require-Property $candidateMetadata "project_settings" "Candidate metadata"
	Assert-CanonicalEqual `
		(Require-Property $baselineProvenance "project_settings_sha256" "Baseline provenance") `
		(Require-Property $candidateProject "sha256" "Candidate metadata.project_settings") `
		"project_settings_sha256"
	Assert-CanonicalEqual `
		(Require-Property $baselineProvenance "project_settings_sha256" "Baseline provenance") `
		(Get-Sha256 (Join-Path $repoRoot "project.godot")) `
		"current_project_settings_sha256"
	$candidateSchema = Require-Property $candidateMetadata "semantic_schema" "Candidate metadata"
	Assert-CanonicalEqual `
		(Require-Property $baselineProvenance "semantic_schema_sha256" "Baseline provenance") `
		(Require-Property $candidateSchema "sha256" "Candidate metadata.semantic_schema") `
		"semantic_schema_sha256"
	Assert-CanonicalEqual `
		(Require-Property $baselineProvenance "semantic_schema_sha256" "Baseline provenance") `
		(Get-Sha256 (Join-Path $repoRoot "tests\visual\semantic_capture.schema.json")) `
		"current_semantic_schema_sha256"
	Assert-CanonicalEqual `
		(Require-Property $baselineProvenance "renderer" "Baseline provenance") `
		(Require-Property $candidateManifest "renderer" "Candidate metadata.manifest") `
		"renderer"
	$baselineViewport = Require-Property $baseline "viewport" "Baseline manifest"
	$candidateViewport = Require-Property $candidateManifest "viewport" "Candidate metadata.manifest"
	Assert-CanonicalEqual $baselineViewport $candidateViewport "viewport"
	Assert-CanonicalEqual `
		(Require-Property $baselineProvenance "fixed_step_hz" "Baseline provenance") `
		(Require-Property $candidateManifest "fixed_step_hz" "Candidate metadata.manifest") `
		"fixed_step_hz"
	$candidateGodot = Require-Property $candidateMetadata "godot" "Candidate metadata"
	Assert-CanonicalEqual `
		(Require-Property $baselineProvenance "godot_version" "Baseline provenance") `
		(Require-Property $candidateGodot "version" "Candidate metadata.godot") `
		"godot_version"
	Assert-CanonicalEqual `
		(Require-Property $baselineProvenance "godot_executable_sha256" "Baseline provenance") `
		(Require-Property $candidateGodot "executable_sha256" "Candidate metadata.godot") `
		"godot_executable_sha256"
	$godotPath = Resolve-Godot $Godot
	Assert-NoReparsePoints $godotPath ([IO.Path]::GetPathRoot($godotPath)) "Metrics Godot executable"
	Assert-CanonicalEqual `
		(Require-Property $baselineProvenance "godot_executable_sha256" "Baseline provenance") `
		(Get-Sha256 $godotPath) `
		"metrics_godot_executable_sha256"
	$candidateHost = Require-Property $candidateMetadata "host" "Candidate metadata"
	$baselineHost = Require-Property $baselineProvenance "host" "Baseline provenance"
	foreach ($hostField in @("os", "os_architecture", "process_architecture")) {
		Assert-CanonicalEqual `
			(Require-Property $baselineHost $hostField "Baseline provenance.host") `
			(Require-Property $candidateHost $hostField "Candidate metadata.host") `
			"host.$hostField"
	}
	Assert-CanonicalEqual `
		(Require-Property $baselineProvenance "camera_preset" "Baseline provenance") `
		(Require-Property $candidateMetadata "camera_preset" "Candidate metadata") `
		"camera_preset"
	Assert-CanonicalEqual `
		(Require-Property $baselineProvenance "camera_zoom" "Baseline provenance") `
		(Require-Property $candidateMetadata "camera_zoom" "Candidate metadata") `
		"camera_zoom"
	Assert-CanonicalEqual `
		(Require-Property $baselineProvenance "capture_mode" "Baseline provenance") `
		(Require-Property $candidateMetadata "capture_mode" "Candidate metadata") `
		"capture_mode"

	$entries = @(Require-Property $baseline "entries" "Baseline manifest")
	if (-not [string]::IsNullOrWhiteSpace($Scenario)) {
		$entries = @($entries | Where-Object {
			[string](Require-Property $_ "scenario_id" "Baseline entry") -ceq $Scenario
		})
	}
	if ($entries.Count -eq 0) {
		throw "No baseline entries matched."
	}
	$artifactCheck = Join-Path $repoRoot "scripts\test\battle_bog_visual_capture_artifact_check.ps1"
	Assert-CanonicalEqual `
		(Require-Property $baselineProvenance "image_metrics_sha256" "Baseline provenance") `
		(Get-Sha256 (Join-Path $repoRoot "scripts\test\visual\image_metrics.gd")) `
		"image_metrics_sha256"
	Assert-CanonicalEqual `
		(Require-Property $baselineProvenance "artifact_checker_sha256" "Baseline provenance") `
		(Get-Sha256 $artifactCheck) `
		"artifact_checker_sha256"
	$artifactOutput = @(
		& (Join-Path $PSHOME "powershell.exe") -NoProfile -ExecutionPolicy Bypass `
			-File $artifactCheck -ArtifactRoot $candidatePath `
			-Manifest (Join-Path $repoRoot "tests\visual\manifest.json") `
			-SemanticSchema (Join-Path $repoRoot "tests\visual\semantic_capture.schema.json") `
			-CameraPreset ([string]$candidateMetadata.camera_preset) `
			-CaptureMode ([string]$candidateMetadata.capture_mode) `
			-Scenario ([string]$candidateMetadata.scenario_filter) 2>&1
	)
	if ($LASTEXITCODE -ne 0) {
		throw "Candidate artifact validation failed: $($artifactOutput -join ' | ')"
	}
	$expectedBasenames = @($entries | ForEach-Object {
		"{0}.frame_{1:D6}" -f
			([string](Require-Property $_ "scenario_id" "Baseline entry")),
			([int](Require-Property $_ "frame" "Baseline entry"))
	} | Sort-Object)
	$candidatePngBasenames = @(
		Get-ChildItem -LiteralPath $candidatePath -Filter "*.png" -File |
			ForEach-Object { $_.BaseName } |
			Sort-Object
	)
	$candidateSemanticBasenames = @(
		Get-ChildItem -LiteralPath $candidatePath -Filter "*.json" -File |
			Where-Object { $_.Name -ne "run_metadata.json" } |
			ForEach-Object { $_.BaseName } |
			Sort-Object
	)
	if (($expectedBasenames -join "`n") -cne ($candidatePngBasenames -join "`n") -or
		($expectedBasenames -join "`n") -cne ($candidateSemanticBasenames -join "`n")) {
		throw "Candidate PNG/semantic inventory differs from the selected baseline entries."
	}
	$entryResults = @()
	$allPassed = $true
	foreach ($entry in $entries) {
		$entryId = Require-SafeId $entry "id" "Baseline entry"
		$scenarioId = Require-SafeId $entry "scenario_id" "Baseline entry '$entryId'"
		$frame = Require-Int (Require-Property $entry "frame" "Baseline entry '$entryId'") "Baseline entry '$entryId'.frame" 0
		$anchor = [string](Require-Property $entry "anchor" "Baseline entry '$entryId'")
		if ($anchor -cnotmatch $SafeAnchorPattern) {
			throw "Baseline entry '$entryId'.anchor must be a closed ASCII anchor."
		}
		if ([string](Require-Property $entry "camera_preset" "Baseline entry '$entryId'") -cne
			[string](Require-Property $candidateMetadata "camera_preset" "Candidate metadata") -or
			[string](Require-Property $entry "capture_mode" "Baseline entry '$entryId'") -cne
			[string](Require-Property $candidateMetadata "capture_mode" "Candidate metadata")) {
			throw "Candidate camera or capture mode differs for '$entryId'."
		}

		$baselinePng = Get-RelativeArtifactPath $baselinePath `
			([string](Require-Property $entry "png_path" "Baseline entry '$entryId'")) "Baseline PNG"
		$baselineJson = Get-RelativeArtifactPath $baselinePath `
			([string](Require-Property $entry "semantic_path" "Baseline entry '$entryId'")) "Baseline semantic JSON"
		$basename = "{0}.frame_{1:D6}" -f $scenarioId, $frame
		$candidatePng = Join-Path $candidatePath "$basename.png"
		$candidateJson = Join-Path $candidatePath "$basename.json"
		foreach ($requiredFile in @($baselinePng, $baselineJson, $candidatePng, $candidateJson)) {
			if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
				throw "Comparator input is missing: $requiredFile"
			}
			Assert-NoReparsePoints $requiredFile $repoRoot "Comparator input"
		}

		$expectedPngHash = Require-Sha256 $entry "png_sha256" "Baseline entry '$entryId'"
		$expectedSemanticHash = Require-Sha256 $entry "semantic_sha256" "Baseline entry '$entryId'"
		if ((Get-Sha256 $baselinePng) -cne $expectedPngHash) {
			throw "Baseline PNG hash drifted for '$entryId'."
		}
		if ((Get-Sha256 $baselineJson) -cne $expectedSemanticHash) {
			throw "Baseline semantic hash drifted for '$entryId'."
		}

		$baselineState = Read-Json $baselineJson "Baseline semantic capture '$entryId'"
		$candidateState = Read-Json $candidateJson "Candidate semantic capture '$entryId'"
		$candidateRuntime = Require-Property $candidateState "runtime" "Candidate semantic '$entryId'"
		$candidateRuntimeRenderer = Require-Property $candidateRuntime "renderer" "Candidate semantic '$entryId'.runtime"
		$baselineGpu = Require-Property $baselineProvenance "gpu" "Baseline provenance"
		Assert-CanonicalEqual `
			(Require-Property $baselineProvenance "godot_build" "Baseline provenance") `
			(Require-Property $candidateRuntime "godot_version" "Candidate semantic '$entryId'.runtime") `
			"godot_build"
		Assert-CanonicalEqual `
			(Require-Property $baselineProvenance "renderer" "Baseline provenance") `
			(Require-Property $candidateRuntimeRenderer "actual_method" "Candidate semantic '$entryId'.runtime.renderer") `
			"actual_renderer"
		Assert-CanonicalEqual `
			(Require-Property $baselineProvenance "renderer" "Baseline provenance") `
			(Require-Property $candidateRuntimeRenderer "configured_method" "Candidate semantic '$entryId'.runtime.renderer") `
			"configured_renderer"
		Assert-CanonicalEqual `
			(Require-Property $baselineProvenance "renderer_driver" "Baseline provenance") `
			(Require-Property $candidateRuntimeRenderer "actual_driver" "Candidate semantic '$entryId'.runtime.renderer") `
			"renderer_driver"
		foreach ($gpuField in @(
			@("name", "video_adapter_name"),
			@("vendor", "video_adapter_vendor"),
			@("api_version", "video_adapter_api_version"),
			@("driver", "actual_driver"),
			@("display_server", "display_server")
		)) {
			Assert-CanonicalEqual `
				(Require-Property $baselineGpu $gpuField[0] "Baseline provenance.gpu") `
				(Require-Property $candidateRuntimeRenderer $gpuField[1] "Candidate semantic '$entryId'.runtime.renderer") `
				"gpu.$($gpuField[0])"
		}
		$baselineStatePngHash = [string](Require-Property $baselineState "png_sha256" "Baseline semantic '$entryId'")
		$candidateStatePngHash = [string](Require-Property $candidateState "png_sha256" "Candidate semantic '$entryId'")
		if ($baselineStatePngHash -cnotmatch $Sha256Pattern -or
			$baselineStatePngHash -cne $expectedPngHash) {
			throw "Baseline PNG hash differs from its semantic capture for '$entryId'."
		}
		if ($candidateStatePngHash -cnotmatch $Sha256Pattern -or
			(Get-Sha256 $candidatePng) -cne $candidateStatePngHash) {
			throw "Candidate PNG hash differs from its semantic capture for '$entryId'."
		}
		Assert-SemanticIdentity $baselineState $candidateState $entryId
		$baselineRoi = Get-CriticalRoi $baselineState "Baseline semantic '$entryId'"
		$candidateRoi = Get-CriticalRoi $candidateState "Candidate semantic '$entryId'"
		$manifestRoi = Require-Property $entry "roi" "Baseline entry '$entryId'"
		Assert-RoiEqual $baselineRoi $manifestRoi "Baseline ROI '$entryId'"
		Assert-RoiEqual $candidateRoi $manifestRoi "Candidate ROI '$entryId'"

		$metricPath = Join-Path $outputPath "$entryId.metrics.json"
		Invoke-Metrics $godotPath $repoRoot $baselinePng $candidatePng `
			$manifestRoi $metricPath $TimeoutSec
		$metrics = Read-Json $metricPath "Image metrics '$entryId'"
		foreach ($threshold in @(
			@("mae_max", $MaeMaximum),
			@("roi_ssim_min", $RoiSsimMinimum),
			@("changed_pixel_ratio_max", $ChangedPixelRatioMaximum)
		)) {
			$actual = [double](Require-Property $metrics.thresholds $threshold[0] "Image metric thresholds")
			if ($actual -ne [double]$threshold[1]) {
				throw "Image metrics reported an unexpected '$($threshold[0])' threshold."
			}
		}
		if ([double](Require-Property $metrics "changed_pixel_delta" "Image metrics") -ne $ChangedPixelDelta) {
			throw "Image metrics reported an unexpected changed-pixel delta."
		}
		$passed = [bool](Require-Property $metrics "passed" "Image metrics") -and
			[double]$metrics.mae -le $MaeMaximum -and
			[double]$metrics.roi_ssim -ge $RoiSsimMinimum -and
			[double]$metrics.changed_pixel_ratio -le $ChangedPixelRatioMaximum
		$entryResults += [ordered]@{
			id = $entryId
			scenario_id = $scenarioId
			frame = $frame
			anchor = $anchor
			roi = $manifestRoi
			metrics_path = "$entryId.metrics.json"
			mae = [double]$metrics.mae
			roi_ssim = [double]$metrics.roi_ssim
			changed_pixel_ratio = [double]$metrics.changed_pixel_ratio
			passed = $passed
		}
		if (-not $passed) {
			$allPassed = $false
		}
	}

	$summary = [ordered]@{
		schema_version = 1
		platform = $PlatformSlug
		renderer = $baselineRenderer
		baseline_manifest_sha256 = Get-Sha256 $baselineManifestPath
		candidate_run_id = Require-SafeId $candidateMetadata "run_id" "Candidate metadata"
		scenario_filter = $Scenario
		thresholds = [ordered]@{
			mae_max = $MaeMaximum
			roi_ssim_min = $RoiSsimMinimum
			changed_pixel_delta = $ChangedPixelDelta
			changed_pixel_ratio_max = $ChangedPixelRatioMaximum
		}
		entry_count = $entryResults.Count
		passed = $allPassed
		entries = $entryResults
	}
	$summaryPath = Join-Path $outputPath "comparison.json"
	$summary | ConvertTo-Json -Depth 16 |
		Set-Content -LiteralPath $summaryPath -Encoding UTF8
	if (-not $allPassed) {
		throw "Visual comparison failed. See $summaryPath"
	}
} catch {
	$comparisonError = $_
} finally {
	$baselineSnapshotAfter = Get-TreeSnapshot $baselinePath
	Assert-SnapshotsEqual $baselineSnapshotBefore $baselineSnapshotAfter
}

if ($null -ne $comparisonError) {
	throw $comparisonError
}
Write-Host "Visual comparison passed: $($entryResults.Count) baseline entries."
Write-Host "Report: $(Join-Path $outputPath 'comparison.json')"
