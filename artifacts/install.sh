#!/bin/bash
# KernelSU LKM 一键安装（adb root 场景）
# 用法: ./install.sh
# 前置: 手机已连接电脑, 且支持 adb root (ro.debuggable=1 / eng/userdebug)
set -e
cd "$(dirname "$0")"

echo "[-] 确保 adb root"
adb root || true
sleep 2
adb wait-for-device

echo "[-] 关闭 selinux (仅本次开机, 防止模块加载被拦截)"
adb shell setenforce 0 || true

echo "[-] 推送 ksud"
adb push ksud /data/local/tmp/ksud >/dev/null
adb shell chmod 755 /data/local/tmp/ksud

echo "[-] 安装 ksud 到 /data/adb"
adb shell /data/local/tmp/ksud install

echo "[-] 加载 kernelsu.ko (LKM) 并启动 ksud"
adb shell /data/adb/ksud late-load --package-name me.weishu.kernelsu
sleep 2

echo "[-] 安装 KernelSU Manager (官方签名版)"
if ! adb install -r KernelSU-v3.3.0.apk; then
    echo
    echo "!! 安装失败: 手机可能已装过其他签名的 KernelSU Manager。"
    echo "   请先卸载旧版本再安装官方 APK:"
    echo "   adb uninstall me.weishu.kernelsu"
    echo "   adb install KernelSU-v3.3.0.apk"
    exit 1
fi

echo "[-] 验证内核模块是否加载"
adb shell ls /sys/kernel/ksu 2>/dev/null && echo "OK: /sys/kernel/ksu 存在" || echo "警告: 未发现 /sys/kernel/ksu, 可能加载失败, 请查看 logcat"

echo
echo "完成! 打开手机上 KernelSU Manager 验证."
