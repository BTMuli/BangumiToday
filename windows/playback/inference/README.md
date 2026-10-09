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
帧提交通过 `ID3D11Multithread::Enter/Leave` 保护完整转换、CUDA 映射与输出交接，
与 ANGLE / 硬解共用 immediate context 的临界区，避免仅逐调用加锁造成命令交错。
输出平面已 signal / Flush 后释放临界区，再提交最后的 D3D12 输出帧拷贝；
共享 fence 保证访问顺序，command allocator 的背压等待不再阻塞硬解 / ANGLE。
设备移除错误同时记录 D3D12、D3D11 的原因名称与十六进制 HRESULT；真实播放仍需复测。
隔离并发检查使用另一线程持续清空上下文并交替输入明暗帧：未加临界区的版本出现像素错误，
保护后 DirectML、TensorRT 各 120 帧与各自基准逐字节哈希一致，D3D12 调试层无错误。
模拟 D3D12 设备移除可同时记录其移除原因和仍正常的 D3D11 状态；此检查不代表长播放验收。

TensorRT 对固定尺寸、固定 GPU 张量地址的执行上下文，在预热后捕获 CUDA Graph，
后续每帧复用图；捕获不可用时继续执行同一模型的普通 TensorRT enqueue。
图中只包含模型推理，逐帧映射的 D3D11 数组及张量拷贝保持在图外。
CUDA stream 与 graphics map/unmap 保证资源复用顺序，帧提交不再 CPU 轮询等待；
GPU 计时异步采集，完成等待仅保留在预热和资源销毁时。TRT 输入转换后也不再
重复提交 D3D11 fence / Flush，由 CUDA 映射前统一提交。
垫片诊断记录 CUDA Graph 是否启用；这些优化不修改模型、像素格式或超分倍率。

TensorRT 直接注册转换器的私有 R16_FLOAT 输入 / 输出纹理，不再另建 RGB 纹理并
逐帧 CopyResource；DirectML 继续使用 D3D12 共享 RGB 纹理。RGB → YUV 合并为
一个 kernel，每线程只读取一次 2×2 RGB，同时写四个亮度与一个色度样本，保持
原有舍入、clamp 和盒式平均。转换参数按会话创建 immutable constant buffer，
不再每帧 Map / Unmap 两次。1080p TRT 减少约 59.3 MiB 重复 RGB 纹理。

2026-10-08 在 RTX 4070 Laptop 上以同一缓存引擎作隔离前后对比：
1920×1080 Performance、每轮 120 帧、按旧→新→新→旧顺序测量，
旧版为 30.27 / 30.69 ms/帧，新版为 17.75 / 16.99 ms/帧，平均耗时减少约 43%。
此测量包含 FP16 RGB 纹理拷贝、TensorRT 推理和回写，末帧回读也计入总时间，
不含 YUV 转换、硬解或 Flutter 渲染，不代表播放器端到端倍速能力。
两个模型各 120 帧的明暗交替输出与旧版逐字节一致；完整帧桥另覆盖两个模型的
NV12、P010 各 120 帧排队输出，与各自同步参考逐字节一致。
35 项纯 Dart 检查覆盖丢帧窗口、倍速切换、降速重试和设备 / 清理失败的恢复边界。

2026-10-09 在同一 RTX 4070 Laptop、同一缓存引擎上，对上述转换 / 纹理优化作
完整帧桥隔离对比：1080p Performance NV12，每轮 120 帧，旧→新→新→旧，
旧版为 17.96 / 18.08 ms/帧，新版为 17.34 / 17.26 ms/帧，平均耗时减少约 4%。
计时包含 YUV 转换、张量拷贝、TensorRT 推理、输出平面拷贝与末帧 fence 等待；
输入使用预先创建的合成纹理，不含硬解、CPU 像素回读或 Flutter 渲染。
32 组随机 FP16 RGB 转换覆盖 NV12/P010、奇数尺寸、padding 与颜色 clamp，
与旧版逐字节一致。两个后端、两个模型、两种像素格式、1080p 与 1278×719
可见裁切共 192 帧，使用四个轮换输出纹理排队，与旧版输出逐字节一致；
另 192 帧持续并发 ClearState 后仍一致，D3D11 调试层无警告或错误。
这些检查不代表真实播放器端到端性能或长播放验收。

输入 YUV → RGB 的 8×8 线程组现在共用 8×8 FP32 色度缓存，复用 Catmull-Rom
采样并保持原有累加顺序；边界与 padding 线程均在返回前参与组同步。
2026-10-09 在同一 RTX 4070 Laptop 上测量 1080p NV12 输入转换，预热 1000 次，
每轮 6000 次 dispatch，旧→新→新→旧的 GPU 时间分别为
0.0706 / 0.0494 / 0.0485 / 0.0651 ms/帧，平均减少约 28%（约 0.019 ms/帧）。
完整 TRT 帧桥各轮 240 帧为 17.14 / 17.15 / 17.47 / 17.46 ms/帧，整体耗时无明显变化。
该满队列检查中，平均持锁时间由 16.72 ms 降至 0.75 ms，背压仍发生在最终队列提交，
仅将等待移出了共享上下文临界区，不改变 GPU 执行依赖。

