# 新 Session 衔接 Prompt — iOS 18+ 无 Apple-FM 版(RoastMate v1.2.0)

> 把下面整段(从「=== PROMPT 开始 ===」到「=== PROMPT 结束 ===」)贴给新的 Claude Code session。它是自包含的:不依赖任何上一段对话的记忆。

---

=== PROMPT 开始 ===

你接手 RoastMate(「帮你骂」)的一个**已评审通过的开发任务**:让 App 在 **iOS 18 / macOS 14 及以上**安装并正常出活,即使设备**没有** Apple Intelligence(Foundation Models)。FM 从「运行前提」降为「锦上添花」——有就走本地(保留隐私/离线),没有就**经用户同意**走现有的 Cloudflare 云端 Worker。

**先读这两份文件,它们是唯一事实源:**
- `docs/DEV_PLAN_iOS18_NO_APPLE_FM_2026-06.md` ← 完整开发计划,已被 Gemini 3.1 Pro + Codex 评审(结论 SHIP-WITH-FIXES,4 个 P0 修订已回填进文中)。**§4 是增量清单,§11 是评审结论。以 §11 修订后的增量顺序为准。**
- 本文件(衔接说明)。

## 已核实的代码事实(别重新推导,但动手前可自查)
- 部署目标当前 **iOS/macOS 26.0**(`project.yml:4-6`),watchOS 26.0(`project.yml:126`)。`MARKETING_VERSION 1.1.0` / build 15。线上版本 iOS v1.1.0 已上架(READY_FOR_SALE),**不要碰线上,在 `v1.1` 分支拉新 feature 分支做**。
- FM 触点:`Shared/AI/RoastEngine.swift`(actor,主引擎)、`Shared/AI/EchoesEngine.swift`。两者都只有**编译期** `#if canImport(FoundationModels)` 保护 + `SystemLanguageModel.default.availability == .available`;**全仓 0 处** `#available(iOS 26`。
- **关键坑(P0):** `RoastEngine` / `EchoesEngine` 持有**存储属性** `private var currentSession/session: LanguageModelSession?`。`LanguageModelSession` 是 iOS-26-only 类型 —— 一个 iOS 18 也要存在的类型**不能直接持有它**。降目标后会**编译不过**(不是运行崩)。解法:抽一个 `@available(iOS 26.0, macOS 26.0, *)` 的 `AppleFMBackend` 类把所有 FM 符号关进去,引擎通过**不带 @available 的协议** `(any FMBackend)?` 持有(iOS 18 上为 nil)。
- 云端路径已存在但只覆盖一部分:`Shared/Services/CloudVentClient.swift`(打 Worker `/v1/vent`,`CloudVentRequest` 无 `variantCount`、无收据,`mode` ∈ {nil/"vent","roommate"})。`RoastEngine.generate()` 的云分支(`RoastEngine.swift:107-144`)**只对 `intensity.isPrivateDraft`(vent/feral)** 生效,返回**单条**走**宽松** `validateVentOutput`。「能发出去」的模式(Calm/Sharp/Savage、20+ 风格、rewrite、吵架模拟)**没有云路径**,prompt 活在 App 端 `Shared/AI/PromptBuilder.swift`,Worker(`cloud-worker/src/index.js`)**不认识它们**。
- **同意门只在主 App:** `CloudConsentGate` 仅被 `RoastGeneratorViewModel/View` 引用。**`RoastMateShare/Sources/ShareRootView.swift:173`、`RoastMateWatch/Sources/WatchQuickPromptView.swift:84`、`RoastMate/Sources/Intents/GenerateRoastIntent.swift:66` 直接调 `RoastEngine.shared.generate(...)`,绕过同意门。** 一旦让「无 FM→云」全模式生效,这三个面会在 iOS 18 未经同意走云 = 硬性 5.1.2(i) 违规。
- `DeviceID.current()`(`Shared/Services/DeviceID.swift:11-19`)**已是 Keychain 持久 v4 UUID**(不是 IDFV,重装存活)—— 限流的持久标识不用重做。
- `RemoteConfig`(GitHub Pages 上的 `roastmate-config.json`,RESTRICT-only,fail-open)已就绪,可做远程熔断,无需过 Apple 审。

