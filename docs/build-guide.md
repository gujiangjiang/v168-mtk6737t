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
4. 完成后进入该次 run，底部 **Artifacts** 下载：
   - `TWRP-recovery-q5c62q_njx` → `recovery.img`
   - `OrangeFox-recovery-q5c62q_njx` → `OrangeFox-unofficial-q5c62q_njx.img`

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

## 四、产物校验（编完必做）

```sh
python3 tools/unpack_bootimg.py --info out/target/product/q5c62q_njx/recovery.img
# 期望: page_size=2048, kernel load=0x40008000, ramdisk load=0x44000000,
#       tags=0x4e000000, cmdline 含 bootopt=64S3,32N2,32N2
shasum -a 256 out/target/product/q5c62q_njx/*.img   # 与 SHA256SUMS 对照/追加
```
