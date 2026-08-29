# OnePlus 15T Native Kernel

面向 OnePlus 15T（PLZ110）的可审计内核重构项目。

当前阶段是第 1 阶段纯净基线：直接同步一加官方 15T manifest，使用官方
Kleaf `//common:kernel_aarch64_dist` 目标构建 4K Android 16 GKI，不集成
KernelSU、SukiSU、SUSFS、KPM 或任何性能补丁。

## 当前验证目标

第一次真机刷入发生在本阶段构建和静态检查全部通过之后。它只验证以下链路：

- 一加官方 PLZ110 6.12.38 源码；
- 官方 Clang r536225 / Rust 1.82.0 / Kleaf 构建环境；
- GKI/KMI 配置；
- AnyKernel3 对 boot 分区的打包与刷写。

该基线没有 Root。只有它在真机上稳定启动后，才进入第 2 阶段原生 SukiSU
Built-in 后端实现。

## 源码纪律

- 所有主要输入均记录在 `manifest.lock`；
- CI 会保留并验证官方 manifest，再生成全提交锁定的本地 manifest；其中四个
  已被 CodeLinaro 删除、且不参与 Common GKI 构建的测试/DDK 仓库会被排除；
- 官方 manifest 中已删除的 Clang 镜像改由 Google AOSP 同版本 r536225 的
  不可变提交提供；Common、SoC、设备及工具链仓库均按不可变提交检出；
- CI 会拒绝含 KSU、SUSFS、KPM、ADIOS、ReKernel 或 TCP Brutal 的源码；
- CI 会拒绝 Oplus 预编译 `vmlinux` 覆盖本次编译结果；
- Release 附带最终 `.config`、源码清单、内核版本和 SHA-256。

旧的第三方工作流和旧实验项目不属于本项目源码，只作为故障对照资料保留。