## 动手顺序(严格按此,P0 前置)
**先和用户敲定 §9 的开放决策**(尤其:Share/Watch/Intents 无 FM 时是「接同意流(a)」还是「仅本地+引导开 App(b)」—— 计划倾向 b;macOS 降 14 还是 15;watchOS 本期是否维持/摘 target;Pro 用收据校验的形态)。**这些决定影响增量 3 的形状,别先写代码。**

然后:
1. **增量 1** — 抽 `FMBackend` 协议 + `@available` 的 `AppleFMBackend`,把 `RoastEngine`/`EchoesEngine` 的 FM 触点全搬进去;引擎用协议类型持有;`isOnDeviceModelAvailable` 加 `#available` 门;`project.yml` 降目标 + FoundationModels 弱链接。**验收:iOS 18 模拟器冷启动 + 每模式不崩(本地模式此时落罐头,正常);现有测试全绿。**(注:开发机当前只有 iOS 26 runtime,需先装一个 iOS 18.x runtime。)
2. **增量 2** — Worker 加 `mode:"roast"` + rewrite,带 `styleName`+`intensity`+locale;`CloudVentRequest` 加 `variantCount`;App 端云分支按 `isPrivateDraft` 分叉(私密→单条宽松栏;sendable→`splitVariants`+逐条**严格** `validateOutput`)。**FM 与 Qwen 各维护一套 prompt**(共享风格目录 JSON,但指令各自调优),加对照测试盯漂移。云端 sendable 质量 eval 对标线上 vent。
3. **增量 3(P0,先于路由)** — 把同意/熔断判定**下沉到 `RoastEngine.generate()`**:除非传入「已解析同意」凭证 + RemoteConfig 允许,否则拒绝走云(不静默落云)。按用户对 Share/Watch/Intents 的 a/b 决策收口这三个面。**验收:iOS 18 上从这三个面未同意触发 → 用 fake `CloudVentService` 断言绝不出网。**
4. **增量 4** — `isOnDeviceModelAvailable == false` 时先走云(经增量 3 闸门)再落罐头。`ArgumentSimulatorViewModel` 等其它 FM 入口同改。
5. **增量 5** — App 端云路径加 `APP_DAILY_LIMIT_PER_DEVICE`(Pro/免费不同档,叠加边缘 IP 限流);`force_local_only` + `cloud_sendable_enabled` 远程熔断;Datadog 仪表盘 + 告警。
6. **增量 6** — 条件式隐私文案 + **改 App Store Connect 隐私营养标签**(声明采集 User Content + Identifiers 且 Linked)+ 复核 `RoastMate/PrivacyInfo.xcprivacy`。这是提交前硬验收项,漏了会被 5.1.1 拒。
7. **增量 7** — iOS 18 + iOS 26 双模拟器矩阵跑核心流;新增单测(无 FM→路由进云、云失败落罐头、未同意不出网)。
8. **增量 8** — v1.2.0,`cloud_sendable_enabled` 默认 **DARK** 发版 → 小流量开 → 看成本/质量/解析回退率(参照 roommate 的 35% kill / 15% enable bar)→ 全量。构建用 `scripts/build-upload-asc.sh`(keychain-free ASC API-key 流)。macOS 同步发。

## 硬约束(不可破)
- **不引入任何第三方追踪 SDK**(「无第三方 SDK」是产品护城河)。本期也**不**捆绑本地大模型(选项 B 已评估,暂缓)。
- **绝不在未同意时走云** —— 5.1.2(i) 红线,每个 P0 验收都要显式验证。
- **隐私优先**:云只收 `situation` + `deviceId`,不收 Apple ID / 不做跨源拼接。
- zh-Hans-first;改安全栏不放松硬栏(slur/暴力威胁/自残)。
- 改动走 `v1.1` 分支的新 feature 分支;每个增量独立编译 + 测试绿再进下一个。

## 重大产品/架构决策要双顾问会诊
按 Jason 的习惯:重大决策同时咨询 **Codex**(`Agent` subagent_type `codex:codex-rescue`)+ **Gemini 3.1 Pro**(`mcp__gemini__query`,model `gemini-3.1-pro-preview`),综合后再定。

先读两份文档 + 自查上面的代码事实,然后**找用户敲定 §9 的开放决策**,再从增量 1 开始。

=== PROMPT 结束 ===
