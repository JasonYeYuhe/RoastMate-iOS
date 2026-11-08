#!/usr/bin/env python3
"""Read-only payer read for DEV_PLAN_v1.8 §2.3 (weekly signals and the 2027-01-31 read).

Sources. Only reports Apple keeps for about a year are used for counts, because
Analytics DAILY instances expire after about 35 days:
  - Sales SUBSCRIPTION_EVENT (daily) for subscription events. Fetched through
    TODAY, not just through --to, because a Cancel or Renew row for a start in
    the window is written when that start's period ends, which can be after
    --to;
  - Sales SALES (daily) for first-time units (Product Type 1, 1F, 1T, F1), the
    §2.3 denominator, counted inside the window only. Checked 2026-11-08: it
    matches Analytics first-time downloads day for day where both exist. The
    vendor-wide SALES report has rows almost every day (six apps), so its
    latest day also says how far the data reaches;
  - the local log ~/Documents/RoastMate-research/retention-messaging-log.tsv,
    which scripts/weekly_readout.py fills each week from the Analytics
    "Retention Messaging" report (r320) before Apple drops it. Apple's fields:
    Date, App Apple Identifier, Current Subscription, Event ("Page views",
    "Cancels", "Saves"), Page, Retention Message Type, Device, Platform Version,
    Territory, Counts.

Rules, as §2.3 states them. Everything is counted in subscribers (Quantity),
not rows, because Apple folds identical events into one row:
  new start   = "Subscribe" or "Start Introductory Offer" (paid or free trial)
                with Event Date and Original Start Date inside the window.
                Listed but NOT counted: "Start Offer Code" (free creator codes),
                "Start Promotional Offer", "Opt-In", any "Reactivat*",
                crossgrades and upgrades. Whether those count is Jason's call if
                one ever appears.
  cancelled within 3 days, per start (Original Start Date, Country,
  Subscription Name):
    - "Cancel" rows in the first period (Consecutive Paid Periods 1) with Days
      Before Canceling <= 3 (their Quantity). Apple
      dates the Cancel row at the END of the paid or trial period; Days Before
      Canceling counts from the start to the tap on cancel. The TW 2026-09-20
      start has a Cancel row dated 10-20 with Days Before Canceling 0: it
      cancelled on day 0;
    - refund rows dated <= 3 days after the start (for one key, the larger of
      the refund and Cancel counts, since one subscriber can have both; later
      refunds are noted on the start's line);
    - "Cancel" rows with Days Before Canceling > 3 count as kept;
    - for the rest: if the first period has ended (with a day's margin) by the
      day the data reaches, kept. Otherwise r320 "Cancels" rows for the same
      territory (and subscription, when the row names one), dated -1..+3 days
      from the start, count as cancelled PROVISIONALLY: each r320 cancel is
      credited once (earliest start first), and because r320 can't say which
      subscriber cancelled, the verdict's best case treats it as kept until the
      start's own Cancel row or period end settles it. r320 dates follow a different day
      boundary from Sales: the TW day-0 cancel is dated 09-19 in r320 and the
      start 09-20 in Sales. Anything left is "unknown" until the period ends,
      and the verdict is computed both ways.
  second paid period = a paid-period row ("Renew*", "Paid Subscription from*",
                "Crossgrade*", matched across a product change for crossgrades)
                dated inside the window with Consecutive Paid Periods >= 2 for
                a paid start, or >= 1 for a free-trial start (the trial
                converting, also via billing retry); capped at the start's
                Quantity.

  SUCCESS needs all three: >= 3 starts, >= 2 not cancelled within 3 days,
          >= 1 reaching a second paid period.
  KILL if <= 1 start, or every start cancelled within 3 days.
  Otherwise IN BETWEEN.
  Under 40 first-time units in the window, the verdict is labelled
  "traffic-limited"; the consequences in §2.1 do not change.
  If unknown starts could change it: "VERDICT UNDETERMINED", with the date the
  last unknown resolves.

Starts are tied to later events by (Original Start Date, Country, Subscription
Name), because the report has no subscriber id. Two subscribers who share that
key are told apart only by the Quantity of their later rows; a "shared key" note
is printed when a key holds more than one subscriber.

Nothing is written anywhere. Run from the repo root:
  python3 scripts/payer_read.py --from 2026-11-05 --to 2027-01-31
Exit status 2, and no VERDICT line, if any report day failed for a reason other
than 404. A 404 means the day has no rows or is not published yet.
"""
import argparse
import csv
import datetime as dt
import gzip
import io
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.dont_write_bytecode = True  # no __pycache__ in the repo from scheduled runs
sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc_analytics as A  # noqa: E402  (token())

