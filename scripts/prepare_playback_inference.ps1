[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '../.dart_tool/playback_inference/base'),
    [string]$CacheDirectory = (Join-Path $PSScriptRoot '../.dart_tool/playback_inference/downloads'),
    [string]$VCToolsRedistDirectory = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'playback_inference_assets.psm1') -Force
$lock = Get-PlaybackInferenceLock
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/')
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\', '/')
$cacheRoot = [IO.Path]::GetFullPath($CacheDirectory).TrimEnd('\', '/')
function Assert-PreparedHeaders([string]$Root) {
    foreach ($header in $lock.headers) {
        $sdkRoot = switch ($header.package) {
            'directml' { Join-Path $Root 'sdk/directml' }
            'onnxruntime-directml' { Join-Path $Root 'sdk/onnxruntime' }
            default { throw "Unknown inference SDK package: $($header.package)" }
        }
        $path = Get-InferenceTarget -Root $sdkRoot -RelativePath $header.path
        Assert-InferenceFile -Path $path -Bytes $header.bytes -Sha256 $header.sha256
    }
}
# Extract only the four locked CRT DLLs. The signed Microsoft installer is a
# pinned data container here; it is never executed and no runtime is installed.
function Resolve-VCRedistDirectory([string]$Stage) {
    if ($VCToolsRedistDirectory) {
        return (Resolve-Path -LiteralPath $VCToolsRedistDirectory).Path
    }
    $redist = $lock.vcredist
    $archive = Join-Path $cacheRoot ($redist.package.sha256 + '.exe')
    Save-InferenceDownload -Url $redist.package.url -Path $archive `
        -Bytes $redist.package.bytes -Sha256 $redist.package.sha256
    $root = Join-Path $Stage 'crt'
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $container = Join-Path $root 'container.cab'
    $inputStream = [IO.File]::OpenRead($archive)
    try {
        $offset = [long]$redist.container.offset
        $length = [int]$redist.container.bytes
        if ($offset -lt 0 -or $length -gt 32 * 1024 * 1024 -or
            $offset + $length -gt $inputStream.Length) { throw 'Invalid locked CRT container range' }
        $inputStream.Position = $offset
        $buffer = New-Object byte[] $length
        $received = 0
        while ($received -lt $length) {
            $count = $inputStream.Read($buffer, $received, $length - $received)
            if ($count -eq 0) { throw 'Truncated CRT container' }
            $received += $count
        }
        [IO.File]::WriteAllBytes($container, $buffer)
    } finally { $inputStream.Dispose() }
    Assert-InferenceFile -Path $container -Bytes $redist.container.bytes -Sha256 $redist.container.sha256
    $cabinetName = [string]$redist.cabinet.name
    if ($cabinetName -cnotmatch '^a[0-9]+$') { throw 'Invalid locked CRT cabinet name' }
    $expand = Join-Path $env:SystemRoot 'System32/expand.exe'
    & $expand ('-F:' + $cabinetName) $container $root | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'CRT cabinet extraction failed' }
    $cabinet = Join-Path $root $cabinetName
    Assert-InferenceFile -Path $cabinet -Bytes $redist.cabinet.bytes -Sha256 $redist.cabinet.sha256
    foreach ($file in $lock.files | Where-Object { $_.PSObject.Properties['provider'] -and $_.provider -eq 'vcredist' }) {
        $entry = [string]$file.source + '_amd64'
        if ($entry -cnotmatch '^[a-z0-9_]+\.dll_amd64$') { throw 'Invalid locked CRT entry name' }
        & $expand ('-F:' + $entry) $cabinet $root | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "CRT file extraction failed: $entry" }
        $extracted = Join-Path $root $entry
        Assert-InferenceFile -Path $extracted -Bytes $file.bytes -Sha256 $file.sha256
        Move-Item -LiteralPath $extracted -Destination (Join-Path $root $file.source)
    }
    return $root
}
if (Test-Path -LiteralPath $outputRoot) {
    & (Join-Path $PSScriptRoot 'verify_playback_inference_prerequisites.ps1') -RuntimeDirectory (Join-Path $outputRoot 'runtime')
    Assert-PreparedHeaders -Root $outputRoot
    & (Join-Path $PSScriptRoot 'prepare_playback_tensorrt.ps1') -HeadersOnly -SdkDirectory (Join-Path $outputRoot 'sdk/tensorrt') -CacheDirectory $cacheRoot
    Write-Output "Reusing verified inference assets: $outputRoot"
    return
}
$stage = $outputRoot + '.' + [Guid]::NewGuid().ToString('N') + '.staging'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
try {
    foreach ($package in $lock.packages) {
        $archive = Join-Path $cacheRoot ($package.sha256 + '.nupkg')
        Save-InferenceDownload -Url $package.url -Path $archive -Bytes $package.bytes -Sha256 $package.sha256
        $files = @($lock.files | Where-Object { $_.PSObject.Properties['package'] -and $_.package -eq $package.id })
        Expand-InferencePackage -ArchivePath $archive -Package $package -Files $files -Stage $stage
    }
    $vcRedist = $null
    foreach ($file in $lock.files) {
        if (-not $file.PSObject.Properties['provider'] -and
            $file.PSObject.Properties['package']) {
            # Extracted from the pinned NuGet archive above.
            continue
        }
        $provider = if ($file.PSObject.Properties['provider']) { [string]$file.provider } else { 'source' }
        $destination = Get-InferenceTarget -Root (Join-Path $stage 'runtime') -RelativePath $file.path
        if ($provider -eq 'vcredist') {
            if (-not $vcRedist) { $vcRedist = Resolve-VCRedistDirectory -Stage $stage }
            $source = Get-InferenceTarget -Root $vcRedist -RelativePath $file.source
            Assert-InferenceFile -Path $source -Bytes $file.bytes -Sha256 $file.sha256
            New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($destination)) -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $destination
        } elseif ($provider -eq 'repo') {
            $source = Get-InferenceTarget -Root $repoRoot -RelativePath $file.source
            Assert-InferenceFile -Path $source -Bytes $file.bytes -Sha256 $file.sha256
            New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($destination)) -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $destination
        } elseif ($provider -eq 'source') {
            $download = Join-Path $cacheRoot ($file.sha256 + '.asset')
            Save-InferenceDownload -Url ($lock.modelSource + $file.source) -Path $download -Bytes $file.bytes -Sha256 $file.sha256
            New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($destination)) -Force | Out-Null
            Copy-Item -LiteralPath $download -Destination $destination
        } else {
            throw "Unknown inference asset provider: $provider"
        }
    }
    $runtime = Join-Path $stage 'runtime'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../windows/playback/inference/dependencies.lock.json') -Destination (Join-Path $runtime 'manifest.json')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../windows/playback/inference/THIRD_PARTY_NOTICES.txt') -Destination $runtime
    & (Join-Path $PSScriptRoot 'verify_playback_inference_prerequisites.ps1') -RuntimeDirectory $runtime
    Assert-PreparedHeaders -Root $stage
    & (Join-Path $PSScriptRoot 'prepare_playback_tensorrt.ps1') -HeadersOnly -SdkDirectory (Join-Path $stage 'sdk/tensorrt') -CacheDirectory $cacheRoot
    $crtStage = Join-Path $stage 'crt'
    if (Test-Path -LiteralPath $crtStage) {
        foreach ($item in Get-ChildItem -LiteralPath $crtStage -Recurse -File) {
            Remove-Item -LiteralPath $item.FullName
        }
        foreach ($directory in Get-ChildItem -LiteralPath $crtStage -Recurse -Directory |
            Sort-Object { $_.FullName.Length } -Descending) {
            Remove-Item -LiteralPath $directory.FullName
        }
        Remove-Item -LiteralPath $crtStage
    }
    Move-Item -LiteralPath $stage -Destination $outputRoot
    Write-Output "Prepared inference runtime and developer headers: $outputRoot"
} finally {
    # Only this transaction's checked sibling staging directory may be deleted.
    $resolvedStage = [IO.Path]::GetFullPath($stage)
    if ($resolvedStage.StartsWith($outputRoot + '.', [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetDirectoryName($resolvedStage) -eq [IO.Path]::GetDirectoryName($outputRoot) -and
        (Test-Path -LiteralPath $resolvedStage)) {
        Remove-Item -LiteralPath $resolvedStage -Recurse -Force
    }
}
