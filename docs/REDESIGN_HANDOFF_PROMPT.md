# 重设计开发 · 新 session 交接 Prompt

> 把下面代码块整段发给一个新的 Claude Code 会话（在本仓库内打开），即可无缝开始重设计开发。
> 已通过 Gemini 3.1 Pro + Codex 独立评审，约束已写入 `docs/REDESIGN_DEVELOPMENT_PLAN_2026-06.md` 的 §0。

```text
你接手 RoastMate（帮你骂）的「重设计」开发。这是一个已上线、隐私优先、中文优先的 iOS/macOS 情绪表达 App：
本地 Apple Foundation Models + 可选、按用途同意的云端生成（Cloudflare Worker → Groq/OpenRouter），无第三方 SDK。
iOS v1.0.6 已上架，macOS v1.0.6 在审。仓库 /Users/jason/Documents/RoastMate，当前分支 v1.1。

【第一步：读这些，作为本任务的 source of truth】
1. 会话注入的全局规则 + 项目 CLAUDE.md / 记忆（隐私护城河、发布工作流、"重大决策同时咨询 Gemini 3.1 Pro + Codex 并综合" 的习惯）。
2. docs/REDESIGN_DEVELOPMENT_PLAN_2026-06.md —— 重设计主计划。**务必先读 §0 评审修订；与正文冲突处一律以 §0 为准。**
3. README.md（注意：内容已过时，是 Phase 0 要修正的对象之一）。

【本轮硬约束（来自 §0，不可违反）】
- 隐私护城河不动：本轮不上线任何服务端/第三方遥测（数据方案选 B）。量化只用现有 A′ 本地手动导出，定性用 TestFlight 队列访谈。任何"数据不离开设备"的对外声明必须继续为真。
- 只重构、不加新功能。「虚拟舍友群」等新特性不在本轮 scope（独立实验，后置）。
- 先 loop-first 最小验证，不要一上来全量拆 IA。用 feature flag（restrict-only，沿用现有 RemoteConfig 模式：baked-in 默认 + 缓存 + 失败回退 + 测试）只替换 Generator 首页与结果页；复用现有 ViewModel/Service/Safety/History；不删旧导航、不动 Onboarding/Share Extension。关闭 flag 时行为必须与现状完全一致。
- 首发只做「出口气 + 帮我回」两条结果；「帮我理清」/Echoes 暂不进核心（真机 parse fallback < 15% 且定性通过后再并入）。
- 保留品牌个性（帮你骂 / 先骂爽，再说人话）与 ASO 关键词（怼人/吐槽/阴阳/回复/comeback/witty）。
- Paywall：实现前先写清门控规则（哪些免费预览、哪个动作触发 Pro、什么指标不能回退）；不要卡在 Vent→Sendable 转化这一步。
- 每一步都要可发布、可测试、可回退；测试必须保持绿。重大产品/架构决策按项目习惯同时咨询 Gemini 3.1 Pro + Codex 并综合。

【立即开始（按顺序）】
1. 开分支 redesign/loop-first（从 v1.1）。
2. Phase 0 文档对齐（最高优先，先做）：新建 docs/PROJECT_STATUS.md（唯一当前状态 / 下一里程碑 / 阻塞 / 负责人）；修正 README 与隐私政策 / App 元数据里"无网络 / 无数据收集"等与已上线云端 Worker + 云端同意矛盾的表述。
3. Phase 1A「loop-first」脚手架：加 redesigned_home_enabled 远程开关（restrict-only，默认关）；在 flag 之后实现——
   - 「现在」最小首页：大输入框 + 出口气/帮我回 二选一 + 主按钮（首次生成前不堆风格/强度/积分/样例/Pro 矩阵）；
   - 「单一推荐结果 + 两阶段」结果页：私密版（只给你看）→ 变成能发的话；复制 / 换语气（更冷静/更直接/更有梗）；
   - 全部复用现有生成/安全/历史栈，不新建数据库；补 outcome→mode/intensity 映射 + 单测；a11y / Dynamic Type / 深色模式 / 四语言文案。
4. 关 flag 回归全绿、开 flag 能跑通一次 Vent→Sendable 之后，停下来与 Jason 对齐，再决定是否进入 §5 的完整三 Tab 重构。

【并行（Jason 负责，不阻塞你写代码）】
5–8 名现有用户访谈验证「出气/回应/理清」三结果命题；Echoes 真机评测；当前首页关键漏斗基线。

不确定时先问，不要默认全量重写。先交付可回退的最小闭环，用真实行为决定后续范围。
```
