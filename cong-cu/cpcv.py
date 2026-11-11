# -*- coding: utf-8 -*-
"""Kiem thu chia to hop (CPCV, Lopez de Prado) cho chien luoc C: Donchian H4 + ADX + EMA200 (H4 va D1), SL x ATR, trailing 3 ATR.
Muc dich: biet viec CHON tham so co gia tri khong, thay vi chi xem mot lan chia truoc/sau.
  - Chia du lieu thanh N khoi lien tiep theo thoi gian (mac dinh 6). Moi cach chon K khoi lam kiem tra (mac dinh 2 -> 15 cach),
    lay cau hinh tot nhat tren cac khoi con lai, ghi ket qua cua no tren khoi kiem tra.
  - Bo khoi train moi lenh co thoi gian giu (cong them 1 tuan) cham vao khoi kiem tra (purge + embargo).
  - PBO = ty le so lan cau hinh "tot nhat trong mau" xep duoi trung vi khi ra ngoai mau. < 20%: chon tham so co ich; > 50%: vo ich.
Luoi cau hinh dinh truoc, KHONG them sau khi xem ket qua (moi cau hinh them la mot lan thu).
Day la mo phong Python gan dung (gia M10 gom thanh H4, chi phi 0,06%/vong, khong nhoi lenh), khong thay the backtest MT5.

Chay:  python cong-cu/cpcv.py ket-qua/gia-BTCUSDm_M10.zip            (doc thang file .zip hoac .csv)
       python cong-cu/cpcv.py ket-qua/gia-BTCUSDm_M10.zip --khoi 6 --kiemtra 2 --tu 2020-11-01
       python cong-cu/cpcv.py ket-qua/gia-BTCUSDm_M10.zip --bien-the    (so sanh 4 phuong an dinh truoc voi cau hinh goc)
"""
import argparse, io, itertools, zipfile
from datetime import datetime, timezone
import numpy as np

COST = 0.0006            # chi phi moi vong (spread + truot), giong thu_oi_C.py
TRAIL_ATR = 3.0
ADX_MIN = 20.0
EMBARGO = 7 * 86400      # 1 tuan sau moi khoi kiem tra
GRID = [(dc, sl) for dc in (10, 20, 40) for sl in (2.0, 2.5, 3.0)]   # (chu ky Donchian, SL x ATR): 9 cau hinh


def load(path):
    if path.lower().endswith(".zip"):
        z = zipfile.ZipFile(path)
        name = [n for n in z.namelist() if n.lower().endswith(".csv")][0]
        f = io.TextIOWrapper(z.open(name), encoding="utf-8")
    else:
        f = open(path, encoding="utf-8")
    a = np.loadtxt(f, delimiter=",", skiprows=1, usecols=(0, 1, 2, 3, 4))
    return a


