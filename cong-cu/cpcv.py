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
