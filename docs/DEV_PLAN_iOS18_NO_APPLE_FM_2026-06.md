# 开发计划书 — iOS 18+ 兼容版(无需 Apple 本地 AI 也能运行)

**版本目标:** RoastMate v1.2.0
**作者:** Claude (Opus 4.8) · 2026-06-13
**状态:** DRAFT — 待 Gemini 3.1 Pro + Codex 评审后定稿
**分支基线:** `v1.1`(HEAD `11aeb21`),发布中的线上版本 = iOS v1.1.0(READY_FOR_SALE)

---

## 0. 一句话目标

让 RoastMate **能在 iOS 18 / macOS 14 及以上的设备安装并正常出活**,即使设备**没有** Apple Intelligence(Foundation Models)。FM 从「运行前提」降级为「锦上添花」:有就走本地、保留隐私与离线;没有就走云端(经同意),功能不缺。

### 0.1 为什么现在做

- 当前 `project.yml` 部署目标是 **iOS 26.0 / macOS 26.0**(被 FoundationModels 框架硬拽上去的)。
- Apple Foundation Models 只在 **iOS 26 + 开启 Apple Intelligence + 受支持机型(A17 Pro / M 系列起)** 才可用。
- 结果:今天 App 的**可安装人群 ≈ iOS 26 升级用户 ∩ 新机型**,是一个**极小的可触达市场(TAM)**。降到 iOS 18 能把可安装基数放大一个数量级以上。

### 0.2 Non-goals(本期明确不做)

- 不在本期捆绑第三方本地大模型(llama.cpp / MLC)。理由见 §4 选项 B —— 列为「评估过、暂缓」的备选,不是本期范围。
- 不改 watchOS 目标(仍 26.0,Watch 上没有可行的离线替代;本期 Watch 维持现状或临时下架该 target,见 §5.6)。
- 不新增任何**追踪类**第三方 SDK(「无第三方 SDK」护城河不动;推理引擎若未来引入另算,本期不引)。
- 不改 IAP / 定价 / Pro 门控逻辑。

---

## 1. 现状架构(基于代码实测,非记忆)

> 以下都来自 2026-06-13 对 `v1.1` 分支的实读,文件行号可点。

### 1.1 部署目标与框架链接

- `project.yml:4-6` → `iOS: "26.0"`,`macOS: "26.0"`;`project.yml:126` watchOS `26.0`。
- `MARKETING_VERSION 1.1.0` / `CURRENT_PROJECT_VERSION 15`(`project.yml:16-17`)。
- **FoundationModels 没有显式 weak-link 配置**(`project.yml` 里搜不到 frameworks/OTHER_LDFLAGS 段)—— 当前靠 26.0 部署目标隐式保证存在。**这是降版本后必须显式处理的第一颗雷。**

### 1.2 两个引擎都直接吃 FM,且只有编译期保护

- `Shared/AI/RoastEngine.swift`:on-device 主引擎。所有 FM 触点都包在 `#if canImport(FoundationModels)` 里(`RoastEngine.swift:1-5, 146-242`),非 FM 走 `curatedFallback()`(罐头文案)。`isOnDeviceModelAvailable` = `SystemLanguageModel.default.availability == .available`(`RoastEngine.swift:42-48`)。
- `Shared/AI/EchoesEngine.swift`:同样 `#if canImport` + `SystemLanguageModel.default.availability == .available`(`EchoesEngine.swift:4, 124`)。
- **关键风险:`grep` 全仓 `#available(iOS 26` / `#available(macOS 26` = 0 命中。** 没有任何**运行期**可用性门。
  - **【评审更正 / Gemini P0】** 我初稿写的是「`#if canImport` 拦不住运行期触碰 → 直接崩」,这是**事实错误**。真相更早暴露:`SystemLanguageModel` 等是 iOS-26-only 符号,**一旦把部署目标降到 18,项目根本编译不过**(成百上千个 `'SystemLanguageModel' is only available in iOS 26.0 or newer`)。所以加 `#available` 不是「防崩」,是「**让它能编译**」;而且 Swift 在 `#available` 下会**自动弱链接**框架(`project.yml` 里再显式声明是 defense-in-depth,不是必需)。
  - **【评审补充 / Codex P0】** 崩/编译面**不止方法体**:`actor RoastEngine` 持有**存储属性** `private var currentSession: LanguageModelSession?` / `currentSessionKey`,`EchoesEngine` 持有 `private var session: LanguageModelSession?`。**一个在 iOS 18 就要存在的类型,不能直接持有 iOS-26-only 类型的存储属性。** 这逼出「FM 必须抽进一个 `@available(iOS 26,*)` 后端类、外层用非门控协议持有」的重构 —— 见 §2 修订与 §11。

