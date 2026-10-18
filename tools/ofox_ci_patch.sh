#!/bin/sh
# OrangeFox (fox_12.1) 构建前源码补丁 —— 与 CI 工作流保持一致
# 用法: 在 fox_12.1 源码树根目录执行:
#   sh <本仓库>/tools/ofox_ci_patch.sh
set -e

PATCHED=0

# 关闭 TW_INCLUDE_CRYPTO 后, partitionmanager.cpp 中 AID_MEDIA_RW 的
# 传递性 include 链(原本经由 crypto 相关头文件带入)不再生效,
# 编译报 "use of undeclared identifier 'AID_MEDIA_RW'"。
# 该宏在 A12 中仍定义于 system/core/libcutils(private/android_filesystem_config.h)
# 且恒为 1023, 因此等价替换为字面量 1023。
FILES=$(grep -rl "AID_MEDIA_RW" bootable/recovery vendor/twrp 2>/dev/null || true)
if [ -n "$FILES" ]; then
    echo "$FILES" | xargs sed -i 's/\bAID_MEDIA_RW\b/1023/g'
    echo "[ofox_ci_patch] 已替换 AID_MEDIA_RW -> 1023:"
    echo "$FILES"
    PATCHED=1
else
    echo "[ofox_ci_patch] 未发现 AID_MEDIA_RW, 无需补丁"
fi

if [ "$PATCHED" -eq 1 ]; then
    echo "[ofox_ci_patch] 补丁后残留检查:"
    grep -rn "AID_MEDIA_RW" bootable/recovery vendor/twrp 2>/dev/null || echo "  无残留"
fi
