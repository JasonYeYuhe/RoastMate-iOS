你接手 RoastMate（幫你罵 / 帮你骂 / RoastMate AI），仓库 `~/Documents/RoastMate`，分支 `feature/v1.4-track-b`，不要动 `main`。这是 1.9.0 的第二个执行会话，剩下的事只有三件：跑 Q1 的门槛，做发布检查，12-07 提交。

## 第 0 步：先看机器能不能用

11-19 的 Q1 门槛跑到一半作废了。原因是机器过载：负载约 580，swap 26.7 GB，可用磁盘 13 GB，都是别的会话造成的。

开始任何工作前，先跑下面三条：

```bash
sysctl -n vm.loadavg; sysctl vm.swapusage; df -h /
```

- 1 分钟负载要在 10 左右以下，swap 要回到正常水平（重启后通常 < 2 GB）。达不到就不要开始门槛，告诉 Jason 需要重启。
- 可用磁盘要 ≥ 30 GB。不够就不要启动模拟器，告诉 Jason：可能需要清空废纸篓（⌘⇧⌫），或者清理别的项目。
- 门槛跑的约 5～6 小时里，不要同时跑模拟器、UI 测试或别的构建。门槛里有延迟这一项，会被干扰。

## 先读，按这个顺序

1. `docs/HANDOFF_v1.8_NEXT_SESSION.md`：读 "Update 2026-11-19"，再读 "Update 2026-11-18 (late)"。
2. `docs/DEV_PLAN_PRO_QUALITY_2026-11.md`：顶部的 "Status 2026-11-19"，还有 §2、§4、§5、§7。
3. `docs/evidence/2026-11-18-pro-bench/README.md`，重点读这几段：
   - "How to run"；
   - "1.8.0 baseline"；
   - "Q1 — on-device sendable quality: development"；
   - "Q1 gate attempt 1 — criteria declared before the run"；
   - "Q1 gate attempt 1: void"，里面有重跑命令。
4. 项目 `CLAUDE.md` 和全局 `~/.claude/CLAUDE.md`：构建目录、模拟器、签名、收尾规则。

文档里的说法先验证再用：关于代码的，打开文件看；关于线上的，实测。

## 现状（11-19 实测）

- **线上 app：** iOS 1.8.0 (29)、macOS 1.8.0 (28)。远程开关没动过。
- **线上 Worker：** `eb7b671c-56a7-48a0-a22d-ffbcb43e43fc`，里面有 Q2b 和云端發洩/痛罵的安全修复。
  - 这个计划的 2 次生产部署都已用完，之后只能回滚或改开关。
  - 回滚命令：`npx wrangler rollback c1253b1c-6fec-4627-9f6c-fcc73f48c430`；回到 1.8.0 的 Worker 用 `046f2134-5424-4069-b6f3-28b053ccd594`。
- **Q0 基准：** 完成。1.8.0 的基线是答非所问 22.6%，扣住情境 53.1%（648 次本机调用）。
- **Q2b：** 通过，已上线。
- **已砍（按两次失败就砍的规则）：** Q2a、Q4、Q5。不要重跑，也不要「再改一下试试」。
  - Q4 每次都比 1.8.0 好，代码在 `ff55a76..7ec997e`。要不要推翻规则拿回来由 Jason 决定，你不提议也不做。
- **Q1：** 代码完成（`Shared/AI/AnswerScreen.swift` 加提示词改写），单元测试通过，**门槛还没用掉任何一次机会**。
  - 开发数据（100 次调用，对照 1.8.0 的同样 100 格）：答非所问 0%（对照 25.7%），扣住情境 100%（对照 63.2%）。
  - 风险一：延迟。dev 1 的中位数比对照多约 2.9 秒，但当时有模拟器在跑；dev 2 的补位和更窄的重试还没在正常负载下量过。门槛是不超过对照 + 2 秒。
  - 风险二：简体字。开发时出过一次「霉」（「霉味」）。Worker 的字表把它算作简体，门槛要求不多于同一次运行里的对照组，而 1.8.0 在基线里是 0。
- **评测花费：** $0.25 / $2。OpenRouter 余额 $9.61。

## 按顺序做

1. **Q1 门槛，第 1 次。**
   - 按 README "Q1 gate attempt 1: void" 段落里的命令，从当前 HEAD 构建候选，从 `v1.8.0-ios29` 构建对照，然后跑：
     ```bash
     gate_final.sh <cand.app> <control.app> q1g1 24
     ```
     放后台跑，约 5～6 小时。
   - 判定照 "criteria declared before the run" 那一段，一条都不改。固定集和没见过的集分开算。
   - `gate_final.sh` 会拒绝在已有 `runs/<tag>_*` 文件时启动：作废的行要先移到 `runs/void/`。
   - 只有机器问题（过载、配额、崩溃）才能判作废，而且要在 README 里写清楚原因。结果不好看不算作废。
2. **结果出来以后：**
   - **通过：** Q1 进 1.9.0。
   - **没过：** 可以针对失败的那一条改一次，在 12-04 前跑第 2 次（tag 用 `q1g2`）。第 2 次再没过就砍掉，代码改回 1.8.0 的样子，写进 README 和计划状态表。
   - **Q1 被砍时：** 1.9.0 只剩本机威胁和恐吓名单新增的几条规则。用 AskUserQuestion 问 Jason，要提交这样的 1.9.0 还是不提交。不要自己决定。