### 1.3 云端路径已存在,但只覆盖一部分模式

- `Shared/Services/CloudVentClient.swift`:HTTPS client,打 Cloudflare Worker `/v1/vent`。请求体 `CloudVentRequest{ situation, styleName, intensity, locale, deviceId, mode }`。`mode` ∈ {nil/"vent", "roommate"}。
- `RoastEngine.generate()` 的云端分支(`RoastEngine.swift:107-144`)**只在 `intensity.isPrivateDraft`(发泄 vent / 痛骂 feral)** 时触发,云失败 → fall through 到本地 FM,再 fall through 到罐头。
- **缺口:** 「能发出去」的那批模式 —— 体面 / 锐利 / 狠(Calm/Sharp/Savage)、20+ 风格、把草稿「改成能发的」(rewrite)、吵架模拟 —— **没有任何云端路径**,只有 FM-或-罐头。这些模式的 prompt 现在活在 App 端 `PromptBuilder.swift`,**Worker 不认识它们**。
- 云端同意门 `CloudConsentGate`(5.1.2(i),一次性同意)+ `RemoteConfig` 远程开关(`force_local_only` / `vent_cloud_enabled` / `roommate_group_enabled`)都已就绪,**RESTRICT-only**(只能 AND 收紧,不能放宽同意)。

### 1.4 由此推出的结论

> **降到 iOS 18 的真正工作量,80% 不在「降部署目标」,而在「给那些今天只能走 FM 的模式补一条云端真·AI 路径」+「把所有 FM 触点改成运行期可用性门控 + 框架弱链接」。**

---

## 2. 核心技术风险:让它先**编译得过**、再不崩(评审后重写)

> 初稿把这一节当「防 dyld 崩」,评审更正:**降目标后是编译不过**(Swift 编译期强制可用性)。所以本节的目标顺序是「编译通过 → 运行期正确门控 → 弱链接兜底 → iOS 18 真机验证」。

1. **【先做】把 FM 抽进一个 `@available(iOS 26.0, macOS 26.0, *)` 后端类,让引擎通过「非门控协议」持有它。** 这是为了解决 §1.2 的**存储属性**问题:`actor RoastEngine` / `EchoesEngine` 不能直接持有 `LanguageModelSession?`。规范形状(待 Codex 给出可编译版本后定稿,§11):
   ```swift
   // 协议本身不带 @available —— 任何 OS 都能持有 (any FMBackend)?
   protocol FMBackend: Sendable {
       func respond(system: String, user: String, temperature: Double, maxTokens: Int) async throws -> String
       var isAvailable: Bool { get }
   }
   // 实现类带 @available,只在 if #available 块里实例化:
   @available(iOS 26.0, macOS 26.0, *)
   final class AppleFMBackend: FMBackend { /* 持有 LanguageModelSession,所有 FM 符号只出现在这里 */ }

   actor RoastEngine {
       private var fm: (any FMBackend)?   // ← 存储的是协议类型,iOS 18 上为 nil,合法
   }
   ```
   待 Codex 确认的坑:协议 witness 的可用性、`if #available` 在 actor-isolated 方法内的用法、`Sendable` 跨边界 —— §11 收口。
2. **每个残留 FM 符号触点包运行期门 `if #available(iOS 26.0, macOS 26.0, *)`。** 抽进后端类后,引擎层应几乎不再直接出现 FM 符号;`isOnDeviceModelAvailable`:
   ```swift
   static var isOnDeviceModelAvailable: Bool {
       #if canImport(FoundationModels)
       if #available(iOS 26.0, macOS 26.0, *) {
           return SystemLanguageModel.default.availability == .available
       }
       #endif
       return false
   }
   ```
3. **弱链接是兜底,不是主手段。** Swift 在 `#available` 下会自动弱链接 FoundationModels;`project.yml` 里再显式声明 weak framework 作为 defense-in-depth(不是编译/启动的必要条件)。
4. **验证手段:在 iOS 18 模拟器真启动。** 当前开发机只装了 iOS 26 runtime;必须装一个 iOS 18.x runtime,跑冷启动 + 触发每个模式(含 Share / Watch / App Intents 三个独立入口,见 §5.4),确认无 `dyld: Symbol not found` 且功能正常。

---

## 3. 选项分析:iOS 18 设备上,「本地模式」用什么出活?

