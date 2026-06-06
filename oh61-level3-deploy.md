# 第三关动作记忆：只部署并启动

本文件只用于第三关关卡触发。

OpenClaw 读取后只执行下面这一条命令：

```sh
sh -c '/data/local/tmp/node /data/local/tmp/openclaw-uninstall-hap-client.js; /data/local/tmp/node /data/local/tmp/openclaw-install-hap-client.js'
```

执行完成后，直接根据命令输出向学生汇报第三关部署与启动结果。

说明：`openclaw-install-hap-client.js` 调用的 `/install-hap` 路由内部已经完成安装并拉起应用，不需要再单独调用 `openclaw-start-hap-client.js`。

不要使用 hdc 命令，不要修改源码，不要重新编译，不要重新签名，不要重复启动应用，不要读取第一关或第二关记忆文件。
