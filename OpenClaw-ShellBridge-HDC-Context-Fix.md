# OpenClaw shell-bridge 模拟 hdc shell 环境修复文档

## 背景

第三关部署流程通过板端客户端触发 HAP 卸载、安装和启动：

```sh
/data/local/tmp/node /data/local/tmp/openclaw-uninstall-hap-client.js
/data/local/tmp/node /data/local/tmp/openclaw-install-hap-client.js
```

两个客户端本身不直接执行安装逻辑，而是访问板端 `shell-bridge` HTTP 接口：

- `http://127.0.0.1:7681/uninstall-hap`
- `http://127.0.0.1:7681/install-hap`

真正执行 `bm` / `aa` 命令的是：

```text
/data/local/tmp/shell-bridge.js
```

原始实现中，`shell-bridge.js` 直接调用：

```sh
/bin/bm uninstall -n com.openclaw.studenthap
/bin/bm install -p /data/local/tmp/entry-signed.hap
/bin/aa start -a EntryAbility -b com.openclaw.studenthap -m entry
```

## 故障现象

通过第三关脚本或 `shell-bridge` 接口执行时，卸载和安装失败：

```text
$ bm uninstall -n com.openclaw.studenthap
error: failed to uninstall bundle.
code:9568384
error: uninstall permission denied.
```

```text
$ bm install -p /data/local/tmp/entry-signed.hap
error: failed to install bundle.
code:9568266
error: install permission denied.
```

随后启动也失败：

```text
$ aa start -a EntryAbility -b com.openclaw.studenthap -m entry
error: failed to start ability.
Error Code:10103601  Error Message:The specified bundleName does not exist.
```

`aa start` 失败不是根因，而是因为前面的 `bm install` 没有成功，系统中不存在该 bundle。

## 对比验证

在 `hdc shell` 中手工执行相同安装命令可以成功：

```sh
bm install -p /data/local/tmp/entry-signed.hap
```

结果：

```text
install bundle successfully.
```

因此问题不是：

- HAP 文件不存在
- bundleName 错误
- Docker 时间错误
- `bm` 参数错误

真正差异在于：`hdc shell` 和 `shell-bridge.js` 的进程上下文不同。

## 根因

`hdc shell` 中的运行身份为：

```text
uid=0(root) gid=0(root) groups=0(root),1006(file_manager),1007(log),2000(shell),3009(readproc) context=u:r:su:s0
```

原始 `shell-bridge.js` Node 进程为：

```text
Uid:    0 0 0 0
Gid:    0 0 0 0
Groups:
context=u:r:su:s0
```

两者虽然都是 `root`，SELinux context 也都是 `u:r:su:s0`，但原始 `shell-bridge.js` 缺少 `hdc shell` 的 supplementary groups：

```text
0, 1006, 1007, 2000, 3009
```

BundleManager 对 `bm install` / `bm uninstall` 的权限判断不仅依赖 uid，还会受到调用进程组信息影响。缺少 `shell`、`file_manager` 等附加组时，`bm` 会返回：

- `install permission denied`
- `uninstall permission denied`

## 修复方案

在 `/data/local/tmp/shell-bridge.js` 启动时，主动设置 supplementary groups，模拟 `hdc shell` 的运行环境。

新增逻辑：

```javascript
const HDC_SHELL_GROUPS = [0, 1006, 1007, 2000, 3009];

function ensureHdcShellLikeContext() {
  try {
    if (typeof process.setgroups === 'function') {
      process.setgroups(HDC_SHELL_GROUPS);
      console.log('[shell-bridge] supplementary groups set to hdc-shell compatible set: ' + HDC_SHELL_GROUPS.join(','));
    }
  } catch (e) {
    console.error('[shell-bridge] failed to set supplementary groups: ' + e.message);
  }

  process.env.PATH = '/usr/local/bin:/bin:/usr/bin:/system/bin:/vendor/bin:/data/local/bin';
  process.env.HOME = '/data/local/tmp';
}

ensureHdcShellLikeContext();
```

放置位置：

- `require(...)` 和常量定义之后
- HTTP server 启动之前
- 所有 `bm` / `aa` 子进程调用之前

这样由 `shell-bridge.js` 启动的子进程会继承与 `hdc shell` 接近的 group 环境。

## 修改文件

板端文件：

```text
/data/local/tmp/shell-bridge.js
```

