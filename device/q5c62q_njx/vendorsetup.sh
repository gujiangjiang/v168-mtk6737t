# TWRP / OrangeFox lunch 目标
# Android 12+ (OrangeFox fox_12.1) 的 add_lunch_combo 已是废弃 stub(只打印提示);
# 检测到废弃实现则跳过调用, lunch 目标由 AndroidProducts.mk 的 COMMON_LUNCH_CHOICES 提供。
if ! declare -f add_lunch_combo | grep -q "obsolete"; then
    add_lunch_combo omni_q5c62q_njx-eng 2>/dev/null || true
    add_lunch_combo omni_q5c62q_njx-userdebug 2>/dev/null || true
    add_lunch_combo twrp_q5c62q_njx-eng 2>/dev/null || true
    add_lunch_combo twrp_q5c62q_njx-userdebug 2>/dev/null || true
fi

export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C

# ---------------------------------------------------------------------------
# OrangeFox 专用变量 (FOX_ / OF_ 前缀必须写在这里或命令行 export, 不能放 *.mk)
# ---------------------------------------------------------------------------
export FOX_BUILD_DEVICE=q5c62q_njx
# 非 MIUI 设备, 关闭 MIUI 相关特性
export FOX_VANILLA_BUILD=1
# 使用无 .config 的预编译内核时, 避免 "NO KERNEL CONFIG" 报错
export OF_FORCE_PREBUILT_KERNEL=1
# 镜像过大时可启用 (本机 16MB recovery 分区, 一般不需要)
# export FOX_DRASTIC_SIZE_REDUCTION=1
