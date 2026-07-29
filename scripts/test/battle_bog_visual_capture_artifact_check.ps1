param(
	[Parameter(Mandatory = $true)]
	[string]$ArtifactRoot,
	[string]$Manifest = "tests\visual\manifest.json",
	[string]$SemanticSchema = "tests\visual\semantic_capture.schema.json",
	[ValidateSet("", "PvAI", "Competitive")]
	[string]$CameraPreset = "",
	[ValidateSet("", "Diagnostic", "Evaluator", "Performance")]
	[string]$CaptureMode = "",
	[string]$Scenario = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3.0

function Resolve-RepositoryPath {
	param([string]$Path, [string]$RepoRoot)
	if ([System.IO.Path]::IsPathRooted($Path)) {
		return [System.IO.Path]::GetFullPath($Path)
	}
	return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Read-JsonFile {
	param([string]$Path, [string]$Label)
	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw "$Label is missing: $Path"
	}
	try {
		return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
	} catch {
		throw "$Label is not valid JSON: $Path`n$($_.Exception.Message)"
	}
}

function Test-Property {
	param([object]$Object, [string]$Name)
	return $null -ne $Object -and $null -ne $Object.PSObject.Properties[$Name]
}

function Require-Property {
	param([object]$Object, [string]$Name, [string]$Path)
	if (-not (Test-Property $Object $Name)) {
		throw "$Path is missing required field '$Name'."
	}
	return $Object.PSObject.Properties[$Name].Value
}

function Require-NonEmptyString {
	param([object]$Object, [string]$Name, [string]$Path)
	$value = Require-Property $Object $Name $Path
	if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) {
		throw "$Path.$Name must be a non-empty string."
	}
	return [string]$value
}

function Require-String {
	param([object]$Object, [string]$Name, [string]$Path)
	$value = Require-Property $Object $Name $Path
	if ($value -isnot [string]) {
		throw "$Path.$Name must be a string."
	}
	return [string]$value
}

function Require-Integer {
	param([object]$Object, [string]$Name, [string]$Path)
	$value = Require-Property $Object $Name $Path
	if ($value -isnot [byte] -and $value -isnot [sbyte] -and
		$value -isnot [int16] -and $value -isnot [uint16] -and
		$value -isnot [int32] -and $value -isnot [uint32] -and
		$value -isnot [int64] -and $value -isnot [uint64]) {
		throw "$Path.$Name must be a JSON integer."
	}
	return [int64]$value
}

function Require-Boolean {
	param([object]$Object, [string]$Name, [string]$Path)
	$value = Require-Property $Object $Name $Path
	if ($value -isnot [bool]) {
		throw "$Path.$Name must be a JSON boolean."
	}
	return [bool]$value
}

function Test-JsonInteger {
	param([object]$Value)
	return $Value -is [byte] -or $Value -is [sbyte] -or
		$Value -is [int16] -or $Value -is [uint16] -or
		$Value -is [int32] -or $Value -is [uint32] -or
		$Value -is [int64] -or $Value -is [uint64]
}

function Test-JsonNumber {
	param([object]$Value)
	if (Test-JsonInteger $Value) {
		return $true
	}
	if ($Value -isnot [double] -and $Value -isnot [single] -and $Value -isnot [decimal]) {
		return $false
	}
	return -not [double]::IsNaN([double]$Value) -and
		-not [double]::IsInfinity([double]$Value)
}

function Test-JsonObject {
	param([object]$Value)
	return $null -ne $Value -and
		($Value -is [pscustomobject] -or $Value -is [System.Collections.IDictionary])
}

