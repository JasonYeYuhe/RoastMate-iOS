你接手 RoastMate（幫你罵 / 帮你骂 / RoastMate AI，`~/Documents/RoastMate`，分支 `feature/v1.4-track-b`，不要动 `main`）。

**先读，按这个顺序：**
1. `docs/HANDOFF_v1.8_NEXT_SESSION.md`：先读顶部的 "Update 2026-11-12"，再读 "Update 2026-11-08 (late)"（路径 D 保留什么）。
2. `docs/DEV_PLAN_v1.9_2026-11.md`：现在执行的计划，**D+**。重点读 §2、§6、§7、§9。
3. `docs/DEV_PLAN_v1.8_2026-11.md` §2.1 和 §2.3：讲 11-15 停止规则的后果和 01-31 读数，这两条照旧有效。
4. 项目 `CLAUDE.md` 和全局 `~/.claude/CLAUDE.md`。

文档里的说法先验证再用：关于代码的，打开文件看；关于线上的，实测。

## 现状（11-12 实测）

- **版本：** macOS 1.8.0 (28) 11-02 上架；iOS 1.8.0 (29) 11-05 上架。
- **商店：** 首次下载每周大约 1–2 次（10-05 起各周依次是 1、4、2、1、1）。1.8.0 上架以来（11-05 → 11-10），首次下载 1 次，新订阅 0。
- **付费：** 0 人。台湾那位当天就取消了（付费期到 10-20 结束）；美国那位 11-04 起扣款失败，苹果在重试。Billing Grace Period 11-08 已打开。
- **推广：** 一篇帖子都没发。路径 A 11-08 结束，之后是路径 D。11-15 的停止规则会走第一分支，也就是「停止功能开发」。
- **定时任务**（都已设好，不要改）：
  - `roastmate-weekly-readout`：每周一的只读读数，有变化才报。
  - `roastmate-openrouter-balance`：每周一查 OpenRouter 余额。
  - `roastmate-stop-rule-1115`：11-15 10:20 JST 把停止规则的结果原文写进 handoff，提交并推送。
  - `roastmate-final-read-0131`：2027-02-04 起做 v1.8 §2.3 的最终付费读数，会自己改期。

## Jason 11-12 的决定：走 D+

D+ = 维护模式 + 三件 $0 的商店页小事。**不写 App 代码，不出新版本，不部署 Worker，不投广告。**

Gemini 4 Argon 和 3.8 Flash 分别审了草稿。两位都反对付费广告（路径 E），也反对 1.8.1 加功能（选项 S），理由见计划 §9。这两个选项留在计划里，但没有被选。

## 下一步（按顺序）

1. **D+1 推广文案（promotionalText）：上架版本可以直接改，不用审核。**
   - 先读出线上现在的文案（`python3 scripts/asc_product_page.py status --version 1.8.0 --platform IOS`，再用 `--platform MAC_OS` 跑一次，两个平台各有一份）。
   - 四个语言各写一版新文案：zh-Hant、en-US、ja、zh-Hans，每版不超过 170 字符。要写进去的内容：
     - 「發洩」免费，用云端模型，第一次使用前要你同意；
     - 年订有 7 天免费试用；
     - 第一次成功发洩之后，免费预览一次「痛罵」；
     - 「改成能發的」只在有 Apple Intelligence 的设备上可用。
   - 每一条都要先核实：
     - 对照 1.8.0 的代码和字符串（`Shared/zh-Hant.lproj/Localizable.strings:36-38, 180` 等）；
     - 用 ASC API 读年订产品在台湾的 intro offer，确认 7 天试用确实存在；
     - 免费点数的说法对照 `StoreService` 和 quota 的代码。
   - 把四版草稿发给 Jason，等他确认原文（这是公开文字，每次都要等确认）。他确认后：
     - 写进 `metadata/<locale>/promotional_text.txt`；
     - 先不带 `--apply` 预演一次，看清改动，再运行 `python3 scripts/asc_product_page.py text --version 1.8.0 --live-promo --apply`，`--platform IOS` 和 `--platform MAC_OS` 各一次；
     - 读回线上内容，核对和确认的原文一致；
     - 提交并**马上推送**。
   - 回滚：git 里的旧文案重新 apply 一次。
