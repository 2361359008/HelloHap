# OpenClaw 导学 HAP — 固件打包文件 / 服务脚本清单

> 适用：RK3588 + OpenHarmony 5.1（API 18）。板端工作根目录统一在 `/data/local/tmp/`。
> 说明：本仓库（HelloHap）只含**脚本 / 源码 / 签名材料 / Agent 人格 / 文档**；
> 板端真正运行的 **node 运行时、OpenClaw 网关 openclaw.mjs、各 `*-signed.hap`、各 `project.tar` 基线、Docker linux-env 镜像** 都不在仓库里（`.gitignore` 忽略 `*.hap`），需另行准备/构建后一起打进固件。

---

## 0. 端口与进程总览

| 服务 | 进程 / 文件 | 端口 | 作用 |
|---|---|---|---|
| Shell-Bridge | `/data/local/tmp/shell-bridge.js`（源=仓库 `shell-bridge.mjs`） | **7681**（HTTP+WS） | 终端 shell 后端、`/token`、各 HAP 还原/安装/列目录/读文件路由 |
| OpenClaw Gateway | `/data/local/tmp/openclaw/openclaw.mjs` | **18800** | Web UI / AI 对话后端 |
| HTTPS 反代（可选） | `/data/local/tmp/https-proxy.js` | **18801→18800** | 给强制 https 的浏览器用 |
| Node 运行时 | `/data/local/tmp/node` | — | 跑上面三个 .js/.mjs |

首页底部状态灯对应：`Shell-Bridge 在线(7681)`、`OpenClaw Gateway 运行中(18800)`。

---

## 1. 板端常驻服务 + 开机自启（必须）

- `/data/local/tmp/node` — Node.js 运行时（二进制，**非仓库**）
- `/data/local/tmp/openclaw/openclaw.mjs` — OpenClaw 网关（**非仓库**）
- `/data/local/tmp/openclaw/node_modules/.pnpm/ws@8.19.0/node_modules` — ws 模块（**非仓库**）
- `/data/local/tmp/shell-bridge.js` — **仓库 `shell-bridge.mjs`**（部署时改名为 .js）
- `/data/local/tmp/https-proxy.js` — **仓库 `https-proxy.js`**（可选）
  - 证书：`/data/local/tmp/proxy-cert.pem`、`/data/local/tmp/proxy-key.pem`（仓库 `proxy-cert.pem` / `proxy-key.pem`，另有 `proxy-cert.der`）
- 开机自启：
  - `/system/etc/init/openclaw.cfg` — init 服务配置（boot 触发）
  - `/data/local/tmp/bin/openclaw-boot.sh` — 启动脚本（setenforce 0 + 起 shell-bridge + 起 gateway）
- OpenClaw 配置（**勿误删**）：`/data/local/tmp/.openclaw/openclaw.json`（含 token、`allowInsecureAuth` 白名单）

> 注意：主导学 HAP 包名仓库里用 `com.openclaw.studenthap`（`shell-bridge.mjs` 默认），迁移文档示例用 `com.openclaw.hellohap`，**打包前以实际签名包为准统一**。

---

## 2. 主导学 HAP（首页三入口的壳）

- 预编译签名包：`/data/local/tmp/entry-signed.hap`（**非仓库**，由 `oh61-hapbuild` 构建）
- 工程目录：`/data/local/tmp/oh61-hapbuild/`
  - `project/`（基础课/主课程可编辑工程）
  - `restore_course_project.sh`（仓库同名）
  - `build_sign_install_run.sh`（仓库同名，板端主 shell 跑，调 Docker 编译+签名）
  - 源码即本仓库 `entry/` + `AppScope/` + `build-profile.json5` + `module.json5` + 资源

---

## 3. 各 HAP 的板端构建目录（统一结构）

每个目录在板上需具备：`project/`（可编辑工程）、`backups/initial/project.tar`（重置基线，**非仓库**）、`<slug>-signed.hap`（预编译包，**非仓库**）、以及下列脚本（**均在仓库根目录**，部署时放进对应 `*-hapbuild/`）。

| 多元开发/课程项 | 板端目录 | 还原脚本 | 安装脚本 | 预编译包 |
|---|---|---|---|---|
| 基础课/主课程 | `oh61-hapbuild/` | `restore_course_project.sh` | （走 build_sign_install_run.sh） | `entry-signed.hap` |
| 高级关卡(advanced) | `advanced-hapbuild/` | `restore_advanced_project.sh` | `install_initial_advanced.sh` | `advanced-signed.hap` |
| 教学之路(teaching) | `advanced-hapbuild/` | （同上工程） | `install_initial_teaching.sh` | 起整包 `schedulehap` |
| 扫雷 | `minesweeper-hapbuild/` | `restore_minesweeper_project.sh` | `install_initial_minesweeper.sh` | `minesweeper-signed.hap` |
| 计算器 | `calculator-hapbuild/` | `restore_calculator_project.sh` | `install_initial_calculator.sh` | `calculator-signed.hap` |
| 俄罗斯方块 | `tetris-hapbuild/` | `restore_tetris_project.sh` | `install_initial_tetris.sh` | `tetris-signed.hap` |
| 视频播放器 | `videoplayer-hapbuild/` | `restore_videoplayer_project.sh` | `install_initial_videoplayer.sh` | `videoplayer-signed.hap` |
| 随心/空白 | `blank-hapbuild/` | `restore_blank_project.sh` | `install_initial_blank.sh` | `blank-signed.hap` |