| | A. 无 FM 时走云端(经同意) | B. 捆绑小本地模型 | C. 混合(A 现在 + B 后续) |
|---|---|---|---|
| 复用现有基建 | ✅ Worker/同意门/远程开关已在 | ❌ 全新推理栈 | ✅ 先 A |
| 质量 | ✅ 高(Groq Qwen3-32B 同线上 vent) | ⚠️ 1.5–3B 明显弱于 FM/云 | ✅ |
| 离线 | ❌ iOS 18 失去离线 | ✅ 真离线 | ✅ 后续补 |
| 隐私叙事 | ⚠️ 「本地」在旧设备变云端,文案/合规要改 | ✅ 仍本地 | ⚠️→✅ |
| App 体积 | ✅ 不变 | ❌ +0.5–2GB,过 App Store 蜂窝下载阈值 | ⚠️ |
| 第三方依赖 | ✅ 无 | ⚠️ 引入推理框架(护城河争议) | ⚠️ |
| 成本 | ⚠️ 旧设备基数大→云用量可能飙升 | ✅ 端侧零边际成本 | ⚠️ |
| 工期 | ✅ 最短 | ❌ 最长(模型选型/量化/集成/调优) | 中 |
| App Review 风险 | ⚠️ 5.1.2(i) 范围扩大 | ⚠️ 体积 + 模型内容审查 | ⚠️ |

### 推荐:**选项 A 作为 v1.2**,把 B 作为已评估的后续阶段(v1.3+ 视云成本与离线需求再定)。

理由:基建已在;质量有保证;工期最短;最大风险(隐私叙事 + 成本)都可控且有现成抓手(同意门 + RemoteConfig 远程熔断 + Datadog 成本监控 + 每设备限流)。捆绑模型的体积与质量代价在「先把可触达市场打开」这个目标面前不划算。

---

## 4. 详细实施计划(增量式,每个增量可独立编译 + 测试绿)

### 增量 1 — 弱链接 + 运行期门控(纯防崩,行为不变)
- `project.yml`:iOS / macOS 部署目标降到 **iOS 18.0 / macOS 14.0**(具体 macOS 取 14 还是 15 由 §5.6 决定);FoundationModels 显式 weak-link。
- 抽 `AppleFMBackend`(`@available(iOS 26.0, macOS 26.0, *)`),把 `RoastEngine` / `EchoesEngine` 里所有 FM 触点搬进去,外层用运行期 `#available` 门 + 弱引用持有。
- `isOnDeviceModelAvailable` 按 §2.2 改写。
- **验收:在 iOS 18 模拟器冷启动 + 每个模式都不崩**(此时本地模式还落罐头,正常)。现有 257+ 测试全绿。

### 增量 2 — Worker 扩展:覆盖「能发出去」的模式
- Worker(`cloud-worker/src/index.js`)新增 `mode:"roast"` 分支(以及 rewrite),携带 `styleName` + `intensity`(calm/sharp/savage)+ locale,服务端构造对应 system/user prompt。
- **【评审 P0 / Gemini #1】多变体 + 解析 + 严格安全栏。** 当前云分支(`RoastEngine.swift:107-144`)是为 vent 写的:返回**单条**草稿、走**宽松**的 `validateVentOutput`。sendable 模式(Pro 出 3 变体)**不能照搬**,否则 iOS 18 的 Pro 用户只拿到 1 条、格式标签泄漏、且强语言绕过严格栏。必须:
  1. `CloudVentRequest` 增 `variantCount: Int`(synthesized `encodeIfPresent`,老 vent 调用点不变);
  2. Worker 生成编号变体;
  3. App 端云分支**按 `intensity.isPrivateDraft` 分叉**:私密草稿 → `[validateVentOutput(text)]`;sendable → `PromptBuilder.splitVariants(text)` 后**逐条过严格 `validateOutput()`**,失败丢(沿用 `try` 非 `try?` 语义)。
- **【评审 P2 / Gemini #5】单一事实源是个陷阱 —— 改为「共享目录、双 prompt」。** Apple FM 与 Groq Qwen3-32B 指令跟随特性不同,一套 prompt 调到 FM 最优会在 Qwen 上劣化(反之亦然)。**决策修订**:共享一份「风格目录 JSON」(名称/ID/UI 色/locale 支持),但 **system 指令与格式规则两边各自维护、各自调优**;用一个对照测试(同一输入两端跑)盯漂移,而不是强行合并成一份。
- 加一个 eval:云端 sendable 模式在 zh-Hans 上的质量/解析通过率,对标线上 vent 的标准。

