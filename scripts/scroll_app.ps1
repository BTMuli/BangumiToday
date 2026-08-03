param([string]$Direction = 'up', [int]$Ticks = 5)
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class W {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, int dwData, UIntPtr dwExtraInfo);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
$p = Get-Process bangumi_today | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { Write-Output "NO WINDOW"; exit 1 }
[W]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 200
$rect = New-Object W+RECT
[W]::GetWindowRect($p.MainWindowHandle, [ref]$rect) | Out-Null
$x = [int](($rect.Left + $rect.Right) / 2)
$y = [int](($rect.Top + $rect.Bottom) * 0.55)
[W]::SetCursorPos($x, $y) | Out-Null
Start-Sleep -Milliseconds 100
$delta = if ($Direction -eq 'up') { 120 } else { -120 }
for ($i = 0; $i -lt $Ticks; $i++) {
  [W]::mouse_event(0x0800, 0, 0, $delta, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 60
}
Write-Output "ok $Direction $Ticks at $x,$y"