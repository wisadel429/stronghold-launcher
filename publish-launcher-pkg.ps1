# publish-launcher-pkg.ps1 — 打「只含代码」的启动器页面热更包（启动器仓库版）
#
# 为什么有这个脚本：热更包必须跟**启动器源码**一起发版，不能从游戏目录里打
# —— 游戏目录那份 launcher/ 可能是旧的，打出来玩家热更完还是旧界面。
#
# 铁律：
#   · 只收 `launcher/` 下的 .js/.mjs/.css/.html/.md，**绝不含美术资源**
#   · 产物只发到本仓库（`stronghold-launcher`）的 Release，不连任何自有服务器
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File .\publish-launcher-pkg.ps1 -Notes "改了什么" [-Version 20261123-08] [-LocalOnly] [-DryRun]
#
# 产物（.\dist\launcher-pkg\）：
#   launcher-pkg.zip           热更包（Release 资产）
#   manifest.json              服务器用清单（zip 为相对路径；本仓库已不用，留作兼容）
#   launcher-pkg-manifest.json -Release 用的清单（zip 为绝对地址，宿主读这个）
#
# 注意包结构：zip 里必须**多包一层顶层目录**（例如 `launcher-pkg-src/launcher/app.js`），
# 宿主解压时会无条件剥掉第一段路径，然后才按 `launcher/` 白名单校验。

param(
  [string]$Notes = '',
  [string]$Version = '',
  [switch]$LocalOnly,
  [string]$Token = $env:GITHUB_TOKEN,
  [string]$Repo = 'wisadel429/stronghold-launcher',
  [int]$KeepReleases = 3,
  [switch]$DryRun
)

$GitHub = -not $LocalOnly
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $root 'dist\launcher-pkg'
if (-not $Version) { $Version = Get-Date -Format 'yyyyMMdd-HHmm' }
New-Item -ItemType Directory -Force $outDir | Out-Null

$srcLauncher = Join-Path $root 'launcher'
if (-not (Test-Path $srcLauncher)) { throw "找不到 launcher/ 目录：$srcLauncher" }

$exts = @('.js', '.mjs', '.css', '.html', '.md')
$stageRoot = Join-Path $root '_pkg-stage'
if (Test-Path $stageRoot) { Remove-Item $stageRoot -Recurse -Force }
# 顶层目录名可以随便起，宿主会剥掉第一段；这里固定一个，便于人工检查
$stage = Join-Path $stageRoot 'launcher-pkg-src'
New-Item -ItemType Directory -Force $stage | Out-Null

$copied = 0
Get-ChildItem $srcLauncher -Recurse -File | ForEach-Object {
  if ($exts -notcontains $_.Extension.ToLowerInvariant()) { return }
  $rel = $_.FullName.Substring($root.Length + 1)   # launcher/xxx
  $dst = Join-Path $stage $rel
  New-Item -ItemType Directory -Force (Split-Path $dst -Parent) | Out-Null
  Copy-Item $_.FullName $dst -Force
  $script:copied++
}
Write-Host ("  收集到 {0} 个启动器页面文件（不含任何美术资源）" -f $copied)

$zip = Join-Path $outDir 'launcher-pkg.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $stage -DestinationPath $zip -CompressionLevel Optimal
Remove-Item $stageRoot -Recurse -Force

$sha = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
$bytes = (Get-Item $zip).Length
$sizeKb = [math]::Round($bytes / 1KB, 1)

$launcherVersion = ''
$lvFile = Join-Path $srcLauncher 'version.json'
if (Test-Path -LiteralPath $lvFile) {
  try { $launcherVersion = (Get-Content -LiteralPath $lvFile -Raw -Encoding UTF8 | ConvertFrom-Json).launcher } catch { }
}

$ghZip = "https://github.com/$Repo/releases/latest/download/launcher-pkg.zip"
$manifest = [ordered]@{
  version = $Version
  kind    = 'launcher'
  at      = (Get-Date -Format 's')
  zip     = '/launcher-pkg/launcher-pkg.zip'
  sha256  = $sha
  bytes   = $bytes
  files   = $copied
  notes   = $Notes
  policy  = 'code-only; launcher page only'
}
if ($launcherVersion) { $manifest.launcherVersion = $launcherVersion }
if ($GitHub) { $manifest.zipFallback = $ghZip }
[System.IO.File]::WriteAllText((Join-Path $outDir 'manifest.json'), ($manifest | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))

