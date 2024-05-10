# 读取.env文件
$file = Get-Content .env
# 读取版本号和签名证书的密码
$signPwd = $file | Select-String -Pattern "SIGN_SECRET" | ForEach-Object { $_ -replace "SIGN_SECRET=", "" }
$version = $file | Select-String -Pattern "MSIX_VERSION" | ForEach-Object { $_ -replace "MSIX_VERSION=", "" }
# 在已安装的 msix 应用中查找 BangumiToday
$package = Get-AppxPackage -Name "BangumiToday"
# 如果已安装 BangumiToday 获取版本号
if ($package)
{
    $versionGet = $package.Version
}
else
{
    $versionGet = 0
}
# 如果版本号与 .env 文件中的版本号一致，不构建
if ($version -eq $versionGet)
{
    Write-Output "已安装应用版本与设置版本一致：$version，不执行构建"
    exit
}
# 如果版本号低于已安装的版本号，不构建
$vers = $version -split "\."
$versGet = $versionGet -split "\."
for ($i = 0; $i -lt 4; $i++)
{
    $veri = [int]$vers[$i]
    $verGeti = [int]$versGet[$i]
    if ($veri -gt $verGeti)
    {
        break
    }
    if ($veri -lt $verGeti)
    {
        Write-Output "已安装应用版本高于设置版本：$version，不执行构建"
        exit
    }
}
Write-Output "开始构建应用版本：$version，本地版本: $versionGet"
# 构建命令
$command = "dart run msix:create --version=$version -p $signPwd"
Write-Output "dart run msix:create --version=$version"
Invoke-Expression $command