# 读取.env文件
$file = Get-Content .env
# 读取版本号和签名证书的密码
$signPwd = $file | Select-String -Pattern "SIGN_SECRET" | ForEach-Object { $_ -replace "SIGN_SECRET=", "" }
$version = $file | Select-String -Pattern "MSIX_VERSION" | ForEach-Object { $_ -replace "MSIX_VERSION=", "" }
# 构建命令
$command = "dart run msix:create --version=$version -p $signPwd"
Write-Output "dart run msix:create --version=$version"
Invoke-Expression $command