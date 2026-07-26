param(
	[string]$Godot = "",
	[ValidateSet("Legacy", "StageB5", "StageB15", "StageCMain", "StageCExtended", "Full")]
	[string]$Stage = "Legacy",
	[ValidateSet("Mirror", "SideNeutral", "All")]
	[string]$PairingMode = "Mirror",
	[string[]]$SquadIds = @("S1", "S2", "S3", "S4", "S5", "S6", "S7"),
	[long[]]$Seeds = @(7, 101),
	[int]$WorkerCount = 4,
	[int]$MaxJobs = 32,
	[double]$MaxSimSeconds = 180.0,
	[double]$ChecksumSeconds = 30.0,
	[int]$TimeoutSec = 120,
	[string]$OutputRoot = "",
	[switch]$ValidateOnly,
	[switch]$Smoke,
	[switch]$Profile,
	[scriptblock]$BuildIdentityProvider = $null
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$MatrixSchema = "battle_bog.balance_matrix.v3"
$ResultSchema = "battle_bog.balance_sim.v1"
$ResultMetadataSchema = "battle_bog.balance_matrix_result.v1"
$ExpectedRulesetId = "competitive_3v3"
$ExpectedRulesSchemaVersion = 1
$StandardSeeds = @(7L, 19L, 43L, 71L, 101L, 149L, 211L, 307L)
$Squads = [ordered]@{
	S1 = @("snapping_turtle", "chorus_frog", "mink")
	S2 = @("beaver", "duck", "firefly")
	S3 = @("owl", "great_blue_heron", "kingfisher")
	S4 = @("cane_toad", "newt", "crayfish")
	S5 = @("alligator", "water_snake", "bullfrog")
	S6 = @("otter", "mosquito_swarm", "leech")
	S7 = @("bog_turtle", "water_shrew", "wolf_spider")
}

function Write-Utf8NoBom {
	param(
		[string]$Path,
		[string[]]$Lines
	)
	$encoding = New-Object System.Text.UTF8Encoding($false)
	$text = $Lines -join [Environment]::NewLine
	if ($Lines.Count -gt 0) {
		$text += [Environment]::NewLine
	}
	[System.IO.File]::WriteAllText($Path, $text, $encoding)
}

function Get-Sha256 {
	param([string]$Text)
	$sha = [System.Security.Cryptography.SHA256]::Create()
	try {
		$bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
		return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
	} finally {
		$sha.Dispose()
	}
}

function Write-JsonAtomic {
	param(
		[string]$Path,
		[object]$Value,
		[int]$Depth = 12
	)
	$tempPath = "$Path.tmp-$PID"
	try {
		Write-Utf8NoBom -Path $tempPath `
			-Lines @(($Value | ConvertTo-Json -Depth $Depth))
		Move-Item -LiteralPath $tempPath -Destination $Path -Force
	} finally {
		Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
	}
}

function Invoke-GitLines {
	param(
		[string]$RepoRoot,
		[string[]]$Arguments
	)
	$lines = @(& git -C $RepoRoot @Arguments)
	if ($LASTEXITCODE -ne 0) {
		throw "Git command failed: git $($Arguments -join ' ')"
	}
	return @($lines | ForEach-Object { $_.ToString().Trim() } | Where-Object {
		-not [string]::IsNullOrWhiteSpace($_)
	})
}

function Get-PathFingerprint {
	param(
		[string]$RepoRoot,
		[string[]]$RelativePaths
	)
	$lines = @($RelativePaths | Sort-Object -Unique | ForEach-Object {
		$relativePath = $_.Replace("\", "/")
		$absolutePath = Join-Path $RepoRoot $relativePath
		if (Test-Path -LiteralPath $absolutePath -PathType Leaf) {
			$fileHash = (Get-FileHash -Algorithm SHA256 `
				-LiteralPath $absolutePath).Hash.ToLowerInvariant()
			"file`t$relativePath`t$fileHash"
		} elseif (Test-Path -LiteralPath $absolutePath) {
			"non_file`t$relativePath"
		} else {
			"missing`t$relativePath"
		}
	})
	return [pscustomobject]@{
		Sha256 = Get-Sha256 -Text ($lines -join "`n")
		Lines = $lines
	}
}

