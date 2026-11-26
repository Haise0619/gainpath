本次使用专用会员，完成了线上 Workout Backup → Recommendation Engine → Member Inbox 的三类自动生成和投递。Tutorial、Routine、Coach 各生成一条，三条都有实际投递回执。完整预约验收仍受测试账号的 Free 会员等级限制。

自动投递的 Gemini 请求在当时的 3 秒期限内超时，三条保存为 rule_fallback。随后用同一测试资料进行了独立的真实 Gemini 排序诊断，9.140 秒内成功返回，三类首选均保持规则首选。诊断结果没有覆盖已投递记录。后台等待期限已调整为 15 秒并部署验证。

**账号及数据性质**

专用会员邮箱为 gainpath.m13.e2e.20261117@example.test，UID 为 m13-e2e-20261117，显示名为 Module 13 TEST — Automated Recommendations。账号与密码保存在[登录资料](../../build/module13-three-kind/credentials.private.json)。账号已通过 Firebase 邮箱密码登录检查，邮箱是测试地址，不能用于收信。

测试会员填写 Build muscle、Beginner、Lightly active，身高 170 cm、体重 70 kg。训练摘要是人工准备的 FYP 测试输入，每笔 Squat 为 8 次、tracked 8 秒、rejected 2 秒、Form Score 为 null。协议中的 realCamera provenance 用于复现现行备份契约，不能作为真实相机采集或实际动作准确性的证据。测试账号显示名、UID 和所有训练 ID 都明确包含测试标识。

共保留一个 Auth 账号、五份备份及其修订、四项授权的审计和命令回执、三份推荐、三份 Inbox、三份投递回执和三份冷却记录。完整路径见[数据保留清单](../../build/module13-three-kind/inventory.json)。没有删除测试或业务记录。真实会员账号没有写入；全组织汇总可能包含这个新增测试会员及五份人工摘要，核对报表时可按清单中的 memberId 排除，不能把这些摘要解释为真实训练。

**实际自动触发结果**

| 类型 | 规则候选数 | 规则首选及实际投递 | 保存的方法 | Inbox / Receipt |
| --- | --- | --- | --- | --- |
| Tutorial | 3 | Squat，来自 Testing 发布记录中的 Squat 教学 | rule_fallback，timeout | 各 1 条 |
| Routine | 4 | Beginner Upper Body Basics | rule_fallback，timeout | 各 1 条 |
| Coach | 1 | Jackson，main 分店 | rule_fallback，timeout | 各 1 条 |

Tutorial ID 为 68bd48b7b2a835f91dc2b839f2839b6f4eacecba738578847cb8f778fa5a7c47。
Routine ID 为 734396271047c19e1c58cfad624d9d894a4301f7f3adca05e3451ce397859c87。
Coach ID 为 ee0afcd60fe8813def56bc4261c9c96723e206915430c8206a97fae798663ecc。

三份推荐位于 orgs/gainpath/canonicalRecommendations/{ID}，对应投递回执位于 orgs/gainpath/canonicalRecommendationDeliveries/{相同 ID}。Inbox 的通知 ID、正文及关联推荐 ID 全部保存在[实际响应与回执](../../build/module13-three-kind/results.private.json)。

实际保存的理由分别为以下内容。

- Tutorial 使用近期 Squat 和 Beginner 匹配，保存理由为 “Build on your recent Squat practice. Matches your beginner experience level.”
- Routine 使用 Beginner 和 Build muscle 匹配，保存理由为 “Matches your beginner experience level. Supports your goal of building muscle.” 这套 Upper Body Routine 没有声称与 Squat 是同动作匹配。
- Coach 使用 Build muscle 与教练 Strength Training 标签匹配，保存理由为 “Supports your goal of building muscle. This coach specializes in building muscle.”

正常 Admin 邮箱 ngzy-pm23@student.tarc.edu.my 对应的现有管理员身份，通过相同后端详情授权检查后能读取三份完整记录。没有创建额外 Admin。该检查使用 CLI 只读调用现有授权与详情服务；浏览器内手动登录验收不包含在这项检查中。

