param(
	[string]$Godot = "",
	[string[]]$BlueRoster = @("snapping_turtle", "chorus_frog", "mink"),
	[string[]]$RedRoster = @("snapping_turtle", "chorus_frog", "mink"),
	[long]$Seed = 7,
	[double]$MaxSimSeconds = 180.0,
	[double]$ChecksumSeconds = 30.0,
	[string]$OutputPath = "",
	[string]$RunId = "",
	[int]$TimeoutSec = 120,
	[switch]$Append,
	[switch]$Smoke,
	[switch]$ValidateOnly,
	[switch]$Profile
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$PlayableIds = @(
	"snapping_turtle", "chorus_frog", "mink", "beaver", "otter", "leech",
	"owl", "duck", "bullfrog", "cane_toad", "crayfish", "bog_turtle",
	"water_shrew", "newt", "great_blue_heron", "kingfisher", "water_snake",
	"alligator", "wolf_spider", "firefly", "mosquito_swarm"
)

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
	foreach ($candidate in @($Requested, $env:GODOT4, "godot")) {
		$resolved = Resolve-Executable $candidate
		if ($null -ne $resolved) {
			return $resolved
		}
	}

	$wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
	if (Test-Path -LiteralPath $wingetRoot) {
		$matches = Get-ChildItem -LiteralPath $wingetRoot -Directory -ErrorAction SilentlyContinue |
			Where-Object { $_.Name -match "Godot" } |
			ForEach-Object {
				Get-ChildItem -LiteralPath $_.FullName -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue
			} |
			Where-Object { $_.Name -match "godot" -and $_.Name -notmatch "headless|server" } |
			Sort-Object @{ Expression = { $_.Name -notmatch "console" } }, LastWriteTime -Descending
		$match = $matches | Select-Object -First 1
		if ($null -ne $match) {
			return $match.FullName
		}
	}
	throw "Could not locate Godot. Pass -Godot or set `$env:GODOT4."
}

function Assert-Roster {
	param(
		[string]$Label,
		[string[]]$Roster
	)
	if ($Roster.Count -ne 3) {
		throw "$Label roster must contain exactly three creature ids."
	}
	$unique = @($Roster | Select-Object -Unique)
	if ($unique.Count -ne 3) {
		throw "$Label roster must contain three unique creature ids."
	}
	foreach ($creatureId in $Roster) {
		if ($creatureId -notin $PlayableIds) {
			throw "$Label roster contains unknown creature id '$creatureId'."
		}
	}
}

function Get-StrictOutputIssues {
	param([string]$Output)
	$issues = @()
	$lines = $Output -split "\r?\n"
	for ($i = 0; $i -lt $lines.Count; $i++) {
		$line = $lines[$i]
		if ($line -match '^\s*WARNING:\s+ObjectDB instances leaked at exit') {
			continue
		}
		if ($line -match '^\s*ERROR:\s+\d+\s+resources? still in use at exit') {
			continue
		}
		if ($line -match '\bSCRIPT ERROR:' -or
			$line -match '\bParse Error\b' -or
			$line -match '^\s*ERROR:') {
			$issues += "line $($i + 1): $line"
		}
	}
	return $issues
}

Assert-Roster -Label "Blue" -Roster $BlueRoster
Assert-Roster -Label "Red" -Roster $RedRoster
if ($Seed -lt 0) {
	throw "Seed must be zero or greater."
}
if ($MaxSimSeconds -le 0.0) {
	throw "MaxSimSeconds must be greater than zero."
}
if ($ChecksumSeconds -le 0.0) {
	throw "ChecksumSeconds must be greater than zero."
}
if ($TimeoutSec -le 0) {
	throw "TimeoutSec must be greater than zero."
}

if ($Smoke -and -not $PSBoundParameters.ContainsKey("MaxSimSeconds")) {
	$MaxSimSeconds = 2.0
}
if ($Smoke -and -not $PSBoundParameters.ContainsKey("ChecksumSeconds")) {
	$ChecksumSeconds = 1.0
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..\..")).Path
$runnerPath = Join-Path $scriptRoot "run_balance_sim.gd"
if (-not (Test-Path -LiteralPath $runnerPath)) {
	throw "Missing Godot runner: $runnerPath"
}
$godotPath = Resolve-Godot $Godot

$safeRunId = if ([string]::IsNullOrWhiteSpace($RunId)) {
	"seed-$Seed-$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
} else {
	$RunId
}
$safeRunId = $safeRunId -replace '[^A-Za-z0-9_.-]', '_'

$artifactDir = Join-Path $repoRoot "artifacts\balance-sim"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
	$OutputPath = Join-Path $artifactDir "results.jsonl"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
	$OutputPath = Join-Path $repoRoot $OutputPath
}
$outputParent = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputParent)) {
	New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
}