用指定《冰剑的魔术师将要统一世界 第二季》第 1 集的 03:00–03:20 片段，
按旧→新→新→旧复测项目所用 libmpv 的 NVIDIA D3D11 硬解、1080p Performance
TRT 超分和 ANGLE 渲染，四轮均输出 3840×2160、无 VO 丢帧或推理失败。
排除最初 48 帧并去除重复诊断快照，旧版 35 个、新版 36 个每秒采样的持锁中位值为
0.83 / 0.66 ms，CUDA map / unmap 中位值约 0.15 / 0.10 ms，锁等待约 0.0003 ms。
这是独立原生播放链路的短片段复测，不包含 Flutter 窗口合成，不能据此声称整体帧率提升。
320 组输入 FP16 输出与旧版逐字节一致，覆盖 NV12/P010、色度位置和线程组 / padding
边界；TRT 两个模型、两种格式、1080p 与可见裁切共 96 帧正常排队、96 帧并发
ClearState 的输出均一致，DirectML 共用路径另 32 帧并发输出一致，D3D11 调试层无错误。

## 输入契约与滤镜控制

- 仅验证 SDR、BT.709 limited、NV12/P010、无旋转、方形像素；固定 2×，
  可见输出不超过 3840×2160。padding 为边缘复制，输出裁去补齐部分。
- 输入色度采用 Catmull-Rom 插值；输出色度采用 2×2 盒式平均，仍需实际画质对比。
- DirectML 会话禁用 CPU EP 回退和 memory pattern；不支持完整 GPU 图时创建失败。
- slot 1 为 Performance（AI 流畅），slot 2 为 Balanced（AI 高质量）。
  TensorRT 引擎后台构建通过 aji_poll 完成通知；插值和预缩放暂未实现。
- 普通播放、Anime4K 和 AI 统一使用 `hwdec=d3d11va`，切档不修改硬解配置。
  视频满足 AI 条件后设置 `vf=animejanai=slot=N:conf=animejanai.conf`；固定滤镜
  必须收到 `conf` 或 `engine` 才加载 `aji.dll`，仅给 slot 会旁路复制。关闭时清 vf。
  暂停时由 mpv 自身刷新滤镜画面；着色器和纹理尺寸通过渲染更新回调重绘，
  不再追加 `seek 0`，避免重复定位。
- Dart 通过 `MPV_FORMAT_NODE` 读回 vf，校验名称、enabled、slot 与非空 conf。
  安装开始即记录待清理状态，部分安装失败也会撤销滤镜并恢复普通播放。
- AI 生效且倍速大于 1 时，在推理前加入 `@bt-janai-rate:lavfi=[select=…]`。
  按媒体时间分桶选帧，保留原始 PTS、D3D11 硬解纹理与音频时钟；跳过的帧不再
  进入 YUV 转换或 TensorRT。无时间戳的帧放行，倒退时间戳保留首帧，seek 重置图。
  1× / 慢放、关闭 AI 及准备期间不抽帧。倍速目标帧率取源视频正常帧率、显示刷新率
  （未知时 60）与 60 FPS 上限的最小值，使超分每墙钟秒的推理量不随倍速增加。
  约 24 FPS 视频在 2× / 4× 下均维持约 24 次推理/秒，按倍速减少保留的媒体帧数。
  不再根据模型 GPU 耗时提高目标帧率：该时间不包含完整硬解、渲染及窗口合成，
  不能代表整机剩余算力。抽帧与其他超分操作共用串行应用队列。
  更新 vf 时保留相同 AnimeJaNai 条目和配置，复用推理上下文；读回确认 selector
  位于启用的推理滤镜之前且 graph 完全一致，失败则清理整条链并恢复普通播放。
- AI 与 Anime4K 共用最终纹理策略：按视口物理像素、源比例、启停滞回及输出预算
  计算尺寸；无需放大时恢复普通播放。模型仍固定 2×，mpv 将滤镜结果缩放到目标纹理。
  窗口大小变化只调整纹理，不重装同档滤镜；显式请求尺寸并确认输出，超时则恢复普通播放。
