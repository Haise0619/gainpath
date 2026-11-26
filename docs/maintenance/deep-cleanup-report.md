# GainPath 深度清理与存储审计

2026-11-23（马来西亚时间）。本次维护在 `C:\Users\Ngzhe\StudioProjects\gainpath` 内执行。审计基线为 `codex/hybrid-workouts` 上的 `95ef039`，与本地 `origin/main` 相同。

## 存储变化

删除 **103.21 GB** 可重建文件。随后完成构建和测试，最终项目较清理前净减少 **100.27 GB**。验证期间新增约 **2.94 GB**，其中包括重新生成的编译/测试缓存、隔离 Web Release 和按 SHA-256 去重后的原 APK 备份。

| 指标 | 清理前 | 删除后、重建前 | 验证后 |
| --- | --- | --- | --- |
| 项目逻辑字节 | 248,313,127,352 | 145,100,177,644 | 148,042,593,170 |
| 常规文件数 | 514,313 | 490,801 | 491,954 |
| 目录数（不含根目录） | 166,607 | 158,011 | 158,344 |
| 跳过的 reparse 条目 | 3,478 | 3,478 | 3,478 |
| 扫描错误 | 0 | 0 | 0 |
| C 盘可用字节 | 17,339,555,840 | 120,359,489,536 | 117,544,615,936 |

大小是文件逻辑长度，GB 按十进制。目录扫描跳过 junction、符号链接和其他 reparse 条目，未对硬链接去重。C 盘空闲值为各扫描开始时系统返回的实际可用字节，受同卷其他写入影响。最终扫描包含验证产物，早于生成本报告与几份 CSV。

## 已执行的删除

| 生成物 | 路径数 | 删除逻辑字节 |
| --- | --- | --- |
| Android Gradle task intermediates | 252 | 71,258,017,792 |
| Flutter compiler cache | 59 | 13,887,690,703 |
| Flutter test cache or staged test assets | 64 | 9,014,373,374 |
| Windows Firebase C++ SDK extraction | 1 | 9,052,876,413 |

所有路径在执行前重新验证绝对位置、Git 忽略及跟踪状态、工作树关系、reparse 属性和内容。删除逐个用精确路径，结果 **376 项成功、0 项失败**。Android 只选择七种已确认的 Gradle 中间任务目录，保留 `build/app/outputs`、源码、包配置和回滚发行物。SDK 目录包含 183 个文件，全部与现存 `firebase_cpp_sdk_windows_13.12.0.zip` 逐字节相同且 CRC 校验通过。已保留 ZIP，CMake 可根据现存归档在本地重新解压；本轮未执行 Windows 桌面构建。

完整路径、字节与删除状态见本机 [removed-paths.csv](../../build/maintenance-verification/audit/removed-paths.csv)。这些详细审计清单存放于 Git 忽略目录。

## Git、发布与证据保护

| 已注册工作树 | HEAD | 处理 |
| --- | --- | --- |
| `C:/Users/Ngzhe/StudioProjects/gainpath` | `95ef03970e44` | 主检出，保留 |
| `C:/Users/Ngzhe/.codex/worktrees/module13-ai-personalization/gainpath` | `254fc8a62e1b` | 项目外，仅登记 |
| `C:/Users/Ngzhe/.codex/worktrees/workout-analytics-verify/gainpath` | `03aa67c0458f` | 项目外，仅登记 |
| `C:/Users/Ngzhe/StudioProjects/gainpath/build/module13-ai-worktree` | `254fc8a62e1b` | 项目内，保留 |
| `C:/Users/Ngzhe/StudioProjects/gainpath/build/module2-phase5a/clean` | `e8b0dd475c78` | 项目内，保留 |
| `C:/Users/Ngzhe/StudioProjects/gainpath/build/workout-optimization-20261111/clean` | `d8b9009699bb` | 项目内，保留 |
| `C:/Users/Ngzhe/StudioProjects/gainpath-demo-b2` | `51ddc66ef132` | 项目外，仅登记 |

七份已注册工作树的提交均可从本地 `origin/main` 到达。`build/workout-analytics-clean/source` 另有自己的 `.git`，也完整保留。项目无 stash；本地分支无未合入本地 `origin/main` 的提交。三份任务开始前的未跟踪文件均通过前后 SHA-256 比对。原有源码、`.run`、Firebase 配置/Rules、Android 项目配置、锁文件及所有 Git 历史仍在。`build/module13-ai` 的 junction 未遍历。

