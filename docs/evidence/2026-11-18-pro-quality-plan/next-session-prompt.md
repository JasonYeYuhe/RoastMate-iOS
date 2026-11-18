你接手 RoastMate（幫你罵 / 帮你骂 / RoastMate AI），仓库 `~/Documents/RoastMate`，分支 `feature/v1.4-track-b`，不要动 `main`。

## 先读，按这个顺序

1. `docs/HANDOFF_v1.8_NEXT_SESSION.md`：先读 "Update 2026-11-18 (late)"，再读 "Update 2026-11-18"、"Update 2026-11-15"。
2. `docs/DEV_PLAN_PRO_QUALITY_2026-11.md`：现在执行的计划，1.9.0。全文都读，重点是 §0、§2、§3、§4、§5、§7。§10 是 Gemini 3.8 Flash 审阅后的取舍。
3. 项目 `CLAUDE.md` 和全局 `~/.claude/CLAUDE.md`（构建目录、模拟器、签名、收尾规则）。
4. 跑基准要用的旧工具：
   - `docs/evidence/2026-11-18-macos2721-probe/README.md`：生产引擎怎么编译、怎么装进最小 `.app`；
   - `docs/evidence/2026-10-27-v18-plan/a4/README.md`、`a5/README.md`；
   - `docs/evidence/2026-10-27-v18-plan/harness/safety/judgetune/README.md`；
   - `docs/evidence/2026-11-08-next-phase/a1-rewrite-recheck/README.md`。

文档里的说法先验证再用：关于代码的，打开文件看；关于线上的，实测。

## Jason 11-18 的决定（AskUserQuestion）

- **推翻规则：** 11-15 停止规则已经触发（停止功能开发），v1.8 原定 12-05 冻结，这两条都有意推翻，开发 1.9.0。01-31 的付费读数（v1.8 §2.3）照旧，大概率还是 KILL。这一版只用质量门槛衡量，不看收入。
- **Q3 不做：** 不给没有 Apple Intelligence 的设备开云端通道。设置里「本機處理、我們永遠看不到」的承诺保持为真，隐私政策和 App Privacy 都不改。
- **Q2a 做：** Pro 的「痛罵」从 1 版变成 3 版。

## 现状（11-18 实测）

- **线上版本：** iOS 1.8.0 (29)、macOS 1.8.0 (28)。Worker 生产版本 `046f2134`，D+ 期间没有部署过。付费用户 0，新订阅 0，评论 0。OpenRouter 余额 $9.86。
- **本机系统：** macOS 27.2.1 (26B131)。11-18 重跑的探针结果和 27.2 一致：
  - 默认护栏几乎全拒；
  - 宽松重试 8/8；
  - 威胁判定逐条相同。
- **生产引擎当天的输出**（`engine.txt`）暴露了 Q1 要修的问题：en 高情商 Composed 回了 "Sleepwalking?" / "Recipe planning?" / "Emergency cleanup?" 三句，没有回应情境；ja 狠是一句抽象短句。
- **改写误判：** 11-08 实测，大约每 5 次正常改写有 1 次被威胁判定误拦（`a1-rewrite-recheck`）。
- **Xcode：**
  - iOS 用 `/Applications/Xcode.app`（27.2，27B52）可以上传：Soundpost 的 build 23、24 在 ASC 里是 VALID。
  - macOS 用 27B52 能不能上传还没验证。先试 27B52；导出被拒就用 `DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer`。
  - 27.1 不要删。
- **定时任务**（都已设好，不要改）：
  - `roastmate-weekly-readout`：每周一的维护读数；
  - `roastmate-openrouter-balance`：每周一查余额；
  - `roastmate-final-read-0131`：2027-02-04 起做最终付费读数。

## 按顺序做（细节和门槛都在计划 §2、§3）

1. **Q0 基准（11-19 → 11-20）**
   - 写 runner 和带单元测试的 `score.py`，评分公式照计划 §2 写死；
   - 写固定输入集；
   - 对照组：`git archive v1.8.0-ios29 Shared` 加 HEAD 上的 harness；
   - 云端用 preview Worker（`npx wrangler dev --remote`），约 18 次调用。
   - 产出 1.8.0 在 27.2.1 上的基线，放进 `docs/evidence/<日期>-pro-bench/`，提交。
2. **Q4 吵架模擬器（→ 11-22）：** 3 次运行都要 ≥ 29/36。
3. **Q1 本机三档质量（→ 11-27）**
   - 先做「答非所问」过滤和重试一次，再改写 Composed/Sharp 的提示词；
   - 不用 `@Generable`：宽松模式只支持字符串。
   - Q2b 同时在 preview Worker 上做。