随心(blank) 额外（仓库根目录脚本，放进 `blank-hapbuild/`）：
- `blank_new.sh`、`blank_select.sh`、`blank_delete.sh`、`blank_clear_all.sh`
- 运行态目录：`blank-hapbuild/projects/<副本名>/`、`blank-hapbuild/current.txt`、`blank-hapbuild/template/`

各 HAP 工程源码（编译用，仓库内）：
- `examples/minesweeper-hap/`、`examples/calculator-hap/`、`examples/tetris-hap/`、`examples/video-player-hap/`、`examples/blank-hap/`
  - 各含 `entry/`、`AppScope/`、`build-profile.json5`、`oh-package.json5`、`hvigorfile.ts`、`build_<name>.sh`、`README.md`
  - 视频内置片源：`examples/video-player-hap/entry/src/main/resources/rawfile/ai-mini-pc-fast-intro-typewriter.mp4`

---

## 4. 多元开发万能构建链（板端编译/签名所需）

- `/data/local/tmp/assemble_deploy.sh`（仓库同名）— 任意工程「编译→签名→安装→启动」
- Docker 客户端 `/data/local/bin/dockerc2` + 容器 `linux-env`（**非仓库**），容器内含：
  - `/root/HAP-BuildKit/ohos_sdk/23`（含 `hap-sign-tool.jar`、`OpenHarmonyProfileRelease.pem`）
  - hvigor、node、python3、基线 `/root/HAP-BuildKit/project`

---

## 5. 签名材料 `/data/local/tmp/signature/`（仓库 `signature/`）

必需 3 件（构建脚本强校验）：
- `HelloHap_debug_profile.json`、`OpenHarmony.p12`、`OpenHarmonyAppChain.pem`

随附：
- `HelloHap_debug.p7b`、`HelloHap_release.p7b`、`HelloHap_release_profile.json`
- `OpenHarmonyApplication.pem`、`OpenHarmonyCA.pem`、`deveco_debug_profile_extracted.json`
- 仓库根另有设备根证书 `ae2f22a0.0`

---

## 6. OpenClaw Agent 人格 / 记忆（AI 对话身份）

- 仓库 `openclaw/IDENTITY.md` + `openclaw/agents/<name>/{SOUL.md,IDENTITY.md}`
  - name ∈ `restore / teaching / minesweeper / calculator / tetris / videoplayer / blank`
  - 部署到网关工作区的 agents 目录
- 会话存储（运行态，清理时只删这里）：`/data/local/tmp/.openclaw/agents/main/sessions/`
- Level1 记忆：`/data/local/tmp/.openclaw/workspace/memory/oh61-level1-compile.md`（+ `-qa.md`）

---

## 7. 提示词 / 内容脚本（仓库内，随工程或网关）

- `freedev-prompts.txt`（自由开发提示词，LF）
- 关卡文案：`oh61-level1-compile.md`、`oh61-level2-sign(.md/-qa.md)`、`oh61-level3-deploy(.md/-qa.md)`

---

## 8. 系统层（固件镜像层面）

- SELinux：开机脚本里 `setenforce 0`（修 WebView 白屏）
- 网络明文白名单：HAP 内 `entry/src/main/resources/base/profile/network_config.json`（允许 `http://localhost:18800`）
- PC 调试端口转发（非固件内容）：`hdc fport tcp:7681 tcp:7681`、`hdc fport tcp:18800 tcp:18800`

---

## 打包速查（最小可运行集）

固件内务必包含：
1. `node` 运行时 + `openclaw/`（openclaw.mjs + ws） + `shell-bridge.js`(+可选 https-proxy.js+证书)
2. 开机自启：`/system/etc/init/openclaw.cfg` + `/data/local/tmp/bin/openclaw-boot.sh`
3. 配置：`/data/local/tmp/.openclaw/openclaw.json`
4. 主 HAP `entry-signed.hap` + 7 个 `*-hapbuild/`（各含 project/、project.tar、`*-signed.hap`、restore/install 脚本）
5. `assemble_deploy.sh` + Docker `linux-env`（如需板端在线编译/AI 改码）
6. `signature/`（≥3 件必需）
7. `openclaw/agents/*`（AI 人格）+ memory
