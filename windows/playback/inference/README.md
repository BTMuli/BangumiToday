# AnimeJaNai DirectML 推理桥

Windows x64 原生实现，使用项目自有 aji ABI v8 垫片接入固定版本 mpv 滤镜。
应用已接入两档 AI 选项与打包；真实播放器验收仍未完成，P0 尚未通过。
完整目标与未实施设计见 [接入方案](../../../docs/feat/animejanai-onnx.md)。
默认 AI 实时超分要求实际播放显卡为 NVIDIA，且 TensorRT 组件和本机引擎就绪。
准备期间保持普通播放，准备或推理失败不自动切换 DirectML；显式
`backend=directml` 仅用于开发诊断，主包配置和缺少 backend 字段的旧配置均使用 TRT。

## 组成与帧路径

| 文件 | 职责 |
|---|---|
| `aji_abi.h` / `aji_bridge.cc` | 滤镜接口、配置解析、slot、诊断与错误边界 |
| `frame_contract.*` / `frame_converter.*` | 色彩和几何准入、D3D11 转换资源 |
| `frame_pipeline.*` / `interop.*` | 帧编排、D3D11/D3D12 共享纹理和 fence、资源回收 |
| `dml_session.*` / `node_placement.*` | ORT DirectML GPU 张量执行及节点分配诊断 |
| `frame_budget.*` | GPU 耗时窗口与降级判断 |
| `trusted_assets.*` / `dependencies.lock.json` | 固定大小、SHA-256 与只读资源租约 |
| `gpu_capabilities.*` | 查询实际播放 adapter 的 CUDA 架构，尚未实现 TRT |
| `shaders/frame_shaders.hlsl` | 构建期编译的 YUV ↔ FP16 RGB 转换着色器 |

```text
D3D11 YUV SRV → 共享 R16_FLOAT 平面 RGB
D3D12 纹理 → FP16 NCHW buffer → DirectML → 输出 buffer
D3D12 buffer → 共享 R16_FLOAT 输出纹理
D3D11 RGB → 亮度/色度平面 → D3D12 拷贝 → NV12/P010 输出帧
```

无 CPU 像素回读。张量留在 D3D12，跨 API 共享纹理，不能共享 D3D11 buffer。
共享纹理同时带 `SHARED` 与 `SHARED_NTHANDLE`；D3D11 context4 与 D3D12 queue
通过同一共享 fence 双向排序，DirectML 也使用该队列。模型宽度补到 128 的倍数，
保证 placed-footprint 行 pitch 对齐 256 字节。资源销毁包含有界等待，并捕获设备移除异常。

## 输入契约与滤镜控制

- 仅验证 SDR、BT.709 limited、NV12/P010、无旋转、方形像素；固定 2×，
  可见输出不超过 3840×2160。padding 为边缘复制，输出裁去补齐部分。
- 输入色度采用 Catmull-Rom 插值；输出色度采用 2×2 盒式平均，仍需实际画质对比。
- DirectML 会话禁用 CPU EP 回退和 memory pattern；不支持完整 GPU 图时创建失败。
- slot 1 为 Performance（AI 流畅），slot 2 为 Balanced（AI 高质量）。
  TensorRT 引擎后台构建通过 aji_poll 完成通知；插值和预缩放暂未实现。
- 播放器初始使用普通解码，仅在视频满足 AI 条件后先设 `hwdec=d3d11va`，再设
  `vf=animejanai=slot=N:conf=animejanai.conf`。固定滤镜必须收到 `conf` 或 `engine`
  才加载 `aji.dll`，仅给 slot 会旁路复制。关闭时先清 vf，再恢复 `d3d11va-copy`。
- Dart 通过 `MPV_FORMAT_NODE` 读回 vf，校验名称、enabled、slot 与非空 conf。
  安装开始即记录待清理状态，部分安装失败也会撤销滤镜并恢复普通播放。
- AI 与 Anime4K 共用最终纹理策略：按视口物理像素、源比例、启停滞回及输出预算
  计算尺寸；无需放大时恢复普通播放。模型仍固定 2×，mpv 将滤镜结果缩放到目标纹理。
  窗口大小变化只调整纹理，不重装同档滤镜；显式请求尺寸并确认输出，超时则恢复普通播放。
- GPU 帧预算为 `1000/fps`：2 秒窗口、至少 10 个样本，连续 3 个有效窗口的
  GPU 中位耗时超预算会报错。Dart 另采样 mpv 的 VO 丢帧计数和估计帧号，
  连续 3 个窗口丢帧率超过 1% 时降级；暂停、seek、计数重置与不可用样本不计入。
  原生错误日志同样触发恢复，主动换档或新媒体才重试。

配置是 UTF-8（允许 BOM）的 `key=value` 文件，放在 aji.dll 旁：

```ini
backend=tensorrt
runtime_dir=playback_inference
model_dir=playback_inference/models
default_slot=1
slot1=<Performance 模型文件名>
slot2=<Balanced 模型文件名>
```

相对路径按配置文件解析。mpv 给出的配置路径不存在时，垫片尝试自身目录的
`animejanai.conf`。可选 `stats=<路径>` 指定诊断快照，否则写入用户本地应用数据目录。
快照最多每秒更新一次，包含 phase、slot、模型、尺寸、计数、GPU 耗时、ticket 和 reason；
应用按 Player / 配置代次读取快照，显示实际后端、GPU 和准备状态；编译日志路径
属于同一任务，界面每两秒读取末尾最多 200 行并显示在可滚动列表中。
推理、配置和完成等待异常在 C ABI 内转换为错误码，诊断写入失败不打断推理。

