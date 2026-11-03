# OpenClaw Gateway — Magisk / KernelSU / APatch 模块

在已 root 的 Android 手机上运行 [OpenClaw](https://openclaw.ai) 网关，通过手机浏览器或电脑浏览器完成配置和使用。

模块自带完整的 arm64 Ubuntu 24.04 运行时（chroot），OpenClaw 和 Node.js 都在其中，因此行为与普通 Linux 主机基本一致：npm 包、原生依赖、`openclaw` CLI、Control UI、内置终端都可以用。

## 离线与体积

- 模块 zip 约 **168 MB**，已包含全部运行时，**安装和首次启动都不需要联网**。
- 安装后占用 `/data` 约 **1.0 GB**。保留完整 OpenClaw 安装（文档、工作区模板、类型声明、各平台预编译），只清理 apt/npm 缓存和临时文件。
- 内存方面：网关常驻 RSS 约 **0.8–1.1 GB**。这是 OpenClaw 自身多 worker isolate 架构决定的；实测 V8 堆上限、`MALLOC_ARENA_MAX`、关闭插件、CPU 亲和等都无法显著降低，强行限制 worker 堆会导致网关崩溃。低内存机型建议把 Gateway 放在电脑或 NAS 上运行。

## 更新日志

- **2026.10.9-android.10**：模块 ID 改为 `openclaw`，安装目录变为 `/data/adb/modules/openclaw`；从旧模块 `openclaw-magisk` 升级前请先卸载旧模块，避免两个模块同时启动。
- **2026.10.9-android.9**：模块 ID 为 `openclaw`；版本号改为 `<上游版本>-android.<versionCode>`；新增 KernelSU/APatch WebUI（`webroot/`），可启动/停止/重启服务、打开面板、查看日志和切换局域网；移除旧的 `action.sh` 操作按钮。

## 版本号

模块版本格式为 `<上游 OpenClaw 版本>-android.<versionCode>`，例如 `2026.10.9-android.10`。

## 环境要求

- arm64 手机（`arm64-v8a`）
- Magisk、KernelSU 或 APatch（已在 Magisk 30.2 / Android 15 / 小米 8 上验证）
- `/data` 至少 2 GB 可用空间（运行时约 900 MB，安装临时空间另算）

## 安装

1. 在 Root 管理器中刷入 `release/openclaw-magisk-2026.10.9-android.10.zip`：

   - Magisk：模块 → 从本地安装
   - KernelSU / APatch：模块 → 安装本地模块

   也可以用 adb（仅 Magisk）：

   ```bash
   adb push openclaw-magisk-2026.10.9-android.10.zip /data/local/tmp/
   adb shell su -c 'magisk --install-module /data/local/tmp/openclaw-magisk-2026.10.9-android.10.zip'
   ```

   模块自带 busybox，KernelSU/APatch 下不依赖 `/data/adb/magisk/busybox`。安装过程会离线解压约 900 MB 运行时，通常 30–60 秒。

   > 从旧模块 `openclaw-magisk` 升级时，请先在 Root 管理器中卸载旧模块，再刷入本版本；否则两个模块会同时启动并争用 18789 端口。

2. 重启手机（或执行 `openclawctl start`）。网关约 20–30 秒后就绪。

3. 浏览器访问：

   ```text
   http://127.0.0.1:18789/#token=<你的 token>
   ```

   手机上执行下面的命令可直接打印带 token 的地址：

   ```bash
   adb shell su -c '/data/adb/modules/openclaw/bin/openclawctl open'
   ```

   token 同时保存在 `/data/openclaw/token`，并复制到 `Download/openclaw-token.txt`。

## 控制命令

所有命令都需要 root：

```bash
adb shell su -c '/data/adb/modules/openclaw/bin/openclawctl status'
```

| 命令 | 作用 |
| --- | --- |
| `openclawctl start` / `stop` / `restart` | 启动、停止、重启网关 |
| `openclawctl status` | 状态、地址、token |
| `openclawctl open` | 输出带 token 的浏览器地址 |
| `openclawctl logs [N]` | 查看网关日志 |
| `openclawctl provision` | 运行时缺失时联网重新部署（备用） |
| `openclawctl update` | 升级 OpenClaw 到最新版并重启 |
| `openclawctl lan on` / `off` | 绑定到 Wi‑Fi（局域网可访问）/ 仅本机 |
| `openclawctl shell` | 进入 Ubuntu 环境的 bash |
| `openclawctl patch` | 重新应用 Android 兼容补丁 |

## 从电脑访问

默认只监听 `127.0.0.1`（手机本机）。电脑通过 USB 使用时：

```bash
adb forward tcp:18789 tcp:18789
```

然后打开 `http://127.0.0.1:18789/#token=<token>`。

如果需要同一 Wi‑Fi 下直接访问：

```bash
adb shell su -c '/data/adb/modules/openclaw/bin/openclawctl lan on'
```

这会监听 `0.0.0.0:18789`，请确认 token 足够保密，且只在可信网络中使用。关闭：

```bash
adb shell su -c '/data/adb/modules/openclaw/bin/openclawctl lan off'
```

## 配置

首次打开 Control UI 后，进入 **Settings → Providers & Models**，选择模型提供商并填入 API Key，即可开始对话。也可以在 **Config** 页直接编辑 OpenClaw 的完整配置。

配置文件位于 `/data/openclaw/home/.openclaw/openclaw.json`，通过 chroot 内的 `~/.openclaw` 访问。

默认关闭了 Android 上不可用的三个插件：`browser`、`cua-computer`、`canvas`。需要时可以在 Control UI 或 CLI 中重新启用。

## 目录结构

```text
/data/adb/modules/openclaw/    Magisk 模块（脚本、开机服务）
/data/openclaw/
  rootfs/                      Ubuntu 24.04 arm64 + Node 26 + OpenClaw（约 900 MB）
  home/                        对应 chroot 内的 /root（配置、会话、凭据）
  logs/                        gateway.log / provision.log / update.log
  token                        网关 token
```

模块升级默认保留 `/data/openclaw`；**卸载模块会自动停止网关、卸载挂载点，并删除 `/data/openclaw`（含配置、会话、日志、token）以及 `Download/openclaw-token.txt`。**

安装完成后会先解析项目短链接的重定向目标，再用浏览器打开目标页：`https://dwz.liuyi.publicvm.com/openclaw-pocket`。

## 模块 WebUI（KernelSU / APatch）

模块带有 `webroot/` 页面。KernelSU 以及支持模块 WebUI 的 APatch / 衍生管理器会在模块页显示“打开 / Open”按钮（不再使用 `action.sh` 操作按钮）。页面可以：

- 查看运行状态、模块版本、上游版本和控制台地址
- 启动、停止、重启网关
- 在当前 WebUI 内显示带 token 的 Control UI（系统返回键回到控制页）
- 查看最近 200 行网关日志
- 开关局域网访问

入口文件：

```text
/data/adb/modules/openclaw/webroot/index.html
```

Magisk 不支持模块 WebUI，请使用下面的 `openclawctl` 命令。

## Android 兼容说明

Android 内核不提供 `/proc/self/ns/pid`，而 OpenClaw 用它判断网关进程是否属于同一 PID namespace。缺少该文件会导致启动时报：

```text
cannot verify Gateway ownership from this process (different PID namespace)
```

模块会在部署、升级和启动时自动给 OpenClaw 的 `dist` 代码打一个小补丁：读不到该文件时返回固定值 `android-nons`，使所有权校验通过。该补丁只影响这一个判断，不修改其他逻辑；`openclawctl update` 会自动重新应用。

其他说明：

- 无 systemd，模块用 supervisor 脚本在 Magisk `late_start service` 阶段启动网关，崩溃后自动重启。
- 模块默认离线安装；如果运行时缺失（例如手工删除），`service.sh` 会尝试联网自动部署，也可以手动执行 `openclawctl provision`。
- 仅支持 arm64。

## 故障排查

```bash
# 网关日志
adb shell su -c '/data/adb/modules/openclaw/bin/openclawctl logs 200'

# chroot 内检查
adb shell su -c '/data/adb/modules/openclaw/bin/openclawctl shell'
```

常见问题：

- **网页打不开**：先看 `openclawctl status` 和 `logs`；首次启动需要 20–30 秒。
- **端口被占用 / 网关反复退出**：`openclawctl logs` 查看原因，确认没有其他进程占用 18789。
- **手机重启后没有自动启动**：确认 Magisk 中模块已启用，并检查 `/data/openclaw/logs/gateway.log`。
- **内存不足**：网关常驻约 0.8–1.1 GB，必要时关闭后台应用，或把 Gateway 移到电脑/NAS。