`build/admin-web/current`、Firebase Hosting 配置所用的 `apps/admin_web/build/web`、Admin App Check 本机配置及已发行 APK/回滚材料保留。现用 Web 的三个关键文件清理前后 SHA-256 相同。两处正常 Android Debug APK 输出在重建前经 SHA-256 保留原始副本。

## 重复内容与后续审批清单

以尺寸和首尾取样筛选，再对疑似重复归档做全文件 SHA-256。对删除后、重建前的 **644** 份至少 16 MiB 的 APK、AAB 与归档，发现 **200** 组完全相同内容，共 **498** 个匹配路径。若每组只保留一份，逻辑空间上限 **53.29 GB**；保留一份/组需要约 **33.90 GB** 的目标容量，另计文件系统余量。此为逻辑上限，实际可回收物理空间和可删路径须逐项核对发布引用、硬链接与回滚证据。

逐路径审批清单见 [archive-review.csv](../../build/maintenance-verification/audit/archive-review.csv)，包含 SHA-256、组号与实际字节；同一组“多余逻辑字节”在组内每行重复展示，按组计一次。另有 [held-cache-review.csv](../../build/maintenance-verification/audit/held-cache-review.csv) 记录落在工作树或其他保护边界的缓存。下列路径均保留，目录大小含其全部内容，不能与重复归档上限相加。

| 相对路径 | 验证后大小 | 批准前需核对 |
| --- | --- | --- |
| `build/non-core-crud-sprint` | 16.85 GB | 含旧发布、App Check 输入与私有留档。只审查各独立历史副本，先确认配置引用。 |
| `apps/mobile/build/pose-quality` | 8.52 GB | 原始相机记录、诊断、APK 和 FYP 证据。须由证据所有人决定是否外部归档。 |
| `build/module13-ai-worktree` | 3.53 GB | 已注册工作树与分支，另有 `build/module13-ai` 链接。须先审核独有工作、引用和归档方案。 |
| `build/workout-analytics-clean/source` | 2.96 GB | 独立 Git checkout，HEAD `657395783820`。保留源、Git 元数据及历史输出。 |
| `build/multi-branch-release` | 1.41 GB | Multi-Branch APK、Admin Web、发布与回滚证据。源 TAR 分别对应 `be09ad0` 和 `5efde21`，两个版本均保留。 |
| `build/operations-calendar` | 0.19 GB | 运营日历验证、发布和历史源码。关键 release 文档绑定到当时的 471 文件快照。 |
| `build/github-ci-repair` | 0.36 GB | CI 源码快照和执行证据。可先归档独立截图、日志并核对引用，再评估整份快照。 |

三份 GitHub CI 快照的 tracked 文件已对归档或 Git 提交逐文件核验。`fresh-run` 与 `exact-98c9830` 源码完全相同；`clean-ci-35bb50c` 保留早期源码基线与后续提交过的 Admin 单文件修订。该核验不等同于忽略输出也相同。运营日历和推荐总览的六份疑似重复源码快照拥有不同源码指纹，按各自历史版本保留。检查现有构建脚本未发现将整个工作树或依赖树复制至新快照的受版本控制逻辑。后续新建快照时用明确提交的 `git archive`，分开记录应用输出与回滚证明，根据下方预览清单处理已验证中间产物。跨盘归档先核对可用空间，复制并回读哈希，再确认源路径删除授权。

## 验证与日常使用

| 检查 | 结果 |
| --- | --- |
| Flutter workspace | `flutter pub get --offline --enforce-lockfile` 通过；Dart 架构检查通过，静态分析无错误或警告，73 条信息级提示。 |
| Member | 启用密码 OTP 的 Android Debug APK 构建成功；重点 Flutter 测试 52 项通过，1 项沿用原可选跳过。Android Studio Run 配置及 `google-services.json` 在位。 |
| Admin | 隔离目录的 Web Release 编译成功；重点 Flutter 测试 28 项通过，2 项沿用原可选跳过。现用静态服务处理器经回环 HTTP 对首页和主 bundle 返回 200。 |
| Functions | Node 22 TypeScript 编译、入口加载和测试类型检查通过；10 个测试文件共 95 项通过。 |
| Firestore Emulator | 在 Demo 项目及回环端口运行预约与聊天回归，11 项通过。 |
| Git | HEAD 保持 `95ef039`。版本控制内的业务源码与配置无内容差异；本地维护变更包括 `.gitignore`、清理工具和本报告。 |

