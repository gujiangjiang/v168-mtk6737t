# Recovery 移植指南（原理 / 工具 / 刷机 / 调试）

## 1. 移植原理：内核替换法

MTK 老平台 recovery 移植的标准做法（本项目采用）：

```
新 recovery.img = 原机内核(不可动) + 适配后的第三方 recovery ramdisk(TWRP/OrangeFox)
```

原因：本机 LCD（LCM）与触摸驱动**闭源编译在 3.18.19 内核内**，
只要内核不变，显示/触摸/存储等底层能力就与官方完全一致；
recovery 本体只是 ramdisk 里的用户态程序，可以任意替换。

本项目已完成的现成产物：
- `prebuilt/TWRP-3.6.1_q5c62q_njx_20261018.img`（TWRP 3.6.1，done）
- OrangeFox 无现成 donor（全网无 MT67xx 3.18 平台的成品），需走源码编译（见 build-guide.md）

## 2. 工具用法（tools/）

### 2.1 解包 boot/recovery.img
```sh
python3 tools/unpack_bootimg.py --info  firmware/stock/boot_stock.img   # 只看头部
python3 tools/unpack_bootimg.py         firmware/stock/boot_stock.img   # 解包 -> 同目录 boot_stock_unpacked/
# 输出: kernel / ramdisk / (second) / rest.bin
```

### 2.2 解包 ramdisk（cpio）
```sh
mkdir root && cd root
gunzip -c ../analysis/boot/ramdisk.gz | cpio -idm
```

### 2.3 重打包 ramdisk（可复现，uid/gid 归 0）
```sh
python3 tools/repack_ramdisk.py <rootdir> out_ramdisk.gz
```

### 2.4 打包 recovery.img（本机参数已内置默认值）
```sh
python3 tools/mkbootimg_mtk.py \
    --kernel  analysis/recovery/kernel.zImage \
    --ramdisk out_ramdisk.gz \
    --out     my_recovery.img \
    --cmdline "bootopt=64S3,32N2,32N2 androidboot.selinux=permissive buildvariant=eng" \
    --name    1505127327
```

### 2.5 只读解析 system.img（免挂载，macOS 可用）
```sh
python3 tools/ext4walk.py <path/to/system.img> /lib/hw     # 列目录
```

## 3. 从零再做一次"内核替换移植"（复刻本项目 TWRP）

1. 准备 donor：找同 SoC 家族（MT6735/6737/6753）、同分辨率 720×1280 的
   TWRP 镜像（本项目用 CUBOT Note Plus TWRP 3.6.1，见 `prebuilt/donor/`）。
2. `unpack_bootimg.py` 解出 donor 的 ramdisk，解包到工作目录
   （本项目工作目录：`prebuilt/twrp_ramdisk_root/`，已适配好）。
3. 适配 ramdisk：
   - **etc/recovery.fstab**：对照原机分区表修改（删掉不存在的分区如 frp；
     路径统一 `/dev/block/platform/mtk-msdc.0/11230000.msdc0/by-name/`）。
   - **default.prop**：加 `ro.hardware=mt6735`、`ro.sf.lcd_density=320`、
     `ro.product.device=Q5C`、`ro.build.product=q5c62q_njx`。
   - 若 donor 自带 `.ko` 模块（触摸等）：全部删除（本机驱动在内核内，乱 insmod 会崩）。
4. `repack_ramdisk.py` 重打包 → `mkbootimg_mtk.py` 套上 **原机内核** 和参数 → 刷机测试。
5. 若 donor ramdisk 的 UI 颜色/亮度/分辨率不对，改 default.prop 或换 donor 重来。

## 4. 刷机

### 4.1 fastboot（推荐）
```sh
adb reboot bootloader        # 或关机后按 音量上+电源 / 音量下+电源 进 fastboot
fastboot devices             # 确认识别
fastboot oem unlock          # 未解锁时执行（清 data，谨慎）
fastboot boot  prebuilt/TWRP-3.6.1_q5c62q_njx_20261018.img   # 可选：临时启动免刷入（视 LK 是否支持）
fastboot flash recovery prebuilt/TWRP-3.6.1_q5c62q_njx_20261018.img
fastboot reboot recovery     # 或手动 音量上+电源
```

**防覆盖**：系统内 `recovery-from-boot.p + install-recovery.sh` 会在下次开机把
stock recovery 刷回去。刷完 **先进 recovery**，在 TWRP 里删除
`/system/recovery-from-boot.p`（挂载 System 后文件管理器删）。

### 4.2 SP Flash Tool（线刷兜底）
装好后加载 `firmware/stock/MT6737T_Android_scatter.txt`，
只勾选 recovery 行并指定自制镜像，Download。注意别动 preloader 行。

### 4.3 mtkclient（备份/救砖）
```sh
python mtk r nvram,nvdata,protect1,protect2,lk,boot,recovery backup.bin   # 示例：分区级备份
python mtk w recovery prebuilt/TWRP-....img
```

### 4.4 首次刷机前必做备份（重要）
- `nvram`（IMEI/射频校准）、`nvdata`（基带数据）、`protect1/2`、`seccfg`、`lk`。
- 仓库内 `firmware/stock/` 已有 boot/recovery/lk/preloader/tee/logo/secro 原厂镜像可回滚。

## 5. 调试

- TWRP 启动后自动开启 adb（root 模式）：`adb shell` 直接进。
- 日志：`adb pull /tmp/recovery.log`（TWRP 菜单也有 Copy Log）。
- 黑屏排查顺序：
  1. `fastboot boot` 临时启动是否也黑屏（排除刷写问题）；
  2. 换 `prebuilt/donor/CUBOT_X18_...img`（不同 donor 对照）；
  3. 确认内核没被换掉（对比 sha256 `661f69a3...`）；
  4. 屏幕颜色/亮度问题 ≠ 黑屏：调 `TARGET_RECOVERY_PIXEL_FORMAT` 或亮度路径（见 device-tree.md）。
- 触摸无效：原机触摸驱动在内核里应当自动可用；若 donor ramdisk 自带了
  `TW_INPUT_BLACKLIST` 或触摸 `.ko`，清理后重打。

## 6. FAQ

| 问题 | 结论 |
|---|---|
| 能不能不刷、直接 fastboot boot 用？ | 视 LK 实现；不行就只能刷 recovery 分区（有原厂镜像可回滚，风险低） |
| 刷了 TWRP 进系统后 recovery 又变回官方？ | 见 4.1 防覆盖 |
| 16GB 机器要不要扩 vendor 分区？ | 只有做 Treble 才需要（见 hardware-analysis.md 第 7 节） |
| 64 位 recovery（arm64）能做吗？ | 内核是 32 位，recovery 必须是 32 位；64 位要整套换内核，工程量大 |
| CUBOT donor 为什么直接可用？ | 同 SoC（MT6737T）、同分辨率 720×1280、同为 TWRP 7.1.2/3.6.1 体系、内核同为 3.18 系 |