if ($GitHub) {
  $ghManifest = [ordered]@{
    version = $Version; kind = 'launcher'; at = (Get-Date -Format 's')
    zip = $ghZip; sha256 = $sha; bytes = $bytes; files = $copied
    notes = $Notes; policy = 'code-only; launcher page only'; source = 'github'
  }
  if ($launcherVersion) { $ghManifest.launcherVersion = $launcherVersion }
  [System.IO.File]::WriteAllText((Join-Path $outDir 'launcher-pkg-manifest.json'),
    ($ghManifest | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
}

Write-Host ""
Write-Host ("  版本     : {0}" -f $Version)
Write-Host ("  启动器   : v{0}" -f ($(if ($launcherVersion) { $launcherVersion } else { '未设置' })))
Write-Host ("  包大小   : {0} KB（{1} 个文件）" -f $sizeKb, $copied)
Write-Host ("  sha256   : {0}" -f $sha)
Write-Host ("  产物目录 : {0}" -f $outDir)

if (-not $GitHub) {
  Write-Host '  提示     : -LocalOnly，只打了本地包，没有发 Release'
  return
}
if ($DryRun) {
  Write-Host '  DryRun   : 跳过上传（清单已生成，可直接手工挂到 Release）'
  return
}

if (-not $Token) {
  try {
    $lines = "protocol=https`nhost=github.com`n`n" | git credential fill 2>$null
    foreach ($line in $lines) { if ($line -match '^password=(.+)$') { $Token = $Matches[1] } }
  } catch { }
}
if (-not $Token) { throw '缺少 GitHub 令牌：用 -Token 传入，或先跑一次 git push 让凭据管理器存下' }

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy = $null

$apiBase = "https://api.github.com/repos/$Repo"
$headers = @{ Authorization = "token $Token"; 'User-Agent' = 'Stronghold-Publish-Script'; Accept = 'application/vnd.github+json' }
$tag = "launcher-$Version"

try {
  $old = Invoke-RestMethod -Method Get -Uri "$apiBase/releases/tags/$tag" -Headers $headers -TimeoutSec 30
  if ($old -and $old.id) {
    Invoke-RestMethod -Method Delete -Uri "$apiBase/releases/$($old.id)" -Headers $headers -TimeoutSec 30
    Write-Host ("  重发     : 已删除同版本旧 Release {0}" -f $tag)
  }
} catch { }

$body = @{
  tag_name   = $tag
  name       = "启动器热更 $Version"
  body       = if ($Notes) { $Notes } else { "启动器页面热更 $Version（只含 launcher/，不含美术资源）" }
  draft      = $false
  prerelease = $false
} | ConvertTo-Json

Write-Host ("  发布     : {0}" -f $tag)
$rel = Invoke-RestMethod -Method Post -Uri "$apiBase/releases" -Headers $headers -Body $body -ContentType 'application/json' -TimeoutSec 60

$assets = @(
  @{ file = $zip; name = 'launcher-pkg.zip' },
  @{ file = (Join-Path $outDir 'launcher-pkg-manifest.json'); name = 'launcher-pkg-manifest.json' }
)
foreach ($a in $assets) {
  $up = "https://uploads.github.com/repos/$Repo/releases/$($rel.id)/assets?name=$($a.name)"
  $res = Invoke-RestMethod -Method Post -Uri $up -Headers $headers -InFile $a.file -ContentType 'application/octet-stream' -TimeoutSec 600
  Write-Host ("  上传     : {0} ({1:N0} B)" -f $res.name, $res.size)
}

try {
  $all = Invoke-RestMethod -Method Get -Uri "$apiBase/releases?per_page=100" -Headers $headers -TimeoutSec 60
  $mine = @($all | Where-Object { $_.tag_name -like 'launcher-*' } | Sort-Object created_at -Descending)
  $drop = @($mine | Select-Object -Skip $KeepReleases)
  foreach ($r in $drop) {
    Invoke-RestMethod -Method Delete -Uri "$apiBase/releases/$($r.id)" -Headers $headers -TimeoutSec 30
    Write-Host ("  清理     : 已删除旧 Release {0}" -f $r.tag_name)
  }
} catch { Write-Host '  清理     : 跳过（列取 Release 失败，不影响本次发布）' }

Write-Host ("  完成     : 下载地址 = {0}" -f $ghZip) -ForegroundColor Green
