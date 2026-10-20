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
# 非 MIUI 设备, 关闭 MIUI 相关特性 (旧版 fox_9.0 的 vendor 脚本读 OF_ 前缀)
export FOX_VANILLA_BUILD=1
export OF_VANILLA_BUILD=1
# 使用无 .config 的预编译内核时, 避免 "NO KERNEL CONFIG" 报错
export OF_FORCE_PREBUILT_KERNEL=1

# ---- 体积选项 (recovery 分区仅 16MB) ----
# 【内核结论·勿动 LZMA】本机 3.18.19 内核 lib/decompress.c 的 compressed_formats
#   表中只有 gzip 条目的解压函数指针是真实的, 其余全为 NULL:
#     1f8b gzip  -> 0xc0c3384c (gunzip, 有效)
#     425a bzip2 -> 0x0   5d00 lzma -> 0x0   fd37 xz -> 0x0
#     894c lzo   -> 0x0   0221 lz4  -> 0x0
#   (以往"方法名 gzip/bzip2/lzma 存在"≠"已启用"; 名字恒在表里, 指针为 0 即未编译)
#   因此 OF_USE_LZMA_COMPRESSION=1 打出的镜像内核无法解压 initramfs
#   ("compression method lzma not configured" -> 无法启动), 永久禁用!
#   ramdisk 必须 gzip; 要进 16MB 只能靠裁剪内容 (fox_9.0 分支 + 官方裁剪变量)。
# export OF_USE_LZMA_COMPRESSION=1   # ← 禁用, 会导致 recovery 无法启动
# 移除 bash(约 1MB) / nano 编辑器 / aapt(若存在约 1.7MB); recovery 不需要
export FOX_REMOVE_BASH=1
export FOX_EXCLUDE_NANO_EDITOR=1
export FOX_REMOVE_AAPT=1
# 镜像过大时可启用 (experimental; 删除非默认字体/附加工具等, fox_9.0 的
# vendor/recovery legacy 分支已实现; 对应工作流输入 fox_extreme)
# export FOX_EXTREME_SIZE_REDUCTION=1
