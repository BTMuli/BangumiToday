# AnimeJaNai 推理桥

Windows x64 原生实现，通过项目自有 aji ABI v8 垫片接入固定版本 mpv 滤镜，
已接入应用的 AI 流畅 / AI 高质量选项及打包流程。
默认后端是 TensorRT；`backend=directml` 仅用于显式开发诊断。
组件缺失、引擎准备期间或推理失败时保持普通播放，不自动切换后端。

## 代码与帧路径

| 文件 | 职责 |
|---|---|
| `aji_abi.h` / `aji_bridge.cc` | 滤镜 ABI、配置、模型 slot、状态与错误边界 |
| `frame_contract.*` / `frame_converter.*` / `shaders/` | 输入准入、尺寸规划、GPU YUV ↔ FP16 RGB 转换 |
| `frame_pipeline.*` / `interop.*` | 帧编排、共享纹理、fence 与资源回收 |
| `cuda_api.*` / `trt_session.*` | CUDA 互操作、TensorRT 推理及 CUDA Graph 复用 |
| `trt_engine_cache.*` / `trt_precompile.*` | 本机引擎构建、缓存及设置页预编译入口 |
| `dml_session.*` / `node_placement.*` | ORT DirectML 执行与 GPU 节点分配诊断 |
| `gpu_capabilities.*` / `frame_budget.*` | 实际播放显卡能力查询、持续超预算与低吞吐检测 |
| `trusted_assets.*` / `*.lock.json` | 固定依赖、大小、SHA-256 与资源租约 |

```text
D3D11 NV12/P010 → FP16 RGB 纹理 → NCHW 张量
  TensorRT：CUDA 映射 / 拷贝 → 模型推理 → RGB 纹理
  DirectML：D3D12 共享纹理 / buffer → 模型推理 → RGB 纹理
→ GPU YUV 转换 → NV12/P010 输出帧
```

像素不经 CPU 回读。D3D11 提交使用完整的多线程临界区，与硬解和 ANGLE
协调共享上下文；跨 API 访问通过 CUDA map/unmap 或共享 fence 排序。
TensorRT 预热后尝试捕获 CUDA Graph，不可用时继续普通 enqueue。

## 播放契约

- 输入限 SDR、BT.709 limited、NV12/P010、无旋转、方形像素；固定 2×，
  补齐后的模型输出不超过 3840×2160。padding 复制边缘，输出裁去补齐部分。
- slot 1 为 Performance（AI 流畅），slot 2 为 Balanced（AI 高质量）。
  插值和预缩放尚未实现；DirectML 禁用 CPU EP 回退。
- 正常 GPU 播放、Anime4K 和 AI 使用 `hwdec=d3d11va`。AI 通过带 `conf`
  的 AnimeJaNai 滤镜启用；Dart 读回校验滤镜链，安装失败时撤销并恢复普通播放。
- AI 倍速播放在推理前按媒体时间选帧，保留 PTS 和音频时钟。目标推理频率
  不超过源视频正常帧率、显示刷新率与 60 FPS 上限；帧率未知时先按帧序号选帧。
  selector 与 AI 滤镜一并安装，倍速更新复用推理上下文；1× / 慢放不抽帧。
- AI 与 Anime4K 按视口、源比例及输出预算决定最终纹理尺寸，无需放大时恢复
  普通播放。窗口变化只调整纹理，同档滤镜保留；全屏过渡合并应用最终视口。
- GPU 持续超预算、低吞吐或实际 VO 丢帧触发降级；主动抽帧不计为 VO 丢帧。
  倍速变化重置统计并留稳定期，性能降级后降低倍速可重试。

配置由 [playback_inference.cmake](../../cmake/playback_inference.cmake) 生成，
与 `aji.dll` 同目录，格式为 UTF-8 `key=value`：

```ini
backend=tensorrt
runtime_dir=playback_inference
model_dir=playback_inference/models
default_slot=1
slot1=<Performance 模型文件名>
slot2=<Balanced 模型文件名>
```

相对路径按配置文件解析。应用生成播放配置时补入 `trt_dir` 和 `engine_cache`。
可用 `stats=<路径>` 覆盖默认 `%LOCALAPPDATA%/BangumiToday/animejanai-stats.txt`；
快照最多每秒更新一次，包含后端、GPU、阶段、尺寸、计数、GPU 耗时和错误原因。
`cpu*Ms` 字段用于区分上下文争用与提交耗时，不代表 GPU 时间。

