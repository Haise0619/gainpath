# GainPath Member Achievements

## 徽章目录

| 徽章 | 解锁条件 |
| --- | --- |
| First Check-in | 成功领取首次每日签到 |
| Three-day Streak | 连续 3 个马来西亚日历日签到 |
| Seven-day Streak | 连续 7 个马来西亚日历日签到 |
| Two-week Champion | 连续 14 个马来西亚日历日签到 |
| First Workout | 完成 1 次符合资格的训练 |
| Workout Regular | 完成 5 次符合资格的训练 |
| Century Club | 在有效的 AI 训练记录中累计 100 次完整动作 |
| Routine Finisher | 在一次保存完成的 Routine 训练中完成当天全部项目 |

## 资格与历史数据

- AI Routine 的完成依据是同一会员已同步的真实摄像头 Session。每项须满足该项的组数和次数，双侧或单侧弯举以已完成组数与每臂目标为准。独立弯举使用保存的目标与完成组数。固定 3 × 8 的独立俯卧撑练习使用 24 次完整动作作为完成门槛。只有动作次数、缺少可确认的完成目标的历史独立记录可以贡献 Century Club 进度。
- Video Timed 使用现有计时记录验证完整目标，Manual 使用明确保存且达到目标的自报组数。两者都可以组成完整的 Routine，当作一次训练。视频、手动和部分动作产生的次数均不计入 AI 完整动作。
- 跳过、提前结束或只完成部分项目的 Routine 不计为完整训练。关联的 Exercise Session 不另算完整训练。真实、完整的单次动作仍可累计到 Century Club，Session ID 只计算一次。
- 工作记录继续沿用 Workout Backup 的本地保存、同账号同步和冲突处理。启用现有备份后，已保存记录同步成功才可用于服务端确认。备份关着时，训练历史继续留在本机，云成就保持最近确认状态。
- 普通会员和同一默认数据库中的正式 FYP cohort 会员按同一规则读取各自的 canonical 记录。预设 fictional 记录、录制 fixture 和真实摄像头记录的来源保留，只有符合现有正式备份校验的资料可进入计算。显式独立的旧 `datasetScope` 会话显示成就不可用。

## 接口和 Firestore

`appCheckInCommand` 新增 `{schemaVersion: 1, organizationId, action: 'achievements'}`。一次调用返回当前 Streak、徽章目录、每枚徽章的目标和进度，以及已确认的解锁时间。鉴权复用原有 Auth、App Check、当前身份、活跃会员和组织校验。客户端无会员 ID 参数。

`overview` 与 `claim` 的 v1 响应继续包含原来的 3 枚签到徽章，顺序、金额、钱包和凭证结构沿用当前逻辑。签到仍提供每日 50 基础积分。8 枚徽章本身都没有积分奖励。历史的三枚徽章从现有签到档案读取，14 天徽章从会员自己的不可变签到凭证重建。

服务端读取 `orgs/{org}/members/{uid}/workoutBackups` 的当前版本，用 ID、来源、摘要和既有验证器判断资格。里程碑首次确认后以事务保存到 `orgs/{org}/members/{uid}/achievementProgress/v1`，并发同步保留首次保存的解锁时间。历史进度每次按来源记录计算，避免累加重复的备份或修订版本。历史扫描按 100 条分页，不会停在固定的历史条数。14 天解锁只求值一次，四枚训练徽章均已解锁后跳过训练历史扫描。还有未完成的训练目标时，刷新会扫描该会员训练备份；极大历史的延迟没有线上基准。

## 客户端

Rewards 与 Profile 共用账号范围内的徽章收藏。收藏页展示总览、当前签到连续天数、最近目标、分组网格以及锁定和解锁详情。账号范围内合并并发请求，正常显示时在两分钟内复用内存结果，并在签到、备份同步和恢复连接后刷新。最近确认状态从账号范围内的本地缓存读取，支持离线重启。首次确认的解锁可触发可关闭的提示，历史成就的首次载入不触发提示。

分享卡在本机生成，包含 GainPath 标志、徽章、说明和日期。Android 通过临时文件的只读 URI 打开系统分享菜单，图片分享失败时回退到文本。卡片不包含会员身份、完整训练记录或姿势评分。

## 本地验证结果

| 验证 | 结果 |
| --- | --- |
| Backend 相关单元测试 | 81 项通过，含签到、训练备份、完整与跳过的项目、会员与组织隔离、FYP 来源、逾一千条历史分页和重复同步 |
| Firestore Emulator | 5 项通过，含并发确认、旧版三徽章响应和私有成就档案的 Rules 拒绝验证 |
| Flutter 相关回归 | 46 项通过，含两处收藏入口、320dp／390dp、200% 字体、详情、返回键、减少动态效果、PNG 生成和文本回退，以及离线缓存和账号切换 |
| GainPath Domain | 198 项通过 |
| 静态检查 | Backend 源码与测试 TypeScript 检查通过，12 个相关 Flutter 路径的 Dart Analyze 无问题 |
| Android Debug Build | `flutter build apk --debug --no-pub --dart-define=APP_CHECK_IN_ENABLED=true --dart-define=WORKOUT_CLOUD_BACKUP_ENABLED=true` 通过 |

APK 位于 `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`。SHA-256 为 `03D33A5FF3E4B78355810E8EBD180827802D8C6D1204C44DF91DCE8B48F3D759`。APK 从当前工作区构建，包含工作区已有的其他进行中改动。Git 提交只收录本次成就系统。

## 部署

2026 年 11 月 17 日已在 `gainpath-0619` 的 asia-southeast1 完成 `functions:appCheckInCommand` 源码更新。发布包保留原生产版签到实现，并开放新增的成就操作。包内测试确认连续签到 14 天仍每天发放 50 积分，旧版响应包含三枚徽章，成就操作返回八枚。线上源码 SHA-256 为 `4f17e42704e5f01b024874261d22fdb97ffd9c6168437f24d1138bb36d8c0c6e`，已与上传包比对。线上匿名请求返回 HTTP 401，既有 IAM、Rules 和另外 78 个 Functions 的配置通过比对。

从提交 `ee3f2cb` 单独构建的 APK 位于 `build/member-achievements-release-20261117/clean-mobile/apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`。SHA-256 为 `57c4e7a713c1e95d34b2408257d2b79de7341be9000f151c7036552576323bdf`。期间 Xiaomi 测试机已通过另一轮构建更新。设备 APK 与当时的本机构建哈希一致（`b71311ab528073eb30b62f5b0fbbdf7b1649fc898f0ebff0686dd16f51011148`），并确认包中含收藏页、解锁提示及分享图稿。设备保留该版本，实际训练和分享验收仍待完成。

## 真机验收

1. 使用已验证的普通会员和 canonical FYP 会员，通过 Rewards 和 Profile 分别进入收藏。检查 320dp、390dp、200% 字体、返回键与切换账号。
2. 完成一次真实 AI Routine，确认结果页面能正常保存和返回。备份已启用的情况下先断网后恢复，确认仅同步一次，相关徽章只提示一次。再完成 Video Timed 和 Manual 流程，对照完整与跳过的 Routine。
3. 开启系统减少动态效果，检查解锁提示可关闭。分别用已解锁徽章和未解锁徽章打开详情，核对进度和日期。
4. 通过 Android 系统菜单分享图片，检查接收端可读取分享卡，卡片不含身份或训练隐私。回到应用、切换前后台并确认分享不会阻塞正常导航。
