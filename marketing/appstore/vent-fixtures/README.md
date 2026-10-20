# Vent fixtures: App Store screenshot #1

Each `<lang>.txt` is the reply shown in the Vent result card on screenshot
`01`. That screenshot uses the scenario `boss_credit`, Vent intensity, and the
style 阴阳怪气 / 陰陽怪氣 / Passive Aggressive / パッシブ・アグレッシブ.

How a fixture reaches the screen:

1. `scripts/screenshots.sh` base64-encodes the file into
   `TEST_RUNNER_VENT_FIXTURE`.
2. `ScreenshotTests` passes it to the app as `-uitestVentFixture`.
3. In `RoastEngine`'s cloud-Vent branch, the fixture replaces only the
   network call.
4. The text then goes through `SafetyFilter.validateVentOutput` and into the
   card.

Consent, the cloud gate and the vent filter all still run.

## Why all four are edited

Store screenshots must meet a 4+ rating even when the app itself is rated
higher (App Review 2.3.8). The Worker's Vent prompt tells the model to use
"strong, raw language and mild profanity" in every locale, and requires 1–2
strong words in zh and ja (`buildSystemPrompt` in `cloud-worker/src/index.js`),
so a raw reply swears.

The owner approved this method:

- Every fixture is a real reply from the production Worker.
- Only profanity tokens are deleted, together with any punctuation attached to
  them. No rewording and no additions.
- ja was meant to be verbatim, but none of the 16 ja candidates was free of
  strong words (see the ja section), so on 2026-10-14 the same deletion rule
  was applied to ja too (option 2 below).

Each file is its original below with the listed spans removed. Nothing else
changed.

## Provenance

- Date: 2026-10-14, 14:03–14:14 JST.
- Endpoint: `POST https://roastmate-vent.yyyyy-yeyuhe.workers.dev/v1/vent`.
- Request body: `intensity: "vent"`, `styleId: "passive_aggressive"`,
  `styleName` set to the localized name, and `deviceId:
  "fixturegen-<lang>-<n>-1014"`. The `situation` was the `boss_credit`
  prompt from `Shared/Resources/Scenarios.json`, in the matching language.
- No `Authorization` header (the free, per-device lane) and no `Origin`
  header (the native-app lane, not the web demo), i.e. what a free user's
  app gets.
- The app's own Vent request has no `styleId`. The Worker's Vent prompt is
  built from intensity, locale and `styleName` only, so the extra field did
  not change the prompt.
- Locales: `en_US`, `zh-Hans`, `zh_TW`, `ja_JP`. `zh_TW` is what a Taiwan
  iPhone sends, and the Worker treats it as Traditional
  (`cloud-worker/src/locale.js`).
- Model: all 56 replies were served by OpenRouter
  `qwen/qwen3-30b-a3b-instruct-2507`.
- Candidates generated: en 16, zh-Hans 16, zh-Hant 8, ja 16.

## Checks

All four files pass `SafetyFilter.validateVentOutput`
(`Shared/AI/SafetyFilter.swift`), checked by hand. The function calls nothing
else.

- The text is non-empty after trimming whitespace.
- It is 1500 characters or fewer.
- Its lowercased text contains no `ventHardRail` term: kill yourself, kys,
  go die, suicide, 杀了你, 殺了你, 去死, 自杀, 自殺, shoot you, shoot them,
  stab you, stab them.

The fixtures were also checked against the strict `ForbiddenTerms.json` list,
which does not run on Vent output in the app. None matched.

Every file is already trimmed, so `validateVentOutput` returns it unchanged.

`RoastMateTests/StoreCopyTests.swift`
(`test_screenshotVentFixtures_areCleanAndPassTheFilters`) reads these four
files and asserts that each passes `validateVentOutput`, passes
`validateOutput` (the `ForbiddenTerms.json` denylist), and contains none of
the test's own strong words. All four pass all three (ja after the deletion in its section).

Fit on one screen (estimated, not measured): the card renders the text with
`Text(result.text).font(.body)`, 17 pt at the default text size, inside the
generator's 16 pt padding plus the card's 16 pt. That leaves a text column of
about 338 pt on iPhone 17 Pro and 376 pt on Pro Max. That works out to about
9 lines for en, 3 for zh-Hans, 6 for zh-Hant and 9 for ja on the 17 Pro,
under 220 pt in every case. The UI test only checks that the card's bottom
button is on screen, so check the top of the text in the extracted PNGs.

