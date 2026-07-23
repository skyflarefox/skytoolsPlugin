$ErrorActionPreference = 'Stop'
$Repo = 'skyflarefox/skytoolsPlugin'
$CurrentVersion = '1.0.4'
$TargetPluginRoot = 'C:\Program Files (x86)\Steam\millennium\plugins\SkyTools.Plugin'
$PluginsRoot = Split-Path -Parent $TargetPluginRoot
$SteamUiCacheRoot = 'C:\Program Files (x86)\Steam\steamui\webkit\SkyTools'
$WorkRoot = Join-Path ([IO.Path]::GetTempPath()) ('skytools-auto-update-' + [Guid]::NewGuid().ToString('N'))
$StatusPath = Join-Path 'c:/program files (x86)/steam\millennium/plugins\skytools\data' 'skytools-auto-update-status.json'
$LogPath = Join-Path 'c:/program files (x86)/steam\millennium/plugins\skytools\data' 'skytools-auto-update.log'

function Write-SkyToolsUpdateLog([string]$Message) {
  try {
    $parent = Split-Path -Parent $LogPath
    if ($parent -and !(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Add-Content -LiteralPath $LogPath -Value ("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $Message) -Encoding UTF8
  } catch {}
}

function Write-SkyToolsUpdateStatus([string]$Status, [string]$Message, [string]$RemoteVersion) {
  try {
    $parent = Split-Path -Parent $StatusPath
    if ($parent -and !(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [ordered]@{
      success = $Status -ne 'error'
      status = $Status
      message = $Message
      currentVersion = $CurrentVersion
      remoteVersion = $RemoteVersion
      updatedAt = [DateTimeOffset]::Now.ToUnixTimeSeconds()
    } | ConvertTo-Json -Compress | Set-Content -LiteralPath $StatusPath -Encoding UTF8
  } catch {}
}

function Get-SkyToolsVersionParts([string]$Value) {
  $clean = ([string]$Value).Trim()
  if ($clean.StartsWith('v', [StringComparison]::OrdinalIgnoreCase)) { $clean = $clean.Substring(1) }
  $match = [regex]::Match($clean, '\d+(?:\.\d+){0,3}')
  if (!$match.Success) { return @() }
  $parts = @()
  foreach ($part in $match.Value.Split('.')) { $parts += [int]$part }
  while ($parts.Count -lt 4) { $parts += 0 }
  return $parts
}

function Compare-SkyToolsVersion([string]$Left, [string]$Right) {
  $leftParts = Get-SkyToolsVersionParts $Left
  $rightParts = Get-SkyToolsVersionParts $Right
  if ($leftParts.Count -eq 0 -or $rightParts.Count -eq 0) {
    return [string]::Compare($Left, $Right, $true)
  }
  for ($i = 0; $i -lt 4; $i += 1) {
    if ($leftParts[$i] -gt $rightParts[$i]) { return 1 }
    if ($leftParts[$i] -lt $rightParts[$i]) { return -1 }
  }
  return 0
}

function Remove-SkyToolsTree([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path -LiteralPath $Path)) { return }
  for ($attempt = 1; $attempt -le 5; $attempt += 1) {
    try {
      Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
      return
    } catch {
      if ($attempt -eq 5) { throw }
      Start-Sleep -Milliseconds (350 * $attempt)
    }
  }
}

function Get-SkyToolsCandidateFolder([string]$ExtractRoot) {
  $folders = @(Get-ChildItem -LiteralPath $ExtractRoot -Directory -Recurse -ErrorAction SilentlyContinue)
  $preferred = @($folders | Where-Object { $_.Name -eq 'SkyTools.Plugin' } | Select-Object -First 1)
  if ($preferred.Count -gt 0) { return $preferred[0] }
  $fallback = @($folders | Where-Object { $_.Name -eq 'SkyTools' } | Select-Object -First 1)
  if ($fallback.Count -gt 0) { return $fallback[0] }
  $manifestFolder = @($folders | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'plugin.json') } | Select-Object -First 1)
  if ($manifestFolder.Count -gt 0) { return $manifestFolder[0] }
  return $null
}

try {
  Write-SkyToolsUpdateStatus 'checking' 'Verificando releases do GitHub.' ''
  Write-SkyToolsUpdateLog ('Verificando update. Versao atual=' + $CurrentVersion)

  $headers = @{
    'User-Agent' = 'SkyTools.Plugin'
    'Accept' = 'application/vnd.github+json'
  }
  $release = Invoke-RestMethod -Uri ('https://api.github.com/repos/' + $Repo + '/releases/latest') -Headers $headers -UseBasicParsing
  $remoteVersion = [string]$release.tag_name
  if ([string]::IsNullOrWhiteSpace($remoteVersion)) { throw 'Release sem tag.' }

  if ((Compare-SkyToolsVersion $remoteVersion $CurrentVersion) -le 0) {
    Write-SkyToolsUpdateStatus 'current' 'SkyTools ja esta atualizado.' $remoteVersion
    Write-SkyToolsUpdateLog ('Sem update. Remoto=' + $remoteVersion)
    return
  }

  Write-SkyToolsUpdateStatus 'downloading' ('Baixando SkyTools ' + $remoteVersion + '.') $remoteVersion
  New-Item -ItemType Directory -Path $WorkRoot -Force | Out-Null
  $zipPath = Join-Path $WorkRoot 'skytools-update.zip'
  $extractRoot = Join-Path $WorkRoot 'extract'
  $asset = @($release.assets | Where-Object { $_.browser_download_url -and $_.name -match '\.zip$' } | Select-Object -First 1)
  $downloadUrl = if ($asset.Count -gt 0) { [string]$asset[0].browser_download_url } else { [string]$release.zipball_url }
  if ([string]::IsNullOrWhiteSpace($downloadUrl)) { throw 'Release sem ZIP para baixar.' }

  Invoke-WebRequest -Uri $downloadUrl -Headers @{ 'User-Agent' = 'SkyTools.Plugin' } -OutFile $zipPath -UseBasicParsing
  if (!(Test-Path -LiteralPath $zipPath) -or (Get-Item -LiteralPath $zipPath).Length -le 0) { throw 'Download do update veio vazio.' }

  Write-SkyToolsUpdateStatus 'extracting' 'Extraindo pacote do update.' $remoteVersion
  New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
  Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force
  $candidate = Get-SkyToolsCandidateFolder $extractRoot
  if ($null -eq $candidate) { throw 'O ZIP nao contem pasta SkyTools.Plugin nem SkyTools.' }

  Write-SkyToolsUpdateStatus 'installing' ('Instalando SkyTools ' + $remoteVersion + '.') $remoteVersion
  if (!(Test-Path -LiteralPath $PluginsRoot)) { New-Item -ItemType Directory -Path $PluginsRoot -Force | Out-Null }
  Remove-SkyToolsTree $TargetPluginRoot
  Remove-SkyToolsTree $SteamUiCacheRoot

  $targetByCandidateName = Join-Path $PluginsRoot $candidate.Name
  Remove-SkyToolsTree $targetByCandidateName
  Copy-Item -LiteralPath $candidate.FullName -Destination $PluginsRoot -Recurse -Force

  $installedRoot = Join-Path $PluginsRoot $candidate.Name
  $installedManifest = Join-Path $installedRoot 'plugin.json'
  if (!(Test-Path -LiteralPath $installedManifest)) { throw 'Update copiado, mas plugin.json nao foi encontrado na pasta instalada.' }

  Write-SkyToolsUpdateStatus 'updated' ('SkyTools atualizado para ' + $remoteVersion + '. Reinicie a Steam para carregar a nova versao.') $remoteVersion
  Write-SkyToolsUpdateLog ('Update instalado em ' + $installedRoot)

  if ($candidate.Name -eq 'SkyTools.Plugin') {
    $newData = Join-Path $installedRoot 'data'
    New-Item -ItemType Directory -Path $newData -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $newData 'skytools-hidden-console.stop') -Value 'updated' -Encoding ASCII
  }
} catch {
  $message = $_.Exception.Message
  if (!$message) { $message = [string]$_ }
  Write-SkyToolsUpdateStatus 'error' $message ''
  Write-SkyToolsUpdateLog ('ERRO ' + $message)
} finally {
  if ($WorkRoot -and (Test-Path -LiteralPath $WorkRoot)) {
    Remove-Item -LiteralPath $WorkRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
