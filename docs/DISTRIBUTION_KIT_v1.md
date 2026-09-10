# RoastMate — Phase 2 distribution kit

_Drafted 2026-09-10, the day v1.5.0 went into review. Every section was written
against the live code, the live ASC API and the live store, then put through an
adversarial editing pass. This is **materials**, not actions: nothing here has
been sent to anyone, and no offer codes have been minted._

**Phase 2 is a code moratorium.** Everything below is deliberately executable
without opening Xcode. Where a section wants a code change, it says so and
defers it.

---

## Read this first: five things the plan had wrong

Verified directly, 2026-09-10. Each of these changes what the outreach should say.

**1. "They'd download it, burn three credits, and hit a paywall" is wrong, and
the truth is worse.** A new user gets **10 seeded credits plus 2/day for 7
days** (`CreditCatalog.swift`) — credits were never the wall. The wall is a
*capability* lock: 狠 / 痛骂 / 发泄 are all `requiresPro`
(`Intensity.swift:38`), and tapping a locked intensity opens the paywall
**immediately, before any generation**. So a free arrival can never reach the
two modes the entire pitch is built on. Offer codes fix this for creators; they
do **not** fix it for a creator's audience.

**2. The app is live on the mainland China App Store.** `帮你骂`, released
2026-05-21 (iTunes lookup, CN storefront). `PHASE_5_STRATEGIC_2026-09.md` §8
treats the mainland SKU as out of scope. Those two cannot both be true, and
Xiaohongshu's audience is mainland-dominant — so this is now a decision, not a
background fact.

**3. The share card's growth CTA points Chinese users at a competitor.**
`sharecard.findus` reads 「App Store 搜索 RoastMate」. Searching *RoastMate* on
the CN store returns a **different app at #1**; ours is #2. Searching 帮你骂
returns ours at #1. The growth layer is currently DARK
(`share_card_enabled:false`), so no damage has been done — but **do not flip
that flag until the string is fixed**, which needs a binary.

**4. The research recruit form has collected exactly zero responses.**
`RESEARCH_ANSWERS`: 0 keys. `RESEARCH_CONTACTS`: 0 keys. Not because it is
broken — because the Settings tile linking to it was a dead link in every
shipped build until `05f305d`, which rides v1.5.0. **v1.5.0 is the first binary
where a user can volunteer at all.** Plan for zero backlog. The form also
claims 「我们在招募 20 位用户」, which is false at this size.

**5. A 7-day free trial already exists** on the yearly subscription (`FREE_TRIAL`
/ `ONE_WEEK`, all territories). So evaluation is not impossible today — it just
costs a stranger a card on file and a $19.99/yr auto-renew. That is a much
bigger ask than a free code, but the accurate claim is "evaluation is
expensive", not "evaluation is impossible".

---

## The claim to stop making

The differentiator most often reached for in this repo is *"a general assistant
would refuse to write this."* **Nothing has ever tested that.**
`evals/runs/2026-08-30-apple-fm-pcc-guardrail-veto.md` measures **Apple's
on-device ~3B model only** — never ChatGPT, DeepSeek or 豆包 — and its headline
100% refusal is under *default* guardrails, which Apple's own public
`permissiveContentTransformations` API drops to **0/64**. The report's real
verdict is a *quality* no-go, not a refusal one.

Said in public, "ChatGPT won't do this" is falsifiable by anyone in thirty
seconds. The defensible version is the quality gap that eval actually measured:
**~0.1–0.5 strong words per draft on-device vs 4.4–6.1 for the cloud path in
Chinese.** An evening with four chat apps would settle the rest — and until
someone does that evening, the claim should not leave the building.

---

## Decisions only Jason can make

Collected from every section. The first three block the others.

