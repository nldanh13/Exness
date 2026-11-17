# -*- coding: utf-8 -*-
"""Offline, trade-free evaluation of TrendBot direction-shadow M15 CSV.

CSV is produced by TrendBot/Direction.mqh in MT5 Common/Files:
  TrendBot_huong_<account>_<symbol>_<magic>_M15.csv
'F' = forecast from a CLOSED M15 bar.
'R' = a horizon result exactly +4/+8/+16 CLOSED M15 bars later.
No trade fills, leverage, spread P&L, model retraining, or MT5 compilation.
"""
from __future__ import annotations

import argparse
import csv
import math
from collections import defaultdict
from pathlib import Path

HORIZONS = (4, 8, 16)
SOURCES = ("ensemble", "dow", "ema", "macd", "structure")


def read_rows(path: str | Path):
    forecasts, resolved = {}, {}
    duplicates = 0
    with Path(path).open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        mandatory = {"event", "t_m15_server_epoch", "horizon", "entry", "close",
                     "delta_price", "atr_m15", "spread", *SOURCES, "label"}
        if not reader.fieldnames or not mandatory.issubset(reader.fieldnames):
            raise ValueError("Sai cau truc CSV du doan huong, hay dung file v5.43")
        for r in reader:
            if not r.get("event") or r["event"].startswith("#"):
                continue
            t = int(r["t_m15_server_epoch"])
            h = int(r["horizon"])
            if r["event"] == "F":
                if h != 0:
                    raise ValueError("Forecast phai co horizon = 0")
                if t in forecasts:
                    duplicates += 1
                    continue
                forecasts[t] = r
            elif r["event"] == "R":
                if h not in HORIZONS:
                    raise ValueError("Horizon la 4,8,16 M15, khong phai " + str(h))
                if (t, h) in resolved:
                    duplicates += 1
                    continue
                resolved[(t, h)] = r
            else:
                raise ValueError("Khong biet event " + repr(r["event"]))
    if not forecasts:
        raise ValueError("Khong co forecast F trong file")
    return forecasts, resolved, duplicates


def realized_direction(r):
    """Significant movement vs original M15 spread & ATR, not fee-adjusted P&L."""
    delta = float(r["delta_price"])
    spread = max(0.0, float(r["spread"]))
    atr = max(0.0, float(r["atr_m15"]))
    band = max(2 * spread, 0.1 * atr)
    return 1 if delta > band else -1 if delta < -band else 0


def wilson(k, n, z=1.96):
    if not n:
        return (None, None)
    p = k / n
    d = 1 + z*z / n
    m = (p + z*z / (2*n)) / d
    b = z * math.sqrt((p*(1-p) + z*z/(4*n)) / n) / d
    return round(max(0, m-b), 4), round(min(1, m+b), 4)


def assess(path):
    forecasts, resolved, duplicates = read_rows(path)
    data = {"forecasts": len(forecasts), "duplicate_events": duplicates,
            "resolved_unmatched": 0, "horizons": {}}
    stats = {h: {src: defaultdict(int) for src in SOURCES} for h in HORIZONS}
    base = {h: defaultdict(int) for h in HORIZONS}
    for (t, h), r in resolved.items():
        f = forecasts.get(t)
        if f is None:
            data["resolved_unmatched"] += 1
            continue
        for key in SOURCES:
            if int(f[key]) != int(r[key]):
                raise ValueError(f"Thay doi phieu {key} sau du doan (t={t}, h={h})")
        if abs(float(f["entry"]) + float(r["delta_price"]) - float(r["close"])) > 1e-5:
            raise ValueError(f"Entry/close/delta khong nhat quan t={t}, h={h}")
        actual = realized_direction(r)
        base[h]["n"] += 1
        base[h]["up" if actual > 0 else "down" if actual < 0 else "flat"] += 1
        for src in SOURCES:
            vote = int(f[src])
            if vote not in (-1, 0, 1):
                raise ValueError("Vote khong phai -1,0,1")
            st = stats[h][src]
            st["total"] += 1
            if vote == 0:
                st["abstain"] += 1
            elif actual == 0:
                st["flat"] += 1
            elif actual == vote:
                st["correct"] += 1
            else:
                st["incorrect"] += 1
    for h in HORIZONS:
        n = base[h]["n"]
        entries = {}
        for src in SOURCES:
            s = stats[h][src]
            correct, wrong = s["correct"], s["incorrect"]
            counted = correct + wrong
            entries[src] = {
                "eligible": n,
                "predictions": n - s["abstain"],
                "abstentions": s["abstain"],
                "correct": correct, "incorrect": wrong, "flat": s["flat"],
                "accuracy_ex_flat": round(correct / counted, 4) if counted else None,
                "wilson95_ex_flat": wilson(correct, counted),
            }
        data["horizons"][h] = {
            "resolved": n,
            "unresolved_or_missing": len(forecasts) - n,
            "base_up": base[h]["up"], "base_down": base[h]["down"],
            "base_flat": base[h]["flat"],
            "sources": entries
        }
    return data


def print_report(data):
    print("Direction shadow (observation ONLY, NOT executed trades)")
    print("Forecasts:", data["forecasts"], "duplicates:", data["duplicate_events"],
          "unmatched outcomes:", data["resolved_unmatched"])
    for h, v in data["horizons"].items():
        print(f"\nH+{h} M15 | complete {v['resolved']}/{data['forecasts']}"
              f" | realized up/down/flat {v['base_up']}/{v['base_down']}/{v['base_flat']}")
        for name, s in v["sources"].items():
            acc = "-" if s["accuracy_ex_flat"] is None else f"{s['accuracy_ex_flat']:.1%}"
            ci = s["wilson95_ex_flat"]
            bound = "-" if ci[0] is None else f"{ci[0]:.1%}..{ci[1]:.1%}"
            print(f"  {name:10} votes={s['predictions']:5} abstain={s['abstentions']:5} "
                  f"right={s['correct']:5} wrong={s['incorrect']:5} flat={s['flat']:5} "
                  f"accuracy(ex flat)={acc:>6} Wilson95={bound}")
    print("\nWARNING: horizons and consecutive signals OVERLAP, and all sources use"
          " related market prices; Wilson intervals ignore serial dependence."
          " These are NOT trading returns, edge or a probability forecast."
          " Use walk-forward / non-overlapping blocks and broker real ticks.")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("csv", help="MT5 Common/Files/TrendBot_huong_..._M15.csv")
    args = p.parse_args()
    print_report(assess(args.csv))


if __name__ == "__main__":
    main()
