# 打包文件清单 & 所有 HAP 写死路径清单

> 本文档汇总两件事：
> 1. **打包/部署整个项目所需的文件清单**（仓库里哪些文件需要推送到开发板、推送到哪里）。
> 2. **所有 HAP 在脚本 / 源码里写死（hardcoded）的文件位置清单**（设备端 `/data/local/tmp/...` 路径、包名、构建容器路径等）。
>
> 信息来源：`shell-bridge.mjs`、`shell_bridge.cfg`、`assemble_deploy.sh`、`build_sign_install_run.sh`、`install_initial_*.sh`、`restore_*.sh`、`examples/*/build_*.sh`、`RK3588-OpenHarmony5.1-HAP迁移部署文档.md`。
>
> 维护提醒：以上任一脚本里的路径 / 包名变化时，请同步更新本文档。

---

## 1. 关键约定（先读这里）

- **设备端工作根目录**：`/data/local/tmp`（脚本里多数 `#!/system/bin/sh`，运行时 `HOME=/data/local/tmp`）。
- **每个 HAP 一个独立的构建目录** `*-hapbuild/`，结构统一：
  - `project/`：可编辑的 HAP 工程源码（编译输入）。
  - `backups/.../project.tar`：还原用的原始基线工程包。
  - `<slug>-signed.hap`：已签名的安装产物（`.gitignore` 忽略 `*.hap`，**不入库**，由构建产出/推送）。
  - `restore_*_project.sh` / `install_initial_*.sh`：还原与初装脚本。
- **签名产物不入库**：`.gitignore` 忽略 `*.hap`、`*.har`、`*.hsp`、`build/`、`node_modules/`、`oh_modules/`。
- **网络端口**：
  - Shell Bridge（HTTP）：`7681`（`shell-bridge.mjs`）。
  - OpenClaw Gateway（HTTP/WS）：`18800`。
  - HTTPS 代理（`https-proxy.js`）：监听 `18801` → 转发 `18800`。

---

## 2. 打包 / 部署整个项目所需文件清单

### 2.1 仓库内需要部署的源文件

| 仓库文件/目录 | 作用 | 部署目标（设备端） |
|---|---|---|
| `entry/` | 主 HAP（基础课/高级课）工程源码 | `/data/local/tmp/oh61-hapbuild/project`、`/data/local/tmp/advanced-hapbuild/project` |
| `examples/blank-hap/` | 随心（空白）示例 HAP | `/data/local/tmp/blank-hapbuild/project` |
| `examples/calculator-hap/` | 计算器示例 HAP | `/data/local/tmp/calculator-hapbuild/project` |
| `examples/minesweeper-hap/` | 扫雷示例 HAP | `/data/local/tmp/minesweeper-hapbuild/project` |
| `examples/tetris-hap/` | 俄罗斯方块示例 HAP | `/data/local/tmp/tetris-hapbuild/project` |
| `examples/video-player-hap/` | 视频播放器示例 HAP | `/data/local/tmp/videoplayer-hapbuild/project` |
| `shell-bridge.mjs` | 板端 Node 服务（发 token / 跑脚本 / 暴露 reset 接口） | `/data/local/tmp/shell-bridge.js`（**注意改名为 `.js`**） |
| `shell_bridge.cfg` | 设备 init 服务配置（`start-mode: boot`，开机自启 shell-bridge） | 设备 init 服务目录 |
| `https-proxy.js` | 给 Gateway（18800）加一层 HTTPS（18801） | `/data/local/tmp`（按需） |
| `proxy-cert.pem` / `proxy-cert.der` / `proxy-key.pem` | HTTPS 代理证书/私钥 | 随 `https-proxy.js` 部署 |
| `assemble_deploy.sh` | 通用「编译→签名→安装→启动」脚本（任意工程目录） | `/data/local/tmp/assemble_deploy.sh` |
| `build_sign_install_run.sh` | 基础课流程脚本 | `/data/local/tmp/oh61-hapbuild/` |
| `build_advanced_with_env.sh` | 高级课「编译/签名/安装/启动」流程脚本 | `/data/local/tmp/advanced-hapbuild/` |
| `restore_*_project.sh` | 各 HAP 工程还原脚本 | 各对应 `*-hapbuild/` |
| `install_initial_*.sh` | 各 HAP 初装/启动脚本 | 各对应 `*-hapbuild/`（advanced 相关放 `advanced-hapbuild/`） |
| `blank_new.sh` / `blank_select.sh` / `blank_delete.sh` / `blank_clear_all.sh` | 随心多副本工程管理 | `/data/local/tmp/blank-hapbuild/` |
| `examples/*/build_*.sh` | 各示例 HAP 的独立构建脚本 | 各对应 `*-hapbuild/` |
| `freedev-prompts.txt` | 自由开发提示词稿 | 部署时拷到日志工作根目录 |
| `openclaw/` | OpenClaw 多 agent 身份文件（`IDENTITY.md` / `SOUL.md`） | OpenClaw 各 agent 工作区 |
| `signature/` | 签名材料（见 2.3） | `/data/local/tmp/signature` |

