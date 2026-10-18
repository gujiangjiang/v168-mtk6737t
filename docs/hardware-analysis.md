# 固件分析报告 — MT6737T / q5c62q_njx (V168)

> 本报告基于对原厂固件的实测解包（产物在 `analysis/`，工具在 `tools/`），
> 所有数值均可复现：`python3 tools/unpack_bootimg.py --info firmware/stock/boot_stock.img`

## 1. 平台与系统

| 项目 | 值 | 依据 |
|---|---|---|
| SoC | MT6737T（4×Cortex-A53 ARMv8-A 64位核心 + Mali-T720 MP2） | scatter / DTB `arm,cortex-a53`、`arm,malit720` |
| BSP | `alps-mp-m0.mp1-V2.84_droi6737t.35g.m0_P178`（Android 6.0） | system build.prop |
| 系统 | Android 6.0 (MRA58K, SDK23) / FreemeOS 6.2（droi 卓易） | build.prop |
| 安全补丁 | 2017-06-05，编译于 2017-09-11 | build.prop |
| 用户态 | **纯 32 位**：`abilist32=armeabi-v7a,armeabi`、`abilist64=` 空、无 `/system/lib64`、`app_process→app_process32`、`init.zygote32` 唯一，`ro.zygote=zygote32` | build.prop / ext4 遍历 |
| 屏幕 | 720×1280 @320dpi | build.prop |
| 低内存优化 | `ro.config.low_ram=true` | ramdisk default.prop |

## 2. boot / recovery 镜像结构

- 标准 Android bootimg v0 头：page_size **2048**，kernel@`0x40008000`，ramdisk@`0x44000000`，
  tags@`0x4e000000`，second=0，header name=`1505127327`。
- cmdline：`bootopt=64S3,32N2,32N2`（无 AVB/vbmeta）。
- 内核：**Linux 3.18.19**（`gcc 4.8 (GCC)`，`server@droi` 编译，2017-09-11），ARM32 zImage，
  gzip 载荷位于 0x422f，解压后 13.5MB（`analysis/boot/kernel_vmlinux`）。
- DTB：**追加在内核尾部** 偏移 `0x5ed828`，大小 `0x10fb8`（69.5KB），已提取为
  `analysis/boot/device.dtb`（root model=`MT6735`）。
- 镜像 id 字段（偏移 576，SHA1）：与 AOSP mkbootimg 算法一致
  （sha1(kernel+size+ramdisk+size+second+size)），已实测比对通过。
- **boot.img 与 recovery.img 使用完全相同的内核**
  （sha256 `661f69a3...d96130`，见 SHA256SUMS）。

## 3. 引导链（preloader / LK）

- preloader：`preloader_q5c62q_njx.bin`（157KB），项目名 `q5c62q_njx`，eMMC + MSDC_0。
- LK（312KB，已由 freeme "extreme lk trim" 裁剪）关键能力（二进制字符串实证）：
  - `[LK]jump to K64 0x%x` + `64Bit/32Bit` + `bootopt=` 解析 + 校验
    `64 bit kernel can't boot at kernel_addr=0x%08x`
    → **引导链具备加载 ARM64（K64）内核的能力**（64 位移植的重要前提）。
  - 完整 **fastboot 模式**（`[Fastboot Mode]`）+ `oem unlock` 支持。
  - LK 通过 `atag,imix_r` 向内核传递分区表（by-name 设备节点的来源）。
- `bootopt=64S3,32N2,32N2` 为 MTK 双段（K32/K64）描述：当前以 K32 段启动，
  移植 64 位内核时需保持合法 kernel_addr（MTK 惯例 0x40080000）并调整 bootopt。

## 4. 分区表（eMMC 16GB）

