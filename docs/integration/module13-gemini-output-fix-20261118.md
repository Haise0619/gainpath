本轮已完成最小修复、六个入口的生产部署及真实自动触发验收。2026-11-18 经用户批准，新增一笔专用会员 Curl Backup，实际生成并投递 method=gemini 的 Tutorial 推荐。下文“待批准”段落保留为部署前范围记录，最终结果以下表为准。

**最终生产验收：通过**

| 项目 | 实际结果 |
| --- | --- |
| 已保存方法 | gemini |
| 推荐类型 / 候选 | Curl Tutorial / 2 |
| 模型 | gemini-3.5-flash-lite |
| 推理耗时 / Total tokens | 629 ms / 227 |
| Rule-Based 与 Gemini 首选 | 均为 Standing single-arm dumbbell curl |
| 改变首选 | 否；Gemini 排序通过校验，本次首选一致 |
| Backup 至投递 | 4,301 ms |
| Inbox / Delivery Receipt | 1 条通知，回执存在 |
| Member resolve | available，正确目标 |
| Admin | 正常 Admin 身份获准读取，详情方法为 Gemini |
| Flutter 展示及导航 | Member 2 项、Admin 1 项通过 |

Recommendation ID：`26c62b85edfcf539f636f9706f6a90a23a53a7b76f6086ad3510e2503286f6ad`

Backup：`orgs/gainpath/members/m13-e2e-20261117/workoutBackups/session-module13-test-curl-20261118-output-v2`

Receipt：`orgs/gainpath/canonicalRecommendationDeliveries/26c62b85edfcf539f636f9706f6a90a23a53a7b76f6086ad3510e2503286f6ad`

备份通过正常 workoutBackupCommand 保存，真正的 Firestore onCreate 日志记录 delivered: 1、HTTP 204。没有直接创建推荐、修改 aiMethod、覆盖旧记录或清除冷却。本次额外授权的一次真实请求已用完；原三次预算保持不变。旧 Tutorial、Routine、Coach 记录保留原方法，本次验证的是新 Curl Tutorial。

六个入口仅更新 buildConfig.source；部署前基线与回滚包已保存，部署后实际源码一致，其余 73 个 Functions、服务配置、IAM、Rules 和索引保持不变。[部署核验](../../build/module13-output-fix/release-verified.json)。

截图使用本次真实生产记录与已发布目标，经现有 Flutter Widgets 渲染；Member 测试验证 Watch Tutorial 打开正确路由。Admin 权限核验使用正常 Admin 身份及线上数据。没有另行登录手机或浏览器拍摄，不声称真实设备 UAT。离线图片使用既有占位图。既有 Admin 文案“Gemini personalized reason”不代表理由文本由模型生成：理由仍由后端真实特征生成，本次未修改 UI。

[Member 详情截图](../../build/module13-output-fix/screenshots/member-content-details.png) · [Admin 排序详情截图](../../build/module13-output-fix/screenshots/admin-content-ranking.png) · [生产结果](../../build/module13-output-fix/acceptance.json) · [事件日志](../../build/module13-output-fix/acceptance-event-logs.json) · [请求预算](../../build/module13-output-fix/request-budget.json)

[Member Flutter 日志](../../build/module13-output-fix/member-acceptance.log) · [Admin Flutter 日志](../../build/module13-output-fix/admin-acceptance.log)。完整回执与 Inbox 路径保存在忽略版本控制的 acceptance-result.private.json。测试账号和全部测试数据保留，未删除业务或历史记录。Rules Fallback 由本地测试和 Emulator 回归验证，没有额外调用生产 Gemini 制造失败。

**失败定位**

此前 Calf Raise 记录保存了模型、7,505 ms 和 330 tokens，因此 Gemini HTTP 响应和 provider envelope 解析已经通过。拒绝发生在后续模型文本 JSON 解析或排序校验阶段。

该笔原始模型文本没有保存，不能追溯确认它究竟遗漏了哪个字段、返回了哪个错误标签或引用了哪个不支持的特征。原来的 invalid_provider_output 合并了这些分支。此次没有重新调用真实 Gemini 来猜测历史响应。

代码确认存在以下契约风险。

- 原模型输出必须同时给出 recommendationType、selectedCandidateId、ranking、relevantWorkoutFactors。
- selectedCandidateId 必须再次等于 ranking 的第一项，形成不必要的重复输出约束。
- relevantWorkoutFactors 必须是第一候选特征的子集，最多三项。Gemini 无需承担这一步，因为特征本来由后端掌握。
- provider 的通用 schema 转换只保留基础结构和 required，原来的枚举、maxItems 和 additionalProperties 没有发送给模型。后端却严格验证这些约束。
- 旧错误码没有区分 JSON、字段、候选和引用问题，日志中也没有保留足够信息定位具体分支。

这些是可确认的契约与诊断缺口，不能当作那次历史响应具体失败字段的证据。

**最小修复**

Gemini 输出改为仅含 rankedCandidateIds 的对象。例如两个 Tutorial 候选的合法输出为 {"rankedCandidateIds":["T2","T1"]}。

