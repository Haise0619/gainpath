# GainPath Admin Reports & Analytics 验收记录

记录日期为 2026-11-16。三个相关 Functions 已部署，私人 Admin 客户端已激活。真实已登录浏览器验收与部分进阶指标仍未完成，本文逐项列明范围。

## 已实施的功能修复

| 报表 | 已确认原因或限制 | 本次处理 |
| --- | --- | --- |
| Platform Usage、Returning Members、Rewards、Gamification | 原 schema 3 请求将签到、兑换、小游戏和活动来源串联，任一可选来源的 failed-precondition 会拒绝整份结果 | 分别记录 extensions 与 observations 的失败状态，保留已验证签到和其他独立来源，展示 Partial 与单独重试 |
| Recorded Workout Activity | 活动报表为计算 Session 事件同时解析 Routine 备份，Routine 兼容问题会阻断无需该记录的 Session 活动 | 只解析 Session 来源，Routine 仍由 Workout 报表统计，不计入 Session 事件 |
| Workout、Form Score | Unified Workout 原本要求普通与 FYP 两来源全部成功 | FYP 来源校验或扫描上限失败时返回明确标识的 canonical-only Partial。权限错误仍拒绝整个请求。普通来源失败仍显示 Error |
| Workout 性能 | 各会员首份备份页逐个读取 | 最多四个会员首份页并发，后续分页和聚合仍按顺序验证，保留扫描上限 |
| Coach Booking Utilization | 部分分支以每日预约上限乘天数充当历史容量 | 改为 Booking Activity，移除无依据百分比。已有真实状态明细和 CSV 保留 |
| Coach 表格 | 原表格排序固定 | Coach、Created、Confirmed、Completed、Cancelled、Scheduled、Consultations 可排序 |
| Active Subscriptions 与 Plan Distribution | FYP Plan Distribution 统计所有订阅，包括 expired。Active 只取 active，故 22 与 23 可以来自不同口径 | 明确显示计划分布定义与活动订阅定义，保留原始真实状态 |
| Unavailable 颜色 | 共用来源标签只根据 live 选择绿色 | Unavailable、Partial、Error、Loading、Empty 使用中性状态颜色 |
| 大字体 KPI | 共用 StatTile 标题高度未考虑 text scale | 按实际字体缩放分配标题高度，并增加大字体卡片宽度 |

普通会员实时备份只读检查使用项目现有 CLI 身份。扫描 9 个会员文档，其中 5 个符合当前报表有效会员范围。33 份最新备份均属于这 5 个有效会员。共读取 33 份最新备份，其中 Routine 18、Session 15，33 份均通过当前本地生产校验与 digest 验证。随后只读下载并重放了三个实际已部署函数的源代码归档，确认版本差异。复用了工作区已有的 Timed Routine signature 兼容修复及其回归测试，并把它纳入本次必要提交依赖。线上 adminWorkoutReportingCommand 与 fypDatasetCommand 各有 4/33 份备份因旧 Timed Routine planSignature 字符串比较失败。线上 adminCheckInReportingCommand 有 12/33 份记录因旧字段/格式支持失败。三个精确待部署归档均在同一批真实备份重放中 33/33 通过。该检查没有调用 Member 写入或修改历史数据。

现有奖励与游戏数据也通过只读本地聚合验证。3 次 Firestore 查询读取 5 文档，耗时 417ms，读取 rewardRedemptions 2、miniGameRoundSessions 2、miniGameParticipationAwards 1。结果为 issued 2、collected 0、expired 2，Move & Catch started 2、completed 1。该数字是本地诊断聚合与实际 Firestore 查询耗时，不是已登录 Callable 的端到端耗时。

## 数据源与定义

| Report | 数据来源 | 日期与定义 |
| --- | --- | --- |
| Recorded Revenue | orgs/gainpath/transactions，加现有 Unified FYP business scenario 数据 | 原有已确认 Sandbox receipt 日期，加已标识场景账目。货币 MYR，minor units 在 CSV 中明确保留 |
| Membership Collections | 原有 membership transactions | 依据原有 clearance 与 refund/review 过滤，不能解释为实际银行到账 |
| Membership Census | orgs/gainpath/members 与现有 commerce extension、FYP subscriptions | 当前账户和当前计划快照。Plan Distribution 与 active 分别显示口径 |
| Workout | members/{uid}/workoutBackups 最新文档 | Session endedAt，Routine finish 或 updated fallback。Routine 汇总不重复加入 Session reps |
| Form Score | Session poseMetrics | 以 exercise、scoringVersion、detectorId、detectorVersion、cameraView、armMode 分组。Null 不当作零分 |
| Booking | orgs/gainpath/bookings，consultations 与现有 commerce extension | Created 按创建时间，scheduled starts 按预约时间，outcomes 为选中创建记录当前状态 |
| Recorded Engagement | appCheckInProfiles/{uid}/claims、bookings、miniGameRoundSessions、Session backups | 可观测事件与当前有效会员 cohort。保留原有上期比较可用条件 |
| Rewards | rewardRedemptions | issuedAt、fulfilledAt 与 expiresAt 分开统计 |
| Gamification | claims、miniGameRoundSessions、miniGameParticipationAwards、badge 数据 | 确认签到积分与可兑积分来源分开。历史 demo award 不升级为可兑积分 |