**输入和时间**

五笔备份位于 orgs/gainpath/members/m13-e2e-20261117/workoutBackups/session-module13-test-squat-20261117-1 至 session-module13-test-squat-20261117-5。每笔的 payloadJson、digest、修订和来源保留在 Firestore。第五笔通过现有 workoutBackupCommand 的 save 操作写入，随后由真实 Firestore 创建事件生成三种推荐。

第五笔备份的实际 Firestore 创建时间为 2026-11-17 23:43:12.695 MYT，三份回执原子提交于 23:43:21.806 MYT。备份提交到实际原子投递为 9.111 秒。save callable 自身用时 668 ms。这里使用 Firestore createTime 计算，避免用事件处理开始时写下的 createdAtMillis 低估提交耗时。[实际提交时间](../../build/module13-three-kind/timings.json)

前四笔被用于原始失败复现及经过批准的诊断。它们没有生成推荐。第五笔是在明确注册 CloudEvent 修复后提交的最终验证输入。

**Gemini 的实际贡献**

自动链路的首次请求同时覆盖三个类型，在 3 秒期限内超时，没有可用的模型输出与 token usage，因此实际投递使用规则回退。Admin 不应把这三条显示为 Gemini 生成。

第二次请求是独立的真实 Gemini 诊断，使用同一测试账号已有备份派生的匿名候选及最少必要特征。该请求没有创建或更新推荐、通知、冷却或投递回执。

| 项目 | 实测值 |
| --- | --- |
| 模型 | gemini-3.5-flash-lite |
| Provider | gemini |
| 总诊断耗时 | 9,140 ms |
| Provider 记录耗时 | 9,139 ms |
| Input tokens | 441 |
| Output tokens | 238 |
| Total tokens | 679 |
| Thinking tokens | 未提供 |
| Cache hit | false |
| Tutorial 首选变化 | false |
| Routine 首选变化 | false |
| Coach 首选变化 | false |

679 tokens 属于一次共享排序请求，不能分别算成三次。规则和 Gemini 在这份测试输入上选择了相同首选，不能据此声称 Gemini 改善准确率。对比与使用的特征见[真实 Gemini 诊断](../../build/module13-three-kind/real-ranking-probe.json)。已使用授权上限 3 次中的 2 次请求，余下 1 次没有使用。[请求预算](../../build/module13-three-kind/generation-budget.json)

**目的地、冷却及去重**

- Tutorial 实际目的地为 routine_v2_7FxVCqK5NTlaykyRhNzA 的 Squat 教学。发布状态、动作 ID、索引和教学步骤通过检查，实际导出的记录通过现有 Flutter Tutorial 路由打开。
- Routine 实际目的地为 routine_v2_gp-beginner-foundations-upper-body-20261107。用该真实发布快照和推荐响应执行 Flutter 导航，Preview Routine → Start Workout 到达现有 RoutineJourneyRoute，routine.id 保持一致。没有进行真机摄像训练。
- Coach 实际目标为 381n2NHBcTMwBUFhp1IZwaMfSsL2，Jackson，main 分店，Strength Training 标签匹配 Build muscle。认证、分店与连续 60 分钟时段资格通过。测试账号的实际预约接口返回 permission-denied，要求有效 Basic 或 Premium 会员。完整预约流程因此没有通过线上验收，没有创建预约、支付或付费资格记录。
- 三种推荐均保存了 untilMillis = createdAtMillis + 7 天的冷却记录。
- 精确重试第五笔相同备份后，Inbox 从 3 条保持为 3 条，没有创建重复通知。跨新来源的冷却抑制另由后端回归覆盖。

[目的地与管理员授权检查](../../build/module13-three-kind/destination-checks.json) · [同一备份重试](../../build/module13-three-kind/duplicate-check.json)

**实际运行 Flutter 的截图**

