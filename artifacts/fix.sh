#!/system/bin/sh
# 手机端: 替换 Manager 内 libksud.so 为修复版 (修复退出后台再打开卡死重启)
# 用法(提权后的 root shell 里): sh /data/local/tmp/fix.sh
PKG=me.weishu.kernelsu
SRC=/data/local/tmp/libksud.so

APK=$(pm path "$PKG" 2>/dev/null | sed 's/package://' | head -1)
if [ -z "$APK" ]; then
    echo "!! 未找到已安装的 $PKG, 请先安装 KernelSU Manager"
    exit 1
fi
LIBDIR="${APK%/base.apk}/lib/arm64"

if [ ! -f "$SRC" ]; then
    echo "!! 缺少 $SRC, 请先 adb push libksud.so /data/local/tmp/libksud.so"
    exit 1
fi
if [ ! -f "$LIBDIR/libksud.so" ]; then
    echo "!! 未找到 $LIBDIR/libksud.so"
    exit 1
fi

OWNER=$(stat -c '%u:%g' "$LIBDIR/libksud.so")
cp "$SRC" "$LIBDIR/libksud.so"
chown "$OWNER" "$LIBDIR/libksud.so"
chmod 755 "$LIBDIR/libksud.so"
restorecon "$LIBDIR/libksud.so" 2>/dev/null || chcon u:object_r:apk_data_file:s0 "$LIBDIR/libksud.so"

echo "[OK] 已替换:"
ls -lZ "$LIBDIR/libksud.so"

echo "[..] 重启 Manager..."
am force-stop "$PKG"
sleep 1
am start -n "$PKG/me.weishu.kernelsu.ui.MainActivity" 2>/dev/null

echo "[OK] 完成! 退出 Manager 再打开应不再卡死重启。"
