# 设备树说明（device/q5c62q_njx）

本设备树同时服务两个目标，这是刻意设计：

| 编译目标 | 体系 | 产品名 | lunch 目标 | workflow |
|---|---|---|---|---|
| TWRP | minimal-manifest `twrp-9.0`（omni 系） | `omni_q5c62q_njx` | `lunch omni_q5c62q_njx-eng` | build_twrp.yml |
| OrangeFox | `fox_12.1`（twrp 系） | `twrp_q5c62q_njx` | `lunch twrp_q5c62q_njx-eng` | build_orangefox.yml |

## 文件职责

| 文件 | 作用 |
|---|---|
| `BoardConfig.mk` | 平台/内核/分区/屏幕/功能开关（核心文件） |
| `omni_q5c62q_njx.mk` | TWRP(omni) 产品定义 |
| `twrp_q5c62q_njx.mk` | OrangeFox(twrp) 产品定义 |
| `AndroidProducts.mk` | 注册两份产品 + COMMON_LUNCH_CHOICES |
| `vendorsetup.sh` | lunch 回退目标 + `FOX_*`/`OF_*` 变量（**必须放脚本不能放 mk**） |
| `recovery.fstab` | 本机分区表（TWRP 格式，含 flags） |
| `kernel` | **原机 3.18.19 zImage**（预编译，勿更换） |

## BoardConfig 关键参数与原因

```makefile
TARGET_BOARD_PLATFORM := mt6735        # 本机 DTB/fstab 均以 mt6735 平台命名
TARGET_ARCH := arm / cortex-a53        # SoC 是 64 位，但本机用户态 32 位，recovery 按 32 位编
TARGET_PREBUILT_KERNEL := $(DEVICE_TREE)/kernel
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,32N2 androidboot.selinux=permissive
BOARD_KERNEL_BASE := 0x40000000
BOARD_MKBOOTIMG_ARGS := --kernel_offset 0x00008000 \   # -> 0x40008000
                        --ramdisk_offset 0x04000000 \   # -> 0x44000000
                        --tags_offset 0x0e000000        # -> 0x4e000000
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 16777216          # 16MB 分区限制
TARGET_RECOVERY_PIXEL_FORMAT := "BGRA_8888"             # 颜色异常时换 RGBA_8888
TW_BRIGHTNESS_PATH := /sys/class/leds/lcd-backlight/brightness
```

`vendorsetup.sh` 中的 OrangeFox 变量：

```sh
export FOX_BUILD_DEVICE=q5c62q_njx
export FOX_VANILLA_BUILD=1          # 非 MIUI
export OF_FORCE_PREBUILT_KERNEL=1   # 预编译内核无 .config，防 "NO KERNEL CONFIG"
```

## 内核文件（不可更换）

- 来源：原机 `recovery.img`（与 boot.img 相同），见 `analysis/recovery/kernel.zImage`。
- sha256：`661f69a3ce46d2599ee08a7f0ba5a0bc614cf41bf0ca9a82c59de16063d96130`
- 原因：LCD 面板（LCM）驱动为闭源集成内核；触摸/显示/传感器全依赖它。
  **任何第三方内核都可能导致黑屏**，包括"看起来同 SoC"的内核。
- 若要换内核，唯一正路是先反编译/逆向本内核的 LCM 驱动或找到 droi 的项目源码，
  再重新编译验证——属于高级任务，谨慎立项。

## recovery.fstab 说明

- 使用长路径 by-name：`/dev/block/platform/mtk-msdc.0/11230000.msdc0/by-name/*`（与原机一致）。
- 已包含：boot / logo / nvram / nvdata / recovery / lk / proinfo / protect1 / protect2 /
  para / secro / metadata / oemkeystore / system(/system_image) / cache / data /
  external_sd(mmcblk1p1) / usbotg。
- 故意**不含 frp**（本机无该分区，donor 里的 frp 行已删除）。
- data 的加密参数：`flags=forceencrypt=.../by-name/metadata`（对应 MTK 硬件级 FDE）。

## 常见调整场景

| 需求 | 动作 |
|---|---|
| UI 过大/过小 | `TW_THEME`（当前 portrait_hdpi） |
| 颜色红蓝颠倒 | `TARGET_RECOVERY_PIXEL_FORMAT` 在 `BGRA_8888` ↔ `RGBA_8888` 切换 |
| 亮度不可调 | 尝试 `TW_MAX_BRIGHTNESS := 255` / `TW_DEFAULT_BRIGHTNESS`，或换 `/sys/devices/platform/leds-mt65xx/...` 路径 |
| 中文界面 | 已设 `TW_DEFAULT_LANGUAGE := zh_CN` + `TW_EXTRA_LANGUAGES := true` |
| 镜像超 16MB | 关 `TW_EXTRA_LANGUAGES`；OFox 可 `export FOX_DRASTIC_SIZE_REDUCTION=1` |
| 触摸方向错误 | 内核触控驱动决定，一般无需处理；软件侧可 `TW_INPUT_BLACKLIST` 排除虚拟鼠标设备 |

## 给非 recovery 移植的建议

若要用本设备树为基础做 **Debian / 主线内核** 类移植：

1. 从 `analysis/boot/device.dtb` 反编译出文本 DTS（`dtc -I dtb -O dts`）作为参考。
2. 驱动对照表（内核 3.18.19 反汇编/字符串）见 `analysis/boot/kernel_vmlinux` 与
   `docs/hardware-analysis.md` 第 6 节。
3. 引导链为 LK+fastboot：Debian 可用 `fastboot flash boot <boot.img>` 直接引导
   自编内核（注意 bootimg 打包参数保持本文常量）。
