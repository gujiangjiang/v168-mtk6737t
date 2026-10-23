# 开发与测试指南（免刷机 / 少刷机）

> 目标：改代码不再"每改一次就刷一遍机"，把刷写次数压到里程碑级别。
> 配套脚本：[`tools/dev/push_test.sh`](../tools/dev/push_test.sh)（QEMU 环节随 Phase 1 提供）。

## 0. 先消除焦虑：我们从未刷过 system

| 操作 | 单次写入量 | 1000 次累计 | 说明 |
|---|---|---|---|
| 刷 recovery（我们唯一在做的事） | 16MB | **16.8GB** | eMMC 寿命通常数十 TB 级 + 磨损均衡，可忽略 |
| 刷 system.img（从来不做） | ~3GB | 3000GB | 这才需要警惕 |

结论：恢复/测试性刷 recovery 分区完全不用担心 NAND 寿命；**system 分区定终身，只在必要时动一次**。

## 1. 测试金字塔

### L1 · 本机 / QEMU（零设备参与）

调用户态逻辑：init 脚本、fb 绘制、输入解析、网络配置。

```sh
# 在 macOS 上玩 ARM32 用户态 (Phase 1 将提供 tools/qemu/run_phase1.sh; 需 brew install qemu)
```

- 通用 ARM 内核只当"司机"，不代表真机驱动；
- `-device ramfb` 提供 `/dev/fb0`、`virtio-tablet` 提供触摸事件，足以调通程序逻辑；
- 同样的 initramfs 稍后刷到真机做最终验证。

### L2 · 真机零写入（把已刷的 TWRP 当测试容器）

TWRP 的 adb shell 是 root，能直接在真机上跑 ARM32 程序、读触摸和探测帧缓冲——**不写任何分区**：

```sh
# 手机进 TWRP 后:
sh tools/dev/push_test.sh run  ./fbconsole               # 跑推送的程序
sh tools/dev/push_test.sh getevent                       # 真实触摸事件流
sh tools/dev/push_test.sh fbinfo                         # 帧缓冲节点探测
sh tools/dev/push_test.sh shell                          # 交互 shell
```

能验证什么：
- ARM32 二进制兼容性、系统调用、busybox 工具链；
- **真实触摸**（`/dev/input/eventX`，evdev 允许多个读者，与 TWRP 互不干扰）；
- **真实屏幕**：`/dev/graphics/fb0` 的 FBIOGET_VSCREENINFO / 直接写像素（TWRP 只在自己刷新时重绘，静态图案会停留，按一下键恢复 UI）；
- 背光/电量/温度等 sysfs 探测。

### L3 · 真机全流程（仅里程碑刷一次）

只有 initramfs 引导逻辑变化才需要刷 recovery（16MB、零风险、随时可刷回原厂或 TWRP）：

```sh
fastboot flash recovery out/linux-phase1.img
fastboot oem reboot-recovery
```

> 附：本机 LK 的 fastboot 命令表（实测自 `firmware/stock/lk.bin`）只有
> `download/erase/flash/getvar/oem/reboot-bootloader`，**没有 `boot:`**，
> 因此不存在 `fastboot boot` 免刷启动，L3 必须写 recovery 分区（写入量可忽略）。

## 2. Phase 2 的零写入终局架构

Linux rootfs 放 **SD 卡**（或 `/data`），recovery 分区里只放几乎不变的 initramfs 引导器：

- 改应用/配置 → 拔卡插电脑改文件，eMMC 零写入；
- 改引导逻辑 → 才需要刷 recovery；
- 真机调用户态时也可以先在 TWRP shell 里 `chroot` 跑 rootfs（不写 eMMC）。

## 3. 建议节奏

1. 日常改代码：L1（QEMU）跑通；
2. 需要真机确认：L2（TWRP 容器）验证输入/显示/二进制；
3. 里程碑：L3 刷 recovery 一次性验证完整引导链。