- **[positioning]** Does the differentiator stay behind the paywall? Right now 狠/痛骂/发泄 are all Pro-only and no free arrival ever sees one. The obvious move is to make 发泄 free (Pro keeps 痛骂, all 16 Pro styles, parallel generation, the argument simulator, unlimited history) — but this is NOT a flag flip: it needs a free-vent counter, and it breaks the Phase-2 Xcode moratorium in docs/DEV_PLAN_v1.6_2026-09.md. It is a strategy call, not a bug fix. Jason decides.
- **[positioning]** Which half of the promise leads outreach: the vent (personality, memeable, gets attention, harder to explain to a stranger) or the rewrite (utility, sensible, indistinguishable from every AI writing tool). The store copy currently leads with both. A DM can only lead with one.
- **[positioning]** Does the privacy claim stay in the top three selling points? It is true for 体面/锐利/狠 and false-in-spirit for 发泄/痛骂, which route to a third-party provider. Leading with privacy invites a fair accusation of overclaiming on exactly the mode being demoed.
- **[positioning]** Name ChatGPT in outreach, or never mention it? Naming it makes the wedge instantly legible and also plants the comparison in someone's head who wasn't making it. No data either way — a judgment call.
- **[positioning]** The zh-Hans copy and style catalog are written in mainland internet register (小红书吐槽, 京片儿, 豆瓣短文) while the stated ICP is explicitly non-mainland (HK/TW/SG/diaspora). Confirm which audience the zh-Hans storefront copy is actually written for before any DM script gets written against it.
- **[creator-access]** Attach the offer to Monthly (6769322501) or Yearly (6769324200). Recommended: Monthly, so a forgotten cancellation costs $2.99 rather than $19.99 — but it means the creator's post-offer price anchor is the monthly tier.
- **[creator-access]** Free duration: 3 months recommended. 1 month risks expiring before a busy creator opens it; 6 or 12 months delays and enlarges the eventual auto-renew surprise.
- **[creator-access]** How many codes to mint. Recommended 25 against a 5–10 creator target; over-minting is free but the batch expiry date then governs 25 live free-Pro codes.
- **[creator-access]** Whether to send codes before or after v1.5.0 clears review. Creating them has no dependency; sending them does — a Pro creator mostly bypasses the v1.5.0 defects, so this is a judgment call about how much of the free-tier experience you want them to accidentally see.
- **[creator-access]** Whether to approach mainland-China-storefront creators at all. The app IS live in CHN (verified, released 2026-05-21) which contradicts the 'no mainland SKU' posture in PHASE_5_STRATEGIC §8 — and the cloud vent path's reachability from a mainland network is untested.
- **[creator-access]** Whether to also fix the free tier (which of 狠 / 痛骂 / 发泄, if any, becomes free) — this is what a creator's audience hits, and it is explicitly NOT solved by offer codes. Recommend deferring until at least one creator has reacted.
- **[creator-access]** Code batch expiration date — pick one you will remember, since unredeemed free-Pro codes otherwise stay live indefinitely.
- **[dm-script]** Mint the subscription offer codes BEFORE sending any message — this is a hard gate, not a nice-to-have. Verified in Intensity.swift:38 that savage/feral/vent are all requiresPro, and CreditCatalog.swift:9 that credits never unlock capability, so an uncoded creator physically cannot reach the vent-then-rewrite mechanic your store copy leads with. Two sub-decisions: (a) set offer-code eligibility to INCLUDE new subscribers — if it is scoped to existing/lapsed only, a creator who never subscribed cannot redeem, and you will not find out until they tell you it failed; (b) batch size — mint ~15 one-time codes for a run of 10, so you have spares for redemption errors.
- **[dm-script]** Settle the mainland 版号/ICP question before any volume. docs/marketing/xiaohongshu-launch-zh.md flags that the app IS live in the CN store but that a high-visibility mainland push on an unlicensed AI listing can get it pulled, and calls this 'the strategic/legal call is yours.' It is still open. Three options: run DM-only at low volume and never chase a viral note; target zh-Hant/日本/海外华人 creators instead (archetype E is the natural route); or resolve the licensing question first. This is the largest downside risk in the whole kit and it is not a question I can answer for you.
- **[dm-script]** Whether to accept a public post at all. My recommendation is the no-ask posture in §2 — it removes the 私单 exposure, removes disclosure obligations, and makes the DM more credible. But it also means you are giving away a year of Pro for feedback rather than reach. If you decide you want posts, the kit changes: disclosure and labeling obligations kick in, and the 蒲公英 question in do-not-do #4 becomes live.
- **[dm-script]** How to handle the auto-renew tail. An offer code converts to a paying ¥138/year subscription unless the creator cancels. §4 handles it by telling them plainly. The alternative is a longer offer term or eating the awkwardness later. There is no clean Apple mechanism for a permanent free grant, so 'be explicit upfront' is the honest option — but confirm you are comfortable with a creator possibly being charged in twelve months.
- **[dm-script]** Which account you DM from. docs/marketing/xiaohongshu-launch-zh.md assumes your own personal account, in first-person founder voice. If that account is cold or near-empty, warming it up is a prerequisite (do-not-do #3), and that is an evening of work on its own — decide whether to spend it before or after minting codes.
- **[dm-script]** Which archetype to run first. I recommend A (高情商话术) because RoastMate manufactures their exact content format rather than merely being relevant to their topic, with a first run split 3×A, 3×B, 2×D, 2×E and archetype C held back. If your instinct says otherwise, the archetype definitions and search criteria transfer unchanged.
- **[xiaohongshu]** Mainland posture. The app IS live on the CN App Store as 「帮你骂」 (verified via the iTunes lookup API), but docs/PHASE_5_STRATEGIC_2026-09.md §8 puts the mainland SKU firmly out of scope. Xiaohongshu's audience is mainland-dominant. Jason has to decide whether he actually wants mainland users arriving — including whatever obligations that carries, and the unknown reachability of the Cloudflare Worker from mainland networks — or whether he is deliberately fishing only for the overseas-Chinese / HK / TW slice of the platform. Everything else in this section assumes the former.
- **[xiaohongshu]** The findus string fix vs. the code moratorium. `sharecard.findus` tells Chinese users to search "RoastMate", and that search returns a DIFFERENT app at #1 on the CN store. Fixing it is two lines in two .strings files, but v1.5.0 is in review and the v1.6 plan says stop writing code. Options: (a) ship it as v1.5.1 and accept one more binary; (b) leave the string wrong and keep `share_card_enabled` dark so the badge never renders; (c) leave it wrong and flip the badge on anyway. My recommendation is (b) until there is another binary for an unrelated reason — Jason's own posts don't use the card, so this does not block the channel.
- **[xiaohongshu]** Whether to flip `share_card_enabled: true` now. The growth badge already shipped in v1.4.0, so this is a remote config flip with no review cycle — but it turns on a QR plus a CTA pointing at the wrong app name. Coupled to the decision above.
- **[xiaohongshu]** Whether to add a `portrait34` (1080x1440) export to ShareCardFormat. The code comment claims 4:5 is 'tuned for 小红书'; 3:4 is what the platform actually recommends for cover CTR. This is another binary change, so it is a moratorium decision, not a design one. Jason can author his own post covers at 3:4 with no code change at all.
- **[xiaohongshu]** Account identity: post openly as 独立开发者 (my recommendation), or stay a neutral content account that never mentions who made the app. The neutral version performs slightly better per post but edges toward 虚假种草 if he ever names the app while posing as a user. Also: personal account now, or 专业号 from the start — I could not verify whether an openly commercial personal account is expected to convert.
- **[xiaohongshu]** The commitment size. This only works as a channel if he commits to ~18 posts over 6 weeks before judging it. He should decide that now, in writing, with the stated kill criterion — because the documented failure mode in this repo is four consecutive waves of abandoning distribution for Xcode, and two posts followed by a shrug would be the fifth.
- **[xiaohongshu]** Which concept ships first. I would publish Concept C (国庆回家被催婚) first because National Day is roughly three weeks out and it is the largest 催婚 window before Spring Festival — the timing is worth more than the concept's ranking on merit.
- **[interviews]** Users vs. problem-havers. I recommend recruiting people who have the PROBLEM, not people who have the app — with ~0 real users, the alternative is four conversations with nobody. This changes what P2.4 means in DEV_PLAN_v1.6 and Jason owns that reframe.
- **[interviews]** Compensation. The live form promises 1 year of Pro via an Apple subscription offer code. I could not confirm any codes have been minted. Either mint 4 tonight, or cut the promise from research.js. Separately: whether to offer anything at all to a friend-of-friend introduction (I recommend nothing up front, a thank-you red packet after).
- **[interviews]** The form says 我们在招募 20 位用户 in all four locales. That is false at this size. Change it to 3–4 or leave it — a research/web/*.js edit, mirrored by the Action, no binary, no moratorium violation.
- **[interviews]** When the 30/90 clock starts. I propose the day v1.5.0 goes READY_FOR_SALE, not today, since v1.5.0 is the first build where the recruit tile works at all.
- **[interviews]** Whether to accept friend-of-friend introductions at all, given the bias, or hold out for strangers from Channel B. I recommend taking the intros — four biased conversations beat zero clean ones — but the bias must be noted in each file's 渠道 field.
- **[interviews]** Where notes live. The repo is PUBLIC. I recommend raw notes in ~/Documents/RoastMate-research/ (mode 700, uncommitted) and only a scrubbed P01–P04 synthesis in docs/. Jason should confirm before the first call, not after.
- **[interviews]** What 'kill' means to him concretely: freeze the time investment, narrow the pitch, or pull the App Store listing. The three are very different and the gate needs him to pre-commit to which one Day 90 triggers.
- **[interviews]** Whether to run the protocol's Arm C (10–15 non-user interviews) at all. I cut it as the 20-person fantasy in a different coat. If he disagrees, it should be a separate decision with its own time budget, not folded into P2.4.

---

# 1. Positioning

## What this app is for

### The one-sentence pitch

**zh-Hans**
> 气头上,一个字都打不出来。「帮你骂」先替你骂一句只给自己看的狠话,再把它改成能发出去的那句。

**English**
> RoastMate is for the ten minutes when you're too angry to type. It says the thing you actually want to say — swearing included, for your eyes only — then rewrites it into the version you can send.

This sharpens the line already on the store page (`先骂爽,再说人话` / "Vent first. Then send the version that actually wins") rather than replacing it. The store line is good but assumes the reader already understands the situation. The pitch above names the moment first, because to a stranger the moment is the only part that sells.

---

### What they type in, and what they get back

**In:** one line about what happened. No prompt, no chat. The shipped scenario catalog (`Shared/Resources/Scenarios.json`) is ten examples of exactly that input shape: 「室友的碗能放好几天,还说我『太计较』。」 / 「我做的项目,领导在全组面前说成是他的功劳。」 Then two taps: an intensity chip (体面 / 锐利 / 狠 / 痛骂 / 发泄) and a style chip (阴阳怪气, 文言文, 京片儿, 职场冷暴力 — 24 in `StylePresets.json`).

**Out:** sendable modes return three variants; 发泄 and 痛骂 return exactly one (`RoastEngine.swift:146` — private drafts are hard-capped at a single variant). Each is under 120 words, in your language and register. A vent draft comes back labelled for-your-eyes-only with a 「改成能发的」 button underneath. Not a conversation. Not a chat log to scroll back through.

**Be accurate about the safety layer, because the temptation is to over-promise it.** The Worker's system prompt forbids the model from echoing names, companies, addresses and contact handles, and `SafetyFilter` blocks slurs, threats and self-harm content on both input and output. But name-stripping is *not* enforced by rule on the generation path — the on-device `Redactor` only runs when composing a share card, and that surface is currently dark (`share_card_enabled: false`). The repo's own measurement against the live Worker (`Shared/Services/Redactor.swift:26-31`, 2026-09-03) found the model still echoed a full name in 2 of 3 generations. So the honest claim is *"no account, no analytics SDK, no advertising ID, and a filter that blocks slurs and threats"* — not *"your ex's name can never come back out."* Do not write the second one anywhere.

---

### Three moments of need

**1 — 23:40, the kitchen.** The dishes have been there three days. You said something; the roommate said 「你太计较了」. You have now typed and deleted a reply four times, because every version is either soft enough that you lose or sharp enough that you still have to live with this person in the morning. What you need at 23:40 is not a reply — it's to get the sentence out of your body so you can sleep. That is 发泄. 「改成能发的」 is the second half: a two-line 阴阳怪气 message short enough to send without turning a sink into a housing problem.

**2 — Friday 18:10, on the train home.** The boss just dropped a 「紧急」 task due Monday. You have four stops and a phone. You share the message into RoastMate, tap 锐利 + 高 EQ, and get three versions before your stop. What you needed here wasn't creativity — it was forty seconds and no blank text box. *Two honest caveats: a general assistant is at full parity here, and on a device without Apple Intelligence this tier returns a stock line rather than anything about your boss. See below.*

**3 — 02:00, someone screenshotted your DM into the group chat.** This is the scene where the correct action is to send nothing at all. The entire value is the draft you don't send: somewhere to put the rage that isn't the group chat and isn't a friend you'll have to explain yourself to tomorrow. RoastMate is the only place in this scene where "just get it out, unfiltered" is a designed feature rather than a mistake.

---

### "ChatGPT already does this"

Take it seriously, because for part of the app it is simply true, and the target market (HK / TW / SG / diaspora) has unrestricted access to every chat assistant there is. The "it's blocked where my users live" defence does not apply. Three claims, tested against the code:

**Claim A — "it's more private." Weak exactly where it matters.** 体面 / 锐利 / 狠 stay on the device. 发泄 / 痛骂 — the two modes that *are* the product — route through the developer's Cloudflare proxy to a third-party LLM. The privacy story is strongest where the app is least differentiated and weakest where it's most differentiated. Do not lead with it. What survives, because it is verifiable and genuinely unusual: no account required, no analytics SDK, no advertising ID, no fingerprinting. That's a tiebreaker, not a wedge.

**Claim B — "it's a different register." Strongest, and it's in the code.** The vent prompt (`cloud-worker/src/index.js`, the `ventRules` / `feralRules` / `localeReinforcement` block) is written as a negative specification against exactly what a general assistant does by default. It names a count and a vocabulary — 「必须使用 1-2 个强烈词(不许零粗口)」, 「零粗口 = 没完成任务」. It forbids the openings 「哎呀」「真是的」「唉」 by name. It forbids advice, consolation, moral lessons, therapist voice and 「你值得更好的」. It splits the wordlist Hans vs Hant so 简体字 doesn't bleed into 繁體 output, and tells the model to drop 大陆专属词 for zh-Hant (朋友圈 → 限動/貼文). The code comment records why: models comply with *permission* to swear and then don't swear, unless you name a number and a list in the target script. That's real craft. It is also a prompt, and a prompt is copyable in an afternoon by anyone who reads enough outputs. Head start, not moat.

**Claim C — "you don't have to ask." This is the real one.** With a chat assistant you negotiate: you phrase the request so it doesn't get softened, you sit through 「我理解你现在很生气」, you ask a second time for something harsher — and you do all of that *while furious*. In RoastMate the register is a chip you tap. The permission is built into the product and paid for by the developer, not extracted by the user in the worst ten minutes of their week. It's a UX claim, not a capability claim, which is precisely why it survives the models getting better.

**Verdict: answerable only on C, and only for the vent half.** For 体面 and 锐利, concede the tier. Don't argue it.

---

### The fact that makes this page moot right now

狠, 痛骂 and 发泄 are all Pro-only (`Intensity.requiresPro`, enforced at `RoastGeneratorViewModel.swift:98`; credits are a quantity knob and by design "NEVER unlock a capability"). Tapping 发泄 fires the paywall on the *chip tap* — `RoastGeneratorView.swift:342-344` — before the text box has even been read.

That is the smaller half of the problem. The larger half:

**On most hardware, the free tier isn't AI.** `AppleFMBackend` is `@available(iOS 26.0, macOS 26.0, *)`. The app deploys to iOS 18 and macOS 14. `cloud_sendable_enabled` is `false` in the live config, so there is no cloud path for the sendable tiers either. Below iOS 26 — or on iOS 26 hardware without Apple Intelligence — 体面 and 锐利 fall through to `FallbackRoasts`: **five hardcoded strings per language**, picked at random, with the `style` parameter accepted and then never read. Pick any of the 24 styles, type anything you like, and you get one of:

> 你这份坚持,真的是不分时间地点。建议你拿来干点别的。
> 我没生气,只是开始重新评估我们之间能聊的范围。

In the build live today (v1.4.0) nothing labels these, and the credit is spent before the engine runs. v1.5.0 — in App Review right now — adds the label (`"roast.notice.curated" = "预设示例 —— 并非根据你输入的内容生成,不扣额度。"`) and stops charging for them. Good fix. It does not change what the free arrival *sees*.

So: 23 lifetime downloads, zero purchases. **Nobody has ever used the thing that makes this app different, and a large share of arrivals never saw a language model at all.** The 197 people who read the product page were promised 「先骂爽」. Some meaningful fraction of the 23 who installed got a fortune cookie.

**What this changes operationally, today:** Jason cannot record a demo of the free tier on a non-Apple-Intelligence Mac or phone and have it be honest. Every screenshot, GIF and outreach clip has to come from 发泄 or 痛骂 on a device that reaches the cloud path — which means every asset shows a locked mode. That is a real constraint on the distribution kit, and it is better to know it before filming than after.

---

### The single sharpest differentiator

**zh-Hans**
> **它用中文替你骂人,不用你先说服它。**

**English**
> **It will swear at your roommate in Chinese without you having to talk it into it first.**

Everything else on this page — the two-step draft, the 24 registers, the on-device tiers, the no-account posture — is support for that one sentence. Any outreach line, screenshot or store update that doesn't make a stranger feel it in under three seconds is the wrong line.

---

### The one thing to do with this page this week

The funnel's biggest leak is **4,919 impressions → 197 page views (4%)**. At that stage a stranger sees three things: icon, name, subtitle. The current subtitle is 「本地 AI 帮你说出心里话」 / "On-device AI comeback writer" — it leads with the privacy tiebreaker this page just argued against leading with, and 说出心里话 could describe a journalling app.

An evening's work, in order of what's actually possible right now:

1. **Promotional text — change it tonight.** It's the one metadata field that updates without a review cycle, so it doesn't touch the v1.5.0 submission in flight. Current: 「先骂爽,再发能赢的那版。多数模式本地运行;发泄/痛骂走可在设置关闭的云端。」 — half of it is a privacy disclosure. Try instead:
   > 气到打不出字的时候,先替你骂一句只给自己看的,再改成能发出去的那句。
2. **Subtitle — write it now, ship it with the version after v1.5.0.** Subtitle is version-bound, so editing it mid-review is not worth the risk. Draft: 「先骂爽,再发能赢的那版」 (zh-Hans) / "Vent first. Send the version that wins" (en-US). Check the 30-character limit per locale before committing.
3. **Don't rewrite the long description yet.** It's accurate and it isn't what the 4,722 people who bounced ever read.

I have no evidence about what any of this does to the conversion rate, and neither does anyone else at 23 downloads — the sample is far too small to read a result from. The argument for doing it is that it costs one evening, zero dollars, and replaces a subtitle that describes the wrong half of the product.

> **What this section could not verify.** ["No head-to-head against ChatGPT exists anywhere in this repo. evals/runs/ compares LLM providers against each other (e.g. the 2026-05-23 OpenRouter sweep), never this app against a general chat assistant. Every claim on this page about what ChatGPT does or refuses is my judgment, not a measurement. If the 'ChatGPT already does this' objection is going to be the centre of the pitch, it deserves one evening of actually running the same five situations through both and saving the transcripts.", "Zero user interviews have happened — P2.4 in the v1.6 plan is unstarted. The three 'moments of need' are inferred from Scenarios.json, the store descriptions and the prompt design. They are plausible; none of them came from a person who used the app.", "I did not run the app or generate anything today. Claims about output quality come from reading the Worker prompt and the eval notes, not from fresh output. In particular I did not confirm on a device that a Pro user actually gets the harsh zh-Hans register that the prompt demands.", "I did not check App Store territory availability, so I cannot say which storefronts the zh-Hans localization actually serves, or whether the 23 downloads skew to any locale. App Analytics was not queried in this session — the 4,919/197/23 figures are taken from docs/DEV_PLAN_v1.6_2026-09.md §0 as given.", "I did not verify whether the live remote config currently has vent_cloud_enabled true, so the claim that 发泄 returns real model output today rests on the plan doc's statement rather than a fetch of the served JSON."]

---

# 2. Creator access

## Creator access — the concrete mechanism

**This is a chore, not a blocker. Budget 20 minutes, and do not let it become the thing you do instead of sending messages.**

Four waves of this project have retreated into a controllable task because outreach is not controllable. App Store Connect is controllable. It would be entirely in character to spend an evening perfecting a code batch, feel productive, and send nothing — so the honest framing is: **creator outreach does not wait on this.** A creator you contact today will not redeem anything until they reply, and most will not reply. Write the codes when you have twenty minutes; send the first messages whether or not the codes exist yet.

What the codes *do* fix is real, and worth the twenty minutes: right now there is nothing you can hand a creator that shows them the product the store listing describes.

---

### 1. What a creator gets today

The plan's shorthand — *"they'd download it, burn three credits, and hit a paywall"* — is wrong, and wrong in the direction that makes it worse. Verified in code:

| what | reality | source |
|---|---|---|
| free generations | **10 seeded credits + 2/day for the first 7 days** — not 3 | `Shared/Services/CreditCatalog.swift` (`seededTrialCredits`, `starterWindowDays`, `starterWindowDailyTrickle`) |
| free intensities | **2 of 5**: 体面 (Calm), 锐利 (Sharp) | `Shared/Models/Intensity.swift` (`requiresPro`) |
| locked intensities | **狠 / 痛骂 / 发泄 — all three `requiresPro`** | same |
| free styles | **8 of 24** (16 are `tier: pro`) | `Shared/Resources/StylePresets.json` |
| what happens on tap | tapping a locked chip opens the paywall **immediately**, before any generation | `RoastMate/Sources/Features/RoastGenerator/RoastGeneratorView.swift:342` |

So the wall is **not** the credit wall. Credits are a quantity knob and by design *never* unlock a capability (`CreditCatalog.swift` header comment). The wall is a capability lock and it fires on tap #1, before a single credit is spent.

Read that against the zh-Hans listing, which opens **「先骂爽,再说人话。」** and leads on 发泄 and 痛骂. The two tones the pitch is built on are behind the paywall, and on any device without Apple Intelligence the two free tones return curated canned text.

**One correction to the obvious conclusion.** There *is* already a way for a creator to reach 发泄 with no action from you: the yearly subscription carries a live 7-day free trial (`FREE_TRIAL`, `ONE_WEEK`, active since 2026-05-14, all territories — read from the ASC API today). It is not a substitute for codes, because it asks a stranger to enter a payment method and accept a $19.99/yr auto-renew in order to evaluate your app, which is a far bigger ask than a free code. But it means the accurate statement is *"evaluation costs the creator a card and a commitment,"* not *"evaluation is impossible."* Don't overclaim this; the overclaim is unnecessary and one check disproves it.

---

### 2. Do this tonight, in this order

**Step 0 — mint the codes and redeem one yourself.** On a second Apple Account, redeem one of your own codes end to end on a real device. This is the step that matters most, because it resolves all three of the open questions in §6 in about ten minutes, and because you have never watched a redemption. Everything you say to a creator afterwards is something you have seen rather than something you assume.

**Step 1 — send three, not ten.** P2.3 targets 5–10 creators. Send the first three, and read what comes back before sending the rest. The first three will teach you that a sentence is confusing or that the code flow has a step you forgot; you want to learn that on three messages, not on ten.

**Step 2 — one follow-up, maximum, and only if they redeemed.** Silence is the normal outcome and is not a signal about the product. Do not chase.

**Sequencing against v1.5.0:** create the codes now — they are generated against the already-live app and have no dependency on review. Send them once v1.5.0 is live, so a creator's first minute is on the build where the charge-for-canned-output defect is fixed.

---

### 3. Which mechanism, and why not the others

> Settle this once: the auto-memory note *"offer codes don't work for consumable IAPs"* is true and irrelevant here. Pro is an **auto-renewable subscription** — `RoastMate Pro Monthly` (`6769322501`, `ONE_MONTH`) and `RoastMate Pro Yearly` (`6769324200`, `ONE_YEAR`), both `APPROVED`, group `RoastMate Pro` (`22088713`). Offer codes are the supported mechanism for subscriptions. The consumable credit packs are the exception and stay ungiftable — there is no supported way to hand someone credits.

| | (a) Offer codes | (b) TestFlight external group | (c) The existing 7-day trial |
|---|---|---|---|
| Setup | ~20 min in ASC | build, upload, Beta App Review, group, invites | none — already live |
| What they install | **the real App Store build** | a beta that expires in 90 days | the real build |
| Can their audience install what they saw? | **yes, same link** | no — TestFlight only, and it caps | yes |
| StoreKit environment | **Production** | Sandbox | Production |
| Cloud vent lane | **Pro lane, 200/day** | free lane, 30/day — the production Worker rejects sandbox receipts (`wrangler.toml:47`, `src/verifier.js:46`) and the client silently falls back rather than erroring (`CloudVentClient.swift`) | free lane |
| Costs the creator | nothing | nothing | **a card on file + a $19.99/yr auto-renew** |
| Verdict | **recommended** | wrong tool | fine if they find it themselves; a bad thing to ask a stranger for |

On (b), one sentence is enough: TestFlight makes the creator's post unusable as a growth loop, because whatever they show links to a beta their viewers cannot install. There are currently **zero TestFlight groups of any kind** on this app. Leave it that way.

---

### 4. Exact ASC parameters

**App Store Connect → RoastMate → Subscriptions → `RoastMate Pro Monthly` → Offer Codes → Create.**

| parameter | value | why |
|---|---|---|
| Reference name | `creator-seed-2026Q4` | internal only |
| Distribution | **One-time use codes** (CSV) | one creator, one code. A custom code is a single string anyone can repost, and free Pro loose on Xiaohongshu is not recoverable |
| Number of codes | **25** | covers re-sends, typos, a second wave, and your own test redemption. Over-minting costs nothing |
| Offer type | **Free** | no per-territory prices to set |
| Duration | **3 months** | 1 month expires before a busy person opens it; 1 year makes the eventual renewal a bigger sting |
| Eligibility | **new, existing, and expired** | you cannot know their history, and a mis-set eligibility fails at redemption with no useful error |
| Territories | **all 175** (CHN, TWN, HKG, MAC, SGP, JPN, USA all confirmed available today) | a free offer has no prices, so "all" removes a class of failure at no cost |
| Code expiration | a date ~6 months out | unredeemed codes should not sit live forever |
| Attach to | **Monthly**, not Yearly | it renews at $2.99/mo, not $19.99/yr. If they forget to cancel that is a small apology, not a refund request |

**No code ships for this.** The entitlement comes from `Transaction.currentEntitlements` matched on the two Pro product IDs (`StoreService.swift:166`); an offer-code subscription is an ordinary production transaction. This stays inside the Phase 2 moratorium.

---

### 5. The message

Cold-open with no reason why *this* person and it reads as a mass send, because it is one. The first line is a slot you fill per creator with something specific they actually made — that line is the whole difference between a DM that gets read and one that doesn't, and it is the only part you cannot template.

> 刷到你那条 XXXXX(具体提一句他发过的内容),笑死。
>
> 我一个人做了个 iOS App,叫「帮你骂」。就是那种——当场被人怼了脑子一片空白,晚上躺床上才想起来该怎么回的时候,帮你把那句话写出来。
>
> App Store:https://apps.apple.com/app/id6769317103
>
> 给你留了个三个月的 Pro 兑换码:`XXXXXXXX`。先把 App 装上,再去 App Store 右上角头像 →「兑换充值码或代码」→ 手动输入。
>
> 三个月后会按 ¥21/月 自动续订,你兑换完顺手去「设置 → Apple ID → 订阅」把自动续订关掉,这三个月照样能用。
>
> 不用发帖,也不用提我。用着觉得哪儿别扭,回我一句就够了。

Follow-up, only if they redeem:

> 忘了说,第一次点「发泄」或者「痛骂」会弹个框问要不要用云端 AI,记得选允许。Apple 本地那个模型太克制了,根本骂不出来,不允许的话出来的东西会特别温吞。

Two things this message does deliberately. It includes the App Store link — a code is useless without the app, and the earlier draft of this section forgot it. And it raises the auto-renew before they can worry about it, because that is the single objection that stops a stranger from redeeming, and pre-empting it costs one sentence.

---

### 6. What they'll actually see, and what could go wrong

**The step that decides whether the demo works at all:** the first time they tap 发泄 or 痛骂 they get a one-time cloud-AI consent sheet (App Review 5.1.2(i)). **They must allow it.** Decline, and `CloudPermission` returns `cloudAllowed: false` — on an Apple-Intelligence device the on-device model is far too gentle for vent, and without one the output is curated canned text. Either way they conclude the app doesn't work, and they will be right about what they saw. Hence the follow-up message.

**Pro does not unlock cloud everywhere.** Only 发泄/痛骂 are cloud-eligible (`CloudConsentGate.swift:57` — `cloudEligible = isPrivateDraft || (!onDeviceModelAvailable && cloudSendableEnabled)`, and `cloud_sendable_enabled` is `false` in the served config). So a Pro creator on a device without Apple Intelligence who taps 狠 still gets curated canned text (`CloudPermission.swift:88`, `willBeCurated`). If you have any choice, steer them to an Apple-Intelligence iPhone, or to 发泄/痛骂.

**Confident:**
- Offer codes apply to auto-renewable subs only. Both Pro products are `APPROVED` and eligible; the credit packs are not. Zero codes currently exist.
- The app is available in **175 territories including CHN**. `PHASE_5_STRATEGIC_2026-09.md` §8 lists "Mainland China SKU" as firmly out of scope — but that decision was about ICP / 备案 / GFW posture, not the storefront checkbox, and the storefront is on. A creator on a CN Apple Account can install and redeem.
- Cancelling auto-renew right after redeeming does not end the free period; access runs to the end of the offer.

**Could not verify — resolve these in Step 0, not in a DM:**
- **Whether redemption requires a payment method on file.** I believe it does not. I am not confident enough to put it in a message. Do not write 「不用留卡」 until you have watched a redemption.
- **The exact selectable durations.** If 3 months isn't offered, take the next longer option, not 1 month.
- **Apple's numeric caps** on codes per batch/quarter and maximum expiry distance. 25 is far below anything I have seen, but the ASC form is the authority.
- **Mainland reachability.** Cloud vent runs through a Cloudflare Worker to Groq/OpenRouter; whether that path works from a mainland network is untested. If your first CN creator reports 发泄 hanging, that is the likely cause — and it is a risk to the entire Xiaohongshu channel, so it is worth one probe before you send five codes into it.
- **Per-code attribution.** I found no evidence ASC reports which code a redemption used. Assume a count, not an identity. Ask them directly.

**Not fixed by any of this:** the free tier stays exactly as §1 describes. Offer codes fix *evaluation*, not *conversion*. The first real user arriving from a creator's post still lands on the 2-of-5, 8-of-24 wall on tap one. That is a separate decision and it should be made with a creator's reaction in hand, not before one.

*No changes were made to App Store Connect in preparing this — every API call was a read-only GET.*

> **What this section could not verify.** Apple's numeric limits on subscription offer codes (max codes per batch/quarter, max redemptions on a custom code, and the maximum expiration horizon) — I did not verify any of these and deliberately did not state a number; confirm in the ASC form. Whether a payment method is required on file at redemption — I believe it is not, but I am not confident, so the suggested DM does not claim it; watch one redemption before saying 不用留卡. The exact list of selectable offer durations (whether "3 months" is offered) — expected but unconfirmed. Whether App Store Connect reports per-code redemption attribution — I found no evidence it does; assume aggregate counts only. Whether the Cloudflare Worker / Groq / OpenRouter cloud-vent path is reachable from a mainland China network — untested and a material risk to the Xiaohongshu channel, since the app IS live in the CHN storefront. TestFlight-specific timings (Beta App Review turnaround, sandbox subscription renewal cycle counts) are from general knowledge, not measured on this account — but the repo-verified facts that decide against TestFlight are solid: cloud-worker/wrangler.toml:47 sets ALLOW_SANDBOX_RECEIPTS="false" and cloud-worker/src/verifier.js:44 rejects sandbox JWS in production, so a TestFlight tester silently lands on the 30/day free lane (DAILY_LIMIT_PER_DEVICE) instead of the 200/day Pro lane (PRO_DAILY_LIMIT). All App Store Connect calls I made were read-only GETs; I created nothing and the offer-code list remains empty.

---

# 3. The outreach kit

# The Outreach Kit — Xiaohongshu creator seeding

> Written against the live repo 2026-09-10. Every product claim below was
> checked in code, not in docs: `Shared/Models/Intensity.swift`,
> `Shared/Services/CreditCatalog.swift`, `Shared/AI/RoastEngine.swift`,
> `Shared/AI/EchoesPersonaCatalog.swift`, `Shared/Resources/StylePresets.json`,
> `Shared/Resources/Scenarios.json`, `Shared/zh-Hans.lproj/Localizable.strings`,
> `metadata/zh-Hans/description.txt`, plus `git show v1.4.0:…` to establish what
> is actually installable today.

---

## 0. Three walls, and the order they have to fall in

The previous draft of this kit named one blocker. There are three, and two of
them change what you are allowed to say in Chinese.

### Wall 1 — capability, not quantity

`DEV_PLAN_v1.6` P2.2 says a creator would "download it, burn three credits, and
hit a paywall." Wrong in both directions.

The quantity wall barely exists: `CreditCatalog.swift` grants
`seededTrialCredits = 10` on first launch plus `starterWindowDailyTrickle = 2`
per day for `starterWindowDays = 7`. Nobody hits a wall at three.

The capability wall sits exactly on the pitch. `Intensity.swift:38`:

```swift
var requiresPro: Bool {
    switch self {
    case .calm, .sharp: return false
    case .savage, .feral, .vent: return true
    }
}
```

and `CreditCatalog.swift:9` — credits "NEVER unlock a capability."

A code-less creator gets **体面 and 锐利** and **8 of the 24 styles** (高 EQ,
阴阳怪气, 日式敬语, 文学体, 哲学家, 奶奶智慧, 一句话, 小红书吐槽 — the rest are
`tier: "pro"`). No 狠, no 痛骂, no 发泄, at any credit balance. 虚拟舍友群 is
Pro too (`EchoesView.swift:62`). The headline of your own listing —
「先骂爽,再说人话」— is behind the wall.

### Wall 2 — hardware, and this is the one the last draft got backwards

`RoastEngine.swift:397`, the rewrite step:

```swift
guard let fm, fm.isAvailable else {
    logger.notice("On-device model unavailable; falling back to curated sendable.")
    return SendableRewrite(text: FallbackRoasts.curated(…), provenance: .curated)
}
```

**「改成能发的」 has no cloud branch.** On any iPhone without Apple Intelligence
— anything below iPhone 15 Pro — and on every Mac below macOS 26, tapping it
returns a random canned line for that style, not a rewrite of their draft.

So the Before/After transformation, the thing you most want them to feel, is the
*least* reliable surface in the app. The reliable ones are the opposite of what
the last draft assumed:

| surface | on a device WITHOUT Apple Intelligence |
|---|---|
| 体面 / 锐利 / 狠 | curated (canned) |
| **发泄 / 痛骂** | **real — cloud, Pro-gated, needs a consent tap** |
| 改成能发的 | **curated (canned)** |
| **虚拟舍友群** | **real — cloud, Pro-gated, zh-Hans personas only** |
| 帮我回消息 / 情绪翻译器 / 社交吐槽 | curated (canned) |

Consequence: **never tell a creator which path to try before you know what
device they are on.** One question fixes it, and §4 asks it.

Second consequence, for §1.E: `EchoesPersonaCatalog.swift:6-8` ships zh-Hans
personas only and falls back to zh-Hans for every other locale. 虚拟舍友群 is
**not** a route into zh-Hant or ja audiences. A Taiwanese creator gets Simplified
roommates. Pitch it to zh-Hans accounts only.

### Wall 3 — the build on the store right now is the wrong one

Live today: **v1.4.0 build 20**. v1.5.0 is in App Review.

`CuratedNoticeBanner` does not exist in the v1.4.0 tree — `git show
v1.4.0:RoastMate/Sources/Views/Components/CuratedNoticeBanner.swift` fails. The
stop-charging-for-canned fix is `4a392c4` + `36271e7`, both after the tag, both
unshipped. So on the build a creator installs **this week**:

- a credit is spent before the engine runs, the curated path reports success,
  and there is no refund and no notice;
- nothing tells them the text was canned.

`DEV_PLAN_v1.6` §1 calls that "taking money for something not delivered." Do not
spend a one-time code introducing a creator to it.

### Therefore, the sequence

| when | do | blocked by |
|---|---|---|
| **tonight, 20 min** | Mint the codes. ASC → 我的 App → 帮你骂 → 订阅 → RoastMate Pro 年度 → **优惠代码 / Offer Codes** → 创建 → free, 1 year → generate a batch of one-time-use codes, download the CSV. **This is a browser task. Do not write a script** — `PHASE_5_RESEARCH_PROTOCOL` line 350 already established the mechanism, and `P1.7` in the v1.6 plan is a fresh reminder of what "let me automate this first" costs. | nothing |
| **tonight, 2 min** | **Test the delivery path before spending a real code.** Send yourself, or a friend, a 私信 in the exact shape of §2's message with a fake 12-character code. If it arrives unfolded, proceed. If it is folded, blocked, or flagged, the whole kit needs the code in a *second* message — find that out now, not on candidate #1. | nothing |
| **this week** | Build the candidate list. 25 accounts, vetted per §1, in a plain text file. This is the un-blocked work, and it is the work four consecutive waves avoided. | nothing |
| **the day v1.5.0 flips READY_FOR_SALE** | Start sending. 2–3 a day. 10 codes. | App Review |
| **only if v1.5.0 is rejected** | Send anyway, and add one line to §4: 「现在这版有个 bug:生成不出来的时候会返回预设句子,还照扣额度。下一版修好了,在审核里。」 Honesty costs less than the discovery does. | — |

You have a real task for every day of the wait. Use it.

---

## 1. Creator archetypes

No named accounts. Kinds of account, plus the search moves to find them.

### The vetting pass — run this before you write anything

Search in the 「笔记」 tab, not 「用户」. Open notes where **收藏 is close to or
above 点赞**. (`DEV_PLAN_v1.6` P2.3 asserts Xiaohongshu weights Saves >
Comments > Likes. Treat that as a working heuristic — the repo records it with
no source and neither of us has verified it. It is directionally sane: a saved
note is one someone means to use later, which is the behaviour that makes a
comeback tool worth recommending.) Then vet the author:

- Posted within the last 14 days.
- They actually reply to comments. If they ignore their own comment section they
  will ignore a DM.
- Not wall-to-wall 「广告」 / 蒲公英合作. A feed of collabs means a rate card, and
  your no-budget DM wastes both your time and theirs.
- Bio does not say 商务/合作/微信xxx. That is a price list, not a person.
- Original writing, not a 搬运合集.
- **Strongest signal:** the comments under their note contain people asking
  「那到底该怎么回」「求话术」「蹲一个回复」. That is unmet demand you can answer,
  and it gives you a true, specific first line.

**Follower range, all archetypes: roughly 3k–5万.** Judgment, not data. Above
10万 and contact routes through 蒲公英 with a quote attached; below 2k and the
account is often dormant. Small accounts also reply, which is the point when you
are sending ten messages rather than a thousand.

**List 25, send 10.** Vetting kills candidates faster than you expect, and you
want the spare capacity when three of your first picks turn out to be collab
farms.

---

### A. 高情商话术 / 沟通表达博主 — start here

Their content format is "someone said X to you, here is how to reply."
RoastMate manufactures their content. Of all five, this is the only archetype
where the app makes their *job* easier rather than merely being *relevant*.

- **搜索词:** 高情商回话、话术、嘴替、这句话怎么回、说话之道、沟通技巧
- **标签:** #高情商沟通 #高情商回话 #说话的艺术 #沟通技巧 #嘴替
- **粉丝:** 5k–5万
- **Lead with:** the style shelf as a register-picker. Use the **free** ones,
  because these work even if the code never lands: **高 EQ / 阴阳怪气 /
  日式敬语 / 小红书吐槽** on the same input. Four registers, one screenshot, a
  carousel that writes itself. Save 文言文, 京片儿, 辩论收尾杀 for after they
  redeem — all three are `tier: "pro"`.

### B. 职场情绪 / 打工人吐槽博主

Four canned scenarios are theirs verbatim, from `Scenarios.json`: `boss_credit`
(「我做的项目,领导在全组面前说成是他的功劳。」), `boss_lastmin`
(「周五傍晚六点,领导甩给我一个『紧急』任务,周一就要。」), `groupchat_ignored`,
`groupchat_screenshot`.

- **搜索词:** 职场PUA、反PUA、甩锅、领导画饼、职场沟通、打工人嘴替、邮件话术
  — 反PUA is fine as a *search* term for finding them; it stays out of anything
  **you** publish (see §5).
- **标签:** #打工人日常 #职场沟通 #职场情绪 #上班搭子
- **粉丝:** 5k–8万
- **Lead with:** 职场冷暴力 and 辩论收尾杀, and 吵架模拟器 for rehearsing a
  review conversation. All Pro — so this archetype only works once the code is
  redeemed. Do not pitch B before the codes exist.

### C. 反内耗 / 情绪管理博主 (心理向)

The "Mate" half — the emotional-validation angle Gemini called the real moat,
since Apple is structurally forced to stay polite and will never ship a Feral
mode.

- **搜索词:** 精神内耗、课题分离、讨好型人格、情绪管理、事后才想起怎么回
- **标签:** #拒绝精神内耗 #情绪价值 #讨好型人格 #课题分离
- **粉丝:** 3k–8万
- **Handle with care.** Never let the pitch drift toward 心理咨询 or 治疗. The
  app is a creative-writing and emotional-expression tool; the safety filter
  strips names, threats and slurs, and it is not crisis support. **Skip accounts
  run by licensed practitioners, and skip anything about 校园霸凌 or 心理危机** —
  the exposure lands on them, and pitching a roast tool into a crisis context is
  what gets screenshotted.

### D. AI 工具 / 效率 App 测评博主 (中文)

The easiest yes and the weakest emotional fit. They review apps for a living, so
a DM with a code is a normal Tuesday.

- **搜索词:** 宝藏App、AI工具、iOS效率、快捷指令、Apple智能、端侧AI、小众App
- **标签:** #宝藏app #AI工具 #效率工具 #iphone必备 #快捷指令
- **粉丝:** 3k–5万
- **Lead with the privacy architecture — the only group that cares:** no
  analytics SDK, no advertising ID, no fingerprinting, cloud routing is a toggle
  in 「设置 → AI 与隐私」. Mention the Watch app, the macOS menu bar item, the
  Share extension, the Shortcuts/Siri intents — surface breadth is a review beat.
- **Highest risk archetype.** They will test on a Mac. Every Mac below macOS 26
  returns curated text for 体面/锐利/狠 *and* for 改成能发的. Give them the §4
  hardware warning **before** they open it, not after.

### E. 合租 / 留学生 / 独居生活博主 — zh-Hans accounts only

Narrow but high-resonance.

- **搜索词:** 室友、合租、奇葩室友、留学生日常、独居女生
- **标签:** #合租 #室友 #留学生日常 #租房
- **粉丝:** 3k–3万
- **Lead with:** `roommate_mess` (「室友的碗能放好几天,还说我『太计较』。」),
  `roommate_rent` (「室友那半份房租,永远是『马上就转』。」), and 虚拟舍友群 —
  three synthetic roommates who take your side. It is the most
  screenshot-friendly thing in the app, and it runs in the cloud, so it is real
  on **every** device.
- **Not a zh-Hant/ja route.** `EchoesPersonaCatalog.swift:6-8`: personas ship
  zh-Hans only and fall back to zh-Hans for every other locale. A Taiwanese
  creator would get Simplified roommates. Keep E in zh-Hans.

**Split for a first run of ten:** 3 from A, 3 from B, 2 from D, 2 from E. Hold C
until you have seen how the first eight go.

---

## 2. The DM

Two rules behind the wording.

**The code is in message one**, not a reward for replying. "Here, no strings"
outperforms "reply and I'll send you something," and given Wall 1 it is the only
honest way to ask someone to judge the product — without it they are evaluating
a politeness app called 帮你骂.

**There is no ask.** You are not requesting a post. This matches the rule already
locked in `PHASE_5_RESEARCH_PROTOCOL`: "No public mention / review / social post
conditional on the code." It also sidesteps the 私单 problem in §5.

One correction to the last draft's reasoning, because getting this wrong is how
you damage someone: **not asking does not remove their disclosure obligation.**
The obligation attaches to *receiving something of value* — a ¥138 subscription —
not to whether you asked. If they post, they should label it. §4 says so, and you
say it before they publish, not after.

And be clear-eyed about what this buys. Ten no-ask DMs is not a distribution
channel; it is ten qualified conversations with a chance of a post attached. See
§6 before you judge the result.

### Primary version

```
你好,我是「帮你骂」这个 App 的开发者,一个人做的。

刷到你那篇写【被同事当众甩锅、当场一个字都憋不出来】的笔记,评论区好多人在
问「那到底该怎么回」。我做的就是这件事:把你憋着没发出去的那句话原样写进去,
选一档语气,它帮你改成一句能发出去的。

给你一个一年 Pro 的兑换码,App Store 里直接兑,不用付钱、不用填任何东西:

XXXXXXXX

先说实话:这是个很小的独立 App,上线到现在一共二十几个下载,基本没人用,我
也没有任何预算。所以真的不用发笔记、不用提我 —— 我不是来买推广的。

就想听一句实话:你随手试完,哪一句最假、最尬?你要是觉得难用,直接说,我更
需要听这个。
```

Replace the bracketed line with a real reference to a real note of theirs. If you
cannot fill that bracket honestly, you have not read enough of their feed to be
messaging them.

### Shorter variant

For D accounts, or whenever the long version feels heavy.

```
你好,我是「帮你骂」的开发者,一个人做的小 App。

你那篇讲【对方阴阳怪气、自己当场语塞】的笔记,基本就是我当初做它的原因。

送你一年 Pro,App Store 兑换码:XXXXXXXX(不用付钱,也不用留任何信息)

不用发笔记、不用提我。就想知道你试完觉得哪里最尬 —— 难听的话最有用。
```

If you normally use an emoji when you message people, add one. A message with
zero warmth reads like a template, which is the one thing it must not look like.

**If your delivery test in §0 showed the code gets eaten**, split it:
message one is the note reference plus 「我这边有一年 Pro 的兑换码,方便的话我
发给你,不用回报什么」, and the code goes in a follow-up the moment they reply.
Worse than code-in-message-one, still better than a blocked DM.

---

## 3. The follow-up, and when to stop

**One follow-up. Seven to ten days later. Then never again.**

It has to add something rather than repeat the ask, and it has to hand them a
clean exit. Explicit permission to ignore you is what makes it land as courtesy
instead of pressure.

```
不好意思再打扰一次,就这一条,之后不会再发了。

上次那个兑换码要是没收到、或者兑的时候报错,跟我说一声,我再补一个。

没兴趣的话完全不用回,真的没关系 🙏
```

### The stop rule

- **Two messages total, per person, forever.** No third. Not a new angle, not
  "v1.6 just shipped, thought of you."
- **No channel-switching.** Do not go find their WeChat, Weibo, email or Bilibili
  because Xiaohongshu went quiet. Following someone across platforms after
  silence is the exact behaviour that gets a screenshot posted about you.
- **No public @ or comment.** Never drop 「试试我的App」 under their note.
- **Read-no-reply is a reply.** Log it as a no and move on.
- Track it in a plain text file: handle, archetype, date sent, code issued, date
  followed up, outcome. If you cannot see at a glance who is owed nothing, you
  will eventually message someone a third time.

---

## 4. When someone says yes

Write this before you send message one. The gap between "sure, I'll try it" and
them opening the app is short, and Wall 2 means the wrong instruction here does
active damage.

**Send it in two parts. The first part is one question.**

```
太好了,谢谢!先问一句:你手机是 iPhone 15 Pro 或更新的吗?(或者说,有没有
开「Apple 智能」?)

问这个是因为 App 里有一半功能走苹果的端侧模型,设备不支持的话会返回内置的
预设句子 —— 不是现场生成的。我先问清楚,免得你拿预设句子去判断这个 AI 的
水平。
```

Then, based on the answer, send **one** of these two.

**如果支持 Apple 智能:**

```
那就走完整的一条路,30 秒,别的先别管:

写一件今天真的让你不爽的事 → 强度选「发泄」→ 生成 → 再点「改成能发的」。
前后两版的反差才是这个 App 的全部意义,其它都是配菜。

第一次点「发泄」会弹一个联网生成的确认框,得点同意,不然出不来东西。
```

**如果不支持(或者主要在 Mac 上用):**

```
那有两个地方在你的设备上是真生成的,其余的先跳过:

1)强度选「发泄」,写一件今天真的让你不爽的事 —— 这一档走我自己的云端,
   任何设备上都是真的。第一次会弹联网确认框,得点同意。
2)「虚拟舍友群」:把同一件事发进去,三个 AI 舍友会一起替你吐槽。

先别点「发泄」下面那个「改成能发的」—— 那一步只在支持 Apple 智能的设备上
是真改写,在你这儿会返回一句预设的,跟你写的没关系。这是我目前最大的一个
坑,不是你操作错了。想看那一步该长什么样,我把我自己手机上的截图发你。
```

Then, either way:

```
兑换:App Store → 右上角头像 → 「兑换充值码」→ 粘贴。同一个 Apple ID 下的
iPhone 和 Mac 都能用。

提醒一句:一年到期后会自动续订,国区 ¥138/年(海外区是当地等值价)。不想续
的话,到期前在「设置 → Apple ID → 订阅」里关掉就行。我不希望你哪天莫名其妙
被扣钱。

想问你三个问题,一句话回就行:
- 哪一句让你觉得「这个我真会发出去」?
- 哪一句最假?
- 你会在什么场合想起来打开它?

再说一次:不用发笔记,不用打分,没有 deadline。
```

Why each piece is there:

- **The hardware question first.** `RoastEngine.swift:397` — the rewrite returns
  curated text whenever `fm.isAvailable` is false, with no cloud fallback. Sending
  a blanket "try 发泄 → 改成能发的" to an unknown device points half your
  recipients at the fake half of the product. One question removes that.
- **发泄 and 虚拟舍友群 as the floor.** Both go through your Cloudflare Worker, so
  both are genuinely generated on any device. They are also both Pro — which is
  exactly what the code buys, and the reason the code cannot wait for a reply.
- **The consent tap.** Vent/Feral are cloud-eligible but gated behind an explicit
  5.1.2(i) consent sheet. A creator who dismisses it gets the gentle local path
  and concludes the app is weak. Warn them.
- **Owning the rewrite gap out loud.** 「这是我目前最大的一个坑,不是你操作错了」
  costs you nothing with someone who already knows you have 23 downloads, and it
  converts a one-star reaction into a shrug. Offering your own screenshot gives
  them the Before/After anyway.
- **The auto-renew warning.** An offer code converts to a paying subscription
  unless cancelled. Gifting a year and letting them get silently charged is how
  you turn a supporter into someone with a story.
- **Three closed questions.** "What do you think?" gets no reply. These get one
  line each, and the middle one gives explicit permission to be negative — which
  is the answer you actually need.

**If they volunteer to post** — and only if they raise it first: six ready images
are at `/Users/jason/Documents/RoastMate/marketing/xiaohongshu/promo/`
(cover, pain, roommate, echoes, rewrite, CTA), and a Gemini+Codex-reviewed
reference post is at
`/Users/jason/Documents/RoastMate/docs/marketing/xiaohongshu-launch-zh.md`.
Note that `05-rewrite.png` is a promo card, not an actual before/after pair — if
you want to show the transformation, screenshot your own real one. Hand over the
images, let them write their own copy, and tell them to label it per platform
rules, **because they received a paid subscription** — that is true whether or
not you asked for the post. Do not draft their caption and do not make anything
conditional.

---

## 5. Do not do this

1. **Do not send ten identical DMs in one sitting.** Repetitive outbound 私信
   from one account is the classic spam signature. Two or three a day, and vary
   the opening line *because you read a different note*, not by shuffling
   synonyms.
2. **No external links in the first message.** Say 「App Store 搜「帮你骂」」.
   Your own launch doc reached this for the public CTA; it applies double in a DM.
3. **Do not DM from a cold account.** No notes, no history, no following, sending
   unsolicited messages with a code in them — that is what a scam looks like.
   Post a few real things first, follow the person, leave one genuine comment.
   Send from your own personal account, as `xiaohongshu-launch-zh.md` assumes.
4. **Do not pay for a post outside 蒲公英.** Off-platform paid collaborations are
   against platform rules as commonly understood, and the penalty lands on the
   *creator's* account, not yours. The no-ask posture sidesteps it.
5. **Never trade the code for a rating or a review.** Incentivised App Store
   reviews put your listing at risk under Apple's guidelines, and
   `PHASE_5_RESEARCH_PROTOCOL` already locked this. Keep it locked.
6. **No 引流 in public comments.** Comments get deleted, accounts get flagged, and
   it reads as desperate.
7. **Do not pitch into crisis contexts.** No accounts centred on 校园霸凌, 自伤 or
   心理危机, and no minors. The app is not crisis support and does not claim to be.
8. **One code per person, never posted publicly.** They are one-time-use. A code
   pasted into a comment or a group is burned by a stranger within minutes.
9. **Do not argue with a no.** Not a rejection, not a bad take, not a public
   criticism. Thank them and leave. You are one person with your real name on it.
10. **Do not send before v1.5.0 is live** — unless you add the honesty line in §0.
    The build on the store today charges a credit for canned text and says
    nothing about it.
11. **Settle the mainland question before any volume.** Your launch doc flags it
    and it is unresolved: 「帮你骂」 is downloadable in the CN store, but China AI
    apps technically require 版号/ICP, and a high-visibility push on an unlicensed
    listing can get it pulled. Ten quiet DMs is a different risk profile from a
    viral note. Ten is fine. A hundred is a decision you have not made yet.

**Framing discipline throughout.** Keep it at 反内耗 / 高情商 / 有分寸, never
攻击 / 骂人. The name 「帮你骂」 sounds aggressive, so defuse it early the way the
launch doc does: 名字听着冲,其实更像随身嘴替. Keep #怼人语录 and #反PUA out of
anything you publish — they are search terms for finding creators, not tags for
your own posts.

---

## 6. What counts as this working

Set this before you send, because otherwise you will measure ten DMs against
downloads, conclude that outreach does not work, and go back to Xcode. That is
the failure this entire month exists to break.

Ten no-ask DMs cannot move a download number, and they are not supposed to. What
they can produce, mapped onto `DEV_PLAN_v1.6` §3's own criteria:

| outcome | counts as | honest expectation |
|---|---|---|
| 3–4 real conversations, written down with quotes | ✅ the v1.6 plan's stated bar for "does anyone want this" | this is the target |
| ≥1 creator finishes the 发泄 path and tells you which line felt sendable | ✅ first outside signal in the product's life | plausible |
| ≥1 unprompted share or post | ✅ the v1.6 plan's card criterion | bonus, not the goal |
| downloads move off 23 | ⚠️ not measurable at this size — detailed ASC reports suppress below 5 and captured 0 of 197 lifetime page views | do not use this |
| zero replies from all ten | ❌ **a result, not a failure** — it says the DM or the archetype is wrong, and you rewrite one variable and send ten more | possible; plan for it |

Write the outcome of all ten in the same text file as the tracker, in one line
each. Ten lines is the first primary-source data this product has ever had.

> **What this section could not verify.** Platform rules — the highest-uncertainty part of this kit. I used no web access, so every claim about Xiaohongshu's current DM rate limits, external-link handling, 蒲公英 brand-collaboration rules, and the penalties for off-platform paid collaborations (私单) is from general knowledge, not a live source. These rules change and are enforced inconsistently. Treat the do-not-do list as risk-reduction heuristics to sanity-check against current platform terms, not as verified policy. The one platform claim I did NOT invent is the Saves > Comments > Likes weighting, which comes from your own DEV_PLAN_v1.6 P2.3.

Creator conversion — I have no data whatsoever on which account types actually respond or convert, for this app or any other. The five archetypes are reasoned backwards from your own Scenarios.json categories (boss / ex / family / roommate / groupchat), the 24-entry StylePresets.json, and the store positioning. They are hypotheses to test across ten messages, not findings. The follower ranges (3k–5万) are judgment with stated reasoning, not measured numbers, and I deliberately produced no engagement or conversion statistics because I would have had to make them up.

Apple specifics — I could not verify the current Chinese App Store redemption UI string; I wrote 「兑换充值码」 but recent iOS versions have also used 「兑换代码」. Check on your own device before sending, since a wrong instruction in the first message costs you the reply. I also did not verify offer-code eligibility semantics against the live ASC API; the endpoints in §0 are quoted from docs/PHASE_5_RESEARCH_PROTOCOL_2026-09.md, not tested. Nothing in scripts/ creates offer codes, which is why I read P2.2 as un-started — but absence of a script is not proof that no codes exist, so confirm before assuming.

Product state — I did not verify the v1.5.0 review status (I took 'in App Review' from the brief) and did not run the app or check a device. The curated-output caveat in §4 is read from the DEV_PLAN_v1.6 P1.2/P1.3 write-ups plus the macOS 14.0 vs AppleFMBackend 26+ deployment gap, not observed on hardware. Worth one real-device check before you tell a creator how the app will behave, since that paragraph is you making a promise about behaviour.

Legal — whether the CN listing carries 版号/ICP is unknown to me and is a legal question, not a code question. I flagged the risk your own doc raised; I cannot assess it.

---

# 4. Xiaohongshu strategy

## 小红书 (Xiaohongshu): mechanics, content strategy, and the account question

### 0. Three facts checked against the live store and the live code. The third one gates the other two.

**(a) The app is live on the mainland CN App Store as 「帮你骂」.** `itunes.apple.com/lookup?id=6769317103`
across six storefronts: `cn` → 帮你骂, `hk`/`tw` → 幫你罵, `jp` → RoastMate, `us`/`sg` → RoastMate AI —
all v1.4.0, all free. So `docs/PHASE_5_STRATEGIC_2026-09.md` §8 "Mainland China SKU — out of this plan"
refers to ICP/备案/go-to-market, **not** availability. A mainland reader who sees a post can install today.

**(b) The in-app card's own CTA sends Chinese users to a meat-roasting app.**
`Shared/zh-Hans.lproj/Localizable.strings:497` reads `"sharecard.findus" = "App Store 搜索 RoastMate"`.
Run that search against the CN storefront:

| rank | trackId | name | developer |
|---|---|---|---|
| 1 | 848819352 | RoastMate | **Meat & Livestock Australia Limited** |
| 2 | **6769317103** | **帮你骂** | Yuhe Ye |
| 3 | 6766095605 | RoastMate | ilke alpay |

Searching 「帮你骂」returns his app at **#1**, with nothing else close. Same for zh-Hant. Line 497 of
`Shared/zh-Hant.lproj/Localizable.strings` has the identical defect (`"App Store 搜尋 RoastMate"`);
`ja` and `en` are correct, because those listings really are named RoastMate.

**Every CTA in every post must say 「App Store 搜索 帮你骂」.** Never the English name.

**(c) The fact the previous draft of this section never checked: what the person who downloads
actually gets.** This is the one that decides whether any of the rest is worth an evening.

- `Shared/AI/FallbackRoasts.swift` holds **five** hardcoded zh-Hans strings. `RoastEngine.curatedFallback`
  calls `FallbackRoasts.curated(for style:locale:count:)`, which **ignores the `style` argument entirely**
  and returns a shuffle of that five-item pool. Same five sentences whichever of the 24 styles you tap,
  and they have no relationship to what the user typed.
- That path fires whenever Apple Foundation Models is unavailable. `AppleFMBackend` is
  `@available(iOS 26.0, macOS 26.0, *)`, so **every device on iOS 18–25 hits it regardless of hardware** —
  on top of the Apple-Intelligence chip and region requirements that a mainland-purchased iPhone is also
  unlikely to satisfy.
- `CreditCatalog`: `starterWindowDailyTrickle = 2`, `starterWindowDays = 7`. **Two free generations a day,
  for one week.**
- `StylePresets.json`: **8 of 24 styles are `tier: "free"`** (`high_eq`, `passive_aggressive`,
  `jp_workplace_keigo`, `literary_lu_xun`, `philosopher`, `grandma_wisdom`, `tweet_short`, `xiaohongshu`).
  The other 16 — including 律师函体, 文言文, 京片儿, 职场冷暴力, 辩论收尾杀 — are Pro.
- The only thing on a no-FM phone that *is* a real model is 发泄/痛骂, which goes to
  `https://roastmate-vent.yyyyy-yeyuhe.workers.dev` (`Shared/Services/CloudConfig.swift:16`). It answers
  from here. **Whether a `workers.dev` subdomain answers from a mainland network is untested**, and it is
  the load-bearing unknown of this entire section.

`docs/DEV_PLAN_v1.6_2026-09.md` §1 already named this defect — *"charges a credit, runs no model, returns
one of five hardcoded strings, and presents it as if the AI wrote it"* — and P1.1/P1.2 fix the charging and
add a notice in v1.5.0, now in review. **Neither fix makes the output good.** A curated-notice banner is
honesty, not a product. So this channel cannot be planned as "drive installs"; it has to be planned as
"publish something valuable, and let the app be a truthfully-described extra."

---

### 0.1 The pre-flight. Do this before writing a single line of any post.

**One WeChat message, five minutes, free.** Ask anyone he knows on a mainland network to open
`https://roastmate-vent.yyyyy-yeyuhe.workers.dev/` in a phone browser and screenshot what happens.
A `405` or any JSON error means reachable. A timeout or reset means not.

Then branch, and do not skip the branch:

| Result | What it means | What to do |
|---|---|---|
| **Reachable** | 发泄/痛骂 works for mainland arrivals who grant cloud consent. The app has a real, differentiated thing to offer | Post to a mainland audience. CTA states the free floor honestly (§3) |
| **Not reachable** | A mainland install is five canned sentences and nothing else | **Do not drive mainland installs at all.** Publish the same posts with **no app mention** for the first three, purely to learn which hook lands — that reading is worth having on its own. Point the CTA at **zh-Hant readers (HK/TW)** instead, where the listing is 幫你罵 and there is no GFW question |

Either way the *content* plan below is unchanged, because every post is built to be useful without the
app. Only the CTA changes. That is deliberate: it means the pre-flight can come back negative and the
evening's work is still not wasted.

---

### 1. What earns 收藏 for this product specifically

Saves > comments > likes is directionally right; the circulating numbers disagree with each other and none
are official (§8). What every source agrees on is that deep signals — saves, shares, follows, dwell —
outweigh likes, and that a save is read as evidence the note solved a problem the reader expects to have
again.

That last clause is the strategy, because it matches this product's usage shape, which the repo already
identified — `docs/PHASE_5_STRATEGIC_2026-09.md`: *"Bursty usage ≠ daily subscription."* Nobody reads a
comeback app's post *during* the fight. They read it on the sofa, calm, and think *I'll need this.*
**收藏 is the literal verb for that.**

So the rule, now doubly binding given §0(c):

> **The note must be completely usable with nothing installed.** If the reader must download to get the
> value, they neither save nor install — and if they *do* install, §0(c) is what greets them. If the note
> *is* a working comeback sheet, they save it, and the app becomes the answer to *"my situation isn't one
> of your ten."*

Three save-motives fit. Everything else is a like, and a like is the cheapest signal on the platform:

1. **存着备用** — a menu I'll pick from later. Many phrasings of one situation.
2. **存方法** — a rule I want to remember. A repeatable procedure, not a punchline.
3. **存在事发之前** — preparation for a dated event. 国庆、过年、年终评估、相亲.

What does not earn a save: "look what the AI wrote, lol." Screenshot-of-funny-output gets likes, dies in
twelve hours, teaches nothing, and sets an expectation §0(c) cannot meet.

---

### 2. What the product will actually let you put on an image

The code forbids the obvious Before/After, deliberately. From `Shared/Services/ShareCardModels.swift`:

> *"This type deliberately has **no** field for the private vent draft. The v1.3.1 purge removed
> `ventText` / `revealVent` … so that no code path — present or future — can put the user's private text
> onto a shareable, RoastMate-branded image."*

`Shared/Services/ShareCardScenario.swift` records why the obvious repair (model-written abstracted "before"
line) was designed and **rejected**: it couldn't reach the installed base, and *"a model summary of the
user's private situation, rendered onto a branded public image, is a different thing from the sendable
reply."* Don't argue with it. Design around it.

| Asset | Where | Privacy risk | Available today? |
|---|---|---|---|
| **Sample Gallery** — **17** authored situation→response pairs, 4 locales | `Shared/Resources/SampleRoasts.json` | Zero — authored by Jason, already public in the shipped app | ✅ |
| **Scenario catalog** — 10 canned situations, 4 locales (only **2** are family: `family_compare`, `family_money`) | `Shared/Resources/Scenarios.json` | Zero | ✅ |
| **Setup chips** — 16 authored "before" lines; **13 are work/roommate, 3 are family** | `ShareCardScenario.swift` + `Localizable.strings:571–586` | Zero **by construction** — closed enum, user-tapped, never model-written | ⚠️ ships in v1.5.0, in review |
| **Style variety** — 24 named styles, **8 free / 16 Pro** | `StylePresets.json`, names at `Localizable.strings:329–398` | Zero | ✅ (but see the free/Pro split) |
| Vent / Feral output (发泄 / 痛骂) | cloud path | **Never post it** | — |

*(The store description says "15 curated examples." The file has 17. The description is stale; trust the file.)*

**The Before/After that survives is: authored setup line → written comeback.** The contrast doesn't need
the *rawness* of the before — it can come from **the register gap**. 「又开始催婚」against a 律师函体 reply
is the same joke shape as vent→polished, and carries no private text at all.

And a convergence worth naming: **posting Feral/Vent output would violate Xiaohongshu's rules anyway.**
The community standard bans 辱骂、诋毁、嘲讽、威胁他人. The product's privacy constraint and the platform's
content policy point the same way — post the polished half. Which is also the half the product sells:
「先骂爽，再说人话」.

---

### 3. Three post concepts

Keep titles under ~20 characters or the feed truncates. Title and first line carry more weight than tags,
so the phrase you want to own goes in **the title, the first line, and the tags** — all three.

**The number in the title must equal the number of lines in the post.** Not the number of styles the app
has. §0(c) is why: a title promising 24 against an app that gives 8 free is a one-star review with a delay
fuse.

---

#### Concept A — 一个场景，十种嘴替 (save-motive: a menu)

**标题：** `同事抢我功劳，我回了10种`

**首句（决定读者停不停）：**

```
上周组会，我熬了两周的东西，他一句「我们团队做的」就带过去了。
当场没吭声，回家把这一句话重写了十遍。
第 6 条我自己都没敢真发出去。
```

**卡片内容（每张两到三条，配风格名）：**

```
高EQ ｜ 很高兴这个思路能帮到团队。我把当时的原始文档同步到群里，大家对齐一下细节。
阴阳怪气 ｜ 辛苦你替我汇报。下次我把 PPT 也提前做好，省得你临时组织语言。
一句话 ｜ 活是我干的，掌声你收着。挺好，各取所需。
冷处理 ｜ 收到。原始文档我发群里了。
职场冷暴力 ｜ 这个项目后续的问题，我按你刚才的口径转给你。
MBA 黑话 ｜ 为了闭环，我把这个项目的 owner 和交付记录拉通同步一下，方便后续对齐。
律师函体 ｜ 兹就该项目归属一事说明：本人保留提供全部提交记录及时间戳的权利。
文言文 ｜ 劳者我也，名者彼也。自古如此，何足道哉。
京片儿 ｜ 得嘞，您这功劳领得，比我干活还熟练。
辩论收尾杀 ｜ 你说是团队做的，那团队里谁写的第一版？这个问题答完，我们就不用再聊了。
```

**结尾（reachable 版）：**

```
存一下，轮到你的时候不用现想。
（这些我是用自己做的一个 app 生成的，叫「帮你骂」，App Store 搜得到。
一个人做的，免费版一天两条，够应急。）
```

**结尾（unreachable 版 / 前三篇）：** delete the parenthetical entirely. Just 「存一下，轮到你的时候不用现想。」

*Fixes made to this concept:* the previous draft's 文言文 line read 「乃其之习也」, which is not idiomatic
文言 — 「其之」 doesn't work as a possessive there. Replaced with a clean parallel couplet. 「倒吸一口凉气」
signals fear, not savagery; 「没敢真发出去」 is what a person would actually write and sets up curiosity.
And the count came down from 24 to 10 for the reason above.

*Why it saves:* it's a menu. Different counterparties need different registers — that's `StylePresets.json`'s
thesis rendered as a post, and a menu is re-openable, which is what a save is for.

---

#### Concept B — 别发第一版 (save-motive: a method)

Unchanged from the previous draft, because it is the strongest of the three and needs no repair.

**标题：** `气到发抖时，别发第一版`

**首句：**

```
一个我用了半年的规矩：情绪最上头的那十分钟，写归写，但不准点发送。
```

**正文三步：**

```
1. 先写只给自己看的那一版。脏话随便，越难听越好。
   写完你会发现，你气的其实不是那件事。
2. 隔十分钟再看一遍，把里面唯一那句「事实」挑出来。
   剩下的都是情绪，情绪不用发给他。
3. 只把那句事实，换成对方接得住的说法，再发。

发出去的那版要做到两件事：立场不退，把柄不留。
```

**只放 After 的对照：**

```
场景 ｜ 临下班甩来「紧急」活
能发的版本 ｜ 这个我可以做，但会占掉周一上午原本给 X 的时间。你定哪个先？

场景 ｜ 已读不回
能发的版本 ｜ 那这条我当没发过，你想说的时候再说。

场景 ｜ 借了东西不还
能发的版本 ｜ 那个我这周要用，你什么时候方便还我？
```

*Why it saves:* it's a rule, not a joke — and it is the product's actual thesis, since the store
description opens on 「先骂爽，再说人话」 and the two-step is literally what the app does. This post recruits
people who are still using the behaviour in a month, whether or not the app served them well.
**Show only the After.** The Before is described as a process step, never rendered.

**This is the post to publish first if the pre-flight comes back unreachable** — it stands entirely on its
own and needs no app at all.

---

#### Concept C — 回家过节，先存这10句 (save-motive: prepare before a dated event)

National Day is ~3 weeks out and is the biggest 催婚/亲戚盘问 window before Spring Festival. Publish this
first **if the pre-flight is clean**.

**The previous draft's version of this post was broken and must not ship as written.** It was titled
「先存16句」 and sourced the 16 from `ShareCardScenario.swift` — where 13 of the 16 are coworkers and
roommates. 需求改了又改 and 前任又冒出来了 and 借了东西不还 are not things an aunt says at dinner. A reader
notices by card four. Only three chips map: 「你看看人家」、又开始催婚、没人问,他偏要教. `Scenarios.json`
adds two more (`family_compare`, `family_money`).

So this is a **writing** post, not a copy-paste post — about ninety minutes, still one evening.

**标题：** `国庆回家被盘问，先存10句`

**首句：**

```
每年国庆和过年，亲戚问的其实就那几句。提前想好一句，比当场脸红强。
```

**卡片格式（对方说 / 你可以说，一页两组）：**

```
对方 ｜「你看看人家」
你 ｜ 人家挺好的，我也挺好的。咱不用比，各过各的。

对方 ｜「怎么还不结婚」
你 ｜ 我知道你是关心我。这事我心里有数，有进展第一个告诉你。

对方 ｜「一个月挣多少啊」
你 ｜ 够花，也存得下一点。您就放心吧。

对方 ｜「没人问，他偏要教」
你 ｜ 谢谢，我先按我自己的方式试试，不行了再来请教您。

对方 ｜「这工作有什么前途」
你 ｜ 我自己挺喜欢的，也在往上走。等做出点样子我再跟您细说。

对方 ｜「什么时候回来发展」
你 ｜ 现在这边的事还没做完，回来的时候我肯定提前说。

对方 ｜「你表哥都买房了」
你 ｜ 他挺厉害的，我按我自己的节奏来。

对方 ｜「是不是眼光太高了」
你 ｜ 也不是眼光高，就是没遇上。遇上了我第一个告诉您。

对方 ｜「我们那会儿……」
你 ｜ 您那会儿是不容易。现在也有现在的难处，都一样。

对方 ｜（被问烦了，想收场）
你 ｜ 行了行了，先吃饭吧，菜要凉了。这个咱回头单聊。
```

*Note the register:* 您 to elders, 你 to peers. Warm, not combative — this is family, and a post that hands
readers ammunition to blow up a holiday dinner will get 举报, not 收藏. The last line is the one people
actually save, because 收场 is the real skill.

*Why it saves:* dated preparation is the highest-save-rate shape there is. The reader isn't in the
situation yet, which is exactly when saving beats acting.

---

### 4. Tags and search

Tags are not a distribution lever — they're **the label you're asking the system to file you under**.
Content semantics now dominate the match, so a tag that contradicts the body hurts.

**5–8 tags total, no more:**

| Layer | Count | Purpose | Examples |
|---|---|---|---|
| Category anchor | 1 | Which pool you're in | `#职场` or `#情感` — pick one, don't hedge |
| Intent | 2–3 | What people search when they need this | `#高情商回复` `#职场沟通` `#嘴替` `#说话之道` |
| Long-tail exact-match | 2–3 | The specific situation, matched to the title | `#同事抢功劳` `#被抢功劳怎么办` `#催婚怎么回` `#已读不回` |

- **Search phrase in the title and first line, not only the tags.** 「催婚怎么回」 in tags but absent from
  the body is a wasted match.
- **One category anchor per post.** Tagging `#职场` and `#情感` together dilutes the label and the note
  gets tested into the wrong pool.
- **Don't tag `#独立开发` on content posts.** It files you under developer content, which reaches
  developers — who will never pay ¥21/month for a comeback app. Save it for a separate 做了个 app 的过程
  post if he ever wants one.
- **No 引流.** Links, QR codes in the image, 「私信我」, variant-spelled workarounds — all draw 限流.
  **No QR in Jason's own posts.** App name in plain text, once, near the end, or not at all.
- **Soft save-prompt only.** 「存一下，轮到你的时候不用现想」 is fine. 「点赞收藏关注三连」 is 诱导互动 and
  penalised. The soft version is also the honest one.

---

### 5. Format: 图文, and the honest counter-argument

**图文 carousel, 8–10 cards, cover at 3:4.**

1. **The value is text.** A video of text is text you can't pause on. The joke lives in the exact wording
   of 「劳者我也，名者彼也」— that has to be readable and re-readable.
2. **Saves exist to be re-opened.** You can't scrub back to card 6 of a video at the moment you need the
   line. A carousel is a document; a video is a broadcast. Format and save-motive have to agree.
3. **One evening, one person, no skills.** A 10-card 图文 is a Keynote file with one text box per slide.
   A video that clears the bar needs a hook, pacing, captions, editing — a skill he doesn't have and a
   project that becomes the fifth wave of retreating into a tool instead of shipping the post.

**Counter-argument, stated honestly:** the platform is tilting toward video, and 2026 reporting claims
video notes get materially more base exposure (against a higher CTR and dwell bar). I could not verify any
of those numbers (§8). 图文 swims slightly against the tilt. Compensate by **making the cover do the work a
video hook would do**: one sentence, huge type, high contrast, the situation stated flatly so the reader
recognises themselves in half a second.

**Cover spec: 3:4, 1080×1440.** Note the mismatch — `Shared/Services/ShareCardModels.swift` exports
`portrait45` at 1080×1350 (4:5) with a comment calling it *"4:5 for 小红书 / IG feed."* 4:5 is the
Instagram number. Jason authors his own covers at 1080×1440 regardless; whether the app gains a
`portrait34` case is a separate call, and under the v1.6 code moratorium the answer is no.

---

### 6. Own account or creator outreach?

**Post from his own account, openly as the developer, leading with the content. No creator outreach.**

**Why not outreach:**

- **It has a cash floor he doesn't have.** Commercial collaboration runs through 蒲公英 with a cooperation
  label in the first paragraph.
- **The cheap version is an explicitly penalised category.** Unlabelled commercial content dressed as
  genuine personal recommendation — 虚假种草 — is a named enforcement priority. "Ask a small account to
  post about my app for free" produces exactly that.
- **He cannot brief a creator, because he has no data.** 4,919 impressions → 197 page views → 23 downloads,
  lifetime. He has never had a piece of content work. A brief written from zero evidence buys a creator's
  audience and spends it on the wrong hook.
- **And §0(c) means he'd be buying installs into a five-string fallback.** Paying for reach before the
  arrival experience is fixed is the most expensive possible way to generate one-star reviews.

**Why his own account genuinely works here:**

- **Distribution is content-first, not follower-first.** Reported consensus is that a note's audience is
  decided by its own labels and early engagement, not the account's follower count. A zero-follower account
  is not the handicap it would be on Instagram or X. (The widely-repeated 养号 ritual has no corresponding
  clause in the platform's published rules.)
- **It's the only feedback loop he can afford.** The problem is 197 lifetime page views — he has never had
  enough traffic to learn anything. Posting himself is the cheapest instrument that returns a reading on
  which hook lands, and that reading is worth having *even if the pre-flight comes back unreachable and
  he never mentions the app at all.*

**The persona:**

- **Be openly the developer. Do not pretend to be a random user.** A fake user persona is 虚假种草.
  一个人做的独立开发者 is both honest and a well-liked persona, so the compliant choice is the
  better-performing one.
- **But don't lead with it.** The hook is the comeback, not the app. The app appears once, near the end,
  in plain text, with the free floor stated. Content first, attribution second, no link.
- **Free adjacent surface: other people's comment sections.** Notes asking 「这种情况怎么回？」 are
  everywhere. A genuinely good reply costs five minutes and is not 引流 — *as long as he doesn't name the
  app*. Naming it repeatedly in comments is 引流-adjacent and gets flagged. Answer well, sign nothing, let
  the profile do the rest.
- **专业号 vs 个人号:** start personal. 专业号 unlocks commercial tooling he doesn't need and brings
  brand-account scrutiny he doesn't want. Whether an openly commercial personal account is expected to
  convert is an open question, not settled advice (§8).

**Cadence and the failure mode.** Cold-start guidance circulating suggests 20–30 notes in the first 30
days; unrealistic for one person with a job. Realistic: **3 posts a week, one evening each, six weeks
(~18 posts)**, re-cutting the three concepts across different situations.

The failure mode is not that the channel doesn't work. It's that he posts twice, gets 200 impressions,
declares Xiaohongshu dead, and goes back to Xcode — the exact pattern `DEV_PLAN_v1.6_2026-09.md` §1
identifies four times over. **Fewer than ~10 posts is not a test.** Write that down before starting.

**Kill criterion, in the style this repo already uses for `roommate_group` and `echoes`:** after 15 posts
over 6 weeks, if no single note clears ~1,000 impressions and total saves across all posts are under ~50,
**the hook is wrong, not the channel** — change the content shape, don't abandon the surface. Abandon only
if the App Store side stays flat too. The readable App Store signal is CN-storefront **Search-source**
impressions in ASC Analytics (this traffic arrives as a store search for 「帮你骂」, not as a link), which
is a different number from the `sharecard_v14` campaign token — that token measures QR scans off the in-app
card and will read zero for this entire effort.

---

### 7. Before the first post

| # | Action | Cost | Needs a build? |
|---|---|---|---|
| 0 | **Run the §0.1 pre-flight** — one message, five minutes. Nothing below matters until it comes back | 0 | No |
| 1 | Every CTA says **「App Store 搜索 帮你骂」**, never RoastMate | 0 | No |
| 2 | Every CTA that mentions the app states the free floor: **一天两条，共七天**. Never a style count | 0 | No |
| 3 | Fix `sharecard.findus` → `"App Store 搜索 帮你骂"` (zh-Hans:497) and `"App Store 搜尋 幫你罵"` (zh-Hant:497). Leave `ja`/`en` — those listings really are named RoastMate | 2 lines | **Yes** — collides with the v1.6 moratorium; it is two string literals and it is currently sending Chinese users to an Australian meat app, so it rides the next binary either way |
| 4 | Leave `share_card_enabled: false`. The QR growth badge shipped in v1.4.0 (`ShareCardBadge.swift` is at the tag), so flipping it is remote-only — but it turns on a badge whose findus line currently points at the wrong app. **Do #3 first.** `share_card_visible` is already `true`; the card itself is live | remote | No |
| 5 | `share_card_setup_enabled` — the setup chips are **not** in v1.4.0 (`ShareCardScenario.swift` is absent from the tag). Flipping it does nothing until v1.5.0 clears | remote | Waits on review |
| 6 | Author covers at **1080×1440 (3:4)**, not the app's 4:5 export | 0 | No |
| 7 | Never post 发泄/痛骂 output. Private by design, and 不友善内容 on the platform | 0 | No |

**Jason's own posts need no share card at all** — he composes the images himself in Keynote. The card
matters for the *user-generated* loop, which is second-order and only matters once there are users.
**Do not block the first post on the card.**

---

### 8. What I could not verify

- **The exact ranking weights.** Sources disagree in the same session: one gives
  `Likes×1 + Saves×1 + Comments×4 + Shares×4 + Follows×8`; another says a save is worth five likes.
  Xiaohongshu has never published a formula. The only defensible claim is the *direction* — deep signals
  beat likes. **Do not put a multiplier in the doc.**
- **The 图文-vs-视频 numbers** (video ≈1.8× base exposure; CTR floors 2.5%/4%; dwell floors 25s/70s).
  Marketing blogs, not the platform. Consistent folklore, not measurement.
- **Whether `roastmate-vent.yyyyy-yeyuhe.workers.dev` is reachable from mainland networks.** The single
  most important unknown in this section, which is why it is §0.1 and not a footnote. It answers from a
  non-mainland network (405 on `GET /`, a JSON validation error on `POST /v1/vent`), which proves the
  Worker is alive and proves nothing about the GFW.
- **Whether Apple Intelligence is actually available to a typical mainland reader's iPhone.** The iOS 26
  floor is certain from the code (`@available(iOS 26.0, macOS 26.0, *)`). The hardware and region gates on
  top of it are Apple's, they have changed repeatedly, and I did not test a real mainland device. The
  fallback path is the safe assumption.
- **Whether 「帮你骂」 itself trips the platform's 违禁词 filter.** It contains 骂 on a platform that
  penalises 辱骂. Unknowable without testing. If early posts are suppressed with no obvious cause, this is
  the first hypothesis: drop the app name from one post and compare.
- **Whether generative-AI content served to mainland users from a CN-storefront app carries a 备案
  obligation.** Out of my competence, not something to guess at. Flagged because the app *is* on the CN
  store whatever the roadmap says.
- **Current tag volumes.** Reading 小红书 search volume needs a logged-in account. §4's tags are reasoned
  from what people plainly search, not measured.
- **Whether an openly commercial personal account is expected to convert to 专业号.**

**On sources:** the previous draft of this section listed ten secondary URLs (marketing blogs, 知乎 posts,
one official 社区规范 page). I verified the App Store and repo facts myself and re-ran them; I did **not**
re-open those ten links or confirm they say what was attributed to them. Every platform-mechanics claim
above should therefore be read as "consistently reported," not "confirmed" — which is exactly why none of
the numbers made it out of this section.

> **What this section could not verify.** I could not verify any specific ranking weight. Two sources in the same search session contradict each other — one gives CES as Likes×1 + Saves×1 + Comments×4 + Shares×4 + Follows×8, another claims one save equals five likes — and Xiaohongshu has never published a formula. The only claim I would defend is the direction (deep signals beat likes), which every source agrees on; the plan's Saves > Comments > Likes ordering is directionally supported but the specific ordering of saves vs comments is NOT something I could confirm. Do not put a multiplier in the doc.

The 图文-vs-视频 figures (video ~1.8x base exposure weight; CTR floors of 2.5% for 图文 and 4% for 视频; dwell floors of 25s and 70s) all come from Chinese marketing blogs, not from the platform. They are mutually consistent, which is weak evidence, and they may simply be copying each other. My format recommendation does not depend on them being right.

I could not verify: whether the app name 「帮你骂」 itself trips the platform's 违禁词 filter (it contains 骂 on a platform that penalises 辱骂); whether the Cloudflare Worker serving the 发泄/痛骂 path is reachable from mainland networks, which decides whether mainland arrivals get real output or curated fallback; whether generative-AI content served to mainland users from a CN-storefront app carries a 备案 obligation (out of my competence — flagging only because the app IS on the CN store); current 小红书 tag search volumes, which need a logged-in account, so the tags in §4 are reasoned rather than measured; and whether an openly commercial personal account is expected to convert to a 专业号.

What I DID verify directly, against live systems rather than documents: the app's storefront availability and listing names across cn/hk/tw/jp/us/sg via the iTunes lookup API; that a CN App Store search for "RoastMate" returns a different developer's app at rank 1 with 帮你骂 at rank 2, while a search for 「帮你骂」 returns it at rank 1; the same for 幫你罵 in HK and TW; the live remote config at jasonyeyuhe.github.io/RoastMate/roastmate-config.json (share_card_enabled false, share_card_setup_enabled false, share_card_visible true); and, via git cat-file against the v1.4.0 tag, that ShareCardBadge.swift shipped in the live build while ShareCardScenario.swift did not — which is what makes the badge a same-day remote flip and the setup chips a wait-for-review item.

---

# 5. Talking to 3–4 people

# P2.4 — Talk to 3–4 people

_Not 8. Eight will not happen. Three might — but only if the asks go out before the prep does._

---

## 0. Read this before you read anything else

**Tonight, before you edit a single file, send the ask in §1 to six people.** It takes eleven minutes. Everything else in this document is preparation, and preparation is the thing this project is good at. Four consecutive waves retreated into Xcode because Xcode is controllable; a research protocol is *also* controllable, and re-reading one is the same retreat in a different costume.

Send the asks. Then come back and read §2.

**One correction to P2.4's own wording first.** The plan says *"talk to 3–4 users."* There are no users. 23 first-time downloads lifetime; zero sessions, zero retention, zero purchases. The in-app recruit tile pointed at `roastmate.app`, an unregistered domain, in every shipped build since v1.0.5 — fixed in `05f305d`, which rides v1.5.0, which is in review now. There is no backlog and there was never a funnel.

So: **talk to 3–4 people who have the problem, not 3–4 people who have the app.** Expect 0 or 1 of the four to have installed it. That is fine and arguably better — the decisive question (§3) is answerable by someone who has never heard of RoastMate, and a stranger cannot flatter you about an app they have never seen.

Everything below assumes **4 conversations, 20 minutes each, no demo, no pitch.**

---

## 1. Tonight (11 minutes, no code, no prep)

Paste this into WeChat, to **six to eight friends**, one at a time. Not a group. Not friends you expect to be interested — friends with wide social graphs.

You are asking for an **introduction**, not for their opinion. A friend will spend twenty minutes telling you the app is cool. A stranger one hop away has no reason to, and still has enough social obligation to show up.

> 想麻烦你个事。
> 我那个 app 现在基本没人用，我想弄明白是我东西做得不对，还是压根就没这个需求。
> 想找三四个人聊 20 分钟。不聊我的 app，聊他们自己的事：上次被谁气到、有话憋在心里没说出口那种。
> 你身边有没有那种平时爱吐槽、憋屈了会在群里发长语音的？给我介绍一个呗。我不推销，也不用他们装什么东西。
> 他要是愿意，你把我微信推给他就行。

**Then stop for the night.** Do not open Xcode. Do not edit the form.

Write one line somewhere you will see it — a Note, the top of a scratch file, anywhere:

```
P2.4 clock started 2026-09-DD. Asks sent: 6. Day 30 = 2026-10-DD.
```

That date is the gate clock in §7. It starts on **the night you send the asks**, not on v1.5.0's approval. Apple's queue has nothing to do with whether four people will talk to you about being angry, and keying the clock to a date you do not control is how the clock never starts.

---

## 2. Where the other conversations come from

Ranked by realistic yield. Work down the list and stop at four.

### Channel A — Friends-of-friends
Already sent, in §1. This is the highest-yield channel you have and it costs one evening of messages. If two weeks pass with nothing, send a second batch to six different people rather than escalating to a harder channel.

### Channel B — Communities where the ICP already complains

Do **not** post a recruitment ad in a community you have never participated in. It gets deleted, and at your size a ban costs a channel you cannot replace.

Instead: find individual posts where someone is describing the exact moment, **reply usefully in public first**, then DM only the people who reply back to you. On 小红书 a cold DM from a non-mutual is throttled and reads as 推销 or worse; a DM to someone who just replied to your comment does not.

**Archetypes to look for** (patterns, not accounts to collect):
- Someone posting a screenshot of a 群 exchange asking 「我该怎么回？」
- Someone who wrote a long post at 1am about a boss / 相亲对象 / 亲戚 and ended with 「算了，不说了」
- Someone asking for wording help on a message they have already drafted five times
- Someone whose comment section is full of strangers writing suggested replies for them — **that comment section is the substitute your product competes with**

**Where to search:** 小红书 (highest density for this ICP), 豆瓣小组 (职场 / 吐槽 / 生活组), 即刻, Threads zh. V2EX skews en/tech — lower fit, deprioritize.

**Search strings, verbatim:** 「怎么回怼」「不知道怎么回他」「憋屈」「窝火」「破防」「意难平」「话到嘴边」「打了又删」「这条要不要发」「气到失眠」

Filter to the last 30 days. Recency beats engagement — you want someone who can still remember the moment.

**The public reply, before any DM.** One rule: it has to stand on its own. If they never speak to you again, that reply should still have been worth their while. No app name, no link, no 「我做了个东西」. A link in a first-contact DM is also the fastest way to get flagged on 小红书 — leave it out entirely.

**The DM, only to people who replied to you:**

> 打扰一下，我是刚在你那条底下回复的那个。
> 你写的那种情况我最近一直在琢磨，想问下你愿不愿意语音聊 20 分钟——就聊你自己遇到的事，我一句都不推销，也不用你装任何东西。
> 我一个人在做一个跟这个有关的小工具，没公司，纯粹想搞清楚这事到底有没有人真需要。
> 方便的话，周三晚上八点或者周六下午，你挑一个。不方便直接不用理我，真的没事。

**The last line is the whole mechanic.** At this scale interviews do not die from refusal; they die at 「好啊」 followed by three days of nobody proposing a time. Always name two concrete slots in the first message.

### Channel C — The in-app tile (passive; expect zero, but it now works)

I verified the plumbing this session, because the draft of this section assumed it and assumptions are how `roastmate.app` shipped dead for five versions:

- `jasonyeyuhe.github.io/RoastMate/research.html` and `research-book.html` — both **HTTP 200**
- The served `research.js` is **byte-identical** to `research/web/research.js` — the mirror workflow is live
- The recruit Worker is **deployed and validating** — an empty POST returns `{"error":"invalid_recency"}` / HTTP 400

So v1.5.0 is the first binary where 「付费 30 分钟用户访谈」 leads to a working form. **Do not wait on it** — a Settings tile against 23 lifetime downloads is a lottery ticket, not a channel. Check the KV once a week (§6 has the command).

**Two things about this tile the earlier draft got wrong or missed.**

**It sunsets 2026-11-01.** `SettingsView.researchRecruitDeadline` hides the section after that date, with no ship required. You have about seven weeks of tile, and then Channel C closes itself. That is a reason to not spend an evening optimizing it.

**You cannot quietly drop the compensation.** The promise lives in two places and only one is editable:

| where | text | editable now? |
|---|---|---|
| `research/web/research.js` | 「招募 **20 位**…报酬：免费 **1 年** RoastMate Pro 订阅」 | **yes** — static site, mirrored by `mirror-research-form-to-pages.yml`, not app code, not covered by the Phase 2 moratorium |
| `Shared/*.lproj/Localizable.strings` (all 4 locales) | `settings.research.tile` = 「**付费** 30 分钟用户访谈」 · footer = 「招募 **20 位**用户做 30 分钟的**付费**访谈」 | **no** — app code, frozen until the next binary |

Delete 报酬 from the page and you get a tile promising 付费 that lands on a page offering nothing. That is a worse state than either end. So: **keep the compensation, fix the count.** One edit to `STRINGS`, four locales:

> 我在找 **3–4 个人**聊 **20 分钟**，聊你自己遇到的事，不聊功能、不推销。
> 报酬：访谈结束后送你 **1 年 RoastMate Pro**（App Store 兑换码，不用给我任何个人信息）。
> 我一个人做的 app，没有公司。

Mint the code **after** an interview happens, for at most four people, not tonight — see §6 for why I am not certain the mint still works. `我一个人做的` is the line that converts at this scale, and it is true.

**Do this edit on the second evening, not the first.** It serves only Channel C, and Channel C is the one you expect nothing from.

### Channel D — App Store reviews: **closed, verified empty**

The research protocol lists "manual outreach to public App Store reviewers via the ASC review-response surface" as a recruiting channel. The public iTunes customer-review RSS for app id `6769317103` returns **no entries in cn, us, jp, tw, hk, or sg**. There is nobody to respond to. Cross it off; do not spend an evening confirming it a second way.

### Explicitly not now

- **TestFlight recruiting tied to compensation** — App Review 2.2 prohibits it. The protocol already decoupled this; keep it decoupled.
- **The protocol's Arm C** (10 non-users + 5 ja). That is the 20-person fantasy in a different coat. Four total.
- **Paying strangers ¥30 up front.** At n=4 that buys incentive-chasers. Offer nothing up front in Channels A and B; if someone gives you a genuinely useful hour, send a red packet afterward as thanks.
- **Asking anyone to install the app before the call.** They would burn three credits and hit a paywall — `DEV_PLAN_v1.6` P2.2 flags this as blocking creator outreach, and it applies here too. It also destroys the one advantage a stranger has: they cannot flatter you about something they have not seen.

---

## 3. The single most important question

> ## 「那句你憋着没说的话，后来发出去了吗？」

Ask it of everyone, installed or not. Everything else in §4 is context for interpreting the answer.

**Why this one.** The store pitch opens 「先骂爽，再说人话」. The product is a two-step machine: a private draft in 发泄 or 痛骂, then 「改成能发的」 turns it into 「可发送版」. That second step is half the app and all of the positioning — `paywall.feature.vent.detail` sells it in those exact words: 「先吐口恶气写出来，再让 AI 改成能发出去的版本。」

This question is the only one that tests whether that second step describes anything that happens in real life.

- **Consistently 没发** → the job is emotional regulation. 「改成能发的」, 「可发送版」, the paywall line, and the whole comeback framing are decoration on a venting toy. That reorders the ASO copy, the paywall, and every surface bet.
- **发了，改了四五遍** → the job is *writing a hard message*, and the vent modes are the on-ramp, not the point. Different keywords, different competitor — Notes and a friend, not other roast apps.

It works on someone who has never installed anything, which is essential, because ~0 of your four will be real users. The protocol already calls Destination "the single question that picks the entire product direction" — but phrases it as *"the last message RoastMate generated for you,"* which literally nobody alive can answer. Rephrasing it about **their own life** is what makes it askable at 23 downloads.

The follow-up 「那条草稿现在还在吗？」 is the cheapest high-value question in the script: a draft still sitting in Notes or an unsent WeChat input box is a person already doing your app's job by hand.

---

## 4. The conversation — 20 minutes, and it actually sums to 20

The earlier version of this script promised 20 分钟 in every outreach message and then ran 27. When you overrun, the thing you cut is the last question — which is the referral ask, which is the only mechanism that turns 4 into 6. So the timings below are real, and two blocks are marked protected.

Say the app's name **as late as possible** — ideally never, unless they installed it.

### 开场（1 分钟，逐字念）

> 谢谢你抽时间。开始之前先说三件事：
> 一，我不卖东西，今天不给你演示任何 app；
> 二，我不记你名字，笔记里你就是一个编号；
> 三，你说难听的对我最有用——夸我没用，纯浪费咱俩时间。
> 哪个问题不想答，直接说「跳过」，我不追问。
> 可以录音吗？不方便我就手打，一样的。

If they hesitate on recording, don't negotiate. Type.

### Block 1 — 那件事（5 分钟）

> 先说个最近的事：上一次有人惹到你、你心里有话但当时没说出口，是什么时候？

追问，一次一个：
- 「那天大概几点？」— a time anchor pulls out detail; 「一般什么时候」 pulls out a theory
- 「不用说是谁，说个关系就行——同事？家里人？」
- 「当时你人在哪儿，手里在干嘛？」

### Block 2 — 你当时干了什么（4 分钟）

> 那会儿你手机上开着什么？

- 「你有没有打了字又删掉？打了几遍？」
- 「这事你最后跟谁说了？」
- 「除了跟人说，你还干了什么让自己好受点的？」

### Block 3 — 结局（6 分钟）— **protected, never cut**

> 那句你憋着没说的话，后来发出去了吗？

- 没发 →「为什么没发？」→「现在回头看，你后悔吗？」
- 发了 →「发之前改了几遍？改的时候你在想什么？」→「发完什么感觉？」
- 两种都问：**「那条草稿现在还在吗？」**

### Block 4 — 假如有个东西（3 分钟）— 不演示，不描述你的 app

> 假设真有个 app 专门干这事。你会怎么跟朋友形容它？就一句话。

- 「你会去哪儿找？搜什么词？」— **write his words down verbatim**
- 「谁跟你说『这个你试试』，你才会真去装？」

### Block 5 — 只对装过的人（替换 Block 4，不是追加）

- 「你装了之后一共打开过几次？」
- 「上一次打开是想干嘛？」
- 「有没有哪次它给你的东西，你原封不动发出去了？」
- 「有没有哪次特别烂？烂在哪儿？」
- 「你是在 iPhone 上用还是 Mac 上？」
- 「你有没有注意到里面有一堆『风格』可以选？」

### 收尾（1 分钟）— **protected, never cut**

- 「今天我没问到、但你觉得我应该知道的，还有什么？」
- 「你身边还有第二个这样的人吗？也是憋着一肚子话那种。给我介绍一下呗，同样 20 分钟。」

**Ask the last one every single time.** It is the only way four becomes six.

**When you run long, cut in this order:** Block 4's second question, then Block 4 entirely, then Block 2's third question. Never Block 3. Never 收尾.

### 绝对不说的话

| 别说 | 为什么 |
|---|---|
| 「你觉得我们这个功能怎么样」 | 他会开始评价你，而不是回忆自己 |
| 「你会用吗 / 你会付费吗」 | 口头的未来行为等于噪音，写下来也没用 |
| 「对对对，我们就是这么想的」 | 你一附和，他就开始配合你 |
| 任何对产品的解释（Block 4 之前） | 一解释，剩下的谈话就变成了对你的礼貌 |
| 在他停顿时补话 | 数三下。停顿之后那句话通常是全场最有价值的 |

---

## 5. What to listen for — specific to this product

Write these down as **facts about what they did**, not impressions.

| Listen for | Why it matters here |
|---|---|
| **群 as the substitute** | `Scenarios.json` already carries a `groupchat` category (`groupchat_ignored`, `groupchat_screenshot`). If the reflex is 「把截图甩进闺蜜群」, your competitor is their friends — free, warm, instant, funnier than any model. That is a far harder competitor than another app. |
| **Which app they were in** | If the answer is WeChat, every Apple surface on the Fork B list (Share Sheet, iMessage app, keyboard, Safari extension) is structurally unreachable. That kills the largest remaining roadmap item without writing a line of code. |
| **The exact word for the feeling** | 憋屈 / 窝火 / 破防 / 意难平 / 不甘心 / emo. **Copy it verbatim, never paraphrase.** Whatever word recurs across four people is your ASO keyword — and the staged ASO metadata (`415d78f`) is currently a no-op waiting for exactly this input. |
| **Whether they wanted to send anything at all** | §3. This is the one. |
| **iPhone vs Mac** | macOS deploys to 14.0 while `AppleFMBackend` is 26+. On a Mac below 26, **every** 体面 / 锐利 / 狠 generation is curated text. A Mac interviewee may literally never have seen the model. Ask before you interpret 「它给的东西很泛」. |
| **Whether they noticed the styles at all** | 24 presets in `StylePresets.json` — **16 Pro-gated, 8 free** — across 5 intensities and 5 scenario categories. If nobody mentions styles, the combinatorial surface the strategic doc's §4 kill list already flags is confirmed dead weight. |
| **Discomfort with the name** | 「帮你骂」, a flame icon, an intensity literally called 痛骂. Strategic §5 flags "brand stuck on vent app" as a risk. If someone says 「这名字我不好意思推荐给人」, that risk just became a measurement — and it is a *distribution* kill, because at zero budget word-of-mouth is your only channel. |
| **Money they already spent** | Never ask 「你会付费吗」. Listen for what they *already pay for* — 陪聊, 情感咨询, 会员, 塔罗, therapy apps. Past payment is evidence; stated willingness is not. |
| **Where they stall** | The three seconds of silence before an answer is usually where the honest answer is. Note the pause itself. |

---

## 6. How to write it down

### Where

**Raw notes go OUTSIDE the repo.** `github.com/JasonYeYuhe/RoastMate-iOS` is **PUBLIC** — I confirmed this, don't take it on trust. A "recent conflict with my manager" narrative is identifying without a name. Use `~/Documents/RoastMate-research/`, mode 700, never committed — the same posture as the secrets directory.

Only a **scrubbed synthesis** goes in `docs/`: participants as `P01`–`P04`; no employer, no city, no job title, no vent text, no quote naming a relationship specific enough to identify anyone.

### One file per person, same headers every time

Identical structure is the entire point — four files with the same headers can be read side by side and grepped; four freeform files cannot.

```markdown
# P0N — 2026-09-DD — 20 min — zh-Hans — 渠道：朋友介绍 / 小红书 / app 内
装过 app：是 / 否   设备：iPhone / Mac / 都有

## 原话（他说的，一个字不改）
- 「…」
- 「…」

## 事实（他做了什么，不是他觉得什么）
- 事件时间：
- 当时在哪个 app：
- 打了字又删了：是 / 否，几遍：
- 最后跟谁说了：
- 发出去了吗：发了 / 没发 / 现在还是草稿
- 草稿还在吗：

## 他用的词
（憋屈 / 窝火 / …—— 逐字）

## 我的解读（明确标记，跟上面分开）
-

## 闸门读数
R1 有具体的一次（我没喂例子）：Y / N
R2 他自己动过手（打了字、删了、改了、发了、截图发群）：Y / N
R3 谈话中他主动要链接 / 问什么时候能用 / 说要发给谁：Y / N

## 我下次要改的问题
-
```

**Three readings, not four.** An earlier draft added "R4 — reopened the app unprompted." Drop it: you have no telemetry egress, so R4 can only be self-reported, and self-reported reopening from at most one installed user is noise. If someone genuinely comes back on their own they will tell you, and that is R3.

**The 原话 / 事实 / 我的解读 separation is load-bearing.** This repo's documented recurring failure is docs asserting things nobody verified — `roastmate.app` shipped dead for five versions on exactly that mechanism. Interpretation leaking into the quote column is the same failure at smaller scale, and it is why four-interview findings usually rot.

### Timing

Write the file **within 30 minutes of hanging up**, before the next thing. Do not plan to transcribe recordings — that is a second evening per interview and it will not happen. Type live; record only as a backup you probably never open.

### The rollup

One file, `docs/RESEARCH_FINDINGS_2026-09.md`:

| | P01 | P02 | P03 | P04 |
|---|---|---|---|---|
| 装过 app | | | | |
| 事件发生在哪个 app | | | | |
| 替代做法 | | | | |
| **发了 / 没发 / 草稿还在** | | | | |
| 他用的词 | | | | |
| R1 / R2 / R3 | | | | |

Under it, three sentences: what all four had in common, what surprised you, and **what you now believe that you did not believe last month.** If you cannot write the third sentence, the four conversations produced nothing — say that in the doc rather than mining them for a conclusion.

### What I did not verify — check these yourself before relying on them

1. **Whether the recruit KV holds anything.** The repo only carries namespace IDs in `research/worker/wrangler.toml`. To actually check:
   `npx wrangler kv key list --namespace-id 149e6fc75bbf4608a652290ff69d6ec6` (answers) and `... 2154ffa8f18f465abe92ff1b6c302da6` (contacts). Given zero sessions and a dead tile link in every shipped build, expect empty — but expecting is not knowing, which is the distinction this repo keeps losing.
2. **Whether subscription offer codes can still be minted** for `pro.yearly` via `POST /v1/subscriptionOfferCodes`. The protocol researched this path and believed it valid; nobody has executed it. **Do not promise a code you have not minted** — mint one for yourself first, redeem it, then put the promise on the page. If it fails, a red packet is an acceptable substitute and 付费 stays true.
3. **v1.5.0's exact review state.** Assume it is still in review until the ASC API says `READY_FOR_SALE`, and remember `READY_FOR_SALE` alone is not a discriminator — all 17 historical version records read that way.

---

## 7. The kill gate

### What the plan actually says (found)

`docs/PHASE_5_STRATEGIC_2026-09.md:293`, in the advisor-convergence table:

> **Kill list 30/90 rule, not 6 months.** Codex: freeze at 30 days clean telemetry, remove at 90. Gemini: 30 days.

Listed again at `:369` as a P1 priority — "**30/90 kill rule** instrumented in A′" — and applied at `:176–201` to the §4 kill list: the Watch app, the dormant keyboard skeleton, Argument Simulator, the 5×5×24 surface, the mainland SKU, ko/hi/es.

### Two problems with it, both fatal at this size

1. **It kills features, not the product.** There is no product-level kill rule anywhere in the strategic doc. Every gate in it assumes the app has users and asks which parts they ignore.
2. **It cannot fire.** It is keyed to A′ telemetry, which is opt-in, App-Group-local, and leaves the device only when a user manually taps Share Sheet. Zero sessions → zero exports → no telemetry, ever. And at 23 downloads a zero counter cannot distinguish "this feature is dead" from "this product has no users," so the rule silently resolves to *kill everything* — which is why it has never been applied to anything. `DEV_PLAN_v1.6` §3 reaches the same conclusion from the other end: "**Deliberately absent:** anything from `EventLedger` (no egress)."

### The version the conversations can feed

Same 30/90 shape — **freeze at 30, decide at 90** — with conversations as the input, because conversations are the only data source that exists at this scale.

**Clock starts the night you send the §1 asks.** Write the date down before the first call, not after the fourth. This project's documented failure mode is retreating into Xcode; a gate written *after* the data arrives will be written to fit the data.

**Day 14 — not a gate, a trigger.** If nobody has booked by then, send the §1 ask to six *different* people. That is the whole action. Do not redesign the script.

#### Day 30 — FREEZE gate

Freeze if **any** of these is true:

- **Fewer than 3 conversations happened, despite at least 12 asks having gone out.** The ask count is part of the condition so that "I didn't really try" cannot pass as "there's no demand." This is its own finding, and the harshest one: if one person cannot obtain three 20-minute conversations about a problem, one person cannot acquire users for a product that solves it.
- **R1 ≤ 1.** People could not produce a specific recent incident without you supplying the scenario. The pain isn't there, or isn't shaped like a message.
- **R1 is high but R2 = 0.** People get angry and never touch words — no draft, no delete, no rewrite, no screenshot. The app is aimed at a step that does not occur.

**FREEZE means:** the app stays live (hosting is effectively free — Groq is free-tier, OpenRouter is prepaid-capped), the kill-switches stay armed, and **no new code ships except crash fixes, safety fixes, and App Review compliance.** No new dev wave. The time goes somewhere else. Freezing is not failure; it is the only thing that stops the fifth consecutive retreat into Xcode.

#### Day 90 — decide

**ARCHIVE** if all four hold after the freeze: still zero purchases; impressions still flat against the 4,919 lifetime baseline; zero unprompted shares; and **R3 = 0** across every conversation held. Archive = stop spending attention. Leave it listed or pull it; that part is cosmetic.

**NARROW** if R1 and R2 are strong but §3's answer is lopsided:
- **0 of 4 ever sent anything** → the "sendable" half is not the product. Cut it from the **pitch** — store copy, screenshots, keywords, the paywall line — not from the code. Rewriting code is Xcode; rewriting a description is an evening.
- **All 4 sent something** → the venting theatrics are the on-ramp, not the product. Same edit, opposite direction.

**CONTINUE** only on positive evidence, and only these two count here:
1. Someone **asked for the link during a conversation** (R3) — behavior, unprompted, inside the call.
2. Someone **paid without being asked to.**

*(Impressions moving off 4,919 is a real signal but it belongs to P2.3's creator outreach, not to this section. Do not let it launder a failed P2.4 into a CONTINUE — and note that `DEV_PLAN_v1.6` already establishes per-creator attribution is unmeasurable at this size: detailed-report rows suppress below 5, and captured 0 of 197 lifetime page views.)*

#### Written down in advance, so future-you cannot cite it

**None of the following is counter-evidence to a kill:** 「这个想法挺好的」, 「我肯定会用」, 「你做得挺不错的」, a friend's enthusiasm, a feature suggestion, or your own sense that the conversation "went well." Every one of these will be said to you, probably by all four people, and none of them predicts anything.

**And state the asymmetry plainly in the doc:** four conversations **cannot prove the product works.** They can only kill it, or fail to kill it. That is the correct asymmetry for someone whose documented failure mode is building more — and it is exactly why four is enough.

> **What this section could not verify.** I read the code, the store copy, the catalogs and the plans directly. I did NOT independently verify anything requiring a live network call, and several claims below rest on facts handed to me or on documents rather than on a probe I ran:

1. The zero-responses fact (RESEARCH_ANSWERS: 0 keys, RESEARCH_CONTACTS: 0 keys) came from the task brief. I did not run wrangler against the production KV namespaces.
2. Whether the App Store listing has ANY written user reviews. Channel D in the section depends on this and I flagged it inline. It needs an ASC API read (or a look at the listing) before it can be counted as a channel — at 23 downloads it is quite possibly empty.
3. Whether any subscription offer codes have been minted for the "1 year of Pro" compensation the live form promises. Not queried via ASC. This is the single riskiest unverified item, because the promise is live on a page users can reach as soon as v1.5.0 ships.
4. v1.5.0's current App Review state. I took "in review right now" from the brief; the v1.6 plan and auto-memory have disagreed about ASC state before, and the plan itself documents that READY_FOR_SALE is not a discriminator.
5. Whether https://jasonyeyuhe.github.io/RoastMate/research.html currently serves the CURRENT research.html. Commit 05f305d asserts it returns 200 and the mirror workflow publishes it, but I did not fetch the page, and the mirror Action has failed silently before (95ea05c fixed exactly that class of bug on the config mirror).
6. Whether roastmate-research.yyyyy-yeyuhe.workers.dev is up and accepting POSTs. If the form 500s, every channel in §2 that routes through it is dead and nobody will tell you.
7. Community-channel specifics (which 小红书/豆瓣 search strings actually surface the archetypes today). I produced search CRITERIA, per the constraint against naming real accounts, and did not run any searches or verify current platform behavior. The claim that Xiaohongshu weights Saves > Comments > Likes comes from DEV_PLAN_v1.6 P2.3, not from me.
8. No statistics are invented anywhere in the section. Every number in it (4,919 / 197 / 23, 24 styles, 14 Pro-gated, 10 scenarios in 5 categories, ¥21/¥138, $2.99/$19.99, macOS 14 vs FM 26+) is read from the repo or the brief. Where I had no number — expected yield per channel, response rates, how many conversations a DM produces — I said so rather than estimating.
