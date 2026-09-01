# 虚拟舍友群 · 新 session 交接 Prompt（Echoes vNext）

> 把下面代码块整段发给一个新的 Claude Code 会话（在本仓库内）。
> 这是「先 roommate 增长冲刺」路径——与重设计 loop-first 工作**互斥**的近期主线；在它落地 + 真机评测出结论前，`docs/REDESIGN_HANDOFF_PROMPT.md` 暂停，别两条线同时跑（单人 + 都碰 RemoteConfig/Echoes，会打架）。
> 工程规格已对照真实代码审过（EchoVoiceCount 现为 .one/.two，加 .three 干净；EchoScene 尚不存在；echoesEnabled 默认 true；persona 为 zh-Hans）。完整规格见 `docs/ROOMMATE_GROUP_FEATURE_PLAN_2026-06.md`。

```text
你接手 RoastMate（帮你骂）的「虚拟舍友群」功能开发——它是 Echoes / 替你出气 的 vNext 场景，一个独立、可回退、flag 门控的增长实验，不是重设计的一部分。

仓库 /Users/jason/Documents/RoastMate，当前分支 v1.1。第一步：开分支 echoes/roommate-group。

【先读，作为 source of truth】
1. 会话注入的全局规则 + 项目 CLAUDE.md / 记忆（隐私护城河；发布工作流；重大架构决策同时咨询 Gemini 3.1 Pro + Codex 并综合）。
2. docs/ROOMMATE_GROUP_FEATURE_PLAN_2026-06.md —— 完整规格（角色、输出合同、UI、技术改动、测试、验收、开发顺序）。
3. docs/REDESIGN_DEVELOPMENT_PLAN_2026-06.md 的 §0 —— 本轮硬约束的来源。
4. 现有 Echoes 实现：Shared/Models/EchoesTypes.swift、EchoTranscriptRecord.swift；Shared/AI/Echoes{Engine,PromptBuilder,Parser,PersonaCatalog}.swift、FallbackRoasts.swift；Shared/Services/{EchoBridgeStore,RemoteConfig,EventLedger}.swift；RoastMate/Sources/Features/Echoes/*；Shared/Resources/echoes-personas-zh-Hans.json。
实现前先做一次简短代码审计；规格里的类名/约束若与现实不符，采用最小、兼容、可测试的实现，并在总结里说明偏差——不要停在规划。

【是什么 / 不是什么】
- 是：在已上线 Echoes 上加一个「发到舍友群，3 个合成舍友一起替你吐槽，最后 Bridge 成能发的话」的一次性、只读群聊视图。复用现有 Engine / SafetyFilter / Pro gating / Feral consent / History / Bridge-to-Action / RemoteConfig / EventLedger，不建第二套 AI 栈。
- 不是：重设计。别动 Generator 首页、三 Tab、Explore、旧导航。别加：群里回复输入框、长期记忆、真人姓名/头像/在线/已读、4 人以上、社区 Feed、第三方 SDK、四语言（v1 只 zh-Hans，缺失 locale 保持现有行为、不显示裸 key）。

【硬约束（违反即返工）】
- 隐私护城河不动：遥测只发本机聚合计数（roommate_group_started / completed / parse_fallback / bridge_tapped / regenerated），绝不记录用户输入、生成文本或自由文本错误。本轮不上任何服务端 / 第三方遥测。
- 新增独立远程开关 roommate_group_enabled，**默认关**，且与 echoes_enabled 做 AND。RemoteConfig 保持 restrict-only——远程值只能收紧权限，绝不能绕过用户 consent。
- 兼容迁移：EchoVoiceCount 加 .three = 3（不改 .one/.two 旧 raw value）；新增可选 EchoScene（.classic / .roommateGroup）+ EchoTranscriptRecord 可选 sceneRaw（nil 推导为 .classic）；旧 1/2 voice 行为、旧 SwiftData/CloudKit 数据零回归。新字段一律可选或有安全默认。
- 解析合同独立于 classic、且更硬：roommate 8–10 条、A/B/C 三角色各≥2 次、validate / reframe / bridge 必有、bridge 收尾；classic 仍 4–6 条。别为新模式放宽旧规则。解析失败进专用 curated roommate fallback（仍 3 角色 / 8 条 / Bridge 收尾），正常展示但单独记 parse_fallback，不伪装成模型成功。
- 每条模型输出继续过 SafetyFilter（validateInput + 逐条 validateVentOutput）；任一条触发 hard rail，整段进 fallback。保留 Pro gating 与现有 Feral consent sheet。第一版不实现 EchoesEngine 里当前关闭的 cloud routing TODO。
- project.yml 是 Xcode 工程的 source of truth，不直接编辑 xcodeproj；改了跑 xcodegen generate。先 git status，绝不删除/覆盖/回退不属于你的未提交文件（工作区有用户未提交内容）。

【评测门控——能否默认开启的唯一硬门】
- 先实现 prompt + parser + curated fallback + 类型/迁移（规格 §12 步骤 1–5），再做 UI。
- roommate 的解析合同比线上 classic（4–6 条）更严，真机 parse fallback 很可能更高，必须实测：真机 ≥20 个简中场景，parse fallback < 15% 才允许把 flag 默认开；≥35% 是硬 kill——停手、先修解析或上报，别强行上线。角色区分度、群聊连贯度人工各 ≥4/5。
- 你（代理）很可能跑不了真机评测（需要 Jason 的真机 + Apple Foundation Models 资产）。那就：把功能完整实现到「flag 默认关、可手动开、可评测」的状态，补齐测试，然后明确把「待 Jason 真机跑 20 场景评测」列为交付后的阻塞项，**不要自己假设通过就默认开**。区分代码失败与环境阻塞。

【必做测试（详见规格 §9）】
Parser（合法 3-role/8–10 条、拒 D、拒数量越界、拒角色<2 次、拒缺 validate/reframe/bridge、拒 bridge 非末位、classic 旧测试仍过）；Safety（任一条 hard rail → 整段 fallback）；Persistence（旧记录无 sceneRaw 读为 classic、新记录可存取 roommateGroup + voiceCount 3）；RemoteConfig（roommate flag 可单独关、echoes 总开关关时 roommate 必关、任何 flag 不扩大 cloud permission）；ViewModel/Bridge（原 situation + 建议 intensity 正确传入 Generator）；UI（Pro gate、生成/逐条 reveal、可跳过动画、Bridge、consent allow/deny、kill-switch 隐藏入口、VoiceOver 顺序、Dynamic Type、简中长文不截断 CTA）。
验证：改 project.yml→xcodegen generate；先跑相关单测再跑完整 RoastMateTests；iOS Simulator build；EchoesFlowUITests；可行时跑 scripts/preflight.sh（否则说明原因）。

【完成定义】
功能代码、兼容迁移、RemoteConfig flag（默认关）、聚合遥测、单元测试、UI 测试、文档全部落地；相关测试与 iOS 构建通过；真机评测门控写清并列为交付后阻塞。完成后更新 docs/ROOMMATE_GROUP_FEATURE_PLAN_2026-06.md 的状态与实际偏差，并更新当天 daily log。在 echoes/roommate-group 分支提交（测试绿后可提交）；未经明确要求不要 push、不要改写其他历史路线图。不要只给方案——直接实现、验证、总结。
```
