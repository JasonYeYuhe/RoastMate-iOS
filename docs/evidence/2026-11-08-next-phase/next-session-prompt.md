你接手 RoastMate（幫你罵 / 帮你骂 / RoastMate AI，`~/Documents/RoastMate`，分支 `feature/v1.4-track-b`，不要动 `main`）。

**先读，按这个顺序：**
1. `docs/HANDOFF_v1.8_NEXT_SESSION.md`：先读顶部的 "Update 2026-11-08"。
2. `docs/NEXT_PHASE_PLAN_2026-11.md`：现在执行的计划，路径 A。
3. `docs/DEV_PLAN_v1.8_2026-11.md`：读 §2.1、§2.3 和 §6，分别讲 11-15 的停止规则、01-31 的读数和护栏。
4. 项目 `CLAUDE.md` 和全局 `~/.claude/CLAUDE.md`。

文档里的说法先验证再用：关于代码的，打开文件看；关于线上的，实测。

## 现状（11-08 实测）

**版本**
- macOS 1.8.0 (28) 11-02 上架，tag `v1.8.0` → `cd1667d`。
- iOS 1.8.0 (29) 11-05 上架，tag `v1.8.0-ios29` → `f29e666`。

**商店数据**（约 10-01 → 11-05）
- 567 次曝光，46 次页面浏览，9 次首次下载，其中 7 次来自 App Store 搜索。
- 台湾：78 次曝光 → 20 次浏览 → 1 次下载。
- 已写评论 0，In-App Event 0，自定义产品页 0。

**付费**
- 现在付费的人是 0。台湾那位 10-19 主动退订；美国那位 11-04 起扣款失败、苹果在重试（billing retry），没有取消。
- Billing Grace Period 11-08 已打开：16 天，覆盖所有续订，生产和沙盒都开。
  - 回滚：`PATCH /v1/subscriptionGracePeriods/6769317103`，设 `optIn: false`。

**推广**
- 帖子 10-23 写好，一篇都还没发。
- 如果 11-15 前不到 3 篇帖子，v1.7 停止规则走第一分支（停功能开发），照原文记录。

## Jason 11-08 的决定

- **走路径 A：** 不做新功能，不出 1.8.1，不部署 Worker，只做外部推广。帖子由 Jason 发。
- **硬切换：** 11-22 前上线的帖子不到 3 篇，就改走路径 D，也就是维护模式。
- **模型：** 继续用付费 Qwen，不换 `:free`，也不重新打开训练开关。

## 下一步（按顺序）

1. **A1，马上做：** 把发帖材料定稿，赶 PTT [廣宣]（只能周一发：11-09 或 11-16）。
   - 逐条核对 `docs/distribution/2026-10-23-p21-posts.md` 里的说法，对照 1.8.0 的代码和文案。补上年订阅 7 天试用和一次免费痛罵预览。
   - 删掉 §4.5 那条过时的说明：图标从 1.7.2（`64c4867`）起已经是繁体。
   - 每个渠道配一个 campaign 链接（`ct=`）。`pt=` 找 Jason 要，或者等他同意后用 Chrome 去 ASC → App Analytics → Campaigns 看。
   - PTT 先查规则 5-A（只能用原始网址，不能用联盟链接）。拿不准就用不带参数的原始网址。
   - 每篇帖子都等 Jason 确认原文和发到哪里，由他自己发。你把每篇的链接和台湾时间记进 `~/Documents/RoastMate-research/creator-outreach-log.tsv`。第三篇帖子发出的日期就是 T。
2. **A5：** 建一个每周只读的报表定时任务。内容：首次下载、页面浏览、订阅开始、billing retry 状态。有变化才报。
3. **A3：** 11-14 刷新 `docs/evidence/2026-10-27-v18-plan/brief-2026-11-15.md`；11-15 把停止规则的结果一字不差记进 handoff。
4. **A4：** 第三篇帖子发出 7 天后，按 campaign 看漏斗。
   - 台湾页面浏览一周不到 25：帖子没把人带到商店。
   - 浏览涨了但下载还不到 5：问题在商店页。
5. **11-22 数帖子：** 3 篇或以上，继续路径 A；不到 3 篇，切到路径 D，并在 handoff 里写清楚 D 保留什么。
6. **读数：** 12-15 做第一次读数；01-31 做最终读数，用 v1.8 §2.3 原来的标准。

**可选：**
- A6：In-App Event。文案是公开内容，要 Jason 批准。
- A7：第二批创作者。3 篇帖子上线以后再做；每封邮件都等 Jason 确认，不联系第一批那 3 位。

## 规则

**行动权限**
- 可逆的事直接做。
- 任何以 Jason 名义发的帖子、邮件、消息，都要等他确认原文和发到哪里，每次都要。
- 路径 A 下不写功能代码，不部署 Worker，不提交审核（回应 App Review 除外）。想到新功能，写进计划的待议事项，不做。
- 改线上开关或 ASC 设置之前，先用一句话说清做什么、怎么回滚，再做。

**付费与安全**
- Debug 构建永远是 Pro。付费墙、试用、点数只在 Release 构建（`ENABLE_TESTABILITY=YES`）里验证。
- `cloud_sendable_enabled` 永远不开。
- 评测花费不超过 $2。
- 不读任何具体用户的 Worker 日志。

**ASC**
- App id 是 6769317103，永远不要从 `$ASC_APP_ID` 环境变量取。
- API 用 `scripts/asc_submit_review.py` 的 `mint_jwt(issuer, key_id, Path)` 和 `api()`，返回 `(status, json)` 元组。
- 报表脚本：`scripts/asc_analytics.py`、`docs/evidence/2026-10-27-v18-plan/harness/lens3/sales_fetch.py`、`docs/evidence/2026-10-27-v18-plan/release-1.8.0/sales_daily.py`。
  - 都从仓库根目录跑。输出放 scratchpad，原始 TSV 不进仓库。
  - 订阅报表比 Sales 报表晚大约一天，查到 404 不等于那天没有事件。
- 如果被拒：先在 Resolution Center 回复，再重新提交。重新提交以后回复入口会消失。

**构建与机器**
- 需要构建时用 `/Applications/Xcode-27.1.app`（设 `DEVELOPER_DIR`）。
- 不删、不擦任何模拟器。
- 构建产物不放在 `~/Documents` 里。
- 删东西用 `/usr/bin/trash`。

## 还是 Jason 自己的事

- 发帖：Threads 随时可以，PTT [廣宣] 只能周一。发完把每篇的链接和时间告诉 agent。
- 提供 `pt=` provider token，或者允许 agent 用 Chrome 去查。
- 如果做 In-App Event，批准它的文案。
- 第二批创作者的每一封邮件。
- OpenRouter 余额低于 $2 时手动充值，每周一的定时任务会提醒。
