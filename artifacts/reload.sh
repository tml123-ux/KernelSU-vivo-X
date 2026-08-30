#!/bin/bash
# 重启后重新加载 KernelSU LKM（adb root 每次开机失效, 需重新执行）
# 用法: ./reload.sh
set -e
cd "$(dirname "$0")"

echo "[-] 确保 adb root"
adb root || true
sleep 2
adb wait-for-device

echo "[-] 关闭 selinux"
adb shell setenforce 0 || true

echo "[-] 重新加载 kernelsu.ko"
adb shell /data/adb/ksud late-load --package-name me.weishu.kernelsu
sleep 2

echo "[-] 验证"
adb shell ls /sys/kernel/ksu 2>/dev/null && echo "OK: /sys/kernel/ksu 存在" || echo "警告: 加载失败, 请查看 logcat"
