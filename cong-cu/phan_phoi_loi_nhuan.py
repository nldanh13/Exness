# -*- coding: utf-8 -*-
"""Phan tich R/lenh va dong gop cua duoi phai; khong suy dien tu win rate co dinh.

Vi du:
  python cong-cu/phan_phoi_loi_nhuan.py ket-qua/20261107-1924-chinhxac-lenh.csv --lan C-Donchian20-H4-ADX
  python cong-cu/phan_phoi_loi_nhuan.py ket-qua/20261107-1924-chinhxac-lenh.csv --lan C-Donchian20-H4-ADX --cot FundingPhanVi --toi-da 80

Neu loc theo bien thieu trong CSV, dung voi loi ro rang thay vi tu doan Fear & Greed.
"""
import argparse
import csv
import math
import statistics


def read_trades(path, run):
    with open(path, encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if "R" not in (reader.fieldnames or []):
            raise ValueError("CSV khong co cot R")
        for row in reader:
            if run and row.get("Lan") != run:
                continue
            try:
                val = float(row["R"])
            except (ValueError, TypeError, KeyError):
                continue
            if math.isfinite(val):
                yield row, val


def stats(trades):
    vals = [r for _, r in trades]
    if not vals:
        return None
    pos = [x for x in vals if x > 0]
    neg = [x for x in vals if x < 0]
    gain, loss = sum(pos), -sum(neg)
    top_n = max(1, math.ceil(0.1 * len(pos))) if pos else 0
    top = sum(sorted(pos, reverse=True)[:top_n])
    peak, balance, drawdown = 0.0, 0.0, 0.0
    for r in vals:
        balance += r
        peak = max(peak, balance)
        drawdown = max(drawdown, peak - balance)
    return {
        "lenh": len(vals),
        "win_rate_pct": round(100 * len(pos) / len(vals), 2),
        "mean_win_R": round(statistics.mean(pos), 3) if pos else None,
        "mean_loss_R": round(statistics.mean(neg), 3) if neg else None,
        "profit_factor": round(gain / loss, 3) if loss > 0 else None,
        "net_R": round(sum(vals), 3),
        "max_drawdown_R": round(drawdown, 3),
        "top_10pct_winners_share_of_gross_profit_pct": round(100 * top / gain, 2) if gain > 0 else None,
        "top_winners_over_net_R_pct": round(100 * top / sum(vals), 2) if sum(vals) > 0 else None,
    }


def main():
    ap = argparse.ArgumentParser(description="Phan phoi loi nhuan theo R va duoi phai")
    ap.add_argument("csv", help="CSV lenh bot: phai co cot R")
    ap.add_argument("--lan", default=None, help="Chi lay 1 cau hinh trong cot Lan")
    ap.add_argument("--cot", default=None, help="Cot so dung de so sanh bo loc gia dinh")
    ap.add_argument("--toi-da", type=float, default=None)
    ap.add_argument("--toi-thieu", type=float, default=None)
    args = ap.parse_args()

    original = list(read_trades(args.csv, args.lan))
    print("GOC (khong ap bo loc):", stats(original))
    if args.cot:
        if not original or args.cot not in original[0][0]:
            ap.error("Cot %r khong ton tai; KHONG the suy ra tac dong cua bo loc." % args.cot)
        keep = []
        for row, r in original:
            try:
                x = float(row[args.cot])
            except (ValueError, TypeError, KeyError):
                continue
            if not math.isfinite(x):
                continue
            if args.toi-da is not None and x > args.toi-da:
                continue
            if args.toi-thieu is not None and x < args.toi-thieu:
                continue
            keep.append((row, r))
        print("LOC GIU:", stats(keep))
        print("BO DI:", stats([t for t in original if t not in keep]))
        print("Can doi chieu out-of-sample; thong ke sau loc khong phai bang chung chien luoc co loi.")


if __name__ == "__main__":
    main()