## 准备与打包

在项目根目录执行，需要 VS x64 C++ 工具链、CMake 和 Windows SDK：

```powershell
./scripts/prepare_playback_inference.ps1
./scripts/verify_playback_inference_prerequisites.ps1 `
  -RuntimeDirectory .dart_tool/playback_inference/base/runtime

cmake -S windows/playback/inference -B .dart_tool/playback_inference/build `
  -A x64 `
  -DPLAYBACK_ORT_SDK_DIR="$PWD/.dart_tool/playback_inference/base/sdk/onnxruntime" `
  -DPLAYBACK_DML_SDK_DIR="$PWD/.dart_tool/playback_inference/base/sdk/directml" `
  -DPLAYBACK_TRT_SDK_DIR="$PWD/.dart_tool/playback_inference/base/sdk/tensorrt"
cmake --build .dart_tool/playback_inference/build --config Release
```

`fxc.exe` 在构建期生成内嵌着色器，可用 `PLAYBACK_FXC_EXECUTABLE` 指定路径。
准备脚本按锁文件校验并提取模型、ORT、DirectML、CRT 和 SDK 头文件，不执行
CRT 安装包。默认输出为 `.dart_tool/playback_inference/base`；现有输出只校验复用，
依赖或 NOTICE 变化时须重新准备资源，可用 `-OutputDirectory` 指定新目录。

开发构建和 release CI 已调用准备脚本。应用 CMake 构建垫片并安装为 `aji.dll`，
配置及四个 CRT DLL 放在可执行文件旁，基础推理资源与许可放在 `playback_inference/`。
SDK 头文件和 NVIDIA 大运行库不进入应用包；`verify_windows_bundle.ps1` 校验
哈希、x64 PE、依赖闭合与模型 slot。第三方归属见 [NOTICE](THIRD_PARTY_NOTICES.txt)，
固定 libmpv 的来源与 GPL 构建限制见 [libmpv NOTICE](../../licenses/libmpv/NOTICE.md)。

## TensorRT 组件与引擎

版本与文件以 [组件锁](trt-components.lock.json) 和 [SDK 锁](trt-sdk.lock.json) 为准。
当前固定 TensorRT 11.3.0.99 / CUDA 13.4，仅开放 SM89、SM90、SM100、SM120，
要求实际播放 D3D11 adapter 对应 NVIDIA CUDA device，驱动 API 版本至少 13040。

用户在设置中主动下载组件，选择画质不会自行下载。组件按架构校验并安装到
`%LOCALAPPDATA%/BangumiToday/playback-tensorrt/11.3.0.99/sm<架构>`；
不安装 Toolkit、驱动或修改 PATH。开发者可独立准备：

```powershell
./scripts/prepare_playback_tensorrt.ps1 -HeadersOnly
./scripts/prepare_playback_tensorrt.ps1 -ComputeCapability 89
```

基础准备脚本已自动执行 `-HeadersOnly`；组件参数也接受 `90`、`100`、`120`。
设置页安装后顺序预编译 720p / 1080p 的两个模型，其他尺寸按需构建。
构建使用受限子进程、GPU 锁、取消和 15 分钟超时；引擎校验并预热后原子发布，
缓存身份包含模型、尺寸、版本、驱动和 GPU。活动引擎有租约保护，缓存预算 4 GiB。

## 验证边界

已有隔离检查覆盖帧转换、同步、ABI、缓存、组件安装及纯 Dart 控制逻辑，
并做过 RTX 4070 Laptop 的独立原生链路短片段复测。
这些结果不代表完整 Flutter 播放或各支持架构均已验收。
长播放、PTS / seek / 暂停 / 连播、全屏切换、设备对齐与恢复、画质及端到端性能、
干净 Windows/MSIX 环境仍需手工验收；SM90 / SM100 / SM120 实机验证、
项目托管组件、完整 TensorRT 许可材料和固定 LGPL 构建仍待落实。
完整目标与后续工作见 [接入方案](../../../docs/feat/animejanai-onnx.md)。
