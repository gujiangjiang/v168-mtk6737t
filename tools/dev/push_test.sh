#!/bin/sh
# 免刷真机测试 (L2): 借助已刷好的 TWRP adb shell (root) 在真机上运行 ARM32 测试程序,
# 一个字节都不写分区 —— 适合调驱动无关的用户态逻辑 (命令行工具/输入/帧缓冲探测)。
#
# 用法:
#   sh tools/dev/push_test.sh push <本地文件...>       # 推送到设备 /tmp/devtest/
#   sh tools/dev/push_test.sh run  <本地文件> [参数..]  # 推送并执行
#   sh tools/dev/push_test.sh shell                    # 进入设备 shell (TWRP, root)
#   sh tools/dev/push_test.sh getevent                 # 实时查看触摸/按键原始事件
#   sh tools/dev/push_test.sh fbinfo                   # 探测帧缓冲设备节点
#
# 前置: 手机已进 TWRP, 且电脑上 `adb devices` 能看到设备 (需 platform-tools)。
set -eu

DEV_DIR=/tmp/devtest

need_adb() {
    command -v adb >/dev/null 2>&1 || {
        echo "错误: 未找到 adb; macOS 可安装: brew install --cask android-platform-tools"
        exit 1
    }
    adb get-state >/dev/null 2>&1 || {
        echo "错误: 没有可用的 adb 设备 (先让手机进入 TWRP, 再运行 adb devices 确认)"
        exit 1
    }
}

do_push() {
    [ "$#" -ge 1 ] || { echo "用法: $0 push <文件...>"; exit 2; }
    adb shell "mkdir -p $DEV_DIR"
    for f in "$@"; do
        if [ ! -f "$f" ]; then
            echo "跳过(不存在): $f"
            continue
        fi
        adb push "$f" "$DEV_DIR/$(basename "$f")" >/dev/null
        adb shell "chmod 0755 $DEV_DIR/$(basename "$f") 2>/dev/null || true"
        echo ">>> 已推送: $(basename "$f")"
    done
    adb shell "ls -la $DEV_DIR"
}

do_run() {
    [ "$#" -ge 1 ] || { echo "用法: $0 run <文件> [参数...]"; exit 2; }
    f=$1
    shift
    adb shell "mkdir -p $DEV_DIR"
    adb push "$f" "$DEV_DIR/$(basename "$f")" >/dev/null
    adb shell "chmod 0755 $DEV_DIR/$(basename "$f")"
    echo ">>> 执行: $DEV_DIR/$(basename "$f") $*"
    adb shell "$DEV_DIR/$(basename "$f") $*"
}

case "${1:-}" in
    push)
        shift
        need_adb
        do_push "$@"
        ;;
    run)
        shift
        need_adb
        do_run "$@"
        ;;
    shell)
        need_adb
        exec adb shell
        ;;
    getevent)
        need_adb
        echo ">>> 触摸测试: 用手指点/划屏幕, Ctrl+C 退出 (零写入)"
        exec adb shell getevent -lt
        ;;
    fbinfo)
        need_adb
        echo ">>> 帧缓冲节点:"
        adb shell 'for n in /dev/graphics/fb0 /dev/fb0; do [ -e "$n" ] && echo "  存在: $n"; done'
        adb shell "dmesg | grep -i -m5 'fb0\\|frame buffer' || true"
        ;;
    *)
        echo "用法: $0 {push|run|shell|getevent|fbinfo} ..."
        echo "  详见 docs/dev-testing.md"
        exit 2
        ;;
esac
