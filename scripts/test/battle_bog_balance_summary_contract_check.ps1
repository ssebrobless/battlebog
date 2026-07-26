$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$summarizer = Join-Path $scriptRoot "summarize_balance_sim.ps1"
if (-not (Test-Path -LiteralPath $summarizer)) {
	throw "Missing summarizer: $summarizer"
}

function Assert-Contract {
	param(
		[bool]$Condition,
		[string]$Message
	)
	if (-not $Condition) {
		throw "balance summary contract failure: $Message"
	}
}

function New-Team {
	param(
		[int]$Stocks,
		[int]$Deposits,
		[int]$Breeds,
		[int]$BossClaims = 0,
		[int]$BossSteals = 0,
		[int]$CenterClaims = 0
	)
	return [ordered]@{
		name = ""
		stocks_remaining = $Stocks
		max_stocks = 9
		deposits = $Deposits
		breeds_completed = $Breeds
		boss_claims = $BossClaims
		boss_steals = $BossSteals
		center_claims = $CenterClaims
	}
}

function New-EconomyTeam {
	param(
		[int]$Food,
		[double]$FoodFirst,
		[int]$Deposits,
		[double]$DepositFirst,
		[int]$Breeds,
		[double]$BreedFirst
	)
	$counts = [ordered]@{}
	$first = [ordered]@{}
	if ($Food -gt 0) {
		$counts.food_consumed = $Food
		$first.food_consumed = $FoodFirst
	}
	if ($Deposits -gt 0) {
		$counts.deposit_committed = $Deposits
		$first.deposit_committed = $DepositFirst
	}
	if ($Breeds -gt 0) {
		$counts.breed_completed = $Breeds
		$first.breed_completed = $BreedFirst
	}
	return [ordered]@{
		counts = $counts
		first_elapsed_sec = $first
	}
}

function New-SlotActivity {
	param(
		[string]$SlotId,
		[int]$SlotIndex,
		[int]$Team,
		[string]$CreatureId,
		[switch]$PersistentIdle
	)
	$activeTicks = if ($PersistentIdle) { 600 } else { 3000 }
	$idleTicks = 3600 - $activeTicks
	$moveInputTicks = if ($PersistentIdle) { 120 } else { 2800 }
	return [ordered]@{
		slot_id = $SlotId
		slot_index = $SlotIndex
		team = $Team
		creature_id = $CreatureId
		sample_ticks = 3600
		alive_ticks = 3600
		active_ticks = $activeTicks
		idle_ticks = $idleTicks
		current_idle_ticks = if ($PersistentIdle) { 900 } else { 0 }
		max_idle_ticks = if ($PersistentIdle) { 1200 } else { 120 }
		distance_traveled_px = if ($PersistentIdle) { 125.5 } else { 4200.25 }
		move_input_ticks = $moveInputTicks
		primary_press_count = if ($PersistentIdle) { 0 } else { 12 }
		ability_press_count = if ($PersistentIdle) { 0 } else { 3 }
		ability_q_press_count = if ($PersistentIdle) { 0 } else { 2 }
		ability_e_press_count = if ($PersistentIdle) { 0 } else { 1 }
		landed_hit_count = if ($PersistentIdle) { 0 } else { 7 }
	}
}

function New-BalanceTelemetry {
	param(
		[string[]]$BlueRoster,
		[string[]]$RedRoster,
		[string]$PersistentIdleCreature = ""
	)
	$slots = @()
	for ($index = 0; $index -lt 3; $index += 1) {
		$blueId = $BlueRoster[$index]
		$redId = $RedRoster[$index]
		$slots += New-SlotActivity "blue:$index" $index 0 $blueId `
			-PersistentIdle:($blueId -eq $PersistentIdleCreature)
		$slots += New-SlotActivity "red:$index" $index 1 $redId `
			-PersistentIdle:($redId -eq $PersistentIdleCreature)
	}
	return [ordered]@{
		slot_activity = $slots
		boss_lifecycle_events = @(
			[ordered]@{
				sequence = 1
				event = "active"
				elapsed_sec = 60.0
				simulation_tick = 3600
				zone_id = "blue_boss"
				family = "champsosaurus"
				center = $false
				side = "blue"
				owner_team = 0
				acting_team = 0
				from_state = "dormant"
				objective_state = "active"
				trigger = "side_wake"
			},
			[ordered]@{
				sequence = 2
				event = "claimable"
				elapsed_sec = 120.0
				simulation_tick = 7200
				zone_id = "blue_boss"
				family = "champsosaurus"
				center = $false
				side = "blue"
				owner_team = 0
				acting_team = -1
				from_state = "active"
				objective_state = "claimable"
				trigger = ""
			},
			[ordered]@{
				sequence = 3
				event = "active"
				elapsed_sec = 600.0
				simulation_tick = 36000
				zone_id = "center_boss"
				family = "teratornis"
				center = $true
				side = "center"
				owner_team = -1
				acting_team = -1
				from_state = "dormant"
				objective_state = "active"
				trigger = "center_spawn"
			}
		)
		boss_lifecycle_total_events = 3
		boss_lifecycle_retained_events = 3
		boss_lifecycle_truncated_events = 0
	}
}

