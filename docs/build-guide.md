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
     - `twrp-8.1`（**默认推荐**）：TWRP 3.2.3 时代，体积天然小，同类 MT6737 机型 16MB 分区已验证可容纳；
     - `twrp-9.0`：现代分支（TWRP 3.6.x），但实测**即使全量裁剪后镜像仍 ~18.7MB**，超出本机 16MB 分区，需要继续瘦身才能用；
     - `twrp-7.1`：最小体积备选。
4. 完成后进入该次 run，底部 **Artifacts** 下载：
   - `TWRP-recovery-q5c62q_njx` → `recovery.img`
   - `OrangeFox-recovery-q5c62q_njx` → `OrangeFox-unofficial-q5c62q_njx.img`

> **运行页 Summary（推荐先看）**：工作流每次运行结束（无论成功/失败）都会在运行页面自动生成
> 汇总报告——成功时显示镜像大小、分区余量、SHA256、bootimg 头部校验与下载位置；
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

### OrangeFox（官方标准流程）
```sh
mkdir -p ~/OrangeFox_sync && cd ~/OrangeFox_sync
git clone https://gitlab.com/OrangeFox/sync.git && cd sync
./orangefox_sync.sh --branch 12.1 --path ~/fox_12.1

mkdir -p ~/fox_12.1/device/mediatek
cp -r <本仓库>/device/q5c62q_njx ~/fox_12.1/device/mediatek/q5c62q_njx

cd ~/fox_12.1
# 应用已知源码补丁(AID_MEDIA_RW 等, 与 CI 一致)
sh <本仓库路径>/tools/ofox_ci_patch.sh
export FOX_BUILD_DEVICE=q5c62q_njx
export FOX_VANILLA_BUILD=1
export OF_FORCE_PREBUILT_KERNEL=1
export ALLOW_MISSING_DEPENDENCIES=true
source build/envsetup.sh
lunch twrp_q5c62q_njx-eng
mka recoveryimage -j$(nproc)
# 产物: out/target/product/q5c62q_njx/OrangeFox-unofficial-q5c62q_njx.img
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
| `recovery.img too large (NNN > 16777216)`（TWRP） | 实测 twrp-9.0 分支即使全量裁剪后 ramdisk 仍 ~12.5MB（镜像 18.7MB），超出 16MB 分区预算（ramdisk 上限 10.49MB）→ TWRP 工作流默认已换 `twrp-8.1`；如坚持 9.0，看运行 Summary 的 ⚠️ 超限分支 + "recovery root 体积明细" 继续定裁剪方向 |
| `Could not find ui.xml for TW_THEME: not set`（OrangeFox soong） | 通常是 lunch/dumpvars 先失败（如 arch variant 报错）的连锁反应；修好前置错误即消失 |
| ninja: `...libopenaes.so.toc ... missing and no known rule`（OrangeFox） | fox_12.1 上游语义 bug：`TW_EXCLUDE_ENCRYPTED_BACKUPS` 非空即链接 libopenaes，但模块只在值≠true 时安装；BoardConfig 已平台条件化（该树留空=正常排除，A9 用 true） |
| ninja: `...busybox... missing and no known rule`（TWRP，假设未来出现） | twrp-9.0 minimal manifest 无 external/busybox；`TW_USE_TOOLBOX` 必须保持 `true`（BoardConfig 已按平台固定） |
| `partitionmanager.cpp: ... use of undeclared identifier 'AID_MEDIA_RW'`（OrangeFox） | 关闭 `TW_INCLUDE_CRYPTO` 后该宏失去传递性 include 链（原本经 crypto 头文件带入）；宏值恒为 1023，工作流已内置 `tools/ofox_ci_patch.sh` 做等价替换（本地构建也要先跑该脚本） |

## 四、产物校验（编完必做）

```sh
python3 tools/unpack_bootimg.py --info out/target/product/q5c62q_njx/recovery.img
# 期望: page_size=2048, kernel load=0x40008000, ramdisk load=0x44000000,
#       tags=0x4e000000, cmdline 含 bootopt=64S3,32N2,32N2
shasum -a 256 out/target/product/q5c62q_njx/*.img   # 与 SHA256SUMS 对照/追加
```