验证为本机编译、静态服务和测试。设备安装、实际登录与生产部署不在此次验证范围。

从项目根目录运行脚本。默认仅预览，执行需要明确指定允许的生成目录。脚本拒绝 Git 内容、工作树、链接和正在使用的编译工具，并可生成逐路径结果 JSON。本地覆盖率输出已补充项目级忽略规则。

```powershell
pwsh -File tools/maintenance/clear-derived-builds.ps1
pwsh -File tools/maintenance/clear-derived-builds.ps1 -RelativePath apps/mobile/build/test_cache
pwsh -File tools/maintenance/clear-derived-builds.ps1 -RelativePath apps/mobile/build/test_cache -Apply
```

## 最大目录与文件

以下清理前盘点覆盖工作区及主要子层级，目录父子行存在重叠，行大小不可直接相加。

### 清理前各层目录前 30

| 排名 | 路径 | 字节 | GB |
| --- | --- | --- | --- |
| 1 | `build` | 202,663,357,792 | 202.66 GB |
| 2 | `apps` | 44,780,711,816 | 44.78 GB |
| 3 | `apps/mobile` | 36,940,930,690 | 36.94 GB |
| 4 | `apps/mobile/build` | 32,587,843,122 | 32.59 GB |
| 5 | `build/non-core-crud-sprint` | 16,846,584,544 | 16.85 GB |
| 6 | `apps/mobile/build/windows` | 11,067,903,423 | 11.07 GB |
| 7 | `apps/mobile/build/pose-quality` | 8,520,452,479 | 8.52 GB |
| 8 | `apps/admin_web` | 7,839,781,126 | 7.84 GB |
| 9 | `apps/admin_web/.dart_tool` | 5,793,159,206 | 5.79 GB |
| 10 | `apps/admin_web/.dart_tool/flutter_build` | 5,791,472,356 | 5.79 GB |
| 11 | `apps/mobile/build/test_cache` | 4,704,086,280 | 4.70 GB |
| 12 | `apps/mobile/build/app` | 4,488,641,041 | 4.49 GB |
| 13 | `build/non-core-crud-sprint/private` | 3,886,131,689 | 3.89 GB |
| 14 | `apps/mobile/.dart_tool` | 3,786,575,562 | 3.79 GB |
| 15 | `apps/mobile/.dart_tool/flutter_build` | 3,784,301,530 | 3.78 GB |
| 16 | `build/coach-preview-loading-20261108` | 3,662,003,331 | 3.66 GB |
| 17 | `build/coach-status-lifecycle-20261108` | 3,661,377,472 | 3.66 GB |
| 18 | `build/coach-roster-summary-20261108` | 3,660,896,839 | 3.66 GB |
| 19 | `build/module9-completion` | 3,595,439,118 | 3.60 GB |
| 20 | `build/module13-ai-worktree` | 3,533,109,102 | 3.53 GB |
| 21 | `build/commercial-checkout-20261113` | 3,387,900,785 | 3.39 GB |
| 22 | `build/checkout-load-fix-20261113` | 3,361,824,959 | 3.36 GB |
| 23 | `build/booking-pull-refresh-20261108` | 3,339,848,025 | 3.34 GB |
| 24 | `build/camera-setup-images-20261107` | 3,333,441,593 | 3.33 GB |
| 25 | `build/multi-branch-release` | 3,318,168,241 | 3.32 GB |
| 26 | `build/module13-ai-worktree/apps` | 3,302,978,222 | 3.30 GB |
| 27 | `build/workout-four-phases-20261107` | 3,222,249,838 | 3.22 GB |
| 28 | `build/booking-payment-ux-20261113` | 3,222,197,492 | 3.22 GB |
| 29 | `build/workout-hub-redesign-20261107` | 3,221,197,539 | 3.22 GB |
| 30 | `build/booking-consumer-20261113` | 3,198,625,257 | 3.20 GB |

### 清理前文件前 30

