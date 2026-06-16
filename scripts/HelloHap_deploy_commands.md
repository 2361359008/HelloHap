## 1. 设置本机部署包路径

```powershell
$BASE = "D:\DevEcoProjects\HelloHap\dist\board-migration"
$HAP_TAR = "$BASE\hap.tar.gz"
$OPEN_TAR = "$BASE\open-start.tar.gz"
```

## 2. 上传并执行 HAP 主部署包

```powershell
hdc shell "rm -rf /data/local/tmp/board-migration && mkdir -p /data/local/tmp/board-migration"
hdc file send $HAP_TAR /data/local/tmp/board-migration/hap.tar.gz
hdc shell "cd /data/local/tmp/board-migration && tar -xzf hap.tar.gz"
hdc shell "cd /data/local/tmp/board-migration/hap && chmod 755 deploy_hellohap_all.sh && sh deploy_hellohap_all.sh"
```

如果解压后的入口目录不是 `/data/local/tmp/board-migration/hap`，先找入口脚本：

```powershell
hdc shell "find /data/local/tmp/board-migration -name deploy_hellohap_all.sh"
```

然后进入实际目录执行，例如：

```powershell
hdc shell "cd /data/local/tmp/board-migration/实际目录 && chmod 755 deploy_hellohap_all.sh && sh deploy_hellohap_all.sh"
```

## 3. 上传并执行开机自启动部署包

```powershell
hdc shell "rm -rf /data/local/tmp/open-start && mkdir -p /data/local/tmp/open-start"
hdc file send $OPEN_TAR /data/local/tmp/open-start.tar.gz
hdc shell "tar -xzf /data/local/tmp/open-start.tar.gz -C /data/local/tmp/open-start"
hdc shell "cd /data/local/tmp/open-start && chmod 755 deploy_open_start.sh ensure_board_ready_this_board.sh oh51-hdc-arm64/hdc && sh deploy_open_start.sh"
```

`deploy_open_start.sh` 会自动完成：

```text
1. 安装 /data/local/tmp/ensure_board_ready.sh
2. 启动/确认 Docker daemon
3. 启动/确认 linux-env 容器
4. 把 hdc 和 libusb_shared.so 安装到容器 /root/oh51-hdc-arm64/
5. remount 根分区为可写
6. 备份 /etc/init/nwebspawn.cfg
7. 写入 hellohap_board_ready 开机自启动服务
8. sync
9. reboot
```

执行完 `deploy_open_start.sh` 后，板子会自动重启。
