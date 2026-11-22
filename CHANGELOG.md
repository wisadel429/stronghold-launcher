# 变更记录

> 只记「已经落地」和「明确计划中」两类，不写推测。
> 每条都带可核对的锚点：提交号、文件行号、产物大小、验证命令。

---

## 2026-11-22 · 启动器 v1.1.0 → v1.1.2（解耦 + 公告源配置化）

### 摘要

| 项 | 值 |
|---|---|
| 仓库 | `github.com/wisadel429/stronghold-launcher` |
| 提交 | `98e1dac`（功能）→ `385e524`（打包） |
| 版本 | `launcher/version.json` 1.1.0 → 1.1.2 |
| 产物 | `Stronghold.exe` 430,080 B → 431,104 B → **431,616 B** |
| 发版 | Release `launcher-20261122-1`（zip + manifest） |
| 一句话 | 把启动器从「侵权游戏专用客户端」改回「通用本地游戏容器」，并让热更真的能跑 |

### 1.1 提交 `98e1dac` — 功能与解耦

| 文件 | 改动 | 目的 |
|---|---|---|
| `launcher-host/Program.cs` | 删除 `ServerOrigin = "http://8.134.50.56:3000"`，热更源改为**只走 GitHub** | 启动器不再指向自有服务器 |
| 同上 | `GitHubPkgBase` 由 `stronghold-protocol-fusion` 改为 **`stronghold-launcher`** | 更新通道不再绑在游戏项目上 |
| 同上 | 新增 `AnnouncementSources()`：读 `data/announcement-source.json`；缺文件 → 只读 `127.0.0.1:3000`；`enabled:false` → 完全不联网；只认 http/https | 公告源配置化，地址不进代码 |
| 同上 | 公告拉取加 4 秒超时 + 256KB 上限 + 失败静默 | 服务器挂了不影响启动 |
| 同上 | `Host.JsonStringArray()` | 读配置里的 `urls` 数组 |
| 同上 | 新增 `Host.IsOwnGameProcess()`；`KillPortOwner` 只杀**进程名为 node 且路径在已登记游戏目录/启动器目录下**的进程，否则跳过 | 不再误杀玩家机器上的其它软件 |
| 同上 | 重启服务器时若 `killed == 0`，回报「端口被其他程序占用，已跳过」 | 让用户知道该自己关 |
| `launcher/app.js` | `NOTICE_SOURCES` 改为 `127.0.0.1:3000`；清理注释里的旧 IP 与已停用域名 | 页面兜底源不指向外网 |
| `launcher/index.html` | 「部署公开服务器」→「开服并打开后台」；「未部署」→「未开服」 | 文案与实际行为一致（该按钮只是 `StartLocal + 打开 /admin`） |
| `launcher/app.js` | 「正在部署公开服务器」→「正在开服」；「已部署」→「已开服」 | 同上 |
| `launcher/version.json` | 1.1.0 → 1.1.1 → 1.1.2 | 区分新旧包 |
| `README.md` | 重写「热更新」小节（只从本仓库 Release 取）；新增「公告」小节 | 文档与代码一致 |
| `NOTICE.md` | 新增「公告政策」：只接受纯文本，不含官方美术/截图/下载链接/收款码；不发送账号/设备/存档；源地址不进代码 | 把边界写成书面条款 |

### 1.2 提交 `385e524` — 打包与发布

| 文件 | 改动 | 目的 |
|---|---|---|
| `publish-launcher-pkg.ps1`（**新增**，171 行） | 从**本仓库** `launcher/` 打热更包，发布到 `stronghold-launcher` 的 Release；产物落 `dist/launcher-pkg/` | 不再从游戏目录的旧副本打包（曾因此打出旧页面） |
| `.gitignore` | 加 `dist/` | 打包产物不入库 |
| `E:\stronghold\Stronghold-Protocol-v0.3.3-Fusion\publish-launcher-pkg.ps1` | 改为**转发脚本**（显式转参给上面那个） | 防止误用旧入口 |
| `Stronghold-Launcher\data\announcement-source.json` | `enabled:true` + 自有服务器地址（**仅本机**） | 你的机器保留公告 |
| `Stronghold-Launcher\data\announcement-source.dist.json` | `enabled:false`（**发给玩家用**） | 分发版默认不联网拉公告 |
| `Stronghold-Launcher\data\update-channel.json` | `enabled:true` | 打开「页面代码」热更（GitHub） |

### 1.3 发布与验证

