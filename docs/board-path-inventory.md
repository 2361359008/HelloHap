# 板端文件位置全量对照（换新板照此摆放，避免“找不到文件”）

> 所有路径均从代码硬编码中抽取：`shell-bridge.mjs` 常量+路由、各 `*.sh`、`https-proxy.js`、主 `entry/.../Index.ets`。
> 主 HAP 并不直接读板端文件，而是通过 **HTTP `http://127.0.0.1:7681/<路由>`** 调 shell-bridge，由 shell-bridge 去碰真正的板端路径。下表把这条链补全。
> 标注：【仓库】=本仓库提供；【板端产物】=不在 Git，需从旧板拷或重新构建后一起摆好。

---

## 一、服务进程 / 端口 / 入口文件

| 服务 | 板端文件 | 端口 | 来源 |
|---|---|---|---|
| Node 运行时 | `/data/local/tmp/node` | — | 【板端产物】|
| OpenClaw Gateway | `/data/local/tmp/openclaw/openclaw.mjs`（+ `node_modules/.pnpm/ws@8.19.0/...`） | 18800 | 【板端产物】|
| Shell-Bridge | `/data/local/tmp/shell-bridge.js` | 7681 (HTTP+WS) | 【仓库 `shell-bridge.mjs`】|
| HTTPS 反代(可选) | `/data/local/tmp/https-proxy.js` (+ `proxy-cert.pem`/`proxy-key.pem`) | 18801→18800 | 【仓库】|
| 开机自启 init | `/system/etc/init/openclaw.cfg` | — | 【板端/系统层】|
| 开机脚本 | `/data/local/tmp/bin/openclaw-boot.sh` | — | 【板端】(含 setenforce 0、起 bridge+gateway) |
| 网关配置(含 token) | `/data/local/tmp/.openclaw/openclaw.json` | — | 【板端，勿误删】|
| 容器自启脚本 | `/data/local/tmp/autostart_houmo.sh` | — | 【板端】shell-bridge 检测到 linux-env 运行后自动跑（存在才跑） |

---

## 二、主 HAP 调用链：路由 → 脚本 → 触碰的板端路径

主 HAP（`com.openclaw.learnhap`）→ `127.0.0.1:7681` 路由：`/read-file`、`/list-files`、`/reset-course`、`/reset-advanced`、`/install-initial`、`/install-teaching`（及各功能 HAP 的 reset/install）。

shell-bridge 全部路由与落点：

| HTTP 路由 | 执行脚本（板端绝对路径） | 关键依赖文件 | 包名/动作 |
|---|---|---|---|
| `/token` | （读配置） | `/data/local/tmp/.openclaw/openclaw.json` | 返回 gateway token |
| `/read-file` `/list-files` | （bridge 内置，白名单目录） | 各 `*-hapbuild/project/`、`.openclaw/workspace/memory/` | 读码/列目录 |
| `/reset-course` | `/data/local/tmp/oh61-hapbuild/restore_course_project.sh` | `oh61-hapbuild/backups/course-initial/project.tar` | 还原主课程工程 |
| `/reset-advanced` | `/data/local/tmp/advanced-hapbuild/restore_advanced_project.sh` | `advanced-hapbuild/backups/course-initial/project.tar` | 还原高级工程 |
| `/install-initial` | `/data/local/tmp/advanced-hapbuild/install_initial_advanced.sh` | `advanced-hapbuild/schedule-initial-signed.hap` | `com.openclaw.schedulehap.lite` 装+启 |
| `/install-teaching` | `/data/local/tmp/advanced-hapbuild/install_initial_teaching.sh` | （不装，仅 `aa start`） | `com.openclaw.schedulehap` 启 |
| `/reset-minesweeper` | `/data/local/tmp/minesweeper-hapbuild/restore_minesweeper_project.sh` | `minesweeper-hapbuild/backups/initial/project.tar` | 还原扫雷 |
| `/install-minesweeper` | `/data/local/tmp/minesweeper-hapbuild/install_initial_minesweeper.sh` | `minesweeper-hapbuild/minesweeper-signed.hap` | `com.openclaw.minesweeper` |
| `/reset-calculator` | `/data/local/tmp/calculator-hapbuild/restore_calculator_project.sh` | `calculator-hapbuild/backups/initial/project.tar` | 还原计算器 |
| `/install-calculator` | `/data/local/tmp/calculator-hapbuild/install_initial_calculator.sh` | `calculator-hapbuild/calculator-signed.hap` | `com.openclaw.calculator` |
| `/reset-tetris` | `/data/local/tmp/tetris-hapbuild/restore_tetris_project.sh` | `tetris-hapbuild/backups/initial/project.tar` | 还原俄罗斯方块 |
| `/install-tetris` | `/data/local/tmp/tetris-hapbuild/install_initial_tetris.sh` | `tetris-hapbuild/tetris-signed.hap` | `com.openclaw.tetris` |
| `/reset-videoplayer` | `/data/local/tmp/videoplayer-hapbuild/restore_videoplayer_project.sh` | `videoplayer-hapbuild/backups/initial/project.tar` | 还原视频播放器 |
| `/install-videoplayer` | `/data/local/tmp/videoplayer-hapbuild/install_initial_videoplayer.sh` | `videoplayer-hapbuild/videoplayer-signed.hap` | `com.openclaw.videoplayer` |
| `/reset-blank` | `/data/local/tmp/blank-hapbuild/restore_blank_project.sh` | `blank-hapbuild/backups/initial/project.tar` | 还原随心模板 |
| `/install-blank` | `/data/local/tmp/blank-hapbuild/install_initial_blank.sh` | `blank-hapbuild/blank-signed.hap` | `com.openclaw.blankhap` |
| `/blank-list` `/blank-new` `/blank-select` `/blank-clear-all` `/blank-delete` | `blank-hapbuild/blank_{new,select,delete,clear_all}.sh` | `blank-hapbuild/projects/`、`blank-hapbuild/current.txt`、`blank-hapbuild/template/` | 随心副本管理 |
| `/install-hap` `/start-hap` `/uninstall-hap` | （通用） | `/data/local/tmp/entry-signed.hap` 等 | 装/启/卸 |
| `/start-linux-env` | 起 Docker `linux-env` + `autostart_houmo.sh` | `/data/local/bin/dockerc2` | 拉容器 |

