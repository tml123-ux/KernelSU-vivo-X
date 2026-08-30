# KernelSU vivo 适配产物

针对 vivo 设备（adb root 临时 root、不解锁 bootloader、不刷分区）的 KernelSU LKM 软件适配。

## 文件说明

| 文件 | 说明 |
|---|---|
| `KernelSU-v3.3.0.apk` | KernelSU Manager（arm64，V2 签名，内置修复版 ksud） |
| `ksud` | ksud 可执行文件（与 APK 内 libksud.so 完全一致，含 android16-6.12 内核模块资产） |
| `install.sh` | 首次安装脚本（电脑端 adb 执行） |
| `reload.sh` | 每次重启后重新加载 LKM 脚本 |

## 使用

```bash
# 首次安装
cd artifacts
./install.sh
# 手机重启后重新加载（adb root 与 LKM 每次开机失效）
./reload.sh
```

## 修复说明

- 修复"退出后台再打开 Manager 系统卡死重启"：`ksud late-load --magica` 在 KernelSU 已激活时直接跳过，不再循环重启 adbd 与 Manager（`userspace/ksud/src/magica.rs`、`late_load.rs`）。
- 适用内核：GKI `android16-6.12`（内置 ko vermagic `6.12.76-4k`，兼容同 KMI 分支小版本）。