### 增量 3 —【评审 P0 / Codex #2】同意门下沉到引擎层(必须先于路由改造)
> **这是评审新增、且必须在「无 FM → 云」路由打开之前完成的 P0。** 经核实:`CloudConsentGate` 只被 `RoastGeneratorViewModel`/`View` 引用;而 `RoastMateShare/ShareRootView.swift:173`、`RoastMateWatch/WatchQuickPromptView.swift:84`、`RoastMate/Sources/Intents/GenerateRoastIntent.swift:66` **都直接调 `RoastEngine.shared.generate(...)`,不经同意门**。今天安全(这三个入口不触发云分支);但增量 4 一旦让「无 FM → 云」对所有模式生效,**这三个面会在 iOS 18 上未经同意静默走云 = 硬性 5.1.2(i) 违规。**
- **修复:同意/熔断判定不再由各 ViewModel 各自算。** 让 `RoastEngine.generate()` 自身成为唯一闸门:除非传入「已解析同意」的凭证 + `RemoteConfig` 允许,否则**拒绝走云**(返回 `.consentRequired` 之类,而不是静默落云)。
- Share / Watch / App Intents 三个面二选一:(a) 接入同一套同意流(Share/Watch 上弹同意可能体验差→倾向 b);(b) 在无 FM 时**仅本地罐头 + 引导「打开 App 生成」**,不在这些面走云。**决策点见 §9。**
- **验收:在 iOS 18 上,从 Share/Watch/Intents 触发且未同意 → 绝不出网**(用 fake `CloudVentService` + 网络断言验证)。

### 增量 4 — 路由改造:无 FM → 云端(经同意)而非罐头
- `RoastEngine.generate()` / `rewriteAsSendable()` / `EchoesEngine`:当 `isOnDeviceModelAvailable == false` 时,**先尝试云端**(经增量 3 的引擎级闸门:`CloudConfig.isConfigured` + 已解析同意 + RemoteConfig 允许),云失败再落 `curatedFallback`。
- `ArgumentSimulatorViewModel` 等其它走 FM 的入口同样改。
- 在 FM 可用的设备上,本地模式**不**触发云同意(行为不变)—— 同意只在「确实要走云」时弹。
- **验收:iOS 18 模拟器上,体面/锐利/狠/改写/吵架模拟都能出真·AI 文案**(经同意);拒绝同意 → 优雅落罐头 + 明确提示。

### 增量 5 — 成本与滥用控制(见 §6)
### 增量 6 — 合规文案 + **隐私营养标签**(见 §5.1 / §5.5)
### 增量 7 — 测试矩阵 + 真机/双模拟器验证(见 §7)
### 增量 8 — 灰度与发布(见 §8)

---

## 5. 隐私与 App Review(最高风险区)

### 5.1 5.1.2(i) 同意范围扩大
今天的同意文案/隐私说明说「体面/锐利/狠/改成能发的 = Apple 本地模型;发泄/痛骂/虚拟舍友群 = 云端」。**降版本后这句话在 iOS 18-25 设备上不成立** —— 那些模式也走云。

- 文案改为**条件式**:「**当你的设备支持 Apple 本地模型时**,这些模式在设备本地运行,不上传任何内容;**否则**(系统较旧或未开启 Apple 智能),需你**同意后**改由我们的云端处理,可随时在设置里关闭并退回本地罐头模式。」
- App Store 隐私「营养标签」需复核:云端会收到 `situation` 文本 —— 这在 vent 路径已披露过,现在覆盖面更广,披露口径要统一。
- **Gemini 之前抓过的 P0(α2′ cloud-consent breach):任何「默认就走云、没先同意」的路径都是 5.1.2(i) 违规。** 本期路由改造**绝不能**在未同意时静默走云 —— 这条是红线,增量 3 的验收必须显式验证「未同意 → 不出网」。

### 5.2 内容分级 / 17+
不变(已是 17+)。云端覆盖面扩大不改变分级,但要确保云端 sendable 模式同样过 `SafetyFilter`,不因换路径而放松硬栏(slur/暴力威胁/自残)。

### 5.3 2.3.1「所见即所审」
提交 Apple 审的那个 build,必须就是开启了 iOS 18 云路由的 build;审核员若用 iOS 18 设备,看到的就是云路径(带同意)。reviewer notes 要说明:本地模型仅在 iOS 26 + Apple Intelligence 设备可用,其余走经同意的云端。

