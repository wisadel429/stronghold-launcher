# 卫戍协议：盟约 · 启动器（Stronghold Launcher）

独立于游戏本体的启动器：负责**启动/切换多个游戏版本**、开服、热更新、公告与反馈入口。

> 本仓库**只含代码**（宿主源码 + 启动页）。美术资源（立绘 / UI 素材 / 图标 / 音频）一律不入库，
> 详见 [NOTICE.md](NOTICE.md)。

## 组成

| 路径 | 说明 |
|---|---|
| `launcher-host/Program.cs` | 宿主：WinForms + WebView2（C# 5 语法，用 Windows 自带 `csc` 直接编译） |
| `launcher/` | 启动页（原生 HTML/CSS/JS，跑在 WebView2 里，虚拟域 `https://app.local`） |
| `launcher/version.json` | **启动器自己的版本号**（与游戏热更包的 `version` 相互独立） |
| `build-launcher.ps1` | 一键编译宿主为 `Stronghold.exe` |

## 编译

```powershell
powershell -ExecutionPolicy Bypass -File .\build-launcher.ps1
```

依赖（放在游戏安装目录里即可，宿主运行时会读）：

- Windows 自带 .NET Framework 4.x 的 `csc.exe`
- `Microsoft.Web.WebView2.Core.dll` / `Microsoft.Web.WebView2.WinForms.dll`（WebView2 SDK）
- 系统已安装 **Microsoft Edge WebView2 Runtime**（常青版）；启动器**不再自带运行时**

## 运行形态

启动器与游戏**分离部署**，靠 `launcher-versions.json` 登记游戏目录：

```json
{"active":"local","versions":[
  {"id":"local","name":"0.3.3 融合版","dir":".","port":3000},
  {"id":"v040","name":"0.4.0 测试版","dir":"E:\\stronghold\\Stronghold-Protocol-v0.4.0","port":3010}
]}
```

- 每个版本**独立目录、独立端口、独立 `data/`**（账号与存档不互通）
- 支持**同时运行多个版本**（端口不冲突即可）
- 启动页的「游戏版本」区块可导入目录、开服/停止、切换当前版本、移除；
  点击「本地游戏 / 部署公开服务器」时若有两个以上版本，会先弹窗选版本

## 热更新

- 启动器代码走 `launcher-pkg`（manifest + zip + sha256，只收 `.js/.mjs/.css/.html/.md`）
- 检查顺序：自有服务器 → 域名 → **GitHub Release 兜底**
- 宿主固定启用 TLS 1.2+ 并**绕过系统自动代理**（否则国内环境下会卡十几秒）

## 版本号口径

| 用途 | 位置 | 例子 |
|---|---|---|
| 启动器版本 | `launcher/version.json` → `launcher` | `1.0.0` |
| 启动器热更包 | `launcher-pkg/manifest.json` → `version` | `20261123-04` |
| 游戏本体版本 | 游戏目录的 `package.json` → `version` | `0.3.3-Yuan` |

## 许可

GPL-3.0-or-later（见 `LICENSE`）。非官方同人作品，与鹰角网络无关，素材版权归原权利人。