| 分区 | 偏移 | 大小 | 说明 |
|---|---|---|---|
| preloader | 0x0 (EMMC_BOOT_1) | 256KB | 引导 |
| pgpt / proinfo / nvram | — | 512KB / 3MB / 5MB | GPT / 产品信息 / **射频校准(必备份)** |
| protect1 / protect2 | — | 10MB ×2 | DRM/安全 |
| lk | 0x1C80000 | 512KB | 引导器 |
| para=boot? / boot | 0x1D80000 | 16MB | 内核 |
| recovery | 0x2D80000 | 16MB | recovery |
| logo | 0x3D80000 | 8MB | 开机图 |
| expdb / seccfg / oemkeystore / secro / keystore | — | — | 调试/锁状态/密钥 |
| tee1 / tee2 | 0x6000000 | 5MB ×2 | Trustonic TEE |
| nvdata | 0x6A00000 | 32MB | 基带数据(**必备份**) |
| metadata | 0x8A00000 | 38MB | 加密元数据 |
| system | 0xB000000 | 0xBB800000 (~3GB) | 系统 |
| cache | 0xC6800000 | 400MB | 缓存 |
| userdata | 0xDF800000 | 0x2CAB80000 (~12GB) | 数据 |
| flashinfo / sgpt | 尾部保留 | — | — |

无 vendor / product / frp 分区 → **Treble 改造需重新分区**。

## 5. system 分析（32 位实证）

- HAL（`/system/lib/hw`，全部 ELF32 ARM）：`audio.primary.mt6737t`、`camera.mt6737t`、
  `gralloc.mt6737t`、`hwcomposer.mt6737t`、`sensors.mt6737t`、`gps.mt6737t`、
  `lights.mt6737t`、`memtrack.mt6737t`、`bluetooth.default` 等。
- 图形：`/system/lib/egl/libGLES_mali.so`（22.5MB，Mali-T720，32 位）。
- 网络/通信固件（`/system/etc/firmware`）：`modem_1_lwg_n.img`(9.7MB)、`modem_1_ltg_n.img`(8.8MB)、
  `modem_3_3g_n.img`(3.5MB)、`WIFI_RAM_CODE_6735`、WMT_SOC.cfg 等（双卡 LTE + C2K）。
- `/system/vendor` 仅为目录（init.rc 里 `/vendor` 软链到 `/system/vendor`，非独立分区）。
- 完整文件清单（1905 文件）：`analysis/system/system_file_manifest.txt`。

## 6. 设备树（device.dtb）外设清单

| 节点 | 地址/说明 |
|---|---|
| camera_main@10 / camera_sub@3c / camera_main_af@0c / strobe_main@63 | i2c 摄像头（主/副/AF/闪光） |
| cap_touch@5d | 电容触摸（i2c 设备地址 0x5d） |
| i2c_lcd_bias@3e | LCD 偏压芯片 |
| swithing_charger@36 | 切换充电 |
| nfc@28 / nfc-gpio-v2 | NFC |
| fingerprint `mediatek,gf518m` | 指纹 |
| gsensor mc3410 / alsps stk3x1x / mag akm09911 / gyro itg1010 | 传感器组 |
| hall ah1883 / battery `mediatek,battery` | 霍尔/电池 |
| mali@13040000 | GPU |
| timer `arm,armv8-timer`、cpus `arm,cortex-a53`×4 | ARMv8 证据 |
| mobicore `trustonic` / trusty `android,trusty-smc-v1` | TEE 框架双配置 |

> 注意：**LCD 面板 IC 名不在 DTB 中**（MTK M 版将 LCM 驱动编入内核），
> 需要内核源码或拆机确认面板型号。这是后续自编译内核时最大的不确定点。

## 7. 64 位 / Treble 移植路线（摘要）

1. **64 位**：CPU/LK 均就绪；需要 arm64 内核（kernel-3.18 有 mt6735 系 arch/arm64 支持）+
   64 位 blobs（Mali/gralloc/audio/camera/ril）+ zygote64；风险在 64 位闭源库可得性。
2. **高版本 Android**：官方天花板 8.1（MTK O BSP）；9/10 需 GSI 改造；11+ 不建议。
3. **Treble**：需重新分区（切 userdata 出 1~1.5GB 做 vendor）、O BSP 的 HIDL HAL 组 vendor.img、
   manifest/compatibility_matrix、内核补丁（3.18 有先例但需 backport）。
4. 参考素材：`analysis/boot/device.dtb`（合入新内核 DTS）、`kernel_vmlinux`（驱动比对）、
   `ramdisk_root`（init 体系参考）、`prebuilt/`（恢复底座）。
