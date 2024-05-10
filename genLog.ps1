# 读取 CHANGELOG.md
$changelog = Get-Content CHANGELOG.md

# 获取第一个 ## [vx.x.x](xxx) 的行数跟第二个 ## [vx.x.x](xxx) 的行数
$versionStart = $changelog | Select-String -Pattern "## \[v" | Select-Object -First 1
$versionEnd = $changelog | Select-String -Pattern "## \[v" | Select-Object -First 2 | Select-Object -Last 1
# 获取第一个到第二个的内容
$content = $changelog | Select-Object -Skip $versionStart.LineNumber | Select-Object -First ($versionEnd.LineNumber - $versionStart.LineNumber - 1)
$content = $content -join "`n"
Write-Output $content
