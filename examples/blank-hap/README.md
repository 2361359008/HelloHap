# 随心（空白）HAP 工程

多元开发里「随心自由开发」对应的完全空白 OpenHarmony ArkTS HAP 工程模板。
首页只有一行欢迎语，作为从零开发的起点——和 AI 助手一起把你想要的应用搭出来。

- 包名：`com.openclaw.blankhap`
- API：OpenHarmony 23（stage 模型）
- 入口：`entry/src/main/ets/pages/Index.ets`

## 构建（在板端 linux-env 容器内编译 + 签名 + 安装 + 启动）

```sh
sh build_blank.sh
```

脚本与扫雷 `build_minesweeper.sh` 同结构，仅路径/包名不同：产物为 `blank-signed.hap`。

## 与多元开发的对应关系（板端约定）

- 可编辑工程根：`/data/local/tmp/blank-hapbuild/project`
- 初始基线：`/data/local/tmp/blank-hapbuild/backups/initial/project.tar`
- 初始签名包：`/data/local/tmp/blank-hapbuild/blank-signed.hap`
- shell-bridge 路由：`/reset-blank`（还原基线）、`/install-blank`（装初始签名 HAP）
- OpenClaw agent：`blank`