| 排名 | 路径 | 字节 | GB |
| --- | --- | --- | --- |
| 1 | `apps/mobile/build/windows/x64/extracted/firebase_cpp_sdk_windows/libs/windows/VS2019/MT/x64/Debug/firebase_firestore.lib` | 2,115,659,764 | 2.12 GB |
| 2 | `apps/mobile/build/windows/x64/extracted/firebase_cpp_sdk_windows/libs/windows/VS2019/MD/x64/Debug/firebase_firestore.lib` | 1,996,383,160 | 2.00 GB |
| 3 | `apps/mobile/build/windows/x64/extracted/firebase_cpp_sdk_windows/libs/windows/VS2019/MT/x86/Debug/firebase_firestore.lib` | 1,749,235,780 | 1.75 GB |
| 4 | `apps/mobile/build/windows/x64/extracted/firebase_cpp_sdk_windows/libs/windows/VS2019/MD/x86/Debug/firebase_firestore.lib` | 1,659,352,562 | 1.66 GB |
| 5 | `apps/mobile/build/windows/x64/firebase_cpp_sdk_windows_13.12.0.zip` | 962,899,485 | 0.96 GB |
| 6 | `apps/mobile/build/pose-quality/step2e-external/candidate/original.mp4` | 575,825,354 | 0.58 GB |
| 7 | `apps/mobile/build/pose-quality/step2e-external/control/original.mp4` | 501,800,667 | 0.50 GB |
| 8 | `apps/mobile/build/pose-quality/step2i-screen/control/original.mp4` | 368,130,457 | 0.37 GB |
| 9 | `build/xendit-verification/mobile-source/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 10 | `build/workout-visual-refresh-20261107/source/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 11 | `build/workout-optimization-20261111/clean/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 12 | `build/workout-hub-visual-20261107/source/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 13 | `build/workout-hub-redesign-20261107/source/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 14 | `build/workout-four-phases-20261107/source/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 15 | `build/workout-backup-default-20261115/source/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 16 | `build/workout-analytics-clean/source/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 17 | `build/report-rewards-consumer-20261112/clean/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 18 | `build/progress-dashboard-20261113/clean-source/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 19 | `build/pair-chat-20261108/isolated/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 20 | `build/multi-branch-release/source/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 21 | `build/module9-completion/source/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 22 | `build/module2-phase5a/clean/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 23 | `build/module13-consumer/clean-source/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 24 | `build/module13-ai-worktree/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 25 | `build/membership-renewal-premium-rewards-20261112/clean-1dc2c7f/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 26 | `build/membership-commercial-20261112/clean-896a211/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 27 | `build/member-coach-ux-20261108/isolated/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 28 | `build/member-coach-tabs-20261108/isolated/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 29 | `build/member-coach-data-20261109/isolated/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |
| 30 | `build/member-achievements-release-20261117/clean-mobile/apps/mobile/build/app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libflutter.so` | 358,479,752 | 0.36 GB |

### 验证后剩余最大目录

| 排名 | 路径 | 字节 | GB |
| --- | --- | --- | --- |
| 1 | `build` | 127,580,933,921 | 127.58 GB |
| 2 | `apps` | 19,592,652,486 | 19.59 GB |
| 3 | `apps/mobile` | 18,576,872,292 | 18.58 GB |
| 4 | `apps/mobile/build` | 17,888,824,461 | 17.89 GB |
| 5 | `build/non-core-crud-sprint` | 16,846,584,544 | 16.85 GB |
| 6 | `apps/mobile/build/pose-quality` | 8,520,452,479 | 8.52 GB |
| 7 | `build/non-core-crud-sprint/private` | 3,886,131,689 | 3.89 GB |
| 8 | `build/module13-ai-worktree` | 3,533,109,102 | 3.53 GB |
| 9 | `apps/mobile/build/app` | 3,452,396,984 | 3.45 GB |
| 10 | `build/module13-ai-worktree/apps` | 3,302,978,222 | 3.30 GB |
| 11 | `build/workout-analytics-clean` | 3,165,073,308 | 3.17 GB |
| 12 | `build/module13-ai-worktree/apps/mobile` | 2,990,972,828 | 2.99 GB |
| 13 | `build/workout-analytics-clean/source` | 2,955,775,988 | 2.96 GB |
| 14 | `build/workout-analytics-clean/source/apps` | 2,866,386,133 | 2.87 GB |
| 15 | `build/module2-phase5a` | 2,789,296,883 | 2.79 GB |