- GPU 帧预算为 `1000/fps`：2 秒窗口、至少 10 个样本，连续 3 个有效窗口的
  GPU 中位耗时超预算会报错。Dart 另采样 mpv 的 VO 丢帧计数和原生实际推理帧数，
  连续 3 个窗口丢帧率超过 1% 时降级；暂停、seek、计数重置与不可用样本不计入。
  主动抽帧不计为 VO 丢帧，也不进入丢帧率分母；更新抽帧图会重置统计窗口。
  切换倍速会重置统计并给予 4 秒稳定期；seek 判断按实际采样间隔与倍速计算，
  防止 2× / 4× 正常推进被固定时间上限误判。性能降级后降低倍速可自动重试；
  模型、设备及恢复失败仍需主动换档或新媒体后重试。

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
快照最多每秒更新一次，包含 phase、slot、模型、尺寸、计数、源帧率 `sourceFps`、
GPU 耗时、ticket 和 reason；Dart 诊断另记录倍速、目标帧率与保留的媒体帧率。
另包含最近成功提交的 `cpuContextWaitMs`、`cpuContextHoldMs`、`cpuCudaMapMs`、
`cpuCudaUnmapMs`、`cpuInteropSubmitMs` 和 `cpuFrameSubmitMs`，用于区分共享上下文
争用、CUDA API 调用耗时和输出拷贝队列背压；这些是 CPU 时间，不是 GPU 执行时间。
应用按 Player / 配置代次读取快照，显示实际后端、GPU 和准备状态；编译日志路径
属于同一任务，界面每两秒读取末尾最多 200 行并显示在可滚动列表中。
推理、配置和完成等待异常在 C ABI 内转换为错误码，诊断写入失败不打断推理。

2026-10-09 对前一版按 GPU 容量提高抽帧帧率的策略，用指定视频的 03:00–03:40
片段，RTX 4070 Laptop、1080p Performance
TRT 缓存引擎、D3D11 硬解和 ANGLE 离屏渲染，音频经 `ao=null` 保留时钟。
4× 全帧链路两轮耗时 17.7 / 17.1 秒；将推理前选帧目标固定为 50 FPS，两轮为
10.4 / 10.5 秒（理想 4× 为 10 秒）。稳定阶段每秒推理约 50 帧，低于全帧需求的
约 96 帧；第二轮全帧链路的 VO 丢帧持续增加，选帧链路在约第 5 秒后不再增加。
启动和预热仍有丢帧，不能宣称整段零丢帧；计数在播放中读取，避免结束时 mpv 重置。
2.5×、30 FPS 目标的时间戳链路另验证按每墙钟秒约 2.5 秒媒体时间推进。
动态 4× / 2×、暂停、精确 seek 均正常输出 3840×2160，无推理失败，更新 selector
全程只创建一次垫片上下文。49 项纯 Dart 功能检查覆盖策略、状态解析、真实丢帧窗口、
并发倍速切换、关闭及错误滤镜顺序的清理。这些验证不包含 Flutter 窗口合成或长播放。

真实 Flutter 播放日志随后发现：约 24 FPS 的 HEVC/P010 视频在 2× 下虽已抽帧，
目标仍由 35 提高到 45 FPS，推理量接近正常播放的两倍，并触发连续 VO 丢帧降级。
当前策略改为按源视频正常帧率限制倍速推理量，避免目标因 GPU 耗时降低而反复升高。
该限制约束的是超分工作量；倍速仍需解码更多源帧，不能保证整机占用与 1× 完全相同。
修正后静态分析与 50 项纯 Dart 功能检查通过，覆盖 2× / 4× 保持正常推理频率、
GPU 时间变化时不提高目标、恢复 1×、并发倍速切换和滤镜清理；尚未复测 Flutter 占用。

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

当前选装版本为 TensorRT 11.3.0.99 / CUDA 13.4，最低 SM89，白名单为
SM89、SM90、SM100、SM120；覆盖 RTX 40 / RTX 50 和相应的 Hopper / Blackwell
架构。SM89 已有本机推理验证，其他三个架构仍需真实显卡播放验收。
SM75、SM80、SM86 不开放，未列入可信清单的架构也不自动使用 PTX 组件。
要求实际播放 D3D11 adapter 对应 NVIDIA CUDA device，驱动 API 版本至少 13040。
能力查询不加载 TensorRT。组件缺失时滤镜旁路普通播放，并发布 `resources_missing`；
播放器显示主动下载入口，选择质量不会自行下载。

基础包仅增加随应用发布的 `tensorrt-components.json` 可信清单和小型 SDK 头文件的
构建依赖，不包含 NVIDIA 大运行库。应用显式下载固定上游 3.7.0 的 common + 当前
显卡架构归档。验证归档和每个文件的 SHA-256，使用系统 tar.exe 解压；不运行
下载的解压器，不安装 Toolkit、修改 PATH 或安装驱动。资源写入
`%LOCALAPPDATA%/BangumiToday/playback-tensorrt/11.3.0.99/sm<架构>`。
只安装和校验对应架构的 builder DLL，设置显示的下载和安装大小由可信清单计算。
NVIDIA 组件不进入 MSIX，增加架构仅增加少量清单和程序数据。