APP_ID = "6769317103"  # never from $ASC_APP_ID: that may be another app
VENDOR = "94126306"
FIRST_TIME_PTI = {"1", "1F", "1T", "F1"}
COUNTED_STARTS = {"Subscribe", "Start Introductory Offer"}
R320_LOG = Path.home() / "Documents" / "RoastMate-research" / "retention-messaging-log.tsv"


def day_range(a: dt.date, b: dt.date):
    d = a
    while d <= b:
        yield d
        d += dt.timedelta(days=1)


def fetch_day(tok: str, report_type: str, day: dt.date, versions):
    """Rows for one daily Sales report: (rows, status), status "ok", "none" (404) or "failed"."""
    for ver in versions:
        url = ("https://api.appstoreconnect.apple.com/v1/salesReports?filter[frequency]=DAILY"
               f"&filter[reportDate]={day.isoformat()}&filter[reportSubType]=SUMMARY"
               f"&filter[reportType]={report_type}&filter[vendorNumber]={VENDOR}&filter[version]={ver}")
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {tok}",
                                                   "Accept": "application/a-gzip"})
        wrong_version = False
        for attempt in range(3):
            try:
                raw = urllib.request.urlopen(req, timeout=60).read()
                rows = list(csv.reader(io.StringIO(gzip.decompress(raw).decode()), delimiter="\t"))
                return [{k: v.strip() for k, v in zip(rows[0], r)} for r in rows[1:]], "ok"
            except urllib.error.HTTPError as e:
                if e.code == 404:
                    return [], "none"
                if e.code in (400, 410):
                    wrong_version = True
                    break
                time.sleep(2 * (attempt + 1))
            except (urllib.error.URLError, TimeoutError, OSError):
                time.sleep(2 * (attempt + 1))
        if not wrong_version:
            return [], "failed"
    return [], "failed"


def duration_days(text: str) -> int:
    m = re.search(r"(\d+)\s*(day|week|month|year)", (text or "").lower())
    if not m:
        return 31
    n, unit = int(m.group(1)), m.group(2)
    return n * {"day": 1, "week": 7, "month": 31, "year": 366}[unit]


def r320_cancel_rows():
    """Rows of the local r320 log whose Event is "Cancels": dicts with date, territory, subscription, count."""
    out = []
    if not R320_LOG.exists():
        return out
    with R320_LOG.open() as f:
        for line in f:
            parts = line.rstrip("\n").split("\t", 1)
            if len(parts) != 2 or not parts[1].startswith("{"):
                continue
            row = json.loads(parts[1])
            if (row.get("Event") or "").strip().lower() != "cancels":
                continue
            n = int(row.get("Counts") or 0) if re.fullmatch(r"\d+", row.get("Counts") or "") else 0
            date = (row.get("Date") or "")[:10]
            if n > 0 and re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
                out.append({"date": date, "territory": row.get("Territory") or "",
                            "subscription": (row.get("Current Subscription") or "").strip(), "count": n})
    return out