全部原有 Auth、Admin Role、App Check、组织范围和最终授权校验仍是结果返回条件。报表继续使用 Asia/Kuala_Lumpur UTC+08 日期边界和 start-inclusive/end-exclusive 查询。

## UI 与功能完整性

| 功能 | 当前状态 |
| --- | --- |
| Overview / Financial / Fitness / Coaching / Engagement | 已实现五个入口与按需首次挂载 |
| Overview | 收入、Booking、当前活动会员 KPI，membership receipt trend，取消预约 attention 入口 |
| Financial | 保留收入、receipt、collection、refund、plan、历史财务明细与导出。Unified 趋势增加 tooltip |
| Fitness | 保留训练、动作、次数、手动组、Routine 与兼容评分图表及导出 |
| Coaching | 保留预约状态、Coach 绩效、比较，新增状态列排序 |
| Engagement | 保留事件、返回会员、兑换和游戏报表。缺失来源显示范围和重试 |
| 日期筛选 | All recorded dates、7/30/90 days、Custom。All recorded dates 仍受后端有界扫描限制，超限显示失败 |
| Branch | 原后端尚无完整可信 branch attribution。Operational 视图继续禁用该筛选，未声称完成跨分支指标 |
| Tab 状态与缓存 | 已访问区块保持 mounted，保留图表选择、排序和滚动位置。30 秒内返回复用结果，超过期限返回会刷新当前标签来源。筛选改变只更新当前 Fitness / Engagement 来源 |
| In-flight deduplication | 复用 Firebase Gateway 既有同查询去重 |
| 导出 | 保留各区块 CSV，包含原有日期与范围。Partial CSV 增加明确来源说明 |
| 全量 DAU、MAU、Retention、Churn、实际 Coach capacity | 现有来源不足，保持有限可观测指标 |
| Overview Workout KPI、完整 score distribution、独立每标签筛选、更多 deterministic insights | 尚未完整实施 |

## 性能证据

测试环境为 Windows、本机 Flutter SDK、Node 22、现有项目依赖。Firebase 诊断与浏览器 fixture 渲染分别记录。

原页面首次挂载一个业务请求、两个 Workout 区块和四个 Check-in 区块。同查询 in-flight 去重后通常为三个独立后端请求。当前 Overview 首次只调用业务请求，Fitness 和 Engagement 在首次访问时请求各自数据。该比较来自实际 Widget 调用计数和现有 Gateway 去重逻辑，不能当作 Firebase 网络耗时比较。

Widget 回归确认初始 Workout 与 Check-in 调用各为零。Fitness 首次两个区块各调用一次测试 Gateway，30 秒内切出再返回不增加调用，刷新增加两个调用。生产 Firebase Gateway 对并发同查询继续合并。

浏览器截图工具记录的约 1–2 秒含固定捕获等待、页面加载及截图。页面使用测试夹具，数值不能作为线上 Firebase latency、真实 Firestore Reads 或优化百分比。未取得优化前线上首屏与 KPI 延迟基线。

## 已运行验证

| 检查 | 实际结果 |
| --- | --- |
| Backend unit tests | Reporting 49，加复用的 Timed Backup 兼容校验测试 11，共 60 通过 |
| TypeScript production build | 通过 |
| TypeScript test typecheck | 通过 |
| Domain tests | 198 通过 |
| Firestore Emulator reporting integration | 3 文件、13 测试通过 |
| Admin reporting tests | 58 通过，包含切出再返回不增加 Workout 请求的回归 |
| Dart reporting analysis | 无问题 |
| Admin Web release | 普通 main.dart 入口 release 构建通过。私人 App Check bundle 另行构建并激活，served hash 核验通过 |

Emulator 使用 demo-gainpath-reporting 与本地 Firestore，不写入真实项目。

## 实际 Flutter Web 截图