### 2.2 设备端预置运行时（非本仓库产物，需另行准备）

来自 `RK3588-OpenHarmony5.1-HAP迁移部署文档.md`：

| 设备端路径 | 说明 |
|---|---|
| `/data/local/tmp/node` | Node.js 运行时 |
| `/data/local/tmp/openclaw/openclaw.mjs` | OpenClaw Gateway 主程序 |
| `/data/local/tmp/shell-bridge.js` | Shell Bridge（源 = 仓库 `shell-bridge.mjs`） |
| `/data/local/tmp/openclaw/node_modules/.pnpm/ws@8.19.0/node_modules` | `ws` 模块（Gateway / Bridge 依赖） |
| `/data/local/tmp/.openclaw/openclaw.json` | OpenClaw 配置（含 token） |
| `/data/local/tmp/.openclaw/workspace/memory/` | OpenClaw 记忆工作区 |
| `/data/local/tmp/bin/openclaw-boot.sh` | 开机自启脚本（init 调用） |

### 2.3 签名材料（`signature/`）

`assemble_deploy.sh` 强制要求这三个文件（缺一即失败）：

- `signature/HelloHap_debug_profile.json`
- `signature/OpenHarmony.p12`
- `signature/OpenHarmonyAppChain.pem`

目录内其它文件：`HelloHap_debug.p7b`、`HelloHap_release.p7b`、`HelloHap_release_profile.json`、`OpenHarmonyApplication.pem`、`OpenHarmonyCA.pem`、`deveco_debug_profile_extracted.json`。设备端副本位置：`/data/local/tmp/signature`。

---

## 3. 所有 HAP 写死路径清单

### 3.1 各 HAP 一览表