function Get-BuildIdentity {
	param(
		[string]$RepoRoot,
		[string]$RunnerPath
	)
	$pathspecs = @(
		"project.godot",
		"assets",
		"data",
		"scenes",
		"scripts/ai",
		"scripts/data",
		"scripts/game",
		"scripts/sim",
		"scripts/ui",
		"scripts/visual",
		"scripts/test/run_balance_matrix.ps1",
		"scripts/test/run_balance_sim.ps1",
		"scripts/test/run_balance_sim.gd"
	)
	$headLines = @(Invoke-GitLines -RepoRoot $RepoRoot `
		-Arguments @("rev-parse", "HEAD"))
	if ($headLines.Count -ne 1) {
		throw "Could not resolve exactly one git HEAD."
	}
	$tracked = @(Invoke-GitLines -RepoRoot $RepoRoot `
		-Arguments (@("ls-files", "--") + $pathspecs))
	$untracked = @(Invoke-GitLines -RepoRoot $RepoRoot `
		-Arguments (@("ls-files", "--others", "--exclude-standard", "--") + $pathspecs))
	$changed = @(Invoke-GitLines -RepoRoot $RepoRoot `
		-Arguments (@("-c", "core.safecrlf=false", "diff", "--name-only",
			"--no-renames", "HEAD", "--") + $pathspecs))
	$dirtyPaths = @($changed + $untracked | Sort-Object -Unique)
	$sourcePaths = @($tracked + $untracked | Sort-Object -Unique)
	$sourceFingerprint = Get-PathFingerprint -RepoRoot $RepoRoot `
		-RelativePaths $sourcePaths
	$dirtyFingerprint = Get-PathFingerprint -RepoRoot $RepoRoot `
		-RelativePaths $dirtyPaths
	$runnerGdPath = [System.IO.Path]::ChangeExtension($RunnerPath, ".gd")
	if (-not (Test-Path -LiteralPath $runnerGdPath -PathType Leaf)) {
		throw "Missing Godot balance runner '$runnerGdPath'."
	}
	$identityContract = [ordered]@{
		git_head = [string]$headLines[0]
		source_tree_sha256 = [string]$sourceFingerprint.Sha256
		source_file_count = $sourcePaths.Count
		dirty_worktree_sha256 = [string]$dirtyFingerprint.Sha256
		dirty = $dirtyPaths.Count -gt 0
		dirty_paths = @($dirtyPaths)
		runner_ps1_sha256 = (
			Get-FileHash -Algorithm SHA256 -LiteralPath $RunnerPath
		).Hash.ToLowerInvariant()
		runner_gd_sha256 = (
			Get-FileHash -Algorithm SHA256 -LiteralPath $runnerGdPath
		).Hash.ToLowerInvariant()
	}
	$identityJson = $identityContract | ConvertTo-Json -Depth 5 -Compress
	return [ordered]@{
		schema = "battle_bog.build_identity.v1"
		identity_sha256 = Get-Sha256 -Text $identityJson
		contract = $identityContract
	}
}

function Resolve-BuildIdentity {
	param(
		[string]$RepoRoot,
		[string]$RunnerPath
	)
	$identity = if ($null -ne $BuildIdentityProvider) {
		& $BuildIdentityProvider $RepoRoot $RunnerPath
	} else {
		Get-BuildIdentity -RepoRoot $RepoRoot -RunnerPath $RunnerPath
	}
	if (
		$null -eq $identity -or
		[string]::IsNullOrWhiteSpace([string]$identity.identity_sha256)
	) {
		throw "Build identity provider returned no deterministic identity."
	}
	return $identity
}

