[CmdletBinding(DefaultParameterSetName = "Prepare")]
param(
	[Parameter(Mandatory = $true, ParameterSetName = "Prepare")]
	[switch]$Prepare,

	[Parameter(Mandatory = $true, ParameterSetName = "Prepare")]
	[ValidateCount(3, 3)]
	[string[]]$RunId,

	[Parameter(Mandatory = $true, ParameterSetName = "Prepare")]
	[string]$AttemptToken,

	[Parameter(Mandatory = $true, ParameterSetName = "Promote")]
	[switch]$Promote,

	[Parameter(Mandatory = $true, ParameterSetName = "Promote")]
	[string]$SourceRunManifest,

	[Parameter(Mandatory = $true, ParameterSetName = "Promote")]
	[string]$ApprovalJson,

	[Parameter(ParameterSetName = "Promote")]
	[switch]$Replace,

	[Parameter(ParameterSetName = "Promote")]
	[string]$ExpectedOldManifestSha256 = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3.0

$PlatformSlug = "windows-x86_64-godot4.6-gl_compatibility"
$RequiredRenderer = "mobile"
$SafeIdPattern = "^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$"
$Sha256Pattern = "^[a-f0-9]{64}$"

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
	if ($AllowRoot -and $fullPath.Equals($fullRoot, [StringComparison]::OrdinalIgnoreCase)) {
		return
	}
	$prefix = $fullRoot + [IO.Path]::DirectorySeparatorChar
	if (-not $fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
		throw "$Label resolves outside its locked root."
	}
}

function Assert-SafeId {
	param([string]$Value, [string]$Label)
	$stem = @($Value -split "\.", 2)[0]
	if ($Value -notmatch $SafeIdPattern -or $Value -in @(".", "..") -or
		$Value.EndsWith(".") -or $stem -match "^(?i:con|prn|aux|nul|com[1-9]|lpt[1-9])$") {
		throw "$Label must be a 1-64 character ASCII identifier using only letters, digits, dot, underscore, or hyphen."
	}
}

function Resolve-SafeRelativePath {
	param(
		[string]$Path,
		[string]$RepoRoot,
		[string]$AllowedRoot,
		[string]$Label
	)
	if ([string]::IsNullOrWhiteSpace($Path) -or
		[IO.Path]::IsPathRooted($Path) -or
		$Path.StartsWith("\\") -or
		$Path -match ":" -or
		$Path -match "[^\x20-\x7e]") {
		throw "$Label must be a safe repository-relative ASCII path."
	}
	$segments = @($Path -split "[\\/]")
	if ($segments.Count -eq 0 -or
		$segments | Where-Object {
			$segmentStem = @(([string]$_) -split "\.", 2)[0]
			[string]::IsNullOrWhiteSpace($_) -or $_ -in @(".", "..") -or
			$_ -match '[<>:"|?*]' -or
			([string]$_).TrimEnd([char[]]@(" ", ".")) -ne [string]$_ -or
			$segmentStem -match "^(?i:con|prn|aux|nul|com[1-9]|lpt[1-9])$"
		}) {
		throw "$Label contains an unsafe path segment."
	}
	$resolved = Get-FullPath (Join-Path $RepoRoot $Path)
	Assert-UnderRoot $resolved $AllowedRoot $Label
	return $resolved
}

function Assert-NoReparsePoints {
	param(
		[string]$Path,
		[string]$StopRoot,
		[string]$Label
	)
	$fullPath = Get-FullPath $Path
	$fullStop = (Get-FullPath $StopRoot).TrimEnd("\", "/")
	Assert-UnderRoot $fullPath $fullStop $Label -AllowRoot
	$current = $fullPath
	while ($true) {
		if (Test-Path -LiteralPath $current) {
			$item = Get-Item -LiteralPath $current -Force
			if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
				throw "$Label traverses a reparse point: $current"
			}
		}
		if ($current.Equals($fullStop, [StringComparison]::OrdinalIgnoreCase)) {
			break
		}
		$parent = Split-Path -Parent $current
		if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) {
			throw "$Label escaped its locked root while checking reparse points."
		}
		$current = $parent
	}
}

function Read-Json {
	param([string]$Path, [string]$Label)
	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw "$Label is missing: $Path"
	}
	try {
		return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
	} catch {
		throw "$Label is invalid JSON: $Path`n$($_.Exception.Message)"
	}
}

function Get-RequiredProperty {
	param([object]$Object, [string]$Name, [string]$Label)
	if ($null -eq $Object) {
		throw "$Label is missing."
	}
	$property = $Object.PSObject.Properties[$Name]
	if ($null -eq $property -or $null -eq $property.Value) {
		throw "$Label.$Name is missing."
	}
	return $property.Value
}

function Get-Sha256 {
	param([string]$Path)
	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw "Cannot hash missing file: $Path"
	}
	return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-StringSha256 {
	param([string]$Value)
	$sha = [Security.Cryptography.SHA256]::Create()
	try {
		$bytes = [Text.Encoding]::UTF8.GetBytes($Value)
		return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
	} finally {
		$sha.Dispose()
	}
}

function ConvertTo-CanonicalJson {
	param([object]$Value)
	return $Value | ConvertTo-Json -Depth 100 -Compress
}

function Assert-ExactInteger {
	param([object]$Value, [string]$Label)
	$number = 0.0
	if (-not [double]::TryParse(
		[string]$Value,
		[Globalization.NumberStyles]::Float,
		[Globalization.CultureInfo]::InvariantCulture,
		[ref]$number
	) -or [double]::IsNaN($number) -or [double]::IsInfinity($number) -or $number -ne [Math]::Truncate($number)) {
		throw "$Label must be an integer."
	}
	if ($number -lt [int]::MinValue -or $number -gt [int]::MaxValue) {
		throw "$Label is outside the supported integer range."
	}
	return [int]$number
}

function Get-CriticalRegionContract {
	param(
		[object]$State,
		[string]$Label
	)
	$viewport = Get-RequiredProperty $State "viewport" $Label
	$viewportWidth = Assert-ExactInteger (Get-RequiredProperty $viewport "width" "$Label.viewport") "$Label.viewport.width"
	$viewportHeight = Assert-ExactInteger (Get-RequiredProperty $viewport "height" "$Label.viewport") "$Label.viewport.height"
	if ($viewportWidth -le 0 -or $viewportHeight -le 0) {
		throw "$Label has a non-positive viewport."
	}
	$regions = Get-RequiredProperty $State "critical_regions_px" $Label
	$allowedGroups = @("body", "contact", "telegraph")
	$actualGroups = @($regions.PSObject.Properties.Name)
	if (@($actualGroups | Where-Object { $_ -notin $allowedGroups }).Count -gt 0 -or
		@($allowedGroups | Where-Object { $_ -notin $actualGroups }).Count -gt 0) {
		throw "$Label.critical_regions_px must contain only body, contact, and telegraph."
	}

	$normalized = [ordered]@{ body = @(); contact = @(); telegraph = @() }
	$unionLeft = $viewportWidth
	$unionTop = $viewportHeight
	$unionRight = 0
	$unionBottom = 0
	$count = 0
	foreach ($group in $allowedGroups) {
		$rectangles = @(Get-RequiredProperty $regions $group "$Label.critical_regions_px")
		foreach ($rectangle in $rectangles) {
			if ($null -eq $rectangle) {
				throw "$Label.critical_regions_px.$group contains a null rectangle."
			}
			$propertyNames = @($rectangle.PSObject.Properties.Name)
			$requiredNames = @("x", "y", "width", "height")
			if (@($propertyNames | Where-Object { $_ -notin $requiredNames }).Count -gt 0 -or
				@($requiredNames | Where-Object { $_ -notin $propertyNames }).Count -gt 0) {
				throw "$Label.critical_regions_px.$group rectangles must contain only x, y, width, and height."
			}
			$x = Assert-ExactInteger (Get-RequiredProperty $rectangle "x" "$Label.critical_regions_px.$group") "$Label.critical_regions_px.$group.x"
			$y = Assert-ExactInteger (Get-RequiredProperty $rectangle "y" "$Label.critical_regions_px.$group") "$Label.critical_regions_px.$group.y"
			$width = Assert-ExactInteger (Get-RequiredProperty $rectangle "width" "$Label.critical_regions_px.$group") "$Label.critical_regions_px.$group.width"
			$height = Assert-ExactInteger (Get-RequiredProperty $rectangle "height" "$Label.critical_regions_px.$group") "$Label.critical_regions_px.$group.height"
			if ($x -lt 0 -or $y -lt 0 -or $width -le 0 -or $height -le 0 -or
				([long]$x + $width) -gt $viewportWidth -or ([long]$y + $height) -gt $viewportHeight) {
				throw "$Label.critical_regions_px.$group contains an empty or out-of-bounds rectangle."
			}
			$normalized[$group] += [ordered]@{
				x = $x
				y = $y
				width = $width
				height = $height
			}
			$unionLeft = [Math]::Min($unionLeft, $x)
			$unionTop = [Math]::Min($unionTop, $y)
			$unionRight = [Math]::Max($unionRight, $x + $width)
			$unionBottom = [Math]::Max($unionBottom, $y + $height)
			$count++
		}
	}
	if ($count -eq 0 -or $unionRight -le $unionLeft -or $unionBottom -le $unionTop) {
		throw "$Label has an empty critical-region union."
	}
	return [ordered]@{
		regions = $normalized
		union = [ordered]@{
			x = $unionLeft
			y = $unionTop
			width = $unionRight - $unionLeft
			height = $unionBottom - $unionTop
		}
	}
}

