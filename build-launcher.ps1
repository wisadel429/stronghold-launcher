# build-launcher.ps1 — 编译启动器宿主（不需要 Visual Studio，用 Windows 自带 .NET Framework csc）
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File .\build-launcher.ps1 [-GameRoot "E:\stronghold\Stronghold-Protocol-v0.3.3-Fusion"] [-Out ".\Stronghold.exe"]
#
# 依赖（从游戏安装目录拿，不入库）：
#   Microsoft.Web.WebView2.Core.dll / Microsoft.Web.WebView2.WinForms.dll
#   launcher\game.ico（图标，属美术资源，不入库；找不到就不带图标编译）

param(
  [string]$GameRoot = '',
  [string]$Out = ''
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path -LiteralPath $csc)) { throw '找不到 .NET Framework 编译器 csc.exe（需要 Windows 自带的 .NET Framework 4.x）' }

# WebView2 SDK：优先本目录 host\lib，其次游戏安装目录、launcher-host-build
$dllDirs = @(
  (Join-Path $here 'host\lib'),
  (Join-Path $here 'launcher-host-build'),
  (Join-Path $GameRoot 'launcher-host-build')
) | Where-Object { $_ -and (Test-Path $_) }

$core = $null; $winforms = $null
foreach ($d in $dllDirs) {
  $c = Join-Path $d 'Microsoft.Web.WebView2.Core.dll'
  $w = Join-Path $d 'Microsoft.Web.WebView2.WinForms.dll'
  if ((Test-Path $c) -and (Test-Path $w)) { $core = $c; $winforms = $w; break }
}
if (-not $core) { throw '缺少 WebView2 SDK：把 Microsoft.Web.WebView2.Core.dll / .WinForms.dll 放到 host\lib 或游戏安装目录' }

if (-not $Out) { $Out = Join-Path $here 'Stronghold.exe' }
$icon = Join-Path $GameRoot 'launcher\game.ico'
$src = Join-Path $here 'launcher-host\Program.cs'
if (-not (Test-Path $src)) { throw "找不到宿主源码：$src" }

$cscArgs = @(
  '/nologo', '/target:winexe', '/platform:x64', '/optimize+', '/utf8output',
  "/out:$Out",
  '/r:System.dll', '/r:System.Core.dll', '/r:System.Drawing.dll', '/r:System.Windows.Forms.dll',
  '/r:System.IO.Compression.dll', '/r:System.IO.Compression.FileSystem.dll',
  "/r:$core", "/r:$winforms",
  $src
)
if (Test-Path $icon) { $cscArgs = @("/win32icon:$icon") + $cscArgs } else { Write-Host '  提示：没有 game.ico，本次不带图标' -ForegroundColor Yellow }

Write-Host '  csc ' -NoNewline
& $csc @cscArgs
if ($LASTEXITCODE -ne 0) { throw "编译失败（exit $LASTEXITCODE）" }

Get-Item -LiteralPath $Out | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
Write-Host ("  已生成：{0}" -f $Out) -ForegroundColor Green
Write-Host '  说明：launcher\ 下是启动页，与 exe 同级放好；version.json 决定「启动器版本号」'
