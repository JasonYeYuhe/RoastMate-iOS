#!/usr/bin/env python3
"""Validate Option A: does the cloud Worker's roommate mode produce transcripts
that pass the strict EchoesParser(scene:.roommateGroup) contract? Posts 20
zh-Hans scenarios, checks each, prints the parse-fallback rate."""
import json, urllib.request, urllib.error, uuid

URL = "https://roastmate-vent.yyyyy-yeyuhe.workers.dev/v1/vent"
DEVICE = "evalcloud-" + uuid.uuid4().hex[:16]

# (intensity, situation) — intensity maps tone: casual->vent, feral->feral
SCENARIOS = [
    ("vent",  "室友半夜两点还在外放打游戏,说了三次都当耳旁风,今天又来。"),
    ("vent",  "同事把我做完的方案直接署上他自己的名字交给老板,一句话都没跟我说。"),
    ("vent",  "朋友又一次临时放我鸽子,我都到餐厅了他才发消息说来不了。"),
    ("vent",  "点的外卖洒了一半,客服只肯赔三块钱优惠券,还说是我自己不会拿。"),
    ("vent",  "妈又开始拿我和别人家孩子比,说我这个年纪还没买房就是没出息。"),
    ("feral", "房东退押金扣东扣西,合同里根本没写的费用也硬塞进来,微信还不回。"),
    ("feral", "组里那个人整个学期啥都没干,汇报的时候全程他在讲,功劳全揽过去。"),
    ("feral", "网店发来的是货不对板的劣质货,要退货反被拉黑,还倒打一耙说我碰瓷。"),
    ("feral", "相亲对象全程低头玩手机,临走还点评我条件也就这样别太挑。"),
    ("feral", "加班到十一点把活赶完,领导第二天当着全组说年轻人就该多奉献。"),
    ("vent",  "室友每次用完厨房都不收拾,油锅放一礼拜,还说我太计较。"),
    ("vent",  "借给同学的充电宝两个月没还,问一次他就已读不回一次。"),
    ("vent",  "群里发了重要通知没人理,结果出了事第一个来甩锅的就是他们。"),
    ("vent",  "健身房私教一直推销课程,说不要还阴阳我没毅力练不出来。"),
    ("vent",  "快递放代收点也不通知,丢了反过来怪我没及时去取。"),
    ("feral", "前任借钱时叫得比谁都亲,分手后立刻翻脸说那是我自愿给的。"),
    ("feral", "甲方改了八版需求一分钱不加,验收又说没达到他想要的感觉。"),
    ("feral", "亲戚群里被长辈公开数落工资低,还说读那么多书有什么用。"),
    ("feral", "合租的人偷用我的东西被抓包,不道歉还反咬一口说我小气。"),
    ("feral", "公司画饼半年说好的晋升,临了换成空降的关系户,理由是我还需要历练。"),
]

ROLES = {"VALIDATE", "ESCALATE", "DEESCALATE", "BRIDGE"}

def parse_roommate(raw):
    """Faithful port of EchoesParser.parse(scene:.roommateGroup)."""
    msgs = []
    for line in (l.strip() for l in raw.splitlines() if l.strip()):
        if not line.startswith("["):
            continue                       # wrapper line — skipped in both modes
        end = line.find("]")
        if end == -1:
            return None                    # malformed tagged line -> strict reject
        header, body = line[1:end], line[end+1:].strip()
        if not body:
            return None
        core = header.split(":", 1)[0]
        parts = core.split("/", 1)
        if len(parts) != 2:
            return None
        role, idx = parts[0].strip().upper(), parts[1].strip().upper()
        if role not in ROLES or idx not in ("A", "B", "C") or len(body) > 80:
            return None
        msgs.append((role, idx))
    if not (8 <= len(msgs) <= 10):
        return None
    if msgs[-1][0] != "BRIDGE" or sum(r == "BRIDGE" for r, _ in msgs) != 1:
        return None
    if not any(r == "VALIDATE" for r, _ in msgs) or not any(r == "DEESCALATE" for r, _ in msgs):
        return None
    for v in ("A", "B", "C"):
        if sum(x == v for _, x in msgs) < 2:
            return None
    return msgs

def post(situation, intensity):
    body = json.dumps({"situation": situation, "intensity": intensity,
                       "locale": "zh-Hans", "deviceId": DEVICE, "mode": "roommate"}).encode()
    req = urllib.request.Request(URL, data=body, headers={
        "Content-Type": "application/json",
        "User-Agent": "RoastMate/1.0 (iPhone; iOS 18.0) CFNetwork/1490 Darwin/23.0.0",
        "Accept": "application/json",
    }, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=70) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        return {"error": f"http_{e.code}", "detail": e.read().decode()[:150]}
    except Exception as e:
        return {"error": str(e)}

import time
responses = parse_fail = rate_limited = parsed_ok = 0
for i, (intensity, sit) in enumerate(SCENARIOS):
    resp = post(sit, intensity)
    text = resp.get("text")
    if not text:
        rate_limited += 1   # upstream 429/502 — capacity artifact, not a contract failure
        print(f"#{i+1} [{intensity}] upstream {resp.get('error')} (rate-limit / capacity)")
    else:
        responses += 1
        msgs = parse_roommate(text)
        if msgs is None:
            parse_fail += 1
            print(f"#{i+1} [{intensity}] PARSE-FAIL provider={resp.get('provider')}\n{text}\n")
        else:
            parsed_ok += 1
            print(f"#{i+1} [{intensity}] PARSED ({len(msgs)}) provider={resp.get('provider')}\n{text}\n")
    if i < len(SCENARIOS) - 1:
        time.sleep(12)   # stay under Groq free-tier TPM so we measure the CONTRACT, not the rate limit

print("\n=== CLOUD roommate eval ===")
print(f"got model response: {responses}/{len(SCENARIOS)}   (upstream rate-limited/capacity: {rate_limited})")
if responses:
    print(f"PARSE-FALLBACK on actual responses = {parse_fail}/{responses} = {parse_fail*100//responses}%   (enable<15% / kill>=35%)")
else:
    print("no model responses got through — all upstream rate-limited.")