主机备份文件：

```text
D:\DevEcoProjects\shell-bridge.js.backup
```

主机补丁文件：

```text
D:\DevEcoProjects\shell-bridge.js.patched
```

## 重启 shell-bridge

修改后需要重启 `shell-bridge` 服务，使新的 Node 进程重新设置 groups。

可使用：

```sh
killall node 2>/dev/null || true
/system/bin/openclaw-ctl start
```

如果不希望杀掉所有 Node 进程，应精确定位 `/data/local/tmp/shell-bridge.js` 对应 PID 后只重启该进程。

## 修复后验证

修复后的 `shell-bridge` Node 进程状态：

```text
Groups: 0 1006 1007 2000 3009
Uid:    0 0 0 0
Gid:    0 0 0 0
```

重新执行第三关客户端：

```sh
/data/local/tmp/node /data/local/tmp/openclaw-uninstall-hap-client.js
/data/local/tmp/node /data/local/tmp/openclaw-install-hap-client.js
```

验证结果：

```text
$ bm uninstall -n com.openclaw.studenthap
uninstall bundle successfully.

$ bm install -p /data/local/tmp/entry-signed.hap
install bundle successfully.

$ aa start -a EntryAbility -b com.openclaw.studenthap -m entry
start ability successfully.
```

## 进一步验证：重启后的新发现

重启设备后，`shell-bridge.js` 仍然会随 OpenClaw 自启，且补丁代码也确实执行了：

```text
[shell-bridge] supplementary groups set to hdc-shell compatible set: 0,1006,1007,2000,3009
[shell-bridge] listening on :7681 (HTTP only)
```

当前监听 `7681` 的进程上下文也已经具备与 `hdc shell` 相同的 supplementary groups：

```text
Name:   node
Uid:    0 0 0 0
Gid:    0 0 0 0
Groups: 0 1006 1007 2000 3009
```

但是，通过开机自启链路启动的 `shell-bridge.js` 调用 `/install-hap` 时，`bm install` / `bm uninstall` 仍可能返回：

```text
install permission denied
uninstall permission denied
```

随后做了两个关键对比验证。

### 1. 直接在 hdc shell 中执行 bm 成功

```sh
bm uninstall -n com.openclaw.studenthap
bm install -p /data/local/tmp/entry-signed.hap
aa start -a EntryAbility -b com.openclaw.studenthap -m entry
```

结果：

```text
uninstall bundle successfully.
install bundle successfully.
start ability successfully.
```

### 2. 从 hdc shell 手动启动同一个 shell-bridge.js 后成功

杀掉开机链路启动的 `shell-bridge` 后，直接从当前 `hdc shell` 启动同一个脚本：

```sh
HOME=/data/local/tmp \
PATH=/usr/local/bin:/bin:/usr/bin:/system/bin:/vendor/bin:/data/local/bin \
nohup /data/local/tmp/node /data/local/tmp/shell-bridge.js \
  >> /data/local/tmp/.openclaw/shell-bridge.log 2>&1 &
```

然后再执行第三关客户端：

```sh
/data/local/tmp/node /data/local/tmp/openclaw-uninstall-hap-client.js
/data/local/tmp/node /data/local/tmp/openclaw-install-hap-client.js
```

结果：

```text
$ bm uninstall -n com.openclaw.studenthap
uninstall bundle successfully.

$ bm install -p /data/local/tmp/entry-signed.hap
install bundle successfully.

$ aa start -a EntryAbility -b com.openclaw.studenthap -m entry
start ability successfully.
```

## 更新后的根因判断

最初判断为 `shell-bridge.js` 缺少 supplementary groups，这只解释了第一层差异，但重启后的验证表明：

```text
仅补齐 groups 还不足以完全模拟 hdc shell。
```

更准确的根因是：

```text
BundleManager 对 install / uninstall 的权限判断不仅依赖 uid、gid、supplementary groups 和 SELinux context，还依赖 hdc shell 启动链路带来的进程上下文。
```

也就是说：

- 从 `hdc shell` 启动的进程可以执行 `bm install` / `bm uninstall`
- 从 `/system/bin/openclaw-boot.sh` 开机自启链路启动的 `shell-bridge.js` 即使补齐 groups，仍可能被 BundleManager 拒绝
- 同一个 `/data/local/tmp/shell-bridge.js`，由 `hdc shell` 手动启动后，请求 `/install-hap` 可以成功

