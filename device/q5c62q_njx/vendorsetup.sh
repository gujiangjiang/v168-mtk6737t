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

# ---- 体积选项 (recovery 分区仅 16MB; OFox R11.3 默认集合约 21.9MB) ----
# LZMA 压缩 recovery ramdisk: 已实测本机 3.18 内核的 initramfs 解压器
# 含 gzip/bzip2/lzma 方法表 (CONFIG_RD_LZMA=y), 压缩率显著优于 gzip,
# 是把镜像压进 16MB 的关键手段 (需构建机有 lzma, 工作流已装 xz-utils)
# 注意: 旧名 FOX_USE_LZMA_COMPRESSION 会被 orangefox.mk 主动报错拒绝, 勿设!
export OF_USE_LZMA_COMPRESSION=1
# 移除 bash(约 1MB) / nano 编辑器 / aapt(若存在约 1.7MB); recovery 不需要
export FOX_REMOVE_BASH=1
export FOX_EXCLUDE_NANO_EDITOR=1
export FOX_REMOVE_AAPT=1
# 镜像过大时可启用 (experimental; 会移除几乎全部 OrangeFox 附加二进制)
# export FOX_DRASTIC_SIZE_REDUCTION=1
