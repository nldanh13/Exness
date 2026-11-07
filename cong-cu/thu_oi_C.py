"""Thu xem open interest / ban do thanh ly uoc tinh co giup chien luoc C (Donchian20 H4 + ADX) khong.
Chay: python thu_oi_C.py gia-BTCUSDm_M10.csv binance_oi_BTCUSDT_1h.csv
Moi bien the duoc dinh truoc (khong do tim tham so). Nguong phan vi tinh tren du lieu QUA KHU (cua so 90 ngay), khong nhin tuong lai."""
import csv, sys
import numpy as np

SRC, OIF = sys.argv[1], sys.argv[2]
COST = 0.0006
# ---- gia M10 -> H1 (cho ban do thanh ly) va H4 (cho chien luoc) ----
a = np.loadtxt(SRC, delimiter=",", skiprows=1, usecols=(0, 1, 2, 3, 4))
a = a[a[:, 0] >= 1625097600]
def group(sec):
    key = (a[:, 0] // sec).astype(np.int64)
    idx = np.flatnonzero(np.r_[True, key[1:] != key[:-1]]); ends = np.r_[idx[1:], len(a)]
    return (key[idx] * sec, a[idx, 1], np.maximum.reduceat(a[:, 2], idx), np.minimum.reduceat(a[:, 3], idx), a[ends - 1, 4])
T, O, H, L, C = group(14400); N = len(T)
T1, O1, H1, L1, C1 = group(3600)

# ---- OI theo gio ----
oi = {}
with open(OIF) as f:
    r = csv.reader(f); hdr = next(r)
    for row in r:
        try: oi[int(row[0])] = [float(x) if x else np.nan for x in row[1:]]
        except ValueError: pass
def oi_at(ts, col):  # gia tri moi nhat <= ts (ts = luc dong nen)
    k = (ts - 1) // 3600 * 3600
    for _ in range(6):
        if k in oi and not np.isnan(oi[k][col]): return oi[k][col]
        k -= 3600
    return np.nan
CLOSE = T + 14400
OI = np.array([oi_at(t, 0) for t in CLOSE]); ACC = np.array([oi_at(t, 4) for t in CLOSE])
TOP = np.array([oi_at(t, 3) for t in CLOSE]); TAK = np.array([oi_at(t, 5) for t in CLOSE])
has_oi = ~np.isnan(OI)

def atr(n=14):
    pc = np.r_[C[0], C[:-1]]; tr = np.maximum(H - L, np.maximum(abs(H - pc), abs(L - pc)))
    out = np.empty_like(tr); out[0] = tr[0]
    for i in range(1, N): out[i] = (out[i-1]*(n-1) + tr[i]) / n
    return out
def sm(x, n):
    out = np.empty_like(x); out[0] = x[0]
    for i in range(1, len(x)): out[i] = (out[i-1]*(n-1) + x[i]) / n
    return out
def ema(x, n):
    k = 2/(n+1); out = np.empty_like(x); out[0] = x[0]
    for i in range(1, len(x)): out[i] = k*x[i] + (1-k)*out[i-1]
    return out
ATR = atr(); E200 = ema(C, 200)
up = H - np.r_[H[0], H[:-1]]; dn = np.r_[L[0], L[:-1]] - L
pdi = 100*sm(np.where((up > dn) & (up > 0), up, 0.), 14)/ATR; ndi = 100*sm(np.where((dn > up) & (dn > 0), dn, 0.), 14)/ATR
ADX = sm(100*abs(pdi-ndi)/np.maximum(pdi+ndi, 1e-9), 14)

# ---- ban do thanh ly uoc tinh (giong cach Coinglass doan): OI moi mo tai gia P -> muc thanh ly o cac don bay pho bien ----
LEV = {10: .30, 25: .30, 50: .25, 100: .15}; BIN = 0.0025
lo_p = np.log(min(L1.min(), 1000)) - 0.5; NB = int((np.log(H1.max()*3) - lo_p) / BIN) + 1
def b(p): return int((np.log(p) - lo_p) / BIN)
longliq = np.zeros(NB); shortliq = np.zeros(NB)   # don vi: BTC du kien bi thanh ly tai moi o gia
snapL, snapS = {}, {}
want = set(CLOSE.tolist()); prev = np.nan; decay = 0.5 ** (1/(30*24))
for j in range(len(T1)):
    t = T1[j]; o = oi.get(t, [np.nan])[0]
    longliq *= decay; shortliq *= decay
    if not np.isnan(o) and not np.isnan(prev):
        d = o - prev
        if d > 0:
            for lv, w in LEV.items():
                longliq[b(C1[j]*(1 - 0.9/lv))] += d*w/2; shortliq[b(C1[j]*(1 + 0.9/lv))] += d*w/2
        elif prev > 0:
            longliq *= o/prev; shortliq *= o/prev
    if not np.isnan(o): prev = o
    longliq[b(L1[j]):b(H1[j])+1] = 0; shortliq[b(L1[j]):b(H1[j])+1] = 0  # gia di qua -> da bi quet
    tc = t + 3600
    if tc in want: snapL[tc] = longliq.copy(); snapS[tc] = shortliq.copy()

def cluster_level(i, d, mind, maxd, side_short):
    """Tim muc gia co mat do thanh ly lon nhat trong [C+mind, C+maxd] (theo huong d). Tra ve gia hoac None neu khong co cum noi bat."""
    m = (snapS if side_short else snapL).get(CLOSE[i])
    if m is None: return None
    p0 = C[i] + d*mind; p1 = C[i] + d*maxd
    i0, i1 = sorted((b(p0), b(p1)))
    seg = m[i0:i1+1]
    if seg.sum() <= 0: return None
    k = int(np.argmax(np.convolve(seg, np.ones(3), "same")))
    # "noi bat": o lon nhat >= 3 lan trung binh trong toan vung +-15%
    wide = m[b(C[i]*0.85):b(C[i]*1.15)]
    if seg[k] < 3 * wide.mean(): return None
    return float(np.exp(lo_p + (i0 + k + 0.5) * BIN))

def pct_rank(x, i, n=540):  # phan vi cua x[i] trong 90 ngay truoc (chi qua khu)
    w = x[max(0, i-n):i]; w = w[~np.isnan(w)]
    if len(w) < 100 or np.isnan(x[i]): return np.nan
    return (w < x[i]).mean()

# ---- C goc + bien the ----
def signal(i):
    if i < 250 or ADX[i] < 20: return None
    if C[i] > H[i-20:i].max() and C[i] > E200[i]: return 1
    if C[i] < L[i-20:i].min() and C[i] < E200[i]: return -1

import random
def run(variant, rnd=None, keep=1.0):
    trades = []; pos = None
    for i in range(N - 1):
        if pos:
            d, ent, sl, tp, risk, i0 = pos; ex = None
            if d == 1:
                if L[i] <= sl: ex = min(sl, O[i])
                elif tp and H[i] >= tp: ex = max(tp, O[i])
            else:
                if H[i] >= sl: ex = max(sl, O[i])
                elif tp and L[i] <= tp: ex = min(tp, O[i])
            if ex is not None:
                trades.append((i0, d*(ex-ent)/risk - COST*ent/risk)); pos = None
            else:
                sl = max(sl, C[i]-3*ATR[i]) if d == 1 else min(sl, C[i]+3*ATR[i]); pos = (d, ent, sl, tp, risk, i0)
        if pos is None:
            d = signal(i)
            if not d: continue
            if not has_oi[i]: continue   # chi so sanh tren giai doan co OI cho cong bang
            if rnd is not None and rnd.random() > keep: continue
            sl = C[i] - d*2.5*ATR[i]; tp = 0
            if variant == "oi24_tang" and not (OI[i] > OI[i-6]): continue
            if variant == "oi24_giam" and not (OI[i] <= OI[i-6]): continue
            if variant == "oi_khong_qua_nong" and pct_rank(OI/np.r_[OI[:6]*np.nan, OI[:-6]], i) > 0.9: continue
            if variant == "dam_dong_nguoc":   # bo lenh khi dam dong (ty le tai khoan long/short) cung phia o muc cuc doan
                pr = pct_rank(ACC, i)
                if (d == 1 and pr > 0.8) or (d == -1 and pr < 0.2): continue
            if variant == "taker_xac_nhan" and not ((TAK[i]-1)*d > 0): continue
            if variant == "tp_cum_thanh_ly":
                lv = cluster_level(i, d, 2*ATR[i], 12*ATR[i], side_short=(d == 1))
                if lv: tp = lv - d*0.1*ATR[i]   # dat chot loi ngay truoc cum
            if variant == "sl_ne_cum":
                lv = cluster_level(i, d, -1.5*ATR[i], -3.5*ATR[i], side_short=(d == -1))
                if lv and abs(lv - sl) < 0.7*ATR[i]: sl = lv - d*0.5*ATR[i]
            risk = abs(C[i] - sl)
            pos = (d, C[i], sl, tp, risk, i)
    return trades

first = np.flatnonzero(has_oi)[0]
mid = np.searchsorted(T, 1709251200)
def stats(tr, lo, hi):
    rs = np.array([r for i, r in tr if lo <= i < hi])
    if len(rs) == 0: return (0, 0, 0, 0)
    eq = np.cumsum(rs); dd = (np.maximum.accumulate(np.r_[0, eq]) - np.r_[0, eq]).max()
    return (len(rs), eq[-1], dd, (rs > 0).mean()*100)
print("OI tu", np.datetime64(int(T[first]), "s"), "| gia den", np.datetime64(int(T[-1]), "s"))
print("%-22s %28s   %28s" % ("", "GD1 %s..2024-02 (n,R,DD,thang%%)" % str(np.datetime64(int(T[first]), "s"))[:7], "GD2 2024-03..het (n,R,DD,thang%)"))
for v in ["C_goc", "oi24_tang", "oi24_giam", "oi_khong_qua_nong", "dam_dong_nguoc", "taker_xac_nhan", "tp_cum_thanh_ly", "sl_ne_cum"]:
    tr = run(v); s1 = stats(tr, first, mid); s2 = stats(tr, mid, N)
    print("%-22s %5d %7.1f %6.1f %5.0f%%     %5d %7.1f %6.1f %5.0f%%" % (v, *s1, *s2))

# moc so sanh: bo lenh NGAU NHIEN cung ty le (vd giu 75% lenh) -> bo loc that phai vuot muc nay moi dang tin
base = run("C_goc")
for keep in (0.75, 0.6):
    rs = np.array([[stats(run("ngau_nhien", random.Random(s), keep), first, mid)[1], stats(run("ngau_nhien", random.Random(s), keep), mid, N)[1]] for s in range(200)])
    print("Bo ngau nhien giu %d%% lenh: R trung binh %.1f / %.1f, 90%% cao nhat %.1f / %.1f" % (keep*100, *rs.mean(0), *np.percentile(rs, 90, 0)))
