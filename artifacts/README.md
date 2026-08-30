# KernelSU vivo 适配产物

针对 vivo 设备（adb root 临时 root、不解锁 bootloader、不刷分区）的 KernelSU LKM 软件适配。

## 文件说明

| 文件 | 说明 |
|---|---|
| `KernelSU-v3.3.0.apk` | KernelSU Manager **官方 v3.3.0 APK**（官方签名）。Manager 必须使用官方签名版，见下方"签名校验"。 |
| `ksud` | **修复版** ksud 可执行文件（含 android16-6.12 内核模块资产） |
| `libksud.so` | 与 `ksud` 同构的修复版（用于覆盖 Manager 内嵌官方版，见下方"卡死重启修复"） |
| `install.sh` | 首次安装脚本（电脑端 adb 执行） |
| `fix-magica.sh` | 替换 Manager 内 libksud.so 为修复版，解决退出后台再打开卡死重启 |
| `reload.sh` | 每次重启后重新加载 LKM 脚本 |

## 签名校验（为什么 Manager 必须用官方 APK）

内核模块内置 Manager APK v2 签名证书的期望哈希（`kernel/Kbuild` 的 `KSU_EXPECTED_HASH`）。Manager 进程启动时，内核 `track_throne` 扫描 `/data/app` 并校验签名，通过后才会在 Manager 进程 `setresuid` 时注入 `[ksu_driver]` fd，Manager 首页才显示"已安装"。

- 官方 APK v2 证书 SHA-256：`c371061b19d8c7d7d6133c6a9bafe198fa944e50c1b31c9d8daa8d7f1fc2d2d6`（匹配内核内置哈希）
- 本地 fork 构建 APK v2 证书 SHA-256：`da69780270f2ecb66188a80f2f8b32dc201bdc00b40a1e10cf458b7eee5f04ea`（不匹配，Manager 显示"未安装"）

fork 构建版仍能正常授予 root（allowlist/sucompat 链路不依赖签名），只是 Manager 无法被识别。若手机已安装其他签名的 Manager，需先卸载再安装官方 APK（`adb uninstall me.weishu.kernelsu`）。

## 使用

```bash
# 首次安装（手机已装旧签名 Manager 时先卸载）
adb uninstall me.weishu.kernelsu   # 仅当已装过其他签名版本
cd artifacts
./install.sh
# 手机重启后重新加载（adb root 与 LKM 每次开机失效）
./reload.sh
```

## 卡死重启修复（退出后台再打开卡死系统）

Manager 冷启动经 `AppZygotePreload` 执行 APK 解压目录内的 `libksud.so`。官方版每次冷启动都重跑 magica（重启 adbd → force-stop/start Manager → 再次冷启动），已激活时仍不跳过，形成死循环卡死系统。

修复版 `libksud.so`（`magica::run` 检测 KernelSU 已激活则直接跳过）可覆盖 Manager 的 lib 目录，替换一次长期有效：

```bash
./fix-magica.sh
```

注意：重装/更新 Manager APK 后 `libksud.so` 恢复官方版，需重新执行。

## 修复说明

- 修复"退出后台再打开 Manager 系统卡死重启"：`ksud late-load --magica` 在 KernelSU 已激活时直接跳过，不再循环重启 adbd 与 Manager（`userspace/ksud/src/magica.rs`、`late_load.rs`）。
- 适用内核：GKI `android16-6.12`（内置 ko vermagic `6.12.76-4k`，兼容同 KMI 分支小版本）。