function Assert-JsonSchemaValue {
	param(
		[AllowNull()][object]$Value,
		[object]$Schema,
		[string]$Path,
		[object]$RootSchema = $null
	)
	if ($null -eq $RootSchema) {
		$RootSchema = $Schema
	}
	if (-not (Test-JsonObject $Schema)) {
		throw "$Path schema node must be an object."
	}
	if (Test-Property $Schema '$ref') {
		$reference = [string]$Schema.'$ref'
		if (-not $reference.StartsWith("#/`$defs/")) {
			throw "$Path schema uses unsupported reference '$reference'."
		}
		$definitionName = $reference.Substring(8)
		$definitions = Require-Property $RootSchema '$defs' "root schema"
		$definition = Require-Property $definitions $definitionName "root schema.`$defs"
		Assert-JsonSchemaValue $Value $definition $Path $RootSchema
		return
	}
	if (Test-Property $Schema "const") {
		$expectedJson = $Schema.const | ConvertTo-Json -Compress -Depth 100
		$actualJson = $Value | ConvertTo-Json -Compress -Depth 100
		if ($actualJson -ne $expectedJson) {
			throw "$Path must equal schema const $expectedJson."
		}
	}
	if (Test-Property $Schema "enum") {
		$actualJson = $Value | ConvertTo-Json -Compress -Depth 100
		$allowed = @($Schema.enum | ForEach-Object {
			$_ | ConvertTo-Json -Compress -Depth 100
		})
		if ($actualJson -notin $allowed) {
			throw "$Path is outside the schema enum."
		}
	}

	$type = if (Test-Property $Schema "type") { [string]$Schema.type } else { "" }
	switch ($type) {
		"object" {
			if (-not (Test-JsonObject $Value)) {
				throw "$Path must be a JSON object."
			}
			$requiredValues = if (Test-Property $Schema "required") {
				@($Schema.required)
			} else {
				@()
			}
			foreach ($requiredName in $requiredValues) {
				$null = Require-Property $Value ([string]$requiredName) $Path
			}
			$propertySchemas = if (Test-Property $Schema "properties") {
				$Schema.properties
			} else {
				$null
			}
			$additional = if (Test-Property $Schema "additionalProperties") {
				$Schema.additionalProperties
			} else {
				$true
			}
			foreach ($property in $Value.PSObject.Properties) {
				$propertySchema = if ($null -ne $propertySchemas) {
					$propertySchemas.PSObject.Properties[$property.Name]
				} else {
					$null
				}
				if ($null -ne $propertySchema) {
					Assert-JsonSchemaValue $property.Value $propertySchema.Value "$Path.$($property.Name)" $RootSchema
				} elseif ($additional -eq $false) {
					throw "$Path contains additional property '$($property.Name)'."
				} elseif (Test-JsonObject $additional) {
					Assert-JsonSchemaValue $property.Value $additional "$Path.$($property.Name)" $RootSchema
				}
			}
		}
		"array" {
			if ($Value -isnot [System.Array]) {
				throw "$Path must be a JSON array."
			}
			$values = @($Value)
			if ((Test-Property $Schema "minItems") -and
				$values.Count -lt [int]$Schema.minItems) {
				throw "$Path has fewer items than schema minItems."
			}
			if (Test-Property $Schema "items") {
				for ($index = 0; $index -lt $values.Count; $index++) {
					Assert-JsonSchemaValue $values[$index] $Schema.items "$Path[$index]" $RootSchema
				}
			}
		}
		"string" {
			if ($Value -isnot [string]) {
				throw "$Path must be a string."
			}
			if ((Test-Property $Schema "minLength") -and
				$Value.Length -lt [int]$Schema.minLength) {
				throw "$Path is shorter than schema minLength."
			}
		}
		"integer" {
			if (-not (Test-JsonInteger $Value)) {
				throw "$Path must be an integer."
			}
		}
		"number" {
			if (-not (Test-JsonNumber $Value)) {
				throw "$Path must be a finite number."
			}
		}
		"boolean" {
			if ($Value -isnot [bool]) {
				throw "$Path must be a boolean."
			}
		}
	}

	if (($type -eq "integer" -or $type -eq "number") -and
		(Test-Property $Schema "minimum") -and
		[double]$Value -lt [double]$Schema.minimum) {
		throw "$Path is below schema minimum."
	}
	if (($type -eq "integer" -or $type -eq "number") -and
		(Test-Property $Schema "maximum") -and
		[double]$Value -gt [double]$Schema.maximum) {
		throw "$Path is above schema maximum."
	}
	if (($type -eq "integer" -or $type -eq "number") -and
		(Test-Property $Schema "exclusiveMinimum") -and
		[double]$Value -le [double]$Schema.exclusiveMinimum) {
		throw "$Path must be above schema exclusiveMinimum."
	}
}

function Get-AnchorSignature {
	param([object]$Anchors, [string]$Path)
	$records = @()
	foreach ($property in @($Anchors.PSObject.Properties | Sort-Object Name)) {
		$value = Require-Integer $Anchors $property.Name $Path
		$records += "$($property.Name)=$value"
	}
	return $records -join ";"
}