4. **Q5 改写误判（→ 11-29）**
   - 先让 Gemini（agy，`mcp__gemini__ask_gemini`）把一份新的盲测集直接写进文件，在读之前先打分；
   - 威胁拦截率不能降：盲测集 ≥ 32/40，隐晦威胁 ≥ 20/28。
5. **Q2a 痛罵 3 版（→ 12-02）**
   - 先在 preview 上过门槛，再做唯一一次生产部署（Q2a 和 Q2b 一起），记下回滚 id；然后改客户端。
   - 免费通道和旧版本仍然是 1 版，B5 的预览也保持 1 版。
6. **截止 12-04：** 没过门槛的项目移出 1.9.0。按计划 §2 第二次失败就砍，不试第三次。
7. **发布检查（12-04 → 12-06）：** preflight，Release 版 UI 测试（`PaywallFlowUITests`；`DeviceHonestyUITests` 在 iOS 18.5 和 27 上跑），最终基准（对照组、候选、没见过的情境），StoreCopy 和多语言配对测试。
8. **12-07 提交 iOS 和 macOS**
   - 用 `scripts/build-upload-asc.sh`、`asc_bind_version.py`（iOS 一次，再加 `--platform MAC_OS` 一次）、审核备注、`asc_submit_review.py`；
   - 读回状态。
9. **上线后**
   - 打 tag `v1.9.0`；
   - 更新四个语言的推广文案（新版本不会继承旧文案）；
   - D+2 排队的关键词和副标题随 1.9.0 一起上，原文都要 Jason 先确认。

每一步提交后马上推送。

## 规则

**行动权限**
- 可逆的事直接做：代码、测试、本地构建、preview Worker、提交并推送到这个分支、对可编辑版本改 ASC 元数据（先预演）。
- 生产 Worker 部署、提交审核、改线上开关：先确认门槛已过，用一句话说清做什么、怎么回滚，再做。
- **任何公开文字都要等 Jason 确认原文**，每次都要：What's New（4 个语言）、推广文案、关键词、副标题。以 Jason 名义发帖、发邮件、发消息同样要确认。
- 不建账户，不填支付信息，不投广告，不加第三方 SDK，不加任何新的统计、计数或归因。

**付费与安全**
- Debug 构建永远是 Pro。付费墙、试用、点数、预览只在 Release 构建（`ENABLE_TESTABILITY=YES`）里验证。
- `cloud_sendable_enabled` 永远不开。
- 评测花费 ≤ $2；生产 Worker 部署最多 2 次，回滚另算。
- 不读任何具体用户的 Worker 日志。
- 改提示词或判定的项目，都要重跑安全集，结果不能比 11-18 差。
- 如果有威胁、自残内容或辱骂到达用户：当天在 `research/web/roastmate-config.json` 里设 `"ondevice_permissive_enabled": false`，然后再调查。
- 新字符串四个语言都要有，并通过配对测试（未配对的中文字符串已经出过三次事）。

**ASC**
- App id 是 6769317103，永远不要从 `$ASC_APP_ID` 取。
- API 用 `scripts/asc_submit_review.py` 的 `mint_jwt` 和 `api()`，返回 `(status, json)`。
- 被拒：先在 Resolution Center 回复，再重新提交。

**构建与机器**
- 构建产物放 `~/Library/Caches/RoastMate-build/` 或 scratchpad，绝不放在 `~/Documents`。
- 编译 `Shared/` 时排除 iCloud 重复文件 `* 2.swift`；`~/Documents` 下带「 2」的文件都不要动。
- 归档前先跑全局 CLAUDE.md 里的两条签名锁屏检查。
- 模拟器按 UDID 选，用 `/tmp/lock-*` 锁，不删、不擦。需要 iOS 18.5 设备时，先看有没有现成的；没有就 clone `Soundpost-iOS18`，用完把删除命令给 Jason。磁盘剩余 < 30 GB 时不要启动模拟器，告诉 Jason。

## 还是 Jason 自己的事

- 所有公开文字的原文：What's New、推广文案、关键词、副标题。
- 可选：一位台湾母语读者读一小时盲测稿。你准备材料，不替他联系任何人。
- 可选：TestFlight 版本在 iPhone 上看 10 分钟。

## 做完

- 1.9.0 两个平台都提交以后，按全局 CLAUDE.md 的 Wrap-up 收尾。
- 用中文向 Jason 报告：每个 Q 项的门槛结果（基线对比的具体数字）、砍掉了什么以及为什么、线上读回来的状态，还有哪些事在等他。
- 然后停下。想到的新点子写进计划，不做。
