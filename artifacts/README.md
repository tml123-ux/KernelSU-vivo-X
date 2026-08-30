# KernelSU vivo 适配产物

针对 vivo 设备（adb root 临时 root、不解锁 bootloader、不刷分区）的 KernelSU LKM 软件适配。

## 文件说明

| 文件 | 说明 |
|---|---|
| `KernelSU-v3.3.0.apk` | KernelSU Manager **官方 v3.3.0 APK**（官方签名）。Manager 必须使用官方签名版，见下方"签名校验"。 |
| `ksud` | **修复版** ksud 可执行文件（含 android16-6.12 内核模块资产） |
| `install.sh` | 首次安装脚本（电脑端 adb 执行） |
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

## 修复说明

- 修复"退出后台再打开 Manager 系统卡死重启"：`ksud late-load --magica` 在 KernelSU 已激活时直接跳过，不再循环重启 adbd 与 Manager（`userspace/ksud/src/magica.rs`、`late_load.rs`）。
- 适用内核：GKI `android16-6.12`（内置 ko vermagic `6.12.76-4k`，兼容同 KMI 分支小版本）。