def collect(tok: str, lo: dt.date, hi: dt.date, today: dt.date) -> dict:
    """Everything §2.3 needs for starts in [lo, hi], with their later events up to today."""
    events, failed, last_event_day, last_sales_day, units = [], [], "", "", 0
    for d in day_range(lo - dt.timedelta(days=1), today):
        rows, st = fetch_day(tok, "SUBSCRIPTION_EVENT", d, ("1_4", "1_3"))
        if st == "failed":
            failed.append(f"{d} SUBSCRIPTION_EVENT")
        for x in rows:
            if x.get("App Apple ID") == APP_ID:
                x["_report_date"] = d.isoformat()
                events.append(x)
                last_event_day = d.isoformat()
        if d >= lo:
            srows, sst = fetch_day(tok, "SALES", d, ("1_1",))
            if sst == "failed":
                failed.append(f"{d} SALES")
            if sst == "ok":
                last_sales_day = d.isoformat()
            if d <= hi:
                units += sum(int(x.get("Units") or 0) for x in srows
                             if x.get("Apple Identifier") == APP_ID
                             and x.get("Product Type Identifier") in FIRST_TIME_PTI)
    through = last_sales_day

    L, H = lo.isoformat(), hi.isoformat()
    events.sort(key=lambda e: (e["Event Date"], e["Event"]))
    starts, excluded = {}, []
    for e in events:
        if not (L <= e["Event Date"] <= H):
            continue
        ev = e["Event"]
        startish = ev == "Subscribe" or ev.startswith("Start ") or ev.startswith("Reactivat") or ev == "Opt-In"
        if not startish:
            continue
        if ev in COUNTED_STARTS and L <= e["Original Start Date"] <= H:
            k = (e["Original Start Date"], e["Country"], e["Subscription Name"])
            s = starts.setdefault(k, {"events": [], "qty": 0, "period_days": 0})
            s["events"].append(ev)
            s["qty"] += int(e.get("Quantity") or 1)
            pd = duration_days(e.get("Subscription Offer Duration")) if e.get("Subscription Offer Type") \
                else duration_days(e.get("Standard Subscription Duration"))
            s["period_days"] = max(s["period_days"], pd)
        else:
            excluded.append(e)

    r320 = r320_cancel_rows()
    for r in r320:
        r["left"] = r["count"]  # each r320 cancel is credited to at most that many subscribers
    for k in sorted(starts):  # date order, so an r320 row goes to the earliest matching start
        s = starts[k]
        start, q = dt.date.fromisoformat(k[0]), s["qty"]
        intro = any(ev == "Start Introductory Offer" for ev in s["events"])
        c_dbc = c_ref = kept = second = 0
        notes = []
        for e in events:
            same = (e["Original Start Date"], e["Country"]) == k[:2]
            if not same or (e["Subscription Name"] != k[2] and not e["Event"].startswith("Crossgrade")):
                continue
            ev, n = e["Event"].lower(), int(e.get("Quantity") or 1)
            dbc = (e.get("Days Before Canceling") or "").strip()
            cpp = (e.get("Consecutive Paid Periods") or "").strip()
            if ev == "cancel" and dbc.isdigit() and e["Subscription Name"] == k[2]:
                # A Cancel row after a renewal (CPP >= 2) means the subscriber was not
                # cancelled within 3 days of the start, whatever DBC is counted from.
                if int(dbc) <= 3 and cpp in ("", "0", "1"):
                    c_dbc += n
                else:
                    kept += n
                notes.append(f"Cancel {e['Event Date']} DBC {dbc} CPP {cpp or '-'} x{n}")
            elif "refund" in ev:
                days = (dt.date.fromisoformat(e["Event Date"]) - start).days
                if days <= 3:
                    c_ref += n
                notes.append(f"refund {e['Event Date']} (day {days}) x{n}")
            paid_event = (e["Event"].startswith("Renew") or e["Event"].startswith("Paid Subscription from")
                          or e["Event"].startswith("Crossgrade"))
            need = 1 if intro else 2
            if e["Event Date"] <= H and paid_event and cpp.isdigit() and int(cpp) >= need:
                second += n
        # One subscriber can have both a refund and a Cancel row: take the larger, not the sum.
        c3 = min(max(c_dbc, c_ref), q)
        kept = min(kept, q - c3)
        rest = q - c3 - kept
        period_end = start + dt.timedelta(days=s["period_days"])
        if rest and through and (period_end + dt.timedelta(days=1)).isoformat() < through:
            kept += rest
            notes.append(f"first period ended ~{period_end}, no Cancel row for {rest}")
            rest = 0
        r320_used = 0
        if rest:
            hits = [r for r in r320 if r["left"] > 0 and r["territory"] in (k[1], "")
                    and (not r["subscription"] or r["subscription"] == k[2])
                    and -1 <= (dt.date.fromisoformat(r["date"]) - start).days <= 3]
            for r in hits:
                take = min(rest - r320_used, r["left"])
                r["left"] -= take
                r320_used += take
            if r320_used:
                rest -= r320_used
                notes.append("r320 (provisional: r320 can't say which subscriber) "
                             + ", ".join(f"{r['date']} {r['territory']} Cancels {r['count']}" for r in hits))
        s.update({"cancel3": c3 + r320_used, "r320": r320_used, "kept": kept, "unknown": rest,
                  "second": min(second, q), "notes": notes,
                  "resolves": (period_end + dt.timedelta(days=4)).isoformat() if (rest or r320_used) else ""})

    return {"events": [e for e in events if e["Event Date"] >= L],
            "starts": starts, "excluded": excluded, "units": units, "failed": failed,
            "through": through, "last_event_day": last_event_day, "r320_rows": r320}