function Assert-BuildIdentityUnchanged {
	param(
		[string]$ExpectedSha256,
		[string]$Phase,
		[string]$RepoRoot,
		[string]$RunnerPath
	)
	$currentIdentity = Resolve-BuildIdentity -RepoRoot $RepoRoot `
		-RunnerPath $RunnerPath
	$currentSha256 = [string]$currentIdentity.identity_sha256
	if ($currentSha256 -ne $ExpectedSha256) {
		throw "Build identity changed $Phase. Matrix aborted before accepting or merging cross-build results."
	}
}

function Enter-OutputRootLock {
	param([string]$ResolvedOutputRoot)
	$lockPath = Join-Path $ResolvedOutputRoot ".balance-matrix.lock"
	try {
		$stream = New-Object System.IO.FileStream(
			$lockPath,
			[System.IO.FileMode]::OpenOrCreate,
			[System.IO.FileAccess]::ReadWrite,
			[System.IO.FileShare]::None
		)
	} catch [System.IO.IOException] {
		throw "OutputRoot '$ResolvedOutputRoot' is already owned by another balance-matrix launcher."
	}
	try {
		$owner = [ordered]@{
			process_id = $PID
			acquired_utc = [DateTime]::UtcNow.ToString("o")
			output_root = $ResolvedOutputRoot
		} | ConvertTo-Json -Compress
		$bytes = [System.Text.Encoding]::UTF8.GetBytes($owner)
		$stream.SetLength(0)
		$stream.Write($bytes, 0, $bytes.Length)
		$stream.Flush()
		return $stream
	} catch {
		$stream.Dispose()
		throw
	}
}

function Assert-ExactArray {
	param(
		[string]$Label,
		[object[]]$Actual,
		[object[]]$Expected
	)
	if ($Actual.Count -ne $Expected.Count) {
		throw "$Label count $($Actual.Count) did not match $($Expected.Count)."
	}
	for ($index = 0; $index -lt $Expected.Count; $index++) {
		if ([string]$Actual[$index] -ne [string]$Expected[$index]) {
			throw "$Label item $index '$($Actual[$index])' did not match '$($Expected[$index])'."
		}
	}
}

function Get-LegacyJobSpecs {
	param(
		[string]$Mode,
		[string[]]$SelectedSquads,
		[long[]]$SelectedSeeds,
		[double]$DurationSeconds
	)
	$pairs = @()
	if ($Mode -in @("Mirror", "All")) {
		foreach ($squadId in $SelectedSquads) {
			$pairs += [pscustomobject]@{ Blue = $squadId; Red = $squadId }
		}
	}
	if ($Mode -in @("SideNeutral", "All")) {
		for ($left = 0; $left -lt $SelectedSquads.Count; $left++) {
			for ($right = $left + 1; $right -lt $SelectedSquads.Count; $right++) {
				$pairs += [pscustomobject]@{
					Blue = $SelectedSquads[$left]
					Red = $SelectedSquads[$right]
				}
				$pairs += [pscustomobject]@{
					Blue = $SelectedSquads[$right]
					Red = $SelectedSquads[$left]
				}
			}
		}
	}

	$jobs = @()
	$ordinal = 0
	foreach ($pair in $pairs) {
		foreach ($seed in $SelectedSeeds) {
			$ordinal++
			$jobs += [pscustomobject]@{
				Ordinal = $ordinal
				StageOrdinal = $ordinal
				Stage = "Legacy"
				BlueSquad = [string]$pair.Blue
				RedSquad = [string]$pair.Red
				BlueRoster = [string[]]$Squads[[string]$pair.Blue]
				RedRoster = [string[]]$Squads[[string]$pair.Red]
				Seed = [long]$seed
				MaxSimSeconds = [double]$DurationSeconds
			}
		}
	}
	return $jobs
}

function Get-NamedStageJobSpecs {
	param([string]$SelectedStage)

	$stageNames = if ($SelectedStage -eq "Full") {
		@("StageB5", "StageB15", "StageCMain", "StageCExtended")
	} else {
		@($SelectedStage)
	}
	$jobs = New-Object System.Collections.Generic.List[object]
	$ordinal = 0

	foreach ($stageName in $stageNames) {
		$durationSeconds = switch ($stageName) {
			"StageB5" { 300.0 }
			"StageB15" { 900.0 }
			"StageCMain" { 900.0 }
			"StageCExtended" { 1500.0 }
			default { throw "Unknown named matrix stage '$stageName'." }
		}
		$stageSeeds = if ($stageName -in @("StageB5", "StageB15")) {
			@(7L, 101L)
		} else {
			@($StandardSeeds)
		}
		$pairs = New-Object System.Collections.Generic.List[object]

		if ($stageName -in @("StageB5", "StageB15")) {
			foreach ($squadId in $Squads.Keys) {
				$pairs.Add([pscustomobject]@{
					Blue = [string]$squadId
					Red = [string]$squadId
				})
			}
		} elseif ($stageName -eq "StageCMain") {
			$squadKeys = @($Squads.Keys)
			for ($left = 0; $left -lt $squadKeys.Count; $left++) {
				for ($right = $left + 1; $right -lt $squadKeys.Count; $right++) {
					$pairs.Add([pscustomobject]@{
						Blue = [string]$squadKeys[$left]
						Red = [string]$squadKeys[$right]
					})
					$pairs.Add([pscustomobject]@{
						Blue = [string]$squadKeys[$right]
						Red = [string]$squadKeys[$left]
					})
				}
			}
		} else {
			$adjacentPairs = @(
				@("S1", "S2"),
				@("S2", "S3"),
				@("S3", "S4"),
				@("S4", "S5"),
				@("S5", "S6"),
				@("S6", "S7"),
				@("S7", "S1")
			)
			foreach ($pair in $adjacentPairs) {
				$pairs.Add([pscustomobject]@{
					Blue = [string]$pair[0]
					Red = [string]$pair[1]
				})
				$pairs.Add([pscustomobject]@{
					Blue = [string]$pair[1]
					Red = [string]$pair[0]
				})
			}
		}

		$stageOrdinal = 0
		foreach ($pair in $pairs) {
			foreach ($seed in $stageSeeds) {
				$ordinal++
				$stageOrdinal++
				$jobs.Add([pscustomobject]@{
					Ordinal = $ordinal
					StageOrdinal = $stageOrdinal
					Stage = $stageName
					BlueSquad = [string]$pair.Blue
					RedSquad = [string]$pair.Red
					BlueRoster = [string[]]$Squads[[string]$pair.Blue]
					RedRoster = [string[]]$Squads[[string]$pair.Red]
					Seed = [long]$seed
					MaxSimSeconds = [double]$durationSeconds
				})
			}
		}
	}
	return @($jobs | ForEach-Object { $_ })
}

function Get-StageSummary {
	param([object[]]$JobSpecs)

	$stageOrder = @("Legacy", "StageB5", "StageB15", "StageCMain", "StageCExtended")
	$summary = @()
	foreach ($stageName in $stageOrder) {
		$stageJobs = @($JobSpecs | Where-Object { $_.Stage -eq $stageName })
		if ($stageJobs.Count -eq 0) {
			continue
		}
		$durations = @($stageJobs | ForEach-Object { [double]$_.MaxSimSeconds } |
			Select-Object -Unique)
		if ($durations.Count -ne 1) {
			throw "Stage '$stageName' contains mixed simulated durations."
		}
		$summary += [pscustomobject]@{
			Stage = $stageName
			Count = $stageJobs.Count
			MaxSimSeconds = [double]$durations[0]
		}
	}
	return $summary
}

function Get-DurationToken {
	param([double]$DurationSeconds)
	$token = $DurationSeconds.ToString(
		"0.###",
		[System.Globalization.CultureInfo]::InvariantCulture
	)
	return $token.Replace(".", "p")
}

function Read-ValidatedResult {
	param(
		[object]$Spec,
		[string]$ResultPath,
		[string]$RunId,
		[string]$BuildIdentitySha256,
		[string]$ExpectedRulesFingerprint,
		[switch]$RequireMetadata
	)
	if (-not (Test-Path -LiteralPath $ResultPath -PathType Leaf)) {
		return $null
	}
	$lines = @(Get-Content -LiteralPath $ResultPath | Where-Object {
		-not [string]::IsNullOrWhiteSpace($_)
	})
	if ($lines.Count -ne 1) {
		throw "Existing job '$RunId' has $($lines.Count) result records; expected exactly one."
	}
	try {
		$record = $lines[0] | ConvertFrom-Json -ErrorAction Stop
	} catch {
		throw "Existing job '$RunId' contains invalid JSON: $($_.Exception.Message)"
	}
	if ([string]$record.schema -ne $ResultSchema) {
		throw "Existing job '$RunId' has unexpected schema '$($record.schema)'."
	}
	if ([string]$record.run_id -ne $RunId) {
		throw "Existing job '$RunId' contains run id '$($record.run_id)'."
	}
	$acceptedStatuses = if ($ValidateOnly) { @("validation_ok") } else { @("completed", "timeout") }
	if ([string]$record.status -notin $acceptedStatuses) {
		throw "Existing job '$RunId' has non-resumable status '$($record.status)'."
	}
	Assert-ExactArray -Label "$RunId Blue roster" `
		-Actual @($record.requested.blue_roster) -Expected @($Spec.BlueRoster)
	Assert-ExactArray -Label "$RunId Red roster" `
		-Actual @($record.requested.red_roster) -Expected @($Spec.RedRoster)
	if ([long]$record.requested.simulation_seed -ne [long]$Spec.Seed) {
		throw "Existing job '$RunId' has the wrong simulation seed."
	}
	if ([double]$record.requested.max_simulated_sec -ne [double]$Spec.MaxSimSeconds) {
		throw "Existing job '$RunId' has a different simulated duration."
	}
	if ([double]$record.requested.checksum_interval_sec -ne $ChecksumSeconds) {
		throw "Existing job '$RunId' has a different checksum interval."
	}
	$rulesFingerprint = ""
	if (-not $ValidateOnly) {
		if (-not ($record.PSObject.Properties.Name -contains "match")) {
			throw "Existing job '$RunId' does not contain a match summary."
		}
		if ([string]$record.match.ruleset_id -ne $ExpectedRulesetId) {
			throw "Existing job '$RunId' has unexpected ruleset '$($record.match.ruleset_id)'."
		}
		if ([int]$record.match.rules_schema_version -ne $ExpectedRulesSchemaVersion) {
			throw "Existing job '$RunId' has unexpected rules schema version."
		}
		$rulesFingerprint = [string]$record.match.rules_fingerprint
		if ([string]::IsNullOrWhiteSpace($rulesFingerprint)) {
			throw "Existing job '$RunId' has no runtime rules fingerprint."
		}
		if (
			-not [string]::IsNullOrWhiteSpace($ExpectedRulesFingerprint) -and
			$rulesFingerprint -ne $ExpectedRulesFingerprint
		) {
			throw "Existing job '$RunId' has runtime rules fingerprint '$rulesFingerprint'; expected '$ExpectedRulesFingerprint'."
		}
	}

	$resultHash = (Get-FileHash -Algorithm SHA256 `
		-LiteralPath $ResultPath).Hash.ToLowerInvariant()
	$metadataPath = Join-Path (Split-Path -Parent $ResultPath) `
		"matrix-result-metadata.json"
	if ($RequireMetadata) {
		if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
			throw "Existing job '$RunId' is missing matrix result metadata."
		}
		try {
			$metadata = Get-Content -LiteralPath $metadataPath -Raw |
				ConvertFrom-Json -ErrorAction Stop
		} catch {
			throw "Existing job '$RunId' has invalid matrix result metadata: $($_.Exception.Message)"
		}
		if ([string]$metadata.schema -ne $ResultMetadataSchema) {
			throw "Existing job '$RunId' has unexpected matrix result metadata schema."
		}
		if ([string]$metadata.run_id -ne $RunId) {
			throw "Existing job '$RunId' has mismatched matrix result metadata."
		}
		if ([string]$metadata.build_identity_sha256 -ne $BuildIdentitySha256) {
			throw "Existing job '$RunId' was produced by a different build identity."
		}
		if ([string]$metadata.result_sha256 -ne $resultHash) {
			throw "Existing job '$RunId' changed after its matrix metadata was written."
		}
		if ([string]$metadata.rules_fingerprint -ne $rulesFingerprint) {
			throw "Existing job '$RunId' matrix metadata has a different rules fingerprint."
		}
	}
	return [pscustomobject]@{
		Record = $record
		ResultSha256 = $resultHash
		RulesFingerprint = $rulesFingerprint
		MetadataPath = $metadataPath
	}
}

function Write-ResultMetadata {
	param(
		[string]$RunId,
		[string]$BuildIdentitySha256,
		[object]$ValidatedResult
	)
	$metadata = [ordered]@{
		schema = $ResultMetadataSchema
		run_id = $RunId
		build_identity_sha256 = $BuildIdentitySha256
		result_sha256 = [string]$ValidatedResult.ResultSha256
		rules_fingerprint = [string]$ValidatedResult.RulesFingerprint
	}
	Write-JsonAtomic -Path $ValidatedResult.MetadataPath -Value $metadata -Depth 4
}

function Start-MatrixJob {
	param(
		[object]$Spec,
		[string]$RunId,
		[string]$JobDirectory,
		[string]$RunnerPath
	)
	New-Item -ItemType Directory -Force -Path $JobDirectory | Out-Null
	$resultPath = Join-Path $JobDirectory "result.jsonl"
	$parameters = @{
		BlueRoster = [string[]]$Spec.BlueRoster
		RedRoster = [string[]]$Spec.RedRoster
		Seed = [long]$Spec.Seed
		MaxSimSeconds = [double]$Spec.MaxSimSeconds
		ChecksumSeconds = $ChecksumSeconds
		OutputPath = $resultPath
		RunId = $RunId
		TimeoutSec = $TimeoutSec
	}
	if (-not [string]::IsNullOrWhiteSpace($Godot)) {
		$parameters.Godot = $Godot
	}
	if ($ValidateOnly) {
		$parameters.ValidateOnly = $true
	}
	if ($Smoke) {
		$parameters.Smoke = $true
	}
	if ($Profile) {
		$parameters.Profile = $true
	}

	return Start-Job -ArgumentList $RunnerPath, $parameters -ScriptBlock {
		param(
			[string]$InnerRunner,
			[hashtable]$InnerParameters
		)
		$exitCode = 0
		try {
			$lines = & $InnerRunner @InnerParameters 2>&1 |
				ForEach-Object { $_.ToString() }
		} catch {
			$exitCode = 1
			$lines = @($_.Exception.Message, $_.ScriptStackTrace)
		}
		[pscustomobject]@{
			ExitCode = $exitCode
			Output = ($lines -join [Environment]::NewLine)
		}
	}
}

if ($WorkerCount -lt 1 -or $WorkerCount -gt 16) {
	throw "WorkerCount must be between 1 and 16."
}
if ($MaxJobs -lt 1) {
	throw "MaxJobs must be at least 1."
}
if ($TimeoutSec -lt 1) {
	throw "TimeoutSec must be at least 1."
}
if ($MaxSimSeconds -le 0.0) {
	throw "MaxSimSeconds must be greater than zero."
}
if ($ChecksumSeconds -le 0.0) {
	throw "ChecksumSeconds must be greater than zero."
}
if ($ValidateOnly -and $Smoke) {
	throw "ValidateOnly and Smoke are mutually exclusive."
}
$namedStage = $Stage -ne "Legacy"
if ($namedStage) {
	$conflictingParameters = @(@(
		"PairingMode",
		"SquadIds",
		"Seeds",
		"MaxSimSeconds"
	) | Where-Object { $PSBoundParameters.ContainsKey($_) })
	if ($conflictingParameters.Count -gt 0) {
		throw "Named stage '$Stage' owns pairing, squads, seeds, and duration; remove: $($conflictingParameters -join ', ')."
	}
	if ($Smoke) {
		throw "Smoke is only supported for legacy pairing plans; named stages retain canonical durations."
	}
} else {
	if ($SquadIds.Count -lt 1) {
		throw "At least one squad id is required."
	}
	if (@($SquadIds | Select-Object -Unique).Count -ne $SquadIds.Count) {
		throw "SquadIds must not contain duplicates."
	}
	foreach ($squadId in $SquadIds) {
		if (-not $Squads.Contains($squadId)) {
			throw "Unknown squad id '$squadId'. Expected one of: $($Squads.Keys -join ', ')."
		}
	}
	if ($Seeds.Count -lt 1) {
		throw "At least one standard seed is required."
	}
	if (@($Seeds | Select-Object -Unique).Count -ne $Seeds.Count) {
		throw "Seeds must not contain duplicates."
	}
	foreach ($seed in $Seeds) {
		if ($seed -notin $StandardSeeds) {
			throw "Seed '$seed' is not a standard seed. Expected one of: $($StandardSeeds -join ', ')."
		}
	}
	if ($PairingMode -eq "SideNeutral" -and $SquadIds.Count -lt 2) {
		throw "SideNeutral pairing requires at least two squads."
	}

	# Normalize caller order so equivalent selections always produce the same plan.
	$SquadIds = @($Squads.Keys | Where-Object { $_ -in $SquadIds })
	$Seeds = @($StandardSeeds | Where-Object { $_ -in $Seeds })

	if ($Smoke) {
		if (-not $PSBoundParameters.ContainsKey("MaxSimSeconds")) {
			$MaxSimSeconds = 2.0
		}
		if (-not $PSBoundParameters.ContainsKey("ChecksumSeconds")) {
			$ChecksumSeconds = 1.0
		}
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..\..")).Path
$runnerPath = Join-Path $scriptRoot "run_balance_sim.ps1"
if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) {
	throw "Missing single-match runner '$runnerPath'."
}
$buildIdentity = Resolve-BuildIdentity -RepoRoot $repoRoot -RunnerPath $runnerPath
$buildIdentitySha256 = [string]$buildIdentity.identity_sha256
$jobSpecs = @(if ($namedStage) {
	Get-NamedStageJobSpecs -SelectedStage $Stage
} else {
	Get-LegacyJobSpecs -Mode $PairingMode -SelectedSquads $SquadIds `
		-SelectedSeeds $Seeds -DurationSeconds $MaxSimSeconds
})
if ($jobSpecs.Count -lt 1) {
	throw "The selected pairing mode, squads, and seeds produced no jobs."
}

