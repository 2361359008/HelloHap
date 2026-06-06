# 第二关动作记忆：只签名

本文件只用于第二关关卡触发。

OpenClaw 读取后只执行下面这一条命令：

```sh
sh -c 'cd /data/local/tmp/oh61-hapbuild && sh build_sign_install_run.sh --sign-only'
```

执行完成后，直接根据命令输出向学生汇报第二关签名结果。

不要重新编译，不要修改源码，不要安装，不要启动应用，不要读取第一关或第三关记忆文件。