因此真正的关键差异不是 JS 安装逻辑，而是 `shell-bridge.js` 的启动来源：

```text
hdc shell 链路启动：可安装
开机自启 / OpenClaw gateway 链路启动：可能被 bm 拒绝
```

## 当前可用临时方案

在需要执行第三关部署前，手动从 `hdc shell` 重启 `shell-bridge.js`：

```sh
# 先杀掉监听 7681 的旧 shell-bridge 进程
kill <shell-bridge-pid>

# 从 hdc shell 重新启动 shell-bridge
HOME=/data/local/tmp \
PATH=/usr/local/bin:/bin:/usr/bin:/system/bin:/vendor/bin:/data/local/bin \
nohup /data/local/tmp/node /data/local/tmp/shell-bridge.js \
  >> /data/local/tmp/.openclaw/shell-bridge.log 2>&1 &
```

随后第三关客户端可以正常完成：

```sh
/data/local/tmp/node /data/local/tmp/openclaw-uninstall-hap-client.js
/data/local/tmp/node /data/local/tmp/openclaw-install-hap-client.js
```

## 最终结论

第三关部署失败的根因应更新为：

```text
shell-bridge.js 由开机自启 / OpenClaw gateway 链路启动时，其进程来源不等价于 hdc shell。即使手动补齐 hdc shell 的 supplementary groups，BundleManager 仍可能基于更深层的调用来源 / 会话上下文拒绝 bm install / uninstall。
```

当前已确认：

```text
同一个 shell-bridge.js，如果从 hdc shell 手动启动，则 /uninstall-hap、/install-hap 和 aa start 均可成功。
```

## 进一步验证：Xshell 环境与 hdc shell 的差异

在板端 Xshell 自启动环境中采集到的上下文，与 `hdc shell` 明显不同：

### hdc shell

```text
uid=0(root) gid=0(root) groups=0(root),1006(file_manager),1007(log),2000(shell),3009(readproc) context=u:r:su:s0
```

```text
OHOS_SOCKET_hdcd=9
HOME=/
PATH=/usr/local/bin:/bin:/usr/bin
```

### Xshell

```text
uid=0(root) gid=2000(shell) groups=2000(shell),1007(log),3009(readproc) context=u:r:console:s0
```

```text
HOME=/
PATH=/usr/local/bin:/bin:/usr/bin
```

差异重点：

- SELinux context 不同：`u:r:su:s0` vs `u:r:console:s0`
- gid 不同：`0(root)` vs `2000(shell)`
- supplementary groups 不同：`hdc shell` 具备 `0` 和 `1006(file_manager)`，Xshell 不具备
- `OHOS_SOCKET_hdcd` 只在 `hdc shell` 中出现，暗示 hdc 可能携带专用会话 / 通道上下文

在 Xshell 下手动启动 `shell-bridge.js` 后，日志显示服务可正常监听 7681 并完成 autostart：

```text
[shell-bridge] supplementary groups set to hdc-shell compatible set: 0,1006,1007,2000,3009
[shell-bridge] listening on :7681 (HTTP only)
[shell-bridge] Waiting for linux-env to be running before executing autostart...
[shell-bridge] linux-env is running! Triggering autostart script: /data/local/tmp/autostart_houmo.sh
[shell-bridge] Startup script completed with code: 0
```

但这并不等于 `bm install/uninstall` 权限已经通过，说明问题不只是 `PATH/HOME/groups` 这类表层环境变量，而更可能与进程来源、会话上下文、SELinux 域和 hdc 专用通道相关。

## 进一步修复方向

后续彻底修复方向应从“修改 installAndStart 命令”转为“修改 shell-bridge 的启动链路”，让它尽可能由等价于 `hdc shell` 的上下文拉起，而不是由普通开机自启链路直接拉起。

如果无法让 `shell-bridge.js` 本身获得等价上下文，可考虑引入一个独立的“hdc 兼容执行入口”作为中继：

- `shell-bridge.js` 仅负责接收 HTTP 请求
- 敏感命令统一转发给一个独立执行进程
- 由该执行进程承担 `bm uninstall` / `bm install` / `aa start`

这样可以把权限敏感逻辑从普通 `console:s0` 链路中剥离出来，减少上下文差异对部署流程的影响。
