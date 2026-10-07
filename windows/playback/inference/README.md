# AnimeJaNai 原生推理基础（P0）

当前实现是独立的 GPU 张量会话及实际播放 adapter 能力查询，尚未接入
mpv / Flutter。P0 没有通过，不能把此目录当成可发布的超分运行包。
完整范围及剩余工作见 [接入方案](../../../docs/feat/animejanai-onnx.md)。

固定的 aji v0.9.0 树未找到明确的独立或文件级授权声明。本实现为项目
自行编写的 MIT 代码，不复制该桥的源码、头文件、shader 或 DLL。

`DmlSession` 使用实际 D3D11 device 的 DXGI adapter 创建 D3D12 / DML1
队列，以 FP16 NCHW GPU buffer 绑定两个固定模型的输入、2 倍输出。
会话采用串行执行、关闭 memory pattern、固定输入动态维度，并禁止 CPU EP
回退。模型、ORT 和 DirectML 在加载前按编译进代码的大小与 SHA-256 校验；
读锁持续覆盖加载及使用，拒绝任意模型。DLL 用绝对 Unicode 路径和受控搜索
范围加载，进程保持一套 ORT / DML。此实现不修改 PATH 或全局 DLL 搜索目录。

调用者必须在原生工作线程创建、执行、等待、销毁会话，通过 `queue()`
提交预处理，再调用 `Run()`。输入 / 输出 buffer 在返回的 fence ticket 完成
之前不能被复用。每个会话只允许一帧在途，GPU 故障后的会话不能再次运行。
销毁时先等待在途工作；仍在执行且未被移除的故障设备资源由回收线程持有，
不会因超时立刻释放。会话对象销毁之前，调用者须停止新的调用并排空线程申请。

`QueryGpuCapabilities` 从传入的实际 playback device 取得 adapter；仅对
NVIDIA 从 System32 动态加载系统 `nvcuda.dll`，通过 `cuD3D11GetDevice`
与 `cuDeviceGetLuid` 校对设备，再读取 compute capability 和驱动版本。
这里没有 TensorRT 就绪判断；架构探测成功也不表示帧桥或实时播放已通过。
[CUDA / D3D11 接口](https://docs.nvidia.com/cuda/cuda-driver-api/cuda_driver_api/group__CUDA__D3D11.html)

## 独立准备与编译

资源准备命令只下载固定的两份模型、许可和微软 NuGet，不下载 NVIDIA SDK
或运行库，也不构建 / 启动 Flutter。NuGet 的整个包按固定哈希校验，只流式
提取 x64 运行文件、许可与开发头文件。开发头文件不进入播放器运行目录。

```powershell
./scripts/prepare_playback_inference.ps1
./scripts/verify_playback_inference_prerequisites.ps1 `
  -RuntimeDirectory .dart_tool/playback_inference/p0/runtime

cmake -S windows/playback/inference -B .dart_tool/playback_inference/build `
  -A x64 `
  -DPLAYBACK_ORT_SDK_DIR="D:/Code/App/bangumi_today/.dart_tool/playback_inference/p0/sdk/onnxruntime" `
  -DPLAYBACK_DML_SDK_DIR="D:/Code/App/bangumi_today/.dart_tool/playback_inference/p0/sdk/directml"
cmake --build .dart_tool/playback_inference/build --config Release
```

使用 Visual Studio 的 x64 C++ 工具链及 Windows SDK。CMake 校验全部固定
SDK 头文件，`/W4 /WX` 编译原生静态库，不链接到当前应用。产物是供后续
项目原生桥使用的内部 C++ 库，不是上游 aji ABI v8 DLL。

默认输出是开发目录 `.dart_tool/playback_inference/p0`。准备事务在同卷
staging 校验文件 / SDK / 清单后发布；已存在的输出只校验复用，不覆盖。
锁文件变化或输出损坏时，应指定新的 `-OutputDirectory`。
已校验下载在 `.dart_tool/playback_inference/downloads` 复用，准备可离线重跑。
这是开发准备脚本；应用级断点续传、选装安装和资源租约仍属于 P3。

## 当前验证和限制

2026-10-07，MSVC 19.51、Windows SDK 10.0.28000.0：

- 原生库 `/W4 /WX` 编译通过，固定文件和全部 SDK 头文件哈希检查通过。
- RTX 4070 Laptop 与 Radeon 780M 的 Performance FP16 GPU 张量推理通过；
  Balanced 在 NVIDIA 上通过。65×63 → 130×126，输出有限，未启用 CPU EP。
- NVIDIA 实际 adapter 校对成功，SM89，CUDA Driver API 版本 13040；AMD
  返回非 NVIDIA 的明确原因，不加载 CUDA。设备识别不根据显卡名称匹配。
- NVIDIA Performance 1920×1080 → 3840×2160 的一次短测（2 次预热、
  12 次采样）中位数 67.3 ms、P95 79.6 ms；未计入 YUV 转换、解码及渲染。
  计时包含 `Run` 提交与 GPU fence 完成等待，是 CPU 墙钟时间，未使用 GPU
  timestamp，也未验证多帧流水线的吞吐。
  此结果未达到方案中 24 fps 的 33.3 ms 目标，也不足以建立长期性能结论。
- 临时非 UI 检查覆盖固定哈希、缺失 / 损坏 / 相对路径、中文 / 空格路径、
  模型写锁、ZIP 越界 / 绝对 / 重复路径、x64 PE 与依赖解析。

当前两个 DLL 的 PE 导入审计确认 ORT 还依赖 `msvcp140.dll`、
`msvcp140_1.dll`、`vcruntime140.dll`、`vcruntime140_1.dll`；干净机器的
app-local 分发及许可闭合尚未完成。这里的准备目录明确标记
`p0-prerequisites`，不能用于主包安装或被 bundle 检查视为完整运行包。

尚缺：GPU YUV 预后处理与 D3D11 / D3D12 纹理同步、固定自有桥 ABI、
含滤镜的可复现 LGPL libmpv、实际 ANGLE 帧消费、完整帧生命周期与性能
优化，以及全部 TRT 帧桥 / 选装 / 引擎缓存和 Dart 产品接入。
两档 UI、默认 DML 与可选 TRT 播放行为均未交付。
