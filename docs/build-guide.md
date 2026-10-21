# 编译指南（TWRP / OrangeFox）

> 本机（macOS）无法编译 AOSP。两条正路：**GitHub Actions 云端**（推荐）
> 或 **本地 Linux**。两个目标都使用 `device/q5c62q_njx` 设备树 + 原机内核。

## 一、GitHub Actions 云端编译（推荐）

### 前置
1. 仓库已含 `.github/workflows/build_twrp.yml` 与 `build_orangefox.yml`。
2. 仓库 Settings → Actions → General → 确认允许运行 Actions（默认开）。

### 步骤
1. 打开仓库 **Actions** 页。
2. 左侧选择：
   - `Build TWRP (q5c62q_njx / MT6737T)`
   - `Build OrangeFox (q5c62q_njx / MT6737T)`
3. 右侧 **Run workflow** → 选 main 分支 → 运行。
   - TWRP 工作流会询问 **`twrp_branch`**（编译分支）：
     - `twrp-9.0`（**默认推荐**）：现代分支（TWRP 3.7 系），已实测在保留充电动画、关闭额外字体时可放进 16MB；
     - `twrp-8.1`：TWRP 3.2.3 时代，体积裕量更大——**需要中文界面（keep_fonts=true）时推荐用该分支**；
     - `twrp-7.1`：最小体积备选。
   - 还会询问两个功能/体积开关：
     - **`keep_fonts`（默认 false）**：额外字体/语言包。打开后引入 4.3MB CJK 字体（压缩后约 2.5MB），中文界面必需；twrp-9.0 下会超限，建议搭配 twrp-8.1；
     - **`keep_charger`（默认 true）**：关机充电动画二进制（约 1MB）。关闭可省体积，但黑屏充电无动画提示。
4. 完成后进入该次 run，底部 **Artifacts** 下载：
   - `TWRP-recovery-q5c62q_njx` → `recovery.img`
   - `OrangeFox-recovery-q5c62q_njx` → `OrangeFox-unofficial-q5c62q_njx.img`

> **运行页 Summary（推荐先看）**：工作流每次运行结束（无论成功/失败）都会在运行页面自动生成
> 汇总报告——成功时显示 **TWRP 版本、编译分支、额外字体/充电动画的实际状态**、
> 镜像大小、分区余量、SHA256、bootimg 头部校验与下载位置；
> 失败时显示错误摘要和 recovery root 体积明细（目录 TOP15 + 单文件 TOP40），无需翻日志即可定位问题。

### 工作流内部做了什么
| 步骤 | 说明 |
|---|---|
| Free disk space | 删除预装 SDK 等，腾出 ~30GB（fox_12.1 需要大空间） |
| Add swap 6G | 免费 runner 7GB 内存，防 ninja 编译 OOM |
| 依赖 | gcc 交叉工具链、python2（TWRP 9.0 构建脚本依赖）等 |
| 同步源码 | TWRP：minimal-manifest `twrp-9.0`；OFox：官方 `orangefox_sync.sh --branch 12.1` |
| 放置设备树 | 复制到 `device/mediatek/q5c62q_njx` |
| 编译 | `lunch omni_/twrp_q5c62q_njx-eng`（脚本内做了互相回退）+ `mka recoveryimage` |

### 预期耗时 / 失败处理
| 目标 | 耗时 | 备注 |
|---|---|---|
| TWRP | 30~60 分钟 | 成功率较高 |
| OrangeFox | 1~2 小时 | fox_12.1 源码约 45GB，免费 runner 空间紧张；若 `repo sync` 失败直接重跑（脚本支持断点续传） |

## 二、本地 Linux 编译（Ubuntu 20.04/22.04，≥8GB RAM，≥100GB 磁盘）

### 依赖（一次性）
```sh
sudo apt-get update
sudo apt-get install -y git-core gnupg flex bison gperf build-essential zip curl \
    zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 lib32ncurses5-dev \
    x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils \
    xsltproc unzip ccache rsync
# TWRP 9.0 需要 python2
sudo apt-get install -y python2 python-is-python2   # 失败则 python2.7
mkdir -p ~/bin && curl -s https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo && export PATH=$HOME/bin:$PATH
```

### TWRP
```sh
mkdir -p ~/twrp && cd ~/twrp
repo init --depth=1 -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni.git -b twrp-9.0
repo sync -j8 --force-sync --no-clone-bundle --no-tags

mkdir -p device/mediatek
cp -r <本仓库>/device/q5c62q_njx device/mediatek/q5c62q_njx

source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C
lunch omni_q5c62q_njx-eng
mka recoveryimage -j$(nproc)
# 产物: out/target/product/q5c62q_njx/recovery.img
```

