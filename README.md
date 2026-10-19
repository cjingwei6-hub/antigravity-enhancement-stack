# Antigravity 增强三件套 · 安装与自动修复

给 [Google Antigravity](https://antigravity.google/) 桌面版装齐三样东西，并让它们在每次版本更新后**自动修回来**。

> 这不是 Antigravity 官方项目。三个组件各自独立维护，本仓库只提供**组合安装顺序、持久化修复脚本**和一份给 AI 用的技能文档。

---

## 三件套是什么

| 组件 | 作用 | 仓库 | 更新后会不会掉 |
|---|---|---|---|
| **Antigravity Desktop CN** | 界面汉化（重包 `app.asar`，注入 preload 翻译引擎） | [Silas-02/antigravity-desktop-cn](https://github.com/Silas-02/antigravity-desktop-cn) | ❌ 会掉 |
| **BetterGravity** | 插件平台（换肤、插件、Pets、内置浏览器…） | [YashjitPal/BetterGravity](https://github.com/YashjitPal/BetterGravity) | ❌ 会掉 |
| **Antigrative Dashboard** | 内嵌仪表盘（tok/s、缓存命中率、5 小时/周配额） | [YOU-SHOULD-KNOW-ME/antigrative-dashboard](https://github.com/YOU-SHOULD-KNOW-ME/antigrative-dashboard) | ✅ 不掉 |

**为什么前两个会掉**：Antigravity 每次更新都替换自己的程序文件，而前两个都改 `app.asar`。第三个装在 `~/.gemini/config/plugins/`，属于 Antigravity 自己的插件系统，不受影响。

---

## ⚠️ 最重要的一条：安装顺序不能反

前两个组件的备份机制**互相不兼容**：

| 组件 | 备份位置 | 语义 |
|---|---|---|
| Antigravity Desktop CN | `resources/app.asar.bak` | 官方原版；**永远从这里重打** |
| BetterGravity | `resources/_app.asar` | 被它接手时的 `app.asar` |

**正确顺序：CN 先 → BetterGravity 后。**

- ✅ CN 先重包 `app.asar`，BG 把**已汉化的包**备份成 `_app.asar`，bootstrap 去加载它 → 两者都生效
- ❌ 反过来：BG 先把 `app.asar` 换成 2 KB bootstrap，CN 会把这个**假 asar** 当成"官方原版"备份，随后重包失败或产出垃圾 → 两个都坏

**卸载顺序相反：先卸 BetterGravity，再卸 CN。**

> 口诀：**装：CN 先；卸：BG 先。**

---

## 快速开始

### 方式 A：手动（三步）

```text
1) 装 CN 汉化     →  https://github.com/Silas-02/antigravity-desktop-cn
                     双击「双击安装中文汉化.bat」（需要 Node.js 16+）

2) 装 BetterGravity →  https://github.com/YashjitPal/BetterGravity/releases
                     运行安装器，点 Install

3) 装 Dashboard    →  https://github.com/YOU-SHOULD-KNOW-ME/antigrative-dashboard/releases
                     解压后 python manage.py install（需要 Python 3.10+）
```

装完**完全退出 Antigravity 再打开**。

### 方式 B：一键修复脚本

```powershell
# 体检（只读，不改任何东西）
powershell -ExecutionPolicy Bypass -File scripts\repair-all.ps1 -DryRun

# 实际修复
powershell -ExecutionPolicy Bypass -File scripts\repair-all.ps1
```

或者直接双击 `scripts\repair-all.cmd`。

脚本会：检测状态 → 确认 Antigravity 没在运行 → 按正确顺序装 CN → 拉最新 runtime 打 BG 补丁 → 核验 → 写日志。

### 方式 C：配成持久化（推荐）

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-persistence.ps1
```

注册两个计划任务：

- **登录后 1 分钟**跑一次（此时 Antigravity 通常还没启动，最安全）
- **每 30 分钟**静默检查一次

**Antigravity 开着的时候会直接跳过，不会强杀** —— 打补丁要独占 `app.asar`，不能打断你正在跑的 agent 任务。所以最坏情况是"等下一个空闲窗口"，不会丢工作。

移除：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-persistence.ps1 -Remove
```

---

## 给 AI 用

`SKILL.md` 是写给 agent 的执行文档，包含：

- 三条腿的状态判读表（`app.asar` / `_app.asar` / `app.asar.bak` 的大小组合 → 当前状态）
- BetterGravity 的三个坑：**PatcherCache 会过期**、EBUSY、`C:/` 不能写 `/c/`
- CN 汉化的注入原理与保护边界
- Dashboard 的 `mounted` 才算成功（`installed: true` 不算）
- **Agent 启动不了 Antigravity 这条硬边界**（附隔离实验方法）
- 高频失败对照表
- 写 `.ps1` 时的 UTF-8 BOM 坑

放进 `~/.workbuddy/skills/antigravity-enhancement-stack/` 即可被识别。

---

## 已知限制（如实说明）

### 已实测通过（2026-10-19 / Antigravity 2.24.0 / Windows 11）

- ✅ **CN 注入**：8 个文件（preload / menu / tray / updater / provisionSplash / wsl / main / ipcHandlers）全部注入成功，`app.asar` 从 4,486,221 → 5,111,370
- ✅ **CN → BG 叠加**：`app.asar`=2,222（bootstrap）、`_app.asar`=5,111,370（含 CN 标记）、`app.asar.bak`=4,486,221（官方）
- ✅ **卸载顺序**：`run uninstall` 卸 BG 后，`app.asar` 回到 5,111,370（CN 版）而非官方 → 证明 BG 的 `_app.asar` 里确实压着 CN 层
- ✅ **脚本幂等**：已装好状态下再跑，识别出「CN 标记已存在」直接跳过，7.8 秒退出码 0
- ✅ **Dashboard**：`state: mounted`，跨版本更新一直存活

### 还没验证的

- ❓ **完整的「更新 → 全掉 → 自动修回」闭环**：脚本的修复路径已验证（手动制造了"仅 CN"状态再跑通），但**没有等到一次真实的 Antigravity 版本更新**来触发「两个都掉」的起点。
- ❓ **界面观感**：脚本能确认文件层面正确、注入标记存在，但 **agent 启动不了 Antigravity**（沙箱限制），所以「中文是不是真的显示出来了」必须由人眼确认。
- ❓ **macOS / Linux 分支**：脚本是按 Windows 写并只在 Windows 上测过。

### 设计上的风险点

- **`app.asar.bak` 的语义会撞车**：Antigravity 更新时也会生成 `.bak`（内容是上一版本）。CN 把它当"官方原版"并永远从它重打，所以脚本会在 CN 未注入时**删掉残留 `.bak`**，让 CN 重新备份当前版本 —— 这一步只在 `app.asar` 确实是有效原生包（>1 MB）时才做，否则可能把 bootstrap 当原版备份。
- **CN 引擎没有 `--no-launch` 参数**。它只在"安装前客户端是开着的"时才自动重启（`if (success && wasAppRunning && !noKill)`），所以脚本坚持在 Antigravity 关闭时修复，以保持静默。
- **三个上游都在活跃更新**，注入点随时可能变。本脚本只保证"按当前已知的正确顺序重放"，不保证永久可用。

---

## 目录

```text
.
├── SKILL.md                          # 给 AI 的执行文档
├── README.md
├── LICENSE
└── scripts/
    ├── repair-all.ps1                # 一键修复（体检 / 执行都靠它）
    ├── repair-all.cmd                # 双击入口（纯 ASCII，优先用 pwsh 7）
    └── install-persistence.ps1       # 注册 / 移除计划任务
```

---

## 许可

MIT。三个上游组件各自遵循其自身许可，本仓库不包含它们的任何代码。