function Get-CameraZoom {
	param([string]$Preset)
	if ($Preset -eq "PvAI") {
		return @(2.6, 2.6)
	}
	return @(2.2, 2.2)
}

function Test-ZoomMatches {
	param([double[]]$Actual, [double[]]$Expected)
	return $Actual.Count -eq 2 -and
		[Math]::Abs($Actual[0] - $Expected[0]) -le 0.0001 -and
		[Math]::Abs($Actual[1] - $Expected[1]) -le 0.0001
}

function Get-ActualZoom {
	param([object]$State, [string]$Path)
	$zoom = if (Test-Property $State "camera_zoom") {
		$State.camera_zoom
	} elseif (Test-Property $State "camera") {
		Require-Property $State.camera "zoom" "$Path.camera"
	} else {
		throw "$Path is missing required camera zoom."
	}
	if ($zoom -is [pscustomobject] -or $zoom -is [System.Collections.IDictionary]) {
		return @(
			[double](Require-Property $zoom "x" "$Path.camera_zoom"),
			[double](Require-Property $zoom "y" "$Path.camera_zoom")
		)
	}
	$values = @($zoom)
	if ($values.Count -ne 2) {
		throw "$Path camera zoom must contain exactly two numbers."
	}
	return @([double]$values[0], [double]$values[1])
}

function Get-ActualRenderer {
	param([object]$State, [string]$Path)
	$runtime = Require-Property $State "runtime" $Path
	$renderer = Require-Property $runtime "renderer" "$Path.runtime"
	return Require-NonEmptyString $renderer "actual_method" "$Path.runtime.renderer"
}

function Get-ExpectedFrames {
	param(
		[object]$ScenarioEntry,
		[object]$RepresentativeState,
		[string]$Path,
		[int64[]]$ProducedFrames
	)
	if (-not (Test-Property $ScenarioEntry "capture_window")) {
		return @($ProducedFrames | Sort-Object -Unique)
	}
	$window = Require-Property $ScenarioEntry "capture_window" "manifest scenario '$($ScenarioEntry.id)'"
	$anchorName = Require-NonEmptyString $window "anchor" "manifest scenario '$($ScenarioEntry.id)'.capture_window"
	$throughName = Require-NonEmptyString $window "through" "manifest scenario '$($ScenarioEntry.id)'.capture_window"
	$beforeFrames = Require-Integer $window "before_frames" "manifest scenario '$($ScenarioEntry.id)'.capture_window"
	$anchors = Require-Property $RepresentativeState "named_anchors" $Path
	$anchorFrame = Require-Integer $anchors $anchorName "$Path.named_anchors"
	$throughFrame = Require-Integer $anchors $throughName "$Path.named_anchors"
	$first = [Math]::Max(0, $anchorFrame - $beforeFrames)
	$last = $throughFrame + 1
	if ($last -lt $first) {
		throw "Scenario '$($ScenarioEntry.id)' resolves to an invalid capture window $first..$last."
	}
	return @($first..$last)
}

function Get-CaptureAtAnchor {
	param(
		[object[]]$Captures,
		[object]$Anchors,
		[string]$Anchor,
		[string]$ScenarioId
	)
	$frame = Require-Integer $Anchors $Anchor "$ScenarioId.named_anchors"
	$match = @($Captures | Where-Object { [int64]$_.Frame -eq $frame })
	if ($match.Count -ne 1) {
		throw "Scenario '$ScenarioId' must capture anchor '$Anchor' exactly once."
	}
	return $match[0].State
}

function Assert-OrderedAnchors {
	param([object]$Anchors, [string[]]$Names, [string]$ScenarioId)
	$previous = -1
	foreach ($name in $Names) {
		$current = Require-Integer $Anchors $name "$ScenarioId.named_anchors"
		if ($current -le $previous) {
			throw "Scenario '$ScenarioId' anchor '$name' is not strictly ordered."
		}
		$previous = $current
	}
}