| HAP（slug） | 包名 bundleName | 工程目录 | 已签名产物 | 还原脚本 | 初装脚本 | 还原基线包 |
|---|---|---|---|---|---|---|
| 基础课 course | `com.openclaw.learnhap`（主工程 `entry/`） | `/data/local/tmp/oh61-hapbuild/project` | `/data/local/tmp/entry-signed.hap` | `oh61-hapbuild/restore_course_project.sh` | （走 `build_sign_install_run.sh`） | `oh61-hapbuild/backups/course-initial/project.tar` |
| 高级课 advanced | `com.openclaw.schedulehap.lite`（初装）/ `com.openclaw.schedulehap`（教学） | `/data/local/tmp/advanced-hapbuild/project` | `/data/local/tmp/advanced-hapbuild/schedule-initial-signed.hap` | `advanced-hapbuild/restore_advanced_project.sh` | `advanced-hapbuild/install_initial_advanced.sh`、`install_initial_teaching.sh` | `advanced-hapbuild/backups/course-initial/project.tar` |
| 扫雷 minesweeper | `com.openclaw.minesweeper` | `/data/local/tmp/minesweeper-hapbuild/project` | `/data/local/tmp/minesweeper-hapbuild/minesweeper-signed.hap` | `minesweeper-hapbuild/restore_minesweeper_project.sh` | `minesweeper-hapbuild/install_initial_minesweeper.sh` | `minesweeper-hapbuild/backups/initial/project.tar` |
| 随心 blank | `com.openclaw.blankhap` | `/data/local/tmp/blank-hapbuild/project`（+ `projects/`） | `/data/local/tmp/blank-hapbuild/blank-signed.hap` | `blank-hapbuild/restore_blank_project.sh` | `blank-hapbuild/install_initial_blank.sh` | `blank-hapbuild/backups/initial/project.tar` |
| 视频 videoplayer | `com.openclaw.videoplayer` | `/data/local/tmp/videoplayer-hapbuild/project` | `/data/local/tmp/videoplayer-hapbuild/videoplayer-signed.hap` | `videoplayer-hapbuild/restore_videoplayer_project.sh` | `videoplayer-hapbuild/install_initial_videoplayer.sh` | `videoplayer-hapbuild/backups/initial/project.tar` |
| 计算器 calculator | `com.openclaw.calculator` | `/data/local/tmp/calculator-hapbuild/project` | `/data/local/tmp/calculator-hapbuild/calculator-signed.hap` | `calculator-hapbuild/restore_calculator_project.sh` | `calculator-hapbuild/install_initial_calculator.sh` | `calculator-hapbuild/backups/initial/project.tar` |
| 俄罗斯方块 tetris | `com.openclaw.tetris` | `/data/local/tmp/tetris-hapbuild/project` | `/data/local/tmp/tetris-hapbuild/tetris-signed.hap` | `tetris-hapbuild/restore_tetris_project.sh` | `tetris-hapbuild/install_initial_tetris.sh` | `tetris-hapbuild/backups/initial/project.tar` |

启动统一为：`aa start -a EntryAbility -b <bundleName> -m entry`。

### 3.2 `shell-bridge.mjs` 顶部写死常量

| 常量 | 值 |
|---|---|
| `PORT` | `7681` |
| `OPENCLAW_CONFIG` | `/data/local/tmp/.openclaw/openclaw.json` |
| `DEFAULT_HAP` | `/data/local/tmp/entry-signed.hap` |
| `DEFAULT_BUNDLE` | `com.openclaw.studenthap` |
| `DEFAULT_ABILITY` / `DEFAULT_MODULE` | `EntryAbility` / `entry` |
| `COURSE_RESTORE_SCRIPT` | `/data/local/tmp/oh61-hapbuild/restore_course_project.sh` |
| `ADVANCED_RESTORE_SCRIPT` | `/data/local/tmp/advanced-hapbuild/restore_advanced_project.sh` |
| `ADVANCED_INSTALL_INITIAL_SCRIPT` | `/data/local/tmp/advanced-hapbuild/install_initial_advanced.sh` |
| `TEACHING_INSTALL_INITIAL_SCRIPT` | `/data/local/tmp/advanced-hapbuild/install_initial_teaching.sh` |
| `MINESWEEPER_RESTORE_SCRIPT` / `_INSTALL_INITIAL_SCRIPT` | `/data/local/tmp/minesweeper-hapbuild/restore_minesweeper_project.sh` / `install_initial_minesweeper.sh` |
| `BLANK_RESTORE_SCRIPT` / `_INSTALL_INITIAL_SCRIPT` | `/data/local/tmp/blank-hapbuild/restore_blank_project.sh` / `install_initial_blank.sh` |
| `BLANK_ROOT` | `/data/local/tmp/blank-hapbuild` |
| `BLANK_PROJECTS_DIR` / `BLANK_CURRENT_FILE` | `blank-hapbuild/projects` / `blank-hapbuild/current.txt` |
| `BLANK_NEW_SCRIPT` / `BLANK_SELECT_SCRIPT` / `BLANK_DELETE_SCRIPT` / `BLANK_CLEAR_ALL_SCRIPT` | `blank-hapbuild/{blank_new,blank_select,blank_delete,blank_clear_all}.sh` |
| `VIDEOPLAYER_RESTORE_SCRIPT` / `_INSTALL_INITIAL_SCRIPT` | `/data/local/tmp/videoplayer-hapbuild/restore_videoplayer_project.sh` / `install_initial_videoplayer.sh` |
| `CALCULATOR_RESTORE_SCRIPT` / `_INSTALL_INITIAL_SCRIPT` | `/data/local/tmp/calculator-hapbuild/restore_calculator_project.sh` / `install_initial_calculator.sh` |
| `TETRIS_RESTORE_SCRIPT` / `_INSTALL_INITIAL_SCRIPT` | `/data/local/tmp/tetris-hapbuild/restore_tetris_project.sh` / `install_initial_tetris.sh` |