### 5.4 【评审 P0 / Codex #2】非主入口的同意覆盖
Share Extension / Watch / App Intents 三个面**不经** `CloudConsentGate`(已核实,见增量 3)。**5.1.2(i) 要求每一个会把内容送上云的入口都先拿到同意**,不只是主 App。增量 3 把闸门下沉到 `RoastEngine` 是结构性修复;若选「这些面无 FM 时只本地」(§9 决策 b),也要保证它们在 iOS 18 上**不**调云。

### 5.5 【评审 P1 / Gemini #4】隐私营养标签 + PrivacyInfo.xcprivacy
不只是 in-app 同意文案。把 `situation` 文本 + `deviceId` 送云 = 在 App Store Connect「隐私营养标签」里**采集** User Content(文本)+ Identifiers(设备 ID)、且**与用户关联**(Linked,用途 App Functionality)。
- 若现标签声明的是「不采集 / 不关联」,与 iOS 18 云行为**矛盾 → Guideline 5.1.1 拒**。
- 同步复核仓内 `RoastMate/PrivacyInfo.xcprivacy`(隐私清单)是否需要补对应的收集类型 / API 使用原因。
- 这一步独立成增量 6 的硬验收项,提交前必须改完。

---

## 6. 成本与滥用控制(旧设备基数大,必须先设闸)

- **【评审更正 / Codex】持久标识已就绪。** Gemini 担心「`deviceId`=IDFV,重装即重置→限流可绕过」—— **本仓不是 IDFV**:`Shared/Services/DeviceID.swift` 的 `DeviceID.current()` 已是 **Keychain 持久化 v4 UUID**(`DeviceID.swift:11-19`,重装/同 App Group 内存活)。所以「持久性」这半已解决;残留的真实缺口是下面两条。
- **每设备每日云调用上限(待建)**:Web 端已有 `WEB_DAILY_LIMIT_PER_IP=8`;App 端云路径**尚无**对应上限,需加 `APP_DAILY_LIMIT_PER_DEVICE`(按 `deviceId`,Pro 与免费不同档)。免费用户在旧设备上若无限免费云调用 = 成本敞口。注意 Keychain UUID 仍可被「抹掉所有内容」/越狱清除 → 这是**软控制**,真要硬控需叠加 Cloudflare 边缘的 IP 维度限流(已有)+ 异常模式封禁,别只靠单一维度。
- **【评审 P1 / Gemini #3】Pro 校验缺失。** Worker 现在**收不到收据**,无法安全判断某 `deviceId` 是不是 Pro → 没法给 Pro 更高额度而不被冒充。需在 `CloudVentRequest` 附可验证的 App Store 收据(或一个服务端可校验的轻凭证),Worker 校验后再发额度。**决策点见 §9。**
- **RemoteConfig 熔断**:复用现有远程开关。新增/复用 `force_local_only`(全局踢回本地)+ 一个 `cloud_sendable_enabled`(单独熔断 sendable 云路径,出问题时不连累 vent)。
- **Datadog**(两个 Worker 已接)加 sendable 模式的调用量 / 错误率 / token 仪表盘 + 异常告警阈值。
- **定价含义**:旧设备免费用户的云成本谁兜?决策点(见 §9 开放问题):是否把「无 FM 设备的云生成」也算进免费额度并更激进引导 Pro。

---

## 7. 测试与验证

- **双 OS 模拟器矩阵**:iOS 18.x(无 FM)+ iOS 26(有 FM)各跑一遍核心流。需先装 iOS 18 runtime。
- **新增单测**:`isOnDeviceModelAvailable == false` 时路由进云、云失败落罐头、未同意不出网(用 `CloudVentService` 的 fake)。
- **崩溃面**:iOS 18 冷启动 + 每模式触发,确认无 FM 符号在运行期被碰(`dyld` 干净)。
- **回归**:现有 257+ 测试全绿;`EchoesParser` / `SafetyFilter` 行为不变。
- **eval**:增量 2 的云端 sendable 质量 eval 通过线上 vent 同等标准方可开闸。
- **2.3.1**:提交前真机/模拟器 smoke,确保审核 build = 开闸 build。

---

## 8. 灰度与发布

- 版本 **v1.2.0**(`MARKETING_VERSION 1.2.0`,build 续号)。
- **远程开关默认 DARK**:`cloud_sendable_enabled` 先 false 发版 → 线上小流量开 → 看成本/质量/解析回退率 → 全量。沿用 roommate 的「DARK→eval→flip」节奏。
- **杀准则(沿用现有模式)**:云端 sendable 解析/安全回退率 ≥ 阈值(参照 roommate 的 35% kill / 15% enable bar)→ 远程 `cloud_sendable_enabled:false`,无需过 Apple。
- 构建用现成的 keychain-free ASC API-key 流(`scripts/build-upload-asc.sh`)。
- macOS 同步降版本随 iOS 一起发(§5.6)。