$jobIdentities = New-Object System.Collections.Generic.HashSet[string]
foreach ($spec in $jobSpecs) {
	$durationIdentity = [double]$spec.MaxSimSeconds
	$identity = "{0}|{1}|{2}|{3}|{4}" -f $spec.Stage, $spec.BlueSquad,
		$spec.RedSquad, $spec.Seed, $durationIdentity.ToString(
			"R",
			[System.Globalization.CultureInfo]::InvariantCulture
		)
	if (-not $jobIdentities.Add($identity)) {
		throw "Matrix plan contains duplicate job identity '$identity'."
	}
}
$stageSummary = @(Get-StageSummary -JobSpecs $jobSpecs)
$stageSummaryText = @($stageSummary | ForEach-Object {
	"{0}={1}@{2}s" -f $_.Stage, $_.Count, (
		[double]$_.MaxSimSeconds
	).ToString("0.###", [System.Globalization.CultureInfo]::InvariantCulture)
}) -join ", "
if ($jobSpecs.Count -gt $MaxJobs) {
	throw "Plan contains $($jobSpecs.Count) jobs ($stageSummaryText), exceeding MaxJobs=$MaxJobs. Increase MaxJobs explicitly after reviewing the workload."
}

$contractSquads = if ($namedStage) {
	@($Squads.Keys | Where-Object {
		$_ -in @($jobSpecs.BlueSquad) -or $_ -in @($jobSpecs.RedSquad)
	})
} else {
	@($SquadIds)
}
$contractSeeds = if ($namedStage) {
	@($StandardSeeds | Where-Object { $_ -in @($jobSpecs.Seed) })
} else {
	@($Seeds)
}
$contract = [ordered]@{
	schema = $MatrixSchema
	build_identity = $buildIdentity
	stage = $Stage
	pairing_mode = if ($namedStage) { $null } else { $PairingMode }
	squad_ids = @($contractSquads)
	seeds = @($contractSeeds)
	max_simulated_sec = if ($namedStage) { $null } else { $MaxSimSeconds }
	checksum_interval_sec = $ChecksumSeconds
	validation_only = [bool]$ValidateOnly
	smoke = [bool]$Smoke
	profile = [bool]$Profile
	stage_summary = @($stageSummary | ForEach-Object {
		[ordered]@{
			stage = $_.Stage
			job_count = $_.Count
			max_simulated_sec = $_.MaxSimSeconds
		}
	})
	jobs = @($jobSpecs | ForEach-Object {
		[ordered]@{
			ordinal = $_.Ordinal
			stage_ordinal = $_.StageOrdinal
			stage = $_.Stage
			blue_squad = $_.BlueSquad
			red_squad = $_.RedSquad
			blue_roster = @($_.BlueRoster)
			red_roster = @($_.RedRoster)
			seed = $_.Seed
			max_simulated_sec = $_.MaxSimSeconds
		}
	})
}
$contractJson = $contract | ConvertTo-Json -Depth 8 -Compress
$planHash = Get-Sha256 -Text $contractJson
$planLabel = if ($namedStage) { $Stage } else { $PairingMode }
$planId = "{0}-{1}" -f $planLabel.ToLowerInvariant(), $planHash.Substring(0, 12)

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
	$OutputRoot = Join-Path $repoRoot "artifacts\balance-matrix\$planId"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputRoot)) {
	$OutputRoot = Join-Path $repoRoot $OutputRoot
}
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$OutputRoot = (Resolve-Path -LiteralPath $OutputRoot).Path
$outputRootLock = Enter-OutputRootLock -ResolvedOutputRoot $OutputRoot
try {
$jobsRoot = Join-Path $OutputRoot "jobs"
New-Item -ItemType Directory -Force -Path $jobsRoot | Out-Null

$manifestPath = Join-Path $OutputRoot "manifest.json"
$expectedRulesFingerprint = ""
$manifest = $null
if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
	try {
		$existingManifest = Get-Content -LiteralPath $manifestPath -Raw |
			ConvertFrom-Json -ErrorAction Stop
	} catch {
		throw "Existing manifest is invalid JSON: $($_.Exception.Message)"
	}
	if ([string]$existingManifest.schema -ne $MatrixSchema) {
		throw "OutputRoot contains an incompatible matrix manifest schema."
	}
	if (
		-not ($existingManifest.PSObject.Properties.Name -contains "build_identity") -or
		[string]$existingManifest.build_identity.identity_sha256 -ne $buildIdentitySha256
	) {
		throw "OutputRoot belongs to a different build identity. Choose another OutputRoot."
	}
	if ([string]$existingManifest.plan_sha256 -ne $planHash) {
		throw "OutputRoot belongs to a different matrix plan. Choose another OutputRoot."
	}
	if (-not ($existingManifest.PSObject.Properties.Name -contains "expected_rules")) {
		throw "Existing manifest does not declare its expected runtime rules."
	}
	if (
		[string]$existingManifest.expected_rules.ruleset_id -ne $ExpectedRulesetId -or
		[int]$existingManifest.expected_rules.rules_schema_version -ne $ExpectedRulesSchemaVersion
	) {
		throw "Existing manifest declares an incompatible runtime rules contract."
	}
	$expectedRulesFingerprint = [string]$existingManifest.expected_rules.fingerprint
	$manifest = $existingManifest
} else {
	$manifest = [ordered]@{
		schema = $MatrixSchema
		plan_id = $planId
		plan_sha256 = $planHash
		build_identity = $buildIdentity
		expected_rules = [ordered]@{
			ruleset_id = $ExpectedRulesetId
			rules_schema_version = $ExpectedRulesSchemaVersion
			fingerprint = $null
			source = "first_completed_runtime_record"
		}
		contract = $contract
	}
	Write-JsonAtomic -Path $manifestPath -Value $manifest -Depth 12
}