$tempResult = Join-Path $artifactDir ".$safeRunId.result.jsonl"
$logPath = Join-Path $artifactDir "$safeRunId.log"
Remove-Item -LiteralPath $tempResult -Force -ErrorAction SilentlyContinue

$userArguments = @(
	"--bb-blue=$($BlueRoster -join ',')",
	"--bb-red=$($RedRoster -join ',')",
	"--bb-seed=$Seed",
	"--bb-max-seconds=$MaxSimSeconds",
	"--bb-checksum-seconds=$ChecksumSeconds",
	"--bb-output=$tempResult",
	"--bb-run-id=$safeRunId"
)
if ($ValidateOnly) {
	$userArguments += "--bb-validate-only"
}
if ($Profile) {
	$userArguments += "--bb-profile"
}

$relativeRunner = $runnerPath.Substring($repoRoot.Length).TrimStart("\", "/") -replace "\\", "/"
$job = Start-Job -ArgumentList $godotPath, $repoRoot, $relativeRunner, $userArguments -ScriptBlock {
	param(
		[string]$InnerGodot,
		[string]$InnerRepo,
		[string]$InnerRunner,
		[string[]]$InnerUserArguments
	)
	Set-Location -LiteralPath $InnerRepo
	$lines = & $InnerGodot --headless --disable-render-loop --path $InnerRepo --fixed-fps 60 --script $InnerRunner -- @InnerUserArguments 2>&1 |
		ForEach-Object { $_.ToString() }
	[pscustomobject]@{
		ExitCode = $LASTEXITCODE
		Output = ($lines -join [Environment]::NewLine)
	}
}

$completedJob = Wait-Job -Job $job -Timeout $TimeoutSec
if ($null -eq $completedJob) {
	Stop-Job -Job $job -ErrorAction SilentlyContinue
	Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
	throw "Balance simulation exceeded the $TimeoutSec second wall-clock timeout."
}
$payload = Receive-Job -Job $job
Remove-Job -Job $job -Force -ErrorAction SilentlyContinue

$rawOutput = [string]$payload.Output
Set-Content -LiteralPath $logPath -Value $rawOutput -Encoding UTF8
$strictIssues = @(Get-StrictOutputIssues -Output $rawOutput)
if ($strictIssues.Count -gt 0) {
	throw "Godot emitted strict-output errors. See '$logPath': $($strictIssues -join '; ')"
}
if (-not (Test-Path -LiteralPath $tempResult)) {
	throw "Godot did not write a result record. Exit code $($payload.ExitCode). See '$logPath'."
}

$records = @(Get-Content -LiteralPath $tempResult | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($records.Count -ne 1) {
	throw "Expected exactly one result record, found $($records.Count). See '$tempResult'."
}
try {
	$parsed = $records[0] | ConvertFrom-Json -ErrorAction Stop
} catch {
	throw "Runner output was not valid JSON: $($_.Exception.Message)"
}
if ($parsed.schema -ne "battle_bog.balance_sim.v1") {
	throw "Unexpected result schema '$($parsed.schema)'."
}
if ($parsed.run_id -ne $safeRunId) {
	throw "Result run id '$($parsed.run_id)' did not match '$safeRunId'."
}

$acceptedExit = if ($ValidateOnly) { 0 } else { 0 }
if ([int]$payload.ExitCode -ne $acceptedExit) {
	throw "Balance simulation failed with exit code $($payload.ExitCode) and status '$($parsed.status)'. See '$logPath'."
}
if ($ValidateOnly -and $parsed.status -ne "validation_ok") {
	throw "Validation run returned unexpected status '$($parsed.status)'."
}
if (-not $ValidateOnly -and $parsed.status -notin @("completed", "timeout")) {
	throw "Simulation returned unexpected status '$($parsed.status)'."
}

if ($Append) {
	Add-Content -LiteralPath $OutputPath -Value $records[0] -Encoding UTF8
} else {
	Set-Content -LiteralPath $OutputPath -Value $records[0] -Encoding UTF8
}
Remove-Item -LiteralPath $tempResult -Force

$mode = if ($ValidateOnly) { "validation" } else { "simulation" }
Write-Host "Battle Bog balance $mode PASS"
Write-Host "Result: $OutputPath"
Write-Host "Log:    $logPath"
Write-Output $records[0]
