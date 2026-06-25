param(
    [string]$Url,
    [Parameter(Mandatory = $true)][string]$DestPath,
    [Parameter(Mandatory = $true)][string]$ExtractDir,
    [string]$StateFile,
    [string]$UserAgent = "discord(dot)gg/luatools"
)

$ErrorActionPreference = 'Stop'

function Write-State {
    param(
        [Parameter(Mandatory = $true)][Hashtable]$StateData
    )
    if ([string]::IsNullOrWhiteSpace($StateFile)) { return }
    
    $json = $StateData | ConvertTo-Json -Compress
    Set-Content -Path $StateFile -Value $json
}

try {

    if (-not [string]::IsNullOrWhiteSpace($Url)) {
        Write-Host "Downloading $Url to $DestPath..."
        
        Add-Type -AssemblyName System.Net.Http

        $client = New-Object System.Net.Http.HttpClient
        
        [void]$client.DefaultRequestHeaders.TryAddWithoutValidation("User-Agent", $UserAgent)

        $responseTask = $client.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
        $response = $responseTask.GetAwaiter().GetResult()
        
        $totalBytes = 0
        if ($response.Content.Headers.ContentLength) {
            $totalBytes = $response.Content.Headers.ContentLength
        }

        $readStream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $fileStream = New-Object System.IO.FileStream($DestPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        
        $buffer = New-Object byte[] 8192 
        $bytesReadTotal = 0
        

        Write-State @{ status = "downloading"; bytesRead = 0; totalBytes = $totalBytes }

        while ($true) {
            $bytesRead = $readStream.Read($buffer, 0, $buffer.Length)
            if ($bytesRead -le 0) { break }
            
            $fileStream.Write($buffer, 0, $bytesRead)
            $bytesReadTotal += $bytesRead
            
            Write-State @{ status = "downloading"; bytesRead = $bytesReadTotal; totalBytes = $totalBytes }
        }

        $fileStream.Close()
        $readStream.Close()
        $client.Dispose()
        
        Write-Host "Download complete!"
    }
    
    if (-not [string]::IsNullOrWhiteSpace($ExtractDir)) {
        Write-State @{ status = "extracting"; bytesRead = $bytesReadTotal; totalBytes = $totalBytes }
        Write-Host "Extracting $DestPath to $ExtractDir..."
        
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($DestPath)
        
        foreach ($entry in $zip.Entries) {
            $target = [System.IO.Path]::Combine($ExtractDir, $entry.FullName)
            $dir = [System.IO.Path]::GetDirectoryName($target)
            
            if (-not (Test-Path $dir)) { 
                New-Item -ItemType Directory -Force -Path $dir | Out-Null 
            }
            
            if ($entry.Name -ne '') { 
                Write-Host "Extracting $($entry.FullName)..."
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true) 
            }
        }
        $zip.Dispose()
        
        Write-State @{ status = "extracted" }
        Write-Host "Extraction complete!"
        Start-Sleep -Seconds 2
    }
    else {
        Write-State @{ status = "done" }
    }
}
catch {
    Write-Host "ERROR ENCOUNTERED:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    if (-not [string]::IsNullOrWhiteSpace($ExtractDir) -and -not (Test-Path $ExtractDir)) {
        New-Item -ItemType Directory -Force -Path $ExtractDir | Out-Null
    }
    
    $errLog = [System.IO.Path]::Combine($ExtractDir, "update_error.log")
    Set-Content -Path $errLog -Value $_.Exception.ToString()
    
    Write-State @{ status = "failed"; error = $_.Exception.Message }
    
    try { Read-Host "Press Enter to exit" } catch {}
    exit 1
}