# q5c62q_njx (MT6737T / V168) Recovery 源码移植工程

本目录是一套**可直接编译 TWRP 与 OrangeFox** 的设备树工程，核心策略：

> **保留原机 3.18.19 内核（预编译），只编译 recovery 用户态。**
> 这是 LCD 面板 / 触摸屏 / 传感器兼容性的唯一可靠保证——
> 本机为杂牌机（droi/FreemeOS 定制），没有公开的 kernel 源码，
> 面板驱动（LCM）是闭源集成在内核里的，换任何第三方内核都可能黑屏。

- SoC: MT6737T（4x Cortex-A53，Mali-T720，本机用户态 32 位）
- 内核: Linux 3.18.19（ARM32 zImage，原机 boot/recovery 同一内核）
- recovery 分区: 16MB（0x1000000），boot/recovery 加载地址 0x40008000 / 0x44000000
- 屏幕: 720x1280，触摸 i2c 0x5d，背光 `/sys/class/leds/lcd-backlight/brightness`

## 目录结构

```
源码移植/
├── device/q5c62q_njx/          # 设备树（TWRP 和 OrangeFox 通用）
│   ├── BoardConfig.mk          # 内核/分区/屏幕/功能开关
│   ├── omni_q5c62q_njx.mk      # 产品定义 (TWRP minimal manifest, omni 系)
│   ├── twrp_q5c62q_njx.mk      # 产品定义 (OrangeFox fox_12.1, twrp 系)
│   ├── AndroidProducts.mk
│   ├── Android.mk
│   ├── recovery.fstab          # 已适配本机分区（无 frp，含 nvram/nvdata/protect）
│   ├── vendorsetup.sh          # lunch 目标 + FOX_ 变量
│   └── kernel                  # 原机内核（预编译，勿替换）
└── .github/workflows/
    ├── build_twrp.yml          # 云端编译 TWRP（twrp-9.0 minimal manifest）
    └── build_orangefox.yml     # 云端编译 OrangeFox（fox_12.1）
```

## 方式一：GitHub Actions 云端编译（无需本地 Linux，推荐）

1. 在本目录初始化 git 仓库并推送到 GitHub（公开/私有均可）：

   ```sh
   cd 源码移植
   git init && git add -A && git commit -m "q5c62q_njx recovery tree"
   git remote add origin git@github.com:<你的用户名>/<仓库名>.git
   git push -u origin main
   ```

2. 打开仓库 **Actions** 页面，选择：
   - `Build TWRP (q5c62q_njx / MT6737T)` → Run workflow
   - `Build OrangeFox (q5c62q_njx / MT6737T)` → Run workflow

3. 完成后在对应 run 的 **Artifacts** 里下载：
   - TWRP：`TWRP-recovery-q5c62q_njx`（recovery.img）
   - OrangeFox：`OrangeFox-recovery-q5c62q_njx`（OrangeFox-unofficial-q5c62q_njx.img）

> 注意：免费 runner 磁盘 ~70GB。工作流已内置清盘步骤；
> 若 fox_12.1 同步仍空间不足，可改用付费大号 runner 或方式二。

## 方式二：本地 Linux 编译（Ubuntu 20.04/22.04，推荐 8GB+ RAM、100GB 磁盘）

### 依赖（两种编译通用）

```sh
sudo apt-get update
sudo apt-get install -y git-core gnupg flex bison gperf build-essential zip curl \
    zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 lib32ncurses5-dev \
    x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils \
    xsltproc unzip ccache python2 python-is-python2
```

### TWRP

```sh
mkdir -p ~/twrp && cd ~/twrp
repo init --depth=1 -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni.git -b twrp-9.0
repo sync -j8 --force-sync --no-clone-bundle --no-tags

mkdir -p device/mediatek
cp -r /path/to/源码移植/device/q5c62q_njx device/mediatek/q5c62q_njx

source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C
lunch omni_q5c62q_njx-eng
mka recoveryimage -j$(nproc)

# 产物: out/target/product/q5c62q_njx/recovery.img
```

### OrangeFox（fox_12.1，官方标准流程）

```sh
mkdir -p ~/OrangeFox_sync && cd ~/OrangeFox_sync
git clone https://gitlab.com/OrangeFox/sync.git
cd sync
./orangefox_sync.sh --branch 12.1 --path ~/fox_12.1

mkdir -p ~/fox_12.1/device/mediatek
cp -r /path/to/源码移植/device/q5c62q_njx ~/fox_12.1/device/mediatek/q5c62q_njx

cd ~/fox_12.1
export FOX_BUILD_DEVICE=q5c62q_njx
export FOX_VANILLA_BUILD=1
export OF_FORCE_PREBUILT_KERNEL=1
export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C
source build/envsetup.sh
lunch twrp_q5c62q_njx-eng
mka recoveryimage -j$(nproc)

# 产物: out/target/product/q5c62q_njx/OrangeFox-unofficial-q5c62q_njx.img
```

## 已知可调参数（首次实机测试后按需修改）

| 现象 | 修改 |
|---|---|
| 屏幕颜色红蓝颠倒 | `BoardConfig.mk` 中 `TARGET_RECOVERY_PIXEL_FORMAT` 在 `BGRA_8888` / `RGBA_8888` 之间切换 |
| 触摸无反应 | 检查 `TW_INPUT_BLACKLIST`；确认内核触摸驱动已内置（原机可用则会自动工作） |
| 亮度异常 | 调整 `TW_BRIGHTNESS_PATH` / `TW_MAX_BRIGHTNESS` / `TW_DEFAULT_BRIGHTNESS` |
| U 屏 UI 过小/过大 | `TW_THEME` 用 `portrait_hdpi`；或设 `TW_STATUS_ICONS_ALIGN` / `TW_CUSTOM_BATTERY_POS` |
| 镜像超出 16MB 分区 | 关闭 `TW_EXTRA_LANGUAGES`，或参考 OrangeFox wiki 开启体积裁剪 |

## 已交付的现成镜像（内核替换法，无需编译）

`编译产物/recovery/TWRP-3.6.1_q5c62q_njx_*.img` —— 由 CUBOT Note Plus (MT6737T, 720x1280,
TWRP 3.6.1, 内核 3.18.35) 的 recovery ramdisk + **本机原内核**重组而成，已适配本机分区表。

刷机与测试方法见项目根目录对话说明；核心步骤：

```sh
adb reboot bootloader          # 或关机后按 音量下(或音量上)+电源 进入 fastboot
fastboot oem unlock            # 仅解锁状态需要, 会清除数据
fastboot flash recovery TWRP-3.6.1_q5c62q_njx_*.img
# 刷完直接进 recovery(音量上+电源), 不要在进 recovery 前先启动系统
```

## 注意事项

- 严禁替换 `device/q5c62q_njx/kernel`（用了别的内核 = 黑屏/触摸失效风险）。
- 本机无 AVB/vbmeta 校验，刷 recovery 不需要额外签名。
- 编译产物仅供个人设备使用；源码按 GPL 发布时请一并公开本设备树。
