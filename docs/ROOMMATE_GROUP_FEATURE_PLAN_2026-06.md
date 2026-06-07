# 虚拟舍友群功能开发计划

**日期：** 2026-06-05  
**状态：** 已纳入重设计计划，待开发  
**技术基础：** 现有 Echoes / 替你出气  
**MVP 语言：** zh-Hans  
**建议版本：** Echoes vNext

## 1. 功能目标

用户输入一件让自己生气、委屈或无语的事，RoastMate 生成一段类似“发进大学舍友群以后，舍友们集体替你出气”的群聊视图。

这不是社交功能，也不是真人在回复。它是一段由 3 个合成角色共同生成、一次性阅读的情绪表达结果，最终仍然服务于 RoastMate 的核心闭环：

> 先有人替我把气说出来，再帮我整理成真正能发出去的话。

## 2. 为什么可行

现有代码已经拥有：

- `EchoesEngine`：一次调用生成结构化多消息结果；
- `EchoesPromptBuilder`：角色化 Prompt 和固定消息弧线；
- `EchoesParser`：标签解析；
- `EchoesPersonaCatalog`：合成人格目录；
- `EchoesView` / `EchoBubble`：逐条展示；
- `EchoTranscriptRecord`：SwiftData 持久化；
- `EchoBridgeStore`：跳转到可发送回复；
- 独立 Feral 云端同意、安全过滤、远程开关和遥测。

需要扩展的是角色数、消息结构、群聊视觉和测试，不需要创建第二套 AI 架构。

## 3. 用户流程

1. 用户进入“虚拟舍友群”。
2. 输入发生的事。
3. 选择“日常吐槽”或“火力全开”。
4. 点击“发到舍友群”。
5. 页面显示群名和合成角色声明。
6. 3 个角色按 350–550ms 间隔展示 8–10 条消息。
7. 最后一条消息提供“变成能发的话 →”。
8. 点击后携带原始情况和建议强度进入现有 Generator/新结果流。
9. 用户复制、编辑、分享或保存可发送版本。

## 4. 角色设计

### 护短室友

- 作用：立即确认用户的委屈，不质疑、不讲道理。
- 示例倾向：“等等，这也能怪到你头上？”
- 禁止：过度依赖语言、关系承诺、煽动报复。

### 毒舌室友

- 作用：指出对方行为的荒谬处，承担主要笑点和火力。
- 示例倾向：“他这甩锅速度，不去练铁饼可惜了。”
- 禁止：身份攻击、歧视词、威胁、真实姓名羞辱。

### 清醒室友

- 作用：接住前面的梗，在不突然变成心理咨询师的情况下收尾。
- 示例倾向：“骂完了，别替他背锅。把时间线发清楚。”
- 最后一条负责 Bridge。

角色显示名可以使用“护短室友 / 毒舌室友 / 清醒室友”。不要生成真实姓名，不要暗示这些角色认识用户。

## 5. 输出合同

### 5.1 消息数量

- 3 个角色；
- 8–10 条消息；
- 每个角色至少出现 2 次；
- 最后一条必须为 `.bridge`；
- 每条简中建议 ≤35 字，解析硬上限 80 字。

### 5.2 顺序

推荐使用以下标签：

```text
[VALIDATE/A]
[REACT/B]
[ESCALATE/A]
[ESCALATE/B]
[BANTER/C]
[BANTER/A]
[REFRAME/C]
[BRIDGE/C]
```

可选增加 1–2 条 `REACT` / `BANTER`，但不能删除 `VALIDATE`、`REFRAME`、`BRIDGE`。

如果希望最小化模型和迁移风险，也可以在第一版继续用现有 `validate / escalate / deescalate / bridge` 四种持久化角色，仅让多个 `escalate` 承担 react/banter。实现前应选择一种方案，不要让 Prompt 与 Parser 使用不同合同。

### 5.3 群聊感要求

- 相邻消息尽量由不同角色发出；
- 后一条要引用、接梗或补充前一条，而不是三个独立文案；
- 至少出现一次角色之间的短互动；
- 不让用户在 transcript 中发言；
- 不生成时间戳、已读状态、在线状态；
- 不说“我们永远陪你”“以后都来找我们”等依赖性语言。

## 6. UI 规格

### Setup

- 标题：`发到虚拟舍友群`
- 副标题：`3 个合成舍友会一起替你吐槽，最后帮你把话说清楚。`
- 输入框：`发生什么了？`
- Tone：日常吐槽 / 火力全开
- CTA：`发到舍友群 →`
- 固定说明：`角色由 AI 合成，不是真人，也不会看到你的内容。`

### Transcript

- Navigation title：`舍友群（3）`
- 顶部 Banner：`虚拟舍友群 · 合成角色 · 非真人`
- 每个角色使用稳定颜色和简单图形头像；
- 气泡左对齐，显示角色名；
- Reveal 总时长控制在 4–6 秒；
- 用户可跳过动画直接显示全部内容；
- Bridge 气泡使用明显按钮样式；
- 完成后仅提供：变成能发的话、换一组、保存、返回；
- “换一组”每次会话最多一次，沿用现有 anti-slot-machine 约束。

## 7. 技术改动

### 模型