def group(a, sec):
    key = (a[:, 0] // sec).astype(np.int64)
    idx = np.flatnonzero(np.r_[True, key[1:] != key[:-1]]); ends = np.r_[idx[1:], len(a)]
    return (key[idx] * sec, a[idx, 1], np.maximum.reduceat(a[:, 2], idx), np.minimum.reduceat(a[:, 3], idx), a[ends - 1, 4])


def wilder(x, n):
    out = np.empty_like(x); out[0] = x[0]
    for i in range(1, len(x)): out[i] = (out[i - 1] * (n - 1) + x[i]) / n
    return out


def ema(x, n):
    k = 2 / (n + 1); out = np.empty_like(x); out[0] = x[0]
    for i in range(1, len(x)): out[i] = k * x[i] + (1 - k) * out[i - 1]
    return out


def indicators(T, H, L, C):
    pc = np.r_[C[0], C[:-1]]
    ATR = wilder(np.maximum(H - L, np.maximum(abs(H - pc), abs(L - pc))), 14)
    E200 = ema(C, 200)
    up = H - np.r_[H[0], H[:-1]]; dn = np.r_[L[0], L[:-1]] - L
    pdi = 100 * wilder(np.where((up > dn) & (up > 0), up, 0.), 14) / ATR
    ndi = 100 * wilder(np.where((dn > up) & (dn > 0), dn, 0.), 14) / ATR
    ADX = wilder(100 * abs(pdi - ndi) / np.maximum(pdi + ndi, 1e-9), 14)
    # EMA200 khung D1, chi dung ngay DA DONG truoc nen H4 hien tai (khong nhin tuong lai)
    day = T // 86400
    dkeys, didx = np.unique(day, return_index=True)
    dclose = np.r_[C[didx[1:] - 1], C[-1]]
    dema = ema(dclose, 200)
    pos = np.searchsorted(dkeys, day) - 1          # ngay truoc
    D1E = np.where(pos >= 200, dema[np.maximum(pos, 0)], np.nan)
    D1C = np.where(pos >= 0, dclose[np.maximum(pos, 0)], np.nan)
    return ATR, E200, ADX, D1E, D1C


def run(dc, slm, T, O, H, L, C, ATR, E200, ADX, D1E, D1C):
    """Tra ve list (gio vao, gio ra, R) theo tung lenh."""
    N = len(C); trades = []; pos = None
    for i in range(N - 1):
        if pos:
            d, ent, sl, risk, t0 = pos; ex = None
            if d == 1 and L[i] <= sl: ex = min(sl, O[i])
            if d == -1 and H[i] >= sl: ex = max(sl, O[i])
            if ex is not None:
                trades.append((t0, T[i] + 14400, d * (ex - ent) / risk - COST * ent / risk)); pos = None
            else:
                sl = max(sl, C[i] - TRAIL_ATR * ATR[i]) if d == 1 else min(sl, C[i] + TRAIL_ATR * ATR[i])
                pos = (d, ent, sl, risk, t0)
        if pos is None and i >= 250 and ADX[i] >= ADX_MIN and not np.isnan(D1E[i]):
            d = 0
            if C[i] > H[i - dc:i].max() and C[i] > E200[i] and D1C[i] > D1E[i]: d = 1
            elif C[i] < L[i - dc:i].min() and C[i] < E200[i] and D1C[i] < D1E[i]: d = -1
            if d:
                sl = C[i] - d * slm * ATR[i]
                pos = (d, C[i], sl, abs(C[i] - sl), T[i] + 14400)   # vao o gia dong nen
    return trades


def run_v(dc, slm, T, O, H, L, C, ATR, E200, ADX, D1E, D1C, size=None, step=None):
    """Nhu run() nhung co them: size(i) = he so rui ro luc vao (mac dinh 1), step = (MFE_R, ATR_trailing_moi):
    khi lai lon nhat dat MFE_R thi trailing chuyen tu TRAIL_ATR sang ATR_trailing_moi. Tra ve (gio vao, gio ra, R, he so)."""
    N = len(C); trades = []; pos = None
    for i in range(N - 1):
        if pos:
            d, ent, sl, risk, t0, w, mfe = pos; ex = None
            if d == 1 and L[i] <= sl: ex = min(sl, O[i])
            if d == -1 and H[i] >= sl: ex = max(sl, O[i])
            if ex is not None:
                trades.append((t0, T[i] + 14400, d * (ex - ent) / risk - COST * ent / risk, w)); pos = None
            else:
                mfe = max(mfe, d * ((H[i] if d == 1 else L[i]) - ent) / risk)
                k = step[1] if step and mfe >= step[0] else TRAIL_ATR
                sl = max(sl, C[i] - k * ATR[i]) if d == 1 else min(sl, C[i] + k * ATR[i])
                pos = (d, ent, sl, risk, t0, w, mfe)
        if pos is None and i >= 250 and ADX[i] >= ADX_MIN and not np.isnan(D1E[i]):
            d = 0
            if C[i] > H[i - dc:i].max() and C[i] > E200[i] and D1C[i] > D1E[i]: d = 1
            elif C[i] < L[i - dc:i].min() and C[i] < E200[i] and D1C[i] < D1E[i]: d = -1
            if d:
                sl = C[i] - d * slm * ATR[i]
                pos = (d, C[i], sl, abs(C[i] - sl), T[i] + 14400, size(i) if size else 1.0, 0.0)
    return trades


def variants(T, O, H, L, C, ATR, E200, ADX, D1E, D1C):
    """4 phuong an DINH TRUOC (lay tu bao cao nghien cuu 11/11/2026), khong do tham so:
    goc      = Donchian 20, SL 2,5 ATR, trailing 3 ATR (cau hinh C)
    gop      = 4 kenh Donchian 10/20/40/80 chay song song, moi kenh 1/4 rui ro
    kl_atr   = goc, rui ro x1,25 khi ATR luc vao o phan vi < 33 cua 90 ngay truoc, x0,75 khi > 67
    trail_bac= goc, trailing 3 ATR cho toi khi lai lon nhat dat 4R, sau do 2 ATR"""
    a = (T, O, H, L, C, ATR, E200, ADX, D1E, D1C)
    def atr_pct(i, n=540):
        w = ATR[max(0, i - n):i]
        return (w < ATR[i]).mean() if len(w) >= 100 else 0.5
    size = lambda i: 1.25 if atr_pct(i) < 1 / 3 else 0.75 if atr_pct(i) > 2 / 3 else 1.0
    out = {"goc": run_v(20, 2.5, *a)}
    out["gop"] = [(t0, t1, r, 0.25) for dc in (10, 20, 40, 80) for t0, t1, r, _ in run_v(dc, 2.5, *a)]
    out["kl_atr"] = run_v(20, 2.5, *a, size=size)
    out["trail_bac"] = run_v(20, 2.5, *a, step=(4.0, 2.0))
    return out


def monthly(tr, t_start, t_end):
    """Tong R (da nhan he so) theo thang, tinh vao thang dong lenh: so sanh cong bang giua phuong an nhieu / it lenh."""
    m0 = datetime.fromtimestamp(int(t_start), timezone.utc); m1 = datetime.fromtimestamp(int(t_end), timezone.utc)
    nm = (m1.year - m0.year) * 12 + m1.month - m0.month + 1
    v = np.zeros(nm)
    for t0, t1, r, w in tr:
        if t0 < t_start: continue
        d = datetime.fromtimestamp(int(t1), timezone.utc)
        k = (d.year - m0.year) * 12 + d.month - m0.month
        if 0 <= k < nm: v[k] += r * w
    return v



def btc_hold_monthly(T, C, t_start, t_end):
    """BTC buy & hold, close-to-close log returns by UTC calendar month.
    Risk-normalize at MONTHLY stdev to compare with an active strategy; NOT R.
    """
    m0 = datetime.fromtimestamp(int(t_start), timezone.utc)
    m1 = datetime.fromtimestamp(int(t_end), timezone.utc)
    size = (m1.year - m0.year) * 12 + m1.month - m0.month + 1
    closes = {}
    initial = None
    for t, px in zip(T, C):
        if t < t_start:
            initial = float(px)
        if t_start <= t < t_end and px > 0:
            d = datetime.fromtimestamp(int(t), timezone.utc)
            month = (d.year - m0.year) * 12 + d.month - m0.month
            closes[month] = float(px)
    out = np.zeros(size)
    previous = initial if initial and initial > 0 else closes.get(0, 0)
    for month in range(size):
        px = closes.get(month, previous)
        if px and previous and px > 0 and previous > 0:
            out[month] = np.log(px / previous)
        if px > 0: previous = px
    return out


def compare(args, T, O, H, L, C, ATR, E200, ADX, D1E, D1C, t_start, t_end, edges):
    res = variants(T, O, H, L, C, ATR, E200, ADX, D1E, D1C)
    m0 = datetime.fromtimestamp(int(t_start), timezone.utc)
    years = sorted({datetime.fromtimestamp(int(t1), timezone.utc).year for _, t1, _, _ in res["goc"] if t1 >= t_start})
    print("\nSo sanh 4 phuong an dinh truoc (R da nhan he so rui ro, tinh theo thang dong lenh):")
    print("%-10s %6s %8s %8s %6s %7s %9s  %s" % ("", "lenh", "tongR", "SR/thang", "t", "DD_R", "R bo top5", "R theo nam " + " ".join(str(y) for y in years)))
    mon = {}
    for k, tr in res.items():
        tr = [x for x in tr if x[0] >= t_start]
        v = monthly(tr, t_start, t_end); mon[k] = v
        sr = v.mean() / v.std(ddof=1) if v.std(ddof=1) > 0 else 0
        eq = np.cumsum(v); dd = (np.maximum.accumulate(np.r_[0, eq]) - np.r_[0, eq]).max()
        rw = sorted(r * w for _, _, r, w in tr)
        ny = [sum(r * w for _, t1, r, w in tr if datetime.fromtimestamp(int(t1), timezone.utc).year == y) for y in years]
        print("%-10s %6d %+8.1f %8.3f %6.2f %7.1f %+9.1f  %s" % (k, len(tr), v.sum(), sr, sr * np.sqrt(len(v)), dd,
              sum(rw[:-5]) if len(rw) > 5 else 0, " ".join("%+5.1f" % x for x in ny)))
    # Tung cach chon khoi kiem tra (CPCV): phuong an co hon goc tren khoi kiem tra khong (theo tong R thang)
    def month_of(t): d = datetime.fromtimestamp(int(t), timezone.utc); return (d.year - m0.year) * 12 + d.month - m0.month
    combos = list(itertools.combinations(range(args.khoi), args.kiemtra))
    # Chuan hoa cung muc rui ro: nhan moi phuong an de do lech chuan R theo thang bang cua goc.
    # Khong chuan hoa thi phuong an nao dung rui ro cao hon (vd kl_atr nhan 1,25) se "hon goc" chi vi danh lon hon.
    sd0 = mon["goc"].std(ddof=1)
    # Passive benchmark: compare at the same MONTHLY volatility as Donchian,
    # rather than comparing BTC % returns directly with strategy R.
    hold = btc_hold_monthly(T, C, t_start, t_end)
    hold_sd = hold.std(ddof=1)
    if hold_sd > 0 and sd0 > 0:
        matched = hold * (sd0 / hold_sd)
        mean = matched.mean()
        sharpe = mean / matched.std(ddof=1)
        eq = np.cumsum(matched)
        dd = np.max(np.maximum.accumulate(np.r_[0.0, eq]) - np.r_[0.0, eq])
        print("  Buy-and-hold BTC (monthly volatility-matched): total equivalent %+0.1fR, Sharpe/month %.3f, DD %.1fR"
              % (matched.sum(), sharpe, dd))
        print("  Luu y: benchmark la log-return quy doi bien dong, khong phai R vao/SL hay mo phong phi.")
    for k in mon:
        if mon[k].std(ddof=1) > 0: mon[k] = mon[k] * sd0 / mon[k].std(ddof=1)
    print("\nTren %d cach chon %d khoi kiem tra, CUNG muc rui ro voi goc: so lan hon goc (tong R) / chenh lech trung vi:" % (len(combos), args.kiemtra))
    for k in res:
        if k == "goc": continue
        diffs = []
        for test in combos:
            idx = [m for g in test for m in range(month_of(edges[g]), month_of(edges[g + 1] - 1) + 1)]
            idx = [m for m in sorted(set(idx)) if 0 <= m < len(mon[k])]
            diffs.append(mon[k][idx].sum() - mon["goc"][idx].sum())
        diffs = np.array(diffs)
        print("  %-10s %2d/%d  %+.1fR" % (k, int((diffs > 0).sum()), len(diffs), np.median(diffs)))
    print("Doc ket qua: phuong an chi dang them vao bot khi hon goc o hau het cac cach chia VA khong lam giam R bo top 5.")


def sharpe(rs):
    rs = np.asarray(rs)
    if len(rs) < 5 or rs.std(ddof=1) == 0: return np.nan
    return rs.mean() / rs.std(ddof=1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("gia", help="file gia M10 (.zip hoac .csv: time,open,high,low,close,...)")
    ap.add_argument("--khoi", type=int, default=6, help="so khoi thoi gian (mac dinh 6)")
    ap.add_argument("--kiemtra", type=int, default=2, help="so khoi kiem tra moi lan (mac dinh 2)")
    ap.add_argument("--tu", default="2020-11-01", help="ngay bat dau tinh (YYYY-MM-DD), truoc do chi de khoi dong chi bao")
    ap.add_argument("--bien-the", action="store_true", help="so sanh 4 phuong an dinh truoc (goc, gop nhieu chu ky, khoi luong theo ATR, trailing theo bac)")
    args = ap.parse_args()

    a = load(args.gia)
    T, O, H, L, C = group(a, 14400)
    ATR, E200, ADX, D1E, D1C = indicators(T, H, L, C)
    t_start = int(datetime.strptime(args.tu, "%Y-%m-%d").replace(tzinfo=timezone.utc).timestamp())
    t_end = int(T[-1]) + 14400
    edges = np.linspace(t_start, t_end, args.khoi + 1).astype(np.int64)
    fmt = lambda t: datetime.fromtimestamp(int(t), timezone.utc).strftime("%Y-%m-%d")
    print("Du lieu H4: %s -> %s, %d khoi:" % (fmt(t_start), fmt(t_end), args.khoi))
    for g in range(args.khoi): print("  khoi %d: %s -> %s" % (g + 1, fmt(edges[g]), fmt(edges[g + 1])))

    if args.bien_the:
        compare(args, T, O, H, L, C, ATR, E200, ADX, D1E, D1C, t_start, t_end, edges)
        return

    res = {}
    for cfg in GRID:
        tr = [x for x in run(cfg[0], cfg[1], T, O, H, L, C, ATR, E200, ADX, D1E, D1C) if x[0] >= t_start]
        res[cfg] = tr

    print("\nTung cau hinh tren toan bo (so lenh, R trung binh, Sharpe moi lenh, t):")
    for cfg, tr in res.items():
        rs = np.array([r for _, _, r in tr])
        s = sharpe(rs)
        print("  Donchian %2d, SL %.1f ATR: %4d lenh  %+.3fR  SR %.3f  t %.2f" % (cfg[0], cfg[1], len(rs), rs.mean(), s, s * np.sqrt(len(rs))))

    combos = list(itertools.combinations(range(args.khoi), args.kiemtra))
    below = 0; oos = []; chosen = {}
    print("\n%d cach chia (khoi kiem tra -> cau hinh chon -> Sharpe ngoai mau, hang tren %d):" % (len(combos), len(GRID)))
    for test in combos:
        ivs = [(edges[g], edges[g + 1]) for g in test]
        in_test = lambda t: any(lo <= t < hi for lo, hi in ivs)
        touches = lambda t0, t1: any(t0 < hi + EMBARGO and t1 > lo for lo, hi in ivs)
        tr_s, te_s = {}, {}
        for cfg, tr in res.items():
            tr_s[cfg] = sharpe([r for t0, t1, r in tr if not touches(t0, t1)])
            te_s[cfg] = sharpe([r for t0, t1, r in tr if in_test(t0)])
        best = max(GRID, key=lambda c: -np.inf if np.isnan(tr_s[c]) else tr_s[c])
        vals = np.array([te_s[c] for c in GRID], dtype=float)
        rank = (np.nan_to_num(vals, nan=-np.inf) < np.nan_to_num(te_s[best], nan=-np.inf)).sum() + 1   # 1 = te nhat
        if rank <= len(GRID) / 2: below += 1
        oos.append(te_s[best]); chosen[best] = chosen.get(best, 0) + 1
        print("  %-8s -> Donchian %2d, SL %.1f -> %+.3f  hang %d/%d" %
              (",".join(str(g + 1) for g in test), best[0], best[1], te_s[best], rank, len(GRID)))
    oos = np.array(oos, dtype=float)
    print("\nPBO (xac suat qua khop): %.0f%%  (duoi 20%% tot, tren 50%% la chon tham so vo ich)" % (below / len(combos) * 100))
    print("Sharpe moi lenh ngoai mau cua cau hinh duoc chon: trung vi %.3f, thap nhat %.3f, %d/%d lan duong" %
          (np.nanmedian(oos), np.nanmin(oos), int((oos > 0).sum()), len(oos)))
    print("So lan moi cau hinh duoc chon: " + ", ".join("D%d/SL%.1f: %d" % (c[0], c[1], k) for c, k in sorted(chosen.items(), key=lambda x: -x[1])))


if __name__ == "__main__":
    main()
