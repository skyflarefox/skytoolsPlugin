param([string]$Root)
$ErrorActionPreference = 'Continue'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
$Queue = Join-Path $Root 'skytools-hidden-console-queue'
$Pending = Join-Path $Queue 'pending'
$Running = Join-Path $Queue 'running'
$Done = Join-Path $Queue 'done'
$StatePath = Join-Path $Root 'skytools-hidden-console-state.json'
$StopPath = Join-Path $Root 'skytools-hidden-console.stop'
$LogPath = Join-Path $Root 'skytools-hidden-console.log'

function Ensure-SkyToolsDirectory([string]$Path) {
  if (!(Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Get-SkyToolsUnixTime {
  return [DateTimeOffset]::Now.ToUnixTimeSeconds()
}

function Write-SkyToolsLog([string]$Message) {
  try {
    Add-Content -LiteralPath $LogPath -Value ("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $Message) -Encoding UTF8
  } catch {}
}

function Write-SkyToolsState([string]$Status, [string]$JobId) {
  try {
    $state = [ordered]@{
      pid = $PID
      status = $Status
      jobId = $JobId
      updatedAt = Get-SkyToolsUnixTime
    } | ConvertTo-Json -Compress
    Set-Content -LiteralPath $StatePath -Value $state -Encoding UTF8
  } catch {}
}

function Complete-SkyToolsJob($Job, [bool]$Success, [int]$ExitCode, [string]$ErrorMessage) {
  try {
    $donePath = Join-Path $Done ([string]$Job.id + '.json')
    $result = [ordered]@{
      id = [string]$Job.id
      kind = [string]$Job.kind
      success = $Success
      exitCode = $ExitCode
      error = $ErrorMessage
      finishedAt = Get-SkyToolsUnixTime
    } | ConvertTo-Json -Compress
    Set-Content -LiteralPath $donePath -Value $result -Encoding UTF8
  } catch {}
}

function Invoke-SkyToolsJob($Job) {
  $exitCode = 0
  switch ([string]$Job.kind) {
    'process' {
      $argv = @()
      if ($null -ne $Job.arguments) {
        foreach ($arg in @($Job.arguments)) { $argv += [string]$arg }
      }
      & ([string]$Job.filePath) @argv
      if ($null -ne $LASTEXITCODE) { $exitCode = [int]$LASTEXITCODE }
    }
    'powershell-file' {
      & ([string]$Job.scriptPath)
      if ($null -ne $LASTEXITCODE) { $exitCode = [int]$LASTEXITCODE }
    }
    'elevated-powershell-file' {
      $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', [string]$Job.scriptPath)
      Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Verb RunAs -WindowStyle Hidden
    }
    default {
      throw ('Tipo de job desconhecido: ' + [string]$Job.kind)
    }
  }
  return $exitCode
}

Ensure-SkyToolsDirectory $Root
Ensure-SkyToolsDirectory $Queue
Ensure-SkyToolsDirectory $Pending
Ensure-SkyToolsDirectory $Running
Ensure-SkyToolsDirectory $Done
Remove-Item -LiteralPath $StopPath -Force -ErrorAction SilentlyContinue
Write-SkyToolsLog 'Worker oculto iniciado.'

while (!(Test-Path -LiteralPath $StopPath)) {
  Write-SkyToolsState 'idle' ''
  $jobs = @(Get-ChildItem -LiteralPath $Pending -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc, Name)
  foreach ($file in $jobs) {
    if (Test-Path -LiteralPath $StopPath) { break }
    $runningPath = Join-Path $Running $file.Name
    try {
      Move-Item -LiteralPath $file.FullName -Destination $runningPath -Force
    } catch {
      continue
    }

    $job = $null
    $jobId = [IO.Path]::GetFileNameWithoutExtension($runningPath)
    try {
      $job = Get-Content -LiteralPath $runningPath -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($job.id) { $jobId = [string]$job.id }
      Write-SkyToolsState 'busy' $jobId
      Write-SkyToolsLog ('Iniciando job ' + $jobId + ' (' + [string]$job.kind + ').')
      $code = Invoke-SkyToolsJob $job
      Complete-SkyToolsJob $job $true $code ''
      Write-SkyToolsLog ('Job ' + $jobId + ' finalizado com exitCode=' + $code + '.')
    } catch {
      $message = $_.Exception.Message
      if (!$message) { $message = [string]$_ }
      Write-SkyToolsLog ('Falha no job ' + $jobId + ': ' + $message)
      if ($null -ne $job) {
        Complete-SkyToolsJob $job $false 1 $message
      }
    } finally {
      Remove-Item -LiteralPath $runningPath -Force -ErrorAction SilentlyContinue
      Write-SkyToolsState 'idle' ''
    }
  }
  Start-Sleep -Milliseconds 250
}

Write-SkyToolsState 'stopped' ''
Write-SkyToolsLog 'Worker oculto encerrado.'
Remove-Item -LiteralPath $StopPath -Force -ErrorAction SilentlyContinue
