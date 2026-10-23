# QEMU 本机测试（L1）

用通用 ARM32 内核 + 我们的 Phase 1 initramfs 在电脑上跑 Linux 用户态，**完全不接触真机**。

> ⚠️ 它不是"设备模拟器"：QEMU 没有 MTK6737T 的显示/触摸/PMIC 等私有硬件模型，
> 也不会使用原机内核。它只用于调 **不依赖专用驱动的用户态逻辑**（init 脚本、
> busybox、网络配置等）。帧缓冲/触摸的最终验证请走真机（L2/L3，见 docs/dev-testing.md）。

## 安装依赖

```sh
# macOS
brew install qemu

# Ubuntu/Debian
sudo apt-get install -y qemu-system-arm
```

## 使用

```sh
# 1) 第一次运行会自动: 构建 initramfs + 下载 Debian ARM32 内核 (~56MB, 之后走缓存)
sh tools/qemu/run_phase1.sh

# 2) 常用参数
sh tools/qemu/run_phase1.sh --rebuild     # 先重建 initramfs 再启动
sh tools/qemu/run_phase1.sh --fb          # 打开显示窗口 (-device ramfb)
V168_QEMU_KERNEL=/path/vmlinuz sh tools/qemu/run_phase1.sh   # 自定义内核

# 退出 QEMU: 终端里按 Ctrl-A 再按 X
```

启动后你会看到一个类似 `v168-mtk6737t Linux Phase 1` 的串口 shell（我们的 init 检测到
`/dev/ttyAMA0` 自动进入），可以直接跑 busybox 命令、测试脚本。

## 内核从哪来 / 缓存

- 默认使用 **Debian stable `linux-image-*-armmp`**（通用多平台 ARMv7 内核）：
  `tools/qemu/fetch_kernel.py` 会解析 Debian 索引、校验 sha256、从 .deb 提取 `vmlinuz`，
  缓存到 `tools/qemu/.cache/vmlinuz-armmp`（不会提交到仓库）。
- 想用别的内核（如自编译 `multi_v7_defconfig`），用 `V168_QEMU_KERNEL=` 指定即可。

## 已知限制

| 项 | 说明 |
|---|---|
| 图形输出 | Debian 内核的 DRM/simpledrm 多为模块，`--fb` 下可能没有 `/dev/fb0`；进系统后 `fbconsole --info` 可确认。真机视觉验证请走 TWRP（L2） |
| 触摸 | QEMU 用 `virtio-tablet`（绝对坐标），与真机 evdev 触摸事件格式一致，可验证解析逻辑 |
| MTK 硬件 | 显示控制器/触摸 IC/modem/传感器 均无模型，不支持 |
| 原机内核 | 不能在 QEMU 启动（MTK 私有硬件），故 QEMU 只能验证用户态 |

## 与真机的对应关系

| 层 | 命令 | 写不写分区 |
|---|---|---|
| L1 本机 QEMU | `sh tools/qemu/run_phase1.sh` | 不接触 |
| L2 真机零写入 | `sh tools/dev/push_test.sh run ./fbconsole --info`（TWRP 里） | 不写 |
| L3 真机全流程 | `fastboot flash recovery out/linux-phase1.img && fastboot oem reboot-recovery` | 只写 16MB recovery |
