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

r30 的高负载游戏复测又定位到一项独立问题：原厂
`oplus_bsp_sched_ext.ko` 携带 split BTF，其类型引用以原厂
`vmlinux` 的 164887 个基础类型为固定 ID 空间。普通源码基线仍保持该空间，
但 Built-in SukiSU/SUSFS 让自动生成的 BTF 增至 165497 个类型。内核因
`CONFIG_MODULE_ALLOW_BTF_MISMATCH=y` 继续加载模块，却无法注册模块 BTF，随后
`hmbird_kfunc_register` 失败，风驰 BPF 调度器以 `-EINVAL` 停止。

修复构建会在最终链接前注入由同一官方提交、同一配置和同一锁定工具链生成的
纯净源码基线 BTF，再正常执行 `resolve_btfids`。CI 同时锁定 BTF 哈希、类型数、
类型区和字符串区长度，并禁止此模式下修改任何已跟踪的类型定义头文件。这样既
保持厂商 split BTF 所需的精确 ID 空间，也不会把原厂固件中的二进制 BTF 当作
构建输入。

## 真机验证状态

`baseline` r22、`sukisu_builtin` r23 和 `sukisu_susfs_builtin` r30 均已在
PLZ110 `PLZ110_16.0.10.500_CN01` 上完成基础启动验证。r30 先通过
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

上述基础验证没有覆盖风驰 split BTF。后续《三角洲行动》实测确认 r30 的 Hmbird
管理器停止、游戏 HAL 持续提交 critical-thread 失败，并在约 6 W 功耗下出现 CPU
传感器 90 °C 以上的异常调度状态。因此 r30 不再视为可发布版本；必须在新的
BTF 兼容构建通过模块 BTF 注册、Hmbird 运行态和受控温度回归后才能替代它。

BTF 兼容修复已在诊断 r32 和关闭 `CONFIG_KSU_DEBUG` 的生产 r33 上完成定向真机
验证。两个构建的最终 BTF 均精确保持 164887 个基础类型，离线合并原厂
`oplus_bsp_sched_ext.ko` 成功；r33 写入活动 `boot_a` 后确认模块 BTF 已注册、
`oplusHmbirdBpfManager` 持续运行且 `sys.oplus.hmbird.manager.enable=1`，未再出现
BTF、kfunc 或 `-EINVAL` 错误。启动《三角洲行动》时场景稳定切换到
`hmbird_II`，`sched_ext` 变为 `enabled`，退出后正常恢复 `none/disabled`。

r32 的 60 秒启动/加载受控测试中，CPU 传感器峰值 69.4 °C、瞬时功耗峰值约
5.29 W、机身峰值 32.2 °C、电池峰值 30.4 °C，未触发安全停止；r33 生产版的
短时复核同样成功挂载调度器，CPU 峰值 71.7 °C。该结果只覆盖游戏启动和加载，
不等同于完整对局压力回归，因此 r33 已验证本次风驰修复，但仍不会在完整对局
复测前标记为正式 Release。

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
- SukiSU 变体会验证并注入锁定的纯净源码基线 BTF；最终 `vmlinux` 的 BTF
  SHA-256 和 164887 个基础类型必须精确匹配，且 `resolve_btfids` 必须成功；
- 原厂 Common 提交早于当前官方 Kleaf 对 `vmlinux_oki` 输出的要求，构建时仅应用
  一行官方后续修复，将本次生成的 `vmlinux` 原样复制为 `vmlinux_oki`；
- CI 严格校验原厂内核 release、精确 Clang build、SukiSU 版本码、最终
  `.config`、补丁哈希和构建产物 SHA-256；
- Release 附带最终 `.config`、原厂锚点、源码清单、内核版本和 SHA-256。

旧的第三方工作流和旧实验项目不属于本项目源码，只作为故障对照资料保留。