---

## 9.0 已敲定的决策(2026-06-14,实施 session 与 Jason 确认)

| 问题 | 决策 | 影响 |
|---|---|---|
| 辅助入口(Share/Watch/Intents)无 FM 时 | **(b) 仅本地罐头 + 引导「打开 App 生成」**,这三个面**绝不走云** | 增量 3 形状 |
| macOS 部署目标 | **macOS 14.0(Sonoma)** —— 最大化可触达 | 增量 1(`project.yml`) |
| watchOS | **维持 26.0 不动**(Watch 上无可行离线/云路径;FoundationModels 也不在 watchOS SDK 里) | 增量 1 |
| Pro 额度校验 | **`CloudVentRequest` 附 App Store 收据,Worker 校验后发 Pro 额度** | 增量 5 |

实施分支:`feature/ios18-no-apple-fm`(基线 `v1.1` HEAD `11aeb21`)。
增量 1 的 `FMBackend` 抽象形状经 Codex + Gemini 3.1 Pro 二次会诊定稿(`protocol FMBackend: Sendable` 无 availability;`@available(iOS 26) actor AppleFMBackend` 独占 FM 符号;`respondCached`/`respondFresh` 分离以保住 rewrite 的 fresh-session 语义;`GenerationError` 在后端内映射成 `FMBackendError`;`fm` 为 `nonisolated let` 让 `isOnDeviceModelAvailable` 同步可读;显式 `-weak_framework FoundationModels` 兜底)。

## 9. 留给评审 / 待定的开放问题(原始)

1. **macOS / watchOS 范围**:macOS 降到 14 还是 15?watchOS 本期是维持 26.0(Watch 上无云 UI?)还是临时摘掉该 target?
2. **PromptBuilder 单一事实源**:sendable prompt 移植到 Worker 后,App 端本地 FM 路径与 Worker 云路径**两份 prompt 如何防漂移**?(提案:共享一份风格目录 JSON,prompt 模板各自渲染但同源参数。)
3. **免费用户云成本**:无 FM 设备的免费云生成是否限额 + 是否更激进引导 Pro?定价是否要为「旧设备 = 必走云 = 有边际成本」单独设计?
4. **隐私叙事**:把「本地优先」改成「设备支持则本地、否则经同意走云」,营销与 App Store 文案统一口径(避免「本地 AI」被指虚假宣传)。
5. **选项 B(捆绑模型)** 是否要在本计划里给一个明确的「触发条件」(例如云月成本 > X 或离线需求验证后)再启动,而不是无限期搁置?
6. **vent 安全栏 vs sendable 安全栏**:云端 sendable 输出走 `validateOutput`(严格)还是有中间档?旧设备上「狠 Savage」走云后的强度是否与本地 FM 一致?
7. **【评审新增】Share / Watch / App Intents 在无 FM 时怎么办?** (a) 接入完整同意流,还是 (b) 仅本地罐头 + 引导「打开 App 生成」?(倾向 b,体验/合规都更稳。)
8. **【评审新增】Pro 校验机制**:`CloudVentRequest` 附 App Store 收据让 Worker 验 Pro 额度,还是用别的服务端可校验凭证?加签防伪怎么做?

---

## 10. 风险登记

| 风险 | 等级 | 缓解 |
|---|---|---|
| iOS 18 启动崩(FM 符号/链接) | P0 | 弱链接 + 运行期 `#available` 门 + 双模拟器冷启动验证(增量 1 验收) |
| 未同意静默走云(5.1.2(i) 违规) | P0 | 增量 3 验收显式验「未同意不出网」;同意门 RESTRICT-only |
| 云成本失控 | P1 | 每设备限流 + RemoteConfig 熔断 + Datadog 告警 |
| 「本地 AI」虚假宣传指控 | P1 | 条件式文案 + 隐私标签复核 |
| 未同意静默走云 — **非主入口**(Share/Watch/Intents) | **P0** | **增量 3:同意门下沉到 `RoastEngine`**;或这些面无 FM 时仅本地(§5.4) |
| 编译不过(降目标后 FM 符号 + 存储属性) | **P0** | 后端类抽象 + `@available` + 协议持有(增量 1,§2) |
| 隐私营养标签与云行为矛盾 → 5.1.1 拒 | P1 | 增量 6 改标签 + `PrivacyInfo.xcprivacy`(§5.5) |
| Pro 无法被 Worker 校验 → 额度被冒充 | P1 | `CloudVentRequest` 附可验证收据(§6) |
| 云成本失控 | P1 | 每设备软限流 + 边缘 IP 限流 + RemoteConfig 熔断 + Datadog |
| 「本地 AI」虚假宣传指控 | P1 | 条件式文案 + 隐私标签复核 |
| 双源 prompt 漂移 | P2 | 共享风格目录 JSON + **双 prompt 各自调优** + 对照测试盯漂移 |
| 云端 sendable 质量/格式不达标 | P2 | DARK 默认 + eval 开闸门 + 多变体解析 + 严格安全栏 |

