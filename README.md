# OnePlus 15T Native SukiSU Kernel

面向 OnePlus 15T（PLZ110）的可审计 Native 内核项目。源码直接来自一加官方
15T manifest，Common 固定到当前 PLZ110 原厂 `boot.img` 对应的官方提交
`844001fb8721c3ee305f17a51628744997f787a0`，由官方 Kleaf
`//common:kernel_aarch64_dist` 目标构建 4K Android 16 GKI。

项目提供三个 CI 变体：

- `baseline`：不包含 KernelSU、SukiSU、SUSFS、KPM 或性能补丁的纯净基线；
- `sukisu_builtin`：在同一原厂 Common 提交上集成官方 SukiSU Ultra
  `v4.1.3`，使用 `CONFIG_KSU=y` 的 Built-in 后端，不启用 SUSFS 或 KPM。
- `sukisu_susfs_builtin`：在上述 Built-in 版本上集成官方 SUSFS `v2.1.0`，
  启用隐藏功能、禁用内核日志且不启用 KPM。SUSFS 官方明确标记为实验性功能，
  此变体只有通过临时启动和完整真机回归后才会作为正式 Release 发布。

## 已确认的兼容性根因

早期 r11 误用了较新的 `150cab866c66...` Common 提交，与当前 OTA 厂商模块
不兼容，真机表现为 Wi-Fi、移动数据、蓝牙和扬声器失效。r11 不可使用。

后续精确回到原厂源码和内核版本后，公开的通用 Common Kleaf 目标仍会生成完整
的 `protected_module_names_list`。PLZ110 原厂系统实际携带并加载未签名的
GKI/厂商模块；公开目标的保护列表会拒绝其中 103 个模块。真机诊断捕获到
`rfkill: exports protected symbol rfkill_alloc`，失败内核只加载 567 个模块，
导致 `cfg80211`、`mac80211`、QCA Wi-Fi、蓝牙及其依赖无法加载。

当前构建保持与原厂一致的 `CONFIG_MODULE_SIG_PROTECT=y` 和配置字符串，但将
构建期生成的 ARM64 保护模块名列表置空。这与原厂内核能够加载同一批未签名模块
的实际策略一致。配合原厂 Clang build `14043575`、GENDWARFKSYMS 和 Zstd
DWARF 设置后，抽查到的 434 个公共模块 CRC 与原厂模块全部一致。

## 真机验证状态

`baseline` r22、`sukisu_builtin` r23 和 `sukisu_susfs_builtin` r30 均已在
PLZ110 `PLZ110_16.0.10.500_CN01` 上完成真机启动验证。r30 先通过
`fastboot boot` 临时启动，再以带 AVB footer 的镜像写入活动 `boot_a`，冷启动后
确认：

- 内核版本严格为
  `6.12.38-android16-5-g844001fb8721-ab14552068-4k`；
- SukiSU Ultra 显示 `工作中 <Built-in>`，驱动和管理器版本同为 `40796`，
  完整版本为 `v4.1.3-0ca744a8@main`，无版本不匹配警告；
- SuSFS 显示 `v2.1.0 (Tracepoint Syscall Redirect)`；`post-fs-data`、`services`
  和 `boot-completed` 三个 ksud 阶段均成功，Root allowlist 正常加载；
- 668 个模块正常加载，仅比一次原厂快照少两个按需模块；`cfg80211`、
  `mac80211`、`qca_cld3_peach_v2` 和蓝牙模块均正常；
- Wi-Fi 和 5G 移动数据均能独立联网，IP 与 DNS 复测无丢包；
- 蓝牙、48 kHz 音频栈、振动器、加速度计、陀螺仪、四个相机设备和
  1216×2640/60–165 Hz 显示链路均正常；
- SELinux 保持 `Enforcing`，pstore 为空，未发现 panic、Oops、watchdog bite、
  ANR 或由 r30 引入的驱动回归。

## 刷入说明

优先在 SukiSU 管理器中刷入 Release 的 AnyKernel3 ZIP；它只更新 `boot`，不需要
也不应先刷 LKM，不会改动 `init_boot`。保留与当前 OTA 匹配的原厂 `boot.img`
作为回退文件。

直接使用 `fastboot flash boot_a` 时，镜像必须带有效的 Android Verified Boot
footer。仅把 Kleaf 的 `Image` 与空 ramdisk 打包后补零到分区大小，虽然可以用
`fastboot boot` 临时启动，但永久写入后会退回 bootloader。Release 中如提供
`*-avb-boot.img`，它仅面向已解锁且处于上述同一 PLZ110 固件的设备。

## 源码纪律

- 所有主要输入均记录在 `manifest.lock`；
- CI 会保留并验证官方 manifest，再生成全提交锁定的本地 manifest；其中三个
  已被 CodeLinaro 删除、且不参与 Common GKI 构建的测试/模块仓库会被排除；
- 官方 manifest 中已删除的 Clang 与 kernel build-tools 镜像改由 Google AOSP
  的不可变官方提交提供；Clang 精确固定为 r536225 build `14043575`；
- 官方 manifest 漏列但 Kleaf 分析阶段必需的 `libcap`、`libcap-ng` 由对应的
  Google AOSP Android 16 不可变提交补齐；
- `baseline` 会拒绝 KSU；`sukisu_builtin` 只允许锁定版本的 Built-in KSU；
  `sukisu_susfs_builtin` 还会逐项验证锁定的 SUSFS 功能并拒绝日志。三个变体
  都会拒绝 KPM、ADIOS、ReKernel 和 TCP Brutal；
- CI 会拒绝 Oplus 预编译 `vmlinux` 覆盖本次编译结果；
- 原厂 Common 提交早于当前官方 Kleaf 对 `vmlinux_oki` 输出的要求，构建时仅应用
  一行官方后续修复，将本次生成的 `vmlinux` 原样复制为 `vmlinux_oki`；
- CI 严格校验原厂内核 release、精确 Clang build、SukiSU 版本码、最终
  `.config`、补丁哈希和构建产物 SHA-256；
- Release 附带最终 `.config`、原厂锚点、源码清单、内核版本和 SHA-256。

旧的第三方工作流和旧实验项目不属于本项目源码，只作为故障对照资料保留。