> ⚠️ 易踩坑：`oh61-hapbuild` 与 `advanced-hapbuild` 的基线是 **`backups/course-initial/project.tar`**；其余 5 个功能 HAP 是 **`backups/initial/project.tar`**。子目录名不同，别摆错。

---

## 三、每个 HAP 的板端目录结构（换板逐个对齐）

通用模板（除随心外）：
```
/data/local/tmp/<x>-hapbuild/
├── project/                         可编辑工程（AI 改这里）
├── backups/<initial|course-initial>/project.tar   重置基线【板端产物】
├── <slug>-signed.hap                预编译签名包【板端产物】
├── restore_<x>_project.sh           【仓库】
└── install_initial_<x>.sh           【仓库】
```

各目录与对应包名 / 签名包：

| 目录 | 基线子目录 | 签名包文件 | 包名 |
|---|---|---|---|
| `oh61-hapbuild/` | `course-initial` | `/data/local/tmp/entry-signed.hap`（主HAP，**目录外**） | `com.openclaw.learnhap` |
| `advanced-hapbuild/` | `course-initial` | `schedule-initial-signed.hap` | `com.openclaw.schedulehap.lite` / `.schedulehap` |
| `minesweeper-hapbuild/` | `initial` | `minesweeper-signed.hap` | `com.openclaw.minesweeper` |
| `calculator-hapbuild/` | `initial` | `calculator-signed.hap` | `com.openclaw.calculator` |
| `tetris-hapbuild/` | `initial` | `tetris-signed.hap` | `com.openclaw.tetris` |
| `videoplayer-hapbuild/` | `initial` | `videoplayer-signed.hap` | `com.openclaw.videoplayer` |
| `blank-hapbuild/` | `initial` | `blank-signed.hap` | `com.openclaw.blankhap` |

随心(blank) 额外：`projects/<副本名>/`、`current.txt`、`template/`、`blank_new.sh`、`blank_select.sh`、`blank_delete.sh`、`blank_clear_all.sh`。

---

## 四、构建链（板端在线编译/AI 改码才需要）

- `/data/local/tmp/assemble_deploy.sh`【仓库】
- `/data/local/bin/dockerc2`（Docker 客户端）【板端】+ 容器 `linux-env`【板端镜像】
- 容器内（`linux-env` 内部，不在板端文件系统直接可见）：
  - `/root/HAP-BuildKit/ohos_sdk/23/toolchains/lib/hap-sign-tool.jar`、`.../restool`
  - `/root/HAP-BuildKit/ohos_sdk`（OHOS_SDK_HOME）
  - `/root/HAP-BuildKit/project`（基线工程，首次构建复制用）
  - 编译产物：`/root/HAP-BuildKit/<...>-project/entry/build/.../entry-default-unsigned.hap`

---

## 五、签名 / 证书 / 配置（必需）

- `/data/local/tmp/signature/`【仓库 `signature/`】必需三件：`HelloHap_debug_profile.json`、`OpenHarmony.p12`、`OpenHarmonyAppChain.pem`（其余 p7b/pem 一并拷）
- `/data/local/tmp/proxy-cert.pem`、`/data/local/tmp/proxy-key.pem`（https 代理用）【仓库】
- `/data/local/tmp/.openclaw/openclaw.json`（gateway token + 白名单）【板端】

---

## 六、AI 人格 / 记忆（gateway workspace）

- 【仓库】`openclaw/IDENTITY.md`、`openclaw/agents/<restore|teaching|minesweeper|calculator|tetris|videoplayer|blank>/{SOUL.md,IDENTITY.md}` → 部署到网关 agents 目录
- 【板端运行态】会话：`/data/local/tmp/.openclaw/agents/main/sessions/`
- 【板端】Level1 记忆：`/data/local/tmp/.openclaw/workspace/memory/oh61-level1-compile.md`(+`-qa.md`)

---

## 七、系统层

- SELinux：`setenforce 0`（开机脚本里，修 WebView 白屏）
- HAP 内明文白名单：`entry/src/main/resources/base/profile/network_config.json`（放行 `http://localhost:18800`）
- 设备根证书：仓库 `ae2f22a0.0`（如系统信任库需要）

---

## 换板核对：用附带的 `check_board_layout.sh`

把 `check_board_layout.sh` push 到新板 `/data/local/tmp/`，`sh check_board_layout.sh` 一次性检查上面所有关键路径是否就位，缺哪个直接列出来，避免运行时才报“找不到”。
