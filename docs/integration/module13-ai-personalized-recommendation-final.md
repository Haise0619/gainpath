# GainPath Module 13 AI 个性化推荐

2026-11-17 · `codex/module13-ai-personalization` · 实现提交 `042f29de3aaf`。八个既有生产入口已上线。真实 Gemini 结果来自一笔虚构输入测试。新训练事件和站内投递流程在隔离模拟器验收，生产接口另有已授权账号的只读验证。

## 功能

| 类型 | 候选与理由 | 会员操作 |
| --- | --- | --- |
| Tutorial | 精确匹配近期训练动作，只选择已发布且有步骤或视频的教程，并考虑相容的 Form Score 和难度。 | 查看封面、动作、难度及理由，并打开现有 Tutorial。 |
| Coach | 已发布并通过资格、共同分店与当前预约时段校验的教练。适用目标来自已声明的 Fitness Goals。 | 查看照片、专长、分店和已发布咨询价，再进入现有 Booking 流程。 |
| Routine | 从已发布、当前动作目录和执行模式均可用的 v1/v2 Routine 选出候选。考虑经验、训练目标、近期动作及可用的时长偏好。 | 查看封面、时长、难度和动作数，预览后明确点击 Start Workout。 |

**Recommended for You** 提供 For You、Routines、Tutorials 和 Coaches 四个筛选，以及 History、Refresh、详情和 Dismiss。等待首笔推荐、授权关闭、某个筛选暂无个性化结果或加载失败时，页面可显示真实已发布的通用内容。发布目录也无法提供内容时，页面提供浏览入口和重试。Inbox 继续显示实际投递的建议。

**Admin Recommendations** 提供 Overview、History、Delivery Issues、Exercise Guidance Insights 和历史队列查看。KPI 显示已加载且授权可见的记录范围。表格默认按创建时间倒序，支持类型、状态、马来西亚日期、已加载记录搜索、分页和刷新。详情展示实际保存的训练上下文、目标、理由、Gemini 或规则方法与投递时间。Insights 保留动作类别、Form Score、教程覆盖、内容缺口及 CSV。

## 同一条自动投递链路

1. 现有 Workout Backup 或符合条件的授权更新触发后台推荐。权限覆盖训练分析、生成和投递。Gemini 另需 External AI Inference 授权。
2. 后端读取 Fitness Profile 的目标和经验、最近已同步的训练摘要、动作及次数、训练频次和可用的 Routine 完成状态。有兼容样本时考虑 Estimated Form Score。历史最多回看 30 天。资料变化在下一次符合条件的训练事件生效。
3. 每个类型最多向 Gemini 提供六个匿名候选，只发送必要的类别和匹配特征。姓名、账号、原始视频、精确身体测量、完整档案和训练历史留在 GainPath。偏好字段缺失时使用现有上下文。
4. Gemini 返回每组候选顺序、第一候选和使用的特征。后端验证匿名标签和依据，再用这些依据写出短英文理由。超时、限流、服务不可用、缺少授权或无效输出时使用同一组候选的规则顺序。打开或刷新页面读取已保存的记录。
5. 提交前重查授权、上下文与目的地。推荐、回执及 Inbox 同时保存，保留 7 天冷却和重试去重。每次事件可生成零至三种。Routine 使用会员级冷却。老版本客户端继续消费原有 Tutorial 和 Coach 投影。

发布版只推荐真实发布的 Routine Templates。自定义 AI Routine 留在后续范围，因为它需要额外的动作处方、预览和保存契约。

## 质量与性能证据

| 检查 | 结果 | 范围 |
| --- | --- | --- |
| 真实 Gemini | 一次请求将教练、教程、Routine 的首选分别改为 C2、T2、R2。三组 ID、顺序与支持依据通过校验。 | 六个虚构候选，规则基线刻意安排较弱首选。 |
| 轻量 Top-1 | 规则命中 2/5，模拟 Gemini 5/5，改变首选 3/5。 | 手工标签与脚本输出。真实用户准确率仍待独立评估。 |
| 三类自动生成与投递 | 一次模拟推理、三条原子投递，重放无新增。最终内存测试约 72 ms。 | 实际选择、约束与保存逻辑，模拟提供者和内存存储。 |
| 真实推理 | 1,383 ms，输入 320、输出 113、合计 433 tokens。 | `gemini-3.5-flash-lite`，未返回独立 thinking token 字段。 |
| Member 首屏 | 16 个 Flutter 样本中位数 122.5 ms，范围 96–871 ms。 | 本地 widget、内存响应和本地图片。 |
| Admin 首屏 | 冷启动样本约 631 ms，后续样本约 95–161 ms。 | 本地 widget、虚构的已保存记录。 |

