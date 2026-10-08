[CmdletBinding()]
param(
    [switch]$HeadersOnly,
    [ValidateSet(89, 90, 100, 120)][int]$ComputeCapability = 89,
    [string]$SdkDirectory = (Join-Path $PSScriptRoot '../.dart_tool/playback_inference/base/sdk/tensorrt'),
    [string]$RuntimeDirectory = '',
    [string]$BaseRuntimeDirectory = (Join-Path $PSScriptRoot '../.dart_tool/playback_inference/base/runtime'),
    [string]$CacheDirectory = (Join-Path $PSScriptRoot '../.dart_tool/playback_inference/downloads')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
Import-Module (Join-Path $PSScriptRoot 'playback_inference_assets.psm1') -Force
$sourceRoot = Join-Path $PSScriptRoot '../windows/playback/inference'
$sdkLock = Get-Content -LiteralPath (Join-Path $sourceRoot 'trt-sdk.lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$componentLock = Get-Content -LiteralPath (Join-Path $sourceRoot 'trt-components.lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($sdkLock.schemaVersion -ne 1 -or $componentLock.schemaVersion -ne 1 -or
    $componentLock.bridgeAbi -ne 8 -or $ComputeCapability -notin $componentLock.supportedSm) {
    throw 'Unsupported TensorRT dependency lock or compute capability'
}
if ([string]::IsNullOrWhiteSpace($RuntimeDirectory)) {
    $RuntimeDirectory = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) "BangumiToday/playback-tensorrt/$($componentLock.trtVersion)/sm$ComputeCapability"
}
$runtimeFiles = @($componentLock.files | Where-Object { $_.group -in @('common', 'crt', "sm$ComputeCapability") })
$runtimeArchives = @($componentLock.archives | Where-Object { $_.group -in @('common', "sm$ComputeCapability") })
$downloadRoot = [IO.Path]::GetFullPath($CacheDirectory)

function Save-TrtAsset([object]$Asset, [string]$Extension) {
    $path = Join-Path $downloadRoot ($Asset.sha256 + $Extension)
    if (Test-Path -LiteralPath $path) {
        Assert-InferenceFile -Path $path -Bytes $Asset.bytes -Sha256 $Asset.sha256
        return $path
    }
    $uri = [Uri]$Asset.url
    if ($uri.Scheme -ne 'https' -or $uri.Host -notin @('raw.githubusercontent.com', 'developer.download.nvidia.com', 'github.com')) {
        throw "Untrusted TensorRT preparation source: $uri"
    }
    New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null
    # Only developer preparation consumes the fixed upstream archives. The
    # application must use project-owned ZIPs and its separate P3 installer.
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $client = [Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromMinutes(15)
    $partial = $path + '.part'
    try {
        for ($redirect = 0; $redirect -le 5; $redirect++) {
            $response = $client.GetAsync($uri, [Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
            if ([int]$response.StatusCode -in @(301, 302, 303, 307, 308)) {
                $next = [Uri]::new($uri, $response.Headers.Location)
                $response.Dispose()
                if ($next.Scheme -ne 'https' -or $next.Host -notin @('github.com', 'release-assets.githubusercontent.com', 'developer.download.nvidia.com')) {
                    throw "Untrusted TensorRT redirect: $next"
                }
                $uri = $next
                continue
            }
            try {
                $response.EnsureSuccessStatusCode() | Out-Null
                $inputStream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                $outputStream = [IO.File]::Open($partial, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
                try {
                    $buffer = New-Object byte[] 65536
                    $written = [long]0
                    while (($count = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                        $written += $count
                        if ($written -gt $Asset.bytes) { throw 'TensorRT download exceeds locked length' }
                        $outputStream.Write($buffer, 0, $count)
                    }
                } finally { $outputStream.Dispose(); $inputStream.Dispose() }
            } finally { $response.Dispose() }
            Assert-InferenceFile -Path $partial -Bytes $Asset.bytes -Sha256 $Asset.sha256
            Move-Item -LiteralPath $partial -Destination $path
            return $path
        }
        throw 'Too many TensorRT source redirects'
    } finally { $client.Dispose(); $handler.Dispose() }
}

function Remove-TrtStage([string]$Stage, [string]$Target) {
    $absolute = [IO.Path]::GetFullPath($Stage)
    if (-not $absolute.StartsWith($Target + '.', [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetDirectoryName($absolute) -ne [IO.Path]::GetDirectoryName($Target)) {
        throw 'TensorRT staging cleanup escaped its checked sibling directory'
    }
    if (Test-Path -LiteralPath $absolute) { Remove-Item -LiteralPath $absolute -Recurse -Force }
}

function Assert-TrtHeaders([string]$Root) {
    foreach ($file in $sdkLock.headers) {
        Assert-InferenceFile -Path (Get-InferenceTarget -Root (Join-Path $Root 'include') -RelativePath $file.name) -Bytes $file.bytes -Sha256 $file.sha256
    }
    foreach ($file in $sdkLock.cudaHeaders) {
        Assert-InferenceFile -Path (Get-InferenceTarget -Root (Join-Path $Root 'cuda/include') -RelativePath $file.name) -Bytes $file.bytes -Sha256 $file.sha256
    }
}

if ($HeadersOnly) {
    $target = [IO.Path]::GetFullPath($SdkDirectory).TrimEnd('\', '/')
    if (Test-Path -LiteralPath $target) {
        Assert-TrtHeaders $target
        Write-Output "Reusing verified TensorRT/CUDA developer headers: $target"
        return
    }
    $stage = $target + '.' + [Guid]::NewGuid().ToString('N') + '.staging'
    New-Item -ItemType Directory -Path (Join-Path $stage 'include') -Force | Out-Null
    try {
        foreach ($file in $sdkLock.headers) {
            $asset = @{ url = $sdkLock.trtSource + $file.name; bytes = $file.bytes; sha256 = $file.sha256 }
            $download = Save-TrtAsset $asset '.header'
            Copy-Item -LiteralPath $download -Destination (Join-Path $stage ('include/' + $file.name))
        }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        foreach ($package in $sdkLock.cudaPackages) {
            $download = Save-TrtAsset $package '.zip'
            $archive = [IO.Compression.ZipFile]::OpenRead($download)
            try {
                foreach ($file in $sdkLock.cudaHeaders | Where-Object { $_.package -eq $package.name }) {
                    $entry = $archive.GetEntry($package.prefix + $file.name)
                    if (-not $entry -or $entry.Length -ne $file.bytes) { throw "Missing locked CUDA header: $($file.name)" }
                    $destination = Get-InferenceTarget -Root (Join-Path $stage 'cuda/include') -RelativePath $file.name
                    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($destination)) -Force | Out-Null
                    $inputStream = $entry.Open()
                    $outputStream = [IO.File]::Open($destination, [IO.FileMode]::CreateNew)
                    try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose(); $inputStream.Dispose() }
                }
            } finally { $archive.Dispose() }
        }
        Assert-TrtHeaders $stage
        Move-Item -LiteralPath $stage -Destination $target
        Write-Output "Prepared TensorRT/CUDA headers without installing a Toolkit: $target"
    } finally { Remove-TrtStage $stage $target }
    return
}

function Assert-TrtRuntime([string]$Root) {
    foreach ($file in $runtimeFiles) {
        $path = Get-InferenceTarget -Root $Root -RelativePath $file.name
        Assert-InferenceFile -Path $path -Bytes $file.bytes -Sha256 $file.sha256
        if ($file.name -match '\.(dll|exe)$') {
            $imports = Get-InferencePeImports $path
            foreach ($import in $imports) {
                if ($import -match '^(api-ms-|ext-ms-)') { continue }
                if ($import -in @($runtimeFiles.name)) { continue }
                if (-not (Test-Path -LiteralPath (Join-Path $env:SystemRoot ('System32/' + $import)))) {
                    throw "Unresolved TensorRT dependency: $($file.name) -> $import"
                }
            }
        }
    }
}

function Write-TrtInstalledRecord([string]$Root) {
    $text = [IO.File]::ReadAllText((Join-Path $sourceRoot 'trt-components.lock.json')).Replace("`r`n", "`n")
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        $manifestSha256 = ([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-', '').ToLowerInvariant()
    } finally { $hash.Dispose() }
    $record = @{ schemaVersion = 1; trtVersion = $componentLock.trtVersion; sm = $ComputeCapability; manifestSha256 = $manifestSha256 } | ConvertTo-Json -Compress
    [IO.File]::WriteAllText((Join-Path $Root 'installed.json'), $record, [Text.UTF8Encoding]::new($false))
}

$target = [IO.Path]::GetFullPath($RuntimeDirectory).TrimEnd('\', '/')
if (Test-Path -LiteralPath $target) {
    Assert-TrtRuntime $target
    Write-TrtInstalledRecord $target
    Write-Output "Reusing verified optional TensorRT sm$ComputeCapability resources: $target"
    return
}
$stage = $target + '.' + [Guid]::NewGuid().ToString('N') + '.staging'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
try {
    foreach ($package in $runtimeArchives) {
        $download = Save-TrtAsset $package '.7z'
        # tar.exe is the OS archive reader, never an executable from a download.
        $tar = Join-Path $env:SystemRoot 'System32/tar.exe'
        $names = @(& $tar -tf $download)
        if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect locked TensorRT archive' }
        $seen = @{}
        foreach ($name in $names) {
            $relative = $name.Replace('\', '/')
            if ($relative -notmatch '^animejanai/inference/[A-Za-z0-9_.-]+$' -or $seen.ContainsKey($relative)) {
                throw "Unsafe TensorRT archive entry: $relative"
            }
            $seen[$relative] = $true
            if ([IO.Path]::GetFileName($relative) -notin @($runtimeFiles.name) + @('DirectML_LICENSE.txt')) {
                throw "Unexpected TensorRT archive entry: $relative"
            }
        }
        & $tar -xf $download -C $stage
        if ($LASTEXITCODE -ne 0) { throw 'Cannot extract locked TensorRT archive' }
    }
    foreach ($file in $runtimeFiles) {
        $source = if ($file.group -eq 'crt') { Join-Path $BaseRuntimeDirectory $file.name } else { Join-Path $stage ('animejanai/inference/' + $file.name) }
        Assert-InferenceFile -Path $source -Bytes $file.bytes -Sha256 $file.sha256
        Copy-Item -LiteralPath $source -Destination (Join-Path $stage $file.name)
    }
    $extracted = [IO.Path]::GetFullPath((Join-Path $stage 'animejanai'))
    if (-not $extracted.StartsWith($stage + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe extraction cleanup' }
    Remove-Item -LiteralPath $extracted -Recurse -Force
    Assert-TrtRuntime $stage
    Write-TrtInstalledRecord $stage
    Move-Item -LiteralPath $stage -Destination $target
    Write-Output "Prepared optional TensorRT sm$ComputeCapability resources (enable separately in playback): $target"
} finally { Remove-TrtStage $stage $target }
