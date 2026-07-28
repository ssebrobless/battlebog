[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string]$Executable,

	[Parameter(Mandatory = $true)]
	[AllowEmptyCollection()]
	[string[]]$Arguments,

	[Parameter(Mandatory = $true)]
	[ValidateRange(1, 2147483)]
	[int]$TimeoutSec,

	[Parameter(Mandatory = $true)]
	[AllowEmptyString()]
	[string]$ExpectedMarker,

	[Parameter(Mandatory = $true)]
	[string]$CommandId,

	[Parameter(Mandatory = $true)]
	[string]$ArtifactRoot
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function ConvertTo-NativeArgument {
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

function Invoke-GitCapture {
	param(
		[string]$WorkingDirectory,
		[string[]]$GitArguments
	)

	$commandText = (@("git.exe", "-C", $WorkingDirectory) + $GitArguments |
		ForEach-Object { ConvertTo-NativeArgument $_ }) -join " "
	$captured = @(& $env:ComSpec /d /s /c $commandText 2>&1)
	$exitCode = $LASTEXITCODE
	if ($exitCode -ne 0) {
		throw "Git failed while computing source fingerprint: $($captured -join [Environment]::NewLine)"
	}
	return ($captured -join [Environment]::NewLine)
}

function Get-SourceTreeFingerprint {
	param([string]$StartDirectory)

	$rootText = Invoke-GitCapture -WorkingDirectory $StartDirectory -GitArguments @(
		"rev-parse", "--show-toplevel"
	)
	$repoRoot = $rootText.Trim()
	if ([string]::IsNullOrWhiteSpace($repoRoot)) {
		throw "Unable to resolve repository root for source fingerprint."
	}

	$pathText = Invoke-GitCapture -WorkingDirectory $repoRoot -GitArguments @(
		"ls-files", "-co", "--exclude-standard", "-z"
	)
	$paths = @($pathText.Split([char]0) | Where-Object {
		-not [string]::IsNullOrEmpty($_)
	} | ForEach-Object {
		$normalized = $_.Replace('\', '/')
		if ($normalized -notlike ".godot/*" -and
			$normalized -ne ".godot" -and
			$normalized -notlike "artifacts/*" -and
			$normalized -ne "artifacts") {
			$normalized
		}
	})
	[Array]::Sort($paths, [System.StringComparer]::Ordinal)

	$records = New-Object System.IO.MemoryStream
	try {
		foreach ($relativePath in $paths) {
			$absolutePath = Join-Path $repoRoot ($relativePath.Replace('/', '\'))
			$item = Get-Item -LiteralPath $absolutePath -Force
			if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
				throw "Source fingerprint rejects reparse point: $relativePath"
			}
			if ($item.PSIsContainer) {
				throw "Source fingerprint expected a file: $relativePath"
			}

			$fileHash = (Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256).Hash.ToLowerInvariant()
			$record = "$relativePath`0$fileHash`0$($item.Length)`n"
			$recordBytes = $Utf8NoBom.GetBytes($record)
			$records.Write($recordBytes, 0, $recordBytes.Length)
		}

		$records.Position = 0
		$sha256 = [System.Security.Cryptography.SHA256]::Create()
		try {
			$hashBytes = $sha256.ComputeHash($records)
		} finally {
			$sha256.Dispose()
		}
		return ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").ToLowerInvariant()
	} finally {
		$records.Dispose()
	}
}

function Stop-ProcessTree {
	param([int]$ProcessId)

	$taskKill = Join-Path $env:SystemRoot "System32\taskkill.exe"
	if (Test-Path -LiteralPath $taskKill) {
		$null = & $taskKill /PID $ProcessId /T /F 2>&1
	}
}

if ($CommandId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or
	$CommandId -eq "." -or $CommandId -eq "..") {
	throw "CommandId must be filename-safe."
}
if (-not (Test-Path -LiteralPath $ArtifactRoot -PathType Container)) {
	throw "ArtifactRoot must be an existing directory."
}

$artifactPath = (Resolve-Path -LiteralPath $ArtifactRoot).Path
$stdoutPath = Join-Path $artifactPath "$CommandId.stdout.log"
$stderrPath = Join-Path $artifactPath "$CommandId.stderr.log"
$resultPath = Join-Path $artifactPath "$CommandId.result.json"
$sourceFingerprint = Get-SourceTreeFingerprint -StartDirectory $PSScriptRoot
$startedUtc = [DateTime]::UtcNow
$timedOut = $false
$exitCode = -1
$stdout = ""
$stderr = ""
$startFailure = $null
$runnerPath = Join-Path $artifactPath (
	".$CommandId.runner." + [Guid]::NewGuid().ToString("N") + ".cmd"
)

$payloadCommand = (@($Executable) + $Arguments | ForEach-Object {
	ConvertTo-NativeArgument $_
}) -join " "
$quotedStdoutPath = '"' + $stdoutPath.Replace('"', '""') + '"'
$quotedStderrPath = '"' + $stderrPath.Replace('"', '""') + '"'
$runnerText = @(
	"@echo off"
	"$payloadCommand 1>$quotedStdoutPath 2>$quotedStderrPath"
	"exit /b %errorlevel%"
) -join "`r`n"
[System.IO.File]::WriteAllText($runnerPath, "$runnerText`r`n", $Utf8NoBom)

$process = $null
try {
	$startInfo = New-Object System.Diagnostics.ProcessStartInfo
	$startInfo.FileName = $env:ComSpec
	$startInfo.Arguments = "/d /s /c " + (ConvertTo-NativeArgument $runnerPath)
	$startInfo.WorkingDirectory = (Get-Location).Path
	$startInfo.UseShellExecute = $false
	$startInfo.CreateNoWindow = $true
	$process = New-Object System.Diagnostics.Process
	$process.StartInfo = $startInfo
	if (-not $process.Start()) {
		throw "Process start returned false."
	}
	if (-not $process.WaitForExit($TimeoutSec * 1000)) {
		$timedOut = $true
		Stop-ProcessTree -ProcessId $process.Id
		if (-not $process.WaitForExit(5000)) {
			$process.Kill()
			$process.WaitForExit()
		}
	}
	$process.WaitForExit()
	$process.Refresh()
	$exitCode = if ($timedOut) { 124 } else { [int]$process.ExitCode }
} catch {
	$startFailure = $_.Exception.Message
	$exitCode = -1
} finally {
	if ($null -ne $process) {
		$process.Dispose()
	}
	Remove-Item -LiteralPath $runnerPath -Force -ErrorAction SilentlyContinue
}

$endedUtc = [DateTime]::UtcNow
if (-not (Test-Path -LiteralPath $stdoutPath -PathType Leaf)) {
	[System.IO.File]::WriteAllText($stdoutPath, "", $Utf8NoBom)
}
if (-not (Test-Path -LiteralPath $stderrPath -PathType Leaf)) {
	[System.IO.File]::WriteAllText($stderrPath, "", $Utf8NoBom)
}
$stdout = [System.IO.File]::ReadAllText($stdoutPath)
$stderr = [System.IO.File]::ReadAllText($stderrPath)
if ($null -ne $startFailure) {
	$stderr = $startFailure
	[System.IO.File]::WriteAllText($stderrPath, $stderr, $Utf8NoBom)
}

$markerFound = [string]::IsNullOrEmpty($ExpectedMarker) -or
	$stdout.Contains($ExpectedMarker) -or $stderr.Contains($ExpectedMarker)
$matchedTestCount = @([regex]::Matches(
	$stdout,
	'(?m)^[^\r\n]*\.gd\s+PASS\s+'
)).Count
$strictOutputIssues = @([regex]::Matches(
	"$stdout`n$stderr",
	'(?m)^strict_output_issue:\s*(.+)$'
) | ForEach-Object { $_.Groups[1].Value })
$nonPassTestRows = @([regex]::Matches(
	$stdout,
	'(?m)^[^\r\n]*\.gd\s+(?!PASS\b)([A-Z]+)\s+'
) | ForEach-Object { $_.Value.Trim() })
$isRunAll = @($Arguments | Where-Object {
	[System.IO.Path]::GetFileName($_) -ieq "run_all.ps1"
}).Count -gt 0
$executableName = [System.IO.Path]::GetFileName($Executable)
$isDiffCheck = ($executableName -ieq "git.exe" -or $executableName -ieq "git") -and
	$Arguments.Count -ge 2 -and
	$Arguments[$Arguments.Count - 2] -eq "diff" -and
	$Arguments[$Arguments.Count - 1] -eq "--check"
$combinedOutput = "$stdout$stderr"

$failureReason = ""
if ($null -ne $startFailure) {
	$failureReason = "process_start_failed"
} elseif ($timedOut) {
	$failureReason = "timeout"
} elseif ($exitCode -ne 0) {
	$failureReason = "nonzero_exit"
} elseif (-not $markerFound) {
	$failureReason = "missing_marker"
} elseif ($strictOutputIssues.Count -gt 0) {
	$failureReason = "strict_output_issue"
} elseif ($isRunAll -and $nonPassTestRows.Count -gt 0) {
	$failureReason = "non_pass_test_row"
} elseif ($isRunAll -and $matchedTestCount -lt 1) {
	$failureReason = "zero_matched_tests"
} elseif ($isDiffCheck -and -not [string]::IsNullOrWhiteSpace($combinedOutput)) {
	$failureReason = "diff_check_output"
}
$passed = [string]::IsNullOrEmpty($failureReason)
$exactCommand = (@($Executable) + $Arguments | ForEach-Object {
	ConvertTo-NativeArgument $_
}) -join " "

$result = [ordered]@{
	schema_version = 1
	command_id = $CommandId
	exact_command = $exactCommand
	executable = $Executable
	arguments = @($Arguments)
	timeout_sec = $TimeoutSec
	expected_marker = $ExpectedMarker
	source_tree_fingerprint = $sourceFingerprint
	started_utc = $startedUtc.ToString("o")
	ended_utc = $endedUtc.ToString("o")
	duration_ms = [int64][Math]::Round(($endedUtc - $startedUtc).TotalMilliseconds)
	exit_code = $exitCode
	timed_out = $timedOut
	completion_marker_found = $markerFound
	matched_test_count = $matchedTestCount
	strict_output_issues = @($strictOutputIssues)
	non_pass_test_rows = @($nonPassTestRows)
	stdout_log_path = $stdoutPath
	stderr_log_path = $stderrPath
	passed = $passed
	failure_reason = $failureReason
}
$resultJson = $result | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($resultPath, "$resultJson`n", $Utf8NoBom)

if (-not $passed) {
	throw "Checked command '$CommandId' failed: $failureReason."
}

Write-Output "BB_CHECKED_COMMAND_OK id=$CommandId"