function Get-AnchorNamesForFrame {
	param([object]$State, [string]$Label)
	$anchors = Get-RequiredProperty $State "named_anchors" $Label
	$frame = Assert-ExactInteger (Get-RequiredProperty $State "frame" $Label) "$Label.frame"
	return @(
		$anchors.PSObject.Properties |
			Where-Object { (Assert-ExactInteger $_.Value "$Label.named_anchors.$($_.Name)") -eq $frame } |
			Sort-Object Name |
			ForEach-Object { $_.Name }
	)
}

function Get-RepositoryState {
	param(
		[string]$RepoRoot,
		[switch]$IgnorePromotionStaging
	)
	$head = (& git -C $RepoRoot rev-parse HEAD 2>&1).ToString().Trim().ToLowerInvariant()
	if ($LASTEXITCODE -ne 0 -or $head -notmatch "^[a-f0-9]{40}$") {
		throw "Could not resolve the repository HEAD."
	}
	$status = @(& git -C $RepoRoot status --porcelain=v1 --untracked-files=all 2>&1)
	if ($LASTEXITCODE -ne 0) {
		throw "Could not inspect repository cleanliness."
	}
	if ($IgnorePromotionStaging) {
		$stagingPrefix = "?? tests/visual/baselines/.$PlatformSlug.staging."
		$status = @($status | Where-Object {
			-not ([string]$_).Replace("\", "/").StartsWith(
				$stagingPrefix,
				[StringComparison]::Ordinal
			)
		})
	}
	return [ordered]@{ head = $head; clean = ($status.Count -eq 0); status = @($status) }
}