---

## 11. 评审结论与已采纳的修订(Gemini 3.1 Pro + Codex,2026-06-13)

**两位顾问独立评审,结论一致:`SHIP-WITH-FIXES`。** 核心策略(FM 可用走本地、不可用经同意走云、降到 iOS 18 放大可触达市场)成立;但初稿有 4 处必须修的硬伤,已全部回填进上文。所有「更正/补充」标记的条目都已对照真实代码核实(非记忆)。

### 已采纳(按严重度)

| # | 来源 | 等级 | 问题 | 已落到 |
|---|---|---|---|---|
| 1 | Gemini | **P0** | 初稿「降目标会 dyld 崩」说法**事实错误** —— 实际是**编译不过**(Swift 编译期强制可用性);`#available` 是为编译、不是防崩 | §1.2、§2(整节重写) |
| 2 | Codex | **P0** | 崩/编译面不止方法体:`actor` 持有 `LanguageModelSession?` **存储属性**,iOS 18 上非法 → 必须抽 `@available` 后端类、协议持有 | §1.2、§2.1 |
| 3 | Codex | **P0** | Share / Watch / App Intents **绕过同意门**直接调 `RoastEngine`(已核实 3 处行号)→ 增量 4 一开就是 5.1.2(i) 违规 → 同意门必须**下沉到引擎层**,且**先于**路由改造 | 新增**增量 3**、§5.4 |
| 4 | Gemini | **P0** | 云分支为 vent 写的(单条 + 宽松栏),sendable 模式**不能照搬**:需 `variantCount` + `splitVariants` + **严格** `validateOutput` | 增量 2 |
| 5 | Gemini | P1 | 隐私**营养标签**(非 in-app 文案)须声明采集 User Content + Identifiers 且 Linked,否则 5.1.1 拒 | §5.5、增量 6 |
| 6 | Gemini | P1 | Worker 收不到收据 → 无法验 Pro 额度 → 需附可验证收据 | §6 |
| 7 | Gemini | P2 | 「单一 prompt 源」是陷阱(FM≠Qwen)→ 改「共享目录 + 双 prompt 各自调优」 | 增量 2 |

### 评审纠正了 Gemini 的一条(经代码核实)
- Gemini P1 说「`deviceId`=IDFV,重装重置→限流可绕」。**核实:本仓 `DeviceID.current()` 已是 Keychain 持久 v4 UUID**(`DeviceID.swift:11-19`),不是 IDFV。持久性这半**已解决**;残留的是「App 端云路径还没限流」+「Worker 无法验 Pro」两条真缺口(已分别落到 §6)。

### 增量顺序(修订后,P0 前置)
**1** 后端类抽象 + 弱链接 + 门控(编译过、不崩,行为不变) → **2** Worker 扩 sendable(多变体 + 严格栏 + 双 prompt) → **3** 同意门下沉引擎层(P0,先于路由) → **4** 无 FM→云 路由 → **5** 成本/滥用闸 → **6** 合规文案 + 隐私标签 → **7** 测试矩阵(iOS18/26 双跑) → **8** DARK 灰度发布。

### 仍开放(交给新 session 在动手前与用户敲定,见 §9)
macOS/watch 范围、Share/Watch/Intents 的 a-or-b、Pro 收据校验形态、选项 B 触发条件、Savage 走云后的强度对齐。

---

*评审完成(SHIP-WITH-FIXES,修订已回填)。新 session 无缝衔接 prompt 见 `docs/HANDOFF_iOS18_NO_APPLE_FM.md`。*

---

## 12. 实施进度