| 检查 | 结果 |
|---|---|
| `git push` | `458a274..385e524 → main`，`HEAD == origin/main == 385e524` |
| Release | tag `launcher-20261122-1`，资产 `launcher-pkg.zip`(31,284 B) + `launcher-pkg-manifest.json`(552 B) |
| manifest 的 zip 地址 | `.../releases/latest/download/launcher-pkg.zip`（绝对地址，`latest` 可解析） |
| 实际下载 zip 的 sha256 | `c26e4f24…89715`，与 manifest 一致 |
| zip 结构 | `launcher-pkg-src\launcher\{app.js,index.html,loading.html,style.css}`（宿主剥顶层后落进 `launcher/` 白名单） |
| C# 编译 | `csc` exit 0（改前/改后各一次） |
| JS 语法 | `node --check` exit 0 |
| exe 字符串审计 | 含 `8.134.50.56`：**否**；含 `stronghold-protocol-fusion`：**否**；含 `stronghold-launcher`：**是**；含 `announcement-source.json`：**是** |

### 1.4 回滚点

| 类型 | 位置 |
|---|---|
| exe（1.1.0） | `Stronghold-Launcher\Stronghold.exe.bak-20261122-announcement` |
| exe（1.1.1） | `Stronghold-Launcher\Stronghold.exe.bak-20261122-v111` |
| 代码（改前远端） | `458a274` |
| Release | `launcher-1.0.0`、`launcher-1.1.0`、`launcher-20261122-1` |

---

## 2026-11-22 · 列表站（`stronghold-server-list`）

> **状态：计划中，尚未实施。** 当前线上仍为 `87b61c0`，`servers.json` 14 条均无「非营利」字段。

### 2.1 已核实的事实

| 项 | 结果 |
|---|---|
| 收录数量 | 14 条，14 条 `enabled: true` |
| 备注/标签里出现「赞助/收费/打赏/广告/付费/会员/卖」 | **0 条** |
| `servers.json` 是否记录非营利状态 | 否 |
| README 是否有收录门槛 | 否 |
| 页面是否有免费公示 | 否 |

### 2.2 待实施改动（A–E）

| 项 | 文件 | 锚点 | 内容 |
|---|---|---|---|
| A | `servers.json` | 14 条 `"enabled": true` 后 | 加 `nonProfit: true`、`nonProfitConfirmedAt`、`nonProfitBasis` |
| B | `server.mjs` | **383 行**（`rowFromInput`，367 行起） | 追加 3 行字段白名单；**不改则后台一保存就丢字段** |
| C | `public/admin.html` | **254 / 357 / 458** | 复选框 + 确认日期 + 确认依据 + 提交字段 |
| D | `public/index.html` | **508–511**（`<footer class="rl-footer">`） | 页脚加「只收录免费服 / 举报即下架」公示 |
| E | `README.md` | 末尾 + 第 7 条已知坑 | 新增「收录规则」6 条 |

> `serversPayload()`（596 行）用 `...srv` 展开，**不用改**。
> 注：早期草稿把该函数误称为 `normalizeRow`，实际名为 `rowFromInput`。

### 2.3 上线步骤（未执行）

1. `git add -A && git commit && git push`
2. `POST /admin/api/deploy`（或后台点「更新到最新版」）
3. 验证 `/api/servers` 14 条均含 `nonProfit: true`；页脚出现公示行

---

## 待办

| # | 事项 | 归属 |
|---|---|---|
| 1 | 收集 14 份服主「免费」书面确认截图，存 `data/confirmations/<id>-<日期>.png` | 需人工 |
| 2 | 列表站 A–E 实施 | 待确认 |
| 3 | 发给玩家的包用 `announcement-source.dist.json` 覆盖同名文件 | 打包时 |
| 4 | 打包分发前删除 `Stronghold.exe.bak-*` | 打包时 |
| 5 | `HANDOFF-2026-11-22.md` 第 1465 行令牌为明文，建议改占位符或到 GitHub 轮换 | 安全 |

---

## 附：本轮涉及的文件

**启动器仓库**：`launcher-host/Program.cs`、`launcher/app.js`、`launcher/index.html`、`launcher/version.json`、`README.md`、`NOTICE.md`、`publish-launcher-pkg.ps1`、`.gitignore`

**分发目录**：`Stronghold-Launcher\{Stronghold.exe, launcher\, data\*.json, 使用说明.txt, NOTICE.md, README.md}`

**游戏目录**：`publish-launcher-pkg.ps1`（已改为转发）

**分析备忘**：`E:\deepseek harness\启动器热更新-合法性分析.md`（三轮：直接侵权 / 帮助侵权与帮信罪 / 14 服全免费）
