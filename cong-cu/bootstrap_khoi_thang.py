# -*- coding: utf-8 -*-
"""Monthly moving-block bootstrap for saved MT5 closed-trade R, no IID fiction.

WARNING: ThoiGianVao is entry month, NOT the exact exit month. Monthly
aggregation is approximate when a trade crosses month boundary.
This is diagnostic, not a simulation of broker tick fills.
"""
import argparse
import csv
import random
from collections import defaultdict
from datetime import datetime
from pathlib import Path


def monthly_r(path, run):
    buckets = defaultdict(float)
    n = 0
    with Path(path).open(encoding="utf-8-sig", newline="") as fh:
        for row in csv.DictReader(fh):
            if run and row.get("Lan") != run:
                continue
            try:
                t = datetime.strptime(row["ThoiGianVao"][:16], "%Y.%m.%d %H:%M")
                r = float(row["R"])
            except (KeyError, ValueError, TypeError):
                continue
            buckets[(t.year, t.month)] += r
            n += 1
    if not buckets:
        raise ValueError("Khong tim thay giao dich R hop le")
    lo, hi = min(buckets), max(buckets)
    vals = []
    y, m = lo
    while (y, m) <= hi:
        vals.append(buckets[(y, m)])
        m += 1
        if m > 12:
            y, m = y + 1, 1
    return vals, n


def bootstrap(values, blocks=3, draws=3000, seed=130326):
    if blocks < 1 or blocks > len(values):
        raise ValueError("block length khong duoc lon hon so thang quan sat")
    if draws < 100:
        raise ValueError("draws >= 100")
    rng = random.Random(seed)
    n = len(values)
    possible = [values[i:i + blocks] for i in range(n - blocks + 1)]
    samples = []
    for _ in range(draws):
        path = []
        while len(path) < n:
            path.extend(rng.choice(possible))
        samples.append(sum(path[:n]))
    samples.sort()
    return {
        "months": n, "observed_R": round(sum(values), 3),
        "p025_R": round(samples[int(0.025 * draws)], 3),
        "median_R": round(samples[draws // 2], 3),
        "p975_R": round(samples[int(0.975 * draws)], 3),
        "p_total_R_nonpositive": round(sum(x <= 0 for x in samples) / draws, 3),
    }


def main():
    ap = argparse.ArgumentParser(description="Monthly block bootstrap theo tung nhom giao dich")
    ap.add_argument("csv")
    ap.add_argument("--lan", default="C-Donchian20-H4-ADX")
    ap.add_argument("--block-months", type=int, default=3)
    ap.add_argument("--draws", type=int, default=3000)
    ns = ap.parse_args()
    months, n = monthly_r(ns.csv, ns.lan)
    print("Strategy:", ns.lan, "deals:", n, "monthly observations:", len(months))
    print("Bootstrap (entry-month approximate):", bootstrap(months, ns.block_months, ns.draws))
    print("Cac block duoc lay lai tu cung du lieu qua khu; CI khong thay duoc OOS thuc.")


if __name__ == "__main__":
    main()
