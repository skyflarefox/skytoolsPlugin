$ErrorActionPreference = 'Stop'

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', "`"$PSCommandPath`""
    )
    exit
}

$sourceRoot = Split-Path -Parent $PSScriptRoot
$targetRoot = 'C:\Program Files (x86)\Steam\millennium\plugins\SkyTools.Plugin'
$targetData = Join-Path $targetRoot 'data'
if (-not (Test-Path -LiteralPath $targetData)) {
    New-Item -ItemType Directory -Path $targetData -Force | Out-Null
}

$copies = @(
    @{ Source = 'plugin.json'; Target = 'plugin.json' },
    @{ Source = 'backend\main.lua'; Target = 'backend\main.lua' },
    @{ Source = 'backend\skytools_installer.js'; Target = 'backend\skytools_installer.js' },
    @{ Source = 'public\skytools.js'; Target = 'public\skytools.js' },
    @{ Source = 'public\skytools.css'; Target = 'public\skytools.css' },
    @{ Source = 'public\skytools_logo.ico'; Target = 'public\skytools_logo.ico' },
    @{ Source = 'public\skytools_logo.png'; Target = 'public\skytools_logo.png' },
    @{ Source = 'public\fontawesome\webfonts\fa-solid-900.woff2'; Target = 'public\fontawesome\webfonts\fa-solid-900.woff2' },
    @{ Source = 'public\skytools_logo.ico'; Target = 'webkit\SkyTools\skytools_logo.ico' },
    @{ Source = 'public\skytools_logo.png'; Target = 'webkit\SkyTools\skytools_logo.png' },
    @{ Source = 'public\skytools.js'; Target = 'webkit\SkyTools\skytools.js' },
    @{ Source = 'public\skytools.css'; Target = 'webkit\SkyTools\skytools.css' },
    @{ Source = 'public\fontawesome\webfonts\fa-solid-900.woff2'; Target = 'webkit\SkyTools\fontawesome\webfonts\fa-solid-900.woff2' }
)

foreach ($item in $copies) {
    $src = Join-Path $sourceRoot $item.Source
    $dst = Join-Path $targetRoot $item.Target
    $dstDir = Split-Path -Parent $dst
    if (-not (Test-Path -LiteralPath $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $src -Destination $dst -Force

    $srcHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $src).Hash
    $dstHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $dst).Hash
    if ($srcHash -ne $dstHash) {
        throw "Falha ao sincronizar $($item.Target): o arquivo ativo ficou diferente da fonte."
    }

    Write-Host "OK $($item.Target)"
}

$oldCleanup = Join-Path $targetRoot 'data\launchers\cleanup-jobs.vbs'
if (Test-Path -LiteralPath $oldCleanup) {
    Remove-Item -LiteralPath $oldCleanup -Force
}

$oldHiddenFiles = @(
    (Join-Path $targetRoot 'data\launchers\run-hidden.vbs'),
    (Join-Path $targetRoot 'data\launchers\run-hidden-command.txt'),
    (Join-Path $targetRoot 'data\skytools-run-hidden.vbs'),
    (Join-Path $targetRoot 'data\skytools-run-hidden-command.txt'),
    (Join-Path $targetRoot 'data\skytools-run-minimized.vbs'),
    (Join-Path $targetRoot 'data\skytools-run-minimized-command.txt')
)
foreach ($file in $oldHiddenFiles) {
    if (Test-Path -LiteralPath $file) {
        Remove-Item -LiteralPath $file -Force
    }
}

$oldPluginWebkitAssets = @(
    (Join-Path $targetRoot 'webkit\skytools.js'),
    (Join-Path $targetRoot 'webkit\skytools.css'),
    (Join-Path $targetRoot 'webkit\skytools_logo.ico'),
    (Join-Path $targetRoot 'webkit\skytools_logo.png'),
    (Join-Path $targetRoot 'webkit\fontawesome\webfonts\fa-solid-900.woff2')
)
foreach ($file in $oldPluginWebkitAssets) {
    if (Test-Path -LiteralPath $file) {
        Remove-Item -LiteralPath $file -Force
        Write-Host "Removido asset antigo $file"
    }
}

