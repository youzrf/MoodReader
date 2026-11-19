# 在本机起一个静态服务器，让同一 Wi-Fi 下的 iPhone 打开网页版。
# 用法：右键“使用 PowerShell 运行”，或  pwsh -File scripts\start-demo-server.ps1
# 关掉这个窗口 = 停掉服务。
param([int]$Port = 8000)

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$candidates = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
        $_.IPAddress -notlike '127.*' -and
        $_.IPAddress -notlike '169.254.*' -and
        $_.InterfaceAlias -notlike 'vEthernet*' -and
        $_.InterfaceAlias -notlike '*Loopback*'
    }

$ip = ($candidates | Where-Object { $_.InterfaceAlias -match 'WLAN|Wi-Fi|Ethernet|以太网|无线' } |
        Select-Object -First 1).IPAddress
if (-not $ip) { $ip = ($candidates | Select-Object -First 1).IPAddress }

Write-Host ""
Write-Host "  电脑上打开:  http://localhost:$Port/demo/" -ForegroundColor Green
if ($ip) {
    Write-Host "  手机上打开:  http://${ip}:$Port/demo/   (手机要和电脑连同一个 Wi-Fi)" -ForegroundColor Green
} else {
    Write-Host "  没找到局域网 IP，手机上可能打不开。" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  第一次运行时 Windows 会弹防火墙提示，勾选“专用网络”并允许。" -ForegroundColor DarkGray
Write-Host "  按 Ctrl+C 停止。" -ForegroundColor DarkGray
Write-Host ""

python -m http.server $Port --bind 0.0.0.0
