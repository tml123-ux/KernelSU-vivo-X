#!/bin/bash
# 修复官方 KernelSU Manager 退出后台再打开导致的卡死重启 (magica 重入循环)
#
# 原理: Manager 冷启动会经 AppZygotePreload 执行 APK 解压目录里的 libksud.so
# (官方版无"已激活则跳过"保护), 每冷启动都重跑 magica -> 重启 adbd + force-stop
# Manager -> 再次冷启动 -> 死循环卡死系统。
#
# 本脚本用修复版 libksud.so (magica::run 检测 KernelSU 已激活则直接跳过)
# 覆盖 Manager 的 lib 目录, 替换一次长期有效 (Manager 重装/更新后需重跑)。
#
# 用法: ./fix-magica.sh   (手机已连接, 支持 adb root)
set -e
cd "$(dirname "$0")"

PKG=me.weishu.kernelsu
FIXED=libksud.so

echo "[-] 确保 adb root"
adb root >/dev/null 2>&1 || true
sleep 2
adb wait-for-device

echo "[-] 定位 Manager 安装目录"
APK_PATH=$(adb shell pm path "$PKG" 2>/dev/null | tr -d '\r' | sed -n 's#^package:##p' | head -1)
if [ -z "$APK_PATH" ]; then
    echo "!! 未找到已安装的 $PKG, 请先安装 KernelSU Manager"
    exit 1
fi
LIBDIR="${APK_PATH%/base.apk}/lib/arm64"
echo "    lib 目录: $LIBDIR"

if ! adb shell "ls $LIBDIR/libksud.so" >/dev/null 2>&1; then
    echo "!! 未找到 $LIBDIR/libksud.so (可能 extractNativeLibs 关闭或路径不同)"
    exit 1
fi

echo "[-] 记录原文件属主"
OWNER=$(adb shell "stat -c '%u:%g' $LIBDIR/libksud.so" | tr -d '\r')

echo "[-] 推送修复版 libksud.so"
[ -f "$FIXED" ] || { echo "!! 缺少 $FIXED (修复版 ksud), 请从 release 下载"; exit 1; }
adb push "$FIXED" /data/local/tmp/libksud.so >/dev/null

echo "[-] 覆盖 Manager lib 目录"
adb shell "cp /data/local/tmp/libksud.so $LIBDIR/libksud.so"
adb shell "chown $OWNER $LIBDIR/libksud.so"
adb shell "chmod 755 $LIBDIR/libksud.so"
adb shell "restorecon $LIBDIR/libksud.so" 2>/dev/null || \
    adb shell "chcon -v u:object_r:apk_data_file:s0 $LIBDIR/libksud.so" || true

echo "[-] 校验替换结果"
adb shell "ls -lZ $LIBDIR/libksud.so"

echo "[-] 重启 Manager 使新 libksud.so 生效"
adb shell am force-stop "$PKG" || true
adb shell am start -n "$PKG/me.weishu.kernelsu.ui.MainActivity" >/dev/null 2>&1 || true

echo
echo "完成! 现在退出 Manager 后台再打开应不再卡死重启。"
echo "注意: 若之后重装/更新 Manager APK, libksud.so 会恢复为官方版, 需重新执行本脚本。"