$steamUiRoot = 'C:\Program Files (x86)\Steam\steamui'
$oldSteamUiAssets = @(
    (Join-Path $steamUiRoot 'skytools.js'),
    (Join-Path $steamUiRoot 'skytools.css'),
    (Join-Path $steamUiRoot 'webkit\skytools.js'),
    (Join-Path $steamUiRoot 'webkit\skytools.css'),
    (Join-Path $steamUiRoot 'webkit\skytools_logo.ico'),
    (Join-Path $steamUiRoot 'webkit\skytools_logo.png'),
    (Join-Path $steamUiRoot 'skytools_logo.ico'),
    (Join-Path $steamUiRoot 'skytools_logo.png')
)
foreach ($file in $oldSteamUiAssets) {
    if (Test-Path -LiteralPath $file) {
        Remove-Item -LiteralPath $file -Force
        Write-Host "Removido asset antigo $file"
    }
}

$steamUiSkyToolsRoot = Join-Path $steamUiRoot 'webkit\SkyTools'
$steamUiCopies = @(
    @{ Source = 'public\skytools.js'; Target = (Join-Path $steamUiSkyToolsRoot 'skytools.js') },
    @{ Source = 'public\skytools.css'; Target = (Join-Path $steamUiSkyToolsRoot 'skytools.css') },
    @{ Source = 'public\skytools_logo.ico'; Target = (Join-Path $steamUiSkyToolsRoot 'skytools_logo.ico') },
    @{ Source = 'public\skytools_logo.png'; Target = (Join-Path $steamUiSkyToolsRoot 'skytools_logo.png') },
    @{ Source = 'public\fontawesome\webfonts\fa-solid-900.woff2'; Target = (Join-Path $steamUiSkyToolsRoot 'fontawesome\webfonts\fa-solid-900.woff2') }
)

foreach ($item in $steamUiCopies) {
    $src = Join-Path $sourceRoot $item.Source
    $dst = $item.Target
    $dstDir = Split-Path -Parent $dst
    if (-not (Test-Path -LiteralPath $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $src -Destination $dst -Force

    $srcHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $src).Hash
    $dstHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $dst).Hash
    if ($srcHash -ne $dstHash) {
        throw "Falha ao sincronizar asset Steam UI $dst"
    }

    Write-Host "OK Steam UI $dst"
}

$steamRoot = 'C:\Program Files (x86)\Steam'
$installedIndex = Join-Path $targetData 'skytools-job-installed.json'
$scriptDirs = @(
    (Join-Path $steamRoot 'config\stplug-in'),
    (Join-Path $steamRoot 'config\lua')
) | Select-Object -Unique

$installedMap = @{}
foreach ($dir in $scriptDirs) {
    if (-not (Test-Path -LiteralPath $dir)) {
        continue
    }

    Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^(\d+)\.lua(\.disabled)?$' } |
        ForEach-Object {
            $appid = [int]$Matches[1]
            $disabled = [bool]$Matches[2]
            $text = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
            $seen = @{}
            if ($text) {
                [regex]::Matches($text, 'addappid\s*\(\s*(\d+)') | ForEach-Object {
                    $id = $_.Groups[1].Value
                    if ($id -ne [string]$appid) {
                        $seen[$id] = $true
                    }
                }
            }
            if (-not $installedMap.ContainsKey([string]$appid) -or -not $disabled) {
                $installedMap[[string]$appid] = [ordered]@{
                    appId = $appid
                    fileName = $_.Name
                    fullPath = $_.FullName
                    scriptDirectory = $dir
                    dlcCount = $seen.Count
                    isDisabled = $disabled
                }
            }
        }
}

$installedData = $installedMap.GetEnumerator() |
    Sort-Object { [int]$_.Key } |
    ForEach-Object { $_.Value }

[ordered]@{
    success = $true
    data = @($installedData)
    error = ''
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $installedIndex -Encoding UTF8

Write-Host "OK indice biblioteca $($installedData.Count) jogo(s)"

Write-Host ''
Write-Host 'SkyTools atualizado e verificado na pasta ativa da Steam.'
Write-Host 'Reinicie a Steam para o Millennium recarregar o plugin.'