运行时单次推理默认 3 秒、8 KB 输入体积、512 输出 tokens，使用 5 分钟缓存和每 warm instance 每分钟 20 次未缓存请求上限。现有配置的一次真实测试就公开标准付费单价折算约 **USD 0.00038**。实际收费和项目额度由现有 Google 配置决定。此次沿用已有 Gemini 项目和凭证。 [定价](https://aistudio.google.com/docs/pricing#gemini-3.5-flash-lite) · [项目额度](https://aistudio.google.com/docs/rate-limits) · [数据条款](https://aistudio.google.com/docs/terms)

## 截图与构建

以下是 Flutter 实际渲染。会员图使用虚构推荐记录和项目图库，Admin 图使用虚构已保存记录及离线替代字体。

- Member [Routine](../../build/module13-ai/evidence/member-routines-390-100-0.png) · [Tutorial](../../build/module13-ai/evidence/member-tutorials-390-100-0.png) · [Coach](../../build/module13-ai/evidence/member-coaches-390-100-0.png) · [320 dp / 200% Details](../../build/module13-ai/evidence/member-details-320-200-1.png)
- Admin [Overview](../../build/module13-ai/evidence/admin-overview-1440-100.png) · [AI Details](../../build/module13-ai/evidence/admin-details-1440-100.png) · [Delivery Issues](../../build/module13-ai/evidence/admin-issues-1440-100.png)

| 验证 | 已记录结果 |
| --- | --- |
| Backend | 52 个相关文件、562 项通过。最终候选与兼容性修改后的重点套件 78 项通过。 |
| Firebase Emulator | 全套 34 项通过、1 项可选 Flutter 场景跳过。最终重点 5 项通过，含普通／FYP 触发、Routine 解析、旧客户端列表、真实发布发现、跨来源 Admin 分页。 |
| Member Flutter | 95 项受影响测试通过，最终兼容性 29 项及授权页面 15 项通过，Routine 入口回归含系统返回键。共 63 张实际渲染截图。 |
| Admin Flutter | 69 项受影响测试通过，最终兼容性 24 项通过，5 个渲染场景与 29 张截图。 |
| 静态分析与构建 | TypeScript 源码和测试类型检查、范围内 Dart 分析、Android Debug、Admin Web Release。Web 保留既有 CupertinoIcons 字体提示。 |

证据在工作分支 checkout 的 `build/module13-ai/evidence/`。Android APK 位于 `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`，SHA-256 为 `74d43b683d8644c02fda3af76924cc40e81e13fdc3b21e517392200f4a0e8054`。Admin bundle 位于 `build/module13-ai/admin-web-final/`，`main.dart.js` SHA-256 为 `6db78a597431a070e755102b2e613c85a0fb8bf40b4bf6e79e42b920bf5ab734`。

## Firebase 上线及回滚

目标是 `gainpath-0619`、`(default)`、`asia-southeast1`。两份源包基于当前线上归档叠加已验证的模块。保留较新的 FYP 共享接口及其非本次模块的字节。八个入口均为现有入口。[部署及回滚清单](../../build/module13-ai/release/release-plan-v5.json)

- 先更新读端与 Inbox 投影，包括 `module13MemberCommand`、`module13AdminCommand`、`module9MemberCommandCallable`、`fypDatasetCommand`。保留当前调用权限和 App Check。新版读取方使用第三种类型能力字段。
- 再更新四个事件入口 `module13WorkoutBackupCreated`、`module13WorkoutConsentChanged`、`module13FypWorkoutBackupCreated`、`module13FypWorkoutConsentChanged`。这四个入口和两个支持历史回放的 callable 需要绑定同一个既有 `GEMINI_API_KEY`。已确认 runtime service account 有现成读取权限。
- 回滚优先保留理解 Routine 的投影端。需要关闭推理时，恢复六个入口的原密钥绑定配置并保留规则回退。需要回滚生成行为时，先恢复四个事件入口的原版本，再按需处理两个历史回放入口。线上已有 Routine 记录时，读取服务仍需支持第三种类型。保留现有站内记录和回执。每个入口的原源包、配置及源哈希已归档。

用户批准后，八个函数于 **2026-11-17 20:35 MYT** 完成生产部署及校验。下载回来的源包均与部署清单哈希一致，六个入口已绑定现有 Secret。其他 71 个函数、既有运行服务设置、事件过滤器、IAM、Rules 和索引经对比验证。 [部署证据](../../build/module13-ai/release/activated-v5/deployment-verified.json)

新版 Admin 在本机 [localhost:7362](http://localhost:7362/) 提供，已核对服务文件哈希与构建产物，并验证四个 callable 的 CORS。 [本机 Admin 证据](../../build/module13-ai/release/activated-v5/admin-local.json)

上线后 11 项生产只读检查通过，覆盖普通会员新旧版本推荐读取、Inbox、FYP 推荐和已发布内容发现、FYP Admin 监控，以及 Auth、App Check 和角色拒绝。 [线上只读验证](../../build/module13-ai/release/activated-v5/smoke-final.json)

真实 Android/Firebase 验收仍包括用新版 app 完成新拍摄训练、验证独立的 Gemini 授权开关、离线重连、打开真实三类目标、查看 Admin 投递与保存理由，以及量测线上页面延迟和调用次数。普通与 FYP 两种账号在验收中用各自授权的现有路径。
