# MT6737T / q5c62q_njx (V168 / FreemeOS 6.0) recovery 设备树
# 适用: TWRP (minimal-manifest twrp-9.0) 与 OrangeFox (fox_12.1)
# 关键点: 使用原机 3.18.19 预编译内核, 保证 LCD / 触摸驱动完全兼容

DEVICE_TREE := device/mediatek/q5c62q_njx

# Bootloader / Platform
TARGET_NO_BOOTLOADER := true
TARGET_BOOTLOADER_BOARD_NAME := mt6735
TARGET_BOARD_PLATFORM := mt6735

# CPU: 4x Cortex-A53 (64 位 SoC, 本机用户态为 32 位)
# 说明: Android 12+ (fox_12.1) 对 cortex-a53 强制要求 TARGET_ARCH_VARIANT=armv8-a,
#       Android 9 (twrp-9.0) 则沿用 armv7-a-neon, 故按平台 SDK 自动切换。
TARGET_ARCH := arm
ifeq ($(shell test $(PLATFORM_SDK_VERSION) -gt 30 2>/dev/null && echo modern),modern)
TARGET_ARCH_VARIANT := armv8-a
else
TARGET_ARCH_VARIANT := armv7-a-neon
endif
TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi
TARGET_CPU_VARIANT := cortex-a53

# 预编译内核 (原机 boot.img / recovery.img 为同一内核)
TARGET_PREBUILT_KERNEL := $(DEVICE_TREE)/kernel

# 内核参数 (与原机一致; 追加 selinux=permissive 供 recovery 使用)
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,32N2 androidboot.selinux=permissive
BOARD_KERNEL_BASE := 0x40000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_MKBOOTIMG_ARGS := --kernel_offset 0x00008000 --ramdisk_offset 0x04000000 --tags_offset 0x0e000000

# 分区
BOARD_BOOTIMAGE_PARTITION_SIZE := 16777216
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 16777216
BOARD_FLASH_BLOCK_SIZE := 131072

# Recovery 基础
TARGET_USERIMAGES_USE_EXT4 := true
BOARD_HAS_LARGE_FILESYSTEM := true
TARGET_RECOVERY_FSTAB := $(DEVICE_TREE)/recovery.fstab
BOARD_SUPPRESS_SECURE_ERASE := true
RECOVERY_GRAPHICS_USE_LINELENGTH := true

# 屏幕 720x1280 (若颜色通道异常, 在 BGRA_8888 / RGBA_8888 之间切换)
TARGET_RECOVERY_PIXEL_FORMAT := "BGRA_8888"
TW_THEME := portrait_hdpi
TW_DEFAULT_LANGUAGE := zh_CN
TW_EXTRA_LANGUAGES := true

# 通用功能
TW_EXCLUDE_SUPERSU := true
TW_NO_SCREEN_TIMEOUT := true
TW_SCREEN_BLANK_ON_BOOT := true
TW_USE_MODEL_HARDWARE_ID_FOR_DEVICE_ID := true
TW_NO_CPU_TEMP := true

# ---- 体积控制 (recovery 分区仅 16777216 字节; twrp-9.0/fox 默认集合超限) ----
# 通用裁剪项 (两个平台源码语义一致, 已逐一核对)
TW_EXCLUDE_PYTHON := true          # twrp-9.0 默认捆绑 python3_twrp
TW_EXCLUDE_TWRPAPP := true
TW_EXCLUDE_BASH := true
TW_EXCLUDE_NANO := true
TW_EXCLUDE_TZDATA := true
TW_EXCLUDE_MTP := true             # 需要电脑直传文件时改为 false
TW_NO_EXFAT := true                # 仅去掉 exFAT, vfat 卡不受影响
TW_INCLUDE_FB2PNG := false         # 截图功能

# 平台差异项 (两个分支源码语义不同, 已实测核对, 勿轻易合并):
ifeq ($(shell test $(PLATFORM_SDK_VERSION) -gt 30 2>/dev/null && echo modern),modern)
# fox_12.1 (A12 OrangeFox):
#   - TW_EXCLUDE_ENCRYPTED_BACKUPS 只要"非空"就强制链接 libopenaes(上游语义 bug),
#     而其模块又只在"值不等于 true"时安装 → 设为 true 必然链接失败, 必须留空;
#     留空时该功能本身仍被 -DTW_EXCLUDE_ENCRYPTED_BACKUPS 关闭(且模块会被构建, 无害)。
#   - toolbox 由源码内部强制启用; 该树没有 busybox 模块, 不要设置 TW_USE_TOOLBOX。
else
# twrp-9.0 (A9):
#   - true 语义正常, 可安全排除 openaes
#   - 必须显式用 toolbox 模式: minimal manifest 无 external/busybox 仓库
TW_EXCLUDE_ENCRYPTED_BACKUPS := true
TW_USE_TOOLBOX := true
endif

# 背光 / 亮度 (MT65xx 标准路径)
TW_BRIGHTNESS_PATH := /sys/class/leds/lcd-backlight/brightness
TW_MAX_BRIGHTNESS := 255
TW_DEFAULT_BRIGHTNESS := 120

# 数据解密 (MTK 硬件级 FDE; 默认关闭压体积, 需要时整段打开)
TW_INCLUDE_CRYPTO := false
# TW_CRYPTO_FS_TYPE := "ext4"
# TW_CRYPTO_MNT_POINT := "/data"
# TW_CRYPTO_FS_OPTIONS := "nosuid,nodev,noatime,discard,noauto_da_alloc,data=ordered"

# 内部存储位于 userdata (/data/media)
RECOVERY_SDCARD_ON_DATA := true