## 准备、编译与打包

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

需要 VS x64 C++ 工具链与 Windows SDK；`fxc.exe` 在构建期生成内嵌 DXBC，
`PLAYBACK_FXC_EXECUTABLE` 可指定路径。原生目标使用 `/W4 /WX`。

准备脚本下载固定模型、微软 NuGet 和 VC_redist 14.51.36231.0，校验整个包后只提取
锁定文件；CRT 安装包作为数据读取，不执行安装。来源见
[MSVC 运行库说明](../../licenses/msvc-runtime/NOTICE.md)。SDK 头文件不进入应用。
默认目录是 `.dart_tool/playback_inference/base`，缓存位于相邻的 `downloads`；
已存在的输出仅校验复用，锁变化或损坏时使用新的 `-OutputDirectory`，不能静默覆盖。

开发构建和 release CI 在 Flutter 构建前准备资源。应用 CMake 校验基础包及 SDK，
构建垫片并安装为 `aji.dll`，同目录安装配置和四个 CRT DLL，推理 DLL、模型和许可放在
`playback_inference/`。bundle 校验检查哈希、x64 PE、依赖闭合及模型 slot。
[运行库配置](../../cmake/playback_runtime.cmake) 固定含 AnimeJaNai 滤镜的 libmpv
及其 SDK；当前可用预编译包是 GPL，固定 LGPL 构建仍待落实，详见
[libmpv 来源说明](../../licenses/libmpv/NOTICE.md)。

## TensorRT 路线

当前选装版本为 TensorRT 11.3.0.99 / CUDA 13.4，只声明经过本机验证的 SM89。
要求实际播放 D3D11 adapter 对应 NVIDIA CUDA device，驱动 API 版本至少 13040。
能力查询不加载 TensorRT。组件缺失时滤镜旁路普通播放，并发布 `resources_missing`；
播放器显示主动下载入口，选择质量不会自行下载。

基础包仅增加随应用发布的 `tensorrt-components.json` 可信清单和小型 SDK 头文件的
构建依赖，不包含 NVIDIA 大运行库。应用显式下载固定上游 3.6.3 的 common + sm89
归档（约 329 MiB），验证归档和每个文件的 SHA-256，使用系统 tar.exe 解压；不运行
下载的解压器，不安装 Toolkit、修改 PATH 或安装驱动。资源写入
`%LOCALAPPDATA%/BangumiToday/playback-tensorrt/11.3.0.99/sm89`，约 611 MiB。
支持字节进度、HTTP Range / ETag 续传、取消、重试、跨窗口安装锁和 staging 原子发布；
损坏资源通过新目录事务修复。编译阶段显示状态和滚动日志，不估算百分比。

```text
D3D11 NV12/P010 → 共享 R16_FLOAT 平面 RGB → 私有 D3D11 RGB 纹理
CUDA 映射 / cuMemcpy2DAsync → FP16 NCHW → TensorRT enqueueV3
CUDA 输出 → 私有 RGB 纹理 → 共享 RGB → 既有 GPU YUV 转换 / 输出帧
```

像素不经 CPU。固定 FP16 2×模型构建使用受限环境下的绝对路径 trtexec，GPU 构建锁、
Job Object、15 分钟超时和取消负责回收子进程；模型尺寸、版本、驱动、GPU UUID、
模型哈希和构建参数共同组成缓存身份。引擎先验证 IO 契约并预热，再原子发布；缓存
命中复核哈希并预热，使用租约阻止活动引擎被清理，LRU 预算 4 GiB、日志预算 128 MiB。
失败保持普通播放，DirectML 只保留显式诊断配置。

开发者侧可独立准备（不改变播放器偏好）：

```powershell
./scripts/prepare_playback_tensorrt.ps1 -HeadersOnly
./scripts/prepare_playback_tensorrt.ps1 -ComputeCapability 89
```

前者由基础准备脚本自动调用，仅固定 TRT/CUDA 头文件；后者用于开发时侧载选装组件。

## 验证边界与待办

既有隔离原生验证覆盖 NV12/P010 转换、帧桥对 CPU 参考、aji 调用顺序、资源回收、
DirectML 节点分配和 ANGLE EGLStream 消费。ANGLE 要求解码、帧桥与渲染纹理处于
同一 D3D11 device；EGLImage 路线在所测 ANGLE 上不可用。

历史独立测量（非 Flutter 端到端）：RTX 4070 Laptop 1080p Performance 约 26 ms/帧，
GPU 中位 24.6 ms、P95 26.2 ms；Balanced 约 44.7 ms，AMD 780M Performance 约 71 ms。
这些结果不代表所有设备均满足实时播放预算。

剩余工作：真实硬解与 ANGLE device 对齐、PTS/seek/暂停/连播及长播放验收、画质与
端到端性能对比、干净 Windows/MSIX 环境、固定 LGPL 构建；TensorRT 帧桥、本机构建/
缓存和 SM89 选装下载已接通。此次隔离验证覆盖 1080p NV12、P010 padding、ABI 的
缺资源旁路 / slot / 后台编译 / 实时日志、引擎复用及取消，并验证真实下载的取消续传、
安装锁、解压、校验和离线复用。RTX 4070 Laptop 的 1080p Performance TRT 测量约
18.4 ms/帧（GPU 约 15.9 ms），合成灰帧与 DML 输出差为 0；该结果不能代表端到端
播放速度。其他 SM、项目托管组件 ZIP、完整 TensorRT 许可材料、资源移除入口与
发行渠道验证仍待完成。隔离编译和纯逻辑检查不能替代播放器手工验收。
