# v168-mtk6737t — MT6737T (V168 / q5c62q_njx) 完整移植资源库

一部杂牌 MTK 手机（FreemeOS 6.0 / Android 6.0）的**完整复刻与移植资源库**：
固件解包产物、分析工具、设备树、预编译 Recovery、云端编译流水线全部在此。

目标：后续做任何移植（TWRP / OrangeFox / 高版本 Android / Debian / GSI 等）
**无需再重新解包、反编译官方固件**，直接用本库素材开工。

---

## 设备速览

| 项目 | 参数 |
|---|---|
| 机型 / 项目 | V168，项目代号 `q5c62q_njx`（droi 定制 FreemeOS 6.2） |
| SoC | **MT6737T**，4× Cortex-A53（ARMv8-A，**64 位核心**），Mali-T720 MP2 |
| 存储 | 16GB eMMC，system ~3GB / cache 400MB / userdata ~12GB / 无 vendor 分区 |
| 内核 | **Linux 3.18.19（ARM32）**，GCC 4.8，2017-09 编译，`alps-mp-m0.mp1-droi6737t` BSP |
| 系统 | Android 6.0（SDK 23），**纯 32 位用户态**（无 lib64） |
| 屏幕 | 720×1280，触摸 i2c 0x5d，背光 `/sys/class/leds/lcd-backlight/brightness` |
| 引导链 | preloader → LK（**含 K64 跳转代码 + fastboot + oem unlock**）→ kernel |
| boot.img | 标准 Android v0 头，page 2048，kernel@0x40008000，ramdisk@0x44000000，cmdline `bootopt=64S3,32N2,32N2`，无 AVB |
| 外设 | 摄像头 0x10/0x3c、指纹 gf518m、sensors（mc3410/stk3x1x/akm09911/itg1010）、NFC、hall |
| 调制解调器 | modem_1_lwg/ltg_n（4G 双卡）+ modem_3_3g_n（C2K），WMT/CONSYS WiFi |

> 详细分析报告见 [docs/hardware-analysis.md](docs/hardware-analysis.md)

## 目录结构

```
.
├── device/q5c62q_njx/          # ★ TWRP / OrangeFox 通用设备树（含原机内核）
├── prebuilt/                   # ★ 可直接刷写的产物
│   ├── TWRP-3.6.1_q5c62q_njx_*.img    # 移植完成的 TWRP（内核替换法）
│   ├── twrp_ramdisk.gz                # 该 TWRP 使用的 ramdisk
│   ├── twrp_ramdisk_root/             # ramdisk 解包工作目录（可再修改）
│   └── donor/                         # CUBOT 原版 TWRP（donor 存档）
├── analysis/                   # ★ 官方固件解包产物（免重复解包）
│   ├── boot/                   # 原机 boot.img 内核/ramdisk/设备树
│   │   ├── kernel.zImage / kernel_vmlinux / ramdisk.gz
│   │   ├── ramdisk_root/       # ramdisk 解包根目录（init.rc/fstab 等）
│   │   └── device.dtb          # 从内核尾部提取的设备树（含全部外设节点）
│   ├── recovery/               # 原机 recovery.img 解包产物
│   ├── system/                 # system.img 只读遍历清单（1905 个文件）
│   └── logs/                   # 头部解析 / DTB 节点 / system 结构 分析日志
├── tools/                      # ★ 分析/打包工具（纯 python3，跨平台）
│   ├── unpack_bootimg.py       # MTK boot/recovery 解包
│   ├── repack_ramdisk.py       # 目录 → cpio(.gz) 重打包（可复现）
│   ├── mkbootimg_mtk.py        # 打包本机参数 boot/recovery.img
│   └── ext4walk.py             # 免挂载读取 ext4（system.img 用）
├── firmware/stock/             # 原厂小镜像存档（boot/recovery/lk/preloader/tee/logo 等）
├── docs/                       # 文档（见下方索引）
├── .github/workflows/          # GitHub Actions：云端编译 TWRP / OrangeFox
└── SHA256SUMS                  # 全部镜像/内核/设备树校验值
```

## 快速开始

**① 直接刷现成 TWRP**（见 [docs/recovery-guide.md](docs/recovery-guide.md)）

```sh
fastboot oem unlock
fastboot flash recovery prebuilt/TWRP-3.6.1_q5c62q_njx_20261018.img
# 刷完立即进 recovery，不要在第一次先启动系统
```

**② 云端编译 TWRP / OrangeFox**（见 [docs/build-guide.md](docs/build-guide.md)）
把本仓库推到 GitHub → Actions → 选择对应 workflow → Run workflow → 下载 Artifacts。
每次运行结束（无论成功/失败）都会自动生成 **Summary** 报告：镜像大小/SHA256/头部校验，
或失败时的错误摘要与体积诊断，一屏可见。

**③ 后续移植（Debian / 新 Android 等）**
直接使用本库素材：设备树 `analysis/boot/device.dtb`、解包后的内核/ramdisk、
外设清单（[docs/hardware-analysis.md](docs/hardware-analysis.md)）、
打包/解包工具 `tools/`。64 位与 Treble 路线见分析文档末章。

## 文档索引

| 文档 | 内容 |
|---|---|
| [docs/hardware-analysis.md](docs/hardware-analysis.md) | 固件完整分析报告（引导链/分区表/DTB 外设/32位确认/K64/Treble 路线） |
| [docs/device-tree.md](docs/device-tree.md) | 设备树逐项说明与调参指南 |
| [docs/build-guide.md](docs/build-guide.md) | TWRP/OrangeFox 云端与本地编译指南 |
| [docs/recovery-guide.md](docs/recovery-guide.md) | recovery 移植原理、工具用法、刷机与调试 |
| [AGENTS.md](AGENTS.md) | 自动化代理协作规则（环境/提交/目录/禁止事项） |

## 移植关键结论（TL;DR）

1. **内核必须用原机的**：面板（LCM）驱动闭源编译在 3.18.19 内核里，换第三方内核 = 黑屏/触摸失效。
   这也是本库采用"内核替换法"和"源码编译也预置原机内核"的原因。
2. 引导链已具备 64 位能力：LK 内含 `[LK]jump to K64` 代码，cmdline 已带 `64S3` 段描述。
3. 无 AVB / vbmeta 校验，刷 recovery 无需签名；LK fastboot 支持 `oem unlock`。
4. 本机是纯 32 位用户态；64 位 / Treble 属于深水区，路线见分析文档。
5. **不刷机时也要先备份 nvram/nvdata**（IMEI / WiFi MAC / 射频校准）。
6. **recovery ramdisk 必须 gzip**：3.18.19 内核的 initramfs 解压器只编译了 gzip
   （`lib/decompress.c` 方法表中 lzma/xz/bzip2/lzo/lz4 解压函数指针全为 NULL），
   任何 LZMA ramdisk 都会让内核无法解压 initramfs 而无法启动。
   体积预算：16MB 分区 − 6.29MB 内核 ≈ **ramdisk.gz ≤ 10.4MB**；
   这也是 OrangeFox 选 fox_9.0（TWRP 9.0 底座）而非 fox_12.1 的根本原因。

## 来源与授权

- 设备树、工具脚本：本库原创，MIT（保留署名）。
- TWRP / OrangeFox 为 GPLv3 项目；`prebuilt/donor/` 内 CUBOT TWRP 来自
  [seluce/android_twrp_device](https://github.com/seluce/android_twrp_device)（GPLv3）。
- `firmware/stock/` 与 `analysis/` 内的原机固件产物版权归原厂，仅作个人设备恢复/移植用途，请勿商用。
