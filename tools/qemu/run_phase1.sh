#!/bin/sh
# QEMU 本机测试 (L1): 用通用 ARM32 内核 + 我们的 Phase 1 initramfs 启动
#   —— 不接触真机, 适合调试 init 脚本/busybox/用户态程序逻辑
#
# 依赖: qemu-system-arm, python3
#   macOS : brew install qemu
#   Ubuntu: sudo apt-get install -y qemu-system-arm
#
# 用法:
#   sh tools/qemu/run_phase1.sh              # 串口交互 shell (默认)
#   sh tools/qemu/run_phase1.sh --fb         # 额外打开显示窗口 (ramfb; 需内核带 fb 支持)
#   sh tools/qemu/run_phase1.sh --rebuild    # 先重建 initramfs 再启动
#   V168_QEMU_KERNEL=/path/vmlinuz sh tools/qemu/run_phase1.sh   # 指定自定义内核
#
# 退出 QEMU: 终端里按 Ctrl-A 然后按 X
set -eu

REPO=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
CACHE="$REPO/tools/qemu/.cache"
KERNEL=${V168_QEMU_KERNEL:-"$CACHE/vmlinuz-armmp"}
RAMDISK="$REPO/out/phase1-initramfs.cpio.gz"
REBUILD=0
FB=0

while [ $# -gt 0 ]; do
    case "$1" in
        --rebuild) REBUILD=1 ;;
        --fb) FB=1 ;;
        --kernel) shift; KERNEL=$1 ;;
        *) echo "未知参数: $1"; exit 2 ;;
    esac
    shift
done

command -v qemu-system-arm >/dev/null 2>&1 || {
    echo "错误: 未安装 qemu-system-arm"
    echo "  macOS : brew install qemu"
    echo "  Ubuntu: sudo apt-get install -y qemu-system-arm"
    exit 1
}

if [ "$REBUILD" = "1" ] || [ ! -f "$RAMDISK" ]; then
    sh "$REPO/tools/linux/build_phase1_initramfs.sh"
fi

if [ ! -f "$KERNEL" ]; then
    echo ">>> 首次运行: 自动获取 Debian ARM32 内核 (约 56MB, 之后走缓存)"
    python3 "$REPO/tools/qemu/fetch_kernel.py" "$CACHE"
fi

echo ">>> 内核  : $KERNEL"
echo ">>> initrd: $RAMDISK"
echo ">>> 启动 QEMU (退出: Ctrl-A 再按 X)"
echo

set -- qemu-system-arm \
    -M virt -cpu cortex-a15 -m 1024 -smp 4 \
    -kernel "$KERNEL" \
    -initrd "$RAMDISK" \
    -append "console=ttyAMA0 rdinit=/init" \
    -netdev user,id=net0 -device virtio-net-device,netdev=net0 \
    -serial mon:stdio
if [ "$FB" = "1" ]; then
    set -- "$@" -device ramfb
else
    set -- "$@" -display none
fi
exec "$@"