### OrangeFox（单工作流 build_orangefox.yml，`fox_branch` 选项切换 9.0 / 12.1）
> ⚠️ 本机 3.18 内核 **只支持 gzip initramfs**：`lib/decompress.c` 的 compressed_formats
> 表中 gzip 解压函数指针有效（0xc0c3384c），lzma/xz/bzip2/lzo/lz4 全为 NULL。
> 任何 LZMA ramdisk 选项（`OF_USE_LZMA_COMPRESSION` / `FOX_USE_LZMA_COMPRESSION`）
> 都会打出内核无法解压、无法启动的镜像。fox_12.1 的 A12 核心大 ~14MB，无法进 16MB。

```sh
# 1) 同步 twrp-9.0 minimal manifest（与 TWRP 9.0 工作流同源）
repo init --depth=1 -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni.git -b twrp-9.0
repo sync -j$(nproc) --force-sync --no-clone-bundle --no-tags

# 2) 官方 manifest 补丁（把 vendor/recovery/OrangeFox.sh 挂进 build/core）
git clone --depth=1 https://gitlab.com/OrangeFox/sync.git
(cd build && patch -p1 < ../sync/legacy/patches/patch-manifest-fox_9.0.diff)   # sync 目录按实际路径

# 3) 换装 OrangeFox 源码
rm -rf bootable/recovery
git clone --depth=1 -b fox_9.0 https://gitlab.com/OrangeFox/bootable/Recovery.git bootable/recovery
(cd bootable/recovery && git -c url.https://gitlab.com/OrangeFox/misc/theme.git.insteadOf=git@gitlab.com:OrangeFox/misc/theme.git \
    submodule update --init --depth=1)   # CI 无 SSH key 必须用 insteadOf
git clone --depth=1 -b legacy https://gitlab.com/OrangeFox/vendor/recovery.git vendor/recovery
git clone --depth=1 -b android-9.0 https://gitlab.com/OrangeFox/external/busybox.git external/busybox

# 4) 设备树 + 构建
mkdir -p device/mediatek
cp -r <本仓库>/device/q5c62q_njx device/mediatek/q5c62q_njx
export FOX_VANILLA_BUILD=1 OF_VANILLA_BUILD=1
export ALLOW_MISSING_DEPENDENCIES=true LC_ALL=C
source build/envsetup.sh
lunch omni_q5c62q_njx-eng
mka recoveryimage -j$(nproc)
# 产物: out/target/product/q5c62q_njx/recovery.img + OrangeFox-*.img
# 超限时: export FOX_EXTREME_SIZE_REDUCTION=1 后重跑（官方裁剪, 删非默认字体/附加工具）
```

## 三、常见错误速查

