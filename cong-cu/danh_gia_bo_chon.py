# -*- coding: utf-8 -*-
"""Danh gia bo tu chon chien luoc kieu walk-forward tu file lenh cua dot "Xep hang chien luoc" (XH-*).
Moi dau thang: chi nhin cac dot DA DONG truoc thoi diem do, dung DUNG luat cua ChayThuNghiem.ps1
(du dieu kien = R TB toan bo qua khu > 0 va >= 20 dot; diem = can duoi 90% R TB 12 thang gan nhat, >= 8 dot),
chon chien luoc dung dau, roi lay ket qua cac dot cua chien luoc do MO trong thang tiep theo.
So voi: luon Donchian H4, va tung chien luoc rieng le.
Chay:  python cong-cu/danh_gia_bo_chon.py ket-qua/<ngay>-nhanh-lenh.csv"""
import csv, math, sys
from collections import defaultdict
from datetime import datetime, timedelta

WINDOW_M, MIN_REC, MIN_ALL = 12, 8, 20


def campaigns(rows):
    rows = sorted(rows, key=lambda r: r["ThoiGianVao"])
    out, end, d = [], None, None
    for r in rows:
        tin = datetime.strptime(r["ThoiGianVao"], "%Y.%m.%d %H:%M")
        tout = tin + timedelta(hours=float(r["GioGiu"]))
        R = float(r["R"])
        if out and end and tin < end and r["Chieu"] == d:
            out[-1]["R"] += R; out[-1]["out"] = max(out[-1]["out"], tout)
        else:
            out.append({"in": tin, "out": tout, "R": R}); d = r["Chieu"]
        end = max(end, tout) if end else tout
    return out


def score(camps, t):
    past = [c["R"] for c in camps if c["out"] < t]
    rec = [c["R"] for c in camps if t - timedelta(days=30.44 * WINDOW_M) <= c["out"] < t]
    if len(past) < MIN_ALL or sum(past) / len(past) <= 0 or len(rec) < MIN_REC:
        return None
    m = sum(rec) / len(rec)
    sd = math.sqrt(sum((x - m) ** 2 for x in rec) / (len(rec) - 1))
    return m - 1.28 * sd / math.sqrt(len(rec))


def month_starts(a, b):
    t = datetime(a.year, a.month, 1)
    while t < b:
        yield t
        t = datetime(t.year + (t.month == 12), t.month % 12 + 1, 1)


def main(path):
    by = defaultdict(list)
    for r in csv.DictReader(open(path, encoding="utf-8-sig")):
        if r["Lan"].startswith("XH-"):
            by[r["Lan"]].append(r)
    if not by:
        sys.exit("Khong co lenh XH-* trong file.")
    C = {k: campaigns(v) for k, v in by.items()}
    t0 = min(c["in"] for v in C.values() for c in v)
    t1 = max(c["out"] for v in C.values() for c in v)
    sel, picks = [], defaultdict(int)
    for m in month_starts(t0 + timedelta(days=365), t1):
        nxt = datetime(m.year + (m.month == 12), m.month % 12 + 1, 1)
        sc = {k: score(v, m) for k, v in C.items()}
        ok = {k: s for k, s in sc.items() if s is not None}
        pick = max(ok, key=ok.get) if ok else None
        picks[pick or "(khong ai)"] += 1
        if pick:
            sel += [(c["in"], c["R"]) for c in C[pick] if m <= c["in"] < nxt]
    start = t0 + timedelta(days=365)
    mid = start + (t1 - start) / 2

    def stats(lst, a, b):
        x = [r for t, r in lst if a <= t < b]
        if not x:
            return "0 dot"
        m = sum(x) / len(x)
        sd = math.sqrt(sum((v - m) ** 2 for v in x) / max(1, len(x) - 1))
        return "%3d dot, tong R %6.1f, TB %+.3f, t %+.2f" % (len(x), sum(x), m, m / (sd / math.sqrt(len(x))) if sd else 0)

    print("Giai doan danh gia: %s -> %s (nam dau chi de co lich su)" % (start.date(), t1.date()))
    print("So thang chon moi chien luoc:", dict(picks))
    print("%-22s | %-45s | %-45s" % ("", "Nua dau %s-%s" % (start.date(), mid.date()), "Nua sau -> %s" % t1.date()))
    rows = [("BO TU CHON", sel)] + [(k, [(c["in"], c["R"]) for c in v]) for k, v in sorted(C.items())]
    for name, lst in rows:
        print("%-22s | %-45s | %-45s" % (name, stats(lst, start, mid), stats(lst, mid, t1)))
    print("\nTieu chi dat truoc: bo tu chon phai co tong R cao hon 'XH-Donchian-H4' o CA HAI nua.")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else sys.exit(__doc__))
