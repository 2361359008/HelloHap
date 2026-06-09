# 视频播放器 HAP 工程

「多元开发」里「视频播放器 HAP 自由开发」对应的 OpenHarmony ArkTS HAP 工程模板。
基于 ArkUI `Video` 组件实现一个最小可用的播放器（播放/暂停/停止、进度时间、URL 加载），
从这里开始和 AI 助手一起把它扩展成你想要的播放器（播放列表、进度拖动、倍速、全屏、本地文件、字幕……）。

- 包名：`com.openclaw.videoplayer`
- API：OpenHarmony 23（Stage 模型）
- 入口：`entry/src/main/ets/pages/Index.ets`
- 权限：`ohos.permission.INTERNET`（播放网络视频需要；内置 rawfile 播放可不依赖网络）
- 内置片源：`entry/src/main/resources/rawfile/welcome.mp4`（仓库 `videos/openharmony-hap-welcome-updated.mp4`），首页默认 `src = $rawfile('welcome.mp4')`，一进去就播放
- 也可在界面输入框粘贴 http/https 网络地址临时切换，「内置视频」按钮一键切回内置片源

## 构建（在板端 linux-env 容器内编译 + 签名 + 安装 + 启动）

```sh
sh build_videoplayer.sh
```

脚本与扫雷 `build_minesweeper.sh` 同结构，仅路径/包名不同：产物 `videoplayer-signed.hap`。

## 与多元开发对接（板端约定）

- 可编辑工程：`/data/local/tmp/videoplayer-hapbuild/project`
- 初始基线：`/data/local/tmp/videoplayer-hapbuild/backups/initial/project.tar`
- 初始签名包：`/data/local/tmp/videoplayer-hapbuild/videoplayer-signed.hap`
- shell-bridge 路由：`/reset-videoplayer`（还原基线）、`/install-videoplayer`（装初始签名 HAP）
- OpenClaw agent：`videoplayer`