$pending = New-Object System.Collections.Generic.List[object]
$completedRecords = New-Object System.Collections.Generic.List[object]
$skippedCount = 0
foreach ($spec in $jobSpecs) {
	$stageToken = $spec.Stage.ToLowerInvariant()
	$durationToken = Get-DurationToken -DurationSeconds $spec.MaxSimSeconds
	$runId = "bbm-{0}-{1:D3}-{2}-{3}-vs-{4}-seed-{5}-sec-{6}" -f `
		$planHash.Substring(0, 8), $spec.Ordinal, $stageToken, `
		$spec.BlueSquad.ToLowerInvariant(), $spec.RedSquad.ToLowerInvariant(), `
		$spec.Seed, $durationToken
	$jobDirectory = Join-Path $jobsRoot $runId
	$resultPath = Join-Path $jobDirectory "result.jsonl"
	$validatedResult = Read-ValidatedResult -Spec $spec -ResultPath $resultPath `
		-RunId $runId -BuildIdentitySha256 $buildIdentitySha256 `
		-ExpectedRulesFingerprint $expectedRulesFingerprint -RequireMetadata
	if ($null -ne $validatedResult) {
		$skippedCount++
		$completedRecords.Add([pscustomobject]@{
			RunId = $runId
			Ordinal = $spec.Ordinal
			ResultPath = $resultPath
		})
		continue
	}
	$pending.Add([pscustomobject]@{
		Spec = $spec
		RunId = $runId
		JobDirectory = $jobDirectory
		ResultPath = $resultPath
	})
}

Write-Host "Battle Bog balance matrix '$planId'"
Write-Host "Jobs: $($jobSpecs.Count) total, $skippedCount resumed, $($pending.Count) pending"
Write-Host "Stages: $stageSummaryText"
Write-Host "Workers: $WorkerCount (bounded), MaxJobs: $MaxJobs"
Write-Host "Artifacts: $OutputRoot"

$failures = New-Object System.Collections.Generic.List[string]
for ($offset = 0; $offset -lt $pending.Count; $offset += $WorkerCount) {
	$batchNumber = [int]($offset / $WorkerCount) + 1
	Assert-BuildIdentityUnchanged -ExpectedSha256 $buildIdentitySha256 `
		-Phase "before worker batch $batchNumber" -RepoRoot $repoRoot `
		-RunnerPath $runnerPath
	$batchEnd = [Math]::Min($pending.Count - 1, $offset + $WorkerCount - 1)
	$batch = @($pending[$offset..$batchEnd])
	$active = New-Object System.Collections.Generic.List[object]
	foreach ($item in $batch) {
		Write-Host "START $($item.RunId)"
		$backgroundJob = Start-MatrixJob -Spec $item.Spec -RunId $item.RunId `
			-JobDirectory $item.JobDirectory -RunnerPath $runnerPath
		$active.Add([pscustomobject]@{
			Item = $item
			BackgroundJob = $backgroundJob
			Payload = $null
		})
	}
	$active.BackgroundJob | Wait-Job | Out-Null
	foreach ($entry in $active) {
		try {
			$entry.Payload = Receive-Job -Job $entry.BackgroundJob
		} finally {
			Remove-Job -Job $entry.BackgroundJob -Force `
				-ErrorAction SilentlyContinue
		}
	}
	Assert-BuildIdentityUnchanged -ExpectedSha256 $buildIdentitySha256 `
		-Phase "while worker batch $batchNumber was running" -RepoRoot $repoRoot `
		-RunnerPath $runnerPath
	foreach ($entry in $active) {
		$payload = $entry.Payload
		$launcherLog = Join-Path $entry.Item.JobDirectory "launcher.log"
		Write-Utf8NoBom -Path $launcherLog -Lines @([string]$payload.Output)
		if ([int]$payload.ExitCode -ne 0) {
			$failures.Add(
				"$($entry.Item.RunId) exited $($payload.ExitCode); see '$launcherLog'."
			)
			continue
		}
		try {
			$validatedResult = Read-ValidatedResult -Spec $entry.Item.Spec `
				-ResultPath $entry.Item.ResultPath -RunId $entry.Item.RunId `
				-BuildIdentitySha256 $buildIdentitySha256 `
				-ExpectedRulesFingerprint $expectedRulesFingerprint
			if ($null -eq $validatedResult) {
				throw "runner exited successfully without a completed result"
			}
			if (
				-not $ValidateOnly -and
				[string]::IsNullOrWhiteSpace($expectedRulesFingerprint)
			) {
				$expectedRulesFingerprint = [string]$validatedResult.RulesFingerprint
				$manifest.expected_rules.fingerprint = $expectedRulesFingerprint
				Write-JsonAtomic -Path $manifestPath -Value $manifest -Depth 12
			}
			if (
				-not $ValidateOnly -and
				[string]$validatedResult.RulesFingerprint -ne $expectedRulesFingerprint
			) {
				throw "runner produced runtime rules fingerprint '$($validatedResult.RulesFingerprint)'; expected '$expectedRulesFingerprint'"
			}
			Write-ResultMetadata -RunId $entry.Item.RunId `
				-BuildIdentitySha256 $buildIdentitySha256 `
				-ValidatedResult $validatedResult
			$completedRecords.Add([pscustomobject]@{
				RunId = $entry.Item.RunId
				Ordinal = $entry.Item.Spec.Ordinal
				ResultPath = $entry.Item.ResultPath
			})
			Write-Host "PASS  $($entry.Item.RunId)"
		} catch {
			$failures.Add("$($entry.Item.RunId): $($_.Exception.Message)")
		}
	}
	if ($failures.Count -gt 0) {
		break
	}
}