function Assert-PromotionRevision {
	param(
		[string]$RepoRoot,
		[string]$SourceGitSha,
		[object]$RepositoryState
	)
	if (-not $RepositoryState.clean) {
		throw "Promotion requires a clean repository checkout."
	}
	if ($RepositoryState.head -eq $SourceGitSha) {
		throw "Promotion requires one committed human decision after the approved source capture."
	}
	& git -C $RepoRoot merge-base --is-ancestor $SourceGitSha $RepositoryState.head
	if ($LASTEXITCODE -ne 0) {
		throw "Promotion HEAD must be the source SHA or its clean descendant."
	}
	$changedPaths = @(
		& git -C $RepoRoot diff --name-only --diff-filter=ACDMRTUXB "$SourceGitSha..$($RepositoryState.head)" 2>&1 |
			ForEach-Object { ([string]$_).Trim().Replace("\", "/") } |
			Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
	)
	if ($LASTEXITCODE -ne 0) {
		throw "Could not verify the decision-only diff from the source SHA."
	}
	$unexpectedPaths = @($changedPaths | Where-Object { $_ -ne "docs/BATTLE_BOG_DECISIONS.md" })
	if ($unexpectedPaths.Count -gt 0) {
		throw "Promotion descendants may change only docs/BATTLE_BOG_DECISIONS.md; found: $($unexpectedPaths -join ', ')."
	}
	$commitCount = (& git -C $RepoRoot rev-list --count "$SourceGitSha..$($RepositoryState.head)" 2>&1).ToString().Trim()
	if ($LASTEXITCODE -ne 0 -or $commitCount -ne "1" -or
		$changedPaths.Count -ne 1 -or $changedPaths[0] -ne "docs/BATTLE_BOG_DECISIONS.md") {
		throw "Promotion requires exactly one decision-only descendant commit."
	}
}

function Invoke-CaptureArtifactCheck {
	param(
		[string]$PowerShellPath,
		[string]$ArtifactCheckPath,
		[string]$CaptureRoot,
		[string]$RepoRoot
	)
	$output = @(
		& $PowerShellPath `
			-NoProfile `
			-ExecutionPolicy Bypass `
			-File $ArtifactCheckPath `
			-ArtifactRoot $CaptureRoot `
			-Manifest (Join-Path $RepoRoot "tests\visual\manifest.json") `
			-SemanticSchema (Join-Path $RepoRoot "tests\visual\semantic_capture.schema.json") `
			-CameraPreset "PvAI" `
			-CaptureMode "Diagnostic" `
			-Scenario "neutral_smoke" 2>&1
	)
	if ($LASTEXITCODE -ne 0) {
		throw "Capture artifact validation failed for '$CaptureRoot': $($output -join ' | ')"
	}
}

function Get-RunEvidence {
	param(
		[string]$CaptureRoot,
		[string]$RunIdentifier,
		[string]$RepoRoot,
		[string]$VisualManifestPath,
		[string]$ProjectSettingsPath,
		[string]$SemanticSchemaPath,
		[string]$ArtifactCheckPath,
		[string]$PowerShellPath
	)
	Assert-NoReparsePoints $CaptureRoot (Join-Path $RepoRoot "artifacts\visual-regression") "Capture run '$RunIdentifier'"
	if (-not (Test-Path -LiteralPath $CaptureRoot -PathType Container)) {
		throw "Capture run '$RunIdentifier' does not exist."
	}
	$metadataPath = Join-Path $CaptureRoot "run_metadata.json"
	Assert-NoReparsePoints $metadataPath (Join-Path $RepoRoot "artifacts\visual-regression") "Run metadata"
	$metadata = Read-Json $metadataPath "Run metadata for '$RunIdentifier'"
	if ([string](Get-RequiredProperty $metadata "run_id" "run metadata") -ne $RunIdentifier) {
		throw "Run directory and metadata run_id differ for '$RunIdentifier'."
	}
	if ([string](Get-RequiredProperty $metadata "status" "run metadata") -ne "passed" -or
		[string](Get-RequiredProperty $metadata "mode" "run metadata") -ne "capture") {
		throw "Run '$RunIdentifier' must be a passed capture."
	}
	if ([string](Get-RequiredProperty $metadata "capture_mode" "run metadata") -eq "Performance") {
		throw "Performance run '$RunIdentifier' cannot become raster evidence."
	}
	$git = Get-RequiredProperty $metadata "git" "run metadata"
	if ([bool](Get-RequiredProperty $git "dirty" "run metadata.git")) {
		throw "Run '$RunIdentifier' was captured from a dirty checkout."
	}
	$gitSha = ([string](Get-RequiredProperty $git "revision" "run metadata.git")).ToLowerInvariant()
	if ($gitSha -notmatch "^[a-f0-9]{40}$") {
		throw "Run '$RunIdentifier' has an invalid git revision."
	}

	$manifestMetadata = Get-RequiredProperty $metadata "manifest" "run metadata"
	$renderer = [string](Get-RequiredProperty $manifestMetadata "renderer" "run metadata.manifest")
	if ($renderer -ne $RequiredRenderer) {
		throw "Run '$RunIdentifier' renderer must be '$RequiredRenderer', not '$renderer'."
	}
	$viewport = Get-RequiredProperty $manifestMetadata "viewport" "run metadata.manifest"
	$viewportWidth = Assert-ExactInteger (Get-RequiredProperty $viewport "width" "run metadata.manifest.viewport") "run metadata.manifest.viewport.width"
	$viewportHeight = Assert-ExactInteger (Get-RequiredProperty $viewport "height" "run metadata.manifest.viewport") "run metadata.manifest.viewport.height"
	$fixedFps = Assert-ExactInteger (Get-RequiredProperty $manifestMetadata "fixed_step_hz" "run metadata.manifest") "run metadata.manifest.fixed_step_hz"
	if ($viewportWidth -ne 1280 -or $viewportHeight -ne 720 -or $fixedFps -ne 60) {
		throw "Run '$RunIdentifier' must use the initial R2B contract: 1280x720 at 60 Hz."
	}

	$declaredManifestHash = ([string](Get-RequiredProperty $manifestMetadata "sha256" "run metadata.manifest")).ToLowerInvariant()
	$projectMetadata = Get-RequiredProperty $metadata "project_settings" "run metadata"
	$declaredProjectHash = ([string](Get-RequiredProperty $projectMetadata "sha256" "run metadata.project_settings")).ToLowerInvariant()
	$currentManifestHash = Get-Sha256 $VisualManifestPath
	$currentProjectHash = Get-Sha256 $ProjectSettingsPath
	$currentSchemaHash = Get-Sha256 $SemanticSchemaPath
	if ($declaredManifestHash -ne $currentManifestHash -or $declaredProjectHash -ne $currentProjectHash) {
		throw "Run '$RunIdentifier' manifest/project hashes do not match the locked repository files."
	}
	$schemaMetadata = Get-RequiredProperty $metadata "semantic_schema" "run metadata"
	$declaredSchemaHash = ([string](Get-RequiredProperty $schemaMetadata "sha256" "run metadata.semantic_schema")).ToLowerInvariant()
	if ($declaredSchemaHash -notmatch $Sha256Pattern -or $declaredSchemaHash -ne $currentSchemaHash) {
		throw "Run '$RunIdentifier' semantic schema hash does not match the locked repository schema."
	}

	$godot = Get-RequiredProperty $metadata "godot" "run metadata"
	$godotExecutable = Get-FullPath ([string](Get-RequiredProperty $godot "executable" "run metadata.godot"))
	if (-not (Test-Path -LiteralPath $godotExecutable -PathType Leaf)) {
		throw "Run '$RunIdentifier' Godot executable no longer exists."
	}
	Assert-NoReparsePoints $godotExecutable ([IO.Path]::GetPathRoot($godotExecutable)) "Godot executable"
	$godotExecutableHash = Get-Sha256 $godotExecutable
	$declaredGodotExecutableHash = ([string](Get-RequiredProperty $godot "executable_sha256" "run metadata.godot")).ToLowerInvariant()
	if ($declaredGodotExecutableHash -notmatch $Sha256Pattern -or
		$declaredGodotExecutableHash -ne $godotExecutableHash) {
		throw "Run '$RunIdentifier' Godot executable hash does not match the declared executable bytes."
	}
	$godotVersion = [string](Get-RequiredProperty $godot "version" "run metadata.godot")

	$hostMetadata = Get-RequiredProperty $metadata "host" "run metadata"
	$hostOs = [string](Get-RequiredProperty $hostMetadata "os" "run metadata.host")
	$hostOsArchitecture = [string](Get-RequiredProperty $hostMetadata "os_architecture" "run metadata.host")
	$hostProcessArchitecture = [string](Get-RequiredProperty $hostMetadata "process_architecture" "run metadata.host")
	$cameraPreset = [string](Get-RequiredProperty $metadata "camera_preset" "run metadata")
	$captureMode = [string](Get-RequiredProperty $metadata "capture_mode" "run metadata")
	$scenarioFilter = [string](Get-RequiredProperty $metadata "scenario_filter" "run metadata")
	$cameraZoom = Get-RequiredProperty $metadata "camera_zoom" "run metadata"
	if ($scenarioFilter -ne "neutral_smoke" -or $cameraPreset -ne "PvAI" -or $captureMode -ne "Diagnostic") {
		throw "Run '$RunIdentifier' must use neutral_smoke/PvAI/Diagnostic for the initial R2B baseline."
	}
	Invoke-CaptureArtifactCheck `
		-PowerShellPath $PowerShellPath `
		-ArtifactCheckPath $ArtifactCheckPath `
		-CaptureRoot $CaptureRoot `
		-RepoRoot $RepoRoot

	$jsonFiles = @(
		Get-ChildItem -LiteralPath $CaptureRoot -Filter "*.json" -File |
			Where-Object { $_.Name -ne "run_metadata.json" } |
			Sort-Object Name
	)
	$pngFiles = @(Get-ChildItem -LiteralPath $CaptureRoot -Filter "*.png" -File | Sort-Object Name)
	if ($jsonFiles.Count -eq 0 -or $jsonFiles.Count -ne $pngFiles.Count) {
		throw "Run '$RunIdentifier' must contain matching nonempty PNG and semantic inventories."
	}
	$pngByName = @{}
	foreach ($pngFile in $pngFiles) {
		Assert-NoReparsePoints $pngFile.FullName (Join-Path $RepoRoot "artifacts\visual-regression") "Capture PNG"
		$pngByName[$pngFile.BaseName] = $pngFile
	}

	$frames = @()
	$runtimeContract = $null
	foreach ($jsonFile in $jsonFiles) {
		Assert-NoReparsePoints $jsonFile.FullName (Join-Path $RepoRoot "artifacts\visual-regression") "Semantic capture"
		$basename = $jsonFile.BaseName
		if ($basename -notmatch "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$" -or -not $pngByName.ContainsKey($basename)) {
			throw "Run '$RunIdentifier' has an unsafe or unmatched frame basename '$basename'."
		}
		$pngFile = $pngByName[$basename]
		$state = Read-Json $jsonFile.FullName "Semantic capture '$basename'"
		$pngHash = Get-Sha256 $pngFile.FullName
		$semanticHash = Get-Sha256 $jsonFile.FullName
		if (([string](Get-RequiredProperty $state "png_sha256" "semantic '$basename'")).ToLowerInvariant() -ne $pngHash) {
			throw "Semantic capture '$basename' does not bind its PNG bytes."
		}
		if ([string](Get-RequiredProperty $state "camera_preset" "semantic '$basename'") -ne $cameraPreset -or
			[string](Get-RequiredProperty $state "capture_mode" "semantic '$basename'") -ne $captureMode -or
			[string](Get-RequiredProperty $state "scenario_id" "semantic '$basename'") -ne $scenarioFilter) {
			throw "Semantic capture '$basename' differs from run camera/mode/scenario provenance."
		}
		$stateViewport = Get-RequiredProperty $state "viewport" "semantic '$basename'"
		if ((Assert-ExactInteger (Get-RequiredProperty $stateViewport "width" "semantic '$basename'.viewport") "semantic '$basename'.viewport.width") -ne $viewportWidth -or
			(Assert-ExactInteger (Get-RequiredProperty $stateViewport "height" "semantic '$basename'.viewport") "semantic '$basename'.viewport.height") -ne $viewportHeight -or
			[string](Get-RequiredProperty $stateViewport "expected_renderer" "semantic '$basename'.viewport") -ne $RequiredRenderer) {
			throw "Semantic capture '$basename' differs from run viewport/renderer provenance."
		}

		$runtime = Get-RequiredProperty $state "runtime" "semantic '$basename'"
		$runtimeRenderer = Get-RequiredProperty $runtime "renderer" "semantic '$basename'.runtime"
		$frameRuntime = [ordered]@{
			godot_build = [string](Get-RequiredProperty $runtime "godot_version" "semantic '$basename'.runtime")
			configured_method = [string](Get-RequiredProperty $runtimeRenderer "configured_method" "semantic '$basename'.runtime.renderer")
			actual_method = [string](Get-RequiredProperty $runtimeRenderer "actual_method" "semantic '$basename'.runtime.renderer")
			actual_driver = [string](Get-RequiredProperty $runtimeRenderer "actual_driver" "semantic '$basename'.runtime.renderer")
			gpu_name = [string](Get-RequiredProperty $runtimeRenderer "video_adapter_name" "semantic '$basename'.runtime.renderer")
			gpu_vendor = [string](Get-RequiredProperty $runtimeRenderer "video_adapter_vendor" "semantic '$basename'.runtime.renderer")
			gpu_api_version = [string](Get-RequiredProperty $runtimeRenderer "video_adapter_api_version" "semantic '$basename'.runtime.renderer")
			display_server = [string](Get-RequiredProperty $runtimeRenderer "display_server" "semantic '$basename'.runtime.renderer")
		}
		if ($frameRuntime.configured_method -ne $RequiredRenderer -or $frameRuntime.actual_method -ne $RequiredRenderer) {
			throw "Semantic capture '$basename' did not actually render with '$RequiredRenderer'."
		}
		$frameRuntimeJson = ConvertTo-CanonicalJson $frameRuntime
		if ($null -eq $runtimeContract) {
			$runtimeContract = $frameRuntime
		} elseif ((ConvertTo-CanonicalJson $runtimeContract) -ne $frameRuntimeJson) {
			throw "Run '$RunIdentifier' changed runtime/GPU/driver provenance between frames."
		}

		$critical = Get-CriticalRegionContract $state "semantic '$basename'"
		$snapshot = Get-RequiredProperty $state "snapshot" "semantic '$basename'"
		$namedAnchors = Get-RequiredProperty $state "named_anchors" "semantic '$basename'"
		$frames += [ordered]@{
			id = $basename
			png_file = "$basename.png"
			semantic_file = "$basename.json"
			png_sha256 = $pngHash
			semantic_sha256 = $semanticHash
			frame = Assert-ExactInteger (Get-RequiredProperty $state "frame" "semantic '$basename'") "semantic '$basename'.frame"
			tick = Assert-ExactInteger (Get-RequiredProperty $state "tick" "semantic '$basename'") "semantic '$basename'.tick"
			seed = Assert-ExactInteger (Get-RequiredProperty $state "seed" "semantic '$basename'") "semantic '$basename'.seed"
			anchors = $namedAnchors
			anchors_sha256 = Get-StringSha256 (ConvertTo-CanonicalJson $namedAnchors)
			anchors_at_frame = @(Get-AnchorNamesForFrame $state "semantic '$basename'")
			snapshot_sha256 = Get-StringSha256 (ConvertTo-CanonicalJson $snapshot)
			critical_regions_px = $critical.regions
			critical_roi_px = $critical.union
		}
	}
	if (@($pngByName.Keys | Where-Object { $_ -notin @($frames.id) }).Count -gt 0) {
		throw "Run '$RunIdentifier' contains extra PNG files."
	}

	$provenance = [ordered]@{
		git_sha = $gitSha
		git_clean = $true
		visual_manifest_sha256 = $currentManifestHash
		project_settings_sha256 = $currentProjectHash
		semantic_schema_sha256 = $currentSchemaHash
		image_metrics_sha256 = Get-Sha256 (Join-Path $RepoRoot "scripts\test\visual\image_metrics.gd")
		artifact_checker_sha256 = Get-Sha256 $ArtifactCheckPath
		godot_executable_sha256 = $godotExecutableHash
		godot_version = $godotVersion
		godot_build = $runtimeContract.godot_build
		renderer = $RequiredRenderer
		renderer_driver = $runtimeContract.actual_driver
		viewport = [ordered]@{ width = $viewportWidth; height = $viewportHeight }
		fixed_step_hz = $fixedFps
		camera_preset = $cameraPreset
		camera_zoom = $cameraZoom
		capture_mode = $captureMode
		scenario_id = $scenarioFilter
		host = [ordered]@{
			os = $hostOs
			os_architecture = $hostOsArchitecture
			process_architecture = $hostProcessArchitecture
		}
		gpu = [ordered]@{
			name = $runtimeContract.gpu_name
			vendor = $runtimeContract.gpu_vendor
			api_version = $runtimeContract.gpu_api_version
			driver = $runtimeContract.actual_driver
			display_server = $runtimeContract.display_server
		}
	}
	return [ordered]@{
		run_id = $RunIdentifier
		root = $CaptureRoot
		provenance = $provenance
		frames = $frames
	}
}

function Get-EvidenceFingerprint {
	param([object]$Run)
	return ConvertTo-CanonicalJson ([ordered]@{
		provenance = $Run.provenance
		frames = @($Run.frames | ForEach-Object {
			[ordered]@{
				id = $_.id
				png_sha256 = $_.png_sha256
				semantic_sha256 = $_.semantic_sha256
				frame = $_.frame
				tick = $_.tick
				seed = $_.seed
				anchors_sha256 = $_.anchors_sha256
				anchors = $_.anchors
				anchors_at_frame = $_.anchors_at_frame
				snapshot_sha256 = $_.snapshot_sha256
				critical_regions_px = $_.critical_regions_px
				critical_roi_px = $_.critical_roi_px
			}
		})
	})
}

function Assert-FileHash {
	param([string]$Path, [string]$Expected, [string]$Label)
	$actual = Get-Sha256 $Path
	if ($actual -ne $Expected) {
		throw "$Label hash changed or does not match its manifest: expected $Expected, actual $actual."
	}
}

function Assert-BaselineIntegrity {
	param([string]$BaselinePath)
	$manifestPath = Join-Path $BaselinePath "manifest.json"
	Assert-NoReparsePoints $manifestPath (Split-Path -Parent $BaselinePath) "Existing baseline manifest"
	$manifest = Read-Json $manifestPath "Existing baseline manifest"
	if ([string](Get-RequiredProperty $manifest "kind" "existing baseline manifest") -ne
		"battle_bog_visual_baseline" -or
		[string](Get-RequiredProperty $manifest "platform" "existing baseline manifest") -ne $PlatformSlug) {
		throw "Existing baseline has the wrong kind or platform."
	}
	$null = Get-RequiredProperty $manifest "provenance" "existing baseline manifest"
	$null = Get-RequiredProperty $manifest "source" "existing baseline manifest"
	$entries = @(Get-RequiredProperty $manifest "entries" "existing baseline manifest")
	if ($entries.Count -eq 0) {
		throw "Existing baseline manifest has no entries."
	}
	$seenIds = @{}
	$expectedFiles = @()
	foreach ($entry in $entries) {
		$entryId = [string](Get-RequiredProperty $entry "id" "existing baseline entry")
		if ($entryId -notmatch "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$" -or
			$seenIds.ContainsKey($entryId)) {
			throw "Existing baseline contains an unsafe or duplicate entry ID."
		}
		$seenIds[$entryId] = $true
		foreach ($kind in @("png", "semantic")) {
			$relativeName = [string](Get-RequiredProperty $entry "${kind}_file" "existing baseline entry")
			if ($relativeName -match "[\\/]" -or $relativeName -notmatch "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$") {
				throw "Existing baseline manifest contains an unsafe file name."
			}
			$filePath = Join-Path (Join-Path $BaselinePath "captures") $relativeName
			$expectedFiles += $relativeName
			Assert-NoReparsePoints $filePath (Split-Path -Parent $BaselinePath) "Existing baseline file"
			Assert-FileHash $filePath ([string](Get-RequiredProperty $entry "${kind}_sha256" "existing baseline entry")) "Existing baseline file"
		}
	}
	$actualFiles = @(
		Get-ChildItem -LiteralPath (Join-Path $BaselinePath "captures") -File |
			ForEach-Object { $_.Name } |
			Sort-Object
	)
	if ((@($expectedFiles | Sort-Object) -join "`n") -cne ($actualFiles -join "`n")) {
		throw "Existing baseline capture inventory contains missing or extra files."
	}
	return $manifest
}

function Write-RecoveryJournal {
	param(
		[string]$JournalPath,
		[string]$Phase,
		[string]$BackupPath,
		[string]$ExpectedOldManifestSha256,
		[string]$ExpectedNewSourceManifestSha256
	)
	$journal = [ordered]@{
		schema_version = 1
		kind = "battle_bog_visual_baseline_recovery"
		phase = $Phase
		baseline_path = $PlatformSlug
		backup_name = Split-Path -Leaf $BackupPath
		expected_old_manifest_sha256 = $ExpectedOldManifestSha256
		expected_new_source_manifest_sha256 = $ExpectedNewSourceManifestSha256
		updated_utc = (Get-Date).ToUniversalTime().ToString("o")
	}
	$temporaryJournal = "$JournalPath.tmp"
	$journal | ConvertTo-Json -Depth 10 |
		Set-Content -LiteralPath $temporaryJournal -Encoding UTF8
	$written = Read-Json $temporaryJournal "Replacement recovery journal"
	if ([string](Get-RequiredProperty $written "phase" "replacement recovery journal") -ne $Phase) {
		throw "Replacement recovery journal failed write verification."
	}
	Move-Item -LiteralPath $temporaryJournal -Destination $JournalPath -Force
}

function Repair-InterruptedReplacement {
	param(
		[string]$BaselineParent,
		[string]$BaselinePath,
		[string]$BackupPath,
		[string]$JournalPath
	)
	$backupCandidates = @(
		Get-ChildItem -LiteralPath $BaselineParent -Force -ErrorAction Stop |
			Where-Object { $_.Name -like ".$PlatformSlug.backup*" }
	)
	if ($backupCandidates.Count -gt 1) {
		throw "Multiple baseline backups exist; refusing automatic recovery."
	}
	$journalExists = Test-Path -LiteralPath $JournalPath -PathType Leaf
	if ($backupCandidates.Count -eq 1 -and -not $journalExists) {
		throw "An orphaned baseline backup exists without a recovery journal: $($backupCandidates[0].FullName)"
	}
	if (-not $journalExists) {
		return
	}

	Assert-NoReparsePoints $JournalPath $BaselineParent "Replacement recovery journal"
	$journal = Read-Json $JournalPath "Replacement recovery journal"
	if ([string](Get-RequiredProperty $journal "kind" "replacement recovery journal") -ne
		"battle_bog_visual_baseline_recovery") {
		throw "Replacement recovery journal has the wrong kind."
	}
	$phase = [string](Get-RequiredProperty $journal "phase" "replacement recovery journal")
	$journalBackupName = [string](Get-RequiredProperty $journal "backup_name" "replacement recovery journal")
	if ($journalBackupName -ne (Split-Path -Leaf $BackupPath)) {
		throw "Replacement recovery journal names an unexpected backup."
	}
	$expectedOldHash = ([string](Get-RequiredProperty $journal "expected_old_manifest_sha256" "replacement recovery journal")).ToLowerInvariant()
	$expectedNewSourceHash = ([string](Get-RequiredProperty $journal "expected_new_source_manifest_sha256" "replacement recovery journal")).ToLowerInvariant()
	if ($expectedOldHash -notmatch $Sha256Pattern) {
		throw "Replacement recovery journal has an invalid old manifest hash."
	}
	if ($expectedNewSourceHash -notmatch $Sha256Pattern) {
		throw "Replacement recovery journal has an invalid new source-manifest hash."
	}

	if ($phase -eq "promotion_complete") {
		if (-not (Test-Path -LiteralPath $BaselinePath -PathType Container)) {
			throw "Completed replacement journal exists but the active baseline is missing."
		}
		$activeManifest = Assert-BaselineIntegrity $BaselinePath
		$activeSource = Get-RequiredProperty $activeManifest "source" "active baseline manifest"
		if ([string](Get-RequiredProperty $activeSource "source_manifest_sha256" "active baseline source") -ne
			$expectedNewSourceHash) {
			throw "Recovered active baseline is not bound to the journaled source manifest."
		}
		if (Test-Path -LiteralPath $BackupPath) {
			try {
				Remove-Item -LiteralPath $BackupPath -Recurse -Force
			} catch {
				Write-Warning "The promoted baseline remains active, but its completed backup could not be removed: $($_.Exception.Message)"
				return
			}
		}
		Remove-Item -LiteralPath $JournalPath -Force
		return
	}

	if ($phase -notin @("prepared", "old_moved", "new_installed")) {
		throw "Replacement recovery journal has an unsupported phase '$phase'."
	}
	if (Test-Path -LiteralPath $BackupPath -PathType Container) {
		Assert-NoReparsePoints $BackupPath $BaselineParent "Replacement backup"
		$null = Assert-BaselineIntegrity $BackupPath
		if ((Get-Sha256 (Join-Path $BackupPath "manifest.json")) -ne $expectedOldHash) {
			throw "Replacement backup does not match the journal's old manifest hash."
		}
		if (Test-Path -LiteralPath $BaselinePath) {
			Assert-UnderRoot $BaselinePath $BaselineParent "Interrupted replacement baseline"
			Remove-Item -LiteralPath $BaselinePath -Recurse -Force
		}
		Move-Item -LiteralPath $BackupPath -Destination $BaselinePath
		$null = Assert-BaselineIntegrity $BaselinePath
		Remove-Item -LiteralPath $JournalPath -Force
		throw "Recovered the previous baseline from an interrupted replacement. Re-run promotion after reviewing repository state."
	}
	if ($phase -eq "prepared" -and (Test-Path -LiteralPath $BaselinePath -PathType Container)) {
		$null = Assert-BaselineIntegrity $BaselinePath
		if ((Get-Sha256 (Join-Path $BaselinePath "manifest.json")) -ne $expectedOldHash) {
			throw "Prepared replacement journal does not match the still-active baseline."
		}
		Remove-Item -LiteralPath $JournalPath -Force
		throw "Cleared an interrupted pre-swap replacement journal. Re-run promotion."
	}
	throw "Interrupted replacement cannot be recovered automatically because its expected backup is missing."
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..\..")).Path
$captureParent = Join-Path $repoRoot "artifacts\visual-regression"
$executionParent = Join-Path $repoRoot "artifacts\execution\r2b"
$baselineParent = Join-Path $repoRoot "tests\visual\baselines"
$baselinePath = Join-Path $baselineParent $PlatformSlug
$backup = Join-Path $baselineParent (".$PlatformSlug.backup")
$recoveryJournal = Join-Path $baselineParent (".$PlatformSlug.recovery.json")
$visualManifestPath = Join-Path $repoRoot "tests\visual\manifest.json"
$projectSettingsPath = Join-Path $repoRoot "project.godot"
$semanticSchemaPath = Join-Path $repoRoot "tests\visual\semantic_capture.schema.json"
$artifactCheckPath = Join-Path $repoRoot "scripts\test\battle_bog_visual_capture_artifact_check.ps1"
$powerShellPath = (Get-Process -Id $PID).Path

if ($PSCmdlet.ParameterSetName -eq "Prepare") {
	Assert-SafeId $AttemptToken "AttemptToken"
	foreach ($id in $RunId) {
		Assert-SafeId $id "RunId"
	}
	if (@($RunId | ForEach-Object { $_.ToLowerInvariant() } | Select-Object -Unique).Count -ne 3) {
		throw "Prepare requires exactly three distinct capture run IDs."
	}
	$repositoryState = Get-RepositoryState $repoRoot
	if (-not $repositoryState.clean) {
		throw "Prepare requires a clean repository checkout. Current changes: $($repositoryState.status -join ' | ')"
	}
	if (-not (Test-Path -LiteralPath $captureParent -PathType Container)) {
		throw "Capture root is missing."
	}
	Assert-NoReparsePoints $captureParent $repoRoot "Capture root"
	foreach ($lockedFile in @($visualManifestPath, $projectSettingsPath, $semanticSchemaPath)) {
		Assert-NoReparsePoints $lockedFile $repoRoot "Locked provenance file"
	}

	$runs = @()
	foreach ($id in $RunId) {
		$runRoot = Join-Path $captureParent $id
		$runs += Get-RunEvidence `
			-CaptureRoot $runRoot `
			-RunIdentifier $id `
			-RepoRoot $repoRoot `
			-VisualManifestPath $visualManifestPath `
			-ProjectSettingsPath $projectSettingsPath `
			-SemanticSchemaPath $semanticSchemaPath `
			-ArtifactCheckPath $artifactCheckPath `
			-PowerShellPath $powerShellPath
	}
	$referenceFingerprint = Get-EvidenceFingerprint $runs[0]
	foreach ($run in $runs) {
		if ($run.provenance.git_sha -ne $repositoryState.head) {
			throw "Run '$($run.run_id)' source SHA does not equal the current clean HEAD."
		}
		if ((Get-EvidenceFingerprint $run) -ne $referenceFingerprint) {
			throw "All three runs must have byte-identical frame inventory, PNG/semantic hashes, simulation state, and render provenance."
		}
	}

	$attemptRoot = Join-Path $executionParent $AttemptToken
	$sourceManifestPath = Join-Path $attemptRoot "source-run-manifest.json"
	Assert-UnderRoot $attemptRoot $executionParent "Attempt output"
	if (Test-Path -LiteralPath $attemptRoot) {
		throw "Attempt '$AttemptToken' already exists; evidence preparation never overwrites."
	}
	Assert-NoReparsePoints $executionParent $repoRoot "R2B execution root"
	if (-not (Test-Path -LiteralPath $executionParent -PathType Container)) {
		New-Item -ItemType Directory -Path $executionParent -Force | Out-Null
	}
	$temporaryAttempt = Join-Path $executionParent (".$AttemptToken.preparing." + [Guid]::NewGuid().ToString("N"))
	Assert-UnderRoot $temporaryAttempt $executionParent "Temporary evidence directory"
	New-Item -ItemType Directory -Path $temporaryAttempt | Out-Null
	try {
		$sourceManifest = [ordered]@{
			schema_version = 1
			kind = "battle_bog_r2b_source_run_manifest"
			platform = $PlatformSlug
			renderer = $RequiredRenderer
			created_utc = (Get-Date).ToUniversalTime().ToString("o")
			primary_run_id = $runs[0].run_id
			verification_run_ids = @($runs | ForEach-Object { $_.run_id })
			source_git_sha = $runs[0].provenance.git_sha
			provenance = $runs[0].provenance
			frames = $runs[0].frames
		}
		$temporaryManifest = Join-Path $temporaryAttempt "source-run-manifest.json"
		$sourceManifest | ConvertTo-Json -Depth 100 |
			Set-Content -LiteralPath $temporaryManifest -Encoding UTF8
		$written = Read-Json $temporaryManifest "Prepared source-run manifest"
		if ([string]$written.kind -ne "battle_bog_r2b_source_run_manifest") {
			throw "Prepared source-run manifest failed its write verification."
		}
		Move-Item -LiteralPath $temporaryAttempt -Destination $attemptRoot
	} catch {
		if (Test-Path -LiteralPath $temporaryAttempt) {
			Remove-Item -LiteralPath $temporaryAttempt -Recurse -Force
		}
		throw
	}
	Write-Host "R2B evidence prepared; no baseline was changed."
	Write-Host "Source manifest: $sourceManifestPath"
	Write-Host "Source manifest SHA-256: $(Get-Sha256 $sourceManifestPath)"
	exit 0
}

if (Test-Path -LiteralPath $baselineParent -PathType Container) {
	Assert-NoReparsePoints $baselineParent $repoRoot "Baseline parent"
	Repair-InterruptedReplacement `
		-BaselineParent $baselineParent `
		-BaselinePath $baselinePath `
		-BackupPath $backup `
		-JournalPath $recoveryJournal
	if (Test-Path -LiteralPath $backup) {
		throw "A completed replacement backup remains pending cleanup; refusing another promotion."
	}
}

$sourceManifestPath = Resolve-SafeRelativePath $SourceRunManifest $repoRoot $executionParent "SourceRunManifest"
$approvalPath = Resolve-SafeRelativePath $ApprovalJson $repoRoot $executionParent "ApprovalJson"
if ((Split-Path -Leaf $sourceManifestPath) -ne "source-run-manifest.json") {
	throw "SourceRunManifest must name source-run-manifest.json."
}
if ((Split-Path -Parent $sourceManifestPath) -ne (Split-Path -Parent $approvalPath)) {
	throw "ApprovalJson must be in the same immutable evidence directory as SourceRunManifest."
}
Assert-NoReparsePoints $sourceManifestPath $executionParent "SourceRunManifest"
Assert-NoReparsePoints $approvalPath $executionParent "ApprovalJson"
$sourceManifestHashBefore = Get-Sha256 $sourceManifestPath
$approvalHashBefore = Get-Sha256 $approvalPath
$sourceManifest = Read-Json $sourceManifestPath "Source-run manifest"
$approval = Read-Json $approvalPath "Approval JSON"

if ((Assert-ExactInteger (Get-RequiredProperty $sourceManifest "schema_version" "source-run manifest") "source-run manifest.schema_version") -ne 1 -or
	[string](Get-RequiredProperty $sourceManifest "kind" "source-run manifest") -ne "battle_bog_r2b_source_run_manifest" -or
	[string](Get-RequiredProperty $sourceManifest "platform" "source-run manifest") -ne $PlatformSlug -or
	[string](Get-RequiredProperty $sourceManifest "renderer" "source-run manifest") -ne $RequiredRenderer) {
	throw "Source-run manifest has the wrong schema, kind, platform, or renderer."
}
$verificationRunIds = @(Get-RequiredProperty $sourceManifest "verification_run_ids" "source-run manifest")
if ($verificationRunIds.Count -ne 3 -or
	@($verificationRunIds | ForEach-Object { ([string]$_).ToLowerInvariant() } | Select-Object -Unique).Count -ne 3) {
	throw "Source-run manifest must bind exactly three distinct run IDs."
}
foreach ($id in $verificationRunIds) {
	Assert-SafeId ([string]$id) "Source run ID"
}
$primaryRunId = [string](Get-RequiredProperty $sourceManifest "primary_run_id" "source-run manifest")
if ($primaryRunId -notin $verificationRunIds) {
	throw "Source-run manifest primary_run_id is not one of its three verified runs."
}
$sourceGitSha = ([string](Get-RequiredProperty $sourceManifest "source_git_sha" "source-run manifest")).ToLowerInvariant()
if ($sourceGitSha -notmatch "^[a-f0-9]{40}$") {
	throw "Source-run manifest has an invalid source_git_sha."
}

if ([string](Get-RequiredProperty $approval "token" "approval") -ne "HUMAN_APPROVED") {
	throw "Approval token must be exactly HUMAN_APPROVED."
}
if (([string](Get-RequiredProperty $approval "source_manifest_sha256" "approval")).ToLowerInvariant() -ne $sourceManifestHashBefore -or
	[string](Get-RequiredProperty $approval "selected_primary_run_id" "approval") -ne $primaryRunId -or
	([string](Get-RequiredProperty $approval "source_git_sha" "approval")).ToLowerInvariant() -ne $sourceGitSha) {
	throw "Approval is not cryptographically bound to this source manifest, primary run, and source git SHA."
}
$reviewer = [string](Get-RequiredProperty $approval "reviewer" "approval")
$reason = [string](Get-RequiredProperty $approval "reason" "approval")
if ($reviewer -notmatch $SafeIdPattern -or $reviewer.Length -lt 2 -or
	[string]::IsNullOrWhiteSpace($reason) -or $reason.Trim().Length -lt 12 -or $reason.Length -gt 1024) {
	throw "Approval requires a safe reviewer ID and a written 12-1024 character reason."
}

$approvalReplace = [bool](Get-RequiredProperty $approval "replace" "approval")
$approvalOldHashProperty = $approval.PSObject.Properties["expected_old_manifest_sha256"]
$approvalOldHash = if ($null -eq $approvalOldHashProperty -or $null -eq $approvalOldHashProperty.Value) {
	""
} else {
	([string]$approvalOldHashProperty.Value).ToLowerInvariant()
}
if ($approvalReplace -ne [bool]$Replace) {
	throw "CLI -Replace and approval replacement intent differ."
}
if ($Replace) {
	$ExpectedOldManifestSha256 = $ExpectedOldManifestSha256.ToLowerInvariant()
	if ($ExpectedOldManifestSha256 -notmatch $Sha256Pattern -or $approvalOldHash -ne $ExpectedOldManifestSha256) {
		throw "Replacement requires the same exact old manifest SHA-256 in CLI and approval."
	}
} elseif (-not [string]::IsNullOrWhiteSpace($ExpectedOldManifestSha256) -or -not [string]::IsNullOrWhiteSpace($approvalOldHash)) {
	throw "Initial promotion must not provide an old baseline manifest hash."
}

$repositoryState = Get-RepositoryState $repoRoot
Assert-PromotionRevision $repoRoot $sourceGitSha $repositoryState
$provenance = Get-RequiredProperty $sourceManifest "provenance" "source-run manifest"
if (-not [bool](Get-RequiredProperty $provenance "git_clean" "source-run manifest.provenance") -or
	[string](Get-RequiredProperty $provenance "git_sha" "source-run manifest.provenance") -ne $sourceGitSha -or
	[string](Get-RequiredProperty $provenance "renderer" "source-run manifest.provenance") -ne $RequiredRenderer) {
	throw "Source-run provenance does not bind a clean source SHA and mobile renderer."
}
$lockedHashes = [ordered]@{
	visual_manifest_sha256 = Get-Sha256 $visualManifestPath
	project_settings_sha256 = Get-Sha256 $projectSettingsPath
	semantic_schema_sha256 = Get-Sha256 $semanticSchemaPath
}
foreach ($name in $lockedHashes.Keys) {
	if ([string](Get-RequiredProperty $provenance $name "source-run manifest.provenance") -ne $lockedHashes[$name]) {
		throw "Current $name differs from the approved evidence."
	}
}

$godotExecutableHash = [string](Get-RequiredProperty $provenance "godot_executable_sha256" "source-run manifest.provenance")
if ($godotExecutableHash -notmatch $Sha256Pattern) {
	throw "Source-run manifest has an invalid Godot executable hash."
}
$frames = @(Get-RequiredProperty $sourceManifest "frames" "source-run manifest")
if ($frames.Count -eq 0) {
	throw "Source-run manifest has no frames."
}

$approvedFingerprint = Get-EvidenceFingerprint ([ordered]@{
	provenance = $provenance
	frames = $frames
})
foreach ($verifiedRunId in $verificationRunIds) {
	$verifiedRunRoot = Join-Path $captureParent ([string]$verifiedRunId)
	$verifiedEvidence = Get-RunEvidence `
		-CaptureRoot $verifiedRunRoot `
		-RunIdentifier ([string]$verifiedRunId) `
		-RepoRoot $repoRoot `
		-VisualManifestPath $visualManifestPath `
		-ProjectSettingsPath $projectSettingsPath `
		-SemanticSchemaPath $semanticSchemaPath `
		-ArtifactCheckPath $artifactCheckPath `
		-PowerShellPath $powerShellPath
	if ((Get-EvidenceFingerprint $verifiedEvidence) -ne $approvedFingerprint) {
		throw "Verified run '$verifiedRunId' no longer matches the immutable approved evidence packet."
	}
}

$primaryRunRoot = Join-Path $captureParent $primaryRunId
Assert-NoReparsePoints $primaryRunRoot $captureParent "Primary capture run"
$copyPlan = @()
$seenIds = @{}
foreach ($frame in $frames) {
	$id = [string](Get-RequiredProperty $frame "id" "source frame")
	if ($id -notmatch "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$" -or $seenIds.ContainsKey($id)) {
		throw "Source-run manifest contains an unsafe or duplicate frame ID."
	}
	$seenIds[$id] = $true
	$pngName = [string](Get-RequiredProperty $frame "png_file" "source frame '$id'")
	$semanticName = [string](Get-RequiredProperty $frame "semantic_file" "source frame '$id'")
	if ($pngName -ne "$id.png" -or $semanticName -ne "$id.json") {
		throw "Source frame '$id' has noncanonical file names."
	}
	$pngHash = ([string](Get-RequiredProperty $frame "png_sha256" "source frame '$id'")).ToLowerInvariant()
	$semanticHash = ([string](Get-RequiredProperty $frame "semantic_sha256" "source frame '$id'")).ToLowerInvariant()
	if ($pngHash -notmatch $Sha256Pattern -or $semanticHash -notmatch $Sha256Pattern) {
		throw "Source frame '$id' has invalid hashes."
	}
	$pngSource = Join-Path $primaryRunRoot $pngName
	$semanticSource = Join-Path $primaryRunRoot $semanticName
	Assert-NoReparsePoints $pngSource $captureParent "Source PNG"
	Assert-NoReparsePoints $semanticSource $captureParent "Source semantic JSON"
	Assert-FileHash $pngSource $pngHash "Source PNG '$id'"
	Assert-FileHash $semanticSource $semanticHash "Source semantic '$id'"
	$state = Read-Json $semanticSource "Source semantic '$id'"
	$critical = Get-CriticalRegionContract $state "source semantic '$id'"
	if ((ConvertTo-CanonicalJson $critical.regions) -ne
		(ConvertTo-CanonicalJson (Get-RequiredProperty $frame "critical_regions_px" "source frame '$id'")) -or
		(ConvertTo-CanonicalJson $critical.union) -ne
		(ConvertTo-CanonicalJson (Get-RequiredProperty $frame "critical_roi_px" "source frame '$id'"))) {
		throw "Source semantic '$id' critical regions differ from the immutable source manifest."
	}
	$copyPlan += [ordered]@{
		id = $id
		png_name = $pngName
		semantic_name = $semanticName
		png_source = $pngSource
		semantic_source = $semanticSource
		png_sha256 = $pngHash
		semantic_sha256 = $semanticHash
		source_frame = $frame
	}
}

Assert-NoReparsePoints $baselineParent $repoRoot "Baseline parent"
if (-not (Test-Path -LiteralPath $baselineParent -PathType Container)) {
	New-Item -ItemType Directory -Path $baselineParent -Force | Out-Null
}

$baselineObjectExists = Test-Path -LiteralPath $baselinePath
$baselineExists = Test-Path -LiteralPath $baselinePath -PathType Container
if ($baselineObjectExists -and -not $baselineExists) {
	throw "The fixed baseline destination is occupied by a non-directory object."
}
$oldManifestHash = $null
if ($baselineExists) {
	if (-not $Replace) {
		throw "Baseline already exists; replacement requires -Replace and an approved old manifest hash."
	}
	Assert-NoReparsePoints $baselinePath $baselineParent "Existing baseline"
	$null = Assert-BaselineIntegrity $baselinePath
	$oldManifestHash = Get-Sha256 (Join-Path $baselinePath "manifest.json")
	if ($oldManifestHash -ne $ExpectedOldManifestSha256) {
		throw "Current baseline manifest does not match the exact approved replacement hash."
	}
} elseif ($Replace) {
	throw "-Replace cannot be used when no baseline exists."
}

$staging = Join-Path $baselineParent (".$PlatformSlug.staging." + [Guid]::NewGuid().ToString("N"))
Assert-UnderRoot $staging $baselineParent "Baseline staging directory"
Assert-UnderRoot $backup $baselineParent "Baseline backup directory"
New-Item -ItemType Directory -Path $staging | Out-Null
$installedByThisAttempt = $false
try {
	$captureDestination = Join-Path $staging "captures"
	New-Item -ItemType Directory -Path $captureDestination | Out-Null
	$baselineEntries = @()
	foreach ($item in $copyPlan) {
		Assert-FileHash $item.png_source $item.png_sha256 "Source PNG '$($item.id)' before copy"
		Assert-FileHash $item.semantic_source $item.semantic_sha256 "Source semantic '$($item.id)' before copy"
		$pngDestination = Join-Path $captureDestination $item.png_name
		$semanticDestination = Join-Path $captureDestination $item.semantic_name
		Copy-Item -LiteralPath $item.png_source -Destination $pngDestination
		Copy-Item -LiteralPath $item.semantic_source -Destination $semanticDestination
		Assert-FileHash $item.png_source $item.png_sha256 "Source PNG '$($item.id)' after copy"
		Assert-FileHash $item.semantic_source $item.semantic_sha256 "Source semantic '$($item.id)' after copy"
		Assert-FileHash $pngDestination $item.png_sha256 "Staged PNG '$($item.id)'"
		Assert-FileHash $semanticDestination $item.semantic_sha256 "Staged semantic '$($item.id)'"
		$baselineEntries += [ordered]@{
			id = $item.id
			scenario_id = [string]$provenance.scenario_id
			camera_preset = [string]$provenance.camera_preset
			capture_mode = [string]$provenance.capture_mode
			png_file = $item.png_name
			semantic_file = $item.semantic_name
			png_path = "captures/$($item.png_name)"
			semantic_path = "captures/$($item.semantic_name)"
			png_sha256 = $item.png_sha256
			semantic_sha256 = $item.semantic_sha256
			frame = $item.source_frame.frame
			tick = $item.source_frame.tick
			seed = $item.source_frame.seed
			anchor = if (@($item.source_frame.anchors_at_frame).Count -gt 0) {
				[string]@($item.source_frame.anchors_at_frame)[0]
			} else {
				"frame:$($item.source_frame.frame)"
			}
			anchors = $item.source_frame.anchors
			anchors_sha256 = $item.source_frame.anchors_sha256
			anchors_at_frame = $item.source_frame.anchors_at_frame
			snapshot_sha256 = $item.source_frame.snapshot_sha256
			critical_regions_px = $item.source_frame.critical_regions_px
			critical_roi_px = $item.source_frame.critical_roi_px
			roi = $item.source_frame.critical_roi_px
		}
	}
	Assert-FileHash $sourceManifestPath $sourceManifestHashBefore "Source-run manifest after staging"
	Assert-FileHash $approvalPath $approvalHashBefore "Approval JSON after staging"
	$baselineManifest = [ordered]@{
		schema_version = 1
		kind = "battle_bog_visual_baseline"
		platform = $PlatformSlug
		renderer = $RequiredRenderer
		viewport = $provenance.viewport
		godot_version = [string]$provenance.godot_version
		provenance = $provenance
		source = [ordered]@{
			source_manifest_sha256 = $sourceManifestHashBefore
			primary_run_id = $primaryRunId
			verification_run_ids = $verificationRunIds
			git_sha = $sourceGitSha
		}
		approval = [ordered]@{
			token = "HUMAN_APPROVED"
			approval_json_sha256 = $approvalHashBefore
			reviewer = $reviewer
			reason = $reason
			promoted_utc = (Get-Date).ToUniversalTime().ToString("o")
			replace = [bool]$Replace
			old_manifest_sha256 = $oldManifestHash
		}
		entries = $baselineEntries
	}
	$stagedManifestPath = Join-Path $staging "manifest.json"
	$baselineManifest | ConvertTo-Json -Depth 100 |
		Set-Content -LiteralPath $stagedManifestPath -Encoding UTF8
	$null = Read-Json $stagedManifestPath "Staged baseline manifest"
	foreach ($item in $copyPlan) {
		Assert-FileHash (Join-Path $captureDestination $item.png_name) $item.png_sha256 "Final staged PNG '$($item.id)'"
		Assert-FileHash (Join-Path $captureDestination $item.semantic_name) $item.semantic_sha256 "Final staged semantic '$($item.id)'"
	}
	$finalRepositoryState = Get-RepositoryState $repoRoot -IgnorePromotionStaging
	Assert-PromotionRevision $repoRoot $sourceGitSha $finalRepositoryState
	Assert-FileHash $sourceManifestPath $sourceManifestHashBefore "Source-run manifest before install"
	Assert-FileHash $approvalPath $approvalHashBefore "Approval JSON before install"

	if ($baselineExists) {
		# Close the staging-time TOCTOU window immediately before the replacement swap.
		$null = Assert-BaselineIntegrity $baselinePath
		if ((Get-Sha256 (Join-Path $baselinePath "manifest.json")) -ne $ExpectedOldManifestSha256) {
			throw "Existing baseline changed after replacement validation."
		}
		Assert-FileHash $sourceManifestPath $sourceManifestHashBefore "Source-run manifest before replacement swap"
		Assert-FileHash $approvalPath $approvalHashBefore "Approval JSON before replacement swap"
		Write-RecoveryJournal `
			-JournalPath $recoveryJournal `
			-Phase "prepared" `
			-BackupPath $backup `
			-ExpectedOldManifestSha256 $ExpectedOldManifestSha256 `
			-ExpectedNewSourceManifestSha256 $sourceManifestHashBefore
		Move-Item -LiteralPath $baselinePath -Destination $backup
		Write-RecoveryJournal `
			-JournalPath $recoveryJournal `
			-Phase "old_moved" `
			-BackupPath $backup `
			-ExpectedOldManifestSha256 $ExpectedOldManifestSha256 `
			-ExpectedNewSourceManifestSha256 $sourceManifestHashBefore
	}
	Move-Item -LiteralPath $staging -Destination $baselinePath
	$installedByThisAttempt = $true
	if ($baselineExists) {
		Write-RecoveryJournal `
			-JournalPath $recoveryJournal `
			-Phase "new_installed" `
			-BackupPath $backup `
			-ExpectedOldManifestSha256 $ExpectedOldManifestSha256 `
			-ExpectedNewSourceManifestSha256 $sourceManifestHashBefore
	}
	$null = Assert-BaselineIntegrity $baselinePath
	if ($baselineExists) {
		Write-RecoveryJournal `
			-JournalPath $recoveryJournal `
			-Phase "promotion_complete" `
			-BackupPath $backup `
			-ExpectedOldManifestSha256 $ExpectedOldManifestSha256 `
			-ExpectedNewSourceManifestSha256 $sourceManifestHashBefore
		try {
			Remove-Item -LiteralPath $backup -Recurse -Force
			Remove-Item -LiteralPath $recoveryJournal -Force
		} catch {
			Write-Warning "Promotion succeeded and the new baseline remains active, but backup cleanup is pending: $($_.Exception.Message)"
		}
	}
} catch {
	$promotionError = $_
	if (Test-Path -LiteralPath $staging) {
		Remove-Item -LiteralPath $staging -Recurse -Force
	}
	if ($baselineExists -and (Test-Path -LiteralPath $backup -PathType Container)) {
		if (Test-Path -LiteralPath $baselinePath) {
			Assert-UnderRoot $baselinePath $baselineParent "Failed replacement baseline"
			Remove-Item -LiteralPath $baselinePath -Recurse -Force
		}
		Move-Item -LiteralPath $backup -Destination $baselinePath
		$null = Assert-BaselineIntegrity $baselinePath
		if ((Get-Sha256 (Join-Path $baselinePath "manifest.json")) -ne $ExpectedOldManifestSha256) {
			throw "Promotion failed and rollback restored a baseline with an unexpected manifest hash. Original error: $($promotionError.Exception.Message)"
		}
		if (Test-Path -LiteralPath $recoveryJournal) {
			Remove-Item -LiteralPath $recoveryJournal -Force
		}
	} elseif ($baselineExists -and (Test-Path -LiteralPath $recoveryJournal) -and
		(Test-Path -LiteralPath $baselinePath -PathType Container)) {
		# Failure before the old baseline moved leaves the original baseline authoritative.
		$null = Assert-BaselineIntegrity $baselinePath
		if ((Get-Sha256 (Join-Path $baselinePath "manifest.json")) -eq $ExpectedOldManifestSha256) {
			Remove-Item -LiteralPath $recoveryJournal -Force
		}
	} elseif (-not $baselineExists -and $installedByThisAttempt -and
		(Test-Path -LiteralPath $baselinePath)) {
		Assert-UnderRoot $baselinePath $baselineParent "Failed initial baseline"
		Remove-Item -LiteralPath $baselinePath -Recurse -Force
	}
	throw $promotionError
}

$newManifestPath = Join-Path $baselinePath "manifest.json"
Write-Host "Visual baseline promoted from human-approved immutable evidence."
Write-Host "Baseline: $baselinePath"
Write-Host "Manifest SHA-256: $(Get-Sha256 $newManifestPath)"
Write-Host "No commit was created."