`shell-bridge.mjs` 内的目录白名单：

- `ALLOWED_READ_PREFIXES`：各 `*-hapbuild/project/` + `blank-hapbuild/projects/` + `/data/local/tmp/.openclaw/workspace/memory/`。
- `ALLOWED_LIST_PREFIXES`：`/data/local/tmp/blank-hapbuild/projects/`。
- `ALLOWED_LIST_DIRS`：各 `*-hapbuild/project`。

运行时还写死：`process.env.PATH = /usr/local/bin:/bin:/usr/bin:/system/bin:/vendor/bin:/data/local/bin`、`process.env.HOME = /data/local/tmp`、`/system/bin/sh`、`/data/local/bin/docker`（`unix:///data/docker2/run/docker.sock`）、`/data/local/bin/dockerc2`、`/data/local/tmp/autostart_houmo.sh`。

### 3.3 构建 / 签名工具链写死路径

来自 `assemble_deploy.sh` 与 `examples/*/build_*.sh`：

| 项 | 值 |
|---|---|
| Docker CLI（`DOCKER_CLI`） | `/data/local/bin/dockerc2` |
| 构建容器（`CONTAINER`） | `linux-env` |
| SDK 根（`SDK_ROOT`） | `/root/HAP-BuildKit/ohos_sdk/23` |
| 签名工具（`SIGN_TOOL`） | `$SDK_ROOT/toolchains/lib/hap-sign-tool.jar` |
| Profile 证书（`PROFILE_CERT`） | `$SDK_ROOT/toolchains/lib/OpenHarmonyProfileRelease.pem` |
| 容器内基线工程 | `/root/HAP-BuildKit/project` |
| 容器内工程目录（通用脚本） | `/root/HAP-BuildKit/_<slug>-project`、`/root/HAP-BuildKit/_<slug>-signing` |
| 容器内工程目录（示例脚本） | `/root/HAP-BuildKit/<name>-project`（如 `blank-project`、`calculator-project` …） |
| 容器内编译产物 | `entry/build/default/outputs/default/entry-default-unsigned.hap` → `<slug>-signed.hap` |

`build_sign_install_run.sh`（基础课）写死：`OUT_HAP=/data/local/tmp/entry-signed.hap`、`UNSIGNED_HAP=/data/local/tmp/entry-unsigned.hap`、`DOCKER_CLI=/data/local/bin/dockerc2`、工作目录 `/data/local/tmp/oh61-hapbuild`。

签名材料定位顺序（`assemble_deploy.sh` 的 `locate_signing_dir`）：`$SIGNING_DIR` → `$PROJECT_DIR/signature` → `$PROJECT_DIR/../signature` → `$PROJECT_DIR/../../signature` → `/data/local/tmp/signature`。