后端继续维护匿名标签到真实目标的映射。返回数组必须覆盖本次发送的全部标签，每个恰好一次；类型、真实 ID、目标资格、授权、冷却与投递不由模型决定。混合类型的数组按前缀映射回各类型，只采用同一类型内的相对顺序。

只有一个合资格候选的类型直接使用规则选择，并保存 single_eligible_candidate，不发送该类型给 Gemini。若剩余类型有多个候选，仅向模型发送这些需要排序的候选。输出无效时保留规则首选。

最终推荐理由由服务器依据已选候选的已验证特征生成。模型不再返回理由、推荐类型、重复首选或证据引用。理由长度继续受现有记录契约约束。

新 promptVersion 为 module13-workout-v2，以避免复用旧输出契约的缓存。现有模型、15 秒期限、请求预算和资格校验沿用现有实现。

排序被拒绝时，既有 fallbackReason 仍为 invalid_provider_output，额外保存内部 validationFailure，并仅记录失败码和候选数量。具体代码包括以下值。

| 内部代码 | 含义 |
| --- | --- |
| invalid_json | 模型文本无法解析为 JSON |
| missing_required_field | 缺少 rankedCandidateIds |
| extra_field | 出现额外字段 |
| invalid_structure | 顶层或排序数组类型不正确 |
| invalid_candidate_id | 标签不存在、类型不对或使用真实 ID 代替匿名标签 |
| duplicate_candidate_id | 标签重复 |
| incomplete_ranking | 排序遗漏候选 |

该诊断不记录原始 Prompt、会员信息或完整模型文本。单候选类型也不会被错误附上其他类型 Gemini 请求的 token 或模型元数据。

**修改文件**

- [排序 Prompt、Schema、校验及 ID 映射](../../functions/src/modules/recommendation/workout-recommendation-ranking.ts)
- [保存具体失败码、单候选原因及服务器理由](../../functions/src/modules/recommendation/workout-backup-recommendation-runtime.ts)
- [可选内部诊断字段的 TypeScript 类型](../../functions/src/modules/recommendation/canonical-recommendation-lifecycle.ts)
- [排序与传输 fixtures](../../functions/test/workout-recommendation-ranking.test.ts)
- [生成、回执与 Calf 回归](../../functions/test/workout-backup-recommendations.test.ts)

没有修改 UI、Membership 或 Firebase 架构。

**测试证据**

| 检查 | 结果 |
| --- | --- |
| 后端排序、自动投递、provider 传输 | 74 项通过 |
| TypeScript 源码检查 | 通过 |
| TypeScript 测试类型检查 | 通过 |
| Auth、Firestore、Functions Emulator 自动流程 | 5 项通过，32 项因选择运行范围跳过 |
| 真实 Gemini 调用 | 部署前 0 次；批准后 1 次，生产验收通过 |
| 生产部署 | 六个入口已部署并核验 |

Calf 回归构造了与生产同类的 context，包含 muscle_gain、beginner、regular 和 moderate；仅有两个 content 候选 T1、T2。模拟 provider 返回 ["T2","T1"] 后，实际生成和投递服务保存 method=gemini、candidateCount=2、changedTopChoice=true，创建投递回执，会员 resolve 返回 available 和 aiMethod=gemini。该证据来自本地模拟 provider，不能当作真实模型效果或生产验收。

其他 fixtures 覆盖单候选跳过模型、2/3/6 个候选、最多十八个混合候选、完整与不完整排列、未知/重复/非字符串 ID、缺失/额外字段、无效 JSON、超时、429 回退、缓存以及依据缺失时不编造理由。无效 ID 的具体失败码也通过了保存回归。

[后端日志](../../build/module13-output-fix/backend-final.log) · [Emulator 日志](../../build/module13-output-fix/emulator.log)

**待批准的最小生产范围**

已离线准备六个既有生成入口的源码包，每个仅替换两个推荐模块的 JavaScript 与 source map。

- module13MemberCommand
- fypDatasetCommand
- module13WorkoutBackupCreated
- module13WorkoutConsentChanged
- module13FypWorkoutBackupCreated
- module13FypWorkoutConsentChanged

类型声明变化不产生需额外部署的运行时代码。Admin 和 Inbox 的既有读端可读取当前记录，因此没有加入此次部署范围。部署方式为 buildConfig.source 更新；上线前仍需核对实际线上源码与准备包的基线是否一致。每个入口的基线和回滚包已经列入[离线部署清单](../../build/module13-output-fix/deployment-plan.json)。

另需新授权一次真实 Gemini 请求和一笔专用测试会员的合格 Workout Backup。原三次请求预算已用完，本轮没有增加或重置它。

拟继续使用 m13-e2e-20261117，在上线前只读确认未处于冷却期且至少有两个合资格教学候选的动作。清单暂定 Standing single-arm curl；如果其候选条件不满足，先报告实际条件。输入通过正常 workoutBackupCommand 保存，再等待真实 Firestore Trigger。验收必须读取新推荐保存的 method、具体失败码、Inbox 回执、会员 resolve 和 Admin 详情。

以上为部署前授权范围记录；批准后已按范围完成，最终生产验收见本文开头。
