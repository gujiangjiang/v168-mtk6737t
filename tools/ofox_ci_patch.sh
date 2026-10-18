#!/bin/sh
# OrangeFox (fox_12.1) 构建前源码补丁 —— 与 CI 工作流保持一致
# 用法: 在 fox_12.1 源码树根目录执行:
#   sh <本仓库>/tools/ofox_ci_patch.sh
# 注意: 使用 POSIX/GNU/BSD 通用的 sed 写法, macOS 与 Linux 均可运行
set -e

# ---------------------------------------------------------------------------
# 补丁 1: AID_MEDIA_RW
# 关闭 TW_INCLUDE_CRYPTO 后, partitionmanager.cpp 中 AID_MEDIA_RW 的
# 传递性 include 链(原本经由 crypto 相关头文件带入)不再生效,
# 编译报 "use of undeclared identifier 'AID_MEDIA_RW'"。
# 该宏在 A12 中仍定义于 system/core/libcutils(private/android_filesystem_config.h)
# 且恒为 1023, 因此等价替换为字面量 1023。
# ---------------------------------------------------------------------------
FILES=$(grep -rl "AID_MEDIA_RW" bootable/recovery vendor/twrp 2>/dev/null || true)
if [ -n "$FILES" ]; then
    echo "[ofox_ci_patch] 替换 AID_MEDIA_RW -> 1023:"
    echo "$FILES"
    for f in $FILES; do
        sed 's/AID_MEDIA_RW/1023/g' "$f" > "$f.__patch_tmp" && mv "$f.__patch_tmp" "$f"
    done
    echo "[ofox_ci_patch] 补丁后残留检查:"
    grep -rn "AID_MEDIA_RW" bootable/recovery vendor/twrp 2>/dev/null || echo "  无残留"
else
    echo "[ofox_ci_patch] 未发现 AID_MEDIA_RW, 无需补丁"
fi

# ---------------------------------------------------------------------------
# 补丁 2: libbinder.arm32.map
# fox_12.1(android-12.1.0_r4) 的 libbinder.arm32.map 引用了若干在
# __ANDROID_VNDK__ 条件下不再编译的历史符号, 32 位 recovery 链接 libbinder
# 时必然报: "version script assignment ... failed: symbol not defined"
# (freeBuffer / ipcSetDataReference / operator<<(TextOutput&, 整型))。
# 64 位设备不使用该 map 因此无感; 本机是 32 位构建, 必须清理。
# 这些符号对本机(Android 6)无任何意义, 直接从 map 删除即可。
# ---------------------------------------------------------------------------
MAP=frameworks/native/libs/binder/libbinder.arm32.map
if [ -f "$MAP" ]; then
    BEFORE=$(wc -l < "$MAP")
    sed -e '/_ZN7android14IPCThreadState10freeBufferEPNS_6ParcelEPKhjPKyj;/d' \
        -e '/_ZN7android6Parcel19ipcSetDataReferenceEPKhjPKyjPFvPS0_S2_jS4_jE;/d' \
        -e '/_ZN7androidlsI.*EERNS_10TextOutputES2_RKT_/d' \
        "$MAP" > "$MAP.__patch_tmp"
    mv "$MAP.__patch_tmp" "$MAP"
    AFTER=$(wc -l < "$MAP")
    echo "[ofox_ci_patch] libbinder.arm32.map 清理完成: $BEFORE -> $AFTER 行"
else
    echo "[ofox_ci_patch] 未找到 $MAP, 跳过"
fi

# ---------------------------------------------------------------------------
# 补丁 3: recovery ramdisk 组装的 rsync 在"无 vendor 分区"设备上失败
#   could not make way for new symlink: root/vendor
#   cannot delete non-empty directory: root/vendor
# A12 build/make/core/Makefile 用 rsync 把 $OUT/root 合并进 recovery/root,
# 本机无 vendor 分区, $OUT/root/vendor 是符号链接(-> /system/vendor),
# 而 recovery/root/vendor 已被安装成非空目录, rsync 默认拒绝替换 ->
# 需 --force 才允许"以符号链接替换非空目录"。
# ---------------------------------------------------------------------------
MKFILE=build/make/core/Makefile
if grep -q "rsync -a --exclude=sdcard" "$MKFILE" 2>/dev/null; then
    sed 's/rsync -a --exclude=sdcard/rsync -a --force --exclude=sdcard/' "$MKFILE" > "$MKFILE.__patch_tmp"
    mv "$MKFILE.__patch_tmp" "$MKFILE"
    echo "[ofox_ci_patch] 已为 recovery ramdisk rsync 添加 --force"
    echo "[ofox_ci_patch] 生效验证 (应显示 --force):"
    grep -n "rsync -a --force --exclude=sdcard" "$MKFILE" | head -1
else
    echo "[ofox_ci_patch] 未找到目标 rsync 行 (可能上游已修复), 跳过"
fi