截图保存在 build/admin-reports-analytics/screenshots/，采用真实 Flutter Web 编译和 headless Chrome 渲染。测试数据通过单独 preview 入口注入，不属于生产入口，不代表已登录线上数据。

包含五个标签 1440px、Overview 1024px、768px、768px 200% text scale，以及 Loading、Empty、Error。浏览器 150% / 200% 页面缩放尚未单独验收。原始附件仅提供需求文字，本次未收到需求中提及的原始截图。

## 部署、兼容性与回滚

三个目标 Functions 已完成定点源码更新。每个函数部署后重新下载的归档与相应待部署 ZIP 的 SHA-256 一致，runtime、entryPoint、环境配置与 IAM 核验通过。

初次部署和私人 App Check 构建曾被自动审批拒绝，用户随后明确批准了这三个具体函数更新和使用既有 debug 配置激活 localhost:7359。后续执行均在该直接授权后进行。

私人 Admin 正式 main.dart release 已使用既有 App Check 配置成功构建并激活到 http://localhost:7359/。实际服务 main.dart.js SHA-256 为 bea903aff730bc15c33ab281ee166c135c8f8cedfec0fea615df303f65b55f9a，与构建完全一致。原客户端完整保存在 build/admin-reports-analytics/admin-before/。激活时发现本地静态服务未监听，已启动项目既有、只绑定 127.0.0.1:7359 的服务并重新完成哈希核验。

所需变更范围包括 adminWorkoutReportingCommand、adminCheckInReportingCommand，以及 fypDatasetCommand 中 Unified Workout 的相关模块。已从三个当前已部署归档准备独立的 *-prepared-v2.zip。归档文件清单和哈希由独立 reviewer 核对，所有原文件保留，package 配置、entrypoint、权限模块和奖励发放模块无差异。三个精确 entrypoint 均可成功加载，真实备份重放均通过。Check-in 包添加了支持新备份格式所需的 exercise-execution、floor-push-up-validation 和 timed-routine-backup-validation 依赖。

部署前只读基线已保存，真实项目共有 79 个 Functions。部署后总数仍为 79，其他 76 个 Functions 配置核验通过。Eventarc filter 列表以等价属性顺序归一化后比较，Google API 返回的列表顺序不影响该结论。原始部署归档、IAM、配置与拟部署文件哈希保存在 build/admin-reports-analytics/ 忽略目录中。

本次查询仍按 documentId 分页，没有新增复合索引或 Rules 需求。schema 1/2 Check-in 维持原失败语义，schema 3 支持独立来源状态。新 Admin 兼容旧完整响应，旧客户端可忽略新可选状态，但不会展示完整 Partial 说明。

回滚步骤如下。

1. 对照 deployment-baseline.private.json 与 deployed-source-audit.json，使用对应 *-deployed.zip 为原目标函数重新执行 source-only 更新，保留 runtime/env/IAM。
2. 下载回滚后归档并核对原 SHA-256，检查三个目标状态为 ACTIVE。
3. 将 admin-before/ 文件按原 inventory 复制回 build/admin-web/current，最后替换 flutter_bootstrap.js 与 index.html，再核对 localhost:7359/main.dart.js 原哈希。
4. 用真实 Admin 账号重新加载并核对报表，避免对会员和账目做任何数据迁移。

本次没有 Rules、Indexes 或历史记录迁移。部署证据为 deployment-verification.json，客户端证据为 admin-activated.json。

## 尚待真实环境验收

- 已确认 Workout / Unified / Check-in 已部署校验版本差异，三个函数已更新，真实已登录 Admin Callable 的修复后响应仍需浏览器核对。
- FYP 完整 Workout 和 canonical Check-in profile/claim 一致性仍需实际范围诊断。
- 真实已登录 Admin 的 CSV 下载、tooltip、筛选竞态、组织或账户切换与 session revoke 尚需浏览器验收。
- 线上 Cloud Functions 请求次数、实际耗时、Firestore Reads 与优化前后基线尚未完整测量。
- Computer Use 无法可靠识别 Windows 浏览器当前 URL，因此已停止该浏览器操作。不能将服务文件哈希核验和 fixture 截图当作已登录页面验收。

## 交付位置

- 本地证据与回滚归档位于 build/admin-reports-analytics/。
- 主要预览为 screenshots/overview-1440.png 与 screenshots/overview-768-large-text.png。
- 仓库中没有加入真实用户数据、令牌或私人截图。

## Git

实现提交为 617fb59，包含报表改动及必要的既有 Timed Backup signature 兼容修复与测试。验收报告与运行文档另行提交。其他任务原有的未提交内容已保留。