function New-SyntheticRecord {
	param(
		[string]$RunId,
		[string[]]$BlueRoster,
		[string[]]$RedRoster,
		[long]$Seed,
		[string]$Status,
		[string]$Winner,
		[string]$Hash,
		[int]$BlueStocks,
		[int]$RedStocks,
		[int]$BlueDeposits,
		[int]$RedDeposits,
		[int]$BlueBreeds,
		[int]$RedBreeds
	)
	$timedOut = $Status -eq "timeout"
	$completed = $Status -eq "completed"
	$elapsed = if ($timedOut) { 900.0 } else { 600.0 + $Seed }
	$blueTeam = New-Team $BlueStocks $BlueDeposits $BlueBreeds 1 0 0
	$redTeam = New-Team $RedStocks $RedDeposits $RedBreeds 0 1 1
	$blueTeam.name = "Blue"
	$redTeam.name = "Red"
	return [ordered]@{
		schema = "battle_bog.balance_sim.v1"
		run_id = $RunId
		status = $Status
		completed = $completed
		timed_out = $timedOut
		validation_only = $false
		integration_checked = $true
		physics_ticks = [int]($elapsed * 60)
		simulated_sec = $elapsed
		requested = [ordered]@{
			blue_roster = @($BlueRoster)
			red_roster = @($RedRoster)
			simulation_seed = $Seed
			max_simulated_sec = 900.0
			checksum_interval_sec = 30.0
		}
		checksums = @(
			[ordered]@{
				tick = [int]($elapsed * 60)
				simulated_sec = $elapsed
				sha256 = $Hash
			}
		)
		final_checksum = $Hash
		match = [ordered]@{
			schema = "battle_bog_match_summary_v1"
			winner = $Winner
			reason = if ($timedOut) { "simulation_timeout" } else { "team_exhausted" }
			elapsed_sec = $elapsed
			simulation_seed = $Seed
			resolved_rosters = [ordered]@{
				blue = @($BlueRoster)
				red = @($RedRoster)
			}
			teams = [ordered]@{
				blue = $blueTeam
				red = $redTeam
			}
			economy_summary = [ordered]@{
				by_team = [ordered]@{
					blue = New-EconomyTeam 4 80.0 $BlueDeposits 180.0 $BlueBreeds 260.0
					red = New-EconomyTeam 3 95.0 $RedDeposits 210.0 $RedBreeds 285.0
				}
			}
		}
	}
}

function Write-JsonLines {
	param(
		[string]$Path,
		[object[]]$Records
	)
	$lines = @($Records | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 30 })
	[System.IO.File]::WriteAllText(
		$Path,
		($lines -join [Environment]::NewLine) + [Environment]::NewLine,
		[System.Text.UTF8Encoding]::new($false)
	)
}

$s1 = @("snapping_turtle", "chorus_frog", "mink")
$s2 = @("beaver", "duck", "firefly")
$hashA = "a" * 64
$hashB = "b" * 64
$hashC = "c" * 64
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "battle-bog-balance-summary-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