if ($failures.Count -gt 0) {
	throw "Matrix stopped with $($failures.Count) failed job(s): $($failures -join ' ')"
}
if ($completedRecords.Count -ne $jobSpecs.Count) {
	throw "Matrix has $($completedRecords.Count) valid records; expected $($jobSpecs.Count)."
}

Assert-BuildIdentityUnchanged -ExpectedSha256 $buildIdentitySha256 `
	-Phase "before final result merge" -RepoRoot $repoRoot `
	-RunnerPath $runnerPath
$orderedRecords = @($completedRecords | Sort-Object Ordinal, RunId)
$mergedLines = @($orderedRecords | ForEach-Object {
	$line = @(Get-Content -LiteralPath $_.ResultPath | Where-Object {
		-not [string]::IsNullOrWhiteSpace($_)
	})
	if ($line.Count -ne 1) {
		throw "Job '$($_.RunId)' changed during merge."
	}
	$line[0]
})
$mergedPath = Join-Path $OutputRoot "results.jsonl"
Write-Utf8NoBom -Path $mergedPath -Lines $mergedLines
$mergedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $mergedPath).Hash.ToLowerInvariant()

$summary = [ordered]@{
	schema = $MatrixSchema
	plan_id = $planId
	plan_sha256 = $planHash
	build_identity_sha256 = $buildIdentitySha256
	rules_fingerprint = $expectedRulesFingerprint
	stage = $Stage
	stage_summary = @($stageSummary | ForEach-Object {
		[ordered]@{
			stage = $_.Stage
			job_count = $_.Count
			max_simulated_sec = $_.MaxSimSeconds
		}
	})
	total_jobs = $jobSpecs.Count
	executed_jobs = $pending.Count
	resumed_jobs = $skippedCount
	worker_count = $WorkerCount
	results_path = $mergedPath
	results_sha256 = $mergedHash
}
$summaryPath = Join-Path $OutputRoot "summary.json"
Write-Utf8NoBom -Path $summaryPath -Lines @(($summary | ConvertTo-Json -Depth 5))

Write-Host "Battle Bog balance matrix PASS"
Write-Host "Merged:  $mergedPath"
Write-Host "Summary: $summaryPath"
Write-Output ($summary | ConvertTo-Json -Depth 5 -Compress)
} finally {
	if ($null -ne $outputRootLock) {
		$outputRootLock.Dispose()
	}
}
