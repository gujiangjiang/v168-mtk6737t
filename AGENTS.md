# AGENTS.md — 代理协作规则

> 本文件写给所有在此仓库工作的自动化代理（Agent）。人类协作者也建议遵守。
> 项目背景详见 [README.md](README.md) 与 [docs/hardware-analysis.md](docs/hardware-analysis.md)。

## 1. 环境规则

- **开发主机为 macOS**：无 Docker、无 Linux、无法本地编译 AOSP/TWRP/OrangeFox。
  - 需要编译产物时：走 `.github/workflows/` 云端流程（推送到 GitHub 后由 Actions 编译），
    或提示用户使用远程 Linux（Ubuntu 20.04/22.04）。
  - 切勿在 macOS 上尝试 `repo init/sync` 或安装重型构建依赖。
- 本机可用：`python3`（含本仓库 `tools/`）、`git`、`shasum`、`ruby(yaml)`、`curl`。
- 安装新工具/依赖前须先征得用户同意；优先使用纯 python3 脚本实现（跨平台）。
- 处理大文件（`firmware/`、`analysis/`）时注意：仓库含 ~120MB 二进制，克隆/操作勿用浅拷贝工具做破坏性改动。

## 2. 提交与推送规则（强制）

1. **每次变更必须提交**，且必须使用 `-m` 指定提交信息：

   ```sh
   git add -A
   git commit -m "<prefix>: <中文简述>"
   git push
   ```

2. 提交信息前缀约定：`feat`（新功能/新产物）、`fix`（修复）、`docs`（文档）、
   `ci`（工作流）、`artifacts`（镜像/解包产物变更）、`chore`（杂项）。
   示例：`artifacts: 更新 TWRP 镜像并刷新 SHA256SUMS`。
3. **一次逻辑变更一次提交**；不要攒大杂烩。改完文档立即提交，改完产物立即提交。
4. 工作区必须保持干净：任务结束时不允许有未提交的改动（`git status` 应为 clean）。
5. 禁止：`git commit`（无 -m 的交互式提交）、`--amend` 已推送提交、`push --force`、
   跳过 hooks、无意义空提交。
6. 提交前自查：`git status`、`git diff --stat`，确认没有误加二进制/垃圾文件
   （`.DS_Store` 已被 `.gitignore` 忽略）。

## 3. 目录约定

| 目录 | 放什么 | 不放什么 |
|---|---|---|
| `device/q5c62q_njx/` | recovery 设备树（TWRP/OFox 共用） | 构建中间产物 |
| `analysis/` | 官方固件解包产物（内核/ramdisk/DTB/日志/manifest） | 第三方镜像 |
| `prebuilt/` | 可直接刷写的成品与 donor 存档 | 未验证的半成品（需注明） |
| `tools/` | python3 分析/打包脚本 | 有平台依赖的脚本 |
| `firmware/stock/` | 原厂小镜像（boot/recovery/lk/tee/preloader/logo/secoc 等） | system/userdata/cache 等超大镜像 |
| `docs/` | 说明文档（中文，Markdown） | 临时笔记 |

## 4. 禁止事项

- 禁止上传/提交：`system.img`、`userdata.img`、`cache.img`、任何 >100MB 文件、
  密钥/证书/个人数据（nvram 转储、IMEI、本机校准数据、加密私钥）。
- 禁止擅自修改 `device/q5c62q_njx/kernel`（原机内核，sha256 `661f69a3…d96130`）
  与 `analysis/`、`firmware/stock/` 内的原始产物；除非任务明确要求且已在提交信息中说明理由。
- 禁止引入来源不明的二进制（新 donor 镜像必须注明出处链接与授权）。
- 禁止改动 `SHA256SUMS` 之外的镜像却不更新该文件。

## 5. 验证要求

- 修改/生成任何 boot 类镜像后：
  1. `python3 tools/unpack_bootimg.py --info <img>` 校验头部：
     必须满足 page=2048、kernel@`0x40008000`、ramdisk@`0x44000000`、
     tags@`0x4e000000`、cmdline 含 `bootopt=64S3,32N2,32N2`；
  2. 更新 `SHA256SUMS`（`shasum -a 256` 全量重算）；
  3. 镜像不得超过 recovery 分区 16777216 字节。
- 修改 ramdisk：用 `tools/repack_ramdisk.py` 重打，`cpio -it` 验证条目数一致。
- 修改 `.github/workflows/*.yml`：用 `ruby -ryaml -e "YAML.load_file('<file>')"` 校验语法。
- 修改文档：确保路径引用与实际文件一致。

## 6. 硬件关键参数（动手前必读）

```
SoC           MT6737T (4x Cortex-A53, Mali-T720)
Kernel        3.18.19 ARM32（zImage，追加 DTB；不可更换）
引导          LK + fastboot（支持 oem unlock、K64 跳转）
boot/recovery page_size 2048, kernel@0x40008000, ramdisk@0x44000000, tags@0x4e000000
recovery 分区 16777216 字节
屏幕          720x1280，触摸 i2c 0x5d，背光 /sys/class/leds/lcd-backlight/brightness
系统          Android 6.0 / 纯 32 位用户态（无 lib64）
```

## 7. 沟通规范

- 回答使用中文；命令行输出/日志保留原文。
- 变更后向用户汇报：改了什么、产物路径、校验值、下一步建议。
- 涉及风险操作（改分区、刷机、替换内核）必须先说明影响并等待用户确认。