| 报错 | 处理 |
|---|---|
| `python: not found` / py2 相关错误 | 装 python2；`python --version` 应为 2.7 |
| `NO KERNEL CONFIG` | 确保 `OF_FORCE_PREBUILT_KERNEL=1` 已 export |
| ninja OOM（compile 被 kill） | 加 swap；`mka -j2 recoveryimage` 降并发 |
| `repo sync` 中断/403 | 直接重跑；或 `--force-sync --no-clone-bundle` |
| 磁盘不足（fox_12.1） | 换大 runner / 本地机；或清 ccache |
| 镜像超过 16777216 字节 | 见 device-tree.md「镜像超 16MB」一行 |
| `lunch: unknown combo` | 确认 `device/mediatek/q5c62q_njx` 路径正确、vendorsetup.sh 存在 |
| `clang.real: error while loading shared libraries: libtinfo.so.5` | Android 9 预编译 clang 需要旧 ncurses：`sudo apt-get install -y libtinfo5 libncurses5`（工作流已内置） |
| OrangeFox sync 报 `repo: command not found` | 需要先装 repo 工具（工作流已内置；本地见第二章依赖部分） |
| 警告 `Node.js 20 is deprecated`（actions/checkout） | 无害提示；工作流已升级 checkout@v5 |
| `fb2png.c:... error: comparison of integers of different signs` | TWRP 9.0 老 bug（启用 `TW_INCLUDE_FB2PNG` 触发）；工作流含自动补丁 `(ssize_t)fb->size` |
| `add_lunch_combo is obsolete`（OrangeFox） | A12 中该函数是废弃 stub；vendorsetup.sh 已自动检测并跳过调用（A9/TWRP 不受影响），lunch 目标由 COMMON_LUNCH_CHOICES 注册 |
| `check_radio_versions.py ... SyntaxError: Missing parentheses in call to 'print'` | python2 脚本被 python3 执行；工作流已在最高优先级 `~/bin/python` 建 python2 软链（runner 的 /usr/local/bin/python 是 python3，会抢先生效） |
| OrangeFox `source build/envsetup.sh` 后无声退出（exit 1） | `bash -e` 与 A12 envsetup 尾部（addcompletions 加载补全脚本）偶发冲突；工作流构建步骤已 `set +e` 并输出 `>>> xxx rc=` 标记便于定位 |
| `Incorrect TARGET_ARCH_VARIANT, armv7-a-neon. Use armv8-a instead.`（OrangeFox） | A12 对 cortex-a53 强制 armv8-a；BoardConfig 已按 `PLATFORM_SDK_VERSION` 自动切换（SDK>30 用 armv8-a，A9 仍用 armv7-a-neon） |
| `recovery.img too large (NNN > 16777216)`（TWRP） | 实测根因：`TW_EXTRA_LANGUAGES := true` 引入的 **4.3MB CJK 字体**（twres/extra-languages/fonts）+ ~1MB 语言包（压缩后约 2.5MB）。BoardConfig 已默认关闭（`TW_EXTRA_LANGUAGES := false`），需要中文界面时改回并接受增大。工作流仍内置自动瘦身（strip + 重打包 + 去掉 charger）兜底；默认分支 `twrp-8.1`，坚持 `twrp-9.0` 请查看 Summary 的体积明细 |
| `Could not find ui.xml for TW_THEME: not set`（OrangeFox soong） | 通常是 lunch/dumpvars 先失败（如 arch variant 报错）的连锁反应；修好前置错误即消失 |
| ninja: `...libopenaes.so.toc ... missing and no known rule`（OrangeFox） | fox_12.1 上游语义 bug：`TW_EXCLUDE_ENCRYPTED_BACKUPS` 非空即链接 libopenaes，但模块只在值≠true 时安装；BoardConfig 已平台条件化（该树留空=正常排除，A9 用 true） |
| ninja: `...busybox... missing and no known rule`（TWRP，假设未来出现） | twrp-9.0 minimal manifest 无 external/busybox；`TW_USE_TOOLBOX` 必须保持 `true`（BoardConfig 已按平台固定） |
| `partitionmanager.cpp: ... use of undeclared identifier 'AID_MEDIA_RW'`（OrangeFox） | 关闭 `TW_INCLUDE_CRYPTO` 后该宏失去传递性 include 链（原本经 crypto 头文件带入）；宏值恒为 1023，工作流已内置 `tools/ofox_ci_patch.sh` 做等价替换（本地构建也要先跑该脚本） |
| `ld.lld: error: version script assignment of 'LIBBINDER' to symbol ... failed: symbol not defined`（OrangeFox 32位专属） | fox_12.1 的 `libbinder.arm32.map` 引用了 VNDK 变体中不再编译的历史符号（freeBuffer / ipcSetDataReference / TextOutput 运算符）；64 位设备不使用该 map 故无人踩坑。工作流已内置 `tools/ofox_ci_patch.sh` 自动从 map 移除（对本机 Android 6 无任何影响） |
| `You are attempting to build with the incorrect version of java ... required 1.8.x`（TWRP 7.1/8.1/9.0） | Android 7.1-9 构建系统强制 JDK 8（jammy 已无 openjdk-8 apt 包）；工作流已用 `actions/setup-java` 固定 temurin 8 |
| `schedtool: command not found`（`mka rc=127`，TWRP 7.1） | 旧版 envsetup 的 `mka` 依赖 schedtool；已加入依赖安装列表 |
| `could not make way for new symlink: root/vendor` / `cannot delete non-empty directory: root/vendor`（OrangeFox 打包阶段） | "无 vendor 分区"设备在 A12 ramdisk 组装 rsync 时的 目录/符号链接 冲突；`tools/ofox_ci_patch.sh` 已自动为 rsync 添加 `--force` |

## 四、产物校验（编完必做）

```sh
python3 tools/unpack_bootimg.py --info out/target/product/q5c62q_njx/recovery.img
# 期望: page_size=2048, kernel load=0x40008000, ramdisk load=0x44000000,
#       tags=0x4e000000, cmdline 含 bootopt=64S3,32N2,32N2
shasum -a 256 out/target/product/q5c62q_njx/*.img   # 与 SHA256SUMS 对照/追加
```
