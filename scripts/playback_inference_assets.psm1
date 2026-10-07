Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PlaybackInferenceLock {
    $lockPath = Join-Path $PSScriptRoot '../windows/playback/inference/dependencies.lock.json'
    $lock = Get-Content -LiteralPath $lockPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($lock.schemaVersion -ne 1 -or $lock.phase -ne 'p0-prerequisites') {
        throw 'Unsupported inference dependency lock'
    }
    foreach ($asset in @($lock.packages) + @($lock.files) +
        @($lock.vcredist.package, $lock.vcredist.container, $lock.vcredist.cabinet)) {
        if ($asset.bytes -le 0 -or $asset.sha256 -cnotmatch '^[0-9a-f]{64}$') {
            throw "Invalid locked size or digest: $($asset.id)"
        }
    }
    return $lock
}

function Assert-InferenceFile {
    param([string]$Path, [long]$Bytes, [string]$Sha256)
    $file = Get-Item -LiteralPath $Path
    if ($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        $file.Length -ne $Bytes -or (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Sha256) {
        throw "Inference asset failed the source dependency lock: $Path"
    }
}

function Get-InferenceTarget {
    param([string]$Root, [string]$RelativePath)
    $relative = $RelativePath.Replace('\', '/')
    if ($relative -match '(^/|:|\x00|(^|/)\.\.?(/|$))') {
        throw "Invalid inference archive path: $RelativePath"
    }
    $absoluteRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $target = [IO.Path]::GetFullPath((Join-Path $absoluteRoot $relative))
    if (-not $target.StartsWith($absoluteRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "Inference path escapes its destination: $RelativePath"
    }
    return $target
}

function Save-InferenceDownload {
    param([string]$Url, [string]$Path, [long]$Bytes, [string]$Sha256)
    $uri = [Uri]$Url
    if ($uri.Scheme -ne 'https' -or $uri.Host -notin @('raw.githubusercontent.com', 'api.nuget.org', 'download.visualstudio.microsoft.com')) {
        throw "Untrusted inference source: $Url"
    }
    if (Test-Path -LiteralPath $Path) {
        Assert-InferenceFile -Path $Path -Bytes $Bytes -Sha256 $Sha256
        return
    }
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($Path)) -Force | Out-Null
    $partial = $Path + '.part'
    # Developer preparation only: restarting a failed download is intentional.
    # The application-level Range/ETag installer belongs to P3, not this script.
    Invoke-WebRequest -Uri $Url -OutFile $partial -MaximumRedirection 0
    Assert-InferenceFile -Path $partial -Bytes $Bytes -Sha256 $Sha256
    Move-Item -LiteralPath $partial -Destination $Path
}

function Expand-InferencePackage {
    param([string]$ArchivePath, [object]$Package, [object[]]$Files, [string]$Stage)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $seen = @{}
        $remaining = [long]1024 * 1024 * 1024
        if ($archive.Entries.Count -gt 10000) { throw 'Too many NuGet archive entries' }
        $found = @{}
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName.Replace('\', '/')
            if ($name -match '(^/|:|\x00|(^|/)\.\.?(/|$))' -or $name.Length -gt 1024 -or
                (($entry.ExternalAttributes -shr 16) -band 0xf000) -eq 0xa000 -or $seen.ContainsKey($name)) {
                throw "Unsafe or duplicate NuGet archive entry: $name"
            }
            $seen[$name] = $true
            $remaining -= $entry.Length
            if ($remaining -lt 0) { throw 'NuGet archive exceeds its extraction budget' }
            if ($name.EndsWith('/')) { continue }
            $file = @($Files | Where-Object { $_.source -ceq $name })
            $destination = $null
            if ($file.Count -eq 1) {
                $destination = Get-InferenceTarget -Root (Join-Path $Stage 'runtime') -RelativePath $file[0].path
                if ($entry.Length -ne $file[0].bytes) { throw "Unexpected archive file length: $name" }
                $found[$name] = $true
            } elseif ($name.StartsWith($Package.sdkPrefix, [StringComparison]::Ordinal) -and
                $name.EndsWith('.h', [StringComparison]::OrdinalIgnoreCase)) {
                $sdkRelative = $Package.sdkTarget + $name.Substring($Package.sdkPrefix.Length)
                $destination = Get-InferenceTarget -Root $Stage -RelativePath $sdkRelative
                if ($entry.Length -gt 4 * 1024 * 1024) { throw "Oversized SDK header: $name" }
            }
            if (-not $destination) { continue }
            New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($destination)) -Force | Out-Null
            $inputStream = $entry.Open()
            $outputStream = $null
            try {
                $outputStream = [IO.File]::Open($destination, [IO.FileMode]::CreateNew,
                    [IO.FileAccess]::Write, [IO.FileShare]::None)
                $buffer = New-Object byte[] 65536
                $written = [long]0
                while (($count = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $written += $count
                    if ($written -gt $entry.Length) { throw "Expanded length exceeds archive entry: $name" }
                    $outputStream.Write($buffer, 0, $count)
                }
                if ($written -ne $entry.Length) { throw "Truncated archive entry: $name" }
            } finally {
                if ($outputStream) { $outputStream.Dispose() }
                $inputStream.Dispose()
            }
        }
        foreach ($file in $Files) {
            if (-not $found.ContainsKey($file.source)) { throw "Missing pinned archive entry: $($file.source)" }
        }
    } finally {
        $archive.Dispose()
    }
}

function Get-InferencePeImports {
    param([string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $reader = [IO.BinaryReader]::new($stream)
    try {
        if ($reader.ReadUInt16() -ne 0x5a4d) { throw "Not a PE file: $Path" }
        $stream.Position = 0x3c
        $offset = $reader.ReadUInt32()
        $stream.Position = $offset
        if ($reader.ReadUInt32() -ne 0x4550 -or $reader.ReadUInt16() -ne 0x8664) {
            throw "Inference DLL must be PE x64: $Path"
        }
        $sectionCount = $reader.ReadUInt16()
        if ($sectionCount -lt 1 -or $sectionCount -gt 96) { throw 'Invalid PE section count' }
        $stream.Position = $offset + 20
        $optionalSize = $reader.ReadUInt16()
        $optionalOffset = $offset + 24
        $stream.Position = $optionalOffset
        if ($reader.ReadUInt16() -ne 0x20b -or $optionalSize -lt 224) { throw 'Invalid PE32+ header' }
        $sections = @()
        $stream.Position = $optionalOffset + $optionalSize
        for ($index = 0; $index -lt $sectionCount; $index++) {
            $stream.Position += 8
            $virtualSize = $reader.ReadUInt32()
            $virtualAddress = $reader.ReadUInt32()
            $rawSize = $reader.ReadUInt32()
            $rawOffset = $reader.ReadUInt32()
            $sections += @{ rva = $virtualAddress; length = [Math]::Max($virtualSize, $rawSize); offset = $rawOffset; raw = $rawSize }
            $stream.Position += 16
        }
        function Convert-Rva([uint32]$Rva) {
            foreach ($section in $sections) {
                $delta = [long]$Rva - $section.rva
                if ($delta -ge 0 -and $delta -lt $section.length -and $delta -lt $section.raw) {
                    $position = [long]$section.offset + $delta
                    if ($position -ge $stream.Length) { break }
                    return $position
                }
            }
            throw "Invalid PE RVA: $Rva"
        }
        $names = @{}
        # Import descriptors and RVA-based delay-import descriptors.
        foreach ($directory in @(@{ index = 1; size = 20; name = 12 }, @{ index = 13; size = 32; name = 4 })) {
            $stream.Position = $optionalOffset + 112 + 8 * $directory.index
            $rva = $reader.ReadUInt32()
            $size = $reader.ReadUInt32()
            if ($rva -eq 0) { continue }
            if ($size -gt 1024 * 1024) { throw 'Oversized PE import table' }
            $table = Convert-Rva $rva
            $terminated = $false
            for ($entryOffset = 0; $entryOffset + $directory.size -le $size; $entryOffset += $directory.size) {
                $stream.Position = $table + $entryOffset
                $descriptor = $reader.ReadBytes($directory.size)
                if ($descriptor.Length -ne $directory.size) { throw 'Truncated PE import table' }
                if (@($descriptor | Where-Object { $_ -ne 0 }).Count -eq 0) { $terminated = $true; break }
                if ($directory.index -eq 13 -and [BitConverter]::ToUInt32($descriptor, 0) -ne 1) {
                    throw 'Unsupported non-RVA delay-import table'
                }
                $stream.Position = Convert-Rva ([BitConverter]::ToUInt32($descriptor, $directory.name))
                $name = [Text.StringBuilder]::new()
                while ($name.Length -le 260) {
                    $value = $reader.ReadByte()
                    if ($value -eq 0) { break }
                    [void]$name.Append([char]$value)
                }
                if ($name.Length -gt 260 -or $name.ToString() -match '[/\\:]') { throw 'Invalid imported DLL name' }
                $names[$name.ToString().ToLowerInvariant()] = $true
            }
            if (-not $terminated) { throw 'Unterminated PE import table' }
        }
        return @($names.Keys | Sort-Object)
    } finally {
        $reader.Dispose()
        $stream.Dispose()
    }
}

Export-ModuleMember -Function Get-PlaybackInferenceLock, Assert-InferenceFile,
    Get-InferenceTarget, Save-InferenceDownload, Expand-InferencePackage, Get-InferencePeImports