3. **发布检查**（计划 §4，12-04 → 12-06），需要可用磁盘 ≥ 30 GB：
   - `scripts/preflight.sh`（`RoastMate-UITests`，按 UDID）；
   - Release 构建（`ENABLE_TESTABILITY=YES`）的 `PaywallFlowUITests`；
   - `DeviceHonestyUITests`，在 iOS 18.5 和 27 上都跑。iOS 18.5 设备先看有没有现成的，没有就 像 11-01 那次一样 `xcrun simctl clone Soundpost-iOS18 RoastMate-iOS18`（handoff 第 644 行附近），用完关机，把删除命令给 Jason；
   - StoreCopy 和四语言配对测试；
   - 最终基准（如果 Q1 门槛跑完以后代码又改过）。
4. **公开文字：** 1.9.0 里有什么确定以后，再起草四个语言的 What's New、推广文案、关键词和副标题。
   - 每个字都要 Jason 确认，确认前不写进 ASC。
   - What's New 只写真的改了什么，不夸大。云端安全修复已经上线、不在 binary 里，不要写成 1.9.0 的新功能。
5. **12-07 提交 iOS 和 macOS**，按计划 §5：
   - `build-upload-asc.sh`；
   - `asc_bind_version.py`，iOS 一次，再加 `--platform MAC_OS` 一次；
   - 审核备注；
   - `asc_submit_review.py`；
   - 读回状态。
   - macOS 先试 Xcode 27B52，导出被拒就用 27.1（`DEVELOPER_DIR`）。
   - 归档前先跑两条签名锁屏检查。
   - 提交前，用一句话说清做什么、怎么回滚。
6. **上线后：**
   - 打 tag `v1.9.0`；
   - 四个语言的推广文案重新设置（新版本不会继承），关键词和副标题也一起上，都用 Jason 确认过的原文。

每次提交后马上推送。`git add` 只写明确的路径：11-19 用过一次宽泛的 add，把 iCloud 重复文件提交进去了。

## 规则（和上一份一样，加上 11-19 的教训）

**行动权限**
- 可逆的事直接做：代码、测试、本地构建、preview Worker、提交并推送到这个分支、对可编辑版本改 ASC 元数据（先预演）。
- 提交审核、改线上开关、回滚生产 Worker：先确认条件成立，用一句话说清做什么、怎么回滚，再做。**生产 Worker 不能再部署新代码。**
- **任何公开文字都要等 Jason 确认原文**，每次都要。以 Jason 名义发帖、发邮件、发消息同样要确认。
- 不建账户，不填支付信息，不投广告，不加第三方 SDK，不加任何新的统计、计数或归因。

**付费与安全**
- Debug 构建永远是 Pro。付费墙、试用、点数只在 Release 构建（`ENABLE_TESTABILITY=YES`）里验证。
- `cloud_sendable_enabled` 永远不开。
- 评测花费 ≤ $2（已用 $0.25）。
- 不读任何具体用户的 Worker 日志。
- 改提示词或判定，都要重跑安全集，结果不能比 11-18 差。
- 如果有威胁、自残内容或辱骂到达用户：本机路径当天在 `research/web/roastmate-config.json` 里设 `"ondevice_permissive_enabled": false`，然后再调查。云端路径用上面的回滚 id。
- 新字符串四个语言都要有，并通过配对测试。

**ASC**
- App id 是 6769317103，永远不要从 `$ASC_APP_ID` 取。
- API 用 `scripts/asc_submit_review.py` 的 `mint_jwt` 和 `api()`。
- 被拒：先在 Resolution Center 回复，再重新提交。

**构建与机器**
- 构建产物放 `~/Library/Caches/RoastMate-build/` 或 scratchpad，绝不放在 `~/Documents`。
- 编译 `Shared/` 时排除 iCloud 重复文件 `* 2.swift`。`~/Documents` 下带「 2」的文件都不要动，也不要提交。
- 模拟器按 UDID 选，用 `/tmp/lock-*` 锁，不删、不擦。磁盘剩余 < 30 GB 时不要启动模拟器。
- 停掉 UI 测试时一定要关掉它的模拟器，否则会留下约 160 个孤儿进程，把负载推到 900 左右。

## 还是 Jason 自己的事

- 所有公开文字的原文。
- Q1 被砍时，要不要提交只带安全规则的 1.9.0。
- 要不要推翻 Q4 的砍掉。
- 可选：TestFlight 版本在 iPhone 上看 10 分钟。

## 做完

- 1.9.0 提交以后（或者 Jason 决定不提交），按全局 CLAUDE.md 的 Wrap-up 收尾。
- 用中文向 Jason 报告：
  - Q1 门槛的每一条数字（固定集和没见过的集，对照 1.8.0）；
  - 1.9.0 最终包含什么；
  - 线上读回来的状态；
  - 还有哪些事在等他。
- 然后停下。想到的新点子写进计划，不做。