function Assert-R2CScenarioEvidence {
	param([string]$ScenarioId, [object[]]$Captures)
	if (-not $ScenarioId.StartsWith("alligator_")) {
		return
	}
	$expectedActor = "fixture:${ScenarioId}:0"
	$expectedTarget = "fixture:${ScenarioId}:1"
	foreach ($capture in $Captures) {
		$state = $capture.State
		if ([int64]$state.seed -ne 307) {
			throw "Scenario '$ScenarioId' must use seed 307."
		}
		if ([string]$state.actor_id -ne $expectedActor -or
			[string]$state.target_id -ne $expectedTarget) {
			throw "Scenario '$ScenarioId' reports unstable fixture actor identities."
		}
		$evidence = Require-Property $state "scenario_evidence" $capture.Path
		$null = Require-NonEmptyString $evidence "action_phase" "$($capture.Path).scenario_evidence"
		$band = Require-NonEmptyString $evidence "presentation_band" "$($capture.Path).scenario_evidence"
		if ($band -notin @("dry", "mud", "shallow", "deep")) {
			throw "$($capture.Path).scenario_evidence.presentation_band is invalid."
		}
		$null = Require-NonEmptyString $evidence "simulation_terrain" "$($capture.Path).scenario_evidence"
		$edgeDistance = Require-Property $evidence "edge_distance_px" "$($capture.Path).scenario_evidence"
		if (-not (Test-JsonNumber $edgeDistance)) {
			throw "$($capture.Path).scenario_evidence.edge_distance_px must be finite."
		}
	}

	$anchors = $Captures[0].State.named_anchors
	switch ($ScenarioId) {
		"alligator_player_camera_attack" {
			$order = @(
				"HIT_TEL", "HIT_ACTIVE", "HIT_RECOVERY", "HIT_END",
				"WHIFF_TEL", "WHIFF_ACTIVE", "WHIFF_RECOVERY", "WHIFF_END",
				"INTERRUPT_TEL", "INTERRUPT_RECOVERY",
				"SCENARIO_END"
			)
			Assert-OrderedAnchors $anchors $order $ScenarioId
			$interruptApplied = Require-Integer $anchors "INTERRUPT_APPLIED" "$ScenarioId.named_anchors"
			$interruptTell = Require-Integer $anchors "INTERRUPT_TEL" "$ScenarioId.named_anchors"
			$interruptRecovery = Require-Integer $anchors "INTERRUPT_RECOVERY" "$ScenarioId.named_anchors"
			if ($interruptApplied -le $interruptTell -or
				$interruptApplied -gt $interruptRecovery) {
				throw "Alligator interruption must occur after startup begins and no later than recovery."
			}
			$hit = Get-CaptureAtAnchor $Captures $anchors "HIT_RECOVERY" $ScenarioId
			$whiff = Get-CaptureAtAnchor $Captures $anchors "WHIFF_RECOVERY" $ScenarioId
			$interrupted = Get-CaptureAtAnchor $Captures $anchors "INTERRUPT_RECOVERY" $ScenarioId
			if ([string]$hit.outcome -ne "hit" -or [string]$hit.contact_truth -ne "hit") {
				throw "Alligator hit attempt lacks truthful hit evidence."
			}
			if ([string]$whiff.outcome -ne "whiff" -or [string]$whiff.contact_truth -ne "whiff") {
				throw "Alligator whiff attempt lacks truthful whiff evidence."
			}
			if ([string]$interrupted.outcome -ne "interrupted" -or
				[string]$interrupted.contact_truth -ne "none") {
				throw "Alligator interruption lacks truthful no-contact evidence."
			}
		}
		"alligator_shoreline_transition" {
			$order = @(
				"DRY_START", "MUD_IN", "SHALLOW_IN", "DEEP_IN",
				"SHALLOW_OUT", "MUD_OUT", "DRY_RETURN", "SCENARIO_END"
			)
			Assert-OrderedAnchors $anchors $order $ScenarioId
			$expectedBands = [ordered]@{
				DRY_START = "dry"
				MUD_IN = "mud"
				SHALLOW_IN = "shallow"
				DEEP_IN = "deep"
				SHALLOW_OUT = "shallow"
				MUD_OUT = "mud"
				DRY_RETURN = "dry"
			}
			foreach ($pair in $expectedBands.GetEnumerator()) {
				$state = Get-CaptureAtAnchor $Captures $anchors $pair.Key $ScenarioId
				if ([string]$state.scenario_evidence.presentation_band -ne $pair.Value) {
					throw "Shoreline anchor '$($pair.Key)' must report '$($pair.Value)'."
				}
			}
		}
		"alligator_latch_death_roll" {
			Assert-OrderedAnchors $anchors @(
				"BITE_TEL", "BITE_ACTIVE", "LATCH_ATTACHED", "ROLL_STARTUP",
				"ROLL_CHANNEL", "ROLL_EXIT", "LATCH_RELEASED", "SCENARIO_END"
			) $ScenarioId
			$latched = Get-CaptureAtAnchor $Captures $anchors "LATCH_ATTACHED" $ScenarioId
			$channel = Get-CaptureAtAnchor $Captures $anchors "ROLL_CHANNEL" $ScenarioId
			$released = Get-CaptureAtAnchor $Captures $anchors "LATCH_RELEASED" $ScenarioId
			if ([string]$latched.snapshot.latch_target_id -ne $expectedTarget) {
				throw "Latch evidence does not identify the fixture target."
			}
			if ([string]$channel.scenario_evidence.action_phase -ne "channel") {
				throw "Death Roll channel anchor lacks exact channel evidence."
			}
			if ([string]$released.snapshot.latch_target_id -ne "") {
				throw "Death Roll release anchor retains a stale latch target."
			}
		}
		"alligator_death_respawn" {
			Assert-OrderedAnchors $anchors @(
				"BITE_TEL", "LETHAL_DAMAGE", "DEATH", "RESPAWN",
				"RESPAWN_SETTLED", "SCENARIO_END"
			) $ScenarioId
			$dead = Get-CaptureAtAnchor $Captures $anchors "DEATH" $ScenarioId
			$respawned = Get-CaptureAtAnchor $Captures $anchors "RESPAWN" $ScenarioId
			if ([bool]$dead.snapshot.alive -or -not [bool]$respawned.snapshot.alive) {
				throw "Death/respawn anchors do not prove the production alive transition."
			}
		}
		"alligator_six_actor_density" {
			Assert-OrderedAnchors $anchors @(
				"SPREAD", "CONVERGENCE", "THREE_ATTACKS", "PEAK_EFFECTS",
				"REACQUIRE", "AFTERMATH", "SCENARIO_END"
			) $ScenarioId
			$pressure = Get-CaptureAtAnchor $Captures $anchors "THREE_ATTACKS" $ScenarioId
			$actors = @($pressure.scenario_evidence.actors)
			if ($actors.Count -ne 6) {
				throw "Density evidence must contain exactly six actors."
			}
			$ids = @($actors | ForEach-Object { [string]$_.actor_id } | Sort-Object -Unique)
			$blue = @($actors | Where-Object { [int]$_.team -eq 0 })
			$red = @($actors | Where-Object { [int]$_.team -eq 1 })
			$alligators = @($actors | Where-Object { [string]$_.creature_id -eq "alligator" })
			if ($ids.Count -ne 6 -or $blue.Count -ne 3 -or $red.Count -ne 3 -or
				$alligators.Count -ne 6) {
				throw "Density evidence must prove six unique registered Alligators, three per team."
			}
			if (@($pressure.critical_regions_px.body).Count -ne 6) {
				throw "Density pressure frame must expose six body regions."
			}
		}
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..\..")).Path
$artifactPath = Resolve-RepositoryPath $ArtifactRoot $repoRoot
if (-not (Test-Path -LiteralPath $artifactPath -PathType Container)) {
	throw "ArtifactRoot does not exist: $artifactPath"
}
$manifestPath = Resolve-RepositoryPath $Manifest $repoRoot
$manifestData = Read-JsonFile $manifestPath "Visual manifest"
$semanticSchemaPath = Resolve-RepositoryPath $SemanticSchema $repoRoot
$semanticSchemaData = Read-JsonFile $semanticSchemaPath "Semantic capture schema"
$schemaRequired = @($semanticSchemaData.required | ForEach-Object { [string]$_ })
$schemaProperties = @($semanticSchemaData.properties.PSObject.Properties.Name)
$expectedSchemaVersion = [int64]$semanticSchemaData.properties.schema_version.const
if ($semanticSchemaData.additionalProperties -ne $false -or
	$schemaRequired.Count -eq 0 -or $schemaProperties.Count -eq 0) {
	throw "Semantic capture schema must be closed and declare required properties."
}
$metadataPath = Join-Path $artifactPath "run_metadata.json"
$metadata = Read-JsonFile $metadataPath "Run metadata"

if ([string]::IsNullOrWhiteSpace($CameraPreset)) {
	$CameraPreset = Require-NonEmptyString $metadata "camera_preset" "run_metadata.json"
}
if ([string]::IsNullOrWhiteSpace($CaptureMode)) {
	$CaptureMode = Require-NonEmptyString $metadata "capture_mode" "run_metadata.json"
}
if ($CameraPreset -notin @("PvAI", "Competitive")) {
	throw "Unknown camera preset '$CameraPreset'."
}
if ($CaptureMode -notin @("Diagnostic", "Evaluator", "Performance")) {
	throw "Unknown capture mode '$CaptureMode'."
}
if ((Require-NonEmptyString $metadata "camera_preset" "run_metadata.json") -ne $CameraPreset) {
	throw "Run metadata camera preset does not match '$CameraPreset'."
}
if ((Require-NonEmptyString $metadata "capture_mode" "run_metadata.json") -ne $CaptureMode) {
	throw "Run metadata capture mode does not match '$CaptureMode'."
}

$expectedZoom = @(Get-CameraZoom $CameraPreset)
$metadataZoom = @(Get-ActualZoom $metadata "run_metadata.json")
if (-not (Test-ZoomMatches $metadataZoom $expectedZoom)) {
	throw "Run metadata camera zoom does not match preset '$CameraPreset'."
}

$viewport = Require-Property $manifestData "viewport" "manifest"
$expectedWidth = Require-Integer $viewport "width" "manifest.viewport"
$expectedHeight = Require-Integer $viewport "height" "manifest.viewport"
$expectedRenderer = Require-NonEmptyString $viewport "renderer" "manifest.viewport"
$scenarioEntries = @($manifestData.scenarios)
if (-not [string]::IsNullOrWhiteSpace($Scenario)) {
	$scenarioEntries = @($scenarioEntries | Where-Object { [string]$_.id -eq $Scenario })
}
if ($scenarioEntries.Count -eq 0) {
	throw "No manifest scenario matched '$Scenario'."
}

$semanticFiles = @(
	Get-ChildItem -LiteralPath $artifactPath -Filter "*.json" -File |
		Where-Object { $_.Name -ne "run_metadata.json" }
)
if ($semanticFiles.Count -eq 0) {
	throw "No semantic capture JSON files were found in $artifactPath."
}
$statesByScenario = @{}
foreach ($file in $semanticFiles) {
	if ($file.BaseName -notmatch '^(?<scenario>.+)\.frame_(?<frame>\d{6,})$') {
		throw "Unexpected semantic capture filename: $($file.Name)"
	}
	$filenameScenario = $Matches.scenario
	$filenameFrame = [int64]$Matches.frame
	$state = Read-JsonFile $file.FullName "Semantic capture"
	$pathLabel = $file.Name
	Assert-JsonSchemaValue $state $semanticSchemaData $pathLabel $semanticSchemaData
	foreach ($requiredName in $schemaRequired) {
		$null = Require-Property $state $requiredName $pathLabel
	}
	$unexpectedProperties = @(
		$state.PSObject.Properties.Name |
			Where-Object { $_ -notin $schemaProperties }
	)
	if ($unexpectedProperties.Count -gt 0) {
		throw "$pathLabel contains properties outside the closed semantic schema: $($unexpectedProperties -join ', ')."
	}
	$schemaVersion = Require-Integer $state "schema_version" $pathLabel
	if ($schemaVersion -ne $expectedSchemaVersion) {
		throw "$pathLabel.schema_version must be $expectedSchemaVersion."
	}
	$scenarioId = Require-NonEmptyString $state "scenario_id" $pathLabel
	$frame = Require-Integer $state "frame" $pathLabel
	if ($scenarioId -ne $filenameScenario -or $frame -ne $filenameFrame) {
		throw "$pathLabel does not match its scenario/frame fields."
	}
	$null = Require-NonEmptyString $state "action_id" $pathLabel
	$null = Require-Integer $state "seed" $pathLabel
	$null = Require-Integer $state "tick" $pathLabel
	$null = Require-String $state "actor_id" $pathLabel
	$null = Require-String $state "target_id" $pathLabel
	$snapshot = Require-Property $state "snapshot" $pathLabel
	if ($snapshot -isnot [pscustomobject]) {
		throw "$pathLabel.snapshot must be a JSON object."
	}
	$phase = Require-NonEmptyString $state "phase" $pathLabel
	$outcome = Require-NonEmptyString $state "outcome" $pathLabel
	$null = Require-Boolean $state "projected_contact" $pathLabel
	$contactTruth = Require-NonEmptyString $state "contact_truth" $pathLabel
	$null = Require-NonEmptyString $state "terrain" $pathLabel
	$depth = Require-Property $state "depth" $pathLabel
	if ($depth -isnot [pscustomobject]) {
		throw "$pathLabel.depth must be a JSON object."
	}
	$criticalRegions = Require-Property $state "critical_regions_px" $pathLabel
	$regionCount = 0
	foreach ($regionKind in @("body", "contact", "telegraph")) {
		$regions = @(Require-Property $criticalRegions $regionKind "$pathLabel.critical_regions_px")
		foreach ($region in $regions) {
			$x = Require-Integer $region "x" "$pathLabel.critical_regions_px.$regionKind"
			$y = Require-Integer $region "y" "$pathLabel.critical_regions_px.$regionKind"
			$width = Require-Integer $region "width" "$pathLabel.critical_regions_px.$regionKind"
			$height = Require-Integer $region "height" "$pathLabel.critical_regions_px.$regionKind"
			if ($width -lt 1 -or $height -lt 1 -or $x -lt 0 -or $y -lt 0 -or
				$x + $width -gt $expectedWidth -or $y + $height -gt $expectedHeight) {
				throw "$pathLabel critical region '$regionKind' is empty or outside the viewport."
			}
			$regionCount++
		}
	}
	if ($regionCount -eq 0) {
		throw "$pathLabel has an empty critical region union."
	}
	if ($phase -notin @("idle", "startup", "active", "recovery")) {
		throw "$pathLabel.phase is outside the closed vocabulary."
	}
	if ($outcome -notin @("none", "hit", "whiff", "released", "interrupted")) {
		throw "$pathLabel.outcome is outside the closed vocabulary."
	}
	if ($contactTruth -notin @("none", "hit", "whiff", "blocked")) {
		throw "$pathLabel.contact_truth is outside the closed vocabulary."
	}
	$anchors = Require-Property $state "named_anchors" $pathLabel
	if ($anchors -isnot [pscustomobject]) {
		throw "$pathLabel.named_anchors must be a JSON object."
	}
	foreach ($anchorProperty in $anchors.PSObject.Properties) {
		$anchorValue = Require-Integer $anchors $anchorProperty.Name "$pathLabel.named_anchors"
		if ($anchorValue -lt 0) {
			throw "$pathLabel.named_anchors.$($anchorProperty.Name) must be non-negative."
		}
	}
	$stateCamera = Require-NonEmptyString $state "camera_preset" $pathLabel
	$stateMode = Require-NonEmptyString $state "capture_mode" $pathLabel
	if ($stateCamera -ne $CameraPreset -or $stateMode -ne $CaptureMode) {
		throw "$pathLabel reports the wrong camera preset or capture mode."
	}
	$actualZoom = @(Get-ActualZoom $state $pathLabel)
	if (-not (Test-ZoomMatches $actualZoom $expectedZoom)) {
		throw "$pathLabel reports the wrong camera zoom."
	}
	$stateViewport = Require-Property $state "viewport" $pathLabel
	if ((Require-Integer $stateViewport "width" "$pathLabel.viewport") -ne $expectedWidth -or
		(Require-Integer $stateViewport "height" "$pathLabel.viewport") -ne $expectedHeight) {
		throw "$pathLabel reports the wrong viewport."
	}
	if ((Get-ActualRenderer $state $pathLabel) -ne $expectedRenderer) {
		throw "$pathLabel reports the wrong active renderer."
	}
	$diagnosticLabels = Require-Boolean $state "diagnostic_labels" $pathLabel
	$readbackCount = Require-Integer $state "screenshot_readback_count" $pathLabel
	if ($CaptureMode -eq "Evaluator" -and $diagnosticLabels) {
		throw "$pathLabel enables diagnostic labels in Evaluator mode."
	}
	if ($CaptureMode -eq "Performance" -and $readbackCount -ne 0) {
		throw "$pathLabel reports screenshot readback in Performance mode."
	}
	if ($CaptureMode -ne "Performance" -and $readbackCount -lt 1) {
		throw "$pathLabel reports no screenshot readback in a screenshot-producing mode."
	}

	$pngPath = Join-Path $artifactPath "$($file.BaseName).png"
	if ($CaptureMode -eq "Performance") {
		if (Test-Path -LiteralPath $pngPath) {
			throw "Performance mode emitted an unexpected PNG: $pngPath"
		}
		$pngHash = Require-Property $state "png_sha256" $pathLabel
		if ($null -ne $pngHash -and -not [string]::IsNullOrEmpty([string]$pngHash)) {
			throw "$pathLabel must not report a PNG hash in Performance mode."
		}
	} else {
		if (-not (Test-Path -LiteralPath $pngPath -PathType Leaf) -or
			(Get-Item -LiteralPath $pngPath).Length -le 0) {
			throw "Expected screenshot is missing or empty: $pngPath"
		}
		$expectedHash = Require-NonEmptyString $state "png_sha256" $pathLabel
		$actualHash = (Get-FileHash -LiteralPath $pngPath -Algorithm SHA256).Hash.ToLowerInvariant()
		if ($expectedHash.ToLowerInvariant() -ne $actualHash) {
			throw "$pathLabel PNG hash does not match its screenshot."
		}
	}

	if (-not $statesByScenario.ContainsKey($scenarioId)) {
		$statesByScenario[$scenarioId] = @()
	}
	$statesByScenario[$scenarioId] += [pscustomobject]@{
		Frame = $frame
		State = $state
		Path = $pathLabel
	}
}

foreach ($scenarioEntry in $scenarioEntries) {
	$scenarioId = [string]$scenarioEntry.id
	if (-not $statesByScenario.ContainsKey($scenarioId)) {
		throw "Scenario '$scenarioId' has no semantic captures."
	}
	$captures = @($statesByScenario[$scenarioId] | Sort-Object Frame)
	$requiredAnchors = @($scenarioEntry.required_anchors | ForEach-Object { [string]$_ })
	$referenceAnchorSignature = Get-AnchorSignature $captures[0].State.named_anchors "$($captures[0].Path).named_anchors"
	foreach ($capture in $captures) {
		$anchorSignature = Get-AnchorSignature $capture.State.named_anchors "$($capture.Path).named_anchors"
		if ($anchorSignature -ne $referenceAnchorSignature) {
			throw "Scenario '$scenarioId' named anchors differ across semantic captures."
		}
		foreach ($requiredAnchor in $requiredAnchors) {
			$null = Require-Integer $capture.State.named_anchors $requiredAnchor "$($capture.Path).named_anchors"
		}
		if ([string]$capture.State.actor_id -ne [string]$capture.State.snapshot.actor_id) {
			throw "$($capture.Path) actor_id does not match snapshot.actor_id."
		}
		if ([int64]$capture.State.tick -ne [int64]$capture.State.snapshot.simulation_tick) {
			throw "$($capture.Path) tick does not match snapshot.simulation_tick."
		}
	}
	$actualFrames = @($captures | ForEach-Object { [int64]$_.Frame })
	$expectedFrames = @(
		Get-ExpectedFrames `
			$scenarioEntry `
			$captures[0].State `
			$captures[0].Path `
			$actualFrames
	)
	if (($expectedFrames -join ",") -ne ($actualFrames -join ",")) {
		throw "Scenario '$scenarioId' frames differ. Expected [$($expectedFrames -join ', ')], got [$($actualFrames -join ', ')]."
	}
	Assert-R2CScenarioEvidence $scenarioId $captures
}

$selectedIds = @($scenarioEntries | ForEach-Object { [string]$_.id })
$unexpectedIds = @($statesByScenario.Keys | Where-Object { $_ -notin $selectedIds })
if ($unexpectedIds.Count -gt 0) {
	throw "Unexpected scenario captures were found: $($unexpectedIds -join ', ')."
}
$allPngFiles = @(Get-ChildItem -LiteralPath $artifactPath -Filter "*.png" -File)
if ($CaptureMode -eq "Performance" -and $allPngFiles.Count -gt 0) {
	throw "Performance mode emitted PNG artifacts."
}
if ($CaptureMode -ne "Performance" -and $allPngFiles.Count -ne $semanticFiles.Count) {
	throw "PNG/semantic capture counts differ: $($allPngFiles.Count) PNG, $($semanticFiles.Count) semantic."
}

Write-Host "Visual capture artifacts passed: $($semanticFiles.Count) semantic captures ($CameraPreset/$CaptureMode)."
exit 0