| 架构 | 下载（公共 + 当前架构） | 安装（含 CRT，不含引擎缓存） |
|---|---|---|
| SM89 | 约 329 MiB | 约 611 MiB |
| SM90 | 约 579 MiB | 约 872 MiB |
| SM100 | 约 418 MiB | 约 709 MiB |
| SM120 | 约 397 MiB | 约 688 MiB |

SM90 / SM100 已通过归档与文件 SHA-256、解压和 DLL 依赖闭合检查。
隔离功能检查覆盖四种架构的资源选择、SM90 / SM100 安装记录、播放架构匹配，
以及低于 SM89、未列入清单的架构和旧驱动拒绝；其他架构的 builder DLL 不能
代替所需文件。这些检查不代表对应显卡已通过真实推理和播放验收。
支持字节进度、HTTP Range / ETag 续传、取消、重试、跨窗口安装锁和 staging 原子发布；
损坏资源通过新目录事务修复。编译阶段显示状态和滚动日志，不估算百分比。

设置中的组件安装完成后，调用独立于 mpv 滤镜 ABI 的 `bt_trt_precompile_*`
入口，顺序准备 1280×720、1920×1080 × Performance、Balanced 共四个引擎。
后台 isolate 轮询任务序号、阶段及有界日志，取消会回收当前 trtexec 子进程。
准备入口接收安装组件的 SM 架构，原生端只选择相同架构的 DXGI/CUDA adapter；
实际播放显卡的 SM 也必须与已选组件一致。
预编译和播放共用 `MakeFramePlan`、实际 DXGI/CUDA 显卡身份及 `TrtEngineBuild`
缓存校验；已完成的结果在重试时复用，其他源视频尺寸继续按需构建。

```text
D3D11 NV12/P010 → 私有 R16_FLOAT 平面 RGB
CUDA 映射 / cuMemcpy2DAsync → FP16 NCHW → TensorRT enqueueV3
CUDA 输出 → 私有模型输出 RGB 纹理 → 合并 GPU YUV 转换 / 输出帧
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
./scripts/prepare_playback_tensorrt.ps1 -ComputeCapability 90
./scripts/prepare_playback_tensorrt.ps1 -ComputeCapability 100
./scripts/prepare_playback_tensorrt.ps1 -ComputeCapability 120
```

前者由基础准备脚本自动调用，仅固定 TRT/CUDA 头文件；后者用于开发时侧载选装组件。

### AnimeJaNai 3.7.0 对齐

3.7.0 的发布清单仍使用当前固定的 mpv `d6d93599d5`、TensorRT 11.3.0.99 和
ORT / DirectML 1.24.4 / 1.15.4。Performance、Balanced 模型和模型许可的
SHA-256 与现有锁定相同，因此保留原有源码固定点及 SDK。
common / sm89 归档重新打包后 SHA-256 已变化，组件锁和 Dart 可信清单摘要已同步
更新。实际下载、解压及逐文件校验确认运行库文件不变，已安装资源继续在原目录
校验复用，不因上游包版本变化重新下载。

## 验证边界与待办

既有隔离原生验证覆盖 NV12/P010 转换、帧桥对 CPU 参考、aji 调用顺序、资源回收、
DirectML 节点分配和 ANGLE EGLStream 消费。ANGLE 要求解码、帧桥与渲染纹理处于
同一 D3D11 device；EGLImage 路线在所测 ANGLE 上不可用。

历史独立测量（非 Flutter 端到端）：RTX 4070 Laptop 1080p Performance 约 26 ms/帧，
GPU 中位 24.6 ms、P95 26.2 ms；Balanced 约 44.7 ms，AMD 780M Performance 约 71 ms。
这些结果不代表所有设备均满足实时播放预算。

剩余工作：真实硬解与 ANGLE device 对齐、PTS/seek/暂停/连播及长播放验收、画质与
端到端性能对比、干净 Windows/MSIX 环境、固定 LGPL 构建；TensorRT 帧桥、本机构建/
缓存和 SM89 / SM90 / SM100 / SM120 选装下载已接通。既有隔离验证覆盖 1080p
NV12、P010 padding、ABI 的缺资源旁路 / slot / 后台编译 / 实时日志、引擎复用及
取消，并验证真实下载的取消续传、
安装锁、解压、校验和离线复用。RTX 4070 Laptop 的 1080p Performance TRT 测量约
18.4 ms/帧（GPU 约 15.9 ms），合成灰帧与 DML 输出差为 0；该结果不能代表端到端
播放速度。SM90 / SM100 / SM120 的真实显卡推理、项目托管组件 ZIP、完整 TensorRT
许可材料、资源移除入口与发行渠道验证仍待完成。隔离编译和纯逻辑检查不能替代
播放器手工验收。
