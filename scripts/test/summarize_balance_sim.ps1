param(
	[Parameter(Mandatory = $true, Position = 0)]
	[Alias("Path")]
	[string[]]$InputPath,
	[string]$JsonOutputPath = "",
	[string]$MarkdownOutputPath = "",
	[ValidateRange(1, 1000000)]
	[int]$MinimumSampleSize = 8
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ResultSchema = "battle_bog.balance_sim.v1"
$SummarySchema = "battle_bog.balance_summary.v1"
$MatchSchema = "battle_bog_match_summary_v1"
$HashPattern = "^[0-9a-f]{64}$"
$PhysicsTickRate = 60.0
$PersistentIdleMinAliveSec = 30.0
$PersistentIdleMinMaxIdleSec = 15.0
$PersistentIdleMinIdleRatio = 0.75
$PersistentIdleMaxMoveInputRatio = 0.05

$SquadDefinitions = @(
	[pscustomobject]@{ Id = "S1"; Roster = @("snapping_turtle", "chorus_frog", "mink") },
	[pscustomobject]@{ Id = "S2"; Roster = @("beaver", "duck", "firefly") },
	[pscustomobject]@{ Id = "S3"; Roster = @("owl", "great_blue_heron", "kingfisher") },
	[pscustomobject]@{ Id = "S4"; Roster = @("cane_toad", "newt", "crayfish") },
	[pscustomobject]@{ Id = "S5"; Roster = @("alligator", "water_snake", "bullfrog") },
	[pscustomobject]@{ Id = "S6"; Roster = @("otter", "mosquito_swarm", "leech") },
	[pscustomobject]@{ Id = "S7"; Roster = @("bog_turtle", "water_shrew", "wolf_spider") }
)

function Get-Field {
	param(
		[AllowNull()]$Object,
		[string]$Name,
		[AllowNull()]$Default = $null
	)
	if ($null -eq $Object) {
		return $Default
	}
	$property = $Object.PSObject.Properties[$Name]
	if ($null -eq $property) {
		return $Default
	}
	return $property.Value
}

function Test-HasField {
	param(
		[AllowNull()]$Object,
		[string]$Name
	)
	if ($null -eq $Object) {
		return $false
	}
	return $null -ne $Object.PSObject.Properties[$Name]
}

function Test-FiniteNumber {
	param([AllowNull()]$Value)
	if ($null -eq $Value -or $Value -is [bool]) {
		return $false
	}
	try {
		$number = [double]$Value
		return -not [double]::IsNaN($number) -and -not [double]::IsInfinity($number)
	} catch {
		return $false
	}
}

function Test-IntegerNumber {
	param([AllowNull()]$Value)
	if (-not (Test-FiniteNumber $Value)) {
		return $false
	}
	$number = [double]$Value
	return $number -eq [math]::Truncate($number)
}

function Add-RecordError {
	param(
		[System.Collections.Generic.List[string]]$Errors,
		[string]$Source,
		[int]$Line,
		[string]$Message
	)
	$Errors.Add("$Source`:$Line`: $Message")
}

function Get-RosterKey {
	param([string[]]$Roster)
	return (@($Roster | Sort-Object) -join ",")
}

function Get-Squad {
	param([string[]]$Roster)
	$key = Get-RosterKey -Roster $Roster
	foreach ($definition in $SquadDefinitions) {
		if ((Get-RosterKey -Roster $definition.Roster) -eq $key) {
			return [pscustomobject]@{
				Id = $definition.Id
				Roster = @($definition.Roster)
				Canonical = $true
			}
		}
	}
	return [pscustomobject]@{
		Id = "custom[$key]"
		Roster = @($Roster | Sort-Object)
		Canonical = $false
	}
}

function Get-SampleLabel {
	param(
		[int]$Samples,
		[int]$Minimum
	)
	if ($Samples -lt $Minimum) {
		return "insufficient_sample"
	}
	return "sufficient_sample"
}

function New-Rate {
	param(
		[int]$Numerator,
		[int]$Denominator,
		[int]$Minimum
	)
	$value = $null
	$percent = $null
	if ($Denominator -gt 0) {
		$value = [math]::Round($Numerator / [double]$Denominator, 6)
		$percent = [math]::Round($value * 100.0, 2)
	}
	return [ordered]@{
		numerator = $Numerator
		denominator = $Denominator
		value = $value
		percent = $percent
		sample_label = Get-SampleLabel -Samples $Denominator -Minimum $Minimum
		insufficient_sample = ($Denominator -lt $Minimum)
	}
}

function New-Stats {
	param(
		[object[]]$Values,
		[int]$Minimum
	)
	$numbers = @($Values | ForEach-Object { [double]$_ })
	if ($numbers.Count -eq 0) {
		return [ordered]@{
			samples = 0
			total = 0.0
			mean = $null
			min = $null
			max = $null
			sample_label = "insufficient_sample"
			insufficient_sample = $true
		}
	}
	$measure = $numbers | Measure-Object -Sum -Average -Minimum -Maximum
	return [ordered]@{
		samples = $numbers.Count
		total = [math]::Round([double]$measure.Sum, 3)
		mean = [math]::Round([double]$measure.Average, 3)
		min = [math]::Round([double]$measure.Minimum, 3)
		max = [math]::Round([double]$measure.Maximum, 3)
		sample_label = Get-SampleLabel -Samples $numbers.Count -Minimum $Minimum
		insufficient_sample = ($numbers.Count -lt $Minimum)
	}
}

function Resolve-InputFiles {
	param([string[]]$Candidates)
	$files = New-Object System.Collections.Generic.List[string]
	foreach ($candidate in $Candidates) {
		$items = @(Get-Item -Path $candidate -ErrorAction SilentlyContinue)
		if ($items.Count -eq 0) {
			throw "Input path did not resolve to a file or directory: '$candidate'."
		}
		foreach ($item in $items) {
			if ($item.PSIsContainer) {
				foreach ($child in Get-ChildItem -LiteralPath $item.FullName -File -Filter "*.jsonl") {
					$files.Add($child.FullName)
				}
			} else {
				$files.Add($item.FullName)
			}
		}
	}
	$resolved = @($files | Sort-Object -Unique)
	if ($resolved.Count -eq 0) {
		throw "No JSONL input files were found."
	}
	return $resolved
}

function Assert-Roster {
	param(
		[AllowNull()]$Value,
		[string]$Label,
		[string]$Source,
		[int]$Line,
		[System.Collections.Generic.List[string]]$Errors
	)
	$roster = @($Value)
	if ($roster.Count -ne 3) {
		Add-RecordError $Errors $Source $Line "$Label must contain exactly three creature ids"
		return
	}
	$strings = @($roster | ForEach-Object { [string]$_ })
	if (@($strings | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
		Add-RecordError $Errors $Source $Line "$Label contains an empty creature id"
	}
	if (@($strings | Sort-Object -Unique).Count -ne 3) {
		Add-RecordError $Errors $Source $Line "$Label must contain unique creature ids"
	}
}

function Assert-NonnegativeMetric {
	param(
		[AllowNull()]$Object,
		[string]$Name,
		[string]$Source,
		[int]$Line,
		[System.Collections.Generic.List[string]]$Errors,
		[switch]$Optional
	)
	if (-not (Test-HasField $Object $Name)) {
		if (-not $Optional) {
			Add-RecordError $Errors $Source $Line "missing numeric field '$Name'"
		}
		return
	}
	$value = Get-Field $Object $Name
	if (-not (Test-FiniteNumber $value) -or [double]$value -lt 0.0) {
		Add-RecordError $Errors $Source $Line "field '$Name' must be a finite nonnegative number"
	}
}

function Assert-NonnegativeIntegerMetric {
	param(
		[AllowNull()]$Object,
		[string]$Name,
		[string]$Source,
		[int]$Line,
		[System.Collections.Generic.List[string]]$Errors
	)
	if (-not (Test-HasField $Object $Name)) {
		Add-RecordError $Errors $Source $Line "missing integer field '$Name'"
		return
	}
	$value = Get-Field $Object $Name
	if (-not (Test-IntegerNumber $value) -or [long]$value -lt 0) {
		Add-RecordError $Errors $Source $Line "field '$Name' must be a nonnegative integer"
	}
}

function Test-BalanceTelemetry {
	param(
		[AllowNull()]$Telemetry,
		[string]$Source,
		[int]$Line,
		[System.Collections.Generic.List[string]]$Errors
	)
	if ($null -eq $Telemetry) {
		Add-RecordError $Errors $Source $Line "match.balance_telemetry must be an object when present"
		return
	}

	$slotRows = @((Get-Field $Telemetry "slot_activity"))
	if ($slotRows.Count -ne 6) {
		Add-RecordError $Errors $Source $Line "balance_telemetry.slot_activity must contain exactly six rows"
	} else {
		$slotIds = New-Object System.Collections.Generic.List[string]
		foreach ($slotRow in $slotRows) {
			$slotId = [string](Get-Field $slotRow "slot_id" "")
			if ([string]::IsNullOrWhiteSpace($slotId)) {
				Add-RecordError $Errors $Source $Line "balance telemetry slot_id is required"
			} else {
				$slotIds.Add($slotId)
			}
			if (-not (Test-IntegerNumber (Get-Field $slotRow "slot_index")) -or
				[long](Get-Field $slotRow "slot_index" -1) -lt 0) {
				Add-RecordError $Errors $Source $Line "balance telemetry slot_index must be a nonnegative integer"
			}
			$team = Get-Field $slotRow "team"
			if (-not (Test-IntegerNumber $team) -or [long]$team -notin @(0, 1)) {
				Add-RecordError $Errors $Source $Line "balance telemetry team must be 0 or 1"
			}
			if ([string]::IsNullOrWhiteSpace([string](Get-Field $slotRow "creature_id" ""))) {
				Add-RecordError $Errors $Source $Line "balance telemetry creature_id is required"
			}
			foreach ($metric in @(
				"sample_ticks", "alive_ticks", "active_ticks", "idle_ticks",
				"current_idle_ticks", "max_idle_ticks", "move_input_ticks",
				"primary_press_count", "ability_press_count", "ability_q_press_count",
				"ability_e_press_count", "landed_hit_count"
			)) {
				Assert-NonnegativeIntegerMetric $slotRow $metric $Source $Line $Errors
			}
			Assert-NonnegativeMetric $slotRow "distance_traveled_px" $Source $Line $Errors

			$sampleTicks = [long](Get-Field $slotRow "sample_ticks" 0)
			$aliveTicks = [long](Get-Field $slotRow "alive_ticks" 0)
			$activeTicks = [long](Get-Field $slotRow "active_ticks" 0)
			$idleTicks = [long](Get-Field $slotRow "idle_ticks" 0)
			$currentIdleTicks = [long](Get-Field $slotRow "current_idle_ticks" 0)
			$maxIdleTicks = [long](Get-Field $slotRow "max_idle_ticks" 0)
			$moveInputTicks = [long](Get-Field $slotRow "move_input_ticks" 0)
			$abilityPresses = [long](Get-Field $slotRow "ability_press_count" 0)
			$abilityQPresses = [long](Get-Field $slotRow "ability_q_press_count" 0)
			$abilityEPresses = [long](Get-Field $slotRow "ability_e_press_count" 0)
			if ($aliveTicks -gt $sampleTicks) {
				Add-RecordError $Errors $Source $Line "balance telemetry alive_ticks cannot exceed sample_ticks"
			}
			if (($activeTicks + $idleTicks) -ne $aliveTicks) {
				Add-RecordError $Errors $Source $Line "balance telemetry active_ticks + idle_ticks must equal alive_ticks"
			}
			if ($moveInputTicks -gt $activeTicks) {
				Add-RecordError $Errors $Source $Line "balance telemetry move_input_ticks cannot exceed active_ticks"
			}
			if ($currentIdleTicks -gt $maxIdleTicks -or $maxIdleTicks -gt $idleTicks) {
				Add-RecordError $Errors $Source $Line "balance telemetry idle streak ticks are inconsistent"
			}
			if (($abilityQPresses + $abilityEPresses) -ne $abilityPresses) {
				Add-RecordError $Errors $Source $Line "balance telemetry Q/E presses must sum to ability_press_count"
			}
		}
		if (@($slotIds | Sort-Object -Unique).Count -ne 6) {
			Add-RecordError $Errors $Source $Line "balance_telemetry.slot_activity must contain six unique stable slot ids"
		}
	}

	foreach ($metric in @(
		"boss_lifecycle_total_events",
		"boss_lifecycle_retained_events",
		"boss_lifecycle_truncated_events"
	)) {
		Assert-NonnegativeIntegerMetric $Telemetry $metric $Source $Line $Errors
	}
	$events = @((Get-Field $Telemetry "boss_lifecycle_events"))
	$totalEvents = [long](Get-Field $Telemetry "boss_lifecycle_total_events" 0)
	$retainedEvents = [long](Get-Field $Telemetry "boss_lifecycle_retained_events" 0)
	$truncatedEvents = [long](Get-Field $Telemetry "boss_lifecycle_truncated_events" 0)
	if ($retainedEvents -ne $events.Count) {
		Add-RecordError $Errors $Source $Line "boss lifecycle retained count must equal event row count"
	}
	if ($totalEvents -ne ($retainedEvents + $truncatedEvents)) {
		Add-RecordError $Errors $Source $Line "boss lifecycle total must equal retained plus truncated"
	}

	$previousSequence = [long]$truncatedEvents
	$previousElapsed = -1.0
	$previousTick = -1L
	foreach ($eventRow in $events) {
		$sequence = Get-Field $eventRow "sequence"
		$elapsedSec = Get-Field $eventRow "elapsed_sec"
		$simulationTick = Get-Field $eventRow "simulation_tick"
		if (-not (Test-IntegerNumber $sequence) -or [long]$sequence -ne ($previousSequence + 1)) {
			Add-RecordError $Errors $Source $Line "boss lifecycle sequences must be contiguous after truncation"
			break
		}
		if (-not (Test-FiniteNumber $elapsedSec) -or [double]$elapsedSec -lt $previousElapsed) {
			Add-RecordError $Errors $Source $Line "boss lifecycle elapsed_sec values must be finite, nonnegative, and monotonic"
			break
		}
		if (-not (Test-IntegerNumber $simulationTick) -or [long]$simulationTick -lt $previousTick) {
			Add-RecordError $Errors $Source $Line "boss lifecycle simulation_tick values must be nonnegative integers and monotonic"
			break
		}
		$eventName = [string](Get-Field $eventRow "event" "")
		if ($eventName -notin @("active", "claimable", "contested", "claimed", "stolen")) {
			Add-RecordError $Errors $Source $Line "boss lifecycle event '$eventName' is unsupported"
		}
		$center = Get-Field $eventRow "center"
		if ($center -isnot [bool]) {
			Add-RecordError $Errors $Source $Line "boss lifecycle center must be a JSON boolean"
		}
		$side = [string](Get-Field $eventRow "side" "")
		if (($center -eq $true -and $side -ne "center") -or
			($center -eq $false -and $side -notin @("blue", "red"))) {
			Add-RecordError $Errors $Source $Line "boss lifecycle side must agree with center"
		}
		$previousSequence = [long]$sequence
		$previousElapsed = [double]$elapsedSec
		$previousTick = [long]$simulationTick
	}
	if ($events.Count -gt 0 -and $previousSequence -ne $totalEvents) {
		Add-RecordError $Errors $Source $Line "final retained boss lifecycle sequence must equal total event count"
	}
}

function Test-Record {
	param(
		[AllowNull()]$Record,
		[string]$Source,
		[int]$Line,
		[System.Collections.Generic.List[string]]$Errors
	)
	$startCount = $Errors.Count
	if ($null -eq $Record) {
		Add-RecordError $Errors $Source $Line "record is null"
		return $false
	}
	if ([string](Get-Field $Record "schema" "") -ne $ResultSchema) {
		Add-RecordError $Errors $Source $Line "schema must be '$ResultSchema'"
	}
	if ([string]::IsNullOrWhiteSpace([string](Get-Field $Record "run_id" ""))) {
		Add-RecordError $Errors $Source $Line "run_id is required"
	}
	$requested = Get-Field $Record "requested"
	if ($null -eq $requested) {
		Add-RecordError $Errors $Source $Line "requested object is required"
	} else {
		Assert-Roster (Get-Field $requested "blue_roster") "requested.blue_roster" $Source $Line $Errors
		Assert-Roster (Get-Field $requested "red_roster") "requested.red_roster" $Source $Line $Errors
		Assert-NonnegativeMetric $requested "simulation_seed" $Source $Line $Errors
		Assert-NonnegativeMetric $requested "max_simulated_sec" $Source $Line $Errors
		Assert-NonnegativeMetric $requested "checksum_interval_sec" $Source $Line $Errors
		if ((Test-FiniteNumber (Get-Field $requested "max_simulated_sec")) -and
			[double](Get-Field $requested "max_simulated_sec") -le 0.0) {
			Add-RecordError $Errors $Source $Line "requested.max_simulated_sec must be greater than zero"
		}
		if ((Test-FiniteNumber (Get-Field $requested "checksum_interval_sec")) -and
			[double](Get-Field $requested "checksum_interval_sec") -le 0.0) {
			Add-RecordError $Errors $Source $Line "requested.checksum_interval_sec must be greater than zero"
		}
		if (-not (Test-IntegerNumber (Get-Field $requested "simulation_seed"))) {
			Add-RecordError $Errors $Source $Line "requested.simulation_seed must be an integer"
		}
	}

	$status = [string](Get-Field $Record "status" "")
	if ($status -eq "validation_ok") {
		if (-not [bool](Get-Field $Record "validation_only" $false)) {
			Add-RecordError $Errors $Source $Line "validation_ok record must set validation_only=true"
		}
		return $Errors.Count -eq $startCount
	}
	if ($status -notin @("completed", "timeout")) {
		Add-RecordError $Errors $Source $Line "status must be completed, timeout, or validation_ok"
		return $false
	}

	$completed = [bool](Get-Field $Record "completed" $false)
	$timedOut = [bool](Get-Field $Record "timed_out" $false)
	if ((Get-Field $Record "completed") -isnot [bool] -or
		(Get-Field $Record "timed_out") -isnot [bool]) {
		Add-RecordError $Errors $Source $Line "completed and timed_out must be JSON booleans"
	}
	if (($status -eq "completed") -ne $completed) {
		Add-RecordError $Errors $Source $Line "status/completed fields disagree"
	}
	if (($status -eq "timeout") -ne $timedOut) {
		Add-RecordError $Errors $Source $Line "status/timed_out fields disagree"
	}
	Assert-NonnegativeMetric $Record "simulated_sec" $Source $Line $Errors
	Assert-NonnegativeMetric $Record "physics_ticks" $Source $Line $Errors

	$match = Get-Field $Record "match"
	if ($null -eq $match) {
		Add-RecordError $Errors $Source $Line "match object is required"
	} else {
		if ([string](Get-Field $match "schema" "") -ne $MatchSchema) {
			Add-RecordError $Errors $Source $Line "match.schema must be '$MatchSchema'"
		}
		Assert-NonnegativeMetric $match "elapsed_sec" $Source $Line $Errors
		$winner = [string](Get-Field $match "winner" "")
		if ($winner -notin @("", "Blue", "Red")) {
			Add-RecordError $Errors $Source $Line "match.winner must be Blue, Red, or empty"
		}
		if ($completed -and $winner -notin @("Blue", "Red")) {
			Add-RecordError $Errors $Source $Line "completed match must have a Blue or Red winner"
		}
		if ($timedOut -and -not [string]::IsNullOrEmpty($winner)) {
			Add-RecordError $Errors $Source $Line "timed-out match must not have a winner"
		}
		$matchSeed = Get-Field $match "simulation_seed" -1
		$requestSeed = Get-Field $requested "simulation_seed" -2
		if (-not (Test-FiniteNumber $matchSeed) -or [long]$matchSeed -ne [long]$requestSeed) {
			Add-RecordError $Errors $Source $Line "match simulation_seed does not match requested seed"
		}
		$rosters = Get-Field $match "resolved_rosters"
		if ($null -eq $rosters) {
			Add-RecordError $Errors $Source $Line "match.resolved_rosters is required"
		} else {
			$blueResolved = @((Get-Field $rosters "blue") | ForEach-Object { [string]$_ })
			$redResolved = @((Get-Field $rosters "red") | ForEach-Object { [string]$_ })
			$blueRequested = @((Get-Field $requested "blue_roster") | ForEach-Object { [string]$_ })
			$redRequested = @((Get-Field $requested "red_roster") | ForEach-Object { [string]$_ })
			if (($blueResolved -join ",") -ne ($blueRequested -join ",")) {
				Add-RecordError $Errors $Source $Line "resolved Blue roster does not match requested order"
			}
			if (($redResolved -join ",") -ne ($redRequested -join ",")) {
				Add-RecordError $Errors $Source $Line "resolved Red roster does not match requested order"
			}
		}
		$teams = Get-Field $match "teams"
		foreach ($side in @("blue", "red")) {
			$team = Get-Field $teams $side
			if ($null -eq $team) {
				Add-RecordError $Errors $Source $Line "match.teams.$side is required"
				continue
			}
			foreach ($metric in @("stocks_remaining", "max_stocks", "deposits", "breeds_completed")) {
				Assert-NonnegativeMetric $team $metric $Source $Line $Errors
			}
			foreach ($metric in @("boss_claims", "boss_steals", "center_claims")) {
				Assert-NonnegativeMetric $team $metric $Source $Line $Errors -Optional
			}
		}
		$economy = Get-Field $match "economy_summary"
		if ($null -eq $economy) {
			Add-RecordError $Errors $Source $Line "match.economy_summary is required"
		} else {
			foreach ($side in @("blue", "red")) {
				$teamEconomy = Get-Field (Get-Field $economy "by_team") $side
				if ($null -eq $teamEconomy -or
					$null -eq (Get-Field $teamEconomy "counts") -or
					$null -eq (Get-Field $teamEconomy "first_elapsed_sec")) {
					Add-RecordError $Errors $Source $Line "economy_summary.by_team.$side counts and first_elapsed_sec are required"
					continue
				}
				$counts = Get-Field $teamEconomy "counts"
				$firstTimes = Get-Field $teamEconomy "first_elapsed_sec"
				foreach ($eventName in @("food_consumed", "deposit_committed", "breed_completed")) {
					if (Test-HasField $counts $eventName) {
						$count = Get-Field $counts $eventName
						if (-not (Test-IntegerNumber $count) -or [long]$count -lt 0) {
							Add-RecordError $Errors $Source $Line "economy $side $eventName count must be a nonnegative integer"
						}
					}
					if (Test-HasField $firstTimes $eventName) {
						$firstTime = Get-Field $firstTimes $eventName
						if (-not (Test-FiniteNumber $firstTime) -or [double]$firstTime -lt 0.0) {
							Add-RecordError $Errors $Source $Line "economy $side $eventName first time must be finite and nonnegative"
						}
					}
				}
			}
		}
		if (Test-HasField $match "balance_telemetry") {
			Test-BalanceTelemetry (Get-Field $match "balance_telemetry") $Source $Line $Errors
		}
	}

	$checksums = @((Get-Field $Record "checksums"))
	if ($checksums.Count -eq 0) {
		Add-RecordError $Errors $Source $Line "checksums must contain at least one entry"
	} else {
		$previousTick = -1L
		foreach ($checksum in $checksums) {
			$tick = Get-Field $checksum "tick" -1
			$hash = [string](Get-Field $checksum "sha256" "")
			if (-not (Test-IntegerNumber $tick) -or [long]$tick -le $previousTick) {
				Add-RecordError $Errors $Source $Line "checksum ticks must be strictly increasing"
				break
			}
			if ($hash -cnotmatch $HashPattern) {
				Add-RecordError $Errors $Source $Line "checksum sha256 must be 64 lowercase hexadecimal characters"
				break
			}
			$previousTick = [long]$tick
		}
		$lastHash = [string](Get-Field $checksums[-1] "sha256" "")
		if ([string](Get-Field $Record "final_checksum" "") -cne $lastHash) {
			Add-RecordError $Errors $Source $Line "final_checksum does not match the final checksum entry"
		}
	}
	return $Errors.Count -eq $startCount
}

function Get-Team {
	param($MatchRecord, [string]$Side)
	$raw = Get-Field $MatchRecord "Raw"
	$match = Get-Field $raw "match"
	$teams = Get-Field $match "teams"
	return Get-Field $teams $Side
}

function Get-EconomyTeam {
	param($MatchRecord, [string]$Side)
	$match = Get-Field (Get-Field $MatchRecord "Raw") "match"
	$economy = Get-Field $match "economy_summary"
	return Get-Field (Get-Field $economy "by_team") $Side
}

function Get-BalanceTelemetry {
	param($MatchRecord)
	$match = Get-Field (Get-Field $MatchRecord "Raw") "match"
	if (-not (Test-HasField $match "balance_telemetry")) {
		return $null
	}
	return Get-Field $match "balance_telemetry"
}

function Get-TelemetrySide {
	param([AllowNull()]$Team)
	if ([long]$Team -eq 0) {
		return "Blue"
	}
	if ([long]$Team -eq 1) {
		return "Red"
	}
	return "Unknown"
}

function Get-SafeRatio {
	param(
		[double]$Numerator,
		[double]$Denominator
	)
	if ($Denominator -le 0.0) {
		return $null
	}
	return [math]::Round($Numerator / $Denominator, 6)
}

function Test-PersistentIdleSample {
	param($SlotRow)
	$aliveTicks = [double](Get-Field $SlotRow "alive_ticks" 0)
	if ($aliveTicks -le 0.0) {
		return $false
	}
	$aliveSec = $aliveTicks / $PhysicsTickRate
	$maxIdleSec = [double](Get-Field $SlotRow "max_idle_ticks" 0) / $PhysicsTickRate
	$idleRatio = [double](Get-Field $SlotRow "idle_ticks" 0) / $aliveTicks
	$moveInputRatio = [double](Get-Field $SlotRow "move_input_ticks" 0) / $aliveTicks
	return $aliveSec -ge $PersistentIdleMinAliveSec -and
		$maxIdleSec -ge $PersistentIdleMinMaxIdleSec -and
		$idleRatio -ge $PersistentIdleMinIdleRatio -and
		$moveInputRatio -le $PersistentIdleMaxMoveInputRatio
}

function New-ActivityAggregate {
	param(
		[object[]]$Samples,
		[int]$Minimum
	)
	$maxIdleDurations = @()
	$activeRatios = @()
	$idleRatios = @()
	$distances = @()
	$moveInputRatios = @()
	$primaryPresses = @()
	$abilityPresses = @()
	$landedHits = @()
	$anomalyCount = 0
	foreach ($sample in $Samples) {
		$row = Get-Field $sample "Row"
		$aliveTicks = [double](Get-Field $row "alive_ticks" 0)
		$maxIdleDurations += [double](Get-Field $row "max_idle_ticks" 0) / $PhysicsTickRate
		$distances += [double](Get-Field $row "distance_traveled_px" 0)
		$primaryPresses += [double](Get-Field $row "primary_press_count" 0)
		$abilityPresses += [double](Get-Field $row "ability_press_count" 0)
		$landedHits += [double](Get-Field $row "landed_hit_count" 0)
		if ($aliveTicks -gt 0.0) {
			$activeRatios += [double](Get-Field $row "active_ticks" 0) / $aliveTicks
			$idleRatios += [double](Get-Field $row "idle_ticks" 0) / $aliveTicks
			$moveInputRatios += [double](Get-Field $row "move_input_ticks" 0) / $aliveTicks
		}
		if (Test-PersistentIdleSample $row) {
			$anomalyCount += 1
		}
	}
	return [ordered]@{
		samples = $Samples.Count
		sample_label = Get-SampleLabel -Samples $Samples.Count -Minimum $Minimum
		insufficient_sample = ($Samples.Count -lt $Minimum)
		max_idle_duration_sec = New-Stats $maxIdleDurations $Minimum
		active_ratio = New-Stats $activeRatios $Minimum
		idle_ratio = New-Stats $idleRatios $Minimum
		distance_traveled_px = New-Stats $distances $Minimum
		move_input_ratio = New-Stats $moveInputRatios $Minimum
		primary_press_count = New-Stats $primaryPresses $Minimum
		ability_press_count = New-Stats $abilityPresses $Minimum
		landed_hit_count = New-Stats $landedHits $Minimum
		persistent_idle_rate = New-Rate $anomalyCount $Samples.Count $Minimum
	}
}

function Get-Winner {
	param($MatchRecord)
	return [string](Get-Field (Get-Field (Get-Field $MatchRecord "Raw") "match") "winner" "")
}

function Get-DeterminismSignature {
	param($MatchRecord)
	$requested = Get-Field (Get-Field $MatchRecord "Raw") "requested"
	return @(
		(@(Get-Field $requested "blue_roster") -join ","),
		(@(Get-Field $requested "red_roster") -join ","),
		([string](Get-Field $requested "simulation_seed")),
		([string](Get-Field $requested "max_simulated_sec")),
		([string](Get-Field $requested "checksum_interval_sec"))
	) -join "|"
}

function Get-ChecksumSeries {
	param($MatchRecord)
	$checksums = @((Get-Field (Get-Field $MatchRecord "Raw") "checksums"))
	return @($checksums | ForEach-Object {
		$tick = [long](Get-Field $_ "tick" -1)
		$hash = [string](Get-Field $_ "sha256" "")
		"${tick}:$hash"
	}) -join ","
}

function Format-Rate {
	param($Rate)
	if ($null -eq $Rate.value) {
		return "n/a ($($Rate.sample_label))"
	}
	$text = "$($Rate.percent)% ($($Rate.numerator)/$($Rate.denominator))"
	if ($Rate.insufficient_sample) {
		$text += " [insufficient]"
	}
	return $text
}

function Escape-MarkdownCell {
	param([AllowNull()]$Value)
	return ([string]$Value).Replace("|", "\|").Replace("`r", " ").Replace("`n", " ")
}

$inputFiles = @(Resolve-InputFiles -Candidates $InputPath)
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..\..")).Path
$defaultOutputDir = Join-Path $repoRoot "artifacts\balance-sim"
if ([string]::IsNullOrWhiteSpace($JsonOutputPath)) {
	$JsonOutputPath = Join-Path $defaultOutputDir "balance-summary.json"
}
if ([string]::IsNullOrWhiteSpace($MarkdownOutputPath)) {
	$MarkdownOutputPath = Join-Path $defaultOutputDir "balance-summary.md"
}
foreach ($variableName in @("JsonOutputPath", "MarkdownOutputPath")) {
	$value = Get-Variable -Name $variableName -ValueOnly
	if (-not [System.IO.Path]::IsPathRooted($value)) {
		$value = Join-Path $repoRoot $value
		Set-Variable -Name $variableName -Value $value
	}
}

$validationErrors = New-Object System.Collections.Generic.List[string]
$records = New-Object System.Collections.Generic.List[object]
$validationOnlyCount = 0
$lineCount = 0
foreach ($file in $inputFiles) {
	$source = $file.Substring((Split-Path -Qualifier $file).Length).TrimStart("\")
	$lineNumber = 0
	foreach ($lineText in [System.IO.File]::ReadLines($file)) {
		$lineNumber += 1
		if ([string]::IsNullOrWhiteSpace($lineText)) {
			continue
		}
		$lineCount += 1
		try {
			$record = $lineText | ConvertFrom-Json -ErrorAction Stop
		} catch {
			Add-RecordError $validationErrors $source $lineNumber "invalid JSON: $($_.Exception.Message)"
			continue
		}
		if (-not (Test-Record $record $source $lineNumber $validationErrors)) {
			continue
		}
		if ([string](Get-Field $record "status" "") -eq "validation_ok") {
			$validationOnlyCount += 1
			continue
		}
		$requested = Get-Field $record "requested"
		$blueRoster = @((Get-Field $requested "blue_roster") | ForEach-Object { [string]$_ })
		$redRoster = @((Get-Field $requested "red_roster") | ForEach-Object { [string]$_ })
		$records.Add([pscustomobject]@{
			Raw = $record
			Source = $source
			Line = $lineNumber
			Seed = [long](Get-Field $requested "simulation_seed")
			BlueSquad = Get-Squad -Roster $blueRoster
			RedSquad = Get-Squad -Roster $redRoster
		})
	}
}

if ($validationErrors.Count -gt 0) {
	$message = "Balance JSONL validation failed with $($validationErrors.Count) error(s):`n - " +
		($validationErrors -join "`n - ")
	throw $message
}
if ($records.Count -eq 0) {
	throw "No completed or timed-out simulation records were found. Validation-only records: $validationOnlyCount."
}

$sortedRecords = @($records | Sort-Object Seed, @{ Expression = { $_.BlueSquad.Id } },
	@{ Expression = { $_.RedSquad.Id } }, @{ Expression = { [string](Get-Field $_.Raw "run_id" "") } })
$completedCount = @($sortedRecords | Where-Object { [bool](Get-Field $_.Raw "completed" $false) }).Count
$timeoutCount = @($sortedRecords | Where-Object { [bool](Get-Field $_.Raw "timed_out" $false) }).Count
$blueWins = @($sortedRecords | Where-Object { (Get-Winner $_) -eq "Blue" }).Count
$redWins = @($sortedRecords | Where-Object { (Get-Winner $_) -eq "Red" }).Count

$sideRows = @()
foreach ($side in @("blue", "red")) {
	$display = (Get-Culture).TextInfo.ToTitleCase($side)
	$wins = if ($side -eq "blue") { $blueWins } else { $redWins }
	$losses = if ($side -eq "blue") { $redWins } else { $blueWins }
	$stockValues = @($sortedRecords | ForEach-Object { [double](Get-Field (Get-Team $_ $side) "stocks_remaining" 0) })
	$depositValues = @($sortedRecords | ForEach-Object { [double](Get-Field (Get-Team $_ $side) "deposits" 0) })
	$breedValues = @($sortedRecords | ForEach-Object { [double](Get-Field (Get-Team $_ $side) "breeds_completed" 0) })
	$sideRows += [ordered]@{
		side = $display
		matches = $sortedRecords.Count
		wins = $wins
		losses = $losses
		unresolved = $timeoutCount
		win_rate_all_matches = New-Rate $wins $sortedRecords.Count $MinimumSampleSize
		win_rate_resolved = New-Rate $wins ($wins + $losses) $MinimumSampleSize
		stocks_remaining = New-Stats $stockValues $MinimumSampleSize
		deposits = New-Stats $depositValues $MinimumSampleSize
		breeds_completed = New-Stats $breedValues $MinimumSampleSize
	}
}

$squadMap = [ordered]@{}
foreach ($record in $sortedRecords) {
	foreach ($squad in @($record.BlueSquad, $record.RedSquad)) {
		if (-not $squadMap.Contains($squad.Id)) {
			$squadMap[$squad.Id] = $squad
		}
	}
}
$squadRows = @()
foreach ($squadId in @($squadMap.Keys | Sort-Object)) {
	$squad = $squadMap[$squadId]
	$blueAppearances = @($sortedRecords | Where-Object { $_.BlueSquad.Id -eq $squadId })
	$redAppearances = @($sortedRecords | Where-Object { $_.RedSquad.Id -eq $squadId })
	$blueSquadWins = @($blueAppearances | Where-Object { (Get-Winner $_) -eq "Blue" }).Count
	$redSquadWins = @($redAppearances | Where-Object { (Get-Winner $_) -eq "Red" }).Count
	$appearances = $blueAppearances.Count + $redAppearances.Count
	$squadRows += [ordered]@{
		squad_id = $squadId
		canonical = [bool]$squad.Canonical
		roster = @($squad.Roster)
		appearances = $appearances
		blue_appearances = $blueAppearances.Count
		red_appearances = $redAppearances.Count
		wins = $blueSquadWins + $redSquadWins
		wins_as_blue = $blueSquadWins
		wins_as_red = $redSquadWins
		win_rate = New-Rate ($blueSquadWins + $redSquadWins) $appearances $MinimumSampleSize
		win_rate_as_blue = New-Rate $blueSquadWins $blueAppearances.Count $MinimumSampleSize
		win_rate_as_red = New-Rate $redSquadWins $redAppearances.Count $MinimumSampleSize
	}
}

$matchupGroups = @{}
foreach ($record in $sortedRecords) {
	$ids = @($record.BlueSquad.Id, $record.RedSquad.Id) | Sort-Object
	$key = "$($ids[0]) vs $($ids[1])"
	if (-not $matchupGroups.ContainsKey($key)) {
		$matchupGroups[$key] = New-Object System.Collections.Generic.List[object]
	}
	$matchupGroups[$key].Add($record)
}
$matchupRows = @()
foreach ($key in @($matchupGroups.Keys | Sort-Object)) {
	$group = @($matchupGroups[$key] | ForEach-Object { $_ })
	$ids = $key -split " vs ", 2
	$a = $ids[0]
	$b = $ids[1]
	$aBlue = @($group | Where-Object { $_.BlueSquad.Id -eq $a })
	$aRed = @($group | Where-Object { $_.RedSquad.Id -eq $a })
	$aWinsAsBlue = @($aBlue | Where-Object { (Get-Winner $_) -eq "Blue" }).Count
	$aWinsAsRed = @($aRed | Where-Object { (Get-Winner $_) -eq "Red" }).Count
	$matchupTimeouts = @($group | Where-Object { [bool](Get-Field $_.Raw "timed_out" $false) }).Count
	$matchupRows += [ordered]@{
		matchup_id = $key
		squad_a = $a
		squad_b = $b
		matches = $group.Count
		squad_a_blue_assignments = $aBlue.Count
		squad_a_red_assignments = $aRed.Count
		squad_a_wins_as_blue = $aWinsAsBlue
		squad_a_wins_as_red = $aWinsAsRed
		squad_a_win_rate = New-Rate ($aWinsAsBlue + $aWinsAsRed) $group.Count $MinimumSampleSize
		blue_wins = @($group | Where-Object { (Get-Winner $_) -eq "Blue" }).Count
		red_wins = @($group | Where-Object { (Get-Winner $_) -eq "Red" }).Count
		timeout_rate = New-Rate $matchupTimeouts $group.Count $MinimumSampleSize
	}
}

$seedRows = @()
foreach ($seedGroup in @($sortedRecords | Group-Object Seed | Sort-Object { [long]$_.Name })) {
	$group = @($seedGroup.Group)
	$seedTimeouts = @($group | Where-Object { [bool](Get-Field $_.Raw "timed_out" $false) }).Count
	$seedRows += [ordered]@{
		seed = [long]$seedGroup.Name
		matches = $group.Count
		blue_wins = @($group | Where-Object { (Get-Winner $_) -eq "Blue" }).Count
		red_wins = @($group | Where-Object { (Get-Winner $_) -eq "Red" }).Count
		timeout_rate = New-Rate $seedTimeouts $group.Count $MinimumSampleSize
		duration_sec = New-Stats @($group | ForEach-Object {
			[double](Get-Field (Get-Field $_.Raw "match") "elapsed_sec" 0)
		}) $MinimumSampleSize
	}
}

$economyRows = @()
$economyThresholds = @{
	food_consumed = 120.0
	deposit_committed = 240.0
	breed_completed = 300.0
}
foreach ($side in @("blue", "red")) {
	foreach ($eventName in @("food_consumed", "deposit_committed", "breed_completed")) {
		$totals = @()
		$firstTimes = @()
		$withinThreshold = 0
		$threshold = [double]$economyThresholds[$eventName]
		foreach ($record in $sortedRecords) {
			$economyTeam = Get-EconomyTeam $record $side
			$counts = Get-Field $economyTeam "counts"
			$first = Get-Field $economyTeam "first_elapsed_sec"
			$count = [int](Get-Field $counts $eventName 0)
			$totals += $count
			if (Test-HasField $first $eventName) {
				$firstTime = [double](Get-Field $first $eventName)
				$firstTimes += $firstTime
				if ($firstTime -le $threshold) {
					$withinThreshold += 1
				}
			}
		}
		$economyRows += [ordered]@{
			side = (Get-Culture).TextInfo.ToTitleCase($side)
			event = $eventName
			matches = $sortedRecords.Count
			matches_with_event = $firstTimes.Count
			matches_missing_event = $sortedRecords.Count - $firstTimes.Count
			event_totals = New-Stats $totals $MinimumSampleSize
			first_elapsed_sec = New-Stats $firstTimes $MinimumSampleSize
			target_elapsed_sec = $threshold
			target_met_rate = New-Rate $withinThreshold $sortedRecords.Count $MinimumSampleSize
		}
	}
}

$bossRows = @()
foreach ($side in @("blue", "red")) {
	foreach ($metric in @("boss_claims", "boss_steals", "center_claims")) {
		$values = @()
		foreach ($record in $sortedRecords) {
			$team = Get-Team $record $side
			if (Test-HasField $team $metric) {
				$values += [double](Get-Field $team $metric)
			}
		}
		$bossRows += [ordered]@{
			side = (Get-Culture).TextInfo.ToTitleCase($side)
			metric = $metric
			available_samples = $values.Count
			unavailable_samples = $sortedRecords.Count - $values.Count
			availability = if ($values.Count -eq 0) { "unavailable" } else { "available" }
			values = New-Stats $values $MinimumSampleSize
		}
	}
}

$telemetryRecords = @()
$activitySamples = New-Object System.Collections.Generic.List[object]
foreach ($record in $sortedRecords) {
	$telemetry = Get-BalanceTelemetry $record
	if ($null -eq $telemetry) {
		continue
	}
	$telemetryRecords += $record
	foreach ($slotRow in @((Get-Field $telemetry "slot_activity"))) {
		$activitySamples.Add([pscustomobject]@{
			Record = $record
			Row = $slotRow
			RunId = [string](Get-Field $record.Raw "run_id" "")
			Side = Get-TelemetrySide (Get-Field $slotRow "team")
		})
	}
}

$activityBySlotRows = @()
foreach ($groupInfo in @($activitySamples | Group-Object { [string](Get-Field $_.Row "slot_id" "") } | Sort-Object Name)) {
	$samples = @($groupInfo.Group)
	$slotIndexes = @($samples | ForEach-Object { [long](Get-Field $_.Row "slot_index" -1) } | Sort-Object -Unique)
	$sides = @($samples | ForEach-Object { [string]$_.Side } | Sort-Object -Unique)
	$creatureIds = @($samples | ForEach-Object { [string](Get-Field $_.Row "creature_id" "") } | Sort-Object -Unique)
	$activityBySlotRows += [ordered]@{
		slot_id = $groupInfo.Name
		slot_indexes = $slotIndexes
		sides = $sides
		creature_ids = $creatureIds
		metrics = New-ActivityAggregate $samples $MinimumSampleSize
	}
}

$activityByCreatureRows = @()
$creatureSampleCounts = @{}
foreach ($groupInfo in @($activitySamples | Group-Object { [string](Get-Field $_.Row "creature_id" "") } | Sort-Object Name)) {
	$samples = @($groupInfo.Group)
	$creatureSampleCounts[$groupInfo.Name] = $samples.Count
	$activityByCreatureRows += [ordered]@{
		creature_id = $groupInfo.Name
		sides = @($samples | ForEach-Object { [string]$_.Side } | Sort-Object -Unique)
		slot_ids = @($samples | ForEach-Object { [string](Get-Field $_.Row "slot_id" "") } | Sort-Object -Unique)
		metrics = New-ActivityAggregate $samples $MinimumSampleSize
	}
}

$persistentIdleRows = @()
foreach ($sample in @($activitySamples | Sort-Object RunId, Side, @{ Expression = {
		[long](Get-Field $_.Row "slot_index" -1)
	} })) {
	$row = $sample.Row
	if (-not (Test-PersistentIdleSample $row)) {
		continue
	}
	$aliveTicks = [double](Get-Field $row "alive_ticks" 0)
	$creatureId = [string](Get-Field $row "creature_id" "")
	$comparisonSamples = if ($creatureSampleCounts.ContainsKey($creatureId)) {
		[int]$creatureSampleCounts[$creatureId]
	} else {
		0
	}
	$persistentIdleRows += [ordered]@{
		run_id = $sample.RunId
		side = $sample.Side
		slot_id = [string](Get-Field $row "slot_id" "")
		slot_index = [long](Get-Field $row "slot_index" -1)
		creature_id = $creatureId
		alive_sec = [math]::Round($aliveTicks / $PhysicsTickRate, 3)
		max_idle_duration_sec = [math]::Round(
			[double](Get-Field $row "max_idle_ticks" 0) / $PhysicsTickRate,
			3
		)
		active_ratio = Get-SafeRatio (Get-Field $row "active_ticks" 0) $aliveTicks
		idle_ratio = Get-SafeRatio (Get-Field $row "idle_ticks" 0) $aliveTicks
		move_input_ratio = Get-SafeRatio (Get-Field $row "move_input_ticks" 0) $aliveTicks
		primary_press_count = [long](Get-Field $row "primary_press_count" 0)
		ability_press_count = [long](Get-Field $row "ability_press_count" 0)
		landed_hit_count = [long](Get-Field $row "landed_hit_count" 0)
		comparison_samples = $comparisonSamples
		sample_label = Get-SampleLabel -Samples $comparisonSamples -Minimum $MinimumSampleSize
		insufficient_sample = ($comparisonSamples -lt $MinimumSampleSize)
	}
}

$completeBossTelemetryRecords = @($telemetryRecords | Where-Object {
	[long](Get-Field (Get-BalanceTelemetry $_) "boss_lifecycle_truncated_events" 0) -eq 0
})
$truncatedBossTelemetryRecords = @($telemetryRecords | Where-Object {
	[long](Get-Field (Get-BalanceTelemetry $_) "boss_lifecycle_truncated_events" 0) -gt 0
})
$bossLifecycleRows = @()
foreach ($scope in @("Blue", "Red", "Center")) {
	foreach ($eventName in @("active", "claimable", "contested", "claimed", "stolen")) {
		$counts = @()
		$firstTimes = @()
		foreach ($record in $completeBossTelemetryRecords) {
			$events = @((Get-Field (Get-BalanceTelemetry $record) "boss_lifecycle_events"))
			$matching = @($events | Where-Object {
				$eventScope = if ([bool](Get-Field $_ "center" $false)) {
					"Center"
				} else {
					(Get-Culture).TextInfo.ToTitleCase([string](Get-Field $_ "side" ""))
				}
				$eventScope -eq $scope -and [string](Get-Field $_ "event" "") -eq $eventName
			})
			$counts += $matching.Count
			if ($matching.Count -gt 0) {
				$firstTimes += [double](Get-Field $matching[0] "elapsed_sec" 0)
			}
		}
		$bossLifecycleRows += [ordered]@{
			scope = $scope
			event = $eventName
			available_samples = $completeBossTelemetryRecords.Count
			unavailable_samples = $sortedRecords.Count - $completeBossTelemetryRecords.Count
			truncated_samples_excluded = $truncatedBossTelemetryRecords.Count
			availability = if ($completeBossTelemetryRecords.Count -eq 0) {
				"unavailable"
			} elseif ($completeBossTelemetryRecords.Count -lt $sortedRecords.Count) {
				"partial"
			} else {
				"available"
			}
			matches_with_event = $firstTimes.Count
			matches_without_event = $completeBossTelemetryRecords.Count - $firstTimes.Count
			event_count = New-Stats $counts $MinimumSampleSize
			first_elapsed_sec = New-Stats $firstTimes $MinimumSampleSize
		}
	}
}

$determinismAnomalies = @()
$repeatGroups = 0
$repeatRecords = 0
$signatureGroups = @($sortedRecords | Group-Object { Get-DeterminismSignature $_ } | Sort-Object Name)
foreach ($groupInfo in $signatureGroups) {
	$group = @($groupInfo.Group)
	if ($group.Count -lt 2) {
		continue
	}
	$repeatGroups += 1
	$repeatRecords += $group.Count
	$seriesGroups = @($group | Group-Object { Get-ChecksumSeries $_ })
	if ($seriesGroups.Count -gt 1) {
		$determinismAnomalies += [ordered]@{
			type = "checksum_series_divergence"
			request_signature = $groupInfo.Name
			run_ids = @($group | ForEach-Object { [string](Get-Field $_.Raw "run_id" "") } | Sort-Object)
			distinct_series = $seriesGroups.Count
		}
	}
}
$duplicateRunIdAnomalies = @()
foreach ($groupInfo in @($sortedRecords | Group-Object { [string](Get-Field $_.Raw "run_id" "") } | Where-Object Count -gt 1 | Sort-Object Name)) {
	$duplicateRunIdAnomalies += [ordered]@{
		type = "duplicate_run_id"
		run_id = $groupInfo.Name
		records = $groupInfo.Count
		sources = @($groupInfo.Group | ForEach-Object { "$($_.Source):$($_.Line)" } | Sort-Object)
	}
}
$allAnomalies = @($determinismAnomalies) + @($duplicateRunIdAnomalies)

$durationValues = @($sortedRecords | ForEach-Object {
	[double](Get-Field (Get-Field $_.Raw "match") "elapsed_sec" 0)
})
$summary = [ordered]@{
	schema = $SummarySchema
	source_schema = $ResultSchema
	minimum_sample_size = $MinimumSampleSize
	input = [ordered]@{
		files = @($inputFiles)
		nonempty_lines = $lineCount
		validation_only_records_excluded = $validationOnlyCount
		match_records = $sortedRecords.Count
	}
	validation = [ordered]@{
		valid = $true
		error_count = 0
		errors = @()
	}
	overall = [ordered]@{
		matches = $sortedRecords.Count
		completed = $completedCount
		timed_out = $timeoutCount
		timeout_rate = New-Rate $timeoutCount $sortedRecords.Count $MinimumSampleSize
		duration_sec = New-Stats $durationValues $MinimumSampleSize
		blue_wins = $blueWins
		red_wins = $redWins
		unresolved = $timeoutCount
	}
	by_side = $sideRows
	by_squad = $squadRows
	by_matchup = $matchupRows
	by_seed = $seedRows
	economy = $economyRows
	boss_objectives = $bossRows
	activity = [ordered]@{
		availability = if ($telemetryRecords.Count -eq 0) {
			"unavailable"
		} elseif ($telemetryRecords.Count -lt $sortedRecords.Count) {
			"partial"
		} else {
			"available"
		}
		matches_with_telemetry = $telemetryRecords.Count
		matches_without_telemetry = $sortedRecords.Count - $telemetryRecords.Count
		physics_tick_rate_hz = $PhysicsTickRate
		persistent_idle_thresholds = [ordered]@{
			min_alive_sec = $PersistentIdleMinAliveSec
			min_max_idle_duration_sec = $PersistentIdleMinMaxIdleSec
			min_idle_ratio = $PersistentIdleMinIdleRatio
			max_move_input_ratio = $PersistentIdleMaxMoveInputRatio
		}
		by_slot = $activityBySlotRows
		by_creature = $activityByCreatureRows
		persistent_idle_anomaly_count = $persistentIdleRows.Count
		persistent_idle_anomalies = $persistentIdleRows
	}
	boss_lifecycle = [ordered]@{
		availability = if ($telemetryRecords.Count -eq 0) {
			"unavailable"
		} elseif ($telemetryRecords.Count -lt $sortedRecords.Count -or
			$truncatedBossTelemetryRecords.Count -gt 0) {
			"partial"
		} else {
			"available"
		}
		matches_with_telemetry = $telemetryRecords.Count
		matches_without_telemetry = $sortedRecords.Count - $telemetryRecords.Count
		complete_stream_samples = $completeBossTelemetryRecords.Count
		truncated_stream_samples = $truncatedBossTelemetryRecords.Count
		total_events = New-Stats @($telemetryRecords | ForEach-Object {
			[double](Get-Field (Get-BalanceTelemetry $_) "boss_lifecycle_total_events" 0)
		}) $MinimumSampleSize
		retained_events = New-Stats @($telemetryRecords | ForEach-Object {
			[double](Get-Field (Get-BalanceTelemetry $_) "boss_lifecycle_retained_events" 0)
		}) $MinimumSampleSize
		truncated_events = New-Stats @($telemetryRecords | ForEach-Object {
			[double](Get-Field (Get-BalanceTelemetry $_) "boss_lifecycle_truncated_events" 0)
		}) $MinimumSampleSize
		by_scope_event = $bossLifecycleRows
	}
	determinism = [ordered]@{
		repeated_request_groups = $repeatGroups
		repeated_records = $repeatRecords
		checksum_series_divergences = $determinismAnomalies.Count
		duplicate_run_ids = $duplicateRunIdAnomalies.Count
		anomaly_count = $allAnomalies.Count
		status = if ($allAnomalies.Count -eq 0) { "clean" } else { "anomalies_detected" }
		anomalies = $allAnomalies
	}
}

$markdown = New-Object System.Collections.Generic.List[string]
$markdown.Add("# Battle Bog Balance Diagnostics")
$markdown.Add("")
$markdown.Add("- Records: **$($sortedRecords.Count)** matches from **$($inputFiles.Count)** file(s)")
$markdown.Add("- Completed: **$completedCount**; timed out: **$timeoutCount**; timeout rate: **$(Format-Rate $summary.overall.timeout_rate)**")
$markdown.Add("- Determinism: **$($summary.determinism.status)**; repeated request groups: **$repeatGroups**; anomalies: **$($allAnomalies.Count)**")
$markdown.Add("- Minimum sample for a conclusive label: **$MinimumSampleSize**")
if ($validationOnlyCount -gt 0) {
	$markdown.Add("- Validation-only records excluded: **$validationOnlyCount**")
}
$markdown.Add("")
$markdown.Add("## Side Results")
$markdown.Add("")
$markdown.Add("| Side | Wins | Losses | Unresolved | Win rate (all) | Win rate (resolved) | Mean stocks | Mean deposits | Mean breeds |")
$markdown.Add("| --- | ---: | ---: | ---: | --- | --- | ---: | ---: | ---: |")
foreach ($row in $sideRows) {
	$markdown.Add("| $($row.side) | $($row.wins) | $($row.losses) | $($row.unresolved) | $(Format-Rate $row.win_rate_all_matches) | $(Format-Rate $row.win_rate_resolved) | $($row.stocks_remaining.mean) | $($row.deposits.mean) | $($row.breeds_completed.mean) |")
}
$markdown.Add("")
$markdown.Add("## Squads")
$markdown.Add("")
$markdown.Add("| Squad | Roster | Games (B/R) | Wins (B/R) | Win rate |")
$markdown.Add("| --- | --- | ---: | ---: | --- |")
foreach ($row in $squadRows) {
	$rosterText = Escape-MarkdownCell ($row.roster -join ", ")
	$markdown.Add("| $($row.squad_id) | $rosterText | $($row.appearances) ($($row.blue_appearances)/$($row.red_appearances)) | $($row.wins) ($($row.wins_as_blue)/$($row.wins_as_red)) | $(Format-Rate $row.win_rate) |")
}
$markdown.Add("")
$markdown.Add("## Matchups")
$markdown.Add("")
$markdown.Add("| Matchup | Matches | Blue wins | Red wins | Squad A win rate | Timeout rate |")
$markdown.Add("| --- | ---: | ---: | ---: | --- | --- |")
foreach ($row in $matchupRows) {
	$markdown.Add("| $(Escape-MarkdownCell $row.matchup_id) | $($row.matches) | $($row.blue_wins) | $($row.red_wins) | $(Format-Rate $row.squad_a_win_rate) | $(Format-Rate $row.timeout_rate) |")
}
$markdown.Add("")
$markdown.Add("## Economy Timing")
$markdown.Add("")
$markdown.Add("| Side | Event | Total | Matches with event | Missing | Mean first time (s) | Target rate | Sample |")
$markdown.Add("| --- | --- | ---: | ---: | ---: | ---: | --- | --- |")
foreach ($row in $economyRows) {
	$mean = if ($null -eq $row.first_elapsed_sec.mean) { "n/a" } else { [string]$row.first_elapsed_sec.mean }
	$markdown.Add("| $($row.side) | $($row.event) | $($row.event_totals.total) | $($row.matches_with_event) | $($row.matches_missing_event) | $mean | <=$($row.target_elapsed_sec)s: $(Format-Rate $row.target_met_rate) | $($row.first_elapsed_sec.sample_label) |")
}
$markdown.Add("")
$markdown.Add("## Boss Objectives")
$markdown.Add("")
$markdown.Add("| Side | Metric | Available | Total | Mean | Sample |")
$markdown.Add("| --- | --- | ---: | ---: | ---: | --- |")
foreach ($row in $bossRows) {
	$mean = if ($null -eq $row.values.mean) { "n/a" } else { [string]$row.values.mean }
	$markdown.Add("| $($row.side) | $($row.metric) | $($row.available_samples)/$($sortedRecords.Count) | $($row.values.total) | $mean | $($row.values.sample_label) |")
}
$markdown.Add("")
$markdown.Add("## Activity Telemetry")
$markdown.Add("")
$markdown.Add("- Availability: **$($summary.activity.availability)** ($($telemetryRecords.Count)/$($sortedRecords.Count) matches)")
$markdown.Add("- Persistent idle threshold: alive >= **$($PersistentIdleMinAliveSec)s**, max idle >= **$($PersistentIdleMinMaxIdleSec)s**, idle ratio >= **$($PersistentIdleMinIdleRatio)**, move-input ratio <= **$($PersistentIdleMaxMoveInputRatio)**")
$markdown.Add("")
$markdown.Add("### By Stable Slot")
$markdown.Add("")
$markdown.Add("| Slot | Side | Creatures | Samples | Max idle mean/max (s) | Active/idle mean | Distance mean | Move-input mean | Primary/ability mean | Hits mean | Idle anomaly rate | Sample |")
$markdown.Add("| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |")
foreach ($row in $activityBySlotRows) {
	$metrics = $row.metrics
	$markdown.Add("| $(Escape-MarkdownCell $row.slot_id) | $(Escape-MarkdownCell ($row.sides -join ", ")) | $(Escape-MarkdownCell ($row.creature_ids -join ", ")) | $($metrics.samples) | $($metrics.max_idle_duration_sec.mean)/$($metrics.max_idle_duration_sec.max) | $($metrics.active_ratio.mean)/$($metrics.idle_ratio.mean) | $($metrics.distance_traveled_px.mean) | $($metrics.move_input_ratio.mean) | $($metrics.primary_press_count.mean)/$($metrics.ability_press_count.mean) | $($metrics.landed_hit_count.mean) | $(Format-Rate $metrics.persistent_idle_rate) | $($metrics.sample_label) |")
}
if ($activityBySlotRows.Count -eq 0) {
	$markdown.Add("| n/a | n/a | n/a | 0 | n/a | n/a | n/a | n/a | n/a | n/a | n/a | unavailable |")
}
$markdown.Add("")
$markdown.Add("### By Creature")
$markdown.Add("")
$markdown.Add("| Creature | Sides | Samples | Max idle mean/max (s) | Active/idle mean | Distance mean | Move-input mean | Primary/ability mean | Hits mean | Idle anomaly rate | Sample |")
$markdown.Add("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |")
foreach ($row in $activityByCreatureRows) {
	$metrics = $row.metrics
	$markdown.Add("| $(Escape-MarkdownCell $row.creature_id) | $(Escape-MarkdownCell ($row.sides -join ", ")) | $($metrics.samples) | $($metrics.max_idle_duration_sec.mean)/$($metrics.max_idle_duration_sec.max) | $($metrics.active_ratio.mean)/$($metrics.idle_ratio.mean) | $($metrics.distance_traveled_px.mean) | $($metrics.move_input_ratio.mean) | $($metrics.primary_press_count.mean)/$($metrics.ability_press_count.mean) | $($metrics.landed_hit_count.mean) | $(Format-Rate $metrics.persistent_idle_rate) | $($metrics.sample_label) |")
}
if ($activityByCreatureRows.Count -eq 0) {
	$markdown.Add("| n/a | n/a | 0 | n/a | n/a | n/a | n/a | n/a | n/a | n/a | unavailable |")
}
$markdown.Add("")
$markdown.Add("### Persistent Idle Anomalies")
$markdown.Add("")
if ($persistentIdleRows.Count -eq 0) {
	$markdown.Add("No slot sample crossed every conservative persistent-idle threshold.")
} else {
	$markdown.Add("| Run | Side | Slot | Creature | Alive (s) | Max idle (s) | Active/idle | Move input | Primary/ability | Hits | Comparison sample |")
	$markdown.Add("| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |")
	foreach ($row in $persistentIdleRows) {
		$markdown.Add("| $(Escape-MarkdownCell $row.run_id) | $($row.side) | $(Escape-MarkdownCell $row.slot_id) | $(Escape-MarkdownCell $row.creature_id) | $($row.alive_sec) | $($row.max_idle_duration_sec) | $($row.active_ratio)/$($row.idle_ratio) | $($row.move_input_ratio) | $($row.primary_press_count)/$($row.ability_press_count) | $($row.landed_hit_count) | $($row.comparison_samples) $($row.sample_label) |")
	}
}
$markdown.Add("")
$markdown.Add("## Boss Lifecycle Telemetry")
$markdown.Add("")
$markdown.Add("- Availability: **$($summary.boss_lifecycle.availability)**; complete streams: **$($completeBossTelemetryRecords.Count)**; truncated streams excluded from event timing/count aggregation: **$($truncatedBossTelemetryRecords.Count)**")
$markdown.Add("")
$markdown.Add("| Scope | Event | Available | Matches with event | Count mean | First time mean (s) | Sample |")
$markdown.Add("| --- | --- | ---: | ---: | ---: | ---: | --- |")
foreach ($row in $bossLifecycleRows) {
	$countMean = if ($null -eq $row.event_count.mean) { "n/a" } else { [string]$row.event_count.mean }
	$firstMean = if ($null -eq $row.first_elapsed_sec.mean) { "n/a" } else { [string]$row.first_elapsed_sec.mean }
	$markdown.Add("| $($row.scope) | $($row.event) | $($row.available_samples)/$($sortedRecords.Count) | $($row.matches_with_event) | $countMean | $firstMean | $($row.event_count.sample_label) |")
}
$markdown.Add("")
$markdown.Add("## Determinism")
$markdown.Add("")
if ($allAnomalies.Count -eq 0) {
	$markdown.Add("No checksum-series divergence or duplicate run-id anomaly was detected.")
} else {
	foreach ($anomaly in $allAnomalies) {
		$markdown.Add("- **$($anomaly.type)**: $(Escape-MarkdownCell ($anomaly | ConvertTo-Json -Compress -Depth 10))")
	}
}
$insufficientCount = @($squadRows | Where-Object { $_.win_rate.insufficient_sample }).Count +
	@($matchupRows | Where-Object { $_.squad_a_win_rate.insufficient_sample }).Count
$markdown.Add("")
$markdown.Add("## Interpretation")
$markdown.Add("")
if ($insufficientCount -gt 0) {
	$markdown.Add("`insufficient_sample` labels are active for $insufficientCount squad or matchup result row(s). Treat those rates as descriptive only.")
} else {
	$markdown.Add("All squad and matchup result rows meet the configured minimum sample size.")
}

foreach ($outputPath in @($JsonOutputPath, $MarkdownOutputPath)) {
	$parent = Split-Path -Parent $outputPath
	if (-not [string]::IsNullOrWhiteSpace($parent)) {
		New-Item -ItemType Directory -Force -Path $parent | Out-Null
	}
}
$jsonText = $summary | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($JsonOutputPath, $jsonText + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($MarkdownOutputPath, ($markdown -join [Environment]::NewLine) + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))

Write-Host "Battle Bog balance summary PASS"
Write-Host "Records:  $($sortedRecords.Count)"
Write-Host "JSON:     $JsonOutputPath"
Write-Host "Markdown: $MarkdownOutputPath"
if ($allAnomalies.Count -gt 0) {
	Write-Warning "Detected $($allAnomalies.Count) determinism/run-id anomaly record(s)."
}
