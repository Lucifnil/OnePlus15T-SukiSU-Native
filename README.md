# OnePlus 15T Native Kernel

面向 OnePlus 15T（PLZ110）的可审计内核重构项目。

当前阶段是第 1 阶段原厂提交纯净基线：直接同步一加官方 15T manifest，
把 Common 源码固定到当前 PLZ110 原厂 `boot.img` 标识的官方提交
`844001fb8721c3ee305f17a51628744997f787a0`，再使用官方 Kleaf
`//common:kernel_aarch64_dist` 目标构建 4K Android 16 GKI。不集成
KernelSU、SukiSU、SUSFS、KPM 或任何性能补丁。

原厂 `boot.img` 本身采用 GKI，因此 Common 目标不是兼容性问题。早期 r11
误用了较新的 `150cab866c66...` 源码提交；它与当前 OTA 厂商模块的 KMI
不兼容，真机表现为 Wi-Fi、移动数据、蓝牙和扬声器失效。r11 不可使用。

## 当前验证目标

第一次真机刷入发生在本阶段构建和静态检查全部通过之后。它只验证以下链路：

- 一加官方仓库中与原厂 boot 精确对应的 PLZ110 6.12.38 源码；
- 官方 Clang r536225 / Rust 1.82.0 / Kleaf 构建环境；
- 原厂 OTA 厂商模块所需的 GKI/KMI 兼容性；
- AnyKernel3 对 boot 分区的打包与刷写。

该基线没有 Root。只有它在真机上稳定启动后，才进入第 2 阶段原生 SukiSU
Built-in 后端实现。

## 源码纪律

- 所有主要输入均记录在 `manifest.lock`；
- CI 会保留并验证官方 manifest，再生成全提交锁定的本地 manifest；其中三个
  已被 CodeLinaro 删除、且不参与 Common GKI 构建的测试/模块仓库会被排除；
- 官方 manifest 中已删除的 Clang 与 kernel build-tools 镜像改由 Google AOSP
  的不可变官方提交提供，Clang 仍为 r536225；Common、SoC、设备及工具链仓库
  均按不可变提交检出；
- 官方 manifest 漏列但 Kleaf Common GKI 分析阶段必需的 `libcap`、`libcap-ng`
  由对应的 Google AOSP Android 16 不可变提交补齐；
- CI 会拒绝含 KSU、SUSFS、KPM、ADIOS、ReKernel 或 TCP Brutal 的源码；
- CI 会拒绝 Oplus 预编译 `vmlinux` 覆盖本次编译结果；
- 原厂 Common 提交早于当前官方 Kleaf 对 `vmlinux_oki` 输出的要求，构建时仅应用
  一行官方后续修复，将本次生成的 `vmlinux` 原样复制为 `vmlinux_oki`；
- CI 会拒绝不含原厂提交短哈希的构建产物；
- Release 附带最终 `.config`、原厂锚点、源码清单、内核版本和 SHA-256。

旧的第三方工作流和旧实验项目不属于本项目源码，只作为故障对照资料保留。
