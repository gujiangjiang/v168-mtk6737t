#!/bin/sh
# ============================================================
# v168-mtk6737t Linux Phase 1 initramfs 构建器 (macOS/Linux 通用)
#
# 产物:
#   out/phase1-initramfs.cpio.gz   QEMU 直接 -initrd 使用
#   out/linux-phase1.img           刷入 recovery 分区的可启动镜像 (原机内核 + 本 initramfs)
#
# 说明:
#   - busybox 使用官方静态 armv7l 预编译 (sha256 锁定), 本地无需交叉工具链
#   - 可选: 把交叉编译好的 ARM32 程序放进 tools/linux/bin/ 会被自动打包
#     (例如 fbconsole; 由 .github/workflows/build_phase1_linux.yml 云端编译产出)
#   - 真机镜像始终用原机内核 device/q5c62q_njx/kernel (驱动闭源, 不可更换)
# ============================================================
set -eu

REPO=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
CACHE="$REPO/tools/linux/.cache"
STAGE="$REPO/tools/linux/.stage/root"
OUT="$REPO/out"
KERNEL="$REPO/device/q5c62q_njx/kernel"

BUSYBOX_URL="https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-armv7l"
BUSYBOX_SHA256="cd04052b8b6885f75f50b2a280bfcbf849d8710c8e61d369c533acf307eda064"

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

mkdir -p "$CACHE" "$OUT"
BB="$CACHE/busybox-armv7l"

if [ ! -f "$BB" ]; then
    echo ">>> 下载静态 busybox (armv7l, ~1.1MB) ..."
    curl -fL --connect-timeout 20 --retry 3 "$BUSYBOX_URL" -o "$BB.tmp"
    mv "$BB.tmp" "$BB"
fi

have=$(sha256_of "$BB")
if [ "$have" != "$BUSYBOX_SHA256" ]; then
    echo "错误: busybox sha256 不匹配"
    echo "  期望: $BUSYBOX_SHA256"
    echo "  实际: $have"
    exit 1
fi
echo ">>> busybox 校验通过"

# ---------- 组装 initramfs 根 ----------
rm -rf "$STAGE"
mkdir -p "$STAGE/bin" "$STAGE/dev" "$STAGE/proc" "$STAGE/sys" "$STAGE/tmp"

cp "$BB" "$STAGE/bin/busybox"
chmod 0755 "$STAGE/bin/busybox"
ln -sf busybox "$STAGE/bin/sh"

# overlay (init 等固定文件)
if [ -d "$REPO/tools/linux/overlay" ]; then
    (cd "$REPO/tools/linux/overlay" && tar cf - .) | (cd "$STAGE" && tar xf -)
    chmod 0755 "$STAGE/init"
fi

# 可选 ARM32 程序 (fbconsole 等, 来自本地编译或 CI 产物)
if [ -d "$REPO/tools/linux/bin" ]; then
    for f in "$REPO"/tools/linux/bin/*; do
        [ -f "$f" ] || continue
        cp "$f" "$STAGE/bin/"
        chmod 0755 "$STAGE/bin/$(basename "$f")"
        echo ">>> 打包 ARM32 程序: $(basename "$f")"
    done
fi

# ---------- 打包 ----------
RAMDISK="$OUT/phase1-initramfs.cpio.gz"
python3 "$REPO/tools/repack_ramdisk.py" "$STAGE" "$RAMDISK"

# ---------- 真机镜像 (原机内核 + initramfs) ----------
if [ -f "$KERNEL" ]; then
    IMG="$OUT/linux-phase1.img"
    python3 "$REPO/tools/mkbootimg_mtk.py" \
        --kernel "$KERNEL" \
        --ramdisk "$RAMDISK" \
        --out "$IMG" \
        --cmdline "bootopt=64S3,32N2,32N2 androidboot.selinux=permissive" \
        --name v168phase1
    SIZE=$(wc -c < "$IMG" | tr -d ' ')
    echo ">>> $IMG = $SIZE 字节 (recovery 分区 16777216)"
    if [ "$SIZE" -gt 16777216 ]; then
        echo "错误: 超过 recovery 分区!"
        exit 1
    fi
    python3 "$REPO/tools/unpack_bootimg.py" --info "$IMG"
else
    echo ">>> 未找到原机内核 $KERNEL, 跳过真机镜像"
fi

echo ">>> 完成:"
echo "    QEMU : $RAMDISK"
echo "    真机 : $OUT/linux-phase1.img  (fastboot flash recovery 后进 recovery 即启动)"