def verdict(starts: dict, units: int):
    n = sum(s["qty"] for s in starts.values())
    second = sum(s["second"] for s in starts.values())
    kept_worst = sum(s["kept"] for s in starts.values())
    # r320-only cancels are provisional: in the best case those subscribers were kept.
    kept_best = kept_worst + sum(s["unknown"] + s["r320"] for s in starts.values())

    def one(kept):
        if n >= 3 and kept >= 2 and second >= 1:
            return "SUCCESS"
        if n <= 1 or kept == 0:
            return "KILL"
        return "IN BETWEEN"

    best, worst = one(kept_best), one(kept_worst)
    label = " (traffic-limited: fewer than 40 first-time units)" if units < 40 else ""
    if best == worst:
        return (f"VERDICT {best}{label}: starts {n}, kept past 3 days {kept_worst}"
                + (f" (+{kept_best - kept_worst} unknown, which can't change it)" if kept_best != kept_worst else "")
                + f", reached a second paid period {second}")
    resolves = max((s["resolves"] for s in starts.values() if s["resolves"]), default="")
    return (f"VERDICT UNDETERMINED{label}: {worst} if the unknown starts cancelled within 3 days, {best} if not; "
            f"starts {n}, kept {kept_worst}..{kept_best}, second paid period {second}; resolves by ~{resolves}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="start", default="2026-11-05")
    ap.add_argument("--to", dest="end", default="2027-01-31")
    args = ap.parse_args()
    lo, hi = dt.date.fromisoformat(args.start), dt.date.fromisoformat(args.end)
    today = dt.date.today()
    c = collect(A.token(), lo, hi, today)

    print(f"RoastMate payer read (v1.8 §2.3), starts {lo} .. {hi}, later events through today; run {today}")
    print(f"data reaches {c['through'] or 'none'} (latest SALES day; latest SUBSCRIPTION_EVENT day with this "
          f"app's rows {c['last_event_day'] or 'none'}; subscription reports lag Sales by about a day)")
    print(f"events from {lo}: {len(c['events'])}")
    for e in c["events"]:
        print(f"  {e['Event Date']} {e['Country']} {e['Event']} [{e['Subscription Name']}] "
              f"offer={e.get('Subscription Offer Type') or '-'} start={e['Original Start Date']} "
              f"paid_periods={e.get('Consecutive Paid Periods') or '-'} "
              f"days_before_canceling={e.get('Days Before Canceling') or '-'} "
              f"reason={e.get('Cancellation Reason') or '-'} qty={e.get('Quantity')} (report {e['_report_date']})")
    if c["excluded"]:
        print("start-like events NOT counted as §2.3 new starts (offer codes, promotional offers, opt-ins,"
              " reactivations, or an Original Start Date before the window):")
        for e in c["excluded"]:
            print(f"  {e['Event Date']} {e['Country']} {e['Event']} start={e['Original Start Date']} qty={e.get('Quantity')}")
    print(f"r320 cancel rows in the local log: {len(c['r320_rows'])}")
    n = sum(s["qty"] for s in c["starts"].values())
    print(f"new starts: {n}")
    for k, s in sorted(c["starts"].items()):
        shared = " (shared key: subscribers told apart by later rows' Quantity)" if s["qty"] > 1 else ""
        print(f"  {k[0]} {k[1]} {k[2]} via {'/'.join(s['events'])} x{s['qty']}{shared}: "
              f"cancelled within 3 days {s['cancel3']}"
              + (f" ({s['r320']} provisional, from r320)" if s["r320"] else "")
              + f", kept {s['kept']}, unknown {s['unknown']}"
              + (f" (until ~{s['resolves']})" if s["resolves"] else "")
              + f", second paid period {s['second']}"
              + (f" [{'; '.join(s['notes'])}]" if s["notes"] else ""))
    print(f"first-time units in window (Sales): {c['units']}" + (f"; starts per unit {n / c['units']:.3f}" if c["units"] else ""))
    if c["failed"]:
        print(f"FAILED report days (not 404): {', '.join(c['failed'])}")
        print("No verdict: rerun later.")
        sys.exit(2)
    print(verdict(c["starts"], c["units"]))
    if hi >= today or (c["through"] or "") < (hi + dt.timedelta(days=1)).isoformat():
        print(f"NOTE: data reaches {c['through'] or 'none'}, not past {hi} + 1 day yet: this is an interim read.")


if __name__ == "__main__":
    main()