- `EchoVoiceCount` 新增 `.three = 3`；
- 建议新增 `EchoScene`：`.classic` / `.roommateGroup`；
- `EchoTranscriptRecord` 增加可选 `sceneRaw`，nil 推导为 `.classic`；
- 不修改既有 raw value，不破坏旧 CloudKit 数据。

### Catalog

- `echoes-personas-zh-Hans.json` 增加第三角色；
- 为 roommate scene 定义固定三角色集合，不随机缺失关键角色；
- 现有 1–2 voice 随机选择行为保持不变。

### Prompt

- `EchoesPromptBuilder.systemPrompt` 根据 scene 分支；
- Roommate prompt 明确 3 人、8–10 条、角色职责、接梗要求和结尾合同；
- 保持单次生成，不做多次模型串联；
- 第一版保持 `maximumResponseTokens: 600`，真机不足时再依据评测调整，不能凭猜测增加。

### Parser

- 支持 index `C`；
- Parser 接收 expected scene/voice count；
- Classic：4–6 条，A/B 合同保持不变；
- Roommate：8–10 条，A/B/C，每个角色至少 2 条，Bridge 最后；
- 解析失败进入专用 curated roommate fallback；
- 不放宽旧模式的验证规则。

### Engine 与安全

- 复用 `SafetyFilter.validateInput`；
- 每条输出继续通过 `validateVentOutput`；
- Feral 继续使用 `EchoesFeralConsentGate`；
- 第一版不实现 Echoes cloud routing TODO；
- 新增独立 `roommateGroupEnabled` 远程开关，并与 `echoesEnabled` 做 AND；
- 远程配置必须只能收紧权限，不能绕过 consent。

### Persistence

- `voiceCountRaw = 3` 可直接保存；
- `sceneRaw` 使用可选字段实现增量迁移；
- History 能按原角色名和颜色重放群聊；
- 旧 Echoes 记录保持可读。

### Telemetry

只记录聚合计数：

- `roommate_group_started`；
- `roommate_group_completed`；
- `roommate_group_parse_fallback`；
- `roommate_group_bridge_tapped`；
- `roommate_group_regenerated`。

禁止记录输入、输出、角色生成文本或自由文本错误。

## 8. Fallback

至少准备 2 套按场景变量插值的简中静态 fallback。Fallback 仍需：

- 3 个角色；
- 8 条消息；
- 每个角色至少 2 条；
- 安全、短句、自然接话；
- 最后一条 Bridge；
- 清楚标记为合成角色。

Fallback 被使用时要正常向用户展示，同时单独记录 parse fallback，不能伪装成模型成功质量。

## 9. 测试要求

### 单元测试

- 解析合法 3-role / 8-message transcript；
- 支持 A/B/C，拒绝 D；
- 少于 8、多于 10 时拒绝；
- 每个角色少于 2 条时拒绝；
- 缺少 validate/reframe/bridge 时拒绝；
- bridge 非最后一条时拒绝；
- 任何一条触发 hard rail 时整段 fallback；
- classic 旧 Parser 测试继续通过；
- 旧 `EchoTranscriptRecord` 无 `sceneRaw` 时读取为 classic；
- remote flag 能关闭 roommate group，但不能绕过 Echoes 总开关。

### UI 测试

- Free 用户触发现有 Pro Paywall；
- Pro 用户进入舍友群、生成、逐条展示；
- 可跳过动画；
- Bridge 将原始 situation 和建议 intensity 传给 Generator；
- Feral 同意 allow/deny；
- 远程 kill 后入口消失；
- VoiceOver 顺序与 Dynamic Type；
- 简中长文本不截断关键 CTA。

### 真机评测

- 至少 20 个简中场景；
- parse fallback <15% 才能默认开启；
- 角色区分度人工评分 ≥4/5；
- 群聊连贯度人工评分 ≥4/5；
- 不能出现真实人类/在线群聊误导；
- 35% fallback 为硬 kill threshold。

## 10. 验收标准

1. 用户能在现有 Echoes 入口选择或进入“虚拟舍友群”。
2. 生成 3 个可区分角色的 8–10 条消息。
3. 消息之间有接话感，不是独立文案列表。
4. 最后一条能无损进入可发送回复流程。
5. 旧 Echoes、旧历史、云端同意和 Pro 权益没有回归。
6. 所有新增 Parser、RemoteConfig、Persistence、UI 路径有测试。
7. 本地构建和相关测试通过。

## 11. 暂不做

- 用户在群里继续回复；
- 角色长期记住用户；
- 自定义真人姓名或导入联系人；
- 真人头像、在线状态、已读回执；
- 4 人以上群聊；
- 多轮模型调用；
- 社区分享 Feed；
- v1 同时支持四语言；
- 新增第三方 SDK。

## 12. 建议开发顺序

1. 增加 scene/three-voice 类型和兼容测试；
2. 扩 Persona Catalog；
3. 实现 Roommate Prompt 合同；
4. 扩 Parser 与 curated fallback；
5. 接入 Engine、安全和 persistence；
6. 实现 Setup 与群聊 Transcript UI；
7. 接 Bridge、Paywall、consent 和 remote flag；
8. 增加遥测与 UI 测试；
9. 真机跑 20 个场景并记录 fallback；
10. 达标后再默认开启。