try {
	$validPath = Join-Path $tempRoot "valid.jsonl"
	$validRecords = @(
		(New-SyntheticRecord "repeat-a" $s1 $s2 7 "completed" "Blue" $hashA 5 2 3 1 2 1),
		(New-SyntheticRecord "repeat-b" $s1 $s2 7 "completed" "Blue" $hashA 5 2 3 1 2 1),
		(New-SyntheticRecord "mirror" $s2 $s1 19 "completed" "Red" $hashB 3 6 1 3 1 2),
		(New-SyntheticRecord "timeout" $s1 $s2 43 "timeout" "" $hashC 7 7 1 1 0 0),
		[ordered]@{
			schema = "battle_bog.balance_sim.v1"
			run_id = "validation-only"
			status = "validation_ok"
			validation_only = $true
			requested = [ordered]@{
				blue_roster = @($s1)
				red_roster = @($s2)
				simulation_seed = 7
				max_simulated_sec = 900.0
				checksum_interval_sec = 30.0
			}
		}
	)
	$validRecords[0].match.balance_telemetry = New-BalanceTelemetry $s1 $s2
	$validRecords[1].match.balance_telemetry = New-BalanceTelemetry $s1 $s2
	$validRecords[2].match.balance_telemetry = New-BalanceTelemetry $s2 $s1 "firefly"
	$validRecords[2].match.balance_telemetry.boss_lifecycle_truncated_events = 2
	$validRecords[2].match.balance_telemetry.boss_lifecycle_total_events = 5
	for ($eventIndex = 0; $eventIndex -lt 3; $eventIndex += 1) {
		$validRecords[2].match.balance_telemetry.boss_lifecycle_events[$eventIndex].sequence += 2
	}
	$null = $validRecords[3].match.teams.blue.Remove("boss_claims")
	Write-JsonLines $validPath $validRecords
	$jsonPath = Join-Path $tempRoot "summary.json"
	$markdownPath = Join-Path $tempRoot "summary.md"
	try {
		& $summarizer -InputPath $validPath -JsonOutputPath $jsonPath `
			-MarkdownOutputPath $markdownPath -MinimumSampleSize 8
	} catch {
		Write-Host $_.ScriptStackTrace
		throw
	}

	$summary = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
	$markdown = Get-Content -LiteralPath $markdownPath -Raw
	Assert-Contract ($summary.schema -eq "battle_bog.balance_summary.v1") "summary schema"
	Assert-Contract ([int]$summary.overall.matches -eq 4) "match count"
	Assert-Contract ([int]$summary.overall.completed -eq 3) "completed count"
	Assert-Contract ([int]$summary.overall.timed_out -eq 1) "timeout count"
	Assert-Contract ([int]$summary.overall.blue_wins -eq 2) "Blue win count"
	Assert-Contract ([int]$summary.overall.red_wins -eq 1) "Red win count"
	Assert-Contract ([int]$summary.input.validation_only_records_excluded -eq 1) "validation-only exclusion"
	Assert-Contract (@($summary.by_squad).Count -eq 2) "canonical squad grouping"
	Assert-Contract (@($summary.by_matchup).Count -eq 1) "unordered matchup grouping"
	Assert-Contract (@($summary.by_seed).Count -eq 3) "seed grouping"
	Assert-Contract (@($summary.economy).Count -eq 6) "economy side/event rows"
	Assert-Contract (@($summary.boss_objectives).Count -eq 6) "boss metric rows"
	$blueBossClaims = @($summary.boss_objectives | Where-Object {
		$_.side -eq "Blue" -and $_.metric -eq "boss_claims"
	})[0]
	Assert-Contract ([int]$blueBossClaims.available_samples -eq 3) "optional boss metric availability"
	Assert-Contract ([int]$blueBossClaims.unavailable_samples -eq 1) "optional boss metric absence"
	Assert-Contract ($summary.activity.availability -eq "partial") "activity telemetry partial availability"
	Assert-Contract ([int]$summary.activity.matches_with_telemetry -eq 3) "activity telemetry available match count"
	Assert-Contract ([int]$summary.activity.matches_without_telemetry -eq 1) "activity telemetry unavailable match count"
	Assert-Contract (@($summary.activity.by_slot).Count -eq 6) "six stable slot aggregates"
	Assert-Contract (@($summary.activity.by_creature).Count -eq 6) "creature activity aggregates"
	Assert-Contract ([int]$summary.activity.persistent_idle_anomaly_count -eq 1) "persistent idle anomaly count"
	$idleAnomaly = @($summary.activity.persistent_idle_anomalies)[0]
	Assert-Contract ($idleAnomaly.creature_id -eq "firefly") "persistent idle creature identity"
	Assert-Contract ([double]$idleAnomaly.max_idle_duration_sec -eq 20.0) "idle tick-to-second conversion"
	Assert-Contract ([bool]$idleAnomaly.insufficient_sample) "idle anomaly comparison sample label"
	$fireflyActivity = @($summary.activity.by_creature | Where-Object {
		$_.creature_id -eq "firefly"
	})[0]
	Assert-Contract ([double]$fireflyActivity.metrics.max_idle_duration_sec.max -eq 20.0) "creature max idle aggregate"
	Assert-Contract ([double]$fireflyActivity.metrics.distance_traveled_px.samples -eq 3) "creature distance samples"
	Assert-Contract ($summary.boss_lifecycle.availability -eq "partial") "boss lifecycle partial availability"
	Assert-Contract ([int]$summary.boss_lifecycle.complete_stream_samples -eq 2) "boss lifecycle complete streams"
	Assert-Contract ([int]$summary.boss_lifecycle.truncated_stream_samples -eq 1) "boss lifecycle truncated streams"
	$blueActive = @($summary.boss_lifecycle.by_scope_event | Where-Object {
		$_.scope -eq "Blue" -and $_.event -eq "active"
	})[0]
	Assert-Contract ([int]$blueActive.matches_with_event -eq 2) "boss lifecycle event count"
	Assert-Contract ([double]$blueActive.first_elapsed_sec.mean -eq 60.0) "boss lifecycle first timing"
	$centerActive = @($summary.boss_lifecycle.by_scope_event | Where-Object {
		$_.scope -eq "Center" -and $_.event -eq "active"
	})[0]
	Assert-Contract ([double]$centerActive.event_count.total -eq 2.0) "center boss lifecycle aggregate"
	Assert-Contract ([int]$summary.determinism.repeated_request_groups -eq 1) "repeat grouping"
	Assert-Contract ([int]$summary.determinism.anomaly_count -eq 0) "identical repeats are clean"
	Assert-Contract ([bool]$summary.by_matchup[0].squad_a_win_rate.insufficient_sample) "small matchup is labeled insufficient"
	Assert-Contract ($markdown.Contains("insufficient_sample")) "Markdown insufficient-sample label"
	Assert-Contract ($markdown.Contains("Economy Timing")) "Markdown economy diagnostics"
	Assert-Contract ($markdown.Contains("Activity Telemetry")) "Markdown activity diagnostics"
	Assert-Contract ($markdown.Contains("Persistent Idle Anomalies")) "Markdown idle anomaly diagnostics"
	Assert-Contract ($markdown.Contains("Boss Lifecycle Telemetry")) "Markdown boss lifecycle diagnostics"

	$anomalyPath = Join-Path $tempRoot "anomaly.jsonl"
	Write-JsonLines $anomalyPath @(
		(New-SyntheticRecord "det-a" $s1 $s2 101 "timeout" "" $hashA 8 8 0 0 0 0),
		(New-SyntheticRecord "det-b" $s1 $s2 101 "timeout" "" $hashB 8 8 0 0 0 0)
	)
	$anomalyJson = Join-Path $tempRoot "anomaly-summary.json"
	$anomalyMarkdown = Join-Path $tempRoot "anomaly-summary.md"
	& $summarizer -InputPath $anomalyPath -JsonOutputPath $anomalyJson `
		-MarkdownOutputPath $anomalyMarkdown -MinimumSampleSize 2
	$anomalySummary = Get-Content -LiteralPath $anomalyJson -Raw | ConvertFrom-Json
	Assert-Contract ([int]$anomalySummary.determinism.checksum_series_divergences -eq 1) "checksum divergence detection"
	Assert-Contract ($anomalySummary.determinism.status -eq "anomalies_detected") "determinism status"
	Assert-Contract ($anomalySummary.activity.availability -eq "unavailable") "absent activity is unavailable"
	Assert-Contract ([int]$anomalySummary.activity.matches_with_telemetry -eq 0) "absent activity is not zero-filled"
	Assert-Contract (@($anomalySummary.activity.by_slot).Count -eq 0) "absent activity has no synthetic slot rows"
	Assert-Contract ($anomalySummary.boss_lifecycle.availability -eq "unavailable") "absent boss lifecycle is unavailable"
	Assert-Contract ([int]$anomalySummary.boss_lifecycle.complete_stream_samples -eq 0) "absent boss lifecycle has no samples"
	Assert-Contract ($null -eq $anomalySummary.boss_lifecycle.by_scope_event[0].event_count.mean) "absent boss event mean is null"

	$invalidPath = Join-Path $tempRoot "invalid.jsonl"
	$invalid = $validRecords[0]
	$invalid.schema = "wrong.schema"
	Write-JsonLines $invalidPath @($invalid)
	$invalidRejected = $false
	try {
		& $summarizer -InputPath $invalidPath `
			-JsonOutputPath (Join-Path $tempRoot "invalid-summary.json") `
			-MarkdownOutputPath (Join-Path $tempRoot "invalid-summary.md")
	} catch {
		$invalidRejected = $_.Exception.Message.Contains("schema must be")
	}
	Assert-Contract $invalidRejected "malformed schema rejection"

	$invalidSlotsPath = Join-Path $tempRoot "invalid-slots.jsonl"
	$invalidSlots = New-SyntheticRecord "invalid-slots" $s1 $s2 7 "timeout" "" $hashA 8 8 0 0 0 0
	$invalidSlots.match.balance_telemetry = New-BalanceTelemetry $s1 $s2
	$invalidSlots.match.balance_telemetry.slot_activity[5].slot_id = "blue:0"
	Write-JsonLines $invalidSlotsPath @($invalidSlots)
	$invalidSlotsRejected = $false
	try {
		& $summarizer -InputPath $invalidSlotsPath `
			-JsonOutputPath (Join-Path $tempRoot "invalid-slots-summary.json") `
			-MarkdownOutputPath (Join-Path $tempRoot "invalid-slots-summary.md")
	} catch {
		$invalidSlotsRejected = $_.Exception.Message.Contains("six unique stable slot ids")
	}
	Assert-Contract $invalidSlotsRejected "duplicate stable slot rejection"

	$invalidMetricPath = Join-Path $tempRoot "invalid-metric.jsonl"
	$invalidMetric = New-SyntheticRecord "invalid-metric" $s1 $s2 7 "timeout" "" $hashA 8 8 0 0 0 0
	$invalidMetric.match.balance_telemetry = New-BalanceTelemetry $s1 $s2
	$invalidMetric.match.balance_telemetry.slot_activity[0].distance_traveled_px = -1.0
	Write-JsonLines $invalidMetricPath @($invalidMetric)
	$invalidMetricRejected = $false
	try {
		& $summarizer -InputPath $invalidMetricPath `
			-JsonOutputPath (Join-Path $tempRoot "invalid-metric-summary.json") `
			-MarkdownOutputPath (Join-Path $tempRoot "invalid-metric-summary.md")
	} catch {
		$invalidMetricRejected = $_.Exception.Message.Contains("finite nonnegative number")
	}
	Assert-Contract $invalidMetricRejected "negative slot metric rejection"

	$invalidEventsPath = Join-Path $tempRoot "invalid-events.jsonl"
	$invalidEvents = New-SyntheticRecord "invalid-events" $s1 $s2 7 "timeout" "" $hashA 8 8 0 0 0 0
	$invalidEvents.match.balance_telemetry = New-BalanceTelemetry $s1 $s2
	$invalidEvents.match.balance_telemetry.boss_lifecycle_events[1].elapsed_sec = 50.0
	Write-JsonLines $invalidEventsPath @($invalidEvents)
	$invalidEventsRejected = $false
	try {
		& $summarizer -InputPath $invalidEventsPath `
			-JsonOutputPath (Join-Path $tempRoot "invalid-events-summary.json") `
			-MarkdownOutputPath (Join-Path $tempRoot "invalid-events-summary.md")
	} catch {
		$invalidEventsRejected = $_.Exception.Message.Contains("monotonic")
	}
	Assert-Contract $invalidEventsRejected "non-monotonic boss event rejection"

	$invalidTruncationPath = Join-Path $tempRoot "invalid-truncation.jsonl"
	$invalidTruncation = New-SyntheticRecord "invalid-truncation" $s1 $s2 7 "timeout" "" $hashA 8 8 0 0 0 0
	$invalidTruncation.match.balance_telemetry = New-BalanceTelemetry $s1 $s2
	$invalidTruncation.match.balance_telemetry.boss_lifecycle_total_events = 4
	Write-JsonLines $invalidTruncationPath @($invalidTruncation)
	$invalidTruncationRejected = $false
	try {
		& $summarizer -InputPath $invalidTruncationPath `
			-JsonOutputPath (Join-Path $tempRoot "invalid-truncation-summary.json") `
			-MarkdownOutputPath (Join-Path $tempRoot "invalid-truncation-summary.md")
	} catch {
		$invalidTruncationRejected = $_.Exception.Message.Contains("total must equal retained plus truncated")
	}
	Assert-Contract $invalidTruncationRejected "boss truncation metadata rejection"

	Write-Host "battle_bog_balance_summary_contract_check PASS"
} finally {
	Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