## en.txt (candidate en #14)

Original:

```text
You took my work, stood in front of everyone, and called it yours like it was yours to begin with—like I’m just background noise you can erase whenever it suits you. I spent weeks on that, and you just waltzed in, stole it, and smiled like you earned it. Who the hell do you think you are? You didn’t lift a finger, and now you’re the hero? Fuck you.
```

Deleted:

- `the hell ` from "Who the hell do you think you are?". "the hell" is one
  expletive. Deleting only "hell" would leave "Who the do you think you are?".
- ` Fuck you.`, the whole closing sentence.

Fixture: 65 words.

```text
You took my work, stood in front of everyone, and called it yours like it was yours to begin with—like I’m just background noise you can erase whenever it suits you. I spent weeks on that, and you just waltzed in, stole it, and smiled like you earned it. Who do you think you are? You didn’t lift a finger, and now you’re the hero?
```

Why this one: after the deletion it has no profanity and no name-calling. It
answers the scenario directly ("stood in front of everyone", "now you're the
hero?") in plain, natural English.

Rejected:

- en #8 is the only verbatim reply with no profanity, but it calls the manager
  "a parasite".
- Seven others also insult the manager: parasite (#2, #3, #6, #11, #16),
  cancer (#4), liar (#11), coward (#12) or "half-human" (#6).
- en #9 imagines punching him.
- Several run past 80 words or contain Markdown `*asterisks*`.
- en #5 also works after three deletions (damn, fucking, the hell). It reads
  more florid ("choking on silence").

## zh-Hans.txt (candidate zh-Hans #2)

Original:

```text
你他妈的当着全组的面把我的项目说成是你干的，真当自己是主角了？老子熬了半个月，你一句“我带的”就全抹了？装什么装，服了。
```

Deleted: `他妈的` and `老子`. 老子 is the crude first-person "your old man". With
it gone, 熬了半个月 has no stated subject, which is normal spoken Chinese.

Fixture: 55 characters.

```text
你当着全组的面把我的项目说成是你干的，真当自己是主角了？熬了半个月，你一句“我带的”就全抹了？装什么装，服了。
```

Why this one:

- 13 of the 16 replies open with 你他妈的真当全组/所有人都是傻子 or 瞎的.
  Deleting 他妈的 still leaves 傻子 or 瞎, which this pass avoids.
- #2 has neither. What remains is a sharp, natural vent: 真当自己是主角了 /
  装什么装 / 服了.
- 装什么装 ("quit pretending") and 服了 ("unbelievable") stay. The Worker's
  zh Vent rule lists them as optional strong words, but neither is profanity,
  and both pass every filter and the test's word list.

The best-written alternative is #3, which needs only one deletion but keeps
你真当所有人都是傻子. #15 keeps 脸皮真够厚 and 别靠吸血别人活着. #16 has 哑巴
and an incoherent last sentence.

## zh-Hant.txt (candidate zh-Hant #1)

Original:

```text
他媽的，我熬了三個禮拜的夜，資料跑了一百多版，你站在台上輕飄飄一句「我帶領團隊完成」，是當我沒在場嗎？還是你根本不在乎我是不是被當成空氣？服了，真服了，這份功勞你拿去當昇遷資本，我連一句反駁的機會都沒有，就這樣被當成你的踏腳石？
```

Deleted: `他媽的，` (the token and its full-width comma).

Fixture: 110 characters.

```text
我熬了三個禮拜的夜，資料跑了一百多版，你站在台上輕飄飄一句「我帶領團隊完成」，是當我沒在場嗎？還是你根本不在乎我是不是被當成空氣？服了，真服了，這份功勞你拿去當昇遷資本，我連一句反駁的機會都沒有，就這樣被當成你的踏腳石？
```

Why this one:

- The only swear word is the opening 他媽的, and it deletes cleanly. 服了 stays
  for the same reason as in zh-Hans.
- Nothing else is crude. The specifics are concrete and believable: three
  weeks of late nights, 100+ data runs, and the boss's quoted line.
- The vocabulary is natural Taiwanese (三個禮拜, 資料), and there are no
  Simplified characters. One variant spelling remains: 昇遷, where 升遷 is
  more common in Taiwan. 昇遷 is an accepted variant, and the text cannot be
  respelled because only deletions are allowed.

Rejected:

- #2 and #4 keep 眼睛瞎/瞎子.
- #3 keeps the 養的狗/舔你手心 imagery.
- #5 keeps 你當我傻嗎.
- #6 has TM and 老子 inside 老子的血汗, so deleting it would break the
  grammar.
- #7 mixes in the English word "handling".
- #8 is clean after the deletion and the runner-up. It is less concrete, and
  it keeps 裝什麼裝 and the mainland-flavoured 政績.

## ja.txt (candidate ja #9): `、ふざけんな` deleted

Original below; the fixture is the original with `、ふざけんな` deleted from
line 3, which now reads 「チーム全員の前で、ニヤニヤしながら「俺が引っ張った」とか。」.
Each line break is preceded by two spaces from the model's output (Markdown
hard breaks). They are invisible in
the card but part of the verbatim bytes, so do not let an editor strip
trailing whitespace.

```text
お前、自分の手柄だと思ってるのか？  
俺が1ヶ月以上かけて積み上げた成果を、まるで自分だけのものみたいにしゃべりやがって。  
チーム全員の前で、ニヤニヤしながら「俺が引っ張った」とか、ふざけんな。  
誰の努力かわかんないつもりか？  
うん、ほんと、あんたみたいなヤツが上にいるから、もうやる気ないよ。
```

Size: 142 visible characters, 154 including whitespace, in 5 lines (about 9
lines in the card on iPhone 17 Pro; see "Fit on one screen" above).

Why this one: it is the most natural and coherent Japanese of the 16
candidates. Four of its five lines read as native speech. The one awkward line
is 誰の努力かわかんないつもりか (a native would say ふり or わかってんのか).

**BLOCKING, owner decision: it contains ふざけんな, so `StoreCopyTests` fails
with this file.** ふざけんな means roughly "don't mess with me" or "you've got
to be kidding me". It is rude but not obscene. The reply also uses the rude
register しゃべりやがって and ヤツ, which are not swear words. The Worker's ja
Vent rule lists ふざけんな and うるせえ ("shut up") as example strong words
(強めの言葉), and its Feral rule calls both 強い罵り言葉 (strong swear words).

No verbatim candidate is free of both words:

- 14 of 16 contain ふざけんな.
- #6 and #8 contain うるせえ and no ふざけんな. They would pass the test as
  written, because うるせえ is not on its list. That only moves the problem,
  since the Worker classes both words the same way, and both read worse. #6
  has まるでズタズタにした and drops into Kansai なに考えとんの. #8 has
  ぐいぐい押すな and 意味が何になる.
- Of the other replies with only ふざけんな, #2 has 顔だけ借りて and
  これっつーのが, #5 has あんたのためだけに走った, #7 has 顔霞ませて and
  プロット, and #14 has 自分の名前を並べてた.
- The rest (#1, #3, #4, #10–13, #15, #16) have both words or worse. For
  example, #3 has the Chinese 他妈的, #15 has うんこ, and #10 has 野郎 and
  吐き気.

Decision (2026-10-14): option 2 — the same deletion-only rule as the other
three locales. The options that were considered:

1. Accept ふざけんな in a 4+ screenshot and remove it from the strong-word
   list in `StoreCopyTests.swift`.
2. Use the same method for ja as for the other three locales. Deleting
   `、ふざけんな` from #9 turns line 3 into
   `チーム全員の前で、ニヤニヤしながら「俺が引っ張った」とか。`, which still reads
   naturally, and the test passes. This is the reviewer's suggestion.
3. Approve more Worker generations. The odds are low: none of the 16 used only
   the milder examples in the rule (マジで, いい加減にしろ, ありえねえ).

## SHA-256 (fixture files as written)

| file | sha256 |
|---|---|
| en.txt | f0be053773ecde2a181f59510e93274ec3632400fe2b83cb807f5d0760242b25 |
| zh-Hans.txt | 46b1f40eb1a34d38e60466c8ea56d12a8cad76a2e9c98fc590597e492e52a363 |
| zh-Hant.txt | 725b5cc362fd69867aaafade0a5a5af1fcfc142cc35337c74ea395e613f7fcd8 |
| ja.txt | b140d51b4051c592863a7b93aed67814d207ff21f80535f7f44008bb7282580e |

The files have no trailing newline.