2. **D+2 ASO 备用：**
   - 在 `metadata/*` 里准备关键词和副标题的修改，提交时注明 "ride the next binary"。
   - 只是备着，不提交审核：关键词和副标题只能跟新版本一起改。
   - 可以考虑：zh-Hant 副标题还有 15 个字符没用；关键词可以补 回嘴、毒舌、靠北，前提是不和名字重复。
   - 不要把中文关键词塞进 en-US。计划 §5 写了为什么不行。
3. **Worker 冒烟测试，只打一次：**
   - 对生产环境的 Worker 发一次 zh_TW 的 Vent 请求，确认返回的是真生成的内容，不是兜底的固定文案。
   - 先看 `cloud-worker/src` 弄清请求格式。
   - 只看这一次的返回，不读任何用户的日志。
4. **D+3 In-App Event（可选）：**
   - 问 Jason 一次要不要做年底尾牙、年终这类主题的台湾 In-App Event。
   - 他要做的话：起草文案，按苹果当前的尺寸要求做图，文案和图都给他确认，大约 12-05 前提交。
   - 他不要的话，就跳过。
5. **11-15 当天：**
   - 停止规则的记录由定时任务来写。为了不和它冲突：
     - 11-15 10:20 JST 之前，每次提交都马上推送；
     - 不要让 handoff 或 `docs/evidence/2026-10-27-v18-plan/brief-2026-11-15.md` 处在有未提交修改的状态。
   - 定时任务跑完以后，用 `git log` 确认记录已经推上去了。
     - 如果它报告某项检查没通过，把它给出的记录原文手动写进 handoff。
   - 1.8.1 默认不做。只有 Jason 看着这份记录，在对话里明确说要做某一项时才做，按计划 §4 修正后的范围执行。
6. **做完 D+ 就收尾：**
   - 按全局 CLAUDE.md 的 Wrap-up 清理。
   - 用中文向 Jason 报告：做了什么、线上读回来是什么、什么交给定时任务了。
   - 然后停下。不要为了找事做去开新功能。想到的点子写进计划，不做。

## 规则

**行动权限**
- 可逆的事直接做。
- 任何公开文字（推广文案、活动文案和图），以及以 Jason 名义发的帖子、邮件、消息，都要等他确认原文和发到哪里，每次都要。
- 不写 App 功能代码，不出新版本，不部署 Worker，不投广告。不建任何账户，不填任何支付信息。
- 改 ASC 设置或线上开关之前，先用一句话说清做什么、怎么回滚，再做。

**付费与安全**
- Debug 构建永远是 Pro。付费墙、试用、点数只在 Release 构建（`ENABLE_TESTABILITY=YES`）里验证。
- `cloud_sendable_enabled` 永远不开。
- 评测花费不超过 $2。
- 不读任何具体用户的 Worker 日志。
- 如果有威胁、自残内容或辱骂到达用户：当天在 `research/web/roastmate-config.json` 里设 `"ondevice_permissive_enabled": false`，然后再调查。

**ASC**
- App id 是 6769317103，永远不要从 `$ASC_APP_ID` 环境变量取。
- API 用 `scripts/asc_submit_review.py` 的 `mint_jwt(issuer, key_id, Path)` 和 `api()`，返回 `(status, json)` 元组。
- 报表脚本（`scripts/weekly_readout.py`、`scripts/payer_read.py`、`scripts/asc_analytics.py`）都从仓库根目录用 `python3 -B` 跑。输出放 scratchpad，原始 TSV 不进仓库。
- 订阅报表比 Sales 报表晚大约一天，查到 404 不等于那天没有事件。
- 如果被拒：先在 Resolution Center 回复，再重新提交。

**构建与机器**
- 这一阶段不需要构建。万一要构建，用 `/Applications/Xcode-27.1.app`（设 `DEVELOPER_DIR`），构建产物不放在 `~/Documents` 里。
- 不删、不擦任何模拟器。删东西用 `/usr/bin/trash`。
- `~/Documents` 下名字里带「 2」的文件是 iCloud 的重复副本，不要动。`git fetch` 如果报 `bad object refs/... 2`，先确认那个引用指向的提交已经在 HEAD 里，再把它移到废纸篓（11-08 处理过一次）。

## 还是 Jason 自己的事

- 确认推广文案的原文（四个语言）。
- 要不要做 In-App Event。要做的话，确认它的文案和图。
- 11-15 记录出来以后，1.8.1 默认不做；要做必须他明确说。
- OpenRouter 余额低于 $2 时手动充值，每周一的定时任务会提醒。
- 如果还没做：在 OpenRouter 账户里确认免费模型训练开关是关的（v1.8 计划里的老事项，先问他做过没有）。
