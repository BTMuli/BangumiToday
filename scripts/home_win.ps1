param(
  [string]$Action = "maximize",
  [int]$Width = 0,
  [int]$Height = 0
)

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class BtWin32 {
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
}
"@

$proc = Get-Process | Where-Object {
  $_.ProcessName -like 'bangumi_today*' -and $_.MainWindowHandle -ne 0
} | Select-Object -First 1

if (-not $proc) {
  Write-Output "NO_PROC"
  exit 1
}

$h = $proc.MainWindowHandle
switch ($Action) {
  "maximize" { [BtWin32]::ShowWindow($h, 3) | Out-Null }
  "restore"  { [BtWin32]::ShowWindow($h, 9) | Out-Null }
  "size" {
    [BtWin32]::ShowWindow($h, 9) | Out-Null
    [BtWin32]::SetWindowPos($h, [IntPtr]::Zero, 0, 0, $Width, $Height, 0x0014) | Out-Null
  }
  default { Write-Output "BAD_ACTION"; exit 1 }
}

Write-Output "OK $h"