截图由真实线上测试账号已保存的响应与发布快照驱动现有 Flutter Widget。它们是 Flutter 渲染和路由测试，不代表真机签入或正常 Admin 浏览器的手动操作验收。Admin 截图使用本机 Barlow 字体替代离线环境的默认字体；缺少实际媒体的内容显示现有占位图。

| 类型 | Member 卡片 | Member 详情 | Admin View Details |
| --- | --- | --- | --- |
| Tutorial | [卡片](../../build/module13-three-kind/screenshots/member-content-card.png) | [详情](../../build/module13-three-kind/screenshots/member-content-details.png) | [排名对比](../../build/module13-three-kind/screenshots/admin-content-ranking.png) |
| Routine | [卡片](../../build/module13-three-kind/screenshots/member-routine-card.png) | [详情](../../build/module13-three-kind/screenshots/member-routine-details.png) | [排名对比](../../build/module13-three-kind/screenshots/admin-routine-ranking.png) |
| Coach | [卡片](../../build/module13-three-kind/screenshots/member-trainer-card.png) | [详情](../../build/module13-three-kind/screenshots/member-trainer-details.png) | [排名对比](../../build/module13-three-kind/screenshots/admin-trainer-ranking.png) |

Admin drawer 的上半部分另保存为 admin-content-details.png、admin-routine-details.png 和 admin-trainer-details.png。

**发现的问题与修复**

1. 旧 Coach 候选只验证一个 30 分钟时段，实际新预约需要连续 60 分钟。现已验证两个连续时段、同一可用窗口、会员冲突和教练每日容量，推荐目标也保存 60 分钟。增加只有 30 分钟空档时必须排除教练的回归。
2. 线上 Functions Framework 默认按 HTTP 加载事件导出，导致事件处理函数拿到 HTTP Request，params、文档快照和 subject 均缺失。前四份测试备份的 204 返回不能解释为生成成功。现已明确注册四个 Firestore CloudEvent 入口，并用生产 Functions Framework loader 在默认 http 条件下验证实际解析为 cloudevent。普通备份入口也校验实际文档路径。第五笔线上备份完成了修复后的真实自动投递。
3. 3 秒模型期限不足以覆盖这次 9.139 秒的真实 Gemini 推理。后台排序期限已提高到现有 provider 支持的 15 秒，保留失败回退。新期限已经部署并核对源码；当前三份已投递记录仍保留原来的 timeout / rule_fallback，没有重写历史或重新投递。
4. Coach 的 Free 会员预约限制是本次尚未通过的验收项。要完成实际预约入口的最终检查，需要具备有效付费资格的专用测试会员。当前测试范围没有授权新增付费资格或支付凭据，因此保留实际拒绝结果。
5. 通过历史重放诊断的尝试被自动审批拒绝，理由为超出已批准的备份触发测试范围；没有执行。后续输入均通过新增且单独获批的测试备份触发。

[CloudEvent loader 验证](../../build/module13-three-kind/loader-verified.json) · [最终线上部署验证](../../build/module13-three-kind/timeout-release/release-verified.json)

**回归结果**

| 检查 | 结果 |
| --- | --- |
| Backend 排序、生成、投递与新回归 | 53 通过 |
| Auth + Firestore + Functions Emulator 自动流程 | 5 通过，32 项因选择运行范围跳过 |
| Member Inbox、卡片和导航回归 | 24 通过 |
| Admin monitor / View Details 回归 | 21 通过 |
| 使用实际导出记录的 Member 路由与截图 | 2 通过 |
| 使用实际导出记录的 Admin 截图 | 1 通过 |
| TypeScript 源码类型检查 | 通过 |
| 线上发布 | 源码归档与部署包一致，既有 Rules、索引、IAM 经比较验证 |

后端日志为 build/module13-three-kind/backend.log，Emulator 为 emulator-cloudevent.log，Flutter 为 mobile-regression.log、admin-regression.log、member-live-navigation.log 和 admin-render.log。测试脚本复用现有框架，没有新增测试平台。

后续审查与清理应以 inventory.json 的逐路径清单为依据。本次保留了全部输入、诊断、生成记录和回执。

