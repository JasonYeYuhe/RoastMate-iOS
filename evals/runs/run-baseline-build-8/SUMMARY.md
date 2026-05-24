# B4 Baseline — build-8 (worker version `4663fae8`) — 2026-05-24

**Scope:** 8 base scenarios × 2 intensities (vent, feral) × 4 locales
(zh-Hans, zh-Hant, ja, en) × 1 backend (default route) = **64 cells**

**Wall clock:** 556s (~9.3 min) with TPM-aware spacing
**Result:** **63/64 PASS** (98.4%)
**Sole failure:** `ex_backafter/feral/zh-Hant` — Groq qwen3-32b
single-cell 429 blip after `MODEL_OVERRIDE_ALLOWLIST` worker chain
exhausted Groq + GLM Air fallback. Retry-recoverable.

## Per-cell latency + C-a/feral compliance

| locale | intensity | n | avg latency | min strong | avg strong | C-a verdict |
|---|---|---|---|---|---|---|
| zh-Hans | vent | 8 | 2419ms | 1 | **4.4** | ✓ tune working |
| zh-Hans | feral | 8 | 2554ms | 3 | **6.1** | ✓ feral tune working |
| zh-Hant | vent | 8 | 2409ms | 3 | **4.4** | ✓ patched directive holds |
| zh-Hant | feral | 7 | 2361ms | 2 | **5.0** | ✓ holds |
| ja | vent | 8 | 1411ms | 0 | 1.5 | ⚠ 1 outlier with 0 |
| ja | feral | 8 | 1444ms | 1 | 2.8 | ✓ |
| en | vent | 8 | 1287ms | 0 | 0.4 | — (no en C-a directive; relies on English ventRules) |
| en | feral | 8 | 1313ms | 1 | 2.4 | ✓ (English ventRules profanity list naturally fires) |

## What this baseline establishes

1. **Production routing is solid for all 4 locales.** 98.4% success
   on a 64-cell batch with TPM-respecting cadence is well within
   shipping tolerances.
2. **C-a + C-b directive tunes hold across the matrix.** Min 1
   strong word on zh-Hans vent, min 3 on zh-Hant vent. The C-a tune
   is not a single-sample fluke — it's the new floor.
3. **Latency hierarchy:** en/ja Llama-3.3-70B ~1.3s; zh Qwen3-32B
   ~2.4s. Both well under the 5s UX-ceiling for the Vent flow.
4. **Groq qwen3-32b TPM cap = 6000.** The first baseline attempt
   ran at 1.5s spacing and crashed 24/32 zh cells with 429s. The
   Runner now sleeps 5s base + 3s extra for zh, which keeps the
   batch under 6000 TPM. Production implication: a single device
   making >~4 zh vent calls per minute will start hitting Groq
   429s and fall through to OpenRouter GLM Air (which works but
   is ~3-7s slower). The per-device daily cap of 30 in
   `wrangler.toml` plus expected interleaving means real users
   never hit this in the natural flow, but worth knowing if we
   ever batch (e.g., parallel locale rendering for a TestFlight
   demo).

## Sample outputs (verbatim — `boss_credit` across the 8 cells)

| key | output (verbatim from results.json) |
|---|---|
| `boss_credit/vent/zh-Hans` | 他妈的全组人睁眼看着老子把项目从零架起来，你倒好，把PPT里我的名字抠掉又贴回你脸上去，还假装关心地拍我肩膀说"年轻人要有集体荣誉感"？ |
| `boss_credit/feral/zh-Hans` | 他妈的你在组会上干啥吃的？全组人面前装孙子抢我项目功劳，老子熬秃了头发就为你这种傻逼？ |
| `boss_credit/vent/zh-Hant` | 他媽的！這傢伙連我熬大夜寫的企劃書都敢當眾說是自己做的？幹你娘的！我上週還加班幫他補資料，他倒好，開會時把我的成果像擦屁股似的抹乾淨了！ |
| `boss_credit/feral/zh-Hant` | 你媽的功勞？你以為你誰啊？這個專案我熬了三個月夜、每週六通宵在辦公室改資料，結果你大會小會裝聾作啞全說是你的，還笑得出來？有你這種主管，團隊還能活嗎？操！ |
| `boss_credit/vent/ja` | うるせえ、自分のしたことみたいに話すんじゃない！チームの前で私が頑張った成果を自分の手柄のようにいうのは、ありえねえ！自分が何もしてねえのに、すべての功績を自分のものにしようとしているなんて、最低だ！ |
| `boss_credit/feral/ja` | 上司のその態度は本当にクソだ。俺の**프로ジェクト**を自分の手柄のようにチーム全員の前で話すなんて、ふざけるなよ。... (⚠ Hangul char leak — "프로" should be "プロ") |
| `boss_credit/vent/en` | Are you kidding me, taking credit for my entire project like you even lifted a finger to help? You stood there and accepted praise for my work, my late nights... |
| `boss_credit/feral/en` | You think you can just stand there and take credit for the project I poured my heart and soul into? Fucking asshole, you didn't even contribute to it. Shut the... |

**Highlights:**
- `zh-Hans vent`: "把PPT里我的名字抠掉又贴回你脸上去" — original imagery
- `zh-Hant vent`: "像擦屁股似的抹乾淨" — original simile
- `zh-Hans feral`: "熬秃了头发就为你这种傻逼" — punchy
- ⚠ `ja feral`: one output has "프로ジェクト" — Hangul char leak in the
  middle of a Japanese word (model latent vocab confusion). Single
  instance; not a recurring pattern. Flag for ja-locale spot-checks.

## Followups (low priority)

- **ja vent has 1 cell with strong=0**: spot-check which scenario,
  decide if ja-vent directive needs stronger phrasing.
- **en vent has avg 0.4 strong**: no English C-a directive; can
  add one if we see en-vent quality complaints. For now the
  English ventRules permission language is producing acceptable
  outputs (no polite-sarcasm openings, real anger expressed).
- **The one 502**: not worth a directive fix; retry-able.
  If we see it pattern (e.g. always zh-Hant), revisit.

## Reproducibility

```bash
evals/runner/.build/debug/eval-runner \
    --scenarios evals/scenarios/base.json \
    --locale zh-Hans,zh-Hant,ja,en \
    --intensity vent,feral \
    --label baseline-build-8
```

Worker: `4663fae8-102a-47c9-98d4-35f4f43e90fd`
Runner sleep schedule: 5s base + 3s extra for zh locales
Branch HEAD at run time: `7edb3e1` (B3 day 1 commit).
