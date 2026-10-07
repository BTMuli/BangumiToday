[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '../.dart_tool/playback_inference/p0'),
    [string]$CacheDirectory = (Join-Path $PSScriptRoot '../.dart_tool/playback_inference/downloads')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'playback_inference_assets.psm1') -Force
$lock = Get-PlaybackInferenceLock
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
if (Test-Path -LiteralPath $outputRoot) {
    & (Join-Path $PSScriptRoot 'verify_playback_inference_prerequisites.ps1') -RuntimeDirectory (Join-Path $outputRoot 'runtime')
    Assert-PreparedHeaders -Root $outputRoot
    Write-Output "Reusing verified P0 prerequisites: $outputRoot"
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
    foreach ($file in $lock.files | Where-Object { -not $_.PSObject.Properties['package'] }) {
        $download = Join-Path $cacheRoot ($file.sha256 + '.asset')
        Save-InferenceDownload -Url ($lock.modelSource + $file.source) -Path $download -Bytes $file.bytes -Sha256 $file.sha256
        $destination = Get-InferenceTarget -Root (Join-Path $stage 'runtime') -RelativePath $file.path
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($destination)) -Force | Out-Null
        Copy-Item -LiteralPath $download -Destination $destination
    }
    $runtime = Join-Path $stage 'runtime'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../windows/playback/inference/dependencies.lock.json') -Destination (Join-Path $runtime 'manifest.json')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../windows/playback/inference/THIRD_PARTY_NOTICES.txt') -Destination $runtime
    & (Join-Path $PSScriptRoot 'verify_playback_inference_prerequisites.ps1') -RuntimeDirectory $runtime
    Assert-PreparedHeaders -Root $stage
    Move-Item -LiteralPath $stage -Destination $outputRoot
    Write-Output "Prepared P0 runtime and developer headers: $outputRoot"
} finally {
    # Only this transaction's checked sibling staging directory may be deleted.
    $resolvedStage = [IO.Path]::GetFullPath($stage)
    if ($resolvedStage.StartsWith($outputRoot + '.', [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetDirectoryName($resolvedStage) -eq [IO.Path]::GetDirectoryName($outputRoot) -and
        (Test-Path -LiteralPath $resolvedStage)) {
        Remove-Item -LiteralPath $resolvedStage -Recurse -Force
    }
}