### 增量 1 — 弱链接 + 运行期门控(✅ 完成 + 已验证,2026-06-14)
分支 `feature/ios18-no-apple-fm`(基线 `v1.1` HEAD `11aeb21`)。
- **`FMBackend` 抽象**(`Shared/AI/FMBackend.swift` + `AppleFMBackend.swift`):`protocol FMBackend: Sendable`(无 availability)+ `enum FMBackendError` + `FMBackendFactory.make()`;`@available(iOS 26, macOS 26, *) actor AppleFMBackend` 独占所有 FM 符号,守卫 `#if canImport(FoundationModels) && (os(iOS) || os(macOS))`(把 watch 排除干净)。`respondCached`/`respondFresh` 分离保住 rewrite 的 fresh-session 语义;`GenerationError` 在后端内映射成 `FMBackendError`,FM 类型零泄漏。
- **两引擎**(`RoastEngine`/`EchoesEngine`):改为 `private nonisolated let fm: (any FMBackend)?`(`isOnDeviceModelAvailable` 同步可读 `shared.fm?.isAvailable`;`resetConversation()` → `await fm?.reset()`);行为不变。
- **⚠️ 计划遗漏的第二处 iOS-26 触面 = 语音**:`VoiceVentTranscriber`(iOS-26 `SpeechAnalyzer`/`DictationTranscriber`/`AssetInventory`)同样硬依赖 26,降目标即编译不过。**根因同 §1.2(全仓 0 处运行期门 → 降目标暴露所有 26-only API,不止 FM)。**

### 增量 1b — 语音 iOS 18 回退(✅ 完成 + 编译/启动已验证,2026-06-14)
> Jason 拍板:不接受 iOS 18 无语音,**为 iOS 18 补 `SFSpeechRecognizer` 路径**(功能对齐)。
- 同 `FMBackend` 的后端拆分:新增 `RoastMate/Sources/Features/Voice/SpeechRecognitionBackend.swift`(`@MainActor protocol SpeechRecognitionBackend`(无 availability)+ `@MainActor enum VoiceBackendFactory` + `LegacySpeechBackend`)+ `ModernSpeechBackend.swift`(`@available(iOS 26) actor`-风格 class,把原 SpeechAnalyzer 逻辑原样搬入)。`VoiceVentTranscriber` 改成 iOS-18+ 的 `@Observable` 协调器(持有 `(any SpeechRecognitionBackend)?`,共享 mic/speech 权限 + gate),`VoiceVentSheet` 去掉 `@available`,`RoastGeneratorView` 去掉 `if #available`(语音入口在 iOS 18 也显示)。
- **隐私红线照旧**:`LegacySpeechBackend` 强制 `requiresOnDeviceRecognition = true`,且 gate 与 `start()` 双重校验 `supportsOnDeviceRecognition`(本地不支持的 locale → 隐藏语音,**绝不走云**);无 pre-26 `AssetInventory` → fail-closed。`stop()` 用 `CheckedContinuation` + 1.5s 超时拿 final transcript(单次 guarded resume 防 double-resume)。形状经 Codex 会诊定稿(5 处修订全采纳:@MainActor factory、`@MainActor @Sendable` 回调、continuation 模式、双重 on-device 校验/legacy 不深拷、assets-fail-closed)。
- **验收**:iOS 26 sim 编译通过、0 error、无并发/Sendable 警告;iOS 18.5 模拟器冷启动成功(进程稳定、UI 渲染)。**真机 iOS 18 的实际转写质量(zh-Hans on-device)需物理设备验证**(模拟器通常无 on-device 语音模型,与 roommate eval 同属 device-only)。
- **`project.yml`**:iOS `18.0` / macOS `14.0`(watchOS 维持 `26.0`);5 个 FM-编译目标(RoastMate/Mac/Share/Controls/Tests)加 `-weak_framework FoundationModels` 兜底。实测产物里 FoundationModels **连 load command 都没有**(全被 dead-strip,纯弱),iOS 18 启动零负担。
- **验收(全绿)**:① iOS 18.0 / macOS 14.0 / watchOS 26.0 三平台均编译通过;② 278 单测 + UITests 全绿、0 失败(1 个 device-only roommate eval 按设计 skip);③ **iOS 18.5 模拟器冷启动成功**(无 dyld「Symbol not found」,主界面完整渲染,进程稳定,语音入口已隐藏)。④ 无-FM→落罐头路径由那 278 个测试覆盖(模拟器上 model 本就 unavailable)。交互式「点 Generate」因 Simulator 控制授权弹窗未批准而跳过,不影响结论。

### 增量 2-8 — 待开始
下一个:增量 2(Worker 扩 `mode:"roast"` + rewrite,多变体 + 严格安全栏 + 双 prompt)。
